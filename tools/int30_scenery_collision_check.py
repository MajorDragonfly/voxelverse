#!/usr/bin/env python3
"""Run the independent collision tests/captures before central registry integration."""
import argparse
import hashlib
import json
import os
import secrets
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun
from validate_godot import ERROR


def world_evidence_report(output):
    """Describe retained bytes; a checkpoint can never substitute completion."""
    report = {}
    for kind, name in [('final', 'int30-collision-world.json'),
                       ('checkpoint', 'int30-collision-progress.json')]:
        path = output / name
        entry = {'path': name, 'present': path.is_file(), 'valid': False,
                 'complete': False, 'passed': False}
        if entry['present']:
            try:
                contents = path.read_bytes()
                entry['sha256'] = hashlib.sha256(contents).hexdigest()
                value = json.loads(contents)
                if not isinstance(value, dict):
                    raise ValueError('Evidence must be a JSON object')
                if value.get('schema') != 2 or not isinstance(value.get('failures'), list):
                    raise ValueError('Expected diagnostic schema 2 with a failures array')
                entry.update(valid=True, complete=value.get('complete') is True,
                             passed=value.get('passed') is True,
                             status=value.get('status'), phase=value.get('phase'),
                             failure_count=len(value['failures']))
            except (OSError, ValueError, UnicodeError) as error:
                # Keep malformed bytes and still write results/provenance.
                entry['error'] = str(error)
        report[kind] = entry
    final = report['final']
    report['complete'] = final['valid'] and final['complete']
    report['successful_final'] = (report['complete'] and final['passed']
                                  and final['failure_count'] == 0)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--world', action='store_true')
    parser.add_argument('--renderer', choices=['headless', 'gl_compatibility', 'forward_plus'], default='headless')
    parser.add_argument('--xvfb', type=Path, help='Optional portable Xvfb; launched with the engine in the same process group')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source_run = SourceRun(project)
    source = source_run.observe("start")
    source_run.begin_report(output)
    script = 'int30_scenery_collision_world_test' if args.world else 'int30_scenery_collision_test'
    display = None
    display_log = None
    env = os.environ.copy()
    if args.xvfb:
        executable = args.xvfb.resolve()
        env['LD_LIBRARY_PATH'] = str(executable.parent.parent / 'lib/x86_64-linux-gnu')
        display_number = 20000 + secrets.randbelow(20000)
        while Path(f'/tmp/.X{display_number}-lock').exists():
            display_number = 20000 + secrets.randbelow(20000)
        env['DISPLAY'] = f'127.0.0.1:{display_number}'
        env['LIBGL_ALWAYS_SOFTWARE'] = '1'
        display_log = (output / 'display.log').open('w')
        display = subprocess.Popen([str(executable), f':{display_number}', '-screen', '0', '960x540x24',
                                    '-nolisten', 'unix', '-listen', 'tcp', '-ac', '-xkbdir', '/usr/share/X11/xkb'],
                                   env=env, stdout=display_log, stderr=display_log)
        ready = False
        for _ in range(50):
            if display.poll() is not None: break
            with socket.socket() as connection:
                connection.settimeout(0.2)
                try:
                    connection.connect(('127.0.0.1', 6000 + display_number))
                    ready = True
                    break
                except OSError: time.sleep(0.1)
        if not ready:
            display.terminate()
            display.wait()
            display_log.close()
            raise RuntimeError('Portable display failed; see display.log')
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='int30-collision-') as temp:
        command = [str(editor), '--path', str(project), '--audio-driver', 'Dummy']
        command += ['--headless'] if args.renderer == 'headless' else ['--rendering-method', args.renderer, '--resolution', '960x540', '--disable-render-loop']
        command += ['--script', f'res://tests/{script}.gd']
        if args.renderer != 'headless': command += ['--', '--capture']
        try:
            engine_env = isolated_env(Path(temp))
            engine_env.update({key: env[key] for key in ['DISPLAY', 'LD_LIBRARY_PATH', 'LIBGL_ALWAYS_SOFTWARE', 'LP_NUM_THREADS'] if key in env})
            if args.renderer != 'headless': engine_env.setdefault('LP_NUM_THREADS', '2')
            with (output / 'run.log').open('w') as log:
                try:
                    run = subprocess.run(command, env=engine_env, stdout=log, stderr=subprocess.STDOUT, timeout=360)
                except subprocess.TimeoutExpired:
                    log.write('\nERROR: collision capture exceeded its 360-second process guard\n')
                    run = subprocess.CompletedProcess(command, 124)
        finally:
            if display:
                display.terminate()
                display.wait()
                display_log.close()
        for p in Path(temp).rglob('int30-collision-*'):
            if p.is_file(): shutil.copy2(p, output / p.name)
    log = (output / 'run.log').read_text()
    marker = 'INT30_SCENERY_WORLD' if args.world else 'INT30_SCENERY_COLLISION'
    source_run.observe('finish', force=True)
    provenance = source_run.write_report(output)
    passed = run.returncode == 0 and not ERROR.search(log) and marker in log and not source_run.blocked
    diagnostics = world_evidence_report(output) if args.world else None
    if diagnostics:
        passed = passed and diagnostics['successful_final']
    videos = []
    if args.world and args.renderer != 'headless':
        for family in ['ancient_oak_v2', 'tall_pine_v2', 'dense_bush_v2', 'layered_rock_v2']:
            frames = sorted(output.glob(f'int30-collision-{family}-*.png'))
            if len(frames) != 30:
                passed = False
                continue
            video = output / f'{family}.mp4'
            encoded = subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '10', '-i',
                                      str(output / f'int30-collision-{family}-%03d.png'), '-c:v', 'libx264',
                                      '-pix_fmt', 'yuv420p', str(video)], capture_output=True, text=True)
            if encoded.returncode:
                passed = False
                (output / f'{family}-encoding.log').write_text(encoded.stderr)
            else:
                videos.append(video.name)
                for frame in frames:
                    if frame.stem[-3:] not in {'000', '015', '029'}: frame.unlink()
    provenance['reusable'] = provenance['reusable'] and passed
    report = {'passed': passed, 'exit_code': run.returncode, 'command': command, 'renderer': args.renderer,
              'source': source, 'provenance': provenance, 'videos': videos,
              'video_note': '30 explicitly rendered physical states per sweep played at 10 fps; automatic loading renders disabled, simulation unchanged; not a live-FPS measurement.',
              'log_sha256': hashlib.sha256((output / 'run.log').read_bytes()).hexdigest()}
    if diagnostics:
        report['world_evidence'] = diagnostics
        report['incomplete'] = run.returncode == 124 or not diagnostics['complete']
        report['status'] = 'passed' if passed else ('failed_incomplete' if report['incomplete'] else 'failed')
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)
    if not passed: print(log[-16000:])
    return 0 if passed else 1

if __name__ == '__main__': raise SystemExit(main())
