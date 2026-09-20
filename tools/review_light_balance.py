#!/usr/bin/env python3
"""Compare PT17-02 against the exact original controller with an identical fixture."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
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
    parser.add_argument('--baseline', default=BASE, help='Git revision of the complete before project')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)

    def git(*parts):
        return subprocess.check_output(['git', *parts], cwd=project)

    basis = git('rev-parse', '--verify', args.baseline + '^{commit}').decode().strip()
    before = git('show', f'{basis}:{CONTROLLER}')
    source = {'head': git('rev-parse', 'HEAD').decode().strip(),
              'tree': git('rev-parse', 'HEAD^{tree}').decode().strip(),
              'dirty': bool(git('status', '--porcelain')), 'basis': basis,
              'controller_before_sha256': hashlib.sha256(before).hexdigest(),
              'controller_after_sha256': hashlib.sha256((project / CONTROLLER).read_bytes()).hexdigest(),
              'fixture_sha256': hashlib.sha256((project / 'tools/review_light_balance.gd').read_bytes()).hexdigest()}
    passed = True
    # Replay the full original project, including preloaded shaders/preferences.
    # Future graphics changes must neither contaminate the before image nor
    # fail this shared workflow merely because a dependency has changed.
    with validation_editor(args.godot) as godot, tempfile.TemporaryDirectory(prefix='light-baseline-') as snapshot:
        baseline = Path(snapshot)
        with tarfile.open(fileobj=io.BytesIO(git('archive', basis))) as archive:
            archive.extractall(baseline, filter='data')
        shutil.copy2(project / 'tools/review_light_balance.gd', baseline / 'tools/review_light_balance.gd')
        for label in ['before', 'after']:
            directory = output / label
            directory.mkdir()
            with tempfile.TemporaryDirectory(prefix='light-review-') as temporary:
                userdata = Path(temporary)
                capture_project = baseline if label == 'before' else project
                if label == 'before':
                    with (directory / 'import.log').open('w') as log:
                        imported = subprocess.run([str(godot), '--headless', '--path', str(baseline), '--import'],
                                                  env=isolated_env(userdata), stdout=log, stderr=subprocess.STDOUT, timeout=120)
                    if imported.returncode or ERROR.search((directory / 'import.log').read_text()):
                        raise RuntimeError('Baseline import failed; see before/import.log')
                command = [str(godot), '--path', str(capture_project), '--rendering-method', args.renderer,
                           '--audio-driver', 'Dummy', '--script', 'res://tools/review_light_balance.gd',
                           '--', '--capture', str(directory)]
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
