"""Atlas-3 backup closure, reciprocal indexes, overlays and native restart."""
from pathlib import Path
from unittest.mock import patch
import copy
import json
import os
import subprocess
import tempfile
import unittest

import region_backup_test as previous
from tools import region_backup as backup
from tools.validation_support import isolated_env, validation_editor

PROJECT = Path(__file__).resolve().parents[2]


class PlaceBackupTest(unittest.TestCase):
    def setUp(self):
        self.files = previous.RegionBackupTest()
        self.files.setUp()
        self.addCleanup(self.files.doCleanups)
        for name in ("root", "slot", "output", "regions", "blob", "index", "save", "atlas_snapshot"):
            setattr(self, name, getattr(self.files, name))

    def place(self, identity, name="Original", body_id="body:test"):
        return {"id": identity, "name": name, "kind": "home", "own": True,
            "species_id": "kept-species", "object_id": "kept-object",
            "address": {"body_id": body_id, "mode": "legacy_plane_v9", "position": [-32, 0, 15]}}

    def register(self, count=130, body_id="body:test", name="Original"):
        atlas, _ = self.files.atlas(count=3, body_id=body_id)
        values = {}
        for ordinal in range(count):
            identity = "known:" + str(ordinal)
            values["p:" + identity] = {"schema": 1, "body_id": body_id, "ordinal": ordinal,
                "place": self.place(identity, name, body_id)}
            values["o:" + str(ordinal)] = {"schema": 1, "body_id": body_id, "id": identity}
        atlas.update(schema=3, place_count=count, places={}, place_ordinals={},
                     place_storage={"schema": 1, "format": backup.STORE_FORMAT, "root": ""})
        self.publish_values(atlas, values)
        return atlas, values

    def publish_values(self, atlas, values):
        entries = {key: self.blob({"schema": 1, "key": key, "value": value}) for key, value in values.items()}
        atlas["place_storage"]["root"] = self.index(entries) if entries else ""
        return entries

    def export(self, atlas):
        self.save(self.atlas_snapshot(atlas))
        return backup.export_bundle([self.slot], self.regions, self.output)

    def test_all_roots_history_copy_archive_and_pending_keep_exact_snapshots(self):
        old, _ = self.register()
        current, values = self.register(name="Updated")
        current["places"] = {"known:0": self.place("known:0", "Pending override"),
                             "new:130": self.place("new:130", "New place")}
        current["place_ordinals"] = {"known:0": 0, "new:130": 130}
        current["place_count"] = 131
        archived, _ = self.register(count=2, name="Archived")
        snapshot = self.atlas_snapshot(current)
        campaign = snapshot["game_state"]["campaign"]
        campaign["bodies"]["body:test"]["legacy_exploration_atlas"] = archived
        source_text = json.dumps(self.atlas_snapshot(old))
        campaign["surface_migration"] = {"schema": 1, "algorithm": "campaign_places_copy_v2",
            "source_text": source_text, "source_sha256": backup._digest(source_text.encode())}
        self.save(snapshot)
        self.save(self.atlas_snapshot(old), Path(str(self.slot) + ".bak"))
        self.save(self.atlas_snapshot(old), Path(str(self.slot) + ".history/snapshot_0001_old.json"))
        copied = self.save(self.atlas_snapshot(old), self.slot.with_name("slot_copy.json"))
        before = self.slot.read_bytes()
        stats = backup.export_bundle([self.slot, copied], self.regions, self.output)
        self.assertEqual(stats["roots"], 12)
        self.assertEqual(stats["place_records"], 652)
        self.assertLessEqual(stats["peak_index_pages"], 128)
        self.assertEqual(backup.verify_bundle(self.output)["place_records"], 652)
        self.assertEqual(self.slot.read_bytes(), before)
        self.assertEqual((self.output / "saves" / self.slot.name).read_bytes(), before)
        # A missing deep ordinal value invalidates an otherwise complete backup.
        digest = self.blob({"schema": 1, "key": "o:129", "value": values["o:129"]})
        backup._blob_path(self.output / "regions/blobs", digest).unlink()
        with self.assertRaises(OSError): backup.verify_bundle(self.output)

    def test_bad_reciprocal_indexes_do_not_publish_even_with_valid_hashes(self):
        atlas, values = self.register(count=3)
        for kind in ("missing_p", "missing_o", "wrong_id", "duplicate_ordinal", "out_of_range",
                     "noncanonical_key", "future_p", "future_o", "foreign_body", "foreign_place",
                     "invalid_address", "unknown_key", "extra_field"):
            with self.subTest(kind=kind):
                candidate, entries = copy.deepcopy(atlas), copy.deepcopy(values)
                if kind == "missing_p": del entries["p:known:1"]
                elif kind == "missing_o": del entries["o:1"]
                elif kind == "wrong_id": entries["o:1"]["id"] = "known:2"
                elif kind == "duplicate_ordinal": entries["p:known:1"]["ordinal"] = 2
                elif kind == "out_of_range": entries["p:known:1"]["ordinal"] = 3
                elif kind == "noncanonical_key": entries["o:01"] = entries.pop("o:1")
                elif kind == "future_p": entries["p:known:1"]["schema"] = 2
                elif kind == "future_o": entries["o:1"]["schema"] = 2
                elif kind == "foreign_body": entries["o:1"]["body_id"] = "other"
                elif kind == "foreign_place": entries["p:known:1"]["place"]["id"] = "known:2"
                elif kind == "invalid_address": entries["p:known:1"]["place"]["address"]["body_id"] = "other"
                elif kind == "unknown_key": entries["x:unknown"] = {"schema": 1, "body_id": "body:test"}
                else: entries["p:known:1"]["other_storage"] = candidate["storage"]
                self.publish_values(candidate, entries)
                self.save(self.atlas_snapshot(candidate))
                before = self.slot.read_bytes()
                with self.assertRaises(backup.BackupError):
                    backup.export_bundle([self.slot], self.regions, self.output)
                self.assertEqual(self.slot.read_bytes(), before)
                self.assertFalse(self.output.exists())

    def test_pending_overrides_cannot_hide_corruption_or_reassign_positions(self):
        atlas, values = self.register(count=3)
        for identity, ordinal in (("known:0", 1), ("new", 0)):
            candidate = copy.deepcopy(atlas)
            candidate.update(places={identity: self.place(identity)}, place_ordinals={identity: ordinal})
            with self.assertRaisesRegex(backup.BackupError, "Pending place"):
                self.export(candidate)
        # A pending update must not conceal the missing half of a committed pair.
        atlas.update(places={"known:0": self.place("known:0")}, place_ordinals={"known:0": 0})
        del values["p:known:0"]
        self.publish_values(atlas, values)
        with self.assertRaisesRegex(backup.BackupError, "reciprocal"):
            self.export(atlas)

    def test_count_coverage_empty_roots_and_pending_only_register(self):
        atlas, values = self.register(count=3)
        for count in (2, 4, backup.MAX_PLACE_COUNT):
            candidate = copy.deepcopy(atlas)
            candidate["place_count"] = count
            with self.assertRaises(backup.BackupError): self.export(candidate)
        # A hole is invalid even if every remaining pair is internally consistent.
        del values["p:known:1"], values["o:1"]
        self.publish_values(atlas, values)
        with self.assertRaisesRegex(backup.BackupError, "count"):
            self.export(atlas)
        for count in (0, 2):
            candidate, _ = self.register(count=0)
            candidate["place_count"] = count
            candidate["places"] = {f"new:{i}": self.place(f"new:{i}") for i in range(count)}
            candidate["place_ordinals"] = {f"new:{i}": i for i in range(count)}
            self.output = self.root / f"empty-{count}"
            self.assertEqual(self.export(candidate)["place_records"], 0)
            self.assertEqual(backup.verify_bundle(self.output)["roots"], 1) # Existing tile root.

    def test_future_headers_bad_overlays_and_wrong_types_are_rejected_in_archives(self):
        atlas, _ = self.register(count=1)
        for change in ({"schema": 4}, {"place_count": False}, {"place_count": 1.5},
                       {"place_count": backup.MAX_PLACE_COUNT + 1}, {"place_ordinals": {"extra": 0}},
                       {"places": {"a": self.place("a")}, "place_ordinals": {"a": True}},
                       {"places": {"a": self.place("a"), "b": self.place("b")}, "place_ordinals": {"a": 0, "b": 0}},
                       {"place_storage": {**atlas["place_storage"], "schema": 2}},
                       {"place_storage": {**atlas["place_storage"], "format": "future"}},
                       {"places": {str(i): self.place(str(i)) for i in range(97)}},
                       {"next_place_storage": atlas["place_storage"]}):
            with self.subTest(change=change):
                snapshot = self.files.snapshot("")
                text = json.dumps(self.atlas_snapshot({**atlas, **change}))
                snapshot["game_state"]["campaign"]["surface_migration"] = {
                    "schema": 1, "algorithm": "campaign_places_copy_v2", "source_text": text,
                    "source_sha256": backup._digest(text.encode())}
                self.save(snapshot)
                with self.assertRaises(backup.BackupError):
                    backup.export_bundle([self.slot], self.regions, self.output)
                self.assertFalse(self.output.exists())

    def test_failed_copy_and_advancing_source_preserve_the_captured_pair_of_roots(self):
        old, _ = self.register(count=3)
        newer, _ = self.register(count=4, name="New")
        self.save(self.atlas_snapshot(old))
        before = self.slot.read_bytes()
        original_write = backup._write_new

        def advance(path, raw):
            original_write(path, raw)
            if path.name == self.slot.name: self.save(self.atlas_snapshot(newer))

        with patch.object(backup, "_write_new", side_effect=advance):
            stats = backup.export_bundle([self.slot], self.regions, self.output)
        self.assertEqual(stats["place_records"], 3)
        self.assertEqual((self.output / "saves" / self.slot.name).read_bytes(), before)
        self.assertNotEqual(self.slot.read_bytes(), before)
        record = (self.output / backup.RECORD).read_bytes()

        def fail(path, raw):
            if "regions" in path.parts: raise OSError("injected disk full")
            original_write(path, raw)

        with patch.object(backup, "_write_new", side_effect=fail):
            with self.assertRaises(OSError):
                backup.export_bundle([self.slot], self.regions, self.root / "failed")
        self.assertFalse((self.root / "failed").exists())
        self.assertEqual((self.output / backup.RECORD).read_bytes(), record)


@unittest.skipUnless(os.environ.get("GODOT_BINARY") and os.environ.get("PLACE_BACKUP_PROJECT"),
                    "Set GODOT_BINARY and PLACE_BACKUP_PROJECT (published PR #65 checkout)")
class GodotPlaceBackupTest(unittest.TestCase):
    def test_native_place_pages_and_identites_restore_from_exported_files_only(self):
        project = Path(os.environ["PLACE_BACKUP_PROJECT"]).resolve()
        with tempfile.TemporaryDirectory(prefix="arch13-places-native-") as temporary, \
                validation_editor(os.environ["GODOT_BINARY"]) as editor:
            base = Path(temporary)

            def run(mode, env):
                result = subprocess.run([str(editor), "--headless", "--path", str(project), "--script",
                    str(PROJECT / "tools/place_backup_probe.gd"), "--", mode], env=env,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
                self.assertEqual(result.returncode, 0, result.stdout[-6000:])
                self.assertNotIn("SCRIPT ERROR", result.stdout)
                self.assertNotIn("ERROR:", result.stdout)
                rows = [json.loads(line[len("PLACE_BACKUP_PROBE "):]) for line in result.stdout.splitlines()
                        if line.startswith("PLACE_BACKUP_PROBE ")]
                self.assertTrue(rows, result.stdout)
                self.assertTrue(rows[-1]["passed"], result.stdout)
                return rows[-1]

            created = run("create", isolated_env(base / "source"))
            self.assertEqual(created["place_count"], 3106)
            self.assertEqual(created["pending"], 2)
            restored_env = isolated_env(base / "restored")
            destination = Path(restored_env["XDG_DATA_HOME"]) / "godot/app_userdata/Voxelverse"
            stats = backup.export_bundle([Path(created["slot"])], Path(created["regions"]), destination)
            self.assertGreaterEqual(stats["place_records"], 2 * 3105)
            self.assertLessEqual(stats["peak_index_pages"], 128)
            self.assertEqual(backup.verify_bundle(destination)["place_records"], stats["place_records"])
            Path(created["regions"]).rename(base / "source-blobs-unavailable")
            restored = run("verify", restored_env)
            self.assertEqual(restored["checked_places"], 3105 * restored["place_snapshots"] + 1)
            self.assertEqual(restored["checked_legacy_places"], 130 * restored["place_snapshots"])
            self.assertGreaterEqual(restored["place_snapshots"], 2)
            self.assertEqual(restored["peak_page_size"], 64)
            self.assertLessEqual(restored["peak_cache"], 96)
            self.assertLessEqual(restored["peak_pages"], 128)
            self.assertEqual(restored["campaign_id"], created["campaign_id"])
            self.assertEqual(restored["body_id"], created["body_id"])
            print("ARCH13_PLACES_NATIVE_RESULT", json.dumps({"export": stats, "created": created,
                "restart": restored}), flush=True)


if __name__ == "__main__": unittest.main()
