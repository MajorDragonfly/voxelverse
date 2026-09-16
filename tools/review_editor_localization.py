#!/usr/bin/env python3
"""Render the actual creature workshop in DE/EN. Run under an X display.

Example: xvfb-run -s '-screen 0 1920x1080x24' python3 tools/review_editor_localization.py
  --godot /path/to/godot --output /tmp/editor-review
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
    with validation_editor(args.godot) as godot, tempfile.TemporaryDirectory(prefix='editor-review-') as temp:
        command = [str(godot), '--path', str(args.project.resolve()), '--rendering-method',
                   'gl_compatibility', '--audio-driver', 'Dummy', '--script',
                   'res://tests/editor_localization_test.gd', '--', '--capture', temp]
        with (output / 'render.log').open('w') as log:
            result = subprocess.run(command, env=isolated_env(Path(temp)), stdout=log,
                                    stderr=subprocess.STDOUT, timeout=240)
        log_text = (output / 'render.log').read_text()
        images = sorted(Path(temp).glob('editor-*.png'))
        for source in images:
            shutil.copy2(source, output / source.name)
        records = [json.loads(line.split('EDITOR_LOCALIZATION_RESULT ', 1)[1])
                   for line in log_text.splitlines() if line.startswith('EDITOR_LOCALIZATION_RESULT ')]
        passed = result.returncode == 0 and not ERROR.search(log_text) and records and records[-1]['passed'] and len(images) == 16
        report = {'passed': bool(passed), 'screenshots': [p.name for p in images],
                  'renderer': 'gl_compatibility', 'command': command,
                  'scope': 'Real workshop: 48 layouts, DE/EN, 800/1280/1920, 100/150% text, four modes; 16 captures',
                  'test_results': records}
        (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report), flush=True)
        if not passed:
            print(log_text[-8000:])
        return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
