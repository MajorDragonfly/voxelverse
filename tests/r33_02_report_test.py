"""Check attribution boundaries and guards that keep negative evidence negative."""
from pathlib import Path
import sys
import unittest

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
sys.path.insert(0, str(TOOLS))
import review_r33_02_report as report


class ReportTest(unittest.TestCase):
    def test_nested_parent_and_child_are_not_added_twice(self):
        frames = [{'cycle': '0', 'stage': 'walk_outward', 'tick_us': '100000', 'frame_ms': '100'}]
        work = [{'kind': 'tick', 'label': 'spawn', 'started_us': 10000, 'finished_us': 90000, 'ms': 80},
                {'kind': 'mesh', 'label': 'skin', 'started_us': 20000, 'finished_us': 70000, 'ms': 50}]
        value = report.frame_phases(frames, work)[0]
        self.assertEqual(sum(item['overlap_ms'] for item in value['work']), 130)
        self.assertEqual(value['observed_work_union_ms'], 80)

    def test_work_spanning_two_frames_is_clipped_to_each(self):
        frames = [{'cycle': '0', 'stage': 'walk_outward', 'tick_us': str(end), 'frame_ms': '100'}
                  for end in (100000, 200000)]
        work = [{'kind': 'mesh', 'label': 'skin', 'started_us': 80000, 'finished_us': 130000, 'ms': 50}]
        values = report.frame_phases(frames, work)
        self.assertEqual([item['observed_work_union_ms'] for item in values], [20, 30])

    def pair(self):
        row = {'cycle': 0, 'stage': 'walk_outward', 'p50_ms': 16, 'p95_ms': 50,
               'p99_ms': 90, 'max_ms': 100, 'spikes_over_ms': {'33': 3, '50': 2, '100': 0}}
        return {'controlled_comparison_blockers': [], 'source': {'tree': 'tree'}, 'route_rows': [row]}

    def test_negative_or_unconfirmed_baseline_cannot_establish_gain(self):
        before, after = self.pair(), self.pair()
        before['controlled_comparison_blockers'] = ['Foreign Godot load observed', 'Incomplete movement stage']
        after['route_rows'][0]['p95_ms'] = 20
        value = report.compare(before, after)
        self.assertFalse(value['controlled_comparison_allowed'])
        self.assertEqual(len(value['blockers']), 2)
        self.assertTrue(value['same_tree_repeat'])

    def test_route_recipe_mismatch_is_rejected(self):
        before, after = self.pair(), self.pair()
        before['recipe'] = {'route_sha256': 'a'}
        after['recipe'] = {'route_sha256': 'b'}
        self.assertIn('Different recipe', report.compare(before, after)['blockers'])

    def test_regressions_are_retained_even_when_p95_improves(self):
        before, after = self.pair(), self.pair()
        after['route_rows'][0]['p95_ms'] = 40
        after['route_rows'][0]['max_ms'] = 120
        value = report.compare(before, after)['deltas'][0]
        self.assertEqual(value['metric_delta_ms']['p95_ms'], -10)
        self.assertEqual(value['metric_delta_ms']['max_ms'], 20)
        self.assertTrue(value['regression'])


if __name__ == '__main__':
    unittest.main()
