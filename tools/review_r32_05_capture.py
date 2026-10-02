#!/usr/bin/env python3
"""Run one R32-05 native capture on a frozen checkout; local caller holds host flock; CI runs on its own host."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time
from validation_support import isolated_env
from validation_provenance import SourceRun


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--case', choices=['motion', 'occlusion', 'world', 'nests'], required=True)
    p.add_argument('--renderer', choices=['gl_compatibility', 'forward_plus'], default='gl_compatibility')
    p.add_argument('--language', choices=['de', 'en'], default='de')
    p.add_argument('--expect-negative', action='store_true')
    a = p.parse_args()
    project, output = a.project.resolve(), a.output.resolve()
    if output.is_relative_to(project) or output.exists():
        p.error('Choose a new output directory outside the source checkout')
    output.mkdir(parents=True)
    source = SourceRun(project)
    source.begin_report(output)
    scripts = {'motion': 'tools/review_r32_05_motion_capture.gd',
               'occlusion': 'tools/review_r32_05_occlusion_capture.gd',
               'world': 'tools/review_r32_05_world.gd',
               'nests': 'tools/review_r32_05_nest_capture.gd'}
    command = [a.godot, '--path', str(project), '--rendering-method', a.renderer,
               '--audio-driver', 'Dummy', '--script', 'res://' + scripts[a.case], '--', str(output), a.language]
    env = isolated_env(output / 'userdata')
    started = time.monotonic()
    try:
        with (output / 'render.log').open('wb') as log:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                    timeout=420 if a.case == 'world' else 900)
        status = result.returncode
    except subprocess.TimeoutExpired:
        status = 124
    log = (output / 'render.log').read_text()
    process_ok = status == 0 and not any(x in log for x in ['SCRIPT ERROR', '\nERROR:', 'ObjectDB instances leaked', 'Parse Error'])
    expected_ok = False
    if a.expect_negative and a.case == 'occlusion' and (output / 'result.json').exists():
        failures = set(json.loads((output / 'result.json').read_text())['failures'])
        expected_ok = status == 1 and failures == {
            "Visible off-ray foreign mesh's empty capsule hid the target",
            "Foreign visible mesh outside its movement capsule failed to occlude",
            "Nearer contact updated point without matching reticle pixel",
            "Invisible nest's query cylinder invented a visible target"} and not any(
                x in log for x in ['SCRIPT ERROR', 'Parse Error', 'ObjectDB instances leaked'])
    source.observe('capture_complete', force=True)
    provenance = source.write_report(output)
    frames = sorted(output.glob('frame-*.png'))
    if frames:
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '30', '-i', str(output / 'frame-%05d.png'),
                        '-c:v', 'libx264', '-threads', '2', '-crf', '23', '-pix_fmt', 'yuv420p',
                        '-movflags', '+faststart', str(output / 'capture.mp4')], check=True)
    data = {'case': a.case, 'command': command, 'renderer': a.renderer, 'language': a.language,
            'exit': status, 'seconds': round(time.monotonic() - started, 3), 'process_passed': process_ok,
            'expected_negative': a.expect_negative, 'expected_negative_verified': expected_ok, 'frames': len(frames), 'source': provenance,
            'host_coordination': {'kind': 'independent_github_runner' if os.environ.get('GITHUB_ACTIONS') == 'true' else 'caller_managed_local_lock',
                                  'local_lock_path': None if os.environ.get('GITHUB_ACTIONS') == 'true' else '/tmp/voxelverse-r32-db514e109ac6-heavy.lock'},
            'environment': {k: os.environ.get(k) for k in ['DISPLAY', 'LIBGL_ALWAYS_SOFTWARE', 'LP_NUM_THREADS']},
            'target_pc_accepted': False}
    (output / 'run.json').write_text(json.dumps(data, indent=2) + '\n')
    print(json.dumps({k: data[k] for k in ['case', 'exit', 'process_passed', 'seconds', 'frames']}), flush=True)
    return 0 if provenance['reusable'] and (process_ok or expected_ok) else 1


if __name__ == '__main__':
    raise SystemExit(main())
