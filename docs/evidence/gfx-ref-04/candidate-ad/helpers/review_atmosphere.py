#!/usr/bin/env python3
"""Native source-bound atmosphere comparison in the public campaign."""
import argparse
from contextlib import ExitStack
import fcntl
import hashlib
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import tempfile
import time

import sys
PROJECT = Path('/workspace/scratch/bac0d501b6e8/gfx-ref-03/voxelverse')
sys.path.insert(0, str(PROJECT / 'tools'))
from review_r32_06_campaign_light import godot_processes
from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun
from validate_godot import ERROR


def pixel_pairs(output, report):
    from PIL import Image, ImageChops
    result = []
    for pair in report.get('pairs', []):
        images = [Image.open(output / (name + '.png')).convert('RGB') for name in pair['captures']]
        difference = ImageChops.difference(images[0], images[1])
        changed = sum(pixel != (0, 0, 0) for pixel in difference.getdata())
        restored = ImageChops.difference(images[0], images[2]).getbbox() is None
        light = Image.open(output / (pair['lighting_capture'] + '.png')).convert('RGB')
        light_difference = ImageChops.difference(images[0], light)
        light_changed = sum(pixel != (0, 0, 0) for pixel in light_difference.getdata())
        result.append(dict(id=pair['id'], changed_pixels=changed,
                           total_pixels=images[0].width * images[0].height,
                           before_restore_exact=restored, lighting_changed_pixels=light_changed,
                           difference_bounds=difference.getbbox()))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--replay', type=Path, required=True, help='Original saved campaign and canonical views')
    parser.add_argument('--xvfb', type=Path)
    parser.add_argument('--xkbdir', type=Path, default=Path('/usr/share/X11/xkb'))
    parser.add_argument('--graphics-lib', type=Path)
    parser.add_argument('--vulkan-icd', type=Path)
    args = parser.parse_args()
    project = PROJECT
    baseline = Path(__file__).with_name('baseline_atmosphere.gd')
    probe = Path(__file__).with_name('review_atmosphere.gd')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    config = dict(output=str(output), components=False, baseline_code=baseline.read_text(),
                  baseline_sha256=hashlib.sha256(baseline.read_bytes()).hexdigest(),
                  baseline_commit='148ba0bb578e9a01db501444fd11823fa09e8212')
    if args.replay:
        reference = json.loads(args.replay.read_text())
        config.update(initial_save=json.loads(reference['initial_save_text']),
                      initial_save_text=reference['initial_save_text'],
                      region_blobs=reference['region_blobs'],
                      views=[v for v in reference['views'] if v['id'] in ['forest', 'creature-close']])
    recipe = output / 'recipe.json'
    recipe.write_text(json.dumps(config, indent=2) + '\n')
    source = SourceRun(project)
    source.begin_report(output)
    status = dict(host=socket.gethostname(), renderer=args.renderer, target_pc_acceptance=False,
                  timing_note='Six retained force_draw samples after four warmups, excluding readback; software render evidence, no gameplay FPS claim.')
    observed = []
    display = None
    with ExitStack() as stack:
        for filename in ['/tmp/voxelverse-heavy.lock', '/tmp/voxelverse-r32-db514e109ac6-heavy.lock']:
            lock = stack.enter_context(open(filename, 'a+'))
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        status['locks'] = ['/tmp/voxelverse-heavy.lock', '/tmp/voxelverse-r32-db514e109ac6-heavy.lock']
        observed.append(dict(phase='before', processes=godot_processes()))
        if observed[0]['processes']:
            raise RuntimeError('Foreign Godot processes present; no capture launched')
        env = os.environ.copy()
        env.update(LIBGL_ALWAYS_SOFTWARE='1', LP_NUM_THREADS='2', GODOT_SILENCE_ROOT_WARNING='1')
        if args.graphics_lib: env['LD_LIBRARY_PATH'] = str(args.graphics_lib.resolve())
        if args.vulkan_icd: env['VK_ICD_FILENAMES'] = str(args.vulkan_icd.resolve())
        try:
            if args.xvfb:
                number = 20000 + secrets.randbelow(20000)
                env['DISPLAY'] = f'127.0.0.1:{number}'
                with (output / 'display.log').open('w') as log:
                    display = subprocess.Popen([str(args.xvfb.resolve()), f':{number}', '-screen', '0', '960x540x24',
                                                '-nolisten', 'unix', '-listen', 'tcp', '-ac',
                                                '-xkbdir', str(args.xkbdir.resolve())], env=env, stdout=log, stderr=log)
                for _ in range(50):
                    if display.poll() is not None: raise RuntimeError('Xvfb exited; inspect display.log')
                    with socket.socket() as connection:
                        connection.settimeout(0.2)
                        if connection.connect_ex(('127.0.0.1', 6000 + number)) == 0: break
                    time.sleep(0.1)
                else: raise RuntimeError('Xvfb not ready')
            with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='voxelverse-atmosphere-') as temp:
                engine_env = isolated_env(Path(temp))
                engine_env.update({key: env[key] for key in ['DISPLAY', 'LD_LIBRARY_PATH', 'VK_ICD_FILENAMES',
                                  'LIBGL_ALWAYS_SOFTWARE', 'LP_NUM_THREADS', 'GODOT_SILENCE_ROOT_WARNING'] if key in env})
                command = [str(editor), '--path', str(project), '--audio-driver', 'Dummy',
                           '--rendering-method', args.renderer, '--resolution', '960x540', '--disable-render-loop',
                           '--script', str(probe), '--', str(recipe)]
                status['command'] = command
                status['external_inputs'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in [baseline, probe, Path(__file__)]}
                started = time.monotonic()
                with (output / 'run.log').open('w') as log:
                    process = subprocess.Popen(command, env=engine_env, stdout=log, stderr=log)
                    try:
                        while process.poll() is None:
                            observed.append(dict(elapsed=time.monotonic() - started, processes=godot_processes()))
                            if time.monotonic() - started > 600:
                                process.kill()
                                status['timed_out'] = True
                                break
                            time.sleep(1)
                    finally:
                        if process.poll() is None: process.kill()
                        process.wait()
                status.update(exit_code=process.returncode, seconds=time.monotonic() - started)
            source.observe('finish', force=True)
            status['provenance'] = source.write_report(output)
            log_text = (output / 'run.log').read_text()
            report_path = output / 'atmosphere-comparison.json'
            report = json.loads(report_path.read_text()) if report_path.exists() else {}
            pixels = pixel_pairs(output, report)
            status.update(passed=process.returncode == 0 and not ERROR.search(log_text)
                          and report.get('passed') is True and not source.blocked
                          and len(pixels) == len(report.get('views', [])) * 2 and bool(pixels)
                          and all(p['before_restore_exact'] for p in pixels)
                          and all(p['changed_pixels'] > 0 for p in pixels)
                          and all(p['lighting_changed_pixels'] > 0 if p['id'].endswith('-day') else p['lighting_changed_pixels'] == 0 for p in pixels)
                          and len(list(output.glob('*.png'))) == len(pixels) * 4,
                          source=source.summary(source.current), observed_godot_processes=observed,
                          pixels=pixels, images={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.png')},
                          log_sha256=hashlib.sha256((output / 'run.log').read_bytes()).hexdigest())
            (output / 'results.json').write_text(json.dumps(status, indent=2) + '\n')
            print(json.dumps({key: status[key] for key in ['passed', 'exit_code', 'seconds', 'host', 'renderer', 'pixels']}))
            if not status['passed']: print(log_text[-8000:])
            return 0 if status['passed'] else 1
        finally:
            if display:
                display.terminate()
                display.wait(timeout=10)


if __name__ == '__main__':
    raise SystemExit(main())
