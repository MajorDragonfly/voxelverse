#!/usr/bin/env python3
"""One frozen scanner query probe; caller holds the coordinated host lock."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import time
from validation_provenance import SourceRun
from validation_support import isolated_env


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--project', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--save', type=Path, required=True)
    p.add_argument('--renderer', choices=['gl_compatibility', 'forward_plus'], required=True)
    p.add_argument('--profile', action='store_true')
    p.add_argument('--count', type=int, choices=[1, 12])
    a = p.parse_args()
    project, output = a.project.resolve(), a.output.resolve()
    if output.exists() or output.is_relative_to(project):
        p.error('Use a new output outside the source checkout')
    output.mkdir(parents=True)
    source = SourceRun(project)
    source.begin_report(output)
    command = [a.godot, '--path', str(project), '--rendering-method', a.renderer,
               '--audio-driver', 'Dummy', '--script', 'res://tools/review_r32_05_query_probe.gd',
               '--', str(output), str(a.save.resolve())]
    if a.profile:
        command.append('--profile')
    if a.count is not None:
        command.extend(['--count', str(a.count)])
    started = time.monotonic()
    host_start = Path('/proc/stat').read_text()
    with (output / 'render.log').open('wb') as log:
        try:
            process = subprocess.run(command, env=isolated_env(output / 'userdata'),
                                     stdout=log, stderr=subprocess.STDOUT, timeout=240)
            status = process.returncode
        except subprocess.TimeoutExpired:
            status = 124
    log = (output / 'render.log').read_text()
    passed = status == 0 and not any(token in log for token in
        ['SCRIPT ERROR', '\nERROR:', 'ObjectDB instances leaked', 'Parse Error'])
    source.observe('query_complete', force=True)
    provenance = source.write_report(output)
    report = {'command': command, 'exit': status, 'passed': passed,
              'seconds': time.monotonic() - started, 'source': provenance,
              'host': platform.node(), 'affinity': sorted(os.sched_getaffinity(0)),
              'environment': {k: os.environ.get(k) for k in
                              ['DISPLAY', 'LP_NUM_THREADS', 'LIBGL_ALWAYS_SOFTWARE', 'VK_ICD_FILENAMES']},
              'host_stat_start': host_start, 'host_stat_end': Path('/proc/stat').read_text(),
              'save_sha256': hashlib.sha256(a.save.read_bytes()).hexdigest() if a.save.exists() else None,
              'target_pc_accepted': False}
    (output / 'run.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'exit': status, 'passed': passed, 'seconds': report['seconds'],
                      'source_reusable': provenance['reusable']}), flush=True)
    return 0 if passed and provenance['reusable'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
