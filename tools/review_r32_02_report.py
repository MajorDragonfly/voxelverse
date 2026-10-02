#!/usr/bin/env python3
"""Summarize completed and failed R32 route segments without hiding regressions."""
import argparse
import csv
import json
from pathlib import Path

from performance_route_report import summarize


def collect(directory, host_log):
    capture = json.loads((directory / 'capture.json').read_text())
    host = [json.loads(line) for line in host_log.read_text().splitlines()]
    outcomes = {(int(s['cycle']), s['stage']) for s in capture['segments']}
    rows = summarize(directory, capture)
    for row in rows:
        outcome = 'route_outcome' if row['stage'] == 'walk_outward' else 'return_outcome'
        row['complete'] = (row['cycle'], outcome) in outcomes
    work = [entry for value in capture.get('readiness', {}).values() for entry in value.get('work', [])]
    frame_work = []
    with (directory / 'frames.csv').open(newline='') as source:
        previous = None
        for frame in csv.DictReader(source):
            end = int(frame['tick_us'])
            if previous is not None and frame['stage'].startswith('walk_') and float(frame['frame_ms']) > 50:
                stages = [item for item in work if previous < item['finished_us'] <= end]
                frame_work.append({'cycle': int(frame['cycle']), 'stage': frame['stage'],
                                   'frame_ms': float(frame['frame_ms']), 'tick_us': end, 'work': stages})
            previous = end
    readiness = {}
    for cycle, value in capture.get('readiness', {}).items():
        components = {}
        for event in value['events']:
            key = (event['kind'], event['id'], event['component'])
            components.setdefault(key, event)
        summary = []
        for kind in ('animals', 'nests', 'plants'):
            ids = {key[1] for key in components if key[0] == kind}
            waits = []
            unsampled_record = 0
            for identity in ids:
                record = components.get((kind, identity, 'record'))
                mesh = components.get((kind, identity, 'mesh'))
                if record and mesh and mesh['tick_us'] >= record['tick_us']:
                    waits.append((mesh['tick_us'] - record['tick_us']) / 1000)
                elif mesh:
                    unsampled_record += 1
            summary.append({'kind': kind, 'individuals_observed': len(ids),
                            'components': {part: sum(key[0] == kind and key[2] == part for key in components)
                                           for part in ('record', 'terrain_ready_observed', 'physical', 'mesh', 'collider', 'first_ai_step_observed')},
                            'max_record_to_mesh_observed_ms': max(waits, default=None),
                            'mesh_before_record_poll': unsampled_record})
        readiness[cycle] = {'summary': summary, 'sample_work_max_ms': value['sample_work_max_ms'],
                            'dropped': value['dropped'], 'work_dropped': value.get('work_dropped'),
                            'player': value.get('player'), 'notes': value['notes']}
    return {'recipe': capture['recipe'], 'source': capture['source'], 'passed': capture['passed'],
            'failures': capture['failures'], 'blockage': capture.get('blockage'),
            'route_rows': rows, 'readiness': readiness,
            'frames_over_50_with_work': frame_work,
            'foreign_godot_observed': any(item.get('foreign_godot') for item in host),
            'host_samples': len(host), 'cpu': capture['cpu'], 'renderer': capture['renderer'],
            'gpu_metrics_available': False if capture['renderer'] == 'headless' else None,
            'process_rss_peak_bytes': max((item.get('peak_rss_bytes') or 0 for item in capture['snapshots']), default=0),
            'target_pc_acceptance': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', nargs=3, action='append', metavar=('LABEL', 'DIRECTORY', 'HOST_JSONL'), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = {'scope': 'Short headless instrumentation; negative and contaminated runs remain negative. Tick stages explain measured population work, not whole-frame CPU/GPU causality.',
              'target_pc_acceptance': False, 'runs': {label: collect(Path(directory), Path(host)) for label, directory, host in args.run}}
    with args.output.open('x') as output:
        json.dump(report, output, indent=2)
        output.write('\n')


if __name__ == '__main__':
    main()
