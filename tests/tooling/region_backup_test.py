"""Region closure, publication failure and actual Godot restart acceptance."""
from pathlib import Path
import hashlib
import copy
import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT))
from tools import region_backup as backup
from tools.validation_support import isolated_env, validation_editor


class RegionBackupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="arch13-backup-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.regions = self.root / "source/regions/blobs"
        self.slot = self.root / "source/saves/slot_test.json"
        self.output = self.root / "backup"

    def blob(self, value):
        raw = json.dumps(value, separators=(",", ":"), sort_keys=True).encode()
        digest = hashlib.sha256(raw).hexdigest()
        path = backup._blob_path(self.regions, digest)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
        return digest

    def tree(self, count=320, stock=7):
        entries = {f"body:test:region:{i}": self.blob({"schema": 1, "key": f"body:test:region:{i}",
                   "value": {"id": i, "stock": stock, "cargo": "milk", "dead": i == 0}}) for i in range(count)}
        return self.index(entries), entries

    def index(self, entries):
        def partition(values, depth=0):
            if len(values) <= 32:
                return self.blob({"schema": 1, "kind": "leaf", "entries": values})
            buckets = {}
            for key, digest in values.items():
                digit = hashlib.sha256(key.encode()).hexdigest()[depth]
                buckets.setdefault(digit, {})[key] = digest
            return self.blob({"schema": 1, "kind": "branch",
                              "children": {k: partition(v, depth + 1) for k, v in buckets.items()}})
        return partition(entries)

    def atlas(self, count=130, bits=2147483648, body_id="body:test"):
        entries = {}
        for i in range(count):
            key = f"-1:{-i}:0"
            entries[key] = self.blob({"schema": 1, "key": key, "value": {
                "schema": 1, "body_id": body_id, "mode": "legacy_plane_v9", "divisions": 0,
                "rows": [bits] + [0] * 31}})
        return {"schema": 2, "body_id": body_id, "mode": "legacy_plane_v9", "radius": 0,
                "divisions": 0, "tiles": {"-1:0:0": [bits | 1] + [0] * 31}, "places": {},
                "extent": [-count * 512, 0, 512, 512], "storage": {
                "schema": 1, "format": backup.STORE_FORMAT, "root": self.index(entries)}}, entries

    def atlas_snapshot(self, atlas, field="exploration_atlas"):
        snapshot = self.snapshot("")
        body = snapshot["game_state"]["campaign"]["bodies"]["body:test"]
        body.pop("surface_population")  # Atlas-only bodies must not be skipped.
        body[field] = atlas
        return snapshot

    def test_atlas_closure_preserves_history_archive_overlay_and_independent_bodies(self):
        old, _ = self.atlas(bits=1)
        current, entries = self.atlas()
        legacy, _ = self.atlas(bits=4)
        other, _ = self.atlas(count=2, body_id="body:other")
        source_text = json.dumps(self.atlas_snapshot(legacy))
        snapshot = self.atlas_snapshot(current)
        campaign = snapshot["game_state"]["campaign"]
        campaign["bodies"]["body:test"]["legacy_exploration_atlas"] = legacy
        campaign["bodies"]["body:other"] = {"id": "body:other", "exploration_atlas": other,
            "surface_population": {"schema": 1, "body_id": "body:other", "regions": {}}}
        campaign["surface_migration"] = {"schema": 1, "algorithm": "campaign_places_copy_v2",
            "source_text": source_text, "source_sha256": backup._digest(source_text.encode())}
        self.save(snapshot)
        self.save(self.atlas_snapshot(old), Path(str(self.slot) + ".bak"))
        self.save(self.atlas_snapshot(old), Path(str(self.slot) + ".history/snapshot_0001_old.json"))
        second = self.save(self.atlas_snapshot(old), self.slot.with_name("slot_copy.json"))
        originals = {p: p.read_bytes() for p in (self.root / "source").rglob("*.json")}
        stats = backup.export_bundle([self.slot, second], self.regions, self.output)
        self.assertEqual(stats["roots"], 7)
        self.assertGreater(stats["copied_blobs"], 390)
        self.assertLess(stats["peak_pending"], 100)
        self.assertEqual(backup.verify_bundle(self.output)["roots"], 7)
        self.assertEqual((self.output / "saves" / self.slot.name).read_bytes(), originals[self.slot])
        self.assertEqual(backup._object((self.output / "saves" / self.slot.name).read_bytes()), snapshot)
        for path, raw in originals.items():
            self.assertEqual(path.read_bytes(), raw)
        # This also rejects pre-extension backups which copied JSON but omitted atlas blobs.
        backup._blob_path(self.output / "regions/blobs", entries["-1:-129:0"]).unlink()
        with self.assertRaises(OSError):
            backup.verify_bundle(self.output)

    def test_atlas_future_versions_fields_and_body_mismatch_protect_all_snapshot_locations(self):
        atlas, _ = self.atlas(count=1)
        changes = ({"schema": 3}, {"schema": True}, {"body_id": "another"},
            {"places_storage": atlas["storage"]}, {"storage": {**atlas["storage"], "schema": 2}},
            {"storage": {**atlas["storage"], "format": "future"}}, {"storage": {}},
            {"schema": 1}, {"tiles": {"-1:0:0": [4294967296] * 32}},
            {"tiles": {"-1:00:0": [1] * 32}}, {"tiles": {"5:0:0": [1] * 32}},
            {"tiles": {f"-1:{i}:0": [1] * 32 for i in range(97)}})
        for location in ("current", "legacy", "archive", "backup", "history"):
            for change in changes:
                with self.subTest(location=location, change=change):
                    candidate = self.atlas_snapshot({**atlas, **change},
                        "legacy_exploration_atlas" if location == "legacy" else "exploration_atlas")
                    path = self.slot
                    if location == "archive":
                        text = json.dumps(candidate)
                        candidate = self.snapshot("")
                        candidate["game_state"]["campaign"]["surface_migration"] = {
                            "schema": 1, "algorithm": "campaign_places_copy_v2", "source_text": text,
                            "source_sha256": backup._digest(text.encode())}
                    elif location in ("backup", "history"):
                        self.save(self.snapshot(""))
                        path = Path(str(self.slot) + (".bak" if location == "backup" else ".history/snapshot_0001_old.json"))
                    self.save(candidate, path)
                    before = path.read_bytes()
                    with self.assertRaises(backup.BackupError):
                        backup.export_bundle([self.slot], self.regions, self.output)
                    self.assertEqual(path.read_bytes(), before)
                    self.assertFalse(self.output.exists())
                    path.unlink()

    def test_atlas_deep_tiles_validate_payload_even_with_valid_hash_or_pending_override(self):
        atlas, entries = self.atlas(count=40)
        key = "-1:0:0"  # Even an overlay cannot hide a broken committed payload.
        tile = backup._object(backup._blob_path(self.regions, entries[key]).read_bytes())["value"]
        for change in ({"schema": 2}, {"body_id": "another"}, {"mode": "cube_sphere_m1_v1"},
                       {"divisions": 8}, {"divisions": False}, {"rows": [False] * 32}, {"rows": [0] * 31},
                       {"rows": [0.5] * 32}, {"next_storage": atlas["storage"]}):
            with self.subTest(change=change):
                damaged = {**entries, key: self.blob({"schema": 1, "key": key, "value": {**tile, **change}})}
                candidate = copy.deepcopy(atlas)
                candidate["storage"]["root"] = self.index(damaged)
                self.save(self.atlas_snapshot(candidate))
                with self.assertRaises(backup.BackupError):
                    backup.export_bundle([self.slot], self.regions, self.output)
                self.assertFalse(self.output.exists())
        for damage in ("missing", "checksum"):
            self.save(self.atlas_snapshot(atlas))
            path = backup._blob_path(self.regions, entries["-1:-39:0"])
            raw = path.read_bytes()
            if damage == "missing": path.unlink()
            else: path.write_bytes(b"corrupted")
            with self.assertRaises((backup.BackupError, OSError)):
                backup.export_bundle([self.slot], self.regions, self.output)
            self.assertFalse(self.output.exists())
            path.write_bytes(raw)

    def test_inline_and_empty_atlas_need_no_blobs_and_preserve_signed_high_bits(self):
        atlas, _ = self.atlas(count=1)
        for schema in (1, 2):
            candidate = copy.deepcopy(atlas)
            candidate["schema"] = schema
            if schema == 1:
                del candidate["storage"], candidate["extent"]
            else:
                candidate["storage"]["root"] = ""
            candidate["tiles"] = {"-1:-1:-1": [4294967295] * 32}
            self.save(self.atlas_snapshot(candidate))
            output = self.output.with_name(f"backup-{schema}")
            self.assertEqual(backup.export_bundle([self.slot], self.root / "no-blobs", output)["roots"], 0)
            self.assertEqual((output / "saves" / self.slot.name).read_bytes(), self.slot.read_bytes())

    def test_atlas_source_can_advance_while_captured_root_remains_complete(self):
        atlas, _ = self.atlas(count=2)
        newer, _ = self.atlas(count=3)
        self.save(self.atlas_snapshot(atlas))
        captured = self.slot.read_bytes()
        original_write = backup._write_new

        def advance(path, raw):
            original_write(path, raw)
            if path.name == self.slot.name:
                self.save(self.atlas_snapshot(newer))

        with patch.object(backup, "_write_new", side_effect=advance):
            backup.export_bundle([self.slot], self.regions, self.output)
        self.assertEqual((self.output / "saves" / self.slot.name).read_bytes(), captured)
        self.assertNotEqual(self.slot.read_bytes(), captured)
        self.assertEqual(backup.verify_bundle(self.output)["roots"], 1)

    def snapshot(self, root):
        return {"schema": 9, "game_state": {"schema": 4, "campaign": {"schema": 3, "id": "campaign:kept",
                "bodies": {"body:test": {"id": "body:test", "seed": 15838,
                "surface_population": {"schema": 2, "body_id": "body:test",
                "storage": {"schema": 1, "format": backup.STORE_FORMAT, "root": root}}}}, "surface_migration": {}}}}

    def save(self, data, path=None):
        path = path or self.slot
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        return path

    def test_complete_history_archive_closure_exceeds_cache_without_copying_orphans(self):
        old, _ = self.tree(stock=7)
        current, entries = self.tree(stock=8)
        archived, _ = self.tree(count=4, stock=19)
        orphan = self.blob({"schema": 1, "key": "orphan", "value": {"secret": "not referenced"}})
        state = self.snapshot(current)
        source_text = json.dumps(self.snapshot(archived))
        state["game_state"]["campaign"]["surface_migration"] = {
            "schema": 1, "algorithm": "campaign_places_copy_v2", "source_text": source_text,
            "source_sha256": hashlib.sha256(source_text.encode()).hexdigest()}
        self.save(state)
        self.save(self.snapshot(old), Path(str(self.slot) + ".bak"))
        self.save(self.snapshot(old), Path(str(self.slot) + ".history/snapshot_0001_old.json"))
        original = {p.relative_to(self.root / "source"): p.read_bytes()
                    for p in (self.root / "source").rglob("*.json")}
        stats = backup.export_bundle([self.slot], self.regions, self.output)
        self.assertEqual(stats["snapshots"], 3)
        self.assertEqual(stats["roots"], 4)
        self.assertGreater(stats["copied_blobs"], 640)
        self.assertLess(stats["peak_pending"], 100)
        self.assertLessEqual(stats["peak_blob_bytes"], backup.MAX_BLOB_BYTES)
        self.assertFalse(backup._blob_path(self.output / "regions/blobs", orphan).exists())
        for relative, raw in original.items():
            self.assertEqual((self.root / "source" / relative).read_bytes(), raw)
            if relative.parts[0] == "saves":
                self.assertEqual((self.output / relative).read_bytes(), raw)
        self.assertEqual(backup.verify_bundle(self.output)["roots"], 4)
        # A missing deeply referenced payload invalidates the destination.
        backup._blob_path(self.output / "regions/blobs", entries["body:test:region:319"]).unlink()
        with self.assertRaises((OSError, backup.BackupError)):
            backup.verify_bundle(self.output)

    def test_missing_or_corrupt_child_never_publishes_and_keeps_sources(self):
        for damage in ("missing", "corrupt"):
            with self.subTest(damage=damage):
                root, entries = self.tree(count=40)
                self.save(self.snapshot(root))
                raw = self.slot.read_bytes()
                path = backup._blob_path(self.regions, next(iter(entries.values())))
                if damage == "missing":
                    path.unlink()
                else:
                    path.write_text("damaged")
                with self.assertRaises((OSError, backup.BackupError)):
                    backup.export_bundle([self.slot], self.regions, self.output)
                self.assertFalse(self.output.exists())
                self.assertEqual(self.slot.read_bytes(), raw)
                self.assertEqual(list(self.root.glob(".backup*")), [])

    def test_interrupted_write_and_publish_keep_previous_backup(self):
        root, _ = self.tree(count=3)
        self.save(self.snapshot(root))
        with patch.object(backup, "_write_new", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                backup.export_bundle([self.slot], self.regions, self.output)
        self.assertFalse(self.output.exists())
        with patch.object(Path, "rename", side_effect=OSError("publish failed")):
            with self.assertRaises(OSError):
                backup.export_bundle([self.slot], self.regions, self.output)
        self.assertFalse(self.output.exists())
        backup.export_bundle([self.slot], self.regions, self.output)
        record = (self.output / backup.RECORD).read_bytes()
        with self.assertRaises(backup.BackupError):
            backup.export_bundle([self.slot], self.regions, self.output)
        self.assertEqual((self.output / backup.RECORD).read_bytes(), record)

    def test_future_manifest_and_nested_blob_are_protected(self):
        root, _ = self.tree(count=1)
        snapshot = self.snapshot(root)
        snapshot["game_state"]["campaign"]["bodies"]["body:test"]["surface_population"]["storage"]["schema"] = 2
        self.save(snapshot)
        before = self.slot.read_bytes()
        with self.assertRaisesRegex(backup.BackupError, "region manifest"):
            backup.export_bundle([self.slot], self.regions, self.output)
        self.assertEqual(self.slot.read_bytes(), before)
        future = self.blob({"schema": 2, "key": "future", "value": {}})
        root = self.blob({"schema": 1, "kind": "leaf", "entries": {"future": future}})
        self.save(self.snapshot(root))
        with self.assertRaisesRegex(backup.BackupError, "region blob"):
            backup.export_bundle([self.slot], self.regions, self.output)
        self.assertFalse(self.output.exists())

    def test_valid_checksums_do_not_hide_wrong_keys_or_branches(self):
        payload = self.blob({"schema": 1, "key": "different", "value": {}})
        root = self.blob({"schema": 1, "kind": "leaf", "entries": {"expected": payload}})
        self.save(self.snapshot(root))
        with self.assertRaisesRegex(backup.BackupError, "different index key"):
            backup.export_bundle([self.slot], self.regions, self.output)
        leaf = self.blob({"schema": 1, "kind": "leaf", "entries": {"different": payload}})
        wrong = "0" if hashlib.sha256(b"different").hexdigest()[0] != "0" else "1"
        root = self.blob({"schema": 1, "kind": "branch", "children": {wrong: leaf}})
        self.save(self.snapshot(root))
        with self.assertRaisesRegex(backup.BackupError, "outside its trie branch"):
            backup.export_bundle([self.slot], self.regions, self.output)

    def test_inline_empty_store_and_backup_only_slot(self):
        data = self.snapshot("")
        self.save(data, Path(str(self.slot) + ".bak"))
        stats = backup.export_bundle([self.slot], self.regions, self.output)
        self.assertEqual(stats["copied_blobs"], 0)
        self.assertEqual(backup.verify_bundle(self.output)["snapshots"], 1)
        self.output = self.root / "inline"
        data["game_state"]["campaign"]["bodies"]["body:test"]["surface_population"] = {
            "schema": 1, "body_id": "body:test", "regions": {"kept": {"stock": 9}}}
        self.save(data)
        self.assertEqual(backup.export_bundle([self.slot], self.regions, self.output)["copied_blobs"], 0)

    def test_multiple_slots_keep_independent_generations_and_duplicate_names_fail(self):
        first, _ = self.tree(count=40, stock=7)
        second, _ = self.tree(count=40, stock=99)
        self.save(self.snapshot(first))
        other = self.save(self.snapshot(second), self.slot.with_name("slot_other.json"))
        stats = backup.export_bundle([self.slot, other], self.regions, self.output)
        self.assertEqual(stats["roots"], 2)
        self.assertEqual((self.output / "saves" / other.name).read_bytes(), other.read_bytes())
        self.assertEqual(backup.verify_bundle(self.output)["snapshots"], 2)
        with self.assertRaisesRegex(backup.BackupError, "Duplicate slot"):
            backup.export_bundle([self.slot, self.slot], self.regions, self.root / "duplicate")

    def test_depth_future_save_and_old_loose_design_versions_fail_explicitly(self):
        root, _ = self.tree(count=1)
        for _ in range(65):
            root = self.blob({"schema": 1, "kind": "branch", "children": {"0": root}})
        self.save(self.snapshot(root))
        with self.assertRaisesRegex(backup.BackupError, "SHA-256 depth"):
            backup.export_bundle([self.slot], self.regions, self.output)
        for schema in [2, 10]:
            data = self.snapshot("")
            data["schema"] = schema
            self.save(data)
            with self.assertRaisesRegex(backup.BackupError, "self-contained save"):
                backup.export_bundle([self.slot], self.regions, self.output)
        self.assertFalse(self.output.exists())

    def test_bounds_bad_json_and_unsafe_paths(self):
        for raw in (b'{"schema":1,"schema":2}', b'{"n":NaN}', b'{"n":1e999}', b'[]'):
            with self.assertRaises(backup.BackupError):
                backup._object(raw)
        root, _ = self.tree(count=1)
        self.save(self.snapshot(root))
        with patch.object(backup, "MAX_BLOB_BYTES", 2):
            with self.assertRaisesRegex(backup.BackupError, "budget"):
                backup.export_bundle([self.slot], self.regions, self.output)
        with self.assertRaises(backup.BackupError):
            backup.export_bundle([self.slot], self.regions, self.regions / "bad")
        backup.export_bundle([self.slot], self.regions, self.output)
        path = self.output / backup.RECORD
        data = json.loads(path.read_text())
        data["snapshots"][0]["path"] = "saves/../../outside.json"
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(backup.BackupError, "escapes"):
            backup.verify_bundle(self.output)

    def test_source_can_change_after_capture_without_mixing_generations(self):
        first, _ = self.tree(count=2, stock=7)
        second, _ = self.tree(count=2, stock=8)
        self.save(self.snapshot(first))
        captured = self.slot.read_bytes()
        original_write = backup._write_new

        def replace_live(path, raw):
            original_write(path, raw)
            if path.name == self.slot.name:
                self.save(self.snapshot(second))

        with patch.object(backup, "_write_new", side_effect=replace_live):
            backup.export_bundle([self.slot], self.regions, self.output)
        self.assertEqual((self.output / "saves" / self.slot.name).read_bytes(), captured)
        self.assertEqual(backup.verify_bundle(self.output)["roots"], 1)

    @unittest.skipUnless(hasattr(os, "symlink"), "Symlinks unavailable")
    def test_symlinked_blob_is_rejected(self):
        root, entries = self.tree(count=1)
        self.save(self.snapshot(root))
        path = backup._blob_path(self.regions, next(iter(entries.values())))
        outside = self.root / "outside"
        path.rename(outside)
        path.symlink_to(outside)
        with self.assertRaisesRegex(backup.BackupError, "Symbolic link"):
            backup.export_bundle([self.slot], self.regions, self.output)


@unittest.skipUnless(os.environ.get("GODOT_BINARY"), "Set GODOT_BINARY for real store/restart acceptance")
class GodotRegionBackupTest(unittest.TestCase):
    def test_real_store_1200_regions_and_save_service_in_fresh_user_directory(self):
        with tempfile.TemporaryDirectory(prefix="arch13-native-") as temporary, \
                validation_editor(os.environ["GODOT_BINARY"]) as editor:
            base = Path(temporary)
            engine = str(editor)

            def run(mode, env):
                result = subprocess.run([engine, "--headless", "--path", str(PROJECT), "--script",
                    "res://tools/region_backup_probe.gd", "--", mode], env=env,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
                self.assertEqual(result.returncode, 0, result.stdout[-6000:])
                self.assertNotIn("SCRIPT ERROR", result.stdout)
                self.assertNotIn("ERROR:", result.stdout)
                rows = [json.loads(line[len("REGION_BACKUP_PROBE "):]) for line in result.stdout.splitlines()
                        if line.startswith("REGION_BACKUP_PROBE ")]
                self.assertTrue(rows, result.stdout)
                return rows[-1]

            created = run("create", isolated_env(base / "source"))
            restored_env = isolated_env(base / "restored")
            destination = Path(restored_env["XDG_DATA_HOME"]) / "godot/app_userdata/Voxelverse"
            exported = subprocess.run([sys.executable, str(PROJECT / "tools/region_backup.py"), "export",
                "--slot", created["slot"], "--regions-dir", created["regions"], "--output", str(destination)],
                capture_output=True, text=True, timeout=120)
            self.assertEqual(exported.returncode, 0, exported.stderr)
            stats = json.loads(exported.stdout)
            verified = subprocess.run([sys.executable, str(PROJECT / "tools/region_backup.py"),
                "verify", str(destination)], capture_output=True, text=True, timeout=120)
            self.assertEqual(verified.returncode, 0, verified.stderr)
            # The original data must be unavailable to the fresh reader.
            Path(created["regions"]).rename(base / "source-blobs-unavailable")
            restored = run("verify", restored_env)
            self.assertGreaterEqual(restored["checked_regions"], 2400)
            self.assertLessEqual(restored["peak_cache"], 96)
            self.assertEqual(restored["campaign_id"], created["campaign_id"])
            self.assertEqual(restored["body_id"], created["body_id"])
            self.assertGreaterEqual(stats["copied_blobs"], 1200)
            print("ARCH13_NATIVE_RESULT", json.dumps({"export": stats, "restart": restored}), flush=True)


@unittest.skipUnless(os.environ.get("GODOT_BINARY") and os.environ.get("ATLAS_BACKUP_PROJECT"),
                     "Set GODOT_BINARY and ATLAS_BACKUP_PROJECT (published ARCH-14 schema-2 project)")
class GodotAtlasBackupTest(unittest.TestCase):
    def test_real_atlas_export_restores_sphere_history_legacy_and_pending_changes(self):
        project = Path(os.environ["ATLAS_BACKUP_PROJECT"]).resolve()
        with tempfile.TemporaryDirectory(prefix="arch13-atlas-native-") as temporary, \
                validation_editor(os.environ["GODOT_BINARY"]) as editor:
            base = Path(temporary)

            def run(mode, env):
                result = subprocess.run([str(editor), "--headless", "--path", str(project), "--script",
                    str(PROJECT / "tools/atlas_backup_probe.gd"), "--", mode], env=env,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
                self.assertEqual(result.returncode, 0, result.stdout[-6000:])
                self.assertNotIn("SCRIPT ERROR", result.stdout)
                self.assertNotIn("ERROR:", result.stdout)
                rows = [json.loads(line[len("ATLAS_BACKUP_PROBE "):]) for line in result.stdout.splitlines()
                        if line.startswith("ATLAS_BACKUP_PROBE ")]
                self.assertTrue(rows, result.stdout)
                self.assertTrue(rows[-1]["passed"], result.stdout)
                return rows[-1]

            created = run("create", isolated_env(base / "source"))
            self.assertGreater(created["pending"], 0)
            self.assertLessEqual(created["pending"], 96)
            restored_env = isolated_env(base / "restored")
            destination = Path(restored_env["XDG_DATA_HOME"]) / "godot/app_userdata/Voxelverse"
            exported = subprocess.run([sys.executable, str(PROJECT / "tools/region_backup.py"), "export",
                "--slot", created["slot"], "--regions-dir", created["regions"], "--output", str(destination)],
                capture_output=True, text=True, timeout=120)
            self.assertEqual(exported.returncode, 0, exported.stderr)
            stats = json.loads(exported.stdout)
            self.assertEqual(backup.verify_bundle(destination)["roots"], stats["roots"])
            Path(created["regions"]).rename(base / "source-blobs-unavailable")
            restored = run("verify", restored_env)
            self.assertEqual(restored["checked_sphere_tiles"], 1200 * restored["atlas_snapshots"])
            self.assertEqual(restored["checked_legacy_tiles"], 130 * restored["atlas_snapshots"])
            self.assertGreaterEqual(restored["atlas_snapshots"], 2)
            self.assertLessEqual(restored["peak_cache"], 96)
            self.assertLessEqual(restored["peak_pages"], 128)
            self.assertEqual(restored["campaign_id"], created["campaign_id"])
            self.assertEqual(restored["body_id"], created["body_id"])
            print("ARCH13_ATLAS_NATIVE_RESULT", json.dumps({"export": stats, "created": created,
                "restart": restored}), flush=True)


if __name__ == "__main__":
    unittest.main()
