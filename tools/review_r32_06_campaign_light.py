#!/usr/bin/env python3
"""Native, isolated regular-campaign light captures with exact source evidence."""
import argparse
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

from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun
from validate_godot import ERROR


def godot_processes():
    result = []
    for directory in Path('/proc').iterdir():
        if not directory.name.isdigit():
            continue
        try:
            command = (directory / 'cmdline').read_bytes().split(b'\0')
            name = os.fsdecode(command[0])
            if 'godot' in Path(name).name.lower():
                result.append({'pid': int(directory.name), 'executable': name,
                               'arguments': [os.fsdecode(x) for x in command[1:] if x]})
        except (OSError, IndexError):
            pass
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--replay', type=Path, help='campaign-light.json from the exact initial reference')
    parser.add_argument('--xvfb', type=Path, help='Optional portable Xvfb')
    parser.add_argument('--graphics-lib', type=Path)
    parser.add_argument('--vulkan-icd', type=Path)
    parser.add_argument('--lock', type=Path, default=Path('/tmp/voxelverse-r32-db514e109ac6-heavy.lock'))
    parser.add_argument('--no-components', action='store_true')
    parser.add_argument('--component-views', nargs='+', choices=['forest', 'snow', 'water', 'creature-horizon'])
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    config = {'output': str(output), 'components': not args.no_components}
    if args.component_views:
        config['component_views'] = args.component_views
    if args.replay:
        reference = json.loads(args.replay.read_text())
        config.update(initial_save=reference['initial_save'], views=reference['views'])
    config_path = output / 'recipe.json'
    config_path.write_text(json.dumps(config, indent=2) + '\n')
    source = SourceRun(project)
    source.begin_report(output)
    display = None
    env = os.environ.copy()
    env.update(LIBGL_ALWAYS_SOFTWARE='1', LP_NUM_THREADS='2', GODOT_SILENCE_ROOT_WARNING='1')
    if args.graphics_lib:
        env['LD_LIBRARY_PATH'] = str(args.graphics_lib.resolve())
    if args.vulkan_icd:
        env['VK_ICD_FILENAMES'] = str(args.vulkan_icd.resolve())
    lock = args.lock.open('a+')
    # Never block the conversation for more than one minute. The caller may
    # retry after the current owner releases; no unlocked fallback exists.
    deadline = time.monotonic() + 60
    while True:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except BlockingIOError:
            if time.monotonic() >= deadline:
                raise RuntimeError('R32 heavy slot occupied; no capture started')
            time.sleep(0.25)
    observed = [{'phase': 'before', 'processes': godot_processes()}]
    status = {'host': socket.gethostname(), 'renderer': args.renderer, 'lock': str(args.lock),
              'target_pc_acceptance': False, 'timing_note': 'Six force_draw samples per paused scene after four warmup draws, readback excluded. Software GPU and any recorded foreign Godot processes prevent FPS/target-PC conclusions.'}
    try:
        if args.xvfb:
            number = 20000 + secrets.randbelow(20000)
            env['DISPLAY'] = f'127.0.0.1:{number}'
            with (output / 'display.log').open('w') as log:
                display = subprocess.Popen([str(args.xvfb.resolve()), f':{number}', '-screen', '0', '960x540x24',
                                            '-nolisten', 'unix', '-listen', 'tcp', '-ac',
                                            '-xkbdir', '/usr/share/X11/xkb'], env=env, stdout=log, stderr=log)
            for _ in range(50):
                if display.poll() is not None:
                    raise RuntimeError('Xvfb exited; inspect display.log')
                with socket.socket() as connection:
                    connection.settimeout(0.2)
                    if connection.connect_ex(('127.0.0.1', 6000 + number)) == 0:
                        break
                time.sleep(0.1)
            else:
                raise RuntimeError('Xvfb not ready')
        with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='r32-06-light-') as temp:
            engine_env = isolated_env(Path(temp))
            engine_env.update({key: env[key] for key in ['DISPLAY', 'LD_LIBRARY_PATH', 'VK_ICD_FILENAMES', 'LIBGL_ALWAYS_SOFTWARE', 'LP_NUM_THREADS', 'GODOT_SILENCE_ROOT_WARNING'] if key in env})
            command = [str(editor), '--path', str(project), '--audio-driver', 'Dummy',
                       '--rendering-method', args.renderer, '--resolution', '960x540', '--disable-render-loop',
                       '--script', 'res://tools/review_r32_06_campaign_light.gd', '--', str(config_path)]
            status['command'] = command
            started = time.monotonic()
            with (output / 'run.log').open('w') as log:
                process = subprocess.Popen(command, env=engine_env, stdout=log, stderr=log)
                while process.poll() is None:
                    observed.append({'elapsed': time.monotonic() - started, 'processes': godot_processes()})
                    if time.monotonic() - started > 600:
                        process.kill()
                        process.wait()
                        status['timed_out'] = True
                        break
                    time.sleep(1)
            status.update(exit_code=process.returncode, seconds=time.monotonic() - started)
        source.observe('finish', force=True)
        provenance = source.write_report(output)
        text = (output / 'run.log').read_text()
        captures = output / 'campaign-light.json'
        data = json.loads(captures.read_text()) if captures.exists() else {}
        expected = len(data.get('views', [])) * 2
        if config['components']:
            expected += sum(view['id'] in config.get('component_views', ['forest', 'snow', 'water', 'creature-horizon']) for view in data.get('views', [])) * 5
        status.update(passed=process.returncode == 0 and not ERROR.search(text) and data.get('passed') is True and not source.blocked
                      and expected > 0 and len(list(output.glob('*.png'))) == expected,
                      source=source.summary(source.current), provenance=provenance, observed_godot_processes=observed,
                      images={path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in output.glob('*.png')},
                      log_sha256=hashlib.sha256((output / 'run.log').read_bytes()).hexdigest())
        (output / 'results.json').write_text(json.dumps(status, indent=2) + '\n')
        print(json.dumps({key: status[key] for key in ['passed', 'exit_code', 'seconds', 'host', 'renderer']}))
        if not status['passed']:
            print(text[-8000:])
        return 0 if status['passed'] else 1
    finally:
        if display:
            display.terminate()
            display.wait(timeout=10)
        fcntl.flock(lock, fcntl.LOCK_UN)
        lock.close()


if __name__ == '__main__':
    raise SystemExit(main())
