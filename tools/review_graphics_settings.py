#!/usr/bin/env python3
"""Run the real graphics controls with a renderer and capture their visible results."""
import argparse
import json
import subprocess
import tempfile
from pathlib import Path
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    def git(*command):
        return subprocess.check_output(['git', *command], cwd=project, text=True).strip()
    source = {'commit': git('rev-parse', 'HEAD'), 'tree': git('rev-parse', 'HEAD^{tree}'),
              'dirty': bool(git('status', '--porcelain'))}
    with validation_editor(args.godot) as godot, tempfile.TemporaryDirectory(prefix='graphics-review-') as userdata:
        command = [str(godot), '--path', str(project), '--rendering-method', args.renderer,
                   '--audio-driver', 'Dummy', '--script', 'res://tests/graphics_settings_test.gd',
                   '--', '--graphics-capture', str(output)]
        with (output / 'render.log').open('w') as log:
            result = subprocess.run(command, env=isolated_env(Path(userdata)), stdout=log,
                                    stderr=subprocess.STDOUT, timeout=240)
    log = (output / 'render.log').read_text()
    images = ['custom-world', 'preset-world', 'underwater']
    images += [f'settings-{size}-{locale}-{area}' for size in ['800x600', '1280x720', '1920x1080']
               for locale in ['de', 'en'] for area in ['top', 'bottom']]
    unchanged = source['commit'] == git('rev-parse', 'HEAD') and not git('status', '--porcelain')
    passed = (result.returncode == 0 and not ERROR.search(log) and 'GRAPHICS_SETTINGS_PASSED' in log
              and all((output / (name + '.png')).is_file() for name in images) and unchanged and not source['dirty'])
    report = {**source, 'passed': passed, 'renderer': args.renderer, 'command': command,
              'source_unchanged': unchanged, 'images': images,
              'scope': 'Real settings input, persistence/restart, two languages, three sizes at 130% UI scale; rendered atmosphere fixture and water. Campaign/travel separately headless; no target-PC/FPS acceptance.'}
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
