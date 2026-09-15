"""Offline generation manifests and retain-only plans for shared region blobs.

The game must be stopped. Reports describe exact source bytes, not a new game
save or a portable backup. No code in this module deletes source files. Unknown
data remains protected; absence from known roots never authorizes deletion.
"""
from __future__ import annotations

import hashlib
from contextlib import closing
import os
from pathlib import Path
import shutil
import sqlite3
import tempfile

if __package__:
    from . import region_backup as backup
    from . import region_backup_userdata as userdata
else:
    import region_backup as backup
    import region_backup_userdata as userdata

FORMAT = "voxelverse_region_retention_v1"
RECORD = "region-retention.json"
REPORTS = ("files.jsonl", "owners.jsonl", "roots.jsonl", "blobs.jsonl")
MAX_ROOTS = 100_000
MAX_JSON_DEPTH = 128


def _references(value, location="$", depth=0, archives=0):
    """Find existing stores in every JSON owner, including labs and originals.

    Reuse the backup validators for saves/atlases instead of adding another
    interpretation of their schemas. Generic manifests are retained too, but
    are only structurally validated, not declared valid gameplay state.
    """
    backup._require(depth <= MAX_JSON_DEPTH, "Owner JSON nesting exceeds retention budget")
    backup._require(archives <= backup.MAX_ARCHIVE_DEPTH, "Embedded archive nesting exceeds retention budget")
    if isinstance(value, list):
        for index, child in enumerate(value):
            yield from _references(child, f"{location}/{index}", depth + 1, archives)
    if not isinstance(value, dict):
        return
    if "game_state" in value:
        # Old inline originals are preserved; versions with external regions
        # must obey the existing complete-save root contract, including futures.
        if value.get("schema") not in (1, 2):
            for _ in backup._roots(value):
                pass
    excluded = set()
    if {"tiles", "places", "body_id", "mode", "divisions"} <= value.keys():
        root = backup._atlas_root(value, value["body_id"])
        if value["schema"] >= 2:
            yield location + "/storage", root, value
        if value["schema"] == 3:
            yield location + "/place_storage", value["place_storage"]["root"], backup.PlaceReference(value)
        excluded.update(("storage", "place_storage"))
    elif ("root" in value and "format" in value) or value.get("format") == backup.STORE_FORMAT:
        yield location, backup._storage_root(value), None
        excluded.update(("schema", "format", "root"))
    for key, child in value.items():
        if key in excluded:
            continue
        pointer = location + "/" + key.replace("~", "~0").replace("/", "~1")
        if key in ("legacy_save_text", "source_text"):
            backup._require(isinstance(child, str), "Embedded source must be JSON text")
            raw = child.encode("utf-8")
            backup._require(len(raw) <= backup.MAX_ARCHIVE_BYTES, "Embedded source exceeds byte budget")
            if key == "source_text":
                backup._require(backup._digest(raw) == value.get("source_sha256"), "Migration source checksum mismatch")
            yield from _references(backup._object(raw), pointer + "/@json", depth + 1, archives + 1)
        else:
            yield from _references(child, pointer, depth + 1, archives)


def _blob_digest(relative: str) -> str | None:
    parts = relative.split("/")
    if len(parts) == 4 and parts[:2] == ["regions", "blobs"] and parts[3].endswith(".json"):
        digest = parts[3][:-5]
        if backup.HASH.fullmatch(digest) and parts[2] == digest[:2]:
            return digest
    return None


def _finish(stream):
    stream.flush()
    os.fsync(stream.fileno())


def _build(source: Path, directory: Path) -> dict:
    """Stream the inventory; keep the world-sized unique-blob set on disk."""
    stats = {"files": 0, "directories": 0, "bytes": 0, "entries": 0,
             "owners": 0, "opaque_owners": 0, "roots": 0, "blobs": 0,
             "reachable_blobs": 0, "reachable_bytes": 0,
             "not_referenced_by_known_roots": 0, "not_referenced_bytes": 0}
    inventory_digest = hashlib.sha256()
    walk_stats = backup.Stats()
    with tempfile.TemporaryDirectory(prefix="voxelverse-retention-index-") as temporary:
        with closing(sqlite3.connect(str(Path(temporary) / "index.sqlite"))) as index:
            # SQLite's page cache and disk index avoid a galaxy-sized Python set.
            index.execute("PRAGMA cache_size = -2048")
            index.execute("CREATE TABLE blobs (digest TEXT PRIMARY KEY, path TEXT, bytes INTEGER)")
            index.execute("CREATE TABLE reachable (digest TEXT PRIMARY KEY)")
            with (directory / "files.jsonl").open("xb") as files, \
                    (directory / "owners.jsonl").open("xb") as owners, \
                    (directory / "roots.jsonl").open("xb") as roots:
                for relative, kind, _ in userdata._entries(source):
                    backup._require(stats["entries"] < userdata.MAX_ENTRIES, "User-data entry budget exceeded")
                    entry = (userdata._file_record(source / relative, relative) if kind == "file"
                             else {"path": relative, "kind": kind})
                    raw_entry = userdata._line(entry)
                    files.write(raw_entry)
                    inventory_digest.update(raw_entry)
                    stats["entries"] += 1
                    stats["files" if kind == "file" else "directories"] += 1
                    stats["bytes"] += entry.get("bytes", 0)
                    if kind != "file":
                        continue
                    digest = _blob_digest(relative)
                    if digest:
                        backup._require(entry["sha256"] == digest, "Region checksum mismatch: " + relative)
                        index.execute("INSERT INTO blobs VALUES (?, ?, ?)", (digest, relative, entry["bytes"]))
                        continue
                    stats["owners"] += 1
                    count = 0
                    status = "opaque_retained"
                    if entry["bytes"] <= backup.MAX_SAVE_BYTES:
                        raw = backup._read(source / relative, backup.MAX_SAVE_BYTES)
                        backup._require(backup._digest(raw) == entry["sha256"], "Owner changed while planning: " + relative)
                        try:
                            value = backup._object(raw)
                        except backup.BackupError:
                            # Damaged named JSON snapshots cannot become a
                            # completed generation through an older backup.
                            backup._require(".json" not in Path(relative).name,
                                            "Unreadable JSON owner: " + relative)
                        else:
                            status = "json_scanned"
                            for location, root, context in _references(value):
                                backup._require(stats["roots"] < MAX_ROOTS, "Root reference budget exceeded")
                                contract = ("atlas_places" if isinstance(context, backup.PlaceReference)
                                            else "atlas_tiles" if context is not None else "region_trie")
                                roots.write(userdata._line({"owner": relative, "owner_sha256": entry["sha256"],
                                    "location": location, "root": root, "contract": contract}))
                                stats["roots"] += 1
                                count += 1
                                if root or isinstance(context, backup.PlaceReference):
                                    if root:
                                        userdata._directory(source / "regions")
                                        userdata._directory(source / "regions/blobs")
                                    for reached, _ in backup._walk(source / "regions/blobs", root, walk_stats, context):
                                        index.execute("INSERT OR IGNORE INTO reachable VALUES (?)", (reached,))
                    else:
                        backup._require(".json" not in Path(relative).name, "JSON owner exceeds byte budget: " + relative)
                    stats["opaque_owners"] += status == "opaque_retained"
                    owners.write(userdata._line({**entry, "status": status, "roots": count, "action": "retain"}))
                for stream in (files, owners, roots):
                    _finish(stream)
            # A closure reached during traversal must also exist in the complete
            # inventory. This detects removals between owner and blob scanning.
            missing = index.execute("SELECT digest FROM reachable EXCEPT SELECT digest FROM blobs LIMIT 1").fetchone()
            backup._require(missing is None, "Reachable blob missing from generation inventory")
            with (directory / "blobs.jsonl").open("xb") as blobs:
                for digest, path, size, reached in index.execute(
                        "SELECT b.digest, b.path, b.bytes, r.digest IS NOT NULL "
                        "FROM blobs b LEFT JOIN reachable r ON b.digest = r.digest ORDER BY b.path"):
                    stats["blobs"] += 1
                    stats["reachable_blobs" if reached else "not_referenced_by_known_roots"] += 1
                    stats["reachable_bytes" if reached else "not_referenced_bytes"] += size
                    blobs.write(userdata._line({"path": path, "sha256": digest, "bytes": size,
                        "referenced_by_known_roots": bool(reached), "action": "retain",
                        "reason": "reachable" if reached else "not_a_deletion_proof"}))
                _finish(blobs)
    stats["source_generation"] = inventory_digest.hexdigest()
    reports = {name: userdata._file_record(directory / name, name) for name in REPORTS}
    record = {"schema": 1, "format": FORMAT, "validation": "known_region_closures",
              "policy": "retain_all", "deletion_allowed": False, "stats": stats, "reports": reports}
    backup._write_new(directory / RECORD, userdata._line(record))
    return record


def _match_source(source: Path, directory: Path, record: dict):
    actual = userdata._match_tree(source, directory / "files.jsonl")
    backup._require(actual["index_sha256"] == record["stats"]["source_generation"],
                    "Source generation changed while planning")


def _read_plan(directory: Path) -> dict:
    userdata._directory(directory)
    backup._require({p.name for p in directory.iterdir()} == {*REPORTS, RECORD}, "Unexpected retention report contents")
    record = backup._object(backup._read(directory / RECORD, userdata.MAX_LINE_BYTES))
    backup._require(type(record.get("schema")) is int and record["schema"] == 1
                    and record.get("format") == FORMAT and record.get("policy") == "retain_all"
                    and record.get("validation") == "known_region_closures"
                    and record.get("deletion_allowed") is False, "Unsupported retention plan")
    backup._require(isinstance(record.get("stats"), dict)
                    and isinstance(record["stats"].get("source_generation"), str)
                    and backup.HASH.fullmatch(record["stats"]["source_generation"]), "Invalid source generation")
    backup._require(isinstance(record.get("reports"), dict)
                    and set(record["reports"]) == set(REPORTS), "Missing retention report index")
    for name in REPORTS:
        backup._require(userdata._file_record(directory / name, name) == record["reports"].get(name),
                        "Retention report checksum mismatch: " + name)
    return record


def plan_retention(source: Path, output: Path) -> dict:
    source = source.absolute()
    userdata._directory(source)
    source = source.resolve()
    output = output.absolute()
    target = output.resolve()
    project = Path(__file__).resolve().parents[1]
    backup._require(not output.exists() and not output.is_symlink(), "Retention destination already exists")
    backup._require(not target.is_relative_to(source) and not source.is_relative_to(target)
                    and not target.is_relative_to(project), "Retention output must be outside source and project")
    output.parent.mkdir(parents=True, exist_ok=True)
    lock = output.with_name("." + output.name + ".region-retention-lock")
    with lock.open("xb"):
        pass
    staging = None
    try:
        staging = Path(tempfile.mkdtemp(prefix="." + output.name + ".partial-", dir=output.parent))
        record = _build(source, staging)
        backup._require(_read_plan(staging) == record, "Written generation verification failed")
        _match_source(source, staging, record)
        backup._require(not output.exists() and not output.is_symlink(), "Destination appeared while planning")
        staging.rename(output)
        staging = None
        return record
    finally:
        if staging is not None:
            shutil.rmtree(staging)
        lock.unlink()


def verify_retention(source: Path, directory: Path) -> dict:
    """Replay against the exact source generation, including all closure checks."""
    source, directory = source.absolute(), directory.absolute()
    userdata._directory(source)
    record = _read_plan(directory)
    _match_source(source, directory, record)
    with tempfile.TemporaryDirectory(prefix="voxelverse-retention-verify-") as temporary:
        rebuilt = Path(temporary)
        actual = _build(source, rebuilt)
        _match_source(source, rebuilt, actual)
        backup._require(actual == record, "Retention plan differs from verified source generation")
    return record
