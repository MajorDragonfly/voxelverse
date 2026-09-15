"""Byte-preserving archives of a stopped Voxelverse user-data directory.

Unlike a selected-slot export, this deliberately retains every regular file,
including laboratory stores, loose designs, migration originals and all blobs.
Unknown or damaged game formats are preserved, not repaired or declared playable.
"""
from __future__ import annotations

from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import tempfile

if __package__:
    from .region_backup import BackupError, _object, _read, _require, _write_new
else:
    from region_backup import BackupError, _object, _read, _require, _write_new

FORMAT = "voxelverse_userdata_backup_v1"
RECORD = "userdata-backup.json"
INDEX = "files.jsonl"
PAYLOAD = "userdata"
CHUNK_BYTES = 1024 * 1024
MAX_ENTRIES = 1_000_000
MAX_DIRECTORY_ENTRIES = 16384
MAX_DEPTH = 64
MAX_LINE_BYTES = 65536


def _signature(info):
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns,
            info.st_ctime_ns, info.st_mode)


def _directory(path: Path) -> None:
    _require(stat.S_ISDIR(path.lstat().st_mode), f"Not a regular directory: {path}")


def _entries(directory: Path, prefix: str = "", depth: int = 0):
    """Canonical depth-first listing, including empty directories, with budgets."""
    _require(depth <= MAX_DEPTH, "User-data directory nesting exceeds backup budget")
    _directory(directory)
    names = []
    with os.scandir(directory) as listing:
        for entry in listing:
            _require(len(names) < MAX_DIRECTORY_ENTRIES, "Directory entry budget exceeded")
            _require("\\" not in entry.name and ":" not in entry.name,
                     "Filename is not portable: " + entry.name)
            names.append(entry.name)
    for name in sorted(names):
        path = directory / name
        relative = prefix + name
        info = path.lstat()
        _require(stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode),
                 f"Links and special files cannot be archived: {path}")
        kind = "directory" if stat.S_ISDIR(info.st_mode) else "file"
        yield relative, kind, info
        if kind == "directory":
            yield from _entries(path, relative + "/", depth + 1)


@contextmanager
def _regular(path: Path):
    # O_NONBLOCK also prevents a replaced FIFO from blocking the exporter.
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
    before = path.lstat()
    _require(stat.S_ISREG(before.st_mode), f"Not a regular file: {path}")
    with os.fdopen(os.open(path, flags), "rb") as stream:
        opened = os.fstat(stream.fileno())
        _require(_signature(before) == _signature(opened), "File changed before opening: " + str(path))
        yield stream
        _require(_signature(opened) == _signature(os.fstat(stream.fileno()))
                 == _signature(path.lstat()), "File changed while reading: " + str(path))


def _file_record(source: Path, relative: str, destination: Path | None = None) -> dict:
    digest = hashlib.sha256()
    size = 0
    with _regular(source) as reader:
        writer = destination.open("xb") if destination is not None else None
        try:
            while chunk := reader.read(CHUNK_BYTES):
                digest.update(chunk)
                size += len(chunk)
                if writer is not None:
                    writer.write(chunk)
            if writer is not None:
                writer.flush()
                os.fsync(writer.fileno())
        finally:
            if writer is not None:
                writer.close()
    return {"path": relative, "kind": "file", "bytes": size, "sha256": digest.hexdigest()}


def _line(record: dict) -> bytes:
    raw = (json.dumps(record, ensure_ascii=True, separators=(",", ":")) + "\n").encode()
    _require(len(raw) <= MAX_LINE_BYTES, "File manifest line exceeds backup budget")
    return raw


def _match_tree(directory: Path, index: Path) -> dict:
    """Compare traversal to the index; no manifest-supplied path is opened."""
    result = {"files": 0, "directories": 0, "bytes": 0, "entries": 0}
    digest = hashlib.sha256()
    with _regular(index) as manifest:
        for relative, kind, _ in _entries(directory):
            _require(result["entries"] < MAX_ENTRIES, "User-data entry budget exceeded")
            raw = manifest.readline(MAX_LINE_BYTES + 1)
            _require(raw.endswith(b"\n") and len(raw) <= MAX_LINE_BYTES,
                     "Missing or oversized file manifest entry")
            entry = _object(raw)
            actual = (_file_record(directory / relative, relative) if kind == "file"
                      else {"path": relative, "kind": "directory"})
            _require(raw == _line(actual), "Archive tree or file bytes differ: " + relative)
            digest.update(raw)
            result["entries"] += 1
            result["files" if kind == "file" else "directories"] += 1
            result["bytes"] += entry.get("bytes", 0)
        _require(not manifest.read(1), "Manifest contains missing or duplicate paths")
    return {**result, "index_sha256": digest.hexdigest()}


def verify_userdata(directory: Path) -> dict:
    directory = directory.absolute()
    _directory(directory)
    _require({path.name for path in directory.iterdir()} == {RECORD, INDEX, PAYLOAD},
             "Unexpected or missing archive contents")
    record = _object(_read(directory / RECORD, MAX_LINE_BYTES))
    _require(record.get("schema") == 1 and type(record.get("schema")) is int
             and record.get("format") == FORMAT, "Unsupported user-data archive format")
    actual = _match_tree(directory / PAYLOAD, directory / INDEX)
    expected = {"schema": 1, "format": FORMAT, "validation": "exact_file_bytes", **actual}
    _require(record == expected, "Archive completion record differs from verified contents")
    return actual


def export_userdata(source: Path, output: Path) -> dict:
    source = source.absolute()
    _directory(source)
    source = source.resolve()
    output = output.absolute()
    _require(not output.exists() and not output.is_symlink(), "Backup destination already exists")
    project = Path(__file__).resolve().parents[1]
    target = output.resolve()
    _require(not target.is_relative_to(source) and not source.is_relative_to(target)
             and not target.is_relative_to(project),
             "Backup output must be outside the source tree and project")
    output.parent.mkdir(parents=True, exist_ok=True)
    lock = output.with_name("." + output.name + ".region-backup-lock")
    with lock.open("xb"):
        pass
    staging = None
    try:
        staging = Path(tempfile.mkdtemp(prefix="." + output.name + ".partial-", dir=output.parent))
        (staging / PAYLOAD).mkdir()
        result = {"files": 0, "directories": 0, "bytes": 0, "entries": 0}
        digest = hashlib.sha256()
        with (staging / INDEX).open("xb") as index:
            for relative, kind, _ in _entries(source):
                _require(result["entries"] < MAX_ENTRIES, "User-data entry budget exceeded")
                destination = staging / PAYLOAD / relative
                if kind == "directory":
                    destination.mkdir()
                    entry = {"path": relative, "kind": kind}
                else:
                    entry = _file_record(source / relative, relative, destination)
                raw = _line(entry)
                index.write(raw)
                digest.update(raw)
                result["entries"] += 1
                result["files" if kind == "file" else "directories"] += 1
                result["bytes"] += entry.get("bytes", 0)
            index.flush()
            os.fsync(index.fileno())
        result["index_sha256"] = digest.hexdigest()
        _write_new(staging / RECORD, _line({"schema": 1, "format": FORMAT,
                                           "validation": "exact_file_bytes", **result}))
        # First verify the complete destination, then re-read every source file
        # and its directory membership. This detects ordinary concurrent writes;
        # it cannot replace stopping the game's non-cooperating writers.
        _require(verify_userdata(staging) == result, "Destination verification failed")
        _require(_match_tree(source, staging / INDEX) == result, "Source changed during export")
        _require(not output.exists() and not output.is_symlink(), "Destination appeared during export")
        staging.rename(output)
        staging = None
        return result
    finally:
        if staging is not None:
            shutil.rmtree(staging)
        lock.unlink()
