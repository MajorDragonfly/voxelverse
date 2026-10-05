#!/usr/bin/env python3
"""Paired production shader views in the public campaign and wind regressions."""
import argparse
import fcntl
import hashlib
import json
import os
import secrets
import shutil
from pathlib import Path
import subprocess
import tempfile
import time

from validation_support import isolated_env
from validate_godot import ERROR
from validation_provenance import SourceRun

BASE = '2a738a4891a8de11d682c469833ade4dc9b01dfb'
FILES = ['assets/catalog/planet_foliage.gdshader',
         'world/surface/visuals/surface_scenery.gdshader',
         'assets/catalog/planet_surface_detail.gdshaderinc']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--renderer', choices=['gl_compatibility', 'forward_plus'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--xvfb', type=Path, help='Optional TCP-only Xvfb for this portable environment')
    parser.add_argument('--slot-lock', type=Path, required=True, help='Confirmed host slot; held for the entire capture')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    provenance = SourceRun(project)
    provenance.begin_report(output)
    source = {name: subprocess.check_output(['git', 'rev-parse', ref], cwd=project, text=True).strip()
              for name, ref in [('commit', 'HEAD'), ('tree', 'HEAD^{tree}') ]}
    source['dirty_paths'] = subprocess.check_output(['git', 'status', '--porcelain'], cwd=project, text=True)
    source['baseline'] = BASE
    source['shader_sha256'] = {p: hashlib.sha256((project / p).read_bytes()).hexdigest() for p in FILES}
    source['probe_sha256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                            for p in (project / 'tools').glob('review_r32_09_*') if p.is_file()}
    (output / 'source.json').write_text(json.dumps(source, indent=2) + '\n')
    baseline = output / 'baseline-shaders'
    baseline.mkdir()
    for path in FILES:
        (baseline / Path(path).name).write_bytes(subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=project))
    with args.slot_lock.open('a+') as lock, tempfile.TemporaryDirectory(prefix='r32-09-userdata-') as temporary:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        env = isolated_env(Path(temporary))
        env['LIBGL_ALWAYS_SOFTWARE'] = '1'
        env['GODOT_SILENCE_ROOT_WARNING'] = '1'
        xserver = None
        xlog = None
        try:
            if args.xvfb:
                xlog = (output / 'xvfb.log').open('w')
                # No shared display/socket changes. The child shares this namespace.
                display = 120 + secrets.randbelow(10000)
                xcommand = [str(args.xvfb.resolve()), ':' + str(display), '-screen', '0', '960x540x24',
                                           '-nolisten', 'unix', '-nolisten', 'local', '-listen', 'tcp', '-ac']
                xserver = subprocess.Popen(xcommand, env=env, stdout=xlog, stderr=subprocess.STDOUT)
                env['DISPLAY'] = '127.0.0.1:' + str(display)
                time.sleep(1)
                if xserver.poll() is not None:
                    raise RuntimeError('Portable Xvfb failed; inspect xvfb.log')
            (output / 'renderer-environment.json').write_text(json.dumps({
                'xvfb_command': xcommand if args.xvfb else None,
                'environment': {k: env.get(k) for k in ['DISPLAY', 'LD_LIBRARY_PATH', 'VK_ICD_FILENAMES',
                    'LIBGL_ALWAYS_SOFTWARE', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']},
                'note': 'Task-owned fresh display; no existing display, socket or stale lock is removed.'}, indent=2)+'\n')
            results = []
            components = ['ancient_oak_v2', 'layered_rock_v2']
            for name, timeout in [('wind', 90)] + [('campaign-' + family, 600) for family in components]:
                folder = output / name
                folder.mkdir()
                script = 'campaign' if name.startswith('campaign-') else name
                command = [str(args.godot.resolve()), '--path', str(project), '--rendering-method', args.renderer,
                           '--audio-driver', 'Dummy', '--script', f'res://tools/review_r32_09_{script}.gd',
                           '--', str(folder), str(baseline)]
                if script == 'campaign':
                    command.append(name.removeprefix('campaign-'))
                started = time.monotonic()
                try:
                    with (folder / 'render.log').open('w') as log:
                        run = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
                except subprocess.TimeoutExpired:
                    (folder / 'command.json').write_text(json.dumps({'command': command, 'exit_code': None,
                        'seconds': time.monotonic()-started, 'timeout_seconds': timeout, 'timed_out': True}, indent=2)+'\n')
                    raise
                record = {'command': command, 'exit_code': run.returncode, 'seconds': time.monotonic()-started}
                (folder / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
                text = (folder / 'render.log').read_text()
                if run.returncode or ERROR.search(text):
                    raise RuntimeError(f'{name} failed: {text[-3000:]}')
                result = json.loads((folder / 'capture.json').read_text())
                if not result['passed']:
                    raise RuntimeError(f'{name} incomplete or negative')
                results.append({'name': name, **record})
                if provenance.observe(name)['status'] != 'unchanged':
                    raise RuntimeError('Campaign source changed during capture')
            # Each family replays the same immutable public save in a bounded
            # process. Retain the original captures and commands unchanged.
            merged = output / 'campaign'
            merged.mkdir()
            captures = [json.loads((output / ('campaign-' + family) / 'capture.json').read_text())
                        for family in components]
            identity = lambda c: (c['seed'], c['initial_save_sha256'], c['body']['id'],
                                  c['renderer'], c['resolution'], c['frozen_weather'], c['shader_sha256'])
            if identity(captures[0]) != identity(captures[1]):
                raise RuntimeError('Independent material components changed fixed campaign identity')
            aggregate = dict(captures[0])
            for key in ['samples', 'motion', 'settles', 'failures', 'settle_progress']:
                aggregate[key] = [item for c in captures for item in c.get(key, [])]
            aggregate['component_family'] = 'aggregate'
            aggregate['component_captures'] = [{'file': 'campaign-' + family + '/capture.json',
                'sha256': hashlib.sha256((output / ('campaign-' + family) / 'capture.json').read_bytes()).hexdigest()}
                for family in components]
            (merged / 'capture.json').write_text(json.dumps(aggregate, indent=2) + '\n')
            for family in components:
                for png in (output / ('campaign-' + family)).glob('*.png'):
                    shutil.copyfile(png, merged / png.name)
            end_hashes = {p: hashlib.sha256((project / p).read_bytes()).hexdigest() for p in FILES}
            if end_hashes != source['shader_sha256']:
                raise RuntimeError('Material sources changed during capture')
            (output / 'result.json').write_text(json.dumps({'passed': True, 'runs': results,
                'source': source, 'target_pc_accepted': False,
                'scope': 'Same canonical save reloaded per material family, each process bounded to 600 s; eight paused force_draw calls/view; simulation and PNG readback excluded. Software timing is diagnostic, not a target-hardware regression gate.'}, indent=2) + '\n')
        finally:
            provenance.observe('complete', force=True)
            (output / 'source-provenance.json').write_text(json.dumps(provenance.write_report(output), indent=2) + '\n')
            if xserver:
                xserver.terminate()
                xserver.wait(timeout=10)
            if xlog:
                xlog.close()
    print(output)


if __name__ == '__main__':
    main()
