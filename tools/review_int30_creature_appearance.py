#!/usr/bin/env python3
"""Reproduce INT30-22 in a disposable checkout with the delivered owner patches.

Requires Godot 4.6.3 and a display for --render (e.g. Xvfb/Mesa). Never edits
production owner files in the source checkout. Validation/userdata are isolated.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from validation_support import isolated_env, validation_editor
from validate_godot import ERROR

EVIDENCE = Path('docs/evidence/int30-22-creature-appearance')


def execute(command, log, env=None, timeout=240):
    with log.open('w') as stream:
        try:
            result = subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
        except subprocess.TimeoutExpired:
            stream.write('\nERROR: review timed out\n')
            return False
    content = log.read_text()
    return result.returncode == 0 and not ERROR.search(content)


def prepare(source, checkout, output):
    subprocess.run(['git', 'clone', '--no-hardlinks', str(source), str(checkout)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(['git', '-C', str(checkout), 'config', 'user.name', 'INT30-22 QA'], check=True)
    subprocess.run(['git', '-C', str(checkout), 'config', 'user.email', 'int30-22@example.invalid'], check=True)
    subprocess.run(['git', '-C', str(checkout), 'apply', str(checkout / EVIDENCE / 'editor-owner.patch')], check=True)
    subprocess.run(['git', '-C', str(checkout), 'apply', str(checkout / EVIDENCE / 'validation-owner.patch')], check=True)
    catalog = checkout / 'localization/catalog.json'
    data = json.loads(catalog.read_text())
    data['messages'].extend(json.loads((checkout / EVIDENCE / 'translations.append.json').read_text()))
    catalog.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    subprocess.run(['python3', str(checkout / 'tools/localization/catalog.py')], check=True)
    registry = checkout / 'tools/validation/contracts.json'
    data = json.loads(registry.read_text())
    entry = json.loads((checkout / EVIDENCE / 'registry.append.json').read_text())
    contract = next(row for row in data['contracts'] if row['id'] == entry['contract'])
    contract['tests'].extend(entry['tests'])
    registry.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    # Retain exact, reviewable integration source including generated translations.
    subprocess.run(['git', '-C', str(checkout), 'diff', '--binary'], check=True, stdout=(output / 'applied-owner.patch').open('w'))
    subprocess.run(['git', '-C', str(checkout), 'add', '-A'], check=True)
    subprocess.run(['git', '-C', str(checkout), 'commit', '-m', 'QA only: apply INT30-22 owner attachments'], check=True, stdout=subprocess.DEVNULL)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--checkout', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--tests', nargs='+', default=['int30_creature_appearance_test', 'creature_studio_test', 'creature_parts_studio_test', 'editor_localization_test'])
    parser.add_argument('--worker-threads', type=int, help='QA environment only: bound the Godot worker pool')
    parser.add_argument('--reuse-checkout', action='store_true', help='Use already prepared exact QA source for diagnosis')
    args = parser.parse_args()
    source, checkout, output = args.project.resolve(), args.checkout.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    if not args.reuse_checkout:
        prepare(source, checkout, output)
    if args.worker_threads is not None:
        if args.worker_threads < 1: parser.error('--worker-threads must be positive')
        override = checkout / 'override.cfg'
        content = '[threading]\nworker_pool/max_threads=%d\n' % args.worker_threads
        if override.exists() and override.read_text() != content:
            parser.error('Existing QA override differs; choose a fresh checkout')
        override.write_text(content)
        subprocess.run(['git', '-C', str(checkout), 'add', 'override.cfg'], check=True)
        if subprocess.check_output(['git', '-C', str(checkout), 'diff', '--cached', '--name-only'], text=True).strip():
            subprocess.run(['git', '-C', str(checkout), 'commit', '-m', 'QA environment: bounded worker pool'], check=True, stdout=subprocess.DEVNULL)
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='appearance-import-') as temp:
        if not execute([str(editor), '--headless', '--path', str(checkout), '--import'],
                       output / 'import.log', isolated_env(Path(temp)), timeout=180):
            print((output / 'import.log').read_text()[-8000:])
            return 1
    if args.render:
        # Baseline uses identical new capture driver but original host source.
        baseline = subprocess.check_output(['git', '-C', str(source), 'show', 'HEAD:creatures/editor/creature_editor_studio.gd'], text=True)
        applied = (checkout / 'creatures/editor/creature_editor_studio.gd').read_text()
        (checkout / 'creatures/editor/creature_editor_studio.gd').write_text(baseline)
        try:
            with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='appearance-before-') as temp:
                env = isolated_env(Path(temp))
                env['LIBGL_ALWAYS_SOFTWARE'] = '1'
                before = execute([str(editor), '--path', str(checkout), '--rendering-method', 'gl_compatibility',
                                  '--audio-driver', 'Dummy', '--script', 'res://tests/int30_creature_appearance_test.gd',
                                  '--', '--before', '--capture', str(output)], output / 'before-render.log', env)
        finally:
            (checkout / 'creatures/editor/creature_editor_studio.gd').write_text(applied)
        if not before:
            print((output / 'before-render.log').read_text()[-8000:])
            return 1
    test_command = ['python3', str(checkout / 'tools/validate_godot.py'), '--project', str(checkout), '--godot', args.godot,
                    '--tests', *args.tests, '--skip-import', '--skip-main', '--output', str(output / 'validation')]
    result = subprocess.run(test_command)
    if result.returncode: return result.returncode
    if args.render:
        with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='appearance-after-') as temp:
            env = isolated_env(Path(temp))
            env['LIBGL_ALWAYS_SOFTWARE'] = '1'
            passed = execute([str(editor), '--path', str(checkout), '--rendering-method', 'gl_compatibility',
                              '--audio-driver', 'Dummy', '--script', 'res://tests/int30_creature_appearance_test.gd',
                              '--', '--capture', str(output)], output / 'after-render.log', env)
        if not passed:
            print((output / 'after-render.log').read_text()[-8000:])
            return 1
    if args.render:
        expected = {'before-de-1280x720.png', 'after-de-1280x720.png', 'after-en-1280x720.png',
                    'after-en-800x600-150-top.png', 'after-en-800x600-150-skin.png'}
        if {p.name for p in output.glob('*.png')} != expected:
            print('ERROR: Missing expected appearance capture')
            return 1
    images = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.png')}
    report = {'passed': True, 'source_commit': subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip(),
              'applied_owner_tree': subprocess.check_output(['git', '-C', str(checkout), 'rev-parse', 'HEAD^{tree}'], text=True).strip(),
              'worker_threads': args.worker_threads, 'tests': args.tests,
              'renderer': 'GL Compatibility / software Mesa' if args.render else 'headless', 'images': images,
              'scope': 'cosmetic UI and direct editor consumers with explicit owner attachments; no full integration/target-PC acceptance'}
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
