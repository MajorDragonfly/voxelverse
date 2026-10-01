"""Interrupted capture evidence must survive without becoming acceptance."""
from contextlib import contextmanager
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import int30_scenery_collision_check as capture


class StableSource:
    blocked = False

    def __init__(self, project):
        pass

    def observe(self, *args, **kwargs):
        return {"fixture": "stable"}

    def begin_report(self, output):
        pass

    def write_report(self, output):
        return {"status": "stable", "reusable": True}


@contextmanager
def fixture_editor(command):
    yield Path(command)


def evidence(*, complete=False, passed=False, failures=None):
    return json.dumps({"schema": 2, "complete": complete, "passed": passed,
                       "failures": [] if failures is None else failures,
                       "phase": "publication-far-start"}).encode()


class CollisionCaptureDiagnosticsTest(unittest.TestCase):
    def run_capture(self, *, final=None, checkpoint=None, timed_out=False):
        temporary = tempfile.TemporaryDirectory(prefix="collision-report-")
        self.addCleanup(temporary.cleanup)
        output = Path(temporary.name) / "report"

        def engine(command, *, env, stdout, stderr, timeout):
            self.assertEqual(timeout, 360)
            self.assertIn("res://tests/int30_scenery_collision_world_test.gd", command)
            userdata = Path(env["XDG_DATA_HOME"]) / "fixture-userdata"
            userdata.mkdir()
            if final is not None:
                (userdata / "int30-collision-world.json").write_bytes(final)
            if checkpoint is not None:
                (userdata / "int30-collision-progress.json").write_bytes(checkpoint)
            stdout.write("INT30_SCENERY_WORLD success-looking marker\n")
            if timed_out:
                raise subprocess.TimeoutExpired(command, timeout)
            return subprocess.CompletedProcess(command, 0)

        arguments = ["capture", "--godot", "fixture-engine", "--world", "--output", str(output)]
        with patch.object(sys, "argv", arguments), patch.object(capture, "SourceRun", StableSource), \
                patch.object(capture, "validation_editor", fixture_editor), \
                patch.object(capture.subprocess, "run", side_effect=engine), \
                patch("sys.stdout", new_callable=io.StringIO):
            code = capture.main()
        report = json.loads((output / "results.json").read_text())
        return code, report, output

    def test_timeout_retains_partial_bytes_and_timeout_even_with_final_report(self):
        partial = evidence()
        for final in [None, evidence(complete=True, passed=True)]:
            with self.subTest(final=final):
                code, report, output = self.run_capture(final=final, checkpoint=partial, timed_out=True)
                self.assertEqual(code, 1)
                self.assertEqual(report["exit_code"], 124)
                self.assertEqual(report["status"], "failed_incomplete")
                self.assertFalse(report["passed"])
                self.assertFalse(report["provenance"]["reusable"])
                self.assertEqual((output / "int30-collision-progress.json").read_bytes(), partial)

    def test_marker_and_zero_exit_cannot_accept_missing_or_bad_final_evidence(self):
        cases = [None, b"{ interrupted", b"[]", evidence(),
                 evidence(complete=1, passed=True), evidence(complete=True, passed=1),
                 evidence(complete=True, passed=False, failures=["missing oak"]),
                 evidence(complete=True, passed=True, failures=["missing oak"])]
        for final in cases:
            with self.subTest(final=final):
                code, report, output = self.run_capture(final=final, checkpoint=evidence())
                self.assertEqual(code, 1)
                self.assertFalse(report["passed"])
                self.assertFalse(report["world_evidence"]["successful_final"])
                self.assertFalse(report["provenance"]["reusable"])
                if final is not None:
                    self.assertEqual((output / "int30-collision-world.json").read_bytes(), final)

    def test_complete_success_keeps_partial_checkpoint_separate(self):
        partial = evidence()
        code, report, output = self.run_capture(final=evidence(complete=True, passed=True), checkpoint=partial)
        self.assertEqual(code, 0)
        self.assertEqual(report["status"], "passed")
        self.assertTrue(report["passed"])
        self.assertFalse(report["incomplete"])
        self.assertTrue(report["provenance"]["reusable"])
        self.assertFalse(report["world_evidence"]["checkpoint"]["complete"])
        self.assertEqual((output / "int30-collision-progress.json").read_bytes(), partial)

    def test_unreadable_final_is_described_without_becoming_success(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            (output / "int30-collision-world.json").write_bytes(evidence(complete=True, passed=True))
            with patch.object(Path, "read_bytes", side_effect=PermissionError("unreadable retained evidence")):
                report = capture.world_evidence_report(output)
            self.assertFalse(report["successful_final"])
            self.assertFalse(report["final"]["valid"])
            self.assertIn("unreadable", report["final"]["error"])


if __name__ == "__main__":
    unittest.main()
