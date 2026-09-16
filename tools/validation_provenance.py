"""Local source observations for validation, without changing Git or source files.

Hash actual tracked and nonignored untracked bytes. Cache content hashes only
while inode/size/mtime/ctime/mode match; force a complete reread at the end.
Observations are not a filesystem lock or a claim about ignored/external inputs.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import time

MAX_FILES = 200_000
MAX_FILE_BYTES = 512 * 1024 * 1024
MAX_TOTAL_BYTES = 4 * 1024 * 1024 * 1024
UID = re.compile(rb"uid://[a-z0-9]+\r?\n?\Z")
WINDOWS = os.name == "nt"


def _json(value):
    return json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(",", ":")).encode()


def _digest(value):
    return hashlib.sha256(_json(value)).hexdigest()


def _signature(info):
    return (info.st_dev, info.st_ino, info.st_mode, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def _same_open_file(path_signature, descriptor_signature):
    # Windows can report creation time through lstat() and metadata-change
    # time through fstat(). Compare their common file identity here. Keep both
    # full signatures for same-API checks before/after reading and at boundaries.
    if WINDOWS:
        return path_signature[:-1] == descriptor_signature[:-1]
    return path_signature == descriptor_signature


class SourceRun:
    def __init__(self, project):
        self.project = Path(project).resolve()
        self.cache = {}
        self._status_key = None
        self._tracked_dirty = None
        self.observations = []
        self.blocked = False
        self.prepared = False
        self.manifests = {}
        self.start = self._capture()
        self.current = self.start
        if not self.start["available"]:
            self.blocked = True

    def _git(self, *args):
        result = subprocess.run(["git", "--no-optional-locks", "-C", str(self.project), *args],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20)
        if result.returncode:
            raise ValueError("Source Git query failed: " + result.stderr.decode("utf-8", "replace").strip())
        return result.stdout

    def _state(self):
        top = Path(os.fsdecode(self._git("rev-parse", "--show-toplevel")).rstrip("\n")).resolve()
        if top != self.project:
            raise ValueError("Source provenance requires --project at the Git repository root")
        refs = self._git("rev-parse", "HEAD", "HEAD^{tree}").decode().splitlines()
        if len(refs) != 2:
            raise ValueError("Incomplete Git source revision")
        index = self._git("ls-files", "--stage", "-z")
        others = self._git("ls-files", "--others", "--exclude-standard", "-z")
        return {"commit": refs[0], "tree": refs[1], "index": index, "others": others}

    def _file(self, path, force):
        file = self.project / path
        # Do not follow a replaced parent directory to external data.
        parent = file.parent
        while parent != self.project:
            try: parent_info = parent.lstat()
            except FileNotFoundError: return {"path": path, "kind": "missing"}, None, 0
            if not stat.S_ISDIR(parent_info.st_mode):
                raise ValueError("Source parent is not a regular directory: " + path)
            parent = parent.parent
        try:
            before = file.lstat()
        except FileNotFoundError:
            return {"path": path, "kind": "missing"}, None, 0
        signature = _signature(before)
        cached = self.cache.get(path)
        if not force and cached is not None and cached[0] == signature:
            return cached[1], signature, 0
        kind = ("symlink" if stat.S_ISLNK(before.st_mode) else
                "file" if stat.S_ISREG(before.st_mode) else "unsupported")
        if kind == "unsupported":
            raise ValueError("Source path is not a regular file/link: " + path)
        record = {"path": path, "kind": kind, "executable": bool(before.st_mode & stat.S_IXUSR)}
        if kind == "symlink":
            raw = os.fsencode(os.readlink(file))
            record.update(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
            read = len(raw)
        else:
            if before.st_size > MAX_FILE_BYTES:
                raise ValueError("Source file byte budget exceeded: " + path)
            flags = (os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
                     | getattr(os, "O_NONBLOCK", 0) | getattr(os, "O_BINARY", 0))
            digest, prefix, read = hashlib.sha256(), b"", 0
            with os.fdopen(os.open(file, flags), "rb") as stream:
                opened_signature = _signature(os.fstat(stream.fileno()))
                if not _same_open_file(signature, opened_signature):
                    raise ValueError("Source changed while opening: " + path)
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    read += len(chunk)
                    if read > MAX_FILE_BYTES:
                        raise ValueError("Source file byte budget exceeded: " + path)
                    digest.update(chunk)
                    if len(prefix) < 128: prefix += chunk[:128 - len(prefix)]
                if _signature(os.fstat(stream.fileno())) != opened_signature:
                    raise ValueError("Source changed while hashing: " + path)
            record.update(bytes=read, sha256=digest.hexdigest())
            if path.endswith(".uid"):
                record["godot_uid"] = read <= 128 and UID.fullmatch(prefix) is not None
        if _signature(file.lstat()) != signature:
            raise ValueError("Source changed during observation: " + path)
        self.cache[path] = (signature, record)
        return record, signature, read

    def _capture(self, force=False):
        started = time.monotonic()
        try:
            state = self._state()
            paths, tracked, submodules = set(), set(), {}
            for row in state["index"].split(b"\0"):
                if not row: continue
                metadata, raw_path = row.split(b"\t", 1)
                mode, oid, stage = metadata.decode().split()
                path = os.fsdecode(raw_path)
                if stage != "0": raise ValueError("Resolve Git conflicts before validating sources")
                paths.add(path)
                tracked.add(path)
                if mode == "160000": submodules[path] = oid
            paths.update(os.fsdecode(p) for p in state["others"].split(b"\0") if p)
            if len(paths) > MAX_FILES: raise ValueError("Source file-count budget exceeded")
            records, signatures, total, read = [], {}, 0, 0
            for path in sorted(paths):
                if Path(path).is_absolute() or ".." in Path(path).parts:
                    raise ValueError("Invalid repository-relative source path")
                if path in submodules:
                    records.append({"path": path, "kind": "gitlink", "commit": submodules[path], "tracked": True})
                    continue
                record, signature, count = self._file(path, force)
                records.append({**record, "tracked": path in tracked})
                signatures[path] = signature
                total += record.get("bytes", 0)
                read += count
                if total > MAX_TOTAL_BYTES: raise ValueError("Source inventory byte budget exceeded")
            # Git status can rehash the whole checkout when its optional index
            # refresh is disabled. Reuse it only while HEAD/index and every
            # tracked file signature match; content monitoring still runs above.
            status_key = _digest([state["commit"], hashlib.sha256(state["index"]).hexdigest(),
                                  [[p, signatures.get(p)] for p in sorted(tracked)]])
            if status_key != self._status_key:
                self._tracked_dirty = bool(self._git("status", "--porcelain=v1", "-z", "--untracked-files=no"))
                self._status_key = status_key
            # Guard both Git metadata and membership while the file inventory
            # was built. A disappearing/restored file still changes its stat.
            if self._state() != state: raise ValueError("Git source state changed during observation")
            for path, signature in signatures.items():
                try: actual = _signature((self.project / path).lstat())
                except FileNotFoundError: actual = None
                if actual != signature: raise ValueError("Source changed during inventory: " + path)
            self.cache = {path: self.cache[path] for path in paths if path in self.cache}
            identity = [{k: v for k, v in r.items() if k not in {"tracked", "godot_uid"}}
                        for r in records if r["kind"] != "missing"]
            return {"available": True, "commit": state["commit"], "tree": state["tree"],
                    "tracked_worktree_dirty": self._tracked_dirty,
                    "index_sha256": hashlib.sha256(state["index"]).hexdigest(),
                    "source_sha256": _digest(identity), "files": records, "signatures": signatures,
                    "complete": not submodules and not any(r["kind"] == "symlink" for r in records),
                    "file_count": len(records), "bytes": total, "bytes_hashed": read,
                    "seconds": round(time.monotonic() - started, 4)}
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            return {"available": False, "commit": None, "tree": None, "tracked_worktree_dirty": None,
                    "error": str(error), "files": [], "signatures": {}, "complete": False,
                    "seconds": round(time.monotonic() - started, 4)}

    @staticmethod
    def summary(snapshot):
        return {k: v for k, v in snapshot.items() if k not in {"files", "signatures"}}

    def observe(self, after, force=False):
        before, current = self.current, self._capture(force)
        observation = {"after": after, "source": self.summary(current), "changes": [], "git_changes": []}
        if before["available"] and current["available"]:
            old = {r["path"]: r for r in before["files"]}
            new = {r["path"]: r for r in current["files"]}
            for path in sorted(old.keys() | new.keys()):
                if old.get(path) != new.get(path):
                    observation["changes"].append({"path": path, "kind": "content_or_membership",
                                                    "before": old.get(path), "after": new.get(path)})
                elif before["signatures"].get(path) != current["signatures"].get(path):
                    observation["changes"].append({"path": path, "kind": "touched_or_replaced",
                                                    "sha256": new[path].get("sha256")})
            observation["git_changes"] = [key for key in ("commit", "tree", "index_sha256", "tracked_worktree_dirty")
                                           if before[key] != current[key]]
            generated = bool(observation["changes"]) and after == "import" and not observation["git_changes"]
            for change in observation["changes"]:
                row = change.get("after") or {}
                owner = row.get("path", "")[:-4]
                uid_created = (change.get("before") is None and row.get("godot_uid") is True
                             and not row.get("tracked") and row.get("path", "").endswith((".gd.uid", ".gdshader.uid"))
                             and old.get(owner, {}).get("kind") == "file" and old[owner] == new.get(owner))
                # Godot rewrites existing import descriptors even when their
                # bytes are identical. Restrict this exception to import, an
                # unchanged descriptor and its unchanged existing source asset.
                path = change["path"]
                asset = path[:-7]
                import_refreshed = (change["kind"] == "touched_or_replaced" and path.endswith(".import")
                                    and old[path]["kind"] == "file" and old[path] == new[path]
                                    and old.get(asset, {}).get("kind") == "file" and old[asset] == new.get(asset))
                generated = generated and (uid_created or import_refreshed)
            changed = bool(observation["changes"] or observation["git_changes"])
            observation["status"] = "import_preparation" if generated else "changed" if changed else "unchanged"
            self.prepared |= bool(generated)
            self.blocked |= changed and not generated
        else:
            observation["status"] = "unavailable"
            self.blocked = True
        self.current = current
        self.observations.append(observation)
        return observation

    def _write_manifest(self, directory, name, snapshot):
        path = directory / f"source-files-{name}.jsonl"
        digest = hashlib.sha256()
        with path.open("xb") as stream:
            for record in snapshot["files"]:
                raw = _json(record) + b"\n"
                stream.write(raw)
                digest.update(raw)
        self.manifests[name] = {"path": path.name, "sha256": digest.hexdigest()}

    def begin_report(self, directory):
        self._write_manifest(directory, "start", self.start)
        with (directory / "run-start.json").open("x", encoding="utf-8") as stream:
            json.dump({"schema": 1, "status": "in_progress", "source": self.summary(self.start),
                       "manifest": self.manifests["start"]}, stream, indent=2)
            stream.write("\n")

    def write_report(self, directory):
        self._write_manifest(directory, "end", self.current)
        return {"schema": 1, "start": self.summary(self.start), "end": self.summary(self.current),
                "status": "changed_or_unavailable" if self.blocked else "prepared" if self.prepared else "stable",
                "reusable": not self.blocked and self.start["complete"] and self.current["complete"],
                "manifests": self.manifests, "observations": self.observations,
                "scope": "Tracked and nonignored untracked repository entries; symlink targets, submodules and ignored/generated caches are not monitored. Boundary observations are not a source lock."}
