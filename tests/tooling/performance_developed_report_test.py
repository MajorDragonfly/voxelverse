"""Incomplete cold-restart evidence must not become a passing measurement."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from performance_developed_report import REQUIRED_STAGES, validate_developed, write_developed_summary


class DevelopedReportTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.output = Path(self.temporary.name)
        self.userdata = self.output / "isolated"
        self.capture = {
            "recipe": {"cycles": 1, "production": "milk", "renderer": "headless"},
            "source": {"commit": "source-a", "dirty": False}, "passed": True, "process": "main",
            "renderer": "headless", "godot": "4.6.3", "cpu": "test CPU",
            "segments": [self.stage(s) for s in sorted(REQUIRED_STAGES | {"produce_and_collect_milk", "milk_delivered"})],
            "children": [], "snapshots": [{"stage": "animal_travel_far_work",
                "villages": [{"owner": "far", "cargo_units": {"milk": 1}}]}],
        }
        (self.output / "frames.csv").write_text("header\nsample\n")
        for kind in ("far_restart", "home_restart"):
            key = "cycle_0_" + kind
            self.capture["children"].append({"process": key, "exit_code": 0, "elapsed_ms": 100.0})
            (self.output / (key + "-frames.csv")).write_text("header\nsample\n")
            self.write_child(key, dict(self.capture, process=key, children=[], user_data_dir=str(self.userdata / "game"),
                         segments=[self.stage("load_paused_checkpoint"), self.stage("checkpoint_ready")]))

    def stage(self, name):
        return {"cycle": 0, "stage": name, "elapsed_ms": 10.0,
                "frame_ms": {"count": 1, "median": 10.0, "p95": 10.0, "p99": 10.0}, "render_gpu_ms": None}

    def write_child(self, key, child):
        (self.output / (key + "-capture.json")).write_text(json.dumps(child))

    def validate(self):
        return validate_developed(self.output, self.capture, self.userdata)

    def test_parent_success_requires_both_restarts(self):
        self.assertEqual(len(self.validate()), 2)
        self.capture["children"].pop()
        with self.assertRaisesRegex(ValueError, "Missing or duplicate"):
            self.validate()

    def test_godot_float_encoded_cycle_count_is_valid(self):
        self.capture["recipe"]["cycles"] = 1.0
        self.assertEqual(len(self.validate()), 2)
        self.capture["recipe"]["cycles"] = 1.5
        with self.assertRaisesRegex(ValueError, "cycle count"): self.validate()

    def test_duplicate_child_cannot_replace_other_restart(self):
        self.capture["children"][1] = self.capture["children"][0]
        with self.assertRaisesRegex(ValueError, "Missing or duplicate"):
            self.validate()

    def test_missing_delivery_fails(self):
        self.capture["segments"] = [s for s in self.capture["segments"] if s["stage"] != "milk_delivered"]
        with self.assertRaisesRegex(ValueError, "Incomplete developed"):
            self.validate()

    def test_invalid_child_revision_failure_or_directory_fails(self):
        key = "cycle_0_far_restart"
        original = json.loads((self.output / (key + "-capture.json")).read_text())
        for field, value in [("source", {}), ("passed", False), ("user_data_dir", str(self.output)),
                             ("failures", ["lost cargo"]), ("segments", [])]:
            with self.subTest(field=field):
                child = copy.deepcopy(original)
                child[field] = value
                self.write_child(key, child)
                with self.assertRaises(ValueError): self.validate()

    def test_unavailable_gpu_and_separate_subprocess_wait(self):
        self.capture["process_reports"] = self.validate()
        write_developed_summary(self.output, self.capture)
        summary = (self.output / "summary.md").read_text()
        self.assertIn("unavailable", summary)
        self.assertIn("excluded from parent frame percentiles", summary)

    def test_disabled_sampler_and_missing_freight_observation_fail(self):
        self.capture["snapshots"] = []
        with self.assertRaisesRegex(ValueError, "remote product freight"): self.validate()
        for stage in self.capture["segments"]: stage["frame_ms"] = None
        with self.assertRaisesRegex(ValueError, "no frame intervals"): self.validate()

    def test_header_without_raw_frames_fails(self):
        (self.output / "cycle_0_far_restart-frames.csv").write_text("header\n")
        with self.assertRaisesRegex(ValueError, "no raw frame evidence"): self.validate()

    def test_comparison_rejects_different_hardware_or_failed_baseline(self):
        baseline = self.output / "baseline"
        baseline.mkdir()
        for field, value in [("cpu", "different CPU"), ("passed", False), ("recipe", {})]:
            with self.subTest(field=field):
                old = dict(self.capture)
                old[field] = value
                (baseline / "performance.json").write_text(json.dumps(old))
                with self.assertRaisesRegex(ValueError, "identical recipe"):
                    write_developed_summary(self.output, self.capture, baseline)

    def test_compatible_baseline_reports_wall_time_difference(self):
        baseline = self.output / "baseline"
        baseline.mkdir()
        old = copy.deepcopy(self.capture)
        old["source"]["commit"] = "source-b"
        for s in old["segments"]: s["elapsed_ms"] = 12.0
        (baseline / "performance.json").write_text(json.dumps(old))
        write_developed_summary(self.output, self.capture, baseline)
        summary = (self.output / "summary.md").read_text()
        self.assertIn("-2.00", summary)
        self.assertIn("not statistical significance", summary)


if __name__ == "__main__":
    unittest.main()
