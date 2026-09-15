"""Read-only Git observations at validation boundaries, not an immutable checkout.

HEAD identifies unchanged files; SHA-256 overlays identify dirty/new inputs.
Ignored build caches are outside this source record. No git objects/index are written.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from datetime import datetime, timezone

if __package__:
    from .validation_plan import changed_paths, git
else:
    from validation_plan import changed_paths, git


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=True).encode()).hexdigest()


def snapshot(project):
    """Capture the actual worktree, including untracked inputs and index identity."""
    try:
        source = changed_paths(project, "HEAD")
        index = git(project, "ls-files", "--stage", "-z")
        status = git(project, "status", "--porcelain=v1", "-z", "--untracked-files=no")
        if git(project, "rev-parse", "HEAD").decode().strip() != source["head_commit"]:
            raise ValueError("HEAD changed while capturing source")
        for row in source["changes"]:
            if row["status"] != "D" and row["sha256"] is None:
                raise ValueError("Source disappeared or has unsupported type: " + row["path"])
        result = {"available": True, "commit": source["head_commit"], "tree": source["head_tree"],
                  "index_sha256": hashlib.sha256(index).hexdigest(),
                  "tracked_worktree_dirty": bool(status),
                  "untracked_source_count": sum(r["status"] == "?" for r in source["changes"]),
                  "changes": source["changes"]}
        result["fingerprint"] = digest(result)
        return result
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        return {"available": False, "commit": None, "tree": None,
                "tracked_worktree_dirty": None, "error": str(error)}


def check_output_directory(project, output):
    # Reports cannot become newly discovered inputs or overwrite previous evidence.
    if output.resolve().is_relative_to(project.resolve()):
        raise ValueError("Validation reports must be outside the project")
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError("Choose a new output directory to preserve previous check evidence")


class SourceRun:
    def __init__(self, project):
        self.project = Path(project).resolve()
        self.snapshots = []
        self.observations = []
        self.events = []
        self.record("run_start")
        # Sidecars must belong to scripts already identified at run start.
        try:
            self.known_sources = {os.fsdecode(p) for p in git(self.project, "ls-files", "-z").split(b"\0") if p}
        except (OSError, ValueError, subprocess.SubprocessError):
            self.known_sources = set()
        self.known_sources.update(r["path"] for r in self.start.get("changes", [])
                                  if r["status"] != "D" and not r["symlink"] and r["sha256"] is not None)

    @property
    def start(self):
        return self.snapshots[0]

    @property
    def end(self):
        return self.snapshots[self.observations[-1]["snapshot"]]

    @property
    def status(self):
        if any(not s["available"] for s in self.snapshots):
            return "unavailable"
        if any(e["unexpected"] for e in self.events):
            return "changed"
        return "generated_outputs_only" if self.events else "unchanged"

    @property
    def valid(self):
        return self.status in {"unchanged", "generated_outputs_only"}

    def record(self, checkpoint, allow_import_uids=False):
        current = snapshot(self.project)
        if self.observations:
            previous = self.end
            if current != previous:
                self.events.append(self._difference(previous, current, checkpoint, allow_import_uids))
        try:
            identity = self.snapshots.index(current)
        except ValueError:
            identity = len(self.snapshots)
            self.snapshots.append(current)
        self.observations.append({"checkpoint": checkpoint, "snapshot": identity,
                                  "observed_at": datetime.now(timezone.utc).isoformat()})

    def _difference(self, before, after, checkpoint, allow_import_uids):
        event = {"checkpoint": checkpoint, "unexpected": True, "changed_paths": [],
                 "generated_uid_paths": [], "revision_changed": before.get("commit") != after.get("commit")
                 or before.get("tree") != after.get("tree"),
                 "index_changed": before.get("index_sha256") != after.get("index_sha256")}
        if not before["available"] or not after["available"]:
            event["error"] = "Source observation unavailable"
            return event
        old = {r["path"]: r for r in before["changes"]}
        new = {r["path"]: r for r in after["changes"]}
        paths = {path for path in old.keys() | new.keys() if old.get(path) != new.get(path)}
        if before["tree"] != after["tree"]:
            try:
                paths.update(os.fsdecode(p) for p in git(self.project, "diff", "--no-ext-diff", "--no-textconv",
                    "--name-only", "--no-renames", "-z", before["commit"], after["commit"], "--").split(b"\0") if p)
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                event["error"] = str(error)
        for path in sorted(paths):
            if allow_import_uids and path not in old and self._generated_uid(path, new.get(path, {})):
                event["generated_uid_paths"].append(path)
            else:
                event["changed_paths"].append(path)
        event["unexpected"] = bool(event["changed_paths"] or event["revision_changed"] or event["index_changed"]
                                   or event.get("error") or not event["generated_uid_paths"])
        return event

    def _generated_uid(self, path, row):
        if not path.endswith((".gd.uid", ".gdshader.uid")) or path[:-4] not in self.known_sources:
            return False
        if row.get("status") != "?" or row.get("symlink"):
            return False
        try:
            if (self.project / path).stat().st_size > 64:
                return False
            value = (self.project / path).read_bytes()
            return bool(re.fullmatch(rb"uid://[a-z0-9]+\n?", value)) and hashlib.sha256(value).hexdigest() == row["sha256"]
        except OSError:
            return False

    def report(self):
        return {"schema": 1, "status": self.status, "passed": self.valid,
                "source_start": self.start, "source_end": self.end,
                "snapshots": self.snapshots, "observations": self.observations, "events": self.events,
                "limits": "Git-tracked and nonignored untracked inputs sampled at command boundaries; not a filesystem lock. "
                          "A change fully reverted between observations may be missed. Ignored files, imported cache contents "
                          "and external symlink targets are not certified. New valid UID sidecars for scripts identified at run start are "
                          "recorded as generated outputs only immediately after import; later edits still fail."}
