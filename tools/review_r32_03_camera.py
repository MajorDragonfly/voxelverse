#!/usr/bin/env python3
"""Native camera evidence; capped wall-clock rendering and production physics.

Run under the round's exclusive heavy slot. No --fixed-fps, counterfactual
pivot, changed collision, survival protection or deadline overrides.
"""
import argparse
import hashlib
import json
import platform
from pathlib import Path
import statistics
import subprocess
import tempfile

from validate_godot import ERROR
from validation_support import isolated_env


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summarize(trace):
    rows = trace['rows']
    events = []
    for previous, row in zip(rows, rows[1:]):
        rise = row['body'][1] - previous['body'][1]
        if row['phase'] in ['up + fall', 'down'] and abs(rise) > .3:
            events.append({'phase': row['phase'], 'time_s': row['time_s'],
                           'body_rise_m': rise,
                           'target_rise_m': row['pivot'][1] - previous['pivot'][1],
                           'camera_rise_m': row['camera'][1] - previous['camera'][1],
                           'grounded': row['floor'], 'gap_m': row['floor_gap_m']})
    steps = [e for e in events if e['phase'] == 'up + fall' and e['body_rise_m'] > .3]
    down = [e for e in events if e['phase'] == 'down']
    down_rows = [r for r in rows if r['phase'] == 'down']
    descent_height = max(r['body'][1] for r in down_rows)-min(r['body'][1] for r in down_rows) if down_rows else 0
    intervals = [(b['wall_us'] - a['wall_us']) / 1000
                 for a, b in zip(trace['render_frames'], trace['render_frames'][1:])]
    ordered = sorted(intervals)
    quantile = lambda p: ordered[round((len(ordered)-1)*p)] if ordered else 0
    grounded = [abs(r['capsule_support_gap_m']) for r in rows if r['floor'] and r['capsule_support_gap_m'] is not None]
    jump = [r['body'][1] for r in rows if r['phase'].startswith('jump')]
    springs = [r['spring_m'] for r in rows if r['phase'] in ['up + fall', 'down']]
    settled = [abs(r['offset_m']) for r in rows if r['phase'] == 'rebase + settle']
    origin_peak = max((sum((b['camera'][i]-a['camera'][i])**2 for i in range(3))**.5
                      for a,b in zip(rows, rows[1:]) if b['phase']=='rebase + settle'), default=0)
    rendered_origin_peak = max((sum((b['camera'][i]-a['camera'][i])**2 for i in range(3))**.5
                      for a,b in zip(trace['render_frames'], trace['render_frames'][1:])
                      if b['phase']=='rebase + settle'), default=0)
    native_intervals = [r['delta_s'] * 1000 for r in trace['native_render_frames'] if r['delta_s'] > 0]
    native_ordered = sorted(native_intervals)
    native_quantile = lambda p: native_ordered[round((len(native_ordered)-1)*p)] if native_ordered else 0
    checks = {'three_full_steps': len(steps) == 3,
              'up_target_bounded': bool(steps) and max(abs(e['target_rise_m']) for e in steps) < .22,
              'descent_exercised': descent_height > 1.4,
              'grounded_contact': bool(grounded) and max(grounded) < .12,
              'jump_exercised': bool(jump) and max(jump)-min(jump) > .7,
              'spring_collision_exercised': bool(springs) and .1 < min(springs) < 6.5,
              'settled': bool(settled) and max(settled) < .002,
              'origin_shift_exercised': any(r['rebases'] > 0 for r in rows),
              'origin_camera_stable': origin_peak < .01 and rendered_origin_peak < .01,
              'fixture_passed': trace['passed']}
    return {'checks': checks, 'passed': all(checks.values()), 'step_events': events,
            'target_up_peak_m': max((abs(e['target_rise_m']) for e in steps), default=0),
            'target_down_peak_m': max((abs(b['pivot'][1]-a['pivot'][1]) for a,b in zip(rows, rows[1:]) if a['phase']==b['phase']=='down'), default=0),
            'descent_height_m': descent_height,
            'grounded_gap_max_m': max(grounded, default=0),
            'jump_rise_m': max(jump)-min(jump) if jump else 0,
            'spring_min_m': min(springs, default=0),
            'origin_camera_peak_m': origin_peak,
            'rendered_origin_camera_peak_m': rendered_origin_peak,
            'captured_fps_median': 1000/statistics.median(intervals) if intervals else 0,
            'native_render_fps_median': 1000/statistics.median(native_intervals) if native_intervals else 0,
            'native_render_interval_ms': {'p50': native_quantile(.5), 'p95': native_quantile(.95), 'p99': native_quantile(.99), 'max': max(native_intervals, default=0)},
            'capture_interval_ms': {'p50': quantile(.5), 'p95': quantile(.95), 'p99': quantile(.99), 'max': max(intervals, default=0)},
            'frames': len(trace['render_frames']), 'physics_ticks': len(rows)}


def encode(directory, frames):
    # Preserve actual capture timing; do not label a slow 120 cap as 120 FPS.
    concat = directory/'frames.txt'
    lines = []
    for index, frame in enumerate(frames):
        duration = ((frames[index+1]['wall_us'] - frame['wall_us']) / 1e6
                    if index+1 < len(frames) else 1/30)
        # Each image demuxer must use a fine time base. Its default 25 Hz
        # otherwise quantizes the concat durations and silently drops frames.
        lines += [f"file 'frame_{index:05d}.png'", 'option framerate 1000', f'duration {duration:.8f}']
    lines += [f"file 'frame_{len(frames)-1:05d}.png'", 'option framerate 1000']
    concat.write_text('\n'.join(lines)+'\n')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', str(concat),
                    '-fps_mode', 'vfr', '-c:v', 'libx264', '-threads', '2', '-crf', '22',
                    '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(directory/'film.mp4')], check=True)
    stream = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-count_frames', '-select_streams', 'v:0',
                        '-show_entries', 'stream=nb_read_frames,duration,time_base,avg_frame_rate', '-of', 'json',
                        str(directory/'film.mp4')], text=True))['streams'][0]
    if int(stream['nb_read_frames']) != len(frames) + 1:
        raise RuntimeError(f'Encoding changed captured frame count: {stream}')
    # Keep representative original frames and the lossless numeric trace.
    for index in [0, len(frames)//3, 2*len(frames)//3, len(frames)-1]:
        (directory/f'frame_{index:05d}.png').rename(directory/f'view-{index:05d}.png')
    for path in directory.glob('frame_*.png'): path.unlink()
    concat.unlink()
    return stream


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--renderer', choices=['gl_compatibility', 'forward_plus'], required=True)
    parser.add_argument('--case', action='append', default=[])
    parser.add_argument('--collect-negatives', action='store_true',
                        help='Record every negative reference case; aggregate exit status remains failure.')
    parser.add_argument('--script', choices=['res://tools/review_r32_03_frames.gd', 'res://tools/review_r32_03_closeup.gd'],
                        default='res://tools/review_r32_03_frames.gd')
    args = parser.parse_args()
    project = args.project.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([args.godot, '--version'], text=True).strip()
    if version != '4.6.3.stable.official.7d41c59c4': raise RuntimeError(version)
    runtime_paths = ['creatures/player/player_controller.gd', 'creatures/player/player_controller_v2.gd',
                     'creatures/player/spherical_campaign_player.gd', 'creatures/player/player.tscn',
                     'world/surface/gameplay_space.gd', 'world/surface/radial_surface_adapter.gd',
                     'creatures/runtime/adaptive_locomotion_animator.gd',
                     'creatures/runtime/adaptive_locomotion_animator_v2.gd']
    report = {'engine': version, 'renderer': args.renderer, 'host': platform.node(), 'system': platform.platform(),
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip(),
              'source_tree': subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], cwd=project, text=True).strip(),
              'runtime_sha256': {p: sha(project/p) for p in runtime_paths},
              'probe_sha256': {p: sha(project/p) for p in ['tests/r32_03_step_fixture.gd', 'tools/review_r32_03_frames.gd', 'tools/review_r32_03_camera.py']},
              'limits': ['Physical box fixture, active spherical player and real radial adapter; no generated campaign terrain.',
                         'Native max_fps caps; measured actual frame intervals include PNG readback; encoding occurs afterward.',
                         'Production physics remains 60 Hz and production capsule unchanged for both visible body scales.',
                         'Software GPU/container results do not establish target-PC performance or visual acceptance.'], 'cases': []}
    report['probe_sha256'][args.script.removeprefix('res://')] = sha(project/args.script.removeprefix('res://'))
    for cap in [30, 60, 120]:
        for size in [.65, 1.5]:
            for approach in ['straight', 'diagonal']:
                case = f'{cap}cap-{size}-{approach}'
                if args.case and case not in args.case: continue
                directory = output/case
                directory.mkdir(exist_ok=True)
                command = [args.godot, '--path', str(project), '--rendering-method', args.renderer,
                           '--audio-driver', 'Dummy', '--disable-vsync', '--script', args.script,
                           '--', str(cap), str(size), approach, str(directory)]
                with tempfile.TemporaryDirectory(prefix='r32-03-user-') as tmp:
                    env = isolated_env(Path(tmp))
                    env['LP_NUM_THREADS'] = '2'
                    with (directory/'render.log').open('w') as log:
                        result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
                text = (directory/'render.log').read_text()
                trace_path = directory/'trace.json'
                entry = {'case': case, 'command': command, 'exit_code': result.returncode,
                         'log_sha256': sha(directory/'render.log')}
                if trace_path.exists():
                    trace = json.loads(trace_path.read_text())
                    entry.update(summarize(trace))
                    entry['trace_sha256'] = sha(trace_path)
                    entry['encoded_stream'] = encode(directory, trace['render_frames'])
                    entry['video_sha256'] = sha(directory/'film.mp4')
                entry['passed'] = bool(entry.get('passed')) and result.returncode == 0 and not ERROR.search(text)
                report['cases'].append(entry)
                report['passed'] = all(e['passed'] for e in report['cases'])
                (output/'results.json').write_text(json.dumps(report, indent=2)+'\n')
                print(json.dumps({k:v for k,v in entry.items() if k not in ['command','step_events']}), flush=True)
                if not entry['passed'] and not args.collect_negatives:
                    raise RuntimeError(f'Negative camera case: {case}; original trace retained')
    if not report['cases']: raise RuntimeError('No case matched; no evidence produced')
    return 0 if report['passed'] else 1


if __name__ == '__main__': raise SystemExit(main())
