#!/usr/bin/env python3
"""Derive pairwise measurements from the retained native camera traces.

Original results/films are never rewritten. Downward peaks use every adjacent
physics sample; the first capture runner incorrectly reported only >0.3 m
body-step events, which omitted continuous descent. Caps are not achieved FPS.
"""
import argparse
import csv
import hashlib
import json
import statistics
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def measurements(trace, case):
    rows = trace['rows']
    native = trace['native_render_frames']
    wall = sorted((b['wall_us'] - a['wall_us']) / 1000 for a,b in zip(native,native[1:]))
    def peak(field, phase):
        return max((abs(b[field][1] - a[field][1]) for a, b in zip(rows, rows[1:])
                    if a['phase'] == b['phase'] == phase), default=0)
    return {'passed': case['passed'], 'full_step_count': sum(
            b['body'][1] - a['body'][1] > .3 and b['phase'] == 'up + fall'
            for a, b in zip(rows, rows[1:])),
            'up_target_at_step_m': case['target_up_peak_m'],
            'up_camera_peak_m': peak('camera', 'up + fall'),
            'down_body_peak_m': peak('body', 'down'),
            'down_target_peak_m': peak('pivot', 'down'),
            'down_camera_peak_m': peak('camera', 'down'),
            'grounded_capsule_gap_m': case['grounded_gap_max_m'],
            'jump_excursion_m': case['jump_rise_m'], 'spring_min_m': case['spring_min_m'],
            'settled_offset_m': max(abs(r['offset_m']) for r in rows if r['phase'] == 'rebase + settle'),
            'origin_physics_camera_peak_m': max((sum((b['camera'][i]-a['camera'][i])**2 for i in range(3))**.5
                for a,b in zip(rows, rows[1:]) if b['phase']=='rebase + settle'), default=0),
            'origin_render_camera_peak_m': max((sum((b['camera'][i]-a['camera'][i])**2 for i in range(3))**.5
                for a,b in zip(trace['render_frames'],trace['render_frames'][1:])
                if b['phase']=='rebase + settle' and 'camera' in a and 'camera' in b),default=0)
                if all('camera' in r for r in trace['render_frames']) else None,
            'native_fps_median': 1000 / statistics.median(wall),
            'engine_delta_fps_median': case['native_render_fps_median'],
            'captured_fps_median': case['captured_fps_median'],
            'native_interval_p95_ms': wall[round((len(wall)-1)*.95)],
            'native_interval_max_ms': max(wall),
            'engine_delta_interval_max_ms': case['native_render_interval_ms']['max']}


def inspect(directory, renderer):
    reports = {label: json.loads((directory / label / 'results.json').read_text())
               for label in ['baseline', 'candidate']}
    a, b = reports.values()
    assert a['probe_sha256'] == b['probe_sha256'], 'Comparison probes differ'
    changed = [p for p in a['runtime_sha256'] if a['runtime_sha256'][p] != b['runtime_sha256'][p]]
    assert changed == ['creatures/player/player_controller.gd'], changed
    result = []
    for label, report in reports.items():
        for case in report['cases']:
            folder = directory / label / case['case']
            for key, name in [('log_sha256', 'render.log'), ('trace_sha256', 'trace.json'),
                              ('video_sha256', 'film.mp4')]:
                assert digest(folder / name) == case[key], str(folder / name)
            trace = json.loads((folder / 'trace.json').read_text())
            result.append({'renderer': renderer, 'source': label, 'case': case['case'],
                           **measurements(trace, case)})
    checks_path = directory / 'checks/results.json'
    if checks_path.exists():
        checks = json.loads(checks_path.read_text())
        assert checks['passed'] and checks['provenance']['reusable']
        for check in checks['checks']:
            if 'log_sha256' in check:
                assert digest(directory / 'checks' / (check['name'] + '.log')) == check['log_sha256']
        for manifest in checks['provenance']['manifests'].values():
            assert digest(directory / 'checks' / manifest['path']) == manifest['sha256']
    return result, reports


def plot(directory, output, approach):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, axes = plt.subplots(3, 2, figsize=(12, 8), sharex=True)
    for col, label in enumerate(['baseline', 'candidate']):
        trace = json.loads((directory / label / f'60cap-1.5-{approach}/trace.json').read_text())
        rows = trace['rows']
        time = [r['time_s'] for r in rows]
        for field, name, color in [('body', 'Kapsel', '#2468a0'), ('pivot', 'Kameraziel', '#dc7928'),
                                   ('visual', 'Sichtbarer Koerper', '#398956')]:
            initial = rows[0][field][1]
            axes[0, col].plot(time, [r[field][1] - initial for r in rows], label=name, color=color, linewidth=1.3)
        axes[0, col].set_title('Referenz (gerade blockiert)' if col == 0 and approach == 'straight'
                               else 'Referenz' if col == 0 else 'Owner-Kandidat')
        axes[1, col].plot(time, [r['camera'][1] - rows[0]['camera'][1] for r in rows], label='Echte Kamera: Hoehenbewegung', color='#775c9c')
        axes[1, col].plot(time, [r['offset_m'] for r in rows], label='Stufenkorrektur-Versatz', color='#dc7928')
        axes[2, col].step(time, [int(r['floor']) for r in rows], where='post', label='Physischer Bodenkontakt', color='#2468a0')
        axes[2, col].plot(time, [r['capsule_support_gap_m'] for r in rows], label='Kapsel-Unterseite: Abstand (m)', color='#398956')
        for ax in axes[:, col]:
            ax.grid(alpha=.2)
            ax.legend(fontsize=8, loc='upper right')
        axes[2, col].set_xlabel('Physikzeit (s); 60 Hz, Sprung/Fall/Abstieg/Ursprungwechsel im selben Lauf')
    axes[0, 0].set_ylabel('Hoehenbewegung (m)')
    axes[1, 0].set_ylabel('Kamerabewegung / Versatz (m)')
    axes[2, 0].set_ylabel('Kontakt (0/1), Abstand (m)')
    report = json.loads((directory / 'candidate/results.json').read_text())
    case = next(c for c in report['cases'] if c['case'] == f'60cap-1.5-{approach}')
    fps = measurements(json.loads((directory / 'candidate' / case['case'] / 'trace.json').read_text()), case)['native_fps_median']
    fig.suptitle(f'R32-03 | GL | {approach} | 1.5x sichtbarer Koerper | 60 FPS-Kappung (gemessen {fps:.1f} FPS)')
    fig.tight_layout()
    fig.savefig(output / f'traces-{approach}.png', dpi=170)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gl', type=Path, required=True)
    parser.add_argument('--forward', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    rows, sources = [], {}
    for renderer, directory in [('gl_compatibility', args.gl), ('forward_plus', args.forward)]:
        values, reports = inspect(directory, renderer)
        rows.extend(values)
        sources[renderer] = {label: {k: report[k] for k in ['source_commit', 'source_tree', 'runtime_sha256', 'probe_sha256', 'engine', 'host', 'system']}
                             for label, report in reports.items()}
    (args.output / 'derived-matrix.json').write_text(json.dumps({'sources': sources, 'measurements': rows}, indent=2) + '\n')
    with (args.output / 'derived-matrix.csv').open('w', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    for approach in ['straight', 'diagonal']: plot(args.gl, args.output, approach)
    print(f'Verified and derived {len(rows)} original recordings; originals unchanged')


if __name__ == '__main__': main()
