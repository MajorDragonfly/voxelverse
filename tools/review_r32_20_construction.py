#!/usr/bin/env python3
"""Apply owner append attachments in an isolated checkout, or review real sites."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

from validation_provenance import SourceRun
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def prepare(project):
    if project == Path(__file__).resolve().parents[1]:
        raise ValueError('Owner attachments must be applied to a separate review checkout')
    attachment = project / 'docs/evidence/r32-20'
    catalog_path = project / 'localization/catalog.json'
    catalog = json.loads(catalog_path.read_text())
    rows = json.loads((attachment / 'localization-append.json').read_text())
    keys = {row['key'] for row in catalog['messages']}
    if any(row['key'] in keys for row in rows):
        raise ValueError('Append already applied; use a fresh review checkout')
    catalog['messages'].extend(rows)
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
    subprocess.run(['python3', 'tools/localization/catalog.py'], cwd=project, check=True)
    registry_path = project / 'tools/validation/contracts.json'
    registry = json.loads(registry_path.read_text())
    append = json.loads((attachment / 'registry-append.json').read_text())
    contract = next(item for item in registry['contracts'] if item['id'] == append['contract'])
    for name in append['tests']:
        if any(name in item['tests'] for item in registry['contracts']):
            raise ValueError('Duplicate registration: ' + name)
        contract['tests'].append(name)
    registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + '\n')
    runner = project / 'tools/validate_godot.py'
    content = runner.read_text()
    needle = 'LONG_TESTS.add("pause_menu_test")'
    if needle not in content:
        raise ValueError('Runner timeout insertion anchor changed')
    content = content.replace(needle, 'LONG_TESTS.add("r32_20_construction_world_test")  # Bounded real-site lifecycle review.\n' + needle, 1)
    runner.write_text(content)
    print('R32_20_OWNER_ATTACHMENTS_APPLIED: catalog, generated PO, one registration each, world budget')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--prepare-owner-attachments', action='store_true')
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--xvfb', type=Path)
    parser.add_argument('--display-number', type=int, default=220)
    parser.add_argument('--rendering-method', choices=['gl_compatibility', 'forward_plus'], default='gl_compatibility')
    args = parser.parse_args()
    project = args.project.resolve()
    if args.prepare_owner_attachments:
        prepare(project)
        return 0
    if args.output is None or args.xvfb is None:
        parser.error('Review requires --output and --xvfb')
    output = args.output.resolve()
    if output.is_relative_to(project) or (output.exists() and any(output.iterdir())):
        parser.error('Use a new output directory outside the checkout')
    output.mkdir(parents=True, exist_ok=True)
    source = SourceRun(project)
    source.begin_report(output)
    env = os.environ.copy()
    display = f'127.0.0.1:{args.display_number}'
    log_path = output / 'render.log'
    with (output / 'xvfb.log').open('w') as display_log:
        server = subprocess.Popen([str(args.xvfb), f':{args.display_number}', '-screen', '0', '1920x1080x24',
            '-nolisten', 'unix', '-listen', 'tcp', '-ac', '-noreset'], env=env, stdout=display_log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 10
            ready = False
            while time.monotonic() < deadline and server.poll() is None:
                try:
                    with socket.create_connection(('127.0.0.1', 6000 + args.display_number), timeout=0.2):
                        ready = True
                        break
                except OSError:
                    time.sleep(0.1)
            if not ready:
                raise RuntimeError('Xvfb did not become available')
            with validation_editor(args.godot) as engine, tempfile.TemporaryDirectory(prefix='r32-20-render-') as temporary:
                command = [str(engine), '--path', str(project), '--rendering-method', args.rendering_method,
                    '--audio-driver', 'Dummy', '--script', 'res://tests/r32_20_construction_world_test.gd', '--', '--capture', str(output)]
                env = isolated_env(Path(temporary))
                env['DISPLAY'] = display
                env['LIBGL_ALWAYS_SOFTWARE'] = '1'
                with log_path.open('w') as log:
                    try:
                        code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=900).returncode
                    except subprocess.TimeoutExpired:
                        code = 124
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
    source.observe('world_review', force=True)
    provenance = source.write_report(output)
    content = log_path.read_text()
    expected = {'01-prepaid-tool-de.png', '02-first-site-de.png', '03-first-cargo-de.png', '04-first-blocked-de.png',
        '05-confirm-cancel-en.png', '06-second-site-de.png', '07-second-completed-de.png'}
    expected.update(f'layout-{locale}-{width}-150.png' for locale in ['de', 'en'] for width in [800, 1280, 1920])
    images = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.png')}
    missing = sorted(expected - images.keys())
    passed = code == 0 and 'R32_20_WORLD_PASSED' in content and not ERROR.search(content) and not missing and provenance['reusable']
    report = {'passed': passed, 'exit_code': code, 'command': command, 'renderer': args.rendering_method,
        'engine': subprocess.check_output([args.godot, '--version'], text=True).strip(), 'images': images, 'missing': missing,
        'log_sha256': hashlib.sha256(log_path.read_bytes()).hexdigest(), 'source_provenance': provenance,
        'scope': 'Normal spherical campaign; two sequential placed sites; actual GUI input, navigation, resident freight, common save/load; rasterized capture boundaries.',
        'limits': ['No sustained FPS claim', 'Software renderer; target-PC view acceptance outstanding', 'Simultaneous settlement sites separately tested with radial arrived-work fixture']}
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({key: report[key] for key in ['passed', 'exit_code', 'missing']}), flush=True)
    if not passed:
        print(content[-7000:])
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
