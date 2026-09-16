#!/usr/bin/env python3
"""Render actual recovery cards in DE/EN, 720p/1080p and 100/150% text.

Run under a display (for example xvfb-run). All player data is isolated.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

from validation_support import isolated_env
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='recovery-review-') as temp:
        command = [args.godot, '--path', str(project), '--rendering-method',
                   'gl_compatibility', '--audio-driver', 'Dummy', '--script',
                   'res://tests/player_recovery_world_test.gd', '--', '--capture', str(output)]
        with (output / 'render.log').open('w') as log:
            process = subprocess.run(command, env=isolated_env(Path(temp)), stdout=log,
                                     stderr=subprocess.STDOUT, timeout=180)
    log = (output / 'render.log').read_text()
    images = sorted(p.name for p in output.glob('recovery-*.png'))
    passed = (process.returncode == 0 and not ERROR.search(log) and len(images) == 32
              and "RECOVERY_FRESH_PROCESS_PASSED" in log and "PLAYER_RECOVERY_WORLD_PASSED" in log)
    result = {'passed': passed, 'command': command, 'images': images,
              'renderer': 'gl_compatibility', 'isolated_userdata': True}
    (output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
    if not passed:
        print(log[-5000:])
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
