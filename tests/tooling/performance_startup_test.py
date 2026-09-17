"""Reject misleading startup evidence and retain the last phase on hard timeouts."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from performance_startup_report import PHASES, read_progress, run_process, validate_capture, write_summary


class StartupReportTest(unittest.TestCase):
    def fixture(self, root):
        recipe = {"cycles": 2, "seed": 15838, "renderer": "headless"}
        source = {"commit": "source", "tree": "tree", "dirty": False}
        fixture = {"sha256": "a" * 64}
        loads = []
        for cycle in range(2):
            loads.append({"cycle": cycle, "cache_state": "cold_process" if cycle == 0 else "warm_process",
                          "trace": {"status": "ready", "last_phase": "arrival", "error": "", "total_ms": 7.0,
                                    "context": {"scene": "res://main/spherical_campaign.tscn", "seed": 15838, "body_id": "body"},
                                    "segments": [{"phase": name, "duration_ms": 1.0, "start_ms": float(i), "completed": True}
                                                 for i, name in enumerate(PHASES)]}})
        capture = {"passed": True, "recipe": recipe, "source": source, "user_data_dir": str(root / "userdata"),
                   "world_starts": 2, "save_attempts": 0, "initial_save_sha256": fixture["sha256"],
                   "final_save_sha256": fixture["sha256"], "renderer": "headless", "godot": "4.6.3", "cpu": "test",
                   "loads": loads}
        return capture, recipe, source, root, fixture

    def test_complete_cold_warm_evidence_and_summary(self):
        with tempfile.TemporaryDirectory() as temporary:
            args = self.fixture(Path(temporary))
            validate_capture(*args)
            write_summary(Path(temporary), args[0])
            text = (Path(temporary) / "summary.md").read_text()
            self.assertIn("Cold ms", text)
            self.assertIn("Warm ms", text)
            self.assertIn("OS file caches are not cleared", text)
            self.assertIn("start_terrain", text)

    def test_rejects_incomplete_or_mutating_runs(self):
        with tempfile.TemporaryDirectory() as temporary:
            original = self.fixture(Path(temporary))
            mutations = [lambda c: c.update(world_starts=3), lambda c: c.update(save_attempts=1),
                         lambda c: c.update(final_save_sha256="b" * 64), lambda c: c["loads"].pop(),
                         lambda c: c["loads"][1].update(cache_state="cold_process"),
                         lambda c: c["loads"][1]["trace"]["context"].update(body_id="another"),
                         lambda c: c["loads"][0]["trace"]["segments"].pop(),
                         lambda c: c["loads"][0]["trace"]["segments"][0].update(duration_ms=float("nan")),
                         lambda c: c["loads"][0]["trace"]["segments"][1].update(start_ms=0.0),
                         lambda c: c["loads"][0]["trace"].update(status="failed"),
                         lambda c: c["loads"][0]["trace"].update(total_ms=99.0),
                         lambda c: c.update(user_data_dir="/outside-profile")]
            for index, mutate in enumerate(mutations):
                with self.subTest(case=index):
                    capture = copy.deepcopy(original[0])
                    mutate(capture)
                    with self.assertRaises(ValueError): validate_capture(capture, *original[1:])

    def test_hard_timeout_names_last_phase_and_retains_progress(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            progress = root / "startup-progress.json"
            # A genuinely blocked child cannot emit another frame or final report.
            code = ("import json,time; from pathlib import Path; "
                    f"Path({str(progress)!r}).write_text(json.dumps({{'cycle':0,'trace':{{'last_phase':'scene_ready','status':'loading'}}}})); "
                    "time.sleep(10)")
            with self.assertRaisesRegex(RuntimeError, "timeout in phase scene_ready"):
                run_process([sys.executable, "-c", code], root / "userdata", root, 0.5)
            self.assertEqual(read_progress(root)["trace"]["last_phase"], "scene_ready")
            self.assertTrue((root / "engine.log").exists())

    def test_partial_progress_uses_last_complete_log_record(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "startup-progress.json").write_text('{"partial"')
            value = {"cycle": 1, "trace": {"last_phase": "threaded_load"}}
            (root / "engine.log").write_text("STARTUP_PHASE " + json.dumps(value) + '\nSTARTUP_PHASE {"partial"')
            self.assertEqual(read_progress(root), value)

    def test_timeout_budget_restarts_only_when_the_phase_changes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            progress = root / "startup-progress.json"
            code = ("import json,time; from pathlib import Path; "
                    f"p=Path({str(progress)!r}); "
                    "p.write_text(json.dumps({'cycle':0,'trace':{'last_phase':'threaded_load','status':'loading'}})); "
                    "time.sleep(0.4); "
                    "p.write_text(json.dumps({'cycle':0,'trace':{'last_phase':'scene_ready','status':'loading'}})); "
                    "time.sleep(0.4)")
            run_process([sys.executable, "-c", code], root / "userdata", root, 0.7)


if __name__ == "__main__":
    unittest.main()
