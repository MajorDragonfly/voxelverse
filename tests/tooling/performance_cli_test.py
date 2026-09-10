"""Report-path failures must not overwrite source files or previous evidence."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

RUNNER = Path(__file__).resolve().parents[2] / "tools/profile_performance.py"


class PerformanceCliTest(unittest.TestCase):
    def test_rejects_output_inside_the_project_before_launching_godot(self):
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary) / "source"
            project.mkdir()
            output = project / "reports"
            result = subprocess.run([sys.executable, str(RUNNER), "--project", str(project),
                                     "--output", str(output), "--godot", "missing-engine"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn("outside the source project", result.stderr)
            self.assertFalse(output.exists())

    def test_rejects_invalid_seed_and_nonfinite_duration_before_launch(self):
        for option, value in [("--seed", "0"), ("--seed", "2147483648"), ("--walk-seconds", "nan"), ("--walk-seconds", "inf")]:
            with self.subTest(option=option, value=value):
                result = subprocess.run([sys.executable, str(RUNNER), option, value,
                                         "--godot", "missing-engine"], capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertNotIn("Godot executable not found", result.stderr)

    def test_preserves_previous_report(self):
        for name in ("performance.json", "capture.json", "engine.log", "frames.csv", "process-memory.json", "fixture"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                output = Path(temporary)
                previous = output / name
                previous.write_text('"previous evidence"')
                result = subprocess.run([sys.executable, str(RUNNER), "--output", str(output),
                                         "--godot", "missing-engine"], capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(previous.read_text(), '"previous evidence"')


if __name__ == "__main__":
    unittest.main()
