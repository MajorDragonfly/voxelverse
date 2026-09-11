#!/usr/bin/env python3
"""Render the real skills UI in DE/EN, three sizes and 100/150 % text.

Requires a display (e.g. xvfb-run). Campaign files and settings are isolated.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='skills-review-') as temp:
        command = [str(editor), '--path', str(args.project.resolve()), '--rendering-method',
                   'gl_compatibility', '--audio-driver', 'Dummy', '--script',
                   'res://tests/skills_localization_test.gd', '--', '--capture', temp]
        with (output / 'render.log').open('w') as log:
            result = subprocess.run(command, env=isolated_env(Path(temp)), stdout=log,
                                    stderr=subprocess.STDOUT, timeout=150)
        text = (output / 'render.log').read_text()
        images = sorted(Path(temp).glob('skills-*.png'))
        for source in images:
            shutil.copy2(source, output / source.name)
        passed = result.returncode == 0 and not ERROR.search(text) and 'passed=true' in text and len(images) == 26
        report = {'passed': passed, 'screenshots': [p.name for p in images],
                  'renderer': 'gl_compatibility',
                  'scope': 'Real skills UI; mouse/keyboard purchases, rollback, language changes, reload and fresh process'}
        (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report), flush=True)
        if not passed: print(text[-8000:])
        return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
