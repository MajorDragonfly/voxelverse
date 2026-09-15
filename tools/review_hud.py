#!/usr/bin/env python3
"""Render real gameplay HUD controls with isolated saves. Requires a display."""
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
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='hud-review-') as temporary:
        with (output/'render.log').open('w') as log:
            result = subprocess.run([str(editor), '--path', str(project), '--rendering-method',
                'gl_compatibility', '--audio-driver', 'Dummy', '--script', 'res://tests/hud_layout_test.gd',
                '--', '--capture', str(output)], env=isolated_env(Path(temporary)), stdout=log,
                stderr=subprocess.STDOUT, timeout=120)
    log_text = (output/'render.log').read_text()
    images = sorted(p.name for p in output.glob('hud-*.png'))
    passed = result.returncode == 0 and not ERROR.search(log_text) and 'HUD_LAYOUT_OK' in log_text and len(images) >= 3
    source_commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip()
    source_tree = subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], cwd=project, text=True).strip()
    (output/'results.json').write_text(json.dumps({'passed': passed, 'renderer': 'gl_compatibility', 'source_commit': source_commit, 'source_tree': source_tree, 'screenshots': images}, indent=2)+'\n')
    print(json.dumps({'passed': passed, 'screenshots': images}), flush=True)
    if not passed: print(log_text[-6000:])
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
