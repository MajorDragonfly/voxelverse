#!/usr/bin/env python3
"""Capture the real audio settings GUI and exercise its mixer and restart tests."""
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
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)

    def git(*command):
        return subprocess.check_output(['git', *command], cwd=project, text=True).strip()

    source = {'commit': git('rev-parse', 'HEAD'), 'tree': git('rev-parse', 'HEAD^{tree}'),
              'dirty': bool(git('status', '--porcelain'))}
    with validation_editor(args.godot) as godot, tempfile.TemporaryDirectory(prefix='audio-review-') as userdata:
        command = [str(godot), '--path', str(project), '--rendering-method', 'gl_compatibility',
                   '--audio-driver', 'Dummy', '--script', 'res://tests/audio/audio_settings_test.gd',
                   '--', '--audio-settings-capture', str(output)]
        with (output / 'render.log').open('w') as log:
            result = subprocess.run(command, env=isolated_env(Path(userdata)), stdout=log,
                                    stderr=subprocess.STDOUT, timeout=120)
    log = (output / 'render.log').read_text()
    images = [f'audio-{size}-{locale}-{area}' for size in ['800x600', '1280x720', '1920x1080']
              for locale in ['de', 'en'] for area in ['top', 'bottom']]
    unchanged = source['commit'] == git('rev-parse', 'HEAD') and not git('status', '--porcelain')
    passed = (result.returncode == 0 and not ERROR.search(log) and 'AUDIO_SETTINGS_PASSED' in log
              and all((output / (name + '.png')).is_file() for name in images) and unchanged and not source['dirty'])
    report = {**source, 'passed': passed, 'renderer': 'gl_compatibility', 'command': command,
              'source_unchanged': unchanged, 'images': images,
              'scope': 'Real mouse/keyboard input, mixer output, persistence/restart, DE/EN, three sizes at 150% UI scale. PT17-14 combined pause-menu and target-PC acceptance remain separate.'}
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(log)
    print(json.dumps(report, indent=2))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
