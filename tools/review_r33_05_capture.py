#!/usr/bin/env python3
"""Native GL functional capture; invoke inside review_r33_05_locked.py."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import socket
import time

from validate_godot import ERROR
from validation_provenance import SourceRun
from validation_support import isolated_env, validation_editor


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--xvfb', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    project = args.project.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    provenance = SourceRun(project)
    provenance.begin_report(output)
    env = isolated_env(output / 'isolated-user')
    env['LIBGL_ALWAYS_SOFTWARE'] = '1'
    env['DISPLAY'] = '127.0.0.1:235'
    prefix = args.xvfb.resolve().parents[2]
    env['LD_LIBRARY_PATH'] = ':'.join(str(path) for path in
                                    [prefix / 'lib/x86_64-linux-gnu', prefix / 'usr/lib/x86_64-linux-gnu']
                                    if path.is_dir())
    xserver = None
    report = {'host': os.uname().nodename, 'start': time.time(),
              'target_pc_acceptance': False, 'scope': 'Native software GL functionality, no FPS approval'}
    try:
        with (output / 'xvfb.log').open('w') as xlog:
            xserver = subprocess.Popen([str(args.xvfb.resolve()), ':235', '-screen', '0', '1280x720x24',
                                        '-nolisten', 'local', '-nolisten', 'unix', '-listen', 'tcp',
                                        '-ac', '-noreset'], env=env, stdout=xlog, stderr=subprocess.STDOUT)
            for _ in range(30):
                if xserver.poll() is not None: raise RuntimeError('Xvfb failed')
                try:
                    with socket.create_connection(('127.0.0.1', 6235), timeout=0.1): break
                except OSError:
                    pass
                time.sleep(0.1)
            with validation_editor(args.godot) as editor:
                command = [str(editor), '--path', str(project), '--audio-driver', 'Dummy', '--max-fps', '30',
                           '--rendering-method', 'gl_compatibility', '--resolution', '1280x720',
                           '--script', 'res://tests/r33_05_local_sources_world_test.gd', '--',
                           '--capture-dir', str(output / 'captures')]
                report['command'] = command
                report['engine'] = subprocess.check_output([str(editor), '--version'], env=env, text=True).strip()
                with (output / 'world.log').open('w') as log:
                    run = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=540)
                report['exit_code'] = run.returncode
                content = (output / 'world.log').read_text()
                images = list((output / 'captures').glob('*.png'))
                report['images'] = [path.name for path in images]
                report['passed'] = run.returncode == 0 and not ERROR.search(content) and 'R33_05_LOCAL_WORLD_PASSED' in content and len(images) >= 6
                print(content[-10000:])
    finally:
        if xserver is not None:
            xserver.terminate()
            xserver.wait(timeout=10)
        provenance.observe('native_capture', force=True)
        report['source_integrity'] = provenance.write_report(output)
        report['passed'] = report.get('passed', False) and report['source_integrity']['reusable']
        report['end'] = time.time()
        (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({key: value for key, value in report.items() if key != 'source_integrity'}))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
