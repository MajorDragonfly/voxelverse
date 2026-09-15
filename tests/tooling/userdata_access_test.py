"""Real process leases, publication boundaries, crashes and Godot interop."""
from pathlib import Path
import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT))
from tools import userdata_access as access
from tools import region_retention as retention
from tools import region_backup_userdata as backup
from tools.validation_support import isolated_env, validation_editor


class UserdataAccessTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="arch13-access-")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.source = self.base / "source"
        self.source.mkdir()
        (self.source / "save.json").write_text('{"value":7}')

    def child(self, code, *args):
        process = subprocess.Popen([sys.executable, "-u", "-c", code, str(self.source), *map(str, args)],
                                   cwd=PROJECT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        def cleanup():
            if process.poll() is None:
                process.kill()
            process.wait(timeout=10)
            process.stdout.close()
            process.stderr.close()
        self.addCleanup(cleanup)
        return process

    def writer(self):
        process = self.child('''
from tools.userdata_access import access
from pathlib import Path
import sys
with access(Path(sys.argv[1]), "writer") as owner:
    print(owner["token"], flush=True)
    sys.stdin.read()
'''.replace('sys.stdin.read()', 'import time; time.sleep(30)'))
        token = process.stdout.readline().strip()
        self.assertEqual(len(token), 64, process.stderr.read() if process.poll() is not None else token)
        return process, token

    def test_active_writer_blocks_plan_export_and_replay_without_output(self):
        plan = self.base / "before"
        record = retention.plan_retention(self.source, plan)
        process, token = self.writer()
        for operation in [lambda: retention.plan_retention(self.source, self.base / "plan"),
                          lambda: backup.export_userdata(self.source, self.base / "archive"),
                          lambda: retention.verify_retention(self.source, plan)]:
            with self.assertRaisesRegex(access.BackupError, "in use"): operation()
        self.assertFalse((self.base / "plan").exists())
        self.assertFalse((self.base / "archive").exists())
        self.assertEqual((self.source / "save.json").read_text(), '{"value":7}')
        process.kill(); process.wait(timeout=10)
        self.assertEqual(retention.verify_retention(self.source, plan), record)
        self.assertFalse((access.lock_path(self.source).with_name(access.lock_path(self.source).name + ".writers") / token).exists())

    def test_two_writers_keep_scan_blocked_until_both_exit(self):
        first, _ = self.writer()
        second, _ = self.writer()
        first.kill(); first.wait(timeout=10)
        with self.assertRaisesRegex(access.BackupError, "in use"):
            retention.plan_retention(self.source, self.base / "plan")
        second.kill(); second.wait(timeout=10)
        self.assertFalse(retention.plan_retention(self.source, self.base / "plan")["deletion_allowed"])

    def test_offline_lease_blocks_new_writer_and_another_reader(self):
        with access.access(self.source):
            for role in ("writer", "offline"):
                with self.assertRaisesRegex(access.BackupError, "in use"):
                    with access.access(self.source, role): self.fail("Concurrent admission")
        with access.access(self.source, "writer"):
            pass

    def test_lease_is_held_through_publish_and_source_replay(self):
        original = Path.rename
        attempts = []
        def rename(path, target):
            with self.assertRaises(access.BackupError):
                with access.access(self.source, "writer"): self.fail("Writer entered at publication")
            attempts.append(str(target))
            return original(path, target)
        with patch.object(Path, "rename", rename):
            retention.plan_retention(self.source, self.base / "plan")
            backup.export_userdata(self.source, self.base / "backup")
        self.assertEqual(len(attempts), 2)
        build = retention._build
        def replay(*args):
            with self.assertRaises(access.BackupError):
                with access.access(self.source, "writer"): self.fail("Writer entered during replay")
            return build(*args)
        with patch.object(retention, "_build", replay):
            retention.verify_retention(self.source, self.base / "plan")

    def test_killed_offline_publisher_leaves_no_complete_generation_and_can_restart(self):
        process = self.child('''
from pathlib import Path
from tools import region_retention as retention
import os, sys
def interrupted(path, target):
    os._exit(23)
Path.rename = interrupted
retention.plan_retention(Path(sys.argv[1]), Path(sys.argv[2]))
''', self.base / "interrupted")
        process.communicate(timeout=15)
        self.assertEqual(process.returncode, 23)
        self.assertFalse((self.base / "interrupted").exists())
        self.assertTrue(access.lock_path(self.source).exists())
        self.assertTrue(list(self.base.glob(".interrupted.partial-*")))
        with access.access(self.source, "writer"):
            pass
        record = retention.plan_retention(self.source, self.base / "after-crash")
        self.assertEqual(record, retention.verify_retention(self.source, self.base / "after-crash"))

    def test_incomplete_foreign_future_and_reused_live_pid_remain_protected(self):
        lock = access.lock_path(self.source)
        owner = {"schema": 1, "format": access.FORMAT, "pid": os.getpid(),
                 "host": access.host_id(), "token": "a" * 64, "role": "offline"}
        for variant in ({}, {**owner, "host": "another-machine"}, {**owner, "schema": 999}, owner):
            with self.subTest(owner=variant):
                lock.mkdir()
                path = lock / "owner.json"
                if variant: path.write_text(json.dumps(variant))
                with self.assertRaises(access.BackupError):
                    with access.access(self.source): self.fail("Invalid lease was stolen")
                self.assertTrue(lock.exists())
                if path.exists(): path.unlink()
                lock.rmdir()

    def test_writer_marker_corruption_and_foreign_host_do_not_allow_scan(self):
        with access.access(self.source, "writer") as owner:
            lock = access.lock_path(self.source)
            marker = lock.with_name(lock.name + ".writers") / owner["token"] / "owner.json"
            for data in (b"unfinished", json.dumps({**owner, "host": "other"}).encode()):
                marker.write_bytes(data)
                with self.assertRaises(access.BackupError):
                    retention.plan_retention(self.source, self.base / "plan")
                self.assertEqual(marker.read_bytes(), data)
            marker.write_text(json.dumps(owner))

    def test_owner_write_failure_releases_only_own_gate(self):
        with patch.object(access.os, "fsync", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                with access.access(self.source): self.fail("Unwritten owner admitted")
        self.assertFalse(access.lock_path(self.source).exists())
        self.assertEqual((self.source / "save.json").read_text(), '{"value":7}')


@unittest.skipUnless(os.environ.get("GODOT_BINARY"), "Set GODOT_BINARY for real engine interop")
class NativeUserdataAccessTest(unittest.TestCase):
    def test_runtime_writers_offline_gate_crash_and_both_blob_directories(self):
        with tempfile.TemporaryDirectory(prefix="arch13-access-native-") as temporary, \
                validation_editor(os.environ["GODOT_BINARY"]) as engine:
            base = Path(temporary)
            env = isolated_env(base / "user")
            source = Path(env["XDG_DATA_HOME"]) / "godot/app_userdata/Voxelverse"
            source.mkdir(parents=True)
            command = [str(engine), "--headless", "--path", str(PROJECT), "--log-file", str(base / "engine.log"),
                       "--script", "res://tools/userdata_access_probe.gd", "--"]
            def result(output):
                rows = [json.loads(line.removeprefix("USERDATA_ACCESS_PROBE ")) for line in output.splitlines()
                        if line.startswith("USERDATA_ACCESS_PROBE ")]
                self.assertTrue(rows, output[-5000:])
                self.assertNotIn("SCRIPT ERROR", output)
                self.assertNotIn("ERROR:", output)
                return rows[-1]
            for hard_stop in (False, True):
                stop = base / ("crash-stop" if hard_stop else "stop")
                process = subprocess.Popen(command + ["hold", str(stop)], env=env, stdout=subprocess.PIPE,
                                           stderr=subprocess.PIPE, text=True)
                try:
                    lines = []
                    while True:
                        line = process.stdout.readline()
                        if not line: self.fail("Probe exited: " + "".join(lines) + process.stderr.read())
                        lines.append(line)
                        if line.startswith("USERDATA_ACCESS_PROBE "): break
                    self.assertTrue(result("".join(lines))["prepared"])
                    with self.assertRaisesRegex(access.BackupError, "in use"):
                        retention.plan_retention(source, base / "denied")
                    with self.assertRaisesRegex(access.BackupError, "in use"):
                        backup.export_userdata(source, base / "denied-backup")
                    # A separate reader process remains compatible with the
                    # existing native restart probes; it cannot admit a scan.
                    child = subprocess.run(command + ["acquire"], env=env, capture_output=True, text=True, timeout=30)
                    self.assertEqual(child.returncode, 0, child.stderr)
                    self.assertTrue(result(child.stdout + child.stderr)["acquired"])
                    if hard_stop: process.kill()
                    else: stop.touch()
                    output, errors = process.communicate(timeout=30)
                    if not hard_stop:
                        self.assertEqual(process.returncode, 0, errors)
                        self.assertNotIn("ERROR:", errors)
                finally:
                    if process.poll() is None: process.kill(); process.wait(timeout=10)
                    process.stdout.close(); process.stderr.close()
                registry = access.lock_path(source).with_name(access.lock_path(source).name + ".writers")
                markers = list(registry.iterdir())
                self.assertEqual(len(markers), 1 if hard_stop else 0,
                                 [access.read_owner(marker) for marker in markers])
                for marker in markers:
                    self.assertEqual(access.read_owner(marker)["host"], access.host_id())
                plan = base / ("crashed-plan" if hard_stop else "clean-plan")
                record = retention.plan_retention(source, plan)
                self.assertEqual(record, retention.verify_retention(source, plan))
                self.assertGreater(record["stats"]["not_referenced_by_known_roots"], 0)
                roots = [json.loads(line) for line in (plan / "roots.jsonl").read_text().splitlines()]
                self.assertEqual({r.get("store_directory", "regions/blobs") for r in roots},
                                 {"regions/blobs", "living_fauna/blobs"})
            original = (source / "access_snapshot.json").read_bytes()
            with access.access(source):
                blocked = subprocess.run(command + ["blocked"], env=env, capture_output=True, text=True, timeout=30)
                self.assertEqual(blocked.returncode, 0, blocked.stderr)
                summary = result(blocked.stdout + blocked.stderr)
                self.assertTrue(all(summary[key] for key in summary if key.endswith("_blocked")), summary)
                self.assertEqual((source / "access_snapshot.json").read_bytes(), original)
                self.assertFalse((source / "blocked.json").exists())
            if os.name != "nt":
                actual = base / "relocated-user-data"
                source.rename(actual)
                source.symlink_to(actual, target_is_directory=True)
                with access.access(actual):
                    alias = subprocess.run(command + ["blocked"], env=env, capture_output=True, text=True, timeout=30)
                    self.assertEqual(alias.returncode, 0, alias.stderr)
                    alias_result = result(alias.stdout + alias.stderr)
                    self.assertTrue(all(alias_result[k] for k in alias_result if k.endswith("_blocked")), alias_result)
                self.assertEqual((actual / "access_snapshot.json").read_bytes(), original)
            restart = subprocess.run(command + ["acquire"], env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual(restart.returncode, 0, restart.stderr)
            self.assertTrue(result(restart.stdout + restart.stderr)["acquired"])
            print("ARCH13_ACCESS_NATIVE_RESULT", json.dumps({"passed": True, "blocked": summary,
                  "generation": record["stats"]}), flush=True)


if __name__ == "__main__":
    unittest.main()
