#!/usr/bin/env python3
"""Render the owned register and exercise browser controls using real Godot UI.

Reuse the registered localization test, real D2 transactions, isolated saves,
and cold restart. Synthetic collection/observations are marked in the fixture.
Run with a graphical display, for example xvfb-run on Linux CI.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from validation_provenance import SourceRun
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source_run = SourceRun(args.project.resolve())
    source_run.begin_report(output)
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='int30-owned-review-') as temp:
        command = [str(editor), '--path', str(args.project.resolve()), '--rendering-method',
                   'gl_compatibility', '--audio-driver', 'Dummy', '--script',
                   'res://tests/owned_animal_localization_test.gd', '--', '--browser-capture', '--capture', temp]
        with (output / 'render.log').open('w') as log:
            try:
                completed = subprocess.run(command, env=isolated_env(Path(temp)), stdout=log,
                                           stderr=subprocess.STDOUT, timeout=180)
                code = completed.returncode
            except subprocess.TimeoutExpired:
                code = 124
                log.write("\nERROR: graphical review timed out\n")
        source_run.observe("render", force=True)
        provenance = source_run.write_report(output)
        log_text = (output / 'render.log').read_text()
        images = sorted(Path(temp).glob('owned-*.png'))
        for source in images:
            shutil.copy2(source, output / source.name)
        required = {'owned-browser-de-800x600-150-follow.png',
                    'owned-browser-en-800x600-150-follow.png', 'owned-browser-de-empty.png',
                    'owned-browser-de-known-role.png', 'owned-browser-en-known-role.png',
                    'owned-browser-de-role-detail.png', 'owned-browser-en-role-detail.png'}
        passed = (not source_run.blocked and code == 0 and not ERROR.search(log_text)
                  and 'OWNED_BROWSING_CHECKS_COMPLETED' in log_text
                  and '"passed":true' in log_text
                  and len(images) == 27 and required <= {p.name for p in images})
        report = {'passed': passed, 'exit_code': code,
                  'screenshots': [{'name': p.name, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                                  for p in images],
                  'renderer': 'gl_compatibility', 'command': command, 'provenance': provenance,
                  'environment': {'LIBGL_ALWAYS_SOFTWARE': os.environ.get('LIBGL_ALWAYS_SOFTWARE'),
                                  'LP_NUM_THREADS': os.environ.get('LP_NUM_THREADS')},
                  'scope': 'Real shared book and D2 transactions/restart; 127 copied D2 records for layouts and 6 copied records with observed D1 test profiles for browser assertions. Mouse opening and keyboard selection of actual dropdowns.'}
        (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps({'passed': passed, 'exit_code': code,
                          'screenshots': len(images)}), flush=True)
        if not passed:
            print(log_text[-10000:])
        return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
