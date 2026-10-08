#!/usr/bin/env python3
"""Read raw route/phase evidence; preserve failed, incomplete and mixed-host runs."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

from performance_route_report import summarize


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def union_ms(intervals):
    total = 0
    start = end = None
    for left, right in sorted(intervals):
        if start is None:
            start, end = left, right
        elif left <= end:
            end = max(end, right)
        else:
            total += end - start
            start, end = left, right
    if start is not None:
        total += end - start
    return total / 1000.0


def frame_phases(frames, work):
    result = []
    previous = None
    for frame in frames:
        end = int(frame['tick_us'])
        begin = previous if previous is not None else end - round(float(frame['frame_ms']) * 1000)
        previous = end
        if frame['stage'] not in ('walk_outward', 'walk_return') or float(frame['frame_ms']) <= 33:
            continue
        overlap = []
        intervals = []
        for item in work:
            left = max(begin, int(item['started_us']))
            right = min(end, int(item['finished_us']))
            if right > left:
                overlap.append({'kind': item['kind'], 'label': item['label'],
                                'overlap_ms': (right - left) / 1000.0,
                                'full_interval_ms': item['ms']})
                intervals.append((left, right))
        result.append({'cycle': int(frame['cycle']), 'stage': frame['stage'], 'tick_us': end,
                       'frame_ms': float(frame['frame_ms']), 'work': overlap,
                       'observed_work_union_ms': union_ms(intervals)})
    return result


def collect(directory, host_path):
    capture_path = directory / 'capture.json'
    summary_path = directory / 'performance.json'
    capture_written = capture_path.is_file()
    capture = json.loads((capture_path if capture_written else summary_path).read_text()) if capture_written or summary_path.is_file() else {}
    host = [json.loads(line) for line in host_path.read_text().splitlines()]
    start = next((item for item in host if item.get('event') == 'start'), {})
    finish = next((item for item in reversed(host) if item.get('event') == 'end'), {})
    outcomes = {(int(item['cycle']), item['stage']) for item in capture.get('segments', [])}
    reasons = []
    rows = []
    frame_path = directory / 'frames.csv'
    if frame_path.is_file():
        try:
            rows = summarize(directory, capture)
        except ValueError as error:
            reasons.append(str(error))
    else:
        reasons.append('No raw frame file written')
    for row in rows:
        outcome = 'route_outcome' if row['stage'] == 'walk_outward' else 'return_outcome'
        row['complete'] = (row['cycle'], outcome) in outcomes
    readiness = capture.get('readiness', {})
    work = [item for value in readiness.values() for item in value.get('work', [])]
    phases = []
    if frame_path.is_file():
        with frame_path.open(newline='') as source:
            phases = frame_phases(list(csv.DictReader(source)), work)
    if not capture_written:
        reasons.append('No final capture written; retained wrapper/partial evidence only')
    if not start.get('slot_comment_url'):
        reasons.append('No independent R33-01 slot confirmation recorded')
    if any(item.get('foreign_godot') or item.get('foreign_godot_observed') for item in host):
        reasons.append('Foreign Godot load observed')
    if finish.get('exit_code') != 0 or not capture.get('passed') or capture.get('failures'):
        reasons.append('Failed/unfinished process or protocol')
    if finish.get('source_unchanged') is False:
        reasons.append('Measured source changed during the section')
    recipe = capture.get('recipe', {})
    expected = {(cycle, stage) for cycle in range(int(recipe.get('cycles', 0)))
                for stage in ('walk_outward', 'walk_return')}
    if not expected or {(row['cycle'], row['stage']) for row in rows} != expected or not all(row['complete'] for row in rows):
        reasons.append('Incomplete movement stage')
    if (capture.get('source') or {}).get('dirty') is not False:
        reasons.append('Measured source was not clean')
    if any(value.get('dropped', 0) or value.get('work_dropped', 0) for value in readiness.values()):
        reasons.append('Phase/readiness trace overflow')
    return {'host': start.get('host'), 'slot_comment_url': start.get('slot_comment_url'),
            'source': capture.get('source'), 'passed': capture.get('passed'),
            'failures': capture.get('failures'), 'blockage': capture.get('blockage'),
            'capture_written': capture_written, 'host_exit_code': finish.get('exit_code'),
            'measurement_error': capture.get('error'), 'startup_timeout': capture.get('startup_timeout'),
            'cpu': capture.get('cpu'), 'godot': capture.get('godot'),
            'renderer': capture.get('renderer'), 'adapter': capture.get('adapter'),
            'recipe': recipe,
            'initial_save_sha256': recipe.get('replay_input_save_sha256', digest(capture.get('initial_save'))),
            'save_fingerprint_scope': 'actual replay input' if 'replay_input_save_sha256' in recipe else 'captured output; not proof of replay input',
            'route_rows': rows, 'frames_over_33_with_phases': phases,
            'readiness': readiness, 'controlled_comparison_blockers': reasons,
            'publication_coverage': {str(cycle): {
                'animals': capture.get(f'world_{cycle}', {}).get('active_animals'),
                'plants': capture.get(f'world_{cycle}', {}).get('active_plants')}
                for cycle in range(int(recipe.get('cycles', 0)))},
            'process_rss_peak_bytes': max((item.get('peak_rss_bytes') or 0 for item in capture.get('snapshots', [])), default=0),
            'target_pc_acceptance': False}


def compare(before, after):
    blockers = list(before['controlled_comparison_blockers']) + list(after['controlled_comparison_blockers'])
    for key in ('host', 'cpu', 'godot', 'renderer', 'adapter', 'recipe', 'initial_save_sha256'):
        if before.get(key) != after.get(key):
            blockers.append(f'Different {key}')
    if before.get('publication_coverage') != after.get('publication_coverage'):
        blockers.append('Different published population coverage; delayed or reduced work is not a gain')
    old = {(row['cycle'], row['stage']): row for row in before['route_rows']}
    new = {(row['cycle'], row['stage']): row for row in after['route_rows']}
    if old.keys() != new.keys():
        blockers.append('Different movement stages')
    deltas = []
    for key in sorted(old.keys() & new.keys()):
        left, right = old[key], new[key]
        metrics = {name: right[name] - left[name] for name in ('p50_ms', 'p95_ms', 'p99_ms', 'max_ms')}
        spikes = {threshold: right['spikes_over_ms'][threshold] - left['spikes_over_ms'][threshold]
                  for threshold in ('33', '50', '100')}
        deltas.append({'cycle': key[0], 'stage': key[1], 'metric_delta_ms': metrics,
                       'spike_count_delta': spikes, 'regression': any(value > 0 for value in [*metrics.values(), *spikes.values()])})
    return {'controlled_comparison_allowed': not blockers, 'blockers': sorted(set(blockers)),
            'same_tree_repeat': bool((before.get('source') or {}).get('tree')) and (before.get('source') or {}).get('tree') == (after.get('source') or {}).get('tree'),
            'deltas': deltas,
            'note': 'Nested phase intervals are observations; sum the union, never parent plus child. A valid comparison alone does not prove a product cause or target-PC improvement.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', nargs=3, action='append', metavar=('LABEL', 'DIRECTORY', 'HOST_JSONL'), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if len({label for label, _, _ in args.run}) != len(args.run):
        parser.error('Each label must be unique')
    runs = {label: collect(Path(directory), Path(host)) for label, directory, host in args.run}
    report = {'scope': 'Software process-frame/phase evidence; no GPU upload or hardware acceptance claim.',
              'target_pc_acceptance': False, 'runs': runs}
    if len(runs) == 2:
        report['comparison'] = compare(*runs.values())
    with args.output.open('x') as output:
        json.dump(report, output, indent=2)
        output.write('\n')


if __name__ == '__main__':
    main()
