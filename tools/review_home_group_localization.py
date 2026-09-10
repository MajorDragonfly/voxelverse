#!/usr/bin/env python3
"""Render the ARCH-25 home group in DE/EN at three sizes and two scales.

Needs a display (for Linux CI, use xvfb-run). Saves/settings are always isolated.
This runs the real resident/controller route in a test scene.
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
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='home-review-') as temp:
        env = isolated_env(Path(temp))
        command = [str(editor), '--path', str(args.project.resolve()), '--rendering-method',
                   'gl_compatibility', '--audio-driver', 'Dummy', '--script',
                   'res://tests/home_group_localization_test.gd', '--', '--capture', temp]
        with (output / 'render.log').open('w') as log:
            completed = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=90)
        log_text = (output / 'render.log').read_text()
        images = sorted(Path(temp).rglob('home-*.png'))
        for source in images:
            shutil.copy2(source, output / source.name)
        passed = (completed.returncode == 0 and not ERROR.search(log_text)
                  and 'HOME_LOCALIZATION_CHECKS:' in log_text and '"passed":true' in log_text and len(images) == 18)
        report = {'passed': passed, 'screenshots': [p.name for p in images],
                  'renderer': 'gl_compatibility', 'scope': 'Actual home group panel with real resident physics, GUI commands and save/restart'}
        (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report), flush=True)
        if not passed:
            print(log_text[-10000:])
        return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
