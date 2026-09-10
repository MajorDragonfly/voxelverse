#!/usr/bin/env python3
"""Export/verify committed slots and every referenced immutable region blob.

The output is a new Godot user-data directory, with region-backup.json as its
completion record. No running game state is captured and no source is changed.
"""
from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import tempfile
from collections.abc import Iterator

FORMAT = "voxelverse_region_backup_v1"
STORE_FORMAT = "sha256_trie_v1"
MAX_BLOB_BYTES = 2 * 1024 * 1024  # RegionStore.MAX_BYTES
MAX_SAVE_BYTES = 64 * 1024 * 1024
MAX_ARCHIVE_BYTES = 16 * 1024 * 1024  # SphericalMigration.MAX_SOURCE_BYTES
MAX_SNAPSHOTS = 4096
MAX_ARCHIVE_DEPTH = 8
HASH = re.compile(r"[0-9a-f]{64}\Z")
RECORD = "region-backup.json"


class BackupError(ValueError):
    """A backup is incomplete, unsupported or cannot be published safely."""


@dataclass
class Stats:
    snapshots: int = 0
    roots: int = 0
    verified_blobs: int = 0  # References visited; shared history can repeat them.
    copied_blobs: int = 0
    copied_bytes: int = 0
    peak_pending: int = 0
    peak_blob_bytes: int = 0


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise BackupError(message)


def _digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _read(path: Path, limit: int) -> bytes:
    # Do not follow a blob or snapshot symlink out of the selected source.
    _require(not path.is_symlink(), f"Symbolic link is not a backup file: {path}")
    with os.fdopen(os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)), "rb") as stream:
        _require(stat.S_ISREG(os.fstat(stream.fileno()).st_mode), f"Not a regular file: {path}")
        raw = stream.read(limit + 1)
    _require(len(raw) <= limit, f"File exceeds the {limit}-byte budget: {path}")
    return raw


def _object(raw: bytes) -> dict:
    def unique(pairs):
        result = {}
        for key, value in pairs:
            _require(key not in result, f"Duplicate JSON key: {key}")
            result[key] = value
        return result

    def invalid_constant(value):
        raise BackupError(f"Non-finite JSON number: {value}")

    def finite_float(text):
        value = float(text)
        _require(math.isfinite(value), "Non-finite JSON number")
        return value

    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique,
                           parse_constant=invalid_constant, parse_float=finite_float)
    except (UnicodeError, json.JSONDecodeError, RecursionError) as error:
        raise BackupError("Unreadable JSON object") from error
    _require(isinstance(value, dict), "Expected a JSON object")
    return value


def _version(value, versions: range | tuple, label: str) -> None:
    _require(type(value) in (int, float) and value in versions, f"Unsupported {label} version: {value}")


def _storage_root(storage) -> str:
    _require(isinstance(storage, dict), "Missing region manifest")
    _version(storage.get("schema"), (1,), "region manifest")
    _require(storage.get("format") == STORE_FORMAT, "Unknown region storage format")
    root = storage.get("root")
    _require(isinstance(root, str) and (root == "" or HASH.fullmatch(root)), "Invalid root hash")
    return root


def _atlas_rows(rows) -> None:
    _require(isinstance(rows, list) and len(rows) == 32 and all(
        type(row) in (int, float) and 0 <= row <= 4294967295 and row == int(row) for row in rows),
        "Invalid atlas tile rows")


def _atlas_key(key: str, atlas: dict) -> None:
    parts = key.split(":")
    _require(len(key) <= 72 and len(parts) == 3 and all(
        re.fullmatch(r"0|-?[1-9][0-9]{0,9}", part) and abs(int(part)) <= 2147483647 for part in parts),
        "Invalid atlas tile key")
    _require(int(parts[0]) in ((-1,) if atlas["mode"] == "legacy_plane_v9" else range(6)),
        "Invalid atlas tile face")


def _atlas_root(atlas, body_id: str) -> str:
    _require(isinstance(atlas, dict), "Invalid exploration atlas")
    _version(atlas.get("schema"), (1, 2), "exploration atlas")
    # A future register (e.g. paged places) needs its own explicit root adapter;
    # silently copying an unrecognized pointer would produce a partial backup.
    fields = {"schema", "body_id", "mode", "radius", "divisions", "tiles", "places"}
    if atlas["schema"] == 2:
        fields.update(("storage", "extent"))
    _require(set(atlas) <= fields, "Unsupported exploration atlas fields")
    _require(isinstance(body_id, str) and bool(body_id) and atlas.get("body_id") == body_id,
        "Atlas belongs to a different body")
    _require(atlas.get("mode") in ("legacy_plane_v9", "cube_sphere_m1_v1"), "Unknown atlas surface mode")
    radius = atlas.get("radius")
    _require(type(radius) in (int, float) and math.isfinite(radius) and 0 <= radius <= 1e10,
        "Invalid atlas radius")
    sphere = atlas["mode"] == "cube_sphere_m1_v1"
    _require(radius > 0 if sphere else radius == 0, "Atlas radius and mode differ")
    divisions = 2 ** math.ceil(math.log2(max(2 * radius / 16, 1))) if sphere else 0
    _require(type(atlas.get("divisions")) in (int, float) and atlas["divisions"] == divisions,
        "Invalid atlas resolution")
    tiles, places = atlas.get("tiles"), atlas.get("places")
    _require(isinstance(tiles, dict) and len(tiles) <= (96 if atlas["schema"] == 2 else 8192)
        and isinstance(places, dict) and len(places) <= 2048, "Invalid atlas collection")
    for key, rows in tiles.items():
        _atlas_key(key, atlas)
        _atlas_rows(rows)
    if atlas["schema"] == 1:
        return ""
    extent = atlas.get("extent")
    _require(isinstance(extent, list) and (not extent or (len(extent) == 4 and all(
        type(value) in (int, float) and math.isfinite(value) for value in extent)
        and extent[0] <= extent[2] and extent[1] <= extent[3])), "Invalid atlas extent")
    return _storage_root(atlas.get("storage"))


def _roots(snapshot: dict, depth: int = 0) -> Iterator[tuple[str, dict | None]]:
    _require(depth <= MAX_ARCHIVE_DEPTH, "Migration archive nesting exceeds the backup budget")
    # Versions 1/2 refer to loose editor files; claiming a self-contained export
    # for them would silently omit those designs. Use the existing migration.
    _version(snapshot.get("schema"), range(3, 10), "save (requires a self-contained save 3–9)")
    state = snapshot.get("game_state")
    _require(isinstance(state, dict), "Missing game_state")
    _version(state.get("schema", 1), range(1, 5), "game state")
    campaign = state.get("campaign")
    _require(isinstance(campaign, dict), "Missing campaign")
    _version(campaign.get("schema"), range(1, 4), "campaign")
    bodies = campaign.get("bodies")
    _require(isinstance(bodies, dict), "Missing body register")
    for body in bodies.values():
        _require(isinstance(body, dict), "Invalid body record")
        for field in ("exploration_atlas", "legacy_exploration_atlas"):
            if field in body:
                atlas = body[field]
                root = _atlas_root(atlas, body.get("id"))
                if root:
                    yield root, atlas
        if "surface_population" not in body:
            continue
        population = body["surface_population"]
        _require(isinstance(population, dict), "Invalid surface population")
        _version(population.get("schema"), (1, 2), "surface population")
        _require(population.get("body_id") == body.get("id") and isinstance(body.get("id"), str),
                 "Population belongs to a different body")
        if population["schema"] == 1:
            _require(isinstance(population.get("regions"), dict) and "storage" not in population,
                     "Inline population has inconsistent storage")
            continue
        root = _storage_root(population.get("storage"))
        if root:
            yield root, None
    archive = campaign.get("surface_migration", {})
    _require(isinstance(archive, dict), "Invalid migration archive")
    if archive:
        _version(archive.get("schema"), (1,), "migration archive")
        _require(archive.get("algorithm") in ("early_campaign_copy_v1", "campaign_places_copy_v2"),
                 "Unsupported migration archive algorithm")
        text = archive.get("source_text")
        _require(isinstance(text, str), "Missing migration source text")
        raw = text.encode("utf-8")
        _require(len(raw) <= MAX_ARCHIVE_BYTES, "Migration source exceeds its byte budget")
        _require(_digest(raw) == archive.get("source_sha256"), "Migration source checksum mismatch")
        yield from _roots(_object(raw), depth + 1)


def _blob_path(directory: Path, digest: str) -> Path:
    _require(isinstance(digest, str) and HASH.fullmatch(digest), "Invalid blob reference")
    shard = directory / digest[:2]
    _require(not shard.is_symlink(), f"Symbolic link in region directory: {shard}")
    return shard / (digest + ".json")


def _walk(directory: Path, root: str, stats: Stats, atlas: dict | None = None) -> Iterator[tuple[str, bytes]]:
    # Depth-first traversal retains at most 15 siblings per trie level plus
    # one leaf's 32 values. No world-sized visited set or region cache.
    pending = [(root, "", None)]
    while pending:
        stats.peak_pending = max(stats.peak_pending, len(pending))
        digest, prefix, key = pending.pop()
        raw = _read(_blob_path(directory, digest), MAX_BLOB_BYTES)
        _require(_digest(raw) == digest, f"Region checksum mismatch: {digest}")
        value = _object(raw)
        _version(value.get("schema"), (1,), "region blob")
        if key is not None:
            _require(value.get("key") == key and isinstance(value.get("value"), dict),
                     f"Region payload belongs to a different index key: {key}")
            if atlas is not None:
                _atlas_key(key, atlas)
                tile = value["value"]
                _version(tile.get("schema"), (1,), "atlas tile")
                _require(set(tile) == {"schema", "body_id", "mode", "divisions", "rows"},
                         "Unsupported atlas tile fields")
                _require(type(tile.get("divisions")) in (int, float) and
                         all(tile.get(field) == atlas[field] for field in ("body_id", "mode", "divisions")),
                         "Atlas tile belongs to a different body or projection")
                _atlas_rows(tile.get("rows"))
        else:
            kind = value.get("kind")
            _require(kind in ("branch", "leaf"), "Unknown trie page kind")
            entries = value.get("children" if kind == "branch" else "entries")
            _require(isinstance(entries, dict) and len(entries) <= (16 if kind == "branch" else 32),
                     "Trie page exceeds its entry budget")
            _require(bool(entries) or (kind == "leaf" and not prefix), "Empty non-root trie page")
            if kind == "branch":
                _require(len(prefix) < 64, "Trie exceeds SHA-256 depth")
            for name, child in entries.items():
                _require(isinstance(child, str) and HASH.fullmatch(child), "Invalid child hash")
                if kind == "branch":
                    _require(len(name) == 1 and name in "0123456789abcdef", "Invalid trie branch digit")
                    pending.append((child, prefix + name, None))
                else:
                    _require(0 < len(name) <= 400 and _digest(name.encode()).startswith(prefix),
                             "Index key is outside its trie branch")
                    pending.append((child, prefix, name))
        stats.verified_blobs += 1
        stats.peak_blob_bytes = max(stats.peak_blob_bytes, len(raw))
        yield digest, raw


def _save_sources(slots: list[Path]) -> list[tuple[Path, str]]:
    result = []
    names = set()
    for slot in slots:
        slot = slot.absolute()
        _require(slot.name == "voxelverse_save.json" or
                 (slot.name.startswith("slot_") and slot.name.endswith(".json")), "Expected a Voxelverse slot filename")
        relative = slot.name if slot.name == "voxelverse_save.json" else "saves/" + slot.name
        candidates = [(slot, relative), (Path(str(slot) + ".bak"), relative + ".bak")]
        history = Path(str(slot) + ".history")
        _require(not history.is_symlink(), "History directory must not be a symbolic link")
        if history.is_dir():
            for path in history.iterdir():
                if path.name.startswith("snapshot_") and path.name.endswith(".json"):
                    _require(len(candidates) < MAX_SNAPSHOTS, "Too many history snapshots")
                    candidates.append((path, relative + ".history/" + path.name))
        present = 0
        for path, target in sorted(candidates):
            if not path.exists() and not path.is_symlink():
                continue
            _require(target not in names, "Duplicate slot filename in backup: " + target)
            _require(len(result) < MAX_SNAPSHOTS, "Too many snapshots in backup")
            names.add(target)
            result.append((path, target))
            present += 1
        _require(present > 0, f"Slot, backup and history are all missing: {slot}")
    _require(bool(result), "Select at least one slot")
    return result


def _write_new(path: Path, raw: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(raw)
        stream.flush()
        os.fsync(stream.fileno())
    _require(_read(path, max(MAX_SAVE_BYTES, len(raw))) == raw, "Written file failed verification")


def export_bundle(slots: list[Path], regions: Path, output: Path) -> dict:
    sources = _save_sources(slots)
    output = output.absolute()
    _require(not output.exists() and not output.is_symlink(), "Backup destination already exists")
    # Keep newly created files outside both the immutable blob tree and the
    # source project's code, even when the caller accidentally selects them.
    source_root = regions.resolve()
    project_root = Path(__file__).resolve().parents[1]
    target = output.resolve()
    _require(not target.is_relative_to(source_root) and not target.is_relative_to(project_root),
             "Backup output must be outside the source project and region store")
    output.parent.mkdir(parents=True, exist_ok=True)
    lock = output.with_name("." + output.name + ".region-backup-lock")
    # Exclusive reservation prevents two cooperating exports replacing each
    # other's destination. Existing destinations are never updated in place.
    with lock.open("xb"):
        pass
    staging = None
    try:
        staging = Path(tempfile.mkdtemp(prefix="." + output.name + ".partial-", dir=output.parent))
        stats = Stats()
        snapshots = []
        for source, relative in sources:
            raw = _read(source, MAX_SAVE_BYTES)
            snapshot = _object(raw)
            _write_new(staging / relative, raw)
            snapshots.append({"path": relative, "sha256": _digest(raw)})
            stats.snapshots += 1
            for root, atlas in _roots(snapshot):
                stats.roots += 1
                for digest, blob in _walk(source_root, root, stats, atlas):
                    destination = _blob_path(staging / "regions/blobs", digest)
                    if destination.exists():
                        _require(_read(destination, MAX_BLOB_BYTES) == blob, "Conflicting destination blob")
                    else:
                        _write_new(destination, blob)
                        stats.copied_blobs += 1
                        stats.copied_bytes += len(blob)
        manifest = {"schema": 1, "format": FORMAT, "snapshots": snapshots, "stats": asdict(stats)}
        _write_new(staging / RECORD, (json.dumps(manifest, indent=2) + "\n").encode())
        # Read the destination, not the source, before publishing it as a
        # complete user-data directory. Snapshot JSON bytes are never migrated.
        verify_bundle(staging)
        _require(not output.exists() and not output.is_symlink(), "Destination appeared during export")
        staging.rename(output)
        staging = None
        return asdict(stats)
    finally:
        if staging is not None:
            shutil.rmtree(staging)
        lock.unlink()


def verify_bundle(directory: Path) -> dict:
    directory = directory.resolve()
    manifest = _object(_read(directory / RECORD, MAX_SAVE_BYTES))
    _version(manifest.get("schema"), (1,), "backup")
    _require(manifest.get("format") == FORMAT, "Unsupported backup format")
    snapshots = manifest.get("snapshots")
    _require(isinstance(snapshots, list) and 0 < len(snapshots) <= MAX_SNAPSHOTS, "Invalid snapshot list")
    seen = set()
    stats = Stats()
    for entry in snapshots:
        _require(isinstance(entry, dict), "Invalid snapshot entry")
        relative = entry.get("path")
        _require(isinstance(relative, str) and "\\" not in relative and ":" not in relative,
                 "Invalid snapshot path")
        path = PurePosixPath(relative)
        _require(not path.is_absolute() and all(p not in (".", "..") for p in path.parts)
                 and str(path) == relative and len(path.parts) <= 3
                 and (relative.startswith("saves/slot_") or relative.startswith("voxelverse_save.json")),
                 "Snapshot path escapes the slot directory")
        _require(relative not in seen, "Duplicate snapshot in manifest")
        seen.add(relative)
        source = directory / relative
        _require(all(not parent.is_symlink() for parent in source.parents if parent != directory and parent.is_relative_to(directory)),
                 "Symbolic link in backup slot path")
        raw = _read(source, MAX_SAVE_BYTES)
        _require(_digest(raw) == entry.get("sha256"), "Snapshot checksum mismatch")
        stats.snapshots += 1
        _require(not (directory / "regions").is_symlink() and not (directory / "regions/blobs").is_symlink(),
                 "Symbolic link in backup regions")
        for root, atlas in _roots(_object(raw)):
            stats.roots += 1
            for _ in _walk(directory / "regions/blobs", root, stats, atlas):
                pass
    return asdict(stats)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    export = commands.add_parser("export", help="Copy slots, histories and complete region closures")
    export.add_argument("--slot", type=Path, action="append", required=True)
    export.add_argument("--regions-dir", type=Path, required=True)
    export.add_argument("--output", type=Path, required=True)
    verify = commands.add_parser("verify", help="Read-only verification of a completed backup")
    verify.add_argument("directory", type=Path)
    args = parser.parse_args(argv)
    try:
        result = (export_bundle(args.slot, args.regions_dir, args.output) if args.command == "export"
                  else verify_bundle(args.directory))
    except (BackupError, OSError, UnicodeError, RecursionError) as error:
        parser.exit(2, f"Region backup failed: {error}\n")
    print(json.dumps({"ok": True, **result}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
