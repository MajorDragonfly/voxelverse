#!/usr/bin/env python3
"""Summarize original paired campaign traces without changing their verdicts."""
import argparse
from collections import Counter
import json
from pathlib import Path


def summarize(capture):
    stages = {}
    for name in dict.fromkeys(row['stage'] for row in capture['frames']):
        rows = [row for row in capture['frames'] if row['stage'] == name]
        tools = [[(r['visible_tool'], r['tool_angle'], r['tool_remaining']) for r in row['residents']] for row in rows]
        stages[name] = {
            'frames': len(rows), 'clock_first_last': [rows[0]['clock'], rows[-1]['clock']],
            'visible_tools_first_last': [sum(r['visible_tool'] for r in row['residents']) for row in [rows[0], rows[-1]]],
            'max_visible_tools': max(sum(r['visible_tool'] for r in row['residents']) for row in rows),
            'max_abs_tool_angle_rad': max(abs(r['tool_angle']) for row in rows for r in row['residents']),
            'tool_state_frozen_all_frames': all(row == tools[0] for row in tools),
            'campaign_clock_frozen': len({row['clock'] for row in rows}) == 1,
            'water_clock_frozen': len({row['water_time'] for row in rows}) == 1,
            'wind_clock_frozen': len({row['wind_time'] for row in rows}) == 1,
            'stock_first_last': [rows[0]['wood_stock'], rows[-1]['wood_stock']],
        }
    return {'frames': len(capture['frames']), 'original_passed': capture.get('passed', False),
            'failed_checks': [r['label'] for r in capture['checks'] if not r['passed']], 'stages': stages,
            'weather_conditions': dict(Counter(row['weather']['condition'] for row in capture['frames'])),
            'water_matches_campaign_all_frames': all(row['water_time'] == row['clock'] for row in capture['frames']),
            'readiness_waits': capture.get('readiness_waits'), 'save_checkpoint': capture.get('save_checkpoint'),
            'loaded_checkpoint': capture.get('loaded_checkpoint'), 'final_stock': capture.get('final_stock')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('original_pair', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    data = {name: json.loads((args.original_pair / name / 'capture.json').read_text()) for name in ['before', 'after']}
    results = {name: json.loads((args.original_pair / name / 'results.json').read_text()) for name in data}
    source = {name: results[name]['source'] for name in data}
    pairs = list(zip(data['before']['frames'], data['after']['frames']))
    common = {key: source['before']['files'][key] == source['after']['files'][key] for key in source['before']['files']}
    def economy(row):
        return (row['wood_stock'], [(r['id'], r['order'], r['stage'], r['work'], r['cargo']) for r in row['residents']])
    summary = {'schema': 1, 'target_pc_acceptance': False, 'source': source,
               'fixture_digest_equal': results['before']['fixture_digest'] == results['after']['fixture_digest'],
               'recipe_equal': data['before']['recipe'] == data['after']['recipe'], 'common_file_hashes_equal': common,
               'columns': {name: summarize(capture) for name, capture in data.items()},
               'max_campaign_clock_difference_s': max(abs(a['clock'] - b['clock']) for a, b in pairs),
               'economic_states_equal_before_reload': all(economy(a) == economy(b) for a, b in pairs if a['stage'] != 'after_load'),
               'economic_states_equal_after_reload': all(economy(a) == economy(b) for a, b in pairs if a['stage'] == 'after_load'),
               'max_camera_position_difference_m': max(sum((x-y)**2 for x,y in zip(a['camera'],b['camera']))**.5 for a,b in pairs),
               'render_and_readback': {name: {key: results[name][key] for key in ['draw_wait_us', 'readback_png_us']} for name in data},
               'limits': ['Original verdicts retained; comparison summary is postprocessing, not an independent gameplay test.',
                          'Clock/readiness differences after load are exposed; no aggregate FPS or target-PC approval.']}
    args.output.write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps({key: summary[key] for key in ['fixture_digest_equal', 'recipe_equal', 'economic_states_equal_before_reload',
                                                    'economic_states_equal_after_reload', 'max_campaign_clock_difference_s']}, indent=2))


if __name__ == '__main__':
    main()
