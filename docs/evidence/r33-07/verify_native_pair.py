#!/usr/bin/env python3
"""Verify original extracted R33-07 artifacts; does not start Godot or rewrite them."""
import argparse
import hashlib
import json
import math
from pathlib import Path

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text())

def equal(a, b):
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return math.isclose(a, b, rel_tol=1e-10, abs_tol=1e-6)
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(equal(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(equal(x, y) for x, y in zip(a, b))
    return a == b

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('artifacts', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    binding = read(Path(__file__).with_name('owned-source-binding.json'))
    runs = []
    for name, method in [('gl', 'gl_compatibility'), ('forward', 'forward_plus')]:
        folder = args.artifacts / ('r33-07-' + name)
        runner, review = read(folder / 'runner.json'), read(folder / 'review.json')
        assert runner['passed'] and review['passed'] and not review['failures']
        assert runner['renderer_observed'] == review['renderer'] == method
        assert runner['timeout_seconds'] == 300 and runner['error'] is None and runner['exit_code'] == 0
        provenance = runner['source_provenance']
        assert provenance['reusable'] and provenance['status'] == 'stable'
        for boundary in ['start', 'end']:
            source = provenance[boundary]
            assert source['commit'] == binding['measured_qa_head']
            assert source['tree'] == binding['measured_qa_tree']
            assert source['complete'] and not source['tracked_worktree_dirty']
            manifest = folder / provenance['manifests'][boundary]['path']
            assert digest(manifest) == provenance['manifests'][boundary]['sha256']
            actual = {x['path']: x for x in map(json.loads, manifest.read_text().splitlines())}
            for owned in binding['owned_files']:
                assert actual[owned['path']]['sha256'] == owned['sha256'], owned['path']
        assert provenance['start']['source_sha256'] == provenance['end']['source_sha256']
        assert not read(folder / 'host-start.json')['processes']
        assert not read(folder / 'host-end.json')['processes']
        assert len(review['rows']) == 35 and len(runner['captures']) == 36
        for filename, expected in runner['captures'].items():
            assert digest(folder / filename) == expected
        consequences = read(folder / 'consequences.json')
        assert consequences['cold_code'] == 0 and consequences['protected_loss'] == 0
        assert consequences['exposed_1x_loss'] > 0 and consequences['exposed_4x_loss'] > 0
        assert 0 < consequences['exposed_loss'] <= 0.15 * consequences['maximum_health']
        assert equal(consequences['exposed_loss'], consequences['spent_ratio'] * consequences['maximum_health'])
        event = read(folder / 'event-save.json')
        active = event['game_state']['body_id']
        receipt = event['game_state']['campaign']['bodies'][active]['weather_exposure']
        assert equal(receipt['spent_ratio'], consequences['spent_ratio'])
        assert equal(event['player']['health_ratio'] * consequences['maximum_health'], consequences['saved_health'])
        reference = read(folder / 'reference-save.json')
        body = reference['game_state']['campaign']['bodies'][reference['game_state']['body_id']]
        assert body['weather_climate']['profile_id'] == 'arid' and not body['weather_climate']['home_protected']
        runs.append({'method': method, 'wall_seconds': runner['wall_seconds'],
                     'consequences': consequences, 'rows': review['rows'],
                     'reference_sha256': runner['reference_save_sha256'],
                     'video_sha256': digest(folder / 'sandstorm.mp4'),
                     'body': {'id': body['id'], 'seed': body['seed'], 'climate': body['weather_climate'],
                              'spawn': body['surface_context']['spawn']}})
    left, right = runs
    assert left['reference_sha256'] == right['reference_sha256']
    assert equal(left['consequences'], right['consequences']) and equal(left['body'], right['body'])
    differences = []
    actor_settlement = []
    for a, b in zip(left['rows'], right['rows']):
        assert a['file'] == b['file']
        for field in ['clock', 'camera_address', 'camera_forward', 'resolution', 'health', 'receipt', 'health_display', 'terrain_evidence']:
            if not equal(a[field], b[field]): differences.append([a['file'], field])
        actor_a, actor_b = dict(a['actor_address']), dict(b['actor_address'])
        height_a, height_b = actor_a.pop('height'), actor_b.pop('height')
        assert equal(actor_a, actor_b)
        height_difference = abs(height_a - height_b)
        if height_difference > 1e-6:
            # Public load can release the actor between two physics steps.
            # Compare fixed cameras strictly; report small initial/reload settling.
            assert height_difference <= 0.10
            actor_settlement.append({'file': a['file'], 'gl_height_m': height_a,
                                      'forward_height_m': height_b, 'difference_m': height_difference})
        # The observer snapshot's exposure_result is the last physics call;
        # authoritative weather values are compared independently of that call.
        weather_a = {k: v for k, v in a['snapshot'].items() if k != 'exposure_result'}
        weather_b = {k: v for k, v in b['snapshot'].items() if k != 'exposure_result'}
        if not equal(weather_a, weather_b): differences.append([a['file'], 'weather'])
    assert not differences, differences
    focused = args.artifacts / 'r33-07-focused' / 'focused'
    results = read(focused / 'results.json')
    assert results['passed'] and results['provenance']['reusable']
    assert results['source']['commit'] == binding['measured_qa_head'] and results['source']['tree'] == binding['measured_qa_tree']
    for check in results['checks']:
        assert check['passed']
        if 'log_sha256' in check: assert digest(focused / (check['name'] + '.log')) == check['log_sha256']
    log = (focused / 'r33_07_extreme_weather_test.log').read_text()
    work = next(json.loads(line) for line in log.splitlines() if line.startswith('{') and 'R33_07_WORK_EVIDENCE' in line)
    assert work['passed'] and not work['failures'] and work['held_member']['cargo'] == 'wood'
    assert work['order_after_resume'] == 'wood' and work['wood_after_resume'] > work['wood_before_hold']
    assert '241 checks;' in log and 'future: true' in log
    phases = {phase: sum(row['snapshot'].get('storm_phase') == phase for row in left['rows'][:27])
              for phase in ['calm', 'warning', 'rising', 'peak', 'falling']}
    report = {'schema': 1, 'passed': True, 'measured_qa_head': binding['measured_qa_head'],
              'measured_qa_tree': binding['measured_qa_tree'], 'owned_byte_bindings': len(binding['owned_files']),
              'compared_rows': 35, 'comparison_differences': differences, 'sequence_phases': phases,
              'actor_settlement': actor_settlement, 'actor_height_tolerance_m': 0.10,
              'focused_tests': results['selected_tests'], 'checks': [{k:v for k,v in x.items() if k in ['name','passed','seconds','log_sha256']} for x in results['checks']],
              'work_evidence': work, 'native': [{k:v for k,v in x.items() if k != 'rows'} for x in runs],
              'target_pc_acceptance': False}
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'passed': True, 'compared_rows': 35, 'owned_byte_bindings': len(binding['owned_files'])}))

if __name__ == '__main__':
    main()
