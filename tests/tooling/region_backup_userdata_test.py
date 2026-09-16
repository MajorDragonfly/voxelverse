"""Whole-installation preservation, failure paths and native laboratory restart."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT))
from tools import region_backup_userdata as full
from tools import region_retention as retention
from tools.validation_support import isolated_env, validation_editor


class UserdataBackupTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="arch13-userdata-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / "source"
        self.source.mkdir()
        self.output = self.root / "archive"

    def write(self, path, raw=b'{}'):
        destination = self.source / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(raw)
        return destination

    def fixture(self):
        paths = ["saves/slot_a.json", "saves/slot_b.json.bak", "saves/slot_c.json.history/snapshot_01.json",
                 "saves/slot_a.json.schema1.backup.json", "saves/slot_a.json.deadbeef.migration-backup.json",
                 "voxelverse_save.json", "voxelverse_save.json.bak", "d3-village-lab/campaign.json",
                 "d3-village-lab/campaign.json.history/snapshot_02.json", "d2_lab/snapshot.json",
                 "d2_lab/snapshot.json.bak", "living_planet_v1.json", "planet_lab_m1.json",
                 "surface_adapter_m1d.json", "creature_library.json", "creature_assembly_v7.json",
                 "building_designs/Hütte.json", "galaxy_m1c/manifest.json", "galaxy_m1c/systems/id.json",
                 "galaxy_visits_m1c/galaxy/systems/id.json.bak", "input_preferences.cfg",
                 "regions/blobs/aa/old-unreferenced.json", "new-future-format/data.bin", "saves/interrupted.tmp"]
        for i, path in enumerate(paths): self.write(path, bytes([i]) + b'\x00\xff{"schema":999}')
        (self.source / "empty/directory").mkdir(parents=True)
        return {p.relative_to(self.source).as_posix(): p.read_bytes() for p in self.source.rglob("*") if p.is_file()}

    def test_every_original_and_unknown_file_is_preserved_without_normalizing(self):
        originals = self.fixture()
        stats = full.export_userdata(self.source, self.output)
        self.assertEqual(stats["files"], len(originals))
        self.assertEqual(full.verify_userdata(self.output), stats)
        for relative, raw in originals.items():
            self.assertEqual((self.output / full.PAYLOAD / relative).read_bytes(), raw)
            self.assertEqual((self.source / relative).read_bytes(), raw)
        self.assertTrue((self.output / full.PAYLOAD / "empty/directory").is_dir())
        self.assertEqual(stats["bytes"], sum(map(len, originals.values())))

    def test_empty_directory_and_chunked_large_file(self):
        full.export_userdata(self.source, self.output)
        self.assertEqual(full.verify_userdata(self.output)["files"], 0)
        self.output = self.root / "large"
        raw = bytes(range(256)) * 17000
        self.write("large.bin", raw)
        with patch.object(full, "CHUNK_BYTES", 1024): full.export_userdata(self.source, self.output)
        self.assertEqual((self.output / full.PAYLOAD / "large.bin").read_bytes(), raw)

    def test_source_changes_additions_and_removals_abort_publication(self):
        original_verify = full.verify_userdata
        for mutation in ("rewrite", "add", "remove", "directory"):
            with self.subTest(mutation=mutation):
                self.write("original.json", b"original")
                def change_source(path):
                    result = original_verify(path)
                    if mutation == "rewrite": self.write("original.json", b"modified")
                    elif mutation == "add": self.write("new.json")
                    elif mutation == "remove": (self.source / "original.json").unlink()
                    else: (self.source / "new-directory").mkdir()
                    return result
                with patch.object(full, "verify_userdata", side_effect=change_source):
                    with self.assertRaises((full.BackupError, OSError)):
                        full.export_userdata(self.source, self.output)
                self.assertFalse(self.output.exists())
                self.assertEqual(list(self.root.glob(".archive.*")), [])
                shutil.rmtree(self.source)
                self.source.mkdir()

    def test_corruption_missing_added_files_and_manifest_tampering_fail(self):
        self.write("saves/slot_a.json", b"original")
        full.export_userdata(self.source, self.output)
        for mutation in ("bytes", "missing", "extra", "traversal", "duplicate", "root_extra", "version", "summary"):
            with self.subTest(mutation=mutation):
                target = self.root / mutation
                shutil.copytree(self.output, target)
                path = target / full.PAYLOAD / "saves/slot_a.json"
                if mutation == "bytes": path.write_bytes(b"tampered")
                elif mutation == "missing": path.unlink()
                elif mutation == "extra": path.with_name("unexpected").write_bytes(b"extra")
                elif mutation == "root_extra": (target / "unexpected").write_bytes(b"extra")
                elif mutation in ("traversal", "duplicate"):
                    index = target / full.INDEX
                    raw = index.read_bytes()
                    index.write_bytes(raw.replace(b'saves/slot_a.json', b'../../outside') if mutation == "traversal" else raw + raw)
                else:
                    record = target / full.RECORD
                    value = json.loads(record.read_text())
                    value["schema" if mutation == "version" else "bytes"] = 99
                    record.write_text(json.dumps(value))
                with self.assertRaises((full.BackupError, OSError)): full.verify_userdata(target)

    def test_symlinks_special_files_and_unsafe_names_fail_without_following(self):
        outside = self.root / "outside"
        outside.write_bytes(b"untouched")
        for kind in ("file_link", "directory_link", "fifo", "name"):
            with self.subTest(kind=kind):
                path = self.source / ("unsafe:name" if kind == "name" else "unsafe")
                if kind == "file_link": path.symlink_to(outside)
                elif kind == "directory_link": path.symlink_to(self.root, target_is_directory=True)
                elif kind == "fifo": os.mkfifo(path)
                else: path.write_bytes(b"bytes")
                with self.assertRaises(full.BackupError): full.export_userdata(self.source, self.output)
                self.assertFalse(self.output.exists())
                self.assertEqual(outside.read_bytes(), b"untouched")
                path.unlink()
        self.write("a")
        full.export_userdata(self.source, self.output)
        payload = self.output / full.PAYLOAD
        shutil.rmtree(payload)
        payload.symlink_to(self.source, target_is_directory=True)
        with self.assertRaises(full.BackupError): full.verify_userdata(self.output)

    def test_existing_nested_targets_and_concurrent_export_are_protected(self):
        self.write("original")
        for output in (self.source / "nested", self.root, PROJECT / "invalid-backup"):
            with self.assertRaises(full.BackupError): full.export_userdata(self.source, output)
        lock = self.root / ".archive.region-backup-lock"
        lock.write_bytes(b"other exporter")
        with self.assertRaises(FileExistsError): full.export_userdata(self.source, self.output)
        self.assertEqual(lock.read_bytes(), b"other exporter")
        lock.unlink()
        self.output.mkdir()
        with self.assertRaises(full.BackupError): full.export_userdata(self.source, self.output)

    def test_write_verify_and_rename_failures_leave_sources_and_prior_archive(self):
        self.fixture()
        prior = self.root / "prior"
        full.export_userdata(self.source, prior)
        manifest = (prior / full.RECORD).read_bytes()
        for target in ("_file_record", "verify_userdata", "rename"):
            with self.subTest(target=target):
                failure = (patch.object(Path, "rename", side_effect=OSError("interrupted")) if target == "rename"
                           else patch.object(full, target, side_effect=OSError("interrupted")))
                with failure, self.assertRaises(OSError): full.export_userdata(self.source, self.output)
                self.assertFalse(self.output.exists())
                self.assertEqual((prior / full.RECORD).read_bytes(), manifest)
                full.verify_userdata(prior)
                self.assertEqual(list(self.root.glob(".archive.*")), [])

    def test_explicit_budgets_fail_instead_of_truncating(self):
        self.write("one/two/three")
        self.write("second")
        for constant, maximum in (("MAX_ENTRIES", 1), ("MAX_DEPTH", 0),
                                  ("MAX_DIRECTORY_ENTRIES", 1), ("MAX_LINE_BYTES", 1)):
            with self.subTest(constant=constant), patch.object(full, constant, maximum):
                with self.assertRaises(full.BackupError): full.export_userdata(self.source, self.output)
                self.assertFalse(self.output.exists())

    def test_cli_export_and_verify_report_bytes_separately_from_game_validity(self):
        self.fixture()
        cli = [sys.executable, str(PROJECT / "tools/region_backup.py")]
        result = subprocess.run(cli + ["export-user-data", "--user-data", str(self.source), "--output", str(self.output)],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["ok"])
        result = subprocess.run(cli + ["verify-user-data", str(self.output)], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        (self.output / full.INDEX).write_bytes(b"damaged")
        result = subprocess.run(cli + ["verify-user-data", str(self.output)], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Region backup failed", result.stderr)


@unittest.skipUnless(os.environ.get("GODOT_BINARY"), "Set GODOT_BINARY for native restart")
class NativeUserdataBackupTest(unittest.TestCase):
    def test_campaign_and_independent_labs_restore_without_original_directory(self):
        with tempfile.TemporaryDirectory(prefix="arch13-userdata-native-") as temporary, \
                validation_editor(os.environ["GODOT_BINARY"]) as engine:
            base = Path(temporary)
            source_env = isolated_env(base / "source")
            def run(probe, mode, env):
                result = subprocess.run([str(engine), "--headless", "--path", str(PROJECT), "--script",
                                         "res://tools/" + probe + ".gd", "--", mode], env=env,
                                        capture_output=True, text=True, timeout=120)
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0, output[-7000:])
                self.assertNotIn("ERROR:", output)
                marker = "REGION_BACKUP_PROBE " if probe == "region_backup_probe" else "USERDATA_BACKUP_PROBE "
                rows = [json.loads(line[len(marker):]) for line in result.stdout.splitlines() if line.startswith(marker)]
                self.assertTrue(rows, output)
                self.assertTrue(rows[-1]["passed"], output)
                return rows[-1]
            created = run("region_backup_probe", "create", source_env)
            run("userdata_backup_probe", "create", source_env)
            source = Path(created["regions"]).parents[1]
            plan = base / "retention-plan"
            generation = retention.plan_retention(source, plan)
            self.assertEqual(retention.verify_retention(source, plan), generation)
            self.assertGreater(generation["stats"]["reachable_blobs"], 2400)
            self.assertFalse(generation["deletion_allowed"])
            archive = base / "archive"
            stats = full.export_userdata(source, archive)
            self.assertEqual(full.verify_userdata(archive), stats)
            source.rename(base / "original-unavailable")
            restored_env = isolated_env(base / "restored")
            restored = Path(restored_env["XDG_DATA_HOME"]) / "godot/app_userdata/Voxelverse"
            shutil.copytree(archive / full.PAYLOAD, restored)
            # Identical bytes at another location are the same generation.
            # Recheck before the native reader writes its own logs/settings.
            self.assertEqual(retention.verify_retention(restored, plan), generation)
            region_result = run("region_backup_probe", "verify", restored_env)
            lab_result = run("userdata_backup_probe", "verify", restored_env)
            self.assertEqual(region_result["campaign_id"], created["campaign_id"])
            self.assertGreaterEqual(region_result["checked_regions"], 2400)
            print("ARCH13_USERDATA_NATIVE_RESULT", json.dumps({"archive": stats, "retention": generation["stats"],
                  "regions": region_result, "labs": lab_result}), flush=True)


if __name__ == "__main__":
    unittest.main()
