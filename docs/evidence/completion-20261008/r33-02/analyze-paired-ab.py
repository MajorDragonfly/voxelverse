#!/usr/bin/env python3
"""Recompute aggregates/publication observations from an existing original AB report, without engines."""
import argparse
import csv
import json
import math
from pathlib import Path
import statistics

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--runs', type=Path, default=Path(__file__).resolve().parents[1])
parser.add_argument('--prefix', default='ui-matched')
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
report = json.loads((args.runs / (args.prefix + '-ab.json')).read_text())
result = {'comparison': report['comparison'], 'runs': {},
          'scope': 'Original paired headless CPU/wall-frame observation, not target-PC/GPU acceptance'}
for label in ('before', 'after'):
    run = report['runs'][label]
    with (args.runs / (args.prefix + '-' + label) / 'frames.csv').open() as source:
        values = [float(row['frame_ms']) for row in csv.DictReader(source)
                  if row['stage'] in ('walk_outward', 'walk_return') and row['frame_ms']]
    ordered = sorted(values)
    def percentile(fraction):
        return statistics.median(values) if fraction == .5 else ordered[max(0, math.ceil(len(values) * fraction) - 1)]
    row = {'aggregate': {'count': len(values), 'p50_ms': percentile(.5), 'p95_ms': percentile(.95),
                        'p99_ms': percentile(.99), 'max_ms': max(values),
                        'spikes': {str(t): sum(v > t for v in values) for t in (33, 50, 100)}},
           'publication': {}, 'rss': run['process_rss_peak_bytes'], 'recipe': run['recipe'],
           'routes': run['route_rows']}
    for cycle in ('0', '1'):
        readiness = run['readiness'][cycle]
        records = [e for e in readiness['events'] if e['kind'] == 'animals' and e['component'] == 'record']
        physical = sorted((e for e in readiness['events'] if e['kind'] == 'animals' and e['component'] == 'physical'),
                          key=lambda e: e['tick_us'])
        origin = min(e['since_population_ms'] for e in records)
        slices = [w['ms'] for w in readiness['work'] if w['label'] == 'skin_prepare_chunk']
        row['publication'][cycle] = {
            'basis': 'milliseconds after first observed animal record, sampled publication upper bound',
            'record_events': len(records), 'physical_events': len(physical),
            'first_physical_ms': round(physical[0]['since_population_ms'] - origin, 3),
            'full_12_physical_ms': round(physical[11]['since_population_ms'] - origin, 3) if len(physical) >= 12 else None,
            'skin_cpu_ms': round(sum(slices), 3), 'skin_max_ms': max(slices, default=0),
            'mesh_build_sum_ms': round(sum(w['ms'] for w in readiness['work'] if w['label'] == 'skin_build_submission'), 3),
            'physical_by_stage': {stage: sum(e['stage'] == stage for e in physical)
                                  for stage in sorted({e['stage'] for e in physical})}}
    result['runs'][label] = row
with args.output.open('x') as output:
    json.dump(result, output, indent=2)
    output.write('\n')
