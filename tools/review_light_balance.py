#!/usr/bin/env python3
"""Compare PT17-02 against the exact original controller with an identical fixture."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

from validation_support import isolated_env, validation_editor
from validate_godot import ERROR

CONTROLLER = 'world/visuals/atmosphere/campaign_atmosphere.gd'
BASE = '0e0a1cda0d645f872cecd42881b3f6e53b3ba34e'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)

    def git(*parts):
        return subprocess.check_output(['git', *parts], cwd=project)

    before = git('show', f'{BASE}:{CONTROLLER}')
    source = {'head': git('rev-parse', 'HEAD').decode().strip(),
              'tree': git('rev-parse', 'HEAD^{tree}').decode().strip(),
              'dirty': bool(git('status', '--porcelain')), 'basis': BASE,
              'controller_before_sha256': hashlib.sha256(before).hexdigest(),
              'controller_after_sha256': hashlib.sha256((project / CONTROLLER).read_bytes()).hexdigest(),
              'fixture_sha256': hashlib.sha256((project / 'tools/review_light_balance.gd').read_bytes()).hexdigest()}
    # This comparison intentionally substitutes only the changed controller.
    # All of its preloaded production dependencies must still equal the basis.
    for dependency in ['core/graphics_preferences.gd', 'world/visuals/atmosphere/campaign_sky.gdshader']:
        if git('show', f'{BASE}:{dependency}') != (project / dependency).read_bytes():
            raise RuntimeError('Baseline needs its own dependency snapshot: ' + dependency)
    passed = True
    with validation_editor(args.godot) as godot:
        for label in ['before', 'after']:
            directory = output / label
            directory.mkdir()
            with tempfile.TemporaryDirectory(prefix='light-review-') as temporary:
                userdata = Path(temporary)
                command = [str(godot), '--path', str(project), '--rendering-method', args.renderer,
                           '--audio-driver', 'Dummy', '--script', 'res://tools/review_light_balance.gd',
                           '--', '--capture', str(directory)]
                if label == 'before':
                    baseline = userdata / 'baseline_campaign_atmosphere.gd'
                    baseline.write_bytes(before)
                    command += ['--controller', str(baseline)]
                with (directory / 'render.log').open('w') as log:
                    run = subprocess.run(command, env=isolated_env(userdata), stdout=log,
                                         stderr=subprocess.STDOUT, timeout=240)
            log = (directory / 'render.log').read_text()
            ok = (run.returncode == 0 and not ERROR.search(log)
                  and 'LIGHT_BALANCE_RENDER_PASSED' in log and len(list(directory.glob('*.png'))) == 8)
            passed &= ok
            print(f'{label}: {"passed" if ok else "FAILED"}', flush=True)
            if not ok:
                print(log[-10000:], flush=True)
                break
    source['source_unchanged'] = (source['head'] == git('rev-parse', 'HEAD').decode().strip()
                                and not git('status', '--porcelain'))
    passed &= source['source_unchanged'] and not source['dirty']
    (output / 'results.json').write_text(json.dumps({**source, 'passed': passed, 'renderer': args.renderer}, indent=2) + '\n')
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
