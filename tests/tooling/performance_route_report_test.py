"""Route reports must keep tails separate and reject mismatched comparisons."""

import csv
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from performance_route_report import write_route_summary


class RouteReportTest(unittest.TestCase):
    def _capture(self, folder, height=2.0, face=0):
        capture = {"recipe": {"seed": 8, "renderer": "headless"}, "cpu": "test", "renderer": "headless",
                   "adapter": "test", "surface": {"id": "planet"},
                   "initial_address": {"body_id": "planet", "face": face, "u": 0.0, "v": 0.0, "height": height},
                   "world_0": {"population_spawn_stage_max_ms": {"actor_ready": 180.0}}}
        address = dict(capture["initial_address"])
        capture["segments"] = [{"cycle": 0, "stage": "route_outcome",
                                "breadcrumbs": [address, dict(address, u=1e-6)]}]
        (folder / "capture.json").write_text(json.dumps(capture), encoding="utf-8")
        with (folder / "frames.csv").open("w", newline="", encoding="utf-8") as destination:
            writer = csv.DictWriter(destination, fieldnames=["cycle", "stage", "tick_us", "frame_ms"])
            writer.writeheader()
            for index, value in enumerate((16.0, 33.0, 51.0, 101.0)):
                writer.writerow({"cycle": 0, "stage": "walk_outward", "tick_us": 1_000_000 + index * 100_000,
                                 "frame_ms": value})
            writer.writerow({"cycle": 0, "stage": "walk_return", "tick_us": 2_000_000, "frame_ms": 17.0})
        return capture

    def test_raw_route_tails_and_matching_replay(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old, new = root / "old", root / "new"
            old.mkdir(); new.mkdir()
            self._capture(old)
            capture = self._capture(new, height=2.03)
            report = write_route_summary(new, capture, old)
            outward = report["routes"][0]
            self.assertEqual(outward["spikes_over_ms"], {"33": 2, "50": 2, "100": 1})
            self.assertEqual((outward["p50_ms"], outward["p95_ms"], outward["p99_ms"]), (42.0, 101.0, 101.0))
            self.assertEqual(outward["largest_frames"][0], {"route_second": 0.3, "frame_ms": 101.0})
            self.assertEqual(report["routes"][1]["spikes_over_ms"]["33"], 0)
            self.assertEqual(report["comparison"][0]["baseline_spikes_over_ms"]["100"], 1)
            self.assertIn("| 0 | walk_return |", (new / "summary.md").read_text())

    def test_rejects_different_planet_face(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old, new = root / "old", root / "new"
            old.mkdir(); new.mkdir()
            self._capture(old)
            capture = self._capture(new, face=1)
            with self.assertRaisesRegex(ValueError, "same recipe"):
                write_route_summary(new, capture, old)

    def test_replay_float_roundtrip_and_actual_address_change(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old, new = root / "old", root / "new"
            old.mkdir(); new.mkdir()
            previous = self._capture(old)
            previous["segments"][0]["breadcrumbs"][0]["v"] = -0.88
            (old / "capture.json").write_text(json.dumps(previous), encoding="utf-8")
            capture = self._capture(new)
            capture["segments"][0]["breadcrumbs"][0]["v"] = -0.880000000000001
            result = write_route_summary(new, capture, old)
            self.assertEqual(result["comparison"][0]["current_p99_ms"], 101.0)
            self.assertEqual(result["comparison"][0]["current_max_ms"], 101.0)
            capture["segments"][0]["breadcrumbs"][0]["v"] = -0.8800001
            with self.assertRaisesRegex(ValueError, "same recipe"):
                write_route_summary(new, capture, old)


if __name__ == "__main__":
    unittest.main()
