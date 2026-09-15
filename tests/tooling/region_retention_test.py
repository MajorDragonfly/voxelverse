"""Global root owners, exact generations, retain-only policy and failure paths."""
from pathlib import Path
import copy
import json
import os
import shutil
import subprocess
import sys
import unittest
from unittest.mock import patch

import region_backup_test as previous
import region_backup_places_test as places
from tools import region_backup as backup
from tools import region_retention as retention


class RegionRetentionTest(unittest.TestCase):
    def setUp(self):
        self.fixture = previous.RegionBackupTest()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.source = self.fixture.root / "source"
        self.source.mkdir()
        self.output = self.fixture.root / "plan"

    def plan(self):
        return retention.plan_retention(self.source, self.output)

    def rows(self, name):
        return [json.loads(line) for line in (self.output / name).read_text().splitlines()]

    def test_all_owners_generations_shared_blobs_migration_and_orphans(self):
        f = self.fixture
        current, _ = f.tree(count=130, stock=8)
        old, _ = f.tree(count=130, stock=7)
        archived, _ = f.tree(count=4, stock=19)
        lab, _ = f.atlas()
        state = f.snapshot(current)
        original = json.dumps(f.snapshot(archived))
        state["game_state"]["campaign"]["surface_migration"] = {"schema": 1,
            "algorithm": "campaign_places_copy_v2", "source_text": original,
            "source_sha256": backup._digest(original.encode())}
        f.save(state)
        f.save(f.snapshot(old), Path(str(f.slot) + ".bak"))
        f.save(f.snapshot(old), Path(str(f.slot) + ".history/snapshot_001.json"))
        f.save(f.snapshot(old), f.slot.with_name("slot_copy.json"))
        f.save({"legacy_save_text": original, "design_files": {}}, Path(str(f.slot) + ".schema9.backup.json"))
        f.save(f.snapshot(old), self.source / "d3-village-lab/campaign.json")
        f.save({"schema": 3, "map_atlases": {"body:test": lab}}, self.source / "planet_lab_m1.json.bak")
        # A valid interrupted writer is protected too, without being treated as
        # the active save. A completed plan never changes active game pointers.
        f.save(f.snapshot(archived), Path(str(f.slot) + ".tmp"))
        orphan = f.blob({"schema": 1, "key": "orphan", "value": {"stock": 6}})
        (self.source / "unknown.bin").write_bytes(b"\x00\xfffuture")
        originals = {p: p.read_bytes() for p in self.source.rglob("*") if p.is_file()}
        record = self.plan()
        self.assertEqual(retention.verify_retention(self.source, self.output), record)
        self.assertFalse(record["deletion_allowed"])
        self.assertEqual(record["stats"]["roots"], 9)
        self.assertEqual(record["stats"]["not_referenced_by_known_roots"], 1)
        self.assertGreater(record["stats"]["reachable_blobs"], 390)
        self.assertEqual(record["stats"]["opaque_owners"], 1)
        self.assertTrue(all(row["action"] == "retain" for row in self.rows("blobs.jsonl")))
        self.assertEqual([row["sha256"] for row in self.rows("blobs.jsonl")
                          if not row["referenced_by_known_roots"]], [orphan])
        roots = self.rows("roots.jsonl")
        self.assertTrue(any("legacy_save_text/@json" in row["location"] for row in roots))
        self.assertTrue(any(row["contract"] == "atlas_tiles" for row in roots))
        for path, raw in originals.items():
            self.assertEqual(path.read_bytes(), raw)
        # No clocks/absolute paths in generation identity: copying the same bytes
        # yields the same record and a different generation after any change.
        restored = self.fixture.root / "restored"
        shutil.copytree(self.source, restored)
        other = self.fixture.root / "other-plan"
        self.assertEqual(retention.plan_retention(restored, other), record)
        (restored / "unknown.bin").write_bytes(b"changed")
        with self.assertRaises(backup.BackupError):
            retention.verify_retention(restored, other)
        newer = retention.plan_retention(restored, self.fixture.root / "new-plan")
        self.assertNotEqual(newer["stats"]["source_generation"], record["stats"]["source_generation"])

    def test_place_roots_preserve_overlays_and_reject_broken_reciprocal_index(self):
        fixture = places.PlaceBackupTest()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        atlas, values = fixture.register(count=130)
        fixture.save(fixture.atlas_snapshot(atlas))
        source = fixture.root / "source"
        record = retention.plan_retention(source, fixture.output)
        self.assertEqual(record["stats"]["roots"], 2)  # Both atlas roots, no population.
        self.assertEqual(retention.verify_retention(source, fixture.output), record)
        del values["o:129"]
        fixture.publish_values(atlas, values)
        fixture.save(fixture.atlas_snapshot(atlas))
        with self.assertRaisesRegex(backup.BackupError, "reciprocal"):
            retention.plan_retention(source, fixture.root / "bad-plan")
        # Pending-only place indexes must be validated even with an empty root.
        atlas.update(place_storage={"schema": 1, "format": backup.STORE_FORMAT, "root": ""},
                     place_count=1, places={}, place_ordinals={})
        fixture.save(fixture.atlas_snapshot(atlas))
        with self.assertRaisesRegex(backup.BackupError, "count"):
            retention.plan_retention(source, fixture.root / "empty-bad-plan")

    def test_missing_corrupt_and_future_data_cannot_publish_complete_generation(self):
        f = self.fixture
        root, entries = f.tree(count=4)
        state = f.snapshot(root)
        f.save(state)
        blob = backup._blob_path(f.regions, next(iter(entries.values())))
        original_blob = blob.read_bytes()
        for damage in ("missing", "corrupt", "save_future", "store_future", "bad_json", "bad_migration"):
            with self.subTest(damage=damage):
                value = copy.deepcopy(state)
                blob.write_bytes(original_blob)
                if damage == "missing": blob.unlink()
                elif damage == "corrupt": blob.write_bytes(b"corrupt")
                elif damage == "save_future": value["schema"] = 999
                elif damage == "store_future": value["game_state"]["campaign"]["bodies"]["body:test"]["surface_population"]["storage"]["schema"] = 999
                elif damage == "bad_migration": value = {"legacy_save_text": "broken", "design_files": {}}
                f.save(value)
                if damage == "bad_json": f.slot.write_bytes(b"broken")
                # A healthy backup cannot hide the bad primary.
                f.save(state, Path(str(f.slot) + ".bak"))
                before = f.slot.read_bytes()
                with self.assertRaises((backup.BackupError, OSError)):
                    self.plan()
                self.assertFalse(self.output.exists())
                self.assertEqual(f.slot.read_bytes(), before)
                self.assertEqual(list(f.root.glob(".plan.*")), [])

    def test_discovery_is_not_limited_to_slot_names_or_known_fields(self):
        root, _ = self.fixture.tree(count=2)
        self.fixture.save({"new_feature": {"nested": [{"schema": 1, "format": backup.STORE_FORMAT, "root": root}]}},
                          self.source / "custom/name.data")
        record = self.plan()
        self.assertEqual(record["stats"]["roots"], 1)
        self.assertEqual(record["stats"]["not_referenced_by_known_roots"], 0)
        self.assertEqual(self.rows("roots.jsonl")[0]["location"], "$/new_feature/nested/0")

    def test_changed_added_removed_source_prevents_publication(self):
        self.fixture.save(self.fixture.snapshot(""))
        match = retention._match_source
        for change in ("modify", "add", "remove"):
            with self.subTest(change=change):
                def mutate(source, directory, record):
                    if change == "modify": self.fixture.slot.write_bytes(b"modified")
                    elif change == "add": (source / "new-file").write_bytes(b"new")
                    else: self.fixture.slot.unlink()
                    return match(source, directory, record)
                with patch.object(retention, "_match_source", side_effect=mutate):
                    with self.assertRaises((backup.BackupError, OSError)):
                        self.plan()
                self.assertFalse(self.output.exists())
                self.fixture.save(self.fixture.snapshot(""))

    def test_write_and_publish_failure_leave_source_and_previous_plan_untouched(self):
        self.fixture.save(self.fixture.snapshot(""))
        original = self.fixture.slot.read_bytes()
        with patch.object(backup, "_write_new", side_effect=OSError("disk full")):
            with self.assertRaises(OSError): self.plan()
        self.assertFalse(self.output.exists())
        with patch.object(Path, "rename", side_effect=OSError("publication failed")):
            with self.assertRaises(OSError): self.plan()
        self.assertFalse(self.output.exists())
        record = self.plan()
        with self.assertRaises(backup.BackupError): self.plan()
        self.assertEqual(retention.verify_retention(self.source, self.output), record)
        self.assertEqual(self.fixture.slot.read_bytes(), original)

    def test_tampered_report_even_with_recomputed_checksums_is_rejected(self):
        root, _ = self.fixture.tree(count=2)
        self.fixture.save(self.fixture.snapshot(root))
        self.plan()
        path = self.output / "blobs.jsonl"
        raw = path.read_bytes()
        path.write_bytes(raw.replace(b'"referenced_by_known_roots":true', b'"referenced_by_known_roots":false'))
        with self.assertRaisesRegex(backup.BackupError, "checksum"):
            retention.verify_retention(self.source, self.output)
        record = json.loads((self.output / retention.RECORD).read_bytes())
        record["reports"]["blobs.jsonl"] = retention.userdata._file_record(path, "blobs.jsonl")
        (self.output / retention.RECORD).write_bytes(retention.userdata._line(record))
        with self.assertRaisesRegex(backup.BackupError, "differs"):
            retention.verify_retention(self.source, self.output)

    def test_links_special_files_and_nested_or_concurrent_targets_fail(self):
        self.fixture.save(self.fixture.snapshot(""))
        outside = self.fixture.root / "outside"
        outside.write_bytes(b"untouched")
        path = self.source / "unsafe"
        for kind in ("file", "directory", "fifo"):
            if kind == "file": path.symlink_to(outside)
            elif kind == "directory": path.symlink_to(self.fixture.root, target_is_directory=True)
            else: os.mkfifo(path)
            with self.assertRaises(backup.BackupError): self.plan()
            path.unlink()
        for target in (self.source / "plan", self.fixture.root, previous.PROJECT / "bad-plan"):
            with self.assertRaises(backup.BackupError): retention.plan_retention(self.source, target)
        lock = self.fixture.root / ".plan.region-retention-lock"
        lock.write_bytes(b"other planner")
        with self.assertRaises(OSError): self.plan()
        self.assertEqual(lock.read_bytes(), b"other planner")
        self.assertEqual(outside.read_bytes(), b"untouched")

    def test_root_and_inventory_budgets_abort_without_truncation(self):
        self.fixture.save(self.fixture.snapshot(""))
        with patch.object(retention, "MAX_ROOTS", 0):
            with self.assertRaisesRegex(backup.BackupError, "budget"): self.plan()
        with patch.object(retention.userdata, "MAX_ENTRIES", 1):
            with self.assertRaisesRegex(backup.BackupError, "budget"): self.plan()
        self.assertFalse(self.output.exists())

    def test_empty_generation_and_cli_replay(self):
        command = [sys.executable, str(previous.PROJECT / "tools/region_backup.py")]
        created = subprocess.run(command + ["plan-retention", "--user-data", str(self.source), "--output", str(self.output)],
                                 capture_output=True, text=True)
        self.assertEqual(created.returncode, 0, created.stderr)
        verified = subprocess.run(command + ["verify-retention", str(self.output), "--user-data", str(self.source)],
                                  capture_output=True, text=True)
        self.assertEqual(verified.returncode, 0, verified.stderr)
        self.assertEqual(json.loads(created.stdout), json.loads(verified.stdout))
        self.assertEqual(json.loads(created.stdout)["stats"]["blobs"], 0)


if __name__ == "__main__":
    unittest.main()
