#!/usr/bin/env python3
"""Summarize original R32-09 captures; never infer a hardware/visual pass."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    folder = args.directory.resolve()
    capture = json.loads((folder / 'campaign/capture.json').read_text())
    rows = []
    for sample in capture['samples']:
        if 'before' not in sample:
            continue
        images = [np.asarray(Image.open(folder / 'campaign' / sample[v]['file']).convert('RGB'), dtype=np.float32)
                  for v in ['before', 'after']]
        difference = np.abs(images[0]-images[1])/255
        row = {k: sample[k] for k in ['family', 'phase', 'distance_m']}
        row['paired_mean_rgb_difference'] = float(difference.mean())
        for version in ['before', 'after']:
            data = sample[version]
            for metric in ['wall_ms', 'cpu_ms', 'gpu_ms']:
                values = data['raw_' + ('wall_ms' if metric == 'wall_ms' else metric)]
                # Zero viewport timestamps mean unavailable on this backend.
                row[version + '_' + metric + '_median'] = data[metric]['median'] if any(values) else None
            row[version + '_draw_calls'] = data['draw_calls']
            row[version + '_primitives'] = data['primitives']
        rows.append(row)
    before = {(x['family'], x['index']): x for x in capture['motion'] if x['version'] == 'before'}
    after = {(x['family'], x['index']): x for x in capture['motion'] if x['version'] == 'after'}
    assert before.keys() == after.keys()
    for key, old in before.items():
        new = after[key]
        assert old['camera'] == new['camera'] and old['light'] == new['light'], key
    with (folder / 'frame-costs.csv').open('w') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    summary = {'renderer': capture['renderer'], 'adapter': capture['adapter'], 'rows': rows,
               'paired_motion_poses': len(before), 'wind': json.loads((folder / 'wind/capture.json').read_text()),
               'capture_completed': capture.get('complete', False), 'capture_passed': capture['passed'],
               'target_pc_accepted': False,
               'limits': 'Eight frames per view; whole-campaign software timings, fixed before/after order, no hardware regression or isolated shader GPU cost. Camera-only motion is not physical walking. Final combined light/LOD/wind acceptance remains separate.'}
    (folder / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    files = [{'file': str(p.relative_to(folder)), 'bytes': p.stat().st_size,
              'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
             for p in sorted(folder.rglob('*')) if p.is_file() and p.name != 'artifact-manifest.json']
    (folder / 'artifact-manifest.json').write_text(json.dumps(files, indent=2) + '\n')
    print(json.dumps({'views': len(rows), 'paired_motion_poses': len(before), 'scope': summary['limits']}))


if __name__ == '__main__':
    main()
