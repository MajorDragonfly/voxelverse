#!/usr/bin/env python3
"""Capture identical physical stairs with/without PT17-05 pivot compensation."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import statistics
import subprocess
import tempfile

from validation_support import isolated_env
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--case', action='append', default=[],
                        help='Select e.g. 60hz-0.65-straight; omitted runs all twelve cases.')
    parser.add_argument('--capture-timeout', type=int, default=600,
                        help='Wall time for rendering a replay, independent of gameplay/test budgets.')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    evidence = []
    for fps in [30, 60, 120]:
        for size in [0.65, 1.5]:
            for approach in ['straight', 'diagonal']:
                case = f'{fps}hz-{size}-{approach}'
                if args.case and case not in args.case:
                    continue
                pair = []
                for mode in ['before', 'after']:
                    directory = output / f'{case}-{mode}'
                    directory.mkdir(exist_ok=True)
                    log_path = directory / 'render.log'
                    command = [args.godot, '--path', str(project), '--rendering-method',
                               'gl_compatibility', '--audio-driver', 'Dummy', '--fixed-fps', str(fps),
                               '--script', 'res://tools/capture_int30_camera.gd', '--',
                               str(fps), str(size), approach, mode, str(directory)]
                    with tempfile.TemporaryDirectory(prefix='int30-camera-') as temporary:
                        with log_path.open('w') as log:
                            env = isolated_env(Path(temporary))
                            env['LP_NUM_THREADS'] = '2'
                            result = subprocess.run(command, env=env,
                                                    stdout=log, stderr=subprocess.STDOUT, timeout=args.capture_timeout)
                    log_text = log_path.read_text()
                    report = json.loads((directory / 'trace.json').read_text())
                    rows = report['rows']
                    steps = [(r['body'][1] - rows[i-1]['body'][1],
                              abs(r['pivot_y'] - rows[i-1]['pivot_y']))
                             for i, r in enumerate(rows) if i and r['phase'] == 'up + fall'
                             and r['body'][1] - rows[i-1]['body'][1] > 0.30]
                    peak = max((p for _, p in steps), default=0)
                    jump_rows = [r for r in rows if r['phase'] == 'jump']
                    jump_rise = max(r['body'][1] for r in jump_rows) - min(r['body'][1] for r in jump_rows)
                    # Frame zero precedes the first SpringArm physics query.
                    spring_min = min(r['spring_length'] for r in rows if r['phase'] in ['up + fall', 'down'])
                    passed = (result.returncode == 0 and 'INT30_CAMERA_PASSED' in log_text
                              and not ERROR.search(log_text) and report['passed']
                              and len(steps) == 3 and jump_rise > 0.7 and 0.1 < spring_min < 6.5
                              and (mode == 'before' or peak < 0.25))
                    entry = {'case': case, 'mode': mode, 'passed': bool(passed),
                             'simulation_replay_hz': fps, 'visual_body_scale': size,
                             'approach': approach, 'physical_step_peak_m': max((b for b, _ in steps), default=0),
                             'camera_step_peak_m': peak, 'step_count': len(steps),
                             'jump_rise_m': jump_rise, 'spring_min_m': spring_min,
                             'capture_wall_median_ms': statistics.median(r['wall_us'] for r in rows) / 1000,
                             'command': command, 'log_sha256': hashlib.sha256(log_path.read_bytes()).hexdigest()}
                    evidence.append(entry)
                    pair.append(directory)
                    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-framerate', str(fps), '-i',
                                    str(directory/'frame_%04d.png'), '-c:v', 'libx264', '-crf', '24',
                                    '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(directory/'film.mp4')], check=True)
                    for index in [0, fps, fps*2, fps*5, fps*6, fps*8]:
                        shutil.copy2(directory/f'frame_{index:04d}.png', directory/f'view-{index:04d}.png')
                    for frame in directory.glob('frame_*.png'):
                        frame.unlink()
                    print(json.dumps(entry), flush=True)
                    if not passed:
                        raise RuntimeError(f'Camera evidence failed: {entry}')
                subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(pair[0]/'film.mp4'),
                                '-i', str(pair[1]/'film.mp4'), '-filter_complex', 'hstack=inputs=2',
                                '-c:v', 'libx264', '-threads', '2', '-crf', '24', '-pix_fmt', 'yuv420p',
                                '-movflags', '+faststart', str(output/f'{case}-comparison.mp4')], check=True)
    report = {'passed': all(e['passed'] for e in evidence), 'checks': evidence,
              'engine': 'Godot 4.6.3', 'renderer': 'OpenGL / llvmpipe',
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip(),
              'source_files': {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in [project/'creatures/player/player_controller.gd',
                                         project/'creatures/player/player_controller_v2.gd',
                                         project/'tools/capture_int30_camera.gd']},
              'limits': ['Fixed simulation replay rates are not achieved target-PC FPS.',
                         'Visual scale varies; production capsule remains unchanged.',
                         'Before is the pre-PT17-05 rigid pivot on otherwise identical common source.',
                         'Descent starts from the plateau after the independent fall/jump case.']}
    (output/'results.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    main()
