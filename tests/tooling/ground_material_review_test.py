"""Keep real render acceptance strict when a workflow compares the same shader."""
import contextlib
import io
import json
from pathlib import Path
from types import SimpleNamespace
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import review_ground_materials as review


class GroundMaterialReviewTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.project = self.root / "project"
        self.output = self.root / "capture"
        self.output.mkdir()
        self.baseline = self.root / "baseline.gdshader"
        self.candidate = self.project / "world/surface/visuals/living_ground.gdshader"
        self.candidate.parent.mkdir(parents=True)
        self.baseline.write_bytes(b"shader_type spatial;\n")
        self.candidate.write_bytes(self.baseline.read_bytes())
        self.samples = [{"category": category, "view": view, "mean_rgb_change": 0.0,
                         "draw_calls": 25, "baseline_gpu_ms": 1.0, "candidate_gpu_ms": 1.0}
                        for category in ("grassland", "desert", "rocky_highlands", "snow", "coast")
                        for view in ("near", "middle", "far")]
        for sample in self.samples:
            for side in ("before", "after"):
                name = f"{sample['category']}_{sample['view']}_{side}.png"
                (self.output / name).write_bytes(b"fixture frame bytes")
        self.report = {"passed": True, "renderer": "forward_plus", "samples": self.samples}

    def run_review(self, stdout="GROUND_MATERIAL_REVIEW", status=0, during_capture=None):
        (self.output / "capture.json").write_text(json.dumps(self.report))

        def capture(command, **kwargs):
            self.assertEqual(command[-1], str(self.baseline.resolve()))
            self.assertIn("res://tools/capture_ground_materials.gd", command)
            if during_capture:
                during_capture()
            return SimpleNamespace(returncode=status, stdout=stdout)

        argv = ["review_ground_materials", "--godot", "fixture-godot", "--renderer", "forward_plus",
                "--output", str(self.output), "--baseline", str(self.baseline)]
        with patch.object(review, "__file__", str(self.project / "tools/review_ground_materials.py")), \
                patch.object(sys, "argv", argv), \
                patch.object(review, "validation_editor", return_value=contextlib.nullcontext(Path("fixture-godot"))), \
                patch.object(review.subprocess, "run", side_effect=capture), \
                contextlib.redirect_stdout(io.StringIO()):
            review.main()

    def test_identical_source_and_rendered_frames_pass(self):
        self.run_review()

    def test_changed_source_still_requires_the_existing_visible_delta(self):
        self.candidate.write_bytes(b"shader_type spatial; // real change\n")
        with self.assertRaisesRegex(RuntimeError, "did not visibly change"):
            self.run_review()
        self.samples[0]["mean_rgb_change"] = 0.004
        self.run_review()

    def test_identical_source_rejects_any_reported_visual_change(self):
        self.samples[0]["mean_rgb_change"] = 0.000001
        with self.assertRaisesRegex(RuntimeError, "Identical shader sources"):
            self.run_review()

    def test_identical_source_rejects_different_frames_even_when_report_claims_zero_delta(self):
        (self.output / "grassland_near_after.png").write_bytes(b"different fixture pixels")
        with self.assertRaisesRegex(RuntimeError, "Identical shader sources"):
            self.run_review()

    def test_source_replaced_during_capture_cannot_produce_acceptance(self):
        with self.assertRaisesRegex(RuntimeError, "Shader sources changed"):
            self.run_review(during_capture=lambda: self.candidate.write_bytes(b"changed during capture"))

    def test_identical_source_keeps_error_missing_frame_and_draw_guards(self):
        for stdout in ("SCRIPT ERROR: fixture", "ERROR: fixture", "ObjectDB instances leaked at exit"):
            with self.subTest(stdout=stdout), self.assertRaisesRegex(RuntimeError, "Native ground review failed"):
                self.run_review(stdout=stdout)
        with self.assertRaisesRegex(RuntimeError, "Native ground review failed"):
            self.run_review(status=1)
        (self.output / "grassland_near_after.png").unlink()
        with self.assertRaisesRegex(RuntimeError, "Missing before/after frames"):
            self.run_review()
        (self.output / "grassland_near_after.png").write_bytes(b"fixture frame bytes")
        self.samples[0]["draw_calls"] = 0
        with self.assertRaisesRegex(RuntimeError, "Ground was not drawn"):
            self.run_review()


if __name__ == "__main__":
    unittest.main()
