"""Check lock exclusion and child cleanup without starting Godot or a benchmark."""
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

TOOL = Path(__file__).resolve().parents[1] / 'tools/review_r33_02_host_slot.py'
SPEC = importlib.util.spec_from_file_location('host_slot', TOOL)
slot = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(slot)


class HostSlotTest(unittest.TestCase):
    def test_busy_legacy_lock_never_starts_child_and_releases_first_lock(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            paths = [root / 'shared.lock', root / 'legacy.lock']
            marker = root / 'child-started'
            command = [sys.executable, '-c', 'from pathlib import Path; Path("child-started").touch()']
            with paths[1].open('a+') as held:
                fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with self.assertRaisesRegex(RuntimeError, 'Host slot busy'):
                    slot.run_section(command, root, root / 'host.jsonl', 'test', 'test', paths)
            self.assertFalse(marker.exists())
            self.assertFalse((root / 'host.jsonl').exists())
            with slot.exclusive_locks(paths, {'test': 'released'}):
                pass

    def test_existing_godot_aborts_before_command(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with patch.object(slot, 'snapshot', return_value={'foreign_godot': [{'pid': 123}]}):
                with self.assertRaisesRegex(RuntimeError, 'existing Godot'):
                    slot.run_section([sys.executable, '-c', 'raise RuntimeError()'], root,
                                     root / 'host.jsonl', 'test', 'test', [root / 'lock'])
            self.assertFalse((root / 'host.jsonl').exists())

    def test_failed_child_keeps_negative_exit_and_releases_locks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / 'host.jsonl'
            paths = [root / 'lock']
            with patch.object(slot, 'snapshot', return_value={'foreign_godot': []}):
                code = slot.run_section([sys.executable, '-c', 'raise SystemExit(7)'], root,
                                        output, 'test', 'test', paths)
            self.assertEqual(code, 7)
            events = [json.loads(line) for line in output.read_text().splitlines()]
            self.assertEqual(events[-1]['exit_code'], 7)
            self.assertEqual(events[-1]['event'], 'end')
            with slot.exclusive_locks(paths, {'test': 'released'}):
                pass

    def test_foreign_process_stops_owned_child_and_marks_contamination(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / 'host.jsonl'
            clean = {'foreign_godot': []}
            foreign = {'foreign_godot': [{'pid': 123}]}
            with patch.object(slot, 'snapshot', side_effect=[clean, foreign, clean]):
                code = slot.run_section([sys.executable, '-c', 'import time; time.sleep(30)'], root,
                                        output, 'test', 'test', [root / 'lock'])
            self.assertEqual(code, 2)
            events = [json.loads(line) for line in output.read_text().splitlines()]
            self.assertTrue(events[-1]['foreign_godot_observed'])
            self.assertIn('stopped', events[-1]['error'])
            self.assertLess(events[-1]['exit_code'], 0)

    def test_existing_output_is_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / 'host.jsonl'
            output.write_text('original')
            with patch.object(slot, 'snapshot', return_value={'foreign_godot': []}):
                with self.assertRaises(FileExistsError):
                    slot.run_section(['false'], root, output, 'test', 'test', [root / 'lock'])
            self.assertEqual(output.read_text(), 'original')

    def test_descendants_not_same_project_define_ownership(self):
        values = [{'pid': 10, 'ppid': 1}, {'pid': 11, 'ppid': 10},
                  {'pid': 12, 'ppid': 11}, {'pid': 13, 'ppid': 1}]
        self.assertEqual(slot.descendants(values, 10), {10, 11, 12})

    def test_namespace_pid_is_translated_before_ownership(self):
        values = [{'pid': 1000, 'ppid': 1, 'namespace_pid': 5},
                  {'pid': 1001, 'ppid': 1000, 'namespace_pid': 6},
                  {'pid': 5, 'ppid': 1, 'namespace_pid': None}]
        self.assertEqual([item['pid'] for item in slot.owned_values(values, 5)], [1000, 1001])
        self.assertEqual(slot.owned_values(values, 99), [])

    def test_stop_cleans_detached_child_session_and_preserves_foreign_process(self):
        with tempfile.TemporaryDirectory() as temporary:
            marker = Path(temporary) / 'pid'
            source = ('import subprocess,sys,time; from pathlib import Path; '
                      'p=subprocess.Popen([sys.executable,"-c","import time; time.sleep(30)"],start_new_session=True); '
                      'Path(sys.argv[1]).write_text(str(p.pid)); time.sleep(30)')
            parent = subprocess.Popen([sys.executable, '-c', source, str(marker)], start_new_session=True)
            foreign = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'], start_new_session=True)
            child = None
            try:
                deadline = time.monotonic() + 3
                while not marker.exists() and time.monotonic() < deadline:
                    time.sleep(.01)
                self.assertTrue(marker.exists())
                child = int(marker.read_text())
                owned = slot.owned_values(slot.processes(), parent.pid)
                self.assertIn(child, [item['namespace_pid'] for item in owned])
                slot.stop_group(parent)
                values = slot.processes()
                self.assertFalse(any(item['namespace_pid'] == child and item['state'] != 'Z' for item in values))
                self.assertIsNone(foreign.poll())
            finally:
                for process in (parent, foreign):
                    if process.poll() is None:
                        process.kill()
                    process.wait()
                if child is not None:
                    try:
                        os.kill(child, signal.SIGKILL)
                    except ProcessLookupError:
                        pass


if __name__ == '__main__':
    unittest.main()
