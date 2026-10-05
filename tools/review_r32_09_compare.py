#!/usr/bin/env python3
"""Check fixed-save/camera/sun comparability of two original native captures."""
import argparse
import json
import math
from pathlib import Path
import re


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('compatibility', type=Path)
    parser.add_argument('forward_plus', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    captures = [json.loads((p / 'campaign/capture.json').read_text())
                for p in [args.compatibility, args.forward_plus]]
    failures = []

    def same(a, b, path, tolerance=1e-6):
        if isinstance(a, dict) and isinstance(b, dict):
            if a.keys() != b.keys():
                failures.append(path + ': different keys')
                return
            for k in a:
                same(a[k], b[k], path + '/' + k, tolerance)
        elif isinstance(a, list) and isinstance(b, list):
            if len(a) != len(b):
                failures.append(path + ': different sizes')
                return
            for i, (x, y) in enumerate(zip(a, b)):
                same(x, y, path + '/' + str(i), tolerance)
        elif isinstance(a, (int, float)) and isinstance(b, (int, float)):
            if not math.isclose(a, b, rel_tol=0, abs_tol=tolerance):
                failures.append(f'{path}: {a} != {b}')
        elif a != b:
            failures.append(f'{path}: {a!r} != {b!r}')

    gl, fp = captures
    for capture, renderer in zip(captures, ['gl_compatibility', 'forward_plus']):
        if not capture.get('complete') or not capture.get('passed'):
            failures.append(renderer + ': incomplete/negative capture')
        same(capture['renderer'], renderer, renderer + '/backend')
    for key in ['seed', 'initial_save_sha256', 'resolution', 'campaign_scene']:
        same(gl[key], fp[key], key, 0)
    same(gl['body']['id'], fp['body']['id'], 'body_id', 0)
    same(gl['frozen_weather'], fp['frozen_weather'], 'weather')

    def static(capture):
        return {(s['family'], s['phase'], s['distance_m']): s
                for s in capture['samples'] if 'before' in s}

    left, right = static(gl), static(fp)
    same(sorted(left), sorted(right), 'view_keys', 0)
    if len(left) != 12 or len(right) != 12:
        failures.append('Expected twelve complete family/day/distance pairs per backend')
    fields = ['fov', 'origin', 'target', 'camera']
    number = re.compile(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')
    for key in left.keys() & right.keys():
        a, b = left[key], right[key]
        label = '/'.join(map(str, key))
        for field in fields:
            if field == 'camera':
                # Serialized Transform3D, absolute 10-micrometre tolerance.
                same([float(x) for x in number.findall(a[field])],
                     [float(x) for x in number.findall(b[field])], label + '/camera', 1e-5)
            elif field == 'target':
                # Angular values: 1e-10 is <1 mm on this 6371-km body.
                for k in a[field]:
                    same(a[field][k], b[field][k], label + '/target/' + k,
                         1e-10 if k in ['u', 'v'] else 1e-4)
            else:
                same(a[field], b[field], label + '/' + field)
        # Preserve normal backend energy as evidence; compare controlled light.
        same({k: v for k, v in a['light'].items() if k != 'production_energy'},
             {k: v for k, v in b['light'].items() if k != 'production_energy'}, label + '/light')
        for capture_sample in [a, b]:
            same(capture_sample['before']['draw_calls'], capture_sample['after']['draw_calls'], label + '/paired_draw_calls', 0)
            same(capture_sample['before']['primitives'], capture_sample['after']['primitives'], label + '/paired_primitives', 0)
    result = {'script_sha256': __import__('hashlib').sha256(Path(__file__).read_bytes()).hexdigest(),
              'passed': not failures, 'failures': failures, 'paired_views': len(left),
              'source_directories': [str(args.compatibility), str(args.forward_plus)],
              'initial_save_sha256': gl['initial_save_sha256'], 'target_pc_accepted': False,
              'scope': 'Fixed identity, canonical targets, cameras and controlled physical light; renderer-specific lighting/shadow implementation is not equal-image acceptance.'}
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
    raise SystemExit(0 if result['passed'] else 1)


if __name__ == '__main__':
    main()
