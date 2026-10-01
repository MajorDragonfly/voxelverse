#!/usr/bin/env python3
"""Exercise real template/editor geometry and reload in a fresh isolated process.

Requires an existing display for captures (e.g. Xvfb); headless-only is supported.
Shared localization append is loaded by the fixture, not written to the catalog.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

from check_validation_contracts import revision
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--headless-only', action='store_true')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    # A failed repeat must not leave an earlier success looking current.
    (output / 'results.json').write_text(json.dumps({'passed': False, 'status': 'running'}) + '\n')
    sources = [*sorted((project / 'civilization/buildings/templates').rglob('*')),
               project / 'tests/int30_building_templates_test.gd', Path(__file__).resolve(),
               project / 'docs/evidence/int30-building-templates/integration/localization.append.json']
    source_hashes = {p.relative_to(project).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in sources if p.is_file() and p.suffix != '.uid'}
    before = revision(project)
    commands, results = [], []
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='building-template-review-') as temp:
        env = isolated_env(Path(temp))
        common = [str(editor), '--path', str(project), '--audio-driver', 'Dummy']
        command = common + (['--headless'] if args.headless_only else ['--rendering-method', 'gl_compatibility'])
        command += ['--script', 'res://tests/int30_building_templates_test.gd']
        if not args.headless_only:
            command += ['--', '--capture', str(output)]
        restart = common + ['--headless', '--script', 'res://tests/int30_building_templates_test.gd', '--', '--restart']
        for name, argv in [('editor-and-designs', command), ('fresh-process-reload', restart)]:
            commands.append(argv)
            timed_out = False
            with (output / (name + '.log')).open('w') as log:
                try:
                    run = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT, env=env, timeout=150)
                    exit_code = run.returncode
                except subprocess.TimeoutExpired:
                    timed_out = True
                    exit_code = None
            text = (output / (name + '.log')).read_text()
            records = [json.loads(line) for line in text.splitlines() if line.startswith('{') and '"int30_building_templates"' in line]
            passed = not timed_out and exit_code == 0 and not ERROR.search(text) and len(records) == 1 and records[0]['passed']
            results.append({'name': name, 'passed': passed, 'exit_code': exit_code, 'timed_out': timed_out,
                            'log_sha256': hashlib.sha256(text.encode()).hexdigest(),
                            'result': records[0] if len(records) == 1 else None})
            if not passed:
                print(text[-10000:])
                break
    expected_images = {f'{design}-{view}.png' for design in ['residence', 'warehouse', 'workshop']
                       for view in ['front', 'rear', 'top', 'editor-open', 'editor-edited-reload-de']}
    images = sorted(p.name for p in output.glob('*.png') if p.name in expected_images)
    passed = len(results) == 2 and all(result['passed'] for result in results)
    passed = passed and (args.headless_only or len(images) == 15)
    passed = passed and all(hashlib.sha256((project / path).read_bytes()).hexdigest() == digest for path, digest in source_hashes.items())
    report = {'passed': passed, 'source': before, 'source_files_sha256': source_hashes,
              'engine': subprocess.check_output([args.godot, '--version'], text=True).strip(),
              'renderer': 'headless' if args.headless_only else 'gl_compatibility',
              'commands': commands, 'results': results, 'screenshots': images,
              'scope': 'Built-in designs, real catalog meshes, optional picker/editor bridge, isolated explicit copy saves and fresh process reload; no campaign construction'}
    (output / 'results.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'passed': passed, 'screenshots': len(images), 'checks': [r.get('result', {}).get('checks') for r in results if r.get('result')]}))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
