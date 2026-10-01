#!/usr/bin/env python3
"""Run the actual standalone browser with isolated saves and capture PNGs.

Use an existing DISPLAY, or --xvfb for a portable X server. The optional baseline
path is the unchanged panel from the fixed INT30 commit, not a re-created mockup.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--xvfb', type=Path)
    parser.add_argument('--baseline-path', type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    sys.path.insert(0, str(project / 'tools'))
    from validation_support import isolated_env, validation_editor
    from validate_godot import ERROR
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if output.is_relative_to(project):
        parser.error('Capture output must be outside the source project')
    xserver = None
    with tempfile.TemporaryDirectory(prefix='int30-galaxy-capture-') as temporary:
        env = isolated_env(Path(temporary))
        try:
            if args.xvfb:
                with socket.socket() as reserve:
                    reserve.bind(('127.0.0.1', 0))
                    display = reserve.getsockname()[1] - 6000
                env['DISPLAY'] = f'127.0.0.1:{display}'
                with (output / 'xvfb.log').open('w') as log:
                    xserver = subprocess.Popen([str(args.xvfb), f':{display}', '-screen', '0',
                        '1920x1080x24', '-nolisten', 'unix', '-listen', 'tcp', '-ac'],
                        env=env, stdout=log, stderr=subprocess.STDOUT)
                for attempt in range(50):
                    if xserver.poll() is not None:
                        raise RuntimeError('Xvfb failed: ' + (output / 'xvfb.log').read_text())
                    try:
                        with socket.create_connection(('127.0.0.1', display + 6000), timeout=.1):
                            break
                    except OSError:
                        time.sleep(.1)
                else:
                    raise RuntimeError('Xvfb did not become ready')
            with validation_editor(args.godot) as editor:
                script = 'res://tests/int30_galaxy_browser_baseline.gd' if args.baseline_path else 'res://tests/int30_galaxy_browser_capture.gd'
                command = [str(editor), '--path', str(project), '--rendering-method',
                    'gl_compatibility', '--audio-driver', 'Dummy', '--script', script, '--', '--capture']
                if args.baseline_path:
                    command += ['--baseline-path', str(args.baseline_path.resolve())]
                started = time.monotonic()
                with (output / 'render.log').open('w') as log:
                    result = subprocess.run(command, env=env, stdout=log,
                        stderr=subprocess.STDOUT, timeout=120)
                seconds = time.monotonic() - started
            log_text = (output / 'render.log').read_text()
            images = sorted(Path(temporary).rglob('galaxy-*.png'))
            for source in images:
                shutil.copy2(source, output / source.name)
            expected = 2 if args.baseline_path else 12
            passed = result.returncode == 0 and not ERROR.search(log_text) and len(images) == expected
            report = {'passed': passed, 'exit_code': result.returncode, 'seconds': round(seconds, 3),
                'renderer': 'gl_compatibility', 'command': command,
                'screenshots': [{'name': p.name, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in images],
                'scope': 'Actual standalone catalogue UI; software Mesa rendering; no campaign/FPS acceptance'}
            (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps(report, indent=2))
            if not passed:
                print(log_text[-10000:])
            return 0 if passed else 1
        finally:
            if xserver is not None:
                xserver.terminate()
                xserver.wait(timeout=5)


if __name__ == '__main__':
    raise SystemExit(main())
