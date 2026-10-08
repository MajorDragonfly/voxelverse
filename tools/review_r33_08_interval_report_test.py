#!/usr/bin/env python3
"""Original-data and rejection checks for offline interval attribution."""
import copy
import json
from pathlib import Path
import tarfile
import unittest

from review_r33_08_interval_report import analyze_archive, audit_run

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs/evidence/r33-08"


class IntervalReportChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.provenance = json.loads((EVIDENCE / "provenance.json").read_text())
        cls.archive = EVIDENCE / "native-raw.tar.gz"
        with tarfile.open(cls.archive) as tar:
            cls.files = {m.name: tar.extractfile(m).read() for m in tar if m.isfile()}
        cls.name = "overlay-forward_plus"
        cls.prefix = f"r33-08-results/{cls.name}/"

    def read_changed(self, filename, change):
        contents = json.loads(self.files[self.prefix + filename])
        change(contents)
        changed = json.dumps(contents).encode()
        return lambda path: changed if path == self.prefix + filename else self.files[path]

    def test_original_counters_and_unmeasured_baseline(self):
        report = analyze_archive(self.archive, self.provenance)
        runs = {r["case"]: r for r in report["runs"]}
        for name in ("baseline-forward_plus", "overlay-forward_plus"):
            near = runs[name]["stages"]["near"]
            self.assertTrue(near["complete_wait_timestamps"])
            self.assertEqual(near["counter_step_histogram"], [{"process_delta": 1, "physics_delta": 8, "count": 88}])
        self.assertIsNone(runs["baseline-forward_plus"]["stages"]["near"]["pre_draw_callback"])
        self.assertEqual(runs["overlay-forward_plus"]["stages"]["near"]["pre_draw_callback"]["count"], 88)
        self.assertEqual(runs["overlay-forward_plus"]["stages"]["far"]["pre_draw_callback"]["count"], 235)
        self.assertEqual(runs["overlay-gl_compatibility"]["stages"]["near"]["pre_draw_callback"]["count"], 0)
        self.assertFalse(runs["overlay-forward_plus"]["original_route_passed"])
        self.assertEqual(runs["overlay-forward_plus"]["original_exit_code"], 124)
        self.assertFalse(report["product_cause_established"])
        self.assertFalse(report["hardware_acceptance"])

    def test_sparse_gl_is_not_every_frame_evidence(self):
        run = audit_run(self.files.__getitem__, "overlay-gl_compatibility")
        near = run["stages"]["near"]
        self.assertEqual(near["timestamped_waits"], 17)
        self.assertEqual(near["wait_ms"]["count"], 499)
        self.assertFalse(near["complete_wait_timestamps"])
        self.assertIsNone(near["waits_without_slow_measured_callback"])

    def test_tampered_archive_rejected(self):
        provenance = copy.deepcopy(self.provenance)
        provenance["files"]["native-raw.tar.gz"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "archive bytes/hash"):
            analyze_archive(self.archive, provenance)

    def test_changed_log_rejected(self):
        read = lambda path: self.files[path] + b"\nchanged" if path == self.prefix + "run.log" else self.files[path]
        with self.assertRaisesRegex(ValueError, "log hash mismatch"):
            audit_run(read, self.name)

    def test_gl_fallback_rejected(self):
        read = self.read_changed("int30-collision-progress.json", lambda p: p.update(renderer="gl_compatibility"))
        with self.assertRaisesRegex(ValueError, "renderer mismatch"):
            audit_run(read, self.name)

    def test_missing_slow_wait_rejected(self):
        def mutate(p):
            p["slow"].pop(next(i for i, r in enumerate(p["slow"]) if r["operation"] == "await-process.near"))
        read = self.read_changed("int30-collision-spans.json", mutate)
        with self.assertRaisesRegex(ValueError, "incomplete slow timestamps"):
            audit_run(read, self.name)

    def test_nonmonotonic_counters_rejected(self):
        def mutate(p):
            rows = [r for r in p["slow"] if r["operation"] == "await-process.near"]
            rows[1]["process_frame"] = rows[0]["process_frame"]
        read = self.read_changed("int30-collision-spans.json", mutate)
        with self.assertRaisesRegex(ValueError, "unordered counters"):
            audit_run(read, self.name)

    def test_dropped_spans_rejected(self):
        read = self.read_changed("int30-collision-spans.json", lambda p: p["summary"].update(dropped=1))
        with self.assertRaisesRegex(ValueError, "incomplete span collection"):
            audit_run(read, self.name)

    def test_changed_source_inventory_rejected(self):
        read = lambda path: self.files[path] + b"\n" if path == self.prefix + "source-files-end.jsonl" else self.files[path]
        with self.assertRaisesRegex(ValueError, "changed source inventory"):
            audit_run(read, self.name)


if __name__ == "__main__":
    unittest.main()
