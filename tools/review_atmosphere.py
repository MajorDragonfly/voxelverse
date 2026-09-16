#!/usr/bin/env python3
"""Capture the campaign atmosphere in a native voxel test scene, under an X display."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    with validation_editor(args.godot) as godot, tempfile.TemporaryDirectory(prefix='atmosphere-review-') as userdata:
        command = [str(godot), '--path', str(project), '--rendering-method', args.renderer,
                   '--audio-driver', 'Dummy', '--script', 'res://tools/review_atmosphere.gd',
                   '--', '--capture', str(output)]
        with (output / 'render.log').open('w') as log:
            result = subprocess.run(command, env=isolated_env(Path(userdata)), stdout=log,
                                    stderr=subprocess.STDOUT, timeout=240)
    log = (output / 'render.log').read_text()
    passed = result.returncode == 0 and not ERROR.search(log) and 'ATMOSPHERE_RENDER_PASSED' in log and len(list(output.glob('*.png'))) == 6
    report = {'passed': passed, 'renderer': args.renderer, 'command': command,
              'scope': 'Native voxel fixture, identical camera/geometry: before, atmospheric, cinematic, radial, sunset, night. Not a campaign/FPS/Windows acceptance.',
              'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip(),
              'tree': subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], cwd=project, text=True).strip(),
              'dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=project, text=True).strip())}
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
