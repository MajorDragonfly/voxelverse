#!/usr/bin/env python3
"""Render the actual two-settlement campaign scenario on an existing display."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

from check_validation_contracts import revision
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    log_path = output / 'settlement-render.log'
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='settlement-render-') as temporary:
        env = isolated_env(Path(temporary))
        command = [str(editor), '--path', str(project), '--rendering-method', 'gl_compatibility',
                   '--audio-driver', 'Dummy', '--resolution', '1280x720', '--script',
                   'res://tests/settlement_runtime_test.gd', '--', '--capture-dir', str(output)]
        with log_path.open('w') as log:
            try:
                result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=1200)
                status = result.returncode
            except subprocess.TimeoutExpired:
                log.write('\nERROR: settlement render timed out\n')
                status = 124
    text = log_path.read_text(errors='replace')
    # Keep failures diagnosable directly from the job log as well as its artifact.
    print(text, flush=True)
    captures = sorted(path.name for path in output.glob('settlements-*.png'))
    passed = (status == 0 and not ERROR.search(text) and 'SECOND_SITE_RUNTIME_PASSED' in text
              and len(captures) == 6)
    report = {'source': revision(project), 'command': command, 'execution': 'x11_software_opengl',
              'passed': bool(passed), 'exit_code': status, 'captures': captures,
              'limits': 'No native export or target-PC performance acceptance.'}
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
