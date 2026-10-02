"""Keep failed/incomplete and foreign-load R32 measurements visible."""
import csv
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from review_r32_02_report import collect


class ReportCases(unittest.TestCase):
    def test_incomplete_return_and_nested_work_remain_explicit(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            capture = {'recipe': {'seed': 15838}, 'source': {}, 'passed': False,
                       'failures': ['player died'], 'cpu': 'fixture', 'renderer': 'headless',
                       'snapshots': [], 'segments': [{'cycle': 0, 'stage': 'route_outcome'}],
                       'readiness': {'0': {'events': [], 'sample_work_max_ms': 1, 'dropped': 0,
                                          'work_dropped': 0, 'notes': 'bounds',
                                          'work': [{'kind': 'spawn', 'label': 'actor_ready', 'started_us': 2000, 'finished_us': 3000, 'ms': 1}]}}}
            (root / 'capture.json').write_text(json.dumps(capture))
            with (root / 'frames.csv').open('w') as output:
                writer = csv.DictWriter(output, fieldnames=['cycle', 'stage', 'tick_us', 'frame_ms'])
                writer.writeheader()
                writer.writerows([{'cycle': 0, 'stage': 'walk_outward', 'tick_us': 1000, 'frame_ms': 1},
                                  {'cycle': 0, 'stage': 'walk_return', 'tick_us': 60000, 'frame_ms': 59}])
            host = root / 'host.jsonl'
            host.write_text(json.dumps({'foreign_godot': [{'pid': 42}]}) + '\n')
            value = collect(root, host)
            self.assertFalse(value['passed'])
            self.assertEqual(value['failures'], ['player died'])
            self.assertTrue(value['route_rows'][0]['complete'])
            self.assertFalse(value['route_rows'][1]['complete'])
            self.assertTrue(value['foreign_godot_observed'])
            self.assertFalse(value['target_pc_acceptance'])
            self.assertEqual(value['frames_over_50_with_work'][0]['work'][0]['label'], 'actor_ready')


if __name__ == '__main__':
    unittest.main()
