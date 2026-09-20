#!/usr/bin/env python3
"""Render identical PT17-03 views on two fixed sources; preserve both raw reports."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def git(project, *args):
    return subprocess.check_output(['git', *args], cwd=project, text=True).strip()


def capture(project, godot, renderer, output):
    output.mkdir(parents=True)
    source = {key: git(project, 'rev-parse', ref) for key, ref in [('commit', 'HEAD'), ('tree', 'HEAD^{tree}') ]}
    source['capture_script_sha256'] = hashlib.sha256((project / 'tools/capture_surface_transitions.gd').read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix='surface-userdata-') as temporary:
        env = isolated_env(Path(temporary))
        commands = [
            [str(godot), '--headless', '--path', str(project), '--import'],
            [str(godot), '--path', str(project), '--rendering-method', renderer,
             '--audio-driver', 'Dummy', '--script', 'res://tools/capture_surface_transitions.gd', '--', str(output)],
        ]
        for label, command in zip(['import', 'render'], commands):
            with (output / (label + '.log')).open('w') as log:
                run = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, env=env, timeout=900)
            log = (output / (label + '.log')).read_text()
            if run.returncode or ERROR.search(log):
                raise RuntimeError(f'{label} failed at {source["commit"]}: {log[-8000:]}')
    report = json.loads((output / 'capture.json').read_text())
    source['unchanged'] = source['commit'] == git(project, 'rev-parse', 'HEAD') and not git(project, 'diff', '--name-only', 'HEAD')
    report['source'] = source
    if not report['passed'] or len(list(output.glob('*.png'))) != 8 or not source['unchanged']:
        raise RuntimeError(f'Incomplete or changed surface comparison: {output}')
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--baseline-ref', required=True, help='Exact local commit; never fetched or changed by this runner')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    if git(project, 'status', '--porcelain'):
        raise RuntimeError('Commit the candidate before collecting reusable comparison evidence')
    baseline = git(project, 'rev-parse', args.baseline_ref + '^{commit}')
    with validation_editor(args.godot) as godot, tempfile.TemporaryDirectory(prefix='surface-baseline-') as temporary:
        checkout = Path(temporary) / 'source'
        git(project, 'worktree', 'add', '--detach', str(checkout), baseline)
        try:
            # Only the identical measurement script is injected into the old tree.
            # Runtime, materials and all generation code remain at the baseline.
            shutil.copy2(project / 'tools/capture_surface_transitions.gd', checkout / 'tools/capture_surface_transitions.gd')
            before = capture(checkout, godot, args.renderer, output / 'before')
            after = capture(project, godot, args.renderer, output / 'after')
        finally:
            git(project, 'worktree', 'remove', '--force', str(checkout))
    collision_equal = before['geometry']['collision_sha256'] == after['geometry']['collision_sha256']
    passed = collision_equal and after['geometry']['maximum_top_normal_error'] < 0.00001
    report = {'passed': passed, 'collision_unchanged': collision_equal, 'baseline': before['source'], 'candidate': after['source'],
              'before_top_normal_error': before['geometry']['maximum_top_normal_error'],
              'after_top_normal_error': after['geometry']['maximum_top_normal_error'],
              'scope': after['scope'], 'visual_acceptance': 'PNG pairs require human inspection; target-PC acceptance remains separate.'}
    (output / 'comparison.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2), flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
