#!/usr/bin/env python3
"""Prepare/replay one real saved campaign; preserve negative capture evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import time

from validate_godot import ERROR
from validation_support import isolated_env, validation_editor


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--mode', choices=['prepare', 'capture'], required=True)
    parser.add_argument('--fixture', type=Path, help='Prepared report directory; exact user-data copy')
    parser.add_argument('--renderer', choices=['gl_compatibility', 'forward_plus'], default='gl_compatibility')
    args = parser.parse_args()
    project = args.project.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    if output.is_relative_to(project):
        parser.error('Evidence must be outside the source checkout')
    if args.mode == 'capture' and args.fixture is None:
        parser.error('Capture requires the exact prepared fixture')
    source = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip(),
              'tree': subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], cwd=project, text=True).strip(),
              'status': subprocess.check_output(['git', 'status', '--porcelain'], cwd=project, text=True).strip(),
              'files': {name: hashlib.sha256((project / name).read_bytes()).hexdigest()
                        for name in ['world/tribe/village_work_motion.gd', 'world/tribe/village_visuals.gd',
                                     'tools/review_r32_17_campaign.gd', 'tools/review_r32_17_start.gd',
                                     'assets/catalog/planet_foliage.gdshader',
                                     'world/surface/visuals/living_water.gdshader']}}
    (output / 'source.json').write_text(json.dumps(source, indent=2) + '\n')
    start = time.monotonic()
    with tempfile.TemporaryDirectory(prefix='r32-17-user-') as temp:
        user = Path(temp) / 'userdata'
        if args.fixture:
            shutil.copytree(args.fixture.resolve() / 'fixture', user)
        else:
            user.mkdir()
        env = isolated_env(user)
        env['LP_NUM_THREADS'] = '2'
        config = {'mode': args.mode, 'output': str(output)}
        config_path = Path(temp) / 'config.json'
        config_path.write_text(json.dumps(config))
        command = [args.godot, '--path', str(project), '--audio-driver', 'Dummy', '--fixed-fps', '30',
                   '--resolution', '960x540']
        command += ['--headless'] if args.mode == 'prepare' else ['--rendering-method', args.renderer]
        command += ['--script', 'res://tools/review_r32_17_start.gd', '--', '--motion-config', str(config_path)]
        with validation_editor(args.godot) as editor:
            command[0] = str(editor)
            try:
                with (output / 'engine.log').open('w') as log:
                    result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=600)
                exit_code = result.returncode
            except subprocess.TimeoutExpired:
                exit_code = 124
        shutil.copytree(user, output / 'fixture')
    capture = json.loads((output / 'capture.json').read_text()) if (output / 'capture.json').exists() else {}
    text = (output / 'engine.log').read_text()
    report = {'passed': exit_code == 0 and not ERROR.search(text) and capture.get('passed', False),
              'exit_code': exit_code, 'command': command, 'wall_seconds': time.monotonic() - start,
              'host': platform.node(), 'environment': capture.get('environment'),
              'fixture': str(args.fixture) if args.fixture else None,
              'fixture_digest': fixture_digest(args.fixture / 'fixture') if args.fixture else None,
              'source': source, 'checks': capture.get('checks', []),
              'limits': capture.get('limits', []), 'target_pc_acceptance': False}
    frames = capture.get('frames', [])
    if frames:
        for metric in ['draw_wait_us', 'readback_png_us']:
            values = sorted(row[metric] / 1000 for row in frames)
            report[metric] = {'samples': len(values), 'p50_ms': values[int((len(values) - 1) * .50)],
                              'p95_ms': values[int((len(values) - 1) * .95)],
                              'p99_ms': values[int((len(values) - 1) * .99)], 'max_ms': max(values)}
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-framerate', '30', '-i', str(output / 'frame_%04d.png'),
                        '-c:v', 'libx264', '-threads', '2', '-crf', '22', '-pix_fmt', 'yuv420p',
                        '-movflags', '+faststart', str(output / 'film.mp4')], check=True)
        for stage in dict.fromkeys(row['stage'] for row in frames):
            row = next(row for row in frames if row['stage'] == stage)
            shutil.copy2(output / f"frame_{row['index']:04d}.png", output / f'{stage}.png')
        # Originals remain intact in the external report until delivery.
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({key: report[key] for key in ['passed', 'exit_code', 'wall_seconds', 'host']}, indent=2))
    if not report['passed']:
        print(text[-3500:])
    return 0 if report['passed'] else 1


def fixture_digest(root):
    rows = [(path.relative_to(root).as_posix(), hashlib.sha256(path.read_bytes()).hexdigest())
            for path in sorted(root.rglob('*')) if path.is_file()]
    return hashlib.sha256(json.dumps(rows).encode()).hexdigest()


if __name__ == '__main__':
    raise SystemExit(main())
