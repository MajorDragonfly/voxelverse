#!/usr/bin/env python3
"""Check the real husbandry/confirmation UI and optionally capture its graphics.

Use --headless for functional/layout checks; otherwise run on an X display.
All gameplay data and preferences are isolated, then discarded.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from validation_support import isolated_env, validation_editor
from check_validation_contracts import revision
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error('Choose a new output directory to preserve earlier evidence')
    output.mkdir(parents=True, exist_ok=True)
    before = revision(project)
    with validation_editor(args.godot) as godot, tempfile.TemporaryDirectory(prefix='husbandry-review-') as temp:
        env = isolated_env(Path(temp))
        command = [str(godot), '--path', str(project), '--audio-driver', 'Dummy']
        command += ['--headless'] if args.headless else ['--rendering-method', 'gl_compatibility']
        command += ['--script', 'res://tests/husbandry_localization_test.gd']
        if not args.headless:
            command += ['--', '--capture', temp]
        with (output / 'run.log').open('w') as log:
            completed = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        for path in Path(temp).rglob('*.log'):
            shutil.copy2(path, output / ('engine-' + path.name))
        reports = list(Path(temp).rglob('husbandry-localization-result.json'))
        outcome = json.loads(reports[0].read_text()) if len(reports) == 1 else {}
        images = sorted(Path(temp).glob('husbandry-*.png'))
        for path in images:
            shutil.copy2(path, output / path.name)
        after = revision(project)
        logs = '\n'.join(path.read_text(errors='replace') for path in output.glob('*.log'))
        passed = (completed.returncode == 0 and not ERROR.search(logs) and outcome.get('passed') is True
                  and (args.headless or len(images) == 12) and before == after)
        report = {'passed': bool(passed), 'command': command, 'source_before': before, 'source_after': after,
                  'engine': subprocess.check_output([str(godot), '--version'], text=True).strip(),
                  'mode': 'headless' if args.headless else 'gl_compatibility',
                  'test': outcome, 'screenshots': [path.name for path in images]}
        (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report), flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
