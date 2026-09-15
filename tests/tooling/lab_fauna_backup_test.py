"""Restore the paged living laboratory after removing its original user data."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT))
from tools import region_backup_userdata as full
from tools.validation_support import isolated_env, validation_editor


@unittest.skipUnless(os.environ.get("GODOT_BINARY"), "Set GODOT_BINARY for native laboratory restart")
class LabFaunaBackupTest(unittest.TestCase):
    def test_paged_animals_restore_without_original_directory(self):
        with tempfile.TemporaryDirectory(prefix="arch14-lab-backup-") as temporary, \
                validation_editor(os.environ["GODOT_BINARY"]) as engine:
            base = Path(temporary)
            source_env = isolated_env(base / "source")

            def run(mode, env):
                result = subprocess.run([str(engine), "--headless", "--path", str(PROJECT),
                    "--script", "res://tests/living_fauna_archive_test.gd", "--", mode],
                    env=env, capture_output=True, text=True, timeout=180)
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0, output[-6000:])
                self.assertIn("LIVING_FAUNA_ARCHIVE_PASS", output)
                self.assertNotIn("ERROR:", output)
                return output

            output = run("--create-only", source_env)
            prefix = "LIVING_FAUNA_METRICS "
            metrics = json.loads(next(line[len(prefix):] for line in output.splitlines() if line.startswith(prefix)))
            source = Path(metrics["save"]).parent
            archive = base / "archive"
            stats = full.export_userdata(source, archive)
            self.assertEqual(full.verify_userdata(archive), stats)
            self.assertTrue(any((archive / full.PAYLOAD / "living_fauna/blobs").rglob("*.json")))
            source.rename(base / "original-unavailable")
            restored_env = isolated_env(base / "restored")
            restored = Path(restored_env["XDG_DATA_HOME"]) / "godot/app_userdata/Voxelverse"
            shutil.copytree(archive / full.PAYLOAD, restored)
            run("--verify-only", restored_env)
            print("ARCH14_LAB_BACKUP_RESULT", json.dumps({"archive": stats, "history": metrics["history"],
                  "active": metrics["active"], "peak_cache": metrics["peak_cache"]}), flush=True)


if __name__ == "__main__":
    unittest.main()
