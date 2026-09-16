#!/usr/bin/env python3
"""Exercise placement with real mouse input and capture the rendered Godot view."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    project = Path(__file__).resolve().parents[1]
    checks = []
    for test, marker in [('tribal_building_preview_test', 'TRIBAL_PREVIEW_PASSED'),
                         ('tribal_building_preview_world_test', 'TRIBAL_PREVIEW_WORLD_PASSED')]:
        log_path = output / (test + '.log')
        with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='placement-review-') as temporary:
            with log_path.open('w') as log:
                try:
                    result = subprocess.run([str(editor), '--path', str(project), '--rendering-method',
                        'gl_compatibility', '--audio-driver', 'Dummy', '--script', f'res://tests/{test}.gd',
                        '--', '--capture', str(output)], env=isolated_env(Path(temporary)), stdout=log,
                        stderr=subprocess.STDOUT, timeout=180)
                    code = result.returncode
                except subprocess.TimeoutExpired:
                    code = 124
        content = log_path.read_text()
        passed = code == 0 and marker in content and not ERROR.search(content)
        checks.append({'test': test, 'passed': passed, 'exit_code': code})
        if not passed:
            print(content[-6000:], flush=True)
    expected = {'placement-hut-free.png', 'placement-hut-blocked.png', 'placement-tent-free.png',
                'placement-well-free.png', 'placement-committed.png', 'placement-sphere-free.png'}
    images = sorted(p.name for p in output.glob('placement-*.png'))
    missing = sorted(expected - set(images))
    passed = all(check['passed'] for check in checks) and not missing
    source_commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip()
    source_tree = subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], cwd=project, text=True).strip()
    report = {'passed': passed, 'renderer': 'gl_compatibility', 'source_commit': source_commit,
              'source_tree': source_tree, 'checks': checks, 'screenshots': images, 'missing': missing}
    (output/'results.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report), flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
