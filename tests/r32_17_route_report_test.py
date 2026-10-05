"""Integrated route comparison: physical start, original gates kept."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RouteOwnerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        module = ROOT / 'tools/performance_route_report.py'
        spec = importlib.util.spec_from_file_location('r32_17_route_owner', module)
        cls.owner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.owner)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='r32-17-route-test-')
        self.before = Path(self.temp.name) / 'before'
        self.after = Path(self.temp.name) / 'after'
        for directory in (self.before, self.after):
            directory.mkdir()
            (directory / 'frames.csv').write_text('cycle,stage,tick_us,frame_ms\n0,walk_outward,1000,16\n0,walk_outward,2000,40\n')
        address = {'body_id': 'same-body', 'face': 0, 'u': 0.0, 'v': -0.88, 'height': 25.3213125}
        self.old = {'recipe': {'route_sha256': 'same-51-points'}, 'cpu': 'same-cpu', 'renderer': 'headless',
                    'adapter': '', 'surface': {'radius': 6371000}, 'initial_address': dict(address, height=26.310488),
                    'segments': [{'cycle': 0, 'stage': 'route_outcome', 'breadcrumbs': [address, dict(address, u=1e-6)]}]}
        self.new = copy.deepcopy(self.old)
        self.new['initial_address']['height'] = 26.160613

    def tearDown(self):
        self.temp.cleanup()

    def compare(self):
        (self.before / 'capture.json').write_text(json.dumps(self.old))
        return self.owner.write_route_summary(self.after, self.new, self.before)

    def test_falling_pre_settle_pose_does_not_replace_actual_walking_start(self):
        result = self.compare()
        self.assertEqual(result['comparison'][0]['baseline_p95_ms'], 40)
        self.assertEqual(result['comparison'][0]['current_p95_ms'], 40)

    def test_actual_start_and_recipe_gates_still_reject(self):
        for key, value in [('body_id', 'other-body'), ('face', 1), ('u', 1e-10), ('height', 25.4313125)]:
            with self.subTest(key=key):
                self.new = copy.deepcopy(self.old)
                self.new['segments'][0]['breadcrumbs'][0][key] = value
                with self.assertRaises(ValueError):
                    self.compare()
        self.new = copy.deepcopy(self.old)
        self.new['recipe']['route_sha256'] = 'different-route'
        with self.assertRaises(ValueError):
            self.compare()

    def test_missing_physical_route_does_not_fall_back_to_initial_pose(self):
        self.new['segments'] = []
        with self.assertRaises(ValueError):
            self.compare()


if __name__ == '__main__':
    unittest.main()
