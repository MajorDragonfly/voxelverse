#!/usr/bin/env python3
"""Focused R32-14 probes with isolated saves and exact source/log provenance."""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun
from validate_godot import ERROR

@contextmanager
def host_slot(path, wait):
    with open(path, 'a') as lock:
        deadline = time.monotonic()+wait
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise TimeoutError('R32 host slot is occupied; no Godot started')
                time.sleep(.2)
        print('R32_14_HOST_START ' + socket.gethostname(), flush=True)
        try:
            yield
        finally:
            print('R32_14_HOST_END ' + socket.gethostname(), flush=True)
            fcntl.flock(lock, fcntl.LOCK_UN)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--script', default='r32_14_creature_layout_test')
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--xvfb')
    parser.add_argument('--display', type=int, default=314)
    parser.add_argument('--timeout', type=int, default=240)
    parser.add_argument('--lock', default='/tmp/voxelverse-r32-db514e109ac6-heavy.lock')
    parser.add_argument('--lock-wait', type=int, default=50)
    parser.add_argument('probe_args', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        with host_slot(args.lock, min(args.lock_wait, 60)):
            return run(args)
    except TimeoutError as error:
        print(str(error), flush=True)
        return 75

def run(args):
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output.is_relative_to(project) or (output.exists() and any(output.iterdir())):
        raise ValueError('Use a new output directory outside the checkout')
    output.mkdir(parents=True, exist_ok=True)
    source = SourceRun(project)
    source.begin_report(output)
    display = None
    display_log = None
    try:
        with validation_editor(args.godot) as engine, tempfile.TemporaryDirectory(prefix='r32-14-user-') as temp:
            env = isolated_env(Path(temp))
            if args.xvfb:
                display_log = (output/'xvfb.log').open('w')
                display = subprocess.Popen([args.xvfb, f':{args.display}', '-screen', '0',
                    '1920x1080x24', '-nolisten', 'unix', '-listen', 'tcp', '-ac', '-noreset'],
                    env=env, stdout=display_log, stderr=subprocess.STDOUT)
                env['DISPLAY'] = f'127.0.0.1:{args.display}'
                deadline = time.monotonic()+10
                while time.monotonic() < deadline:
                    try:
                        with socket.create_connection(('127.0.0.1', 6000+args.display), timeout=.2): break
                    except OSError:
                        if display.poll() is not None: break
                        time.sleep(.1)
            command = [str(engine), '--path', str(project), '--rendering-method',
                'gl_compatibility', '--audio-driver', 'Dummy']
            if args.headless: command.append('--headless')
            command += ['--script', f'res://tests/{args.script}.gd', '--']
            if not args.headless: command += ['--capture', str(output)]
            command += [v for v in args.probe_args if v != '--']
            with (output/'run.log').open('w') as log:
                try:
                    code = subprocess.run(command, env=env, stdout=log,
                        stderr=subprocess.STDOUT, timeout=args.timeout).returncode
                except subprocess.TimeoutExpired:
                    code = 124
    finally:
        if display:
            display.terminate()
            try: display.wait(timeout=5)
            except subprocess.TimeoutExpired:
                display.kill()
                display.wait()
            display_log.close()
    source.observe('probe', force=True)
    provenance = source.write_report(output)
    content = (output/'run.log').read_text()
    images = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.png')}
    markers = {'r32_14_creature_layout_test': 'HUD_LAYOUT_OK',
        'r32_14_tribe_layout_test': 'R32_14_TRIBE_LAYOUT:',
        'r32_14_speed_test': 'R32_14_SPEED_OBSERVATIONS:',
        'r32_14_hud_world_test': 'R32_14_WORLD:'}
    completed = markers.get(args.script, '') in content
    if not args.headless and args.script == 'r32_14_hud_world_test':
        completed = completed and len(images) >= 36
    report = {'passed': code == 0 and not ERROR.search(content) and provenance['reusable'],
        'exit_code': code, 'command': command, 'source_provenance': provenance,
        'host': socket.gethostname(), 'engine': subprocess.check_output([args.godot,'--version'],text=True).strip(),
        'log_sha256': hashlib.sha256((output/'run.log').read_bytes()).hexdigest(),
        'screenshots': images, 'target_pc_acceptance': False}
    report['passed'] = report['passed'] and completed
    report['completion_marker'] = completed
    (output/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k: report[k] for k in ['passed','exit_code','host']}))
    if not report['passed']: print(content[-7000:])
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
