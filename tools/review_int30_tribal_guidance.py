#!/usr/bin/env python3
"""Render the contextual guide with the explicitly applied owner patches."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

from validate_godot import ERROR
from validation_provenance import SourceRun
from validation_support import isolated_env, validation_editor


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--rendering-method', choices=['gl_compatibility', 'forward_plus'], default='gl_compatibility')
    parser.add_argument('--xvfb', help='Optional Xvfb executable; launch it in the same network namespace as Godot')
    parser.add_argument('--display-number', type=int, default=199, help='Xvfb display number for concurrent independent reviews')
    parser.add_argument('--mode', choices=['ui', 'world'], default='ui', help='Isolated widget/arrived-work fixture or full spherical consumer')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output.is_relative_to(project) or (output.exists() and any(output.iterdir())):
        parser.error('Choose a new output directory outside the project')
    output.mkdir(parents=True, exist_ok=True)
    source = SourceRun(project)
    source.begin_report(output)
    log_path = output / 'render.log'
    display_process = None
    display_log = None
    render_env = os.environ.copy()
    if args.xvfb:
        display_log = (output / 'xvfb.log').open('w')
        display_process = subprocess.Popen([args.xvfb, f':{args.display_number}', '-screen', '0', '1920x1080x24',
            '-nolisten', 'unix', '-listen', 'tcp', '-ac', '-noreset'],
            stdout=display_log, stderr=subprocess.STDOUT)
        render_env['DISPLAY'] = f'127.0.0.1:{args.display_number}'
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            try:
                with socket.create_connection(('127.0.0.1', 6000 + args.display_number), timeout=0.2):
                    break
            except OSError:
                if display_process.poll() is not None:
                    break
                time.sleep(0.1)
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='int30-guide-render-') as temporary:
        command = [str(editor), '--path', str(project), '--rendering-method', args.rendering_method,
                   '--audio-driver', 'Dummy', '--script', f'res://tests/int30_tribal_guidance_{args.mode}_test.gd',
                   '--', '--capture', str(output)]
        with log_path.open('w') as log:
            try:
                env = isolated_env(Path(temporary))
                if args.xvfb: env['DISPLAY'] = render_env['DISPLAY']
                code = subprocess.run(command, env=env, stdout=log,
                                      stderr=subprocess.STDOUT, timeout=900).returncode
            except subprocess.TimeoutExpired:
                code = 124
            finally:
                if display_process is not None:
                    display_process.terminate()
                    try:
                        display_process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        display_process.kill()
                        display_process.wait()
                    display_log.close()
    source.observe('render', force=True)
    provenance = source.write_report(output)
    content = log_path.read_text()
    labels = [
        'no-selection', 'selected', 'rejected-order', 'blocked-route', 'cargo-in-transit',
        'empty-pantry', 'food-ready', 'missing-materials', 'valid-preview',
        'reserved-site-materials', 'paused-construction', 'resumed-help'] if args.mode == 'world' else [
        'no-selection', 'gathering', 'blocked-state', 'cargo-in-transit', 'empty-pantry',
        'missing-materials', 'reserved-site-materials', 'paused-construction']
    expected = {f'{i:02d}-{label}-de.png' for i, label in enumerate(labels, 1)}
    if args.mode == 'world': expected.update(f'help-context-{locale}.png' for locale in ['de', 'en'])
    expected.update(f'layout-{locale}-{width}-150.png' for locale in ['de', 'en'] for width in [800, 1280, 1920])
    images = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.png')}
    missing = sorted(expected - images.keys())
    passed = code == 0 and f'INT30_TRIBAL_GUIDANCE_{args.mode.upper()}_PASSED' in content and not ERROR.search(content) and not missing and provenance['reusable']
    report = {'passed': passed, 'fixture': args.mode, 'renderer': args.rendering_method, 'command': command,
              'exit_code': code, 'screenshots': images, 'missing': missing,
              'capture_policy': 'Actual 3D world rasterized at capture boundaries; physics and GUI live throughout' if args.mode == 'world' else 'Isolated rendered UI and arrived-work fixture',
              'engine': subprocess.check_output([args.godot, '--version'], text=True).strip(),
              'log_sha256': hashlib.sha256(log_path.read_bytes()).hexdigest(), 'source_provenance': provenance}
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({key: report[key] for key in ['passed', 'renderer', 'exit_code', 'missing']}), flush=True)
    if not passed:
        print('\n'.join(line for line in content.splitlines() if not line.startswith('TRIBAL_TUTORIAL_IMAGE:'))[-6000:])
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
