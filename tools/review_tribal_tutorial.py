#!/usr/bin/env python3
"""Run the tribal introduction through the public rendered sphere entry."""
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
    log_path = output / 'tribal_guidance_world_test.log'
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='tutorial-review-') as temporary:
        with log_path.open('w') as log:
            try:
                result = subprocess.run([str(editor), '--path', str(project), '--rendering-method',
                    'gl_compatibility', '--audio-driver', 'Dummy', '--script',
                    'res://tests/tribal_guidance_world_test.gd', '--', '--capture', str(output)],
                    env=isolated_env(Path(temporary)), stdout=log, stderr=subprocess.STDOUT, timeout=480)
                code = result.returncode
            except subprocess.TimeoutExpired:
                code = 124
    content = log_path.read_text()
    for line in content.splitlines():
        if line.startswith(('TRIBAL_TUTORIAL_IMAGE:', 'TRIBAL_TUTORIAL_CONSTRUCTION ')):
            print(line, flush=True)
    expected = {'tutorial-start-de.png', 'tutorial-work-en.png', 'tutorial-placement.png',
                'tutorial-help-720.png', 'tutorial-completed.png'}
    images = sorted(p.name for p in output.glob('tutorial-*.png'))
    missing = sorted(expected - set(images))
    passed = code == 0 and 'TRIBAL_GUIDANCE_WORLD_PASSED' in content and not ERROR.search(content) and not missing
    if not passed:
        print('\n'.join(line for line in content.splitlines() if not line.startswith('TRIBAL_TUTORIAL_IMAGE:'))[-8000:], flush=True)
    source_commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip()
    source_tree = subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], cwd=project, text=True).strip()
    report = {'passed': passed, 'renderer': 'gl_compatibility', 'source_commit': source_commit,
              'source_tree': source_tree, 'exit_code': code, 'screenshots': images, 'missing': missing}
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
