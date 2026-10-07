#!/usr/bin/env python3
"""Native GL atlas review with isolated user data and both shared host locks.

Uses the existing validation provenance/editor/data isolation, strict logs and
finite production load guards. Output goes outside the source checkout.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
p = argparse.ArgumentParser()
p.add_argument('--project', type=Path, required=True)
p.add_argument('--godot', required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--xvfb', required=True)
p.add_argument('--xlibs', required=True)
a = p.parse_args()
project = a.project.resolve()
output = a.output.resolve()
if output.is_relative_to(project) or output.exists(): raise SystemExit('Choose a new output outside source.')
sys.path.insert(0, str(project / 'tools'))
from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun
from validate_godot import ERROR
handles = []
for path in ['/tmp/voxelverse-heavy.lock', '/tmp/voxelverse-r32-db514e109ac6-heavy.lock']:
    h = open(path, 'a'); fcntl.flock(h, fcntl.LOCK_EX | fcntl.LOCK_NB); handles.append(h)
output.mkdir(parents=True)
source = SourceRun(project)
source.begin_report(output)
with tempfile.TemporaryDirectory(prefix='int30-map-review-') as temp, validation_editor(a.godot) as editor:
    env = isolated_env(Path(temp))
    env['DISPLAY'] = '127.0.0.1:117'
    env['LD_LIBRARY_PATH'] = a.xlibs + ':' + env.get('LD_LIBRARY_PATH', '')
    with (output/'xvfb.log').open('w') as xlog:
        x = subprocess.Popen([a.xvfb, ':117', '-screen', '0', '1920x1080x24', '-nolisten', 'unix', '-listen', 'tcp', '-ac'], env=env, stdout=xlog, stderr=subprocess.STDOUT)
        try:
            # Readiness through the X TCP endpoint, bounded; no fixed long sleep.
            import socket, time
            for retry in range(100):
                try:
                    with socket.create_connection(('127.0.0.1', 6117), .1): break
                except OSError: time.sleep(.05)
            cmd = [str(editor), '--path', str(project), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--script', 'res://tests/int30_world_map_campaign_test.gd', '--', '--capture', str(output/'images')]
            print('COMMAND ' + json.dumps(cmd), flush=True)
            with (output/'render.log').open('w') as log:
                run = subprocess.run(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=420)
            text = (output/'render.log').read_text()
            images = sorted((output/'images').glob('*.png'))
            result = {'passed':run.returncode == 0 and not ERROR.search(text) and 'INT30_WORLD_MAP_CAMPAIGN_OK' in text and len(images)==55, 'exit':run.returncode, 'images':len(images), 'scope':'Native viewport input; title/new spherical campaign/map/save/cold restart; GL software renderer', 'sha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in images}}
            (output/'results.json').write_text(json.dumps(result, indent=2)+'\n')
            print(json.dumps(result | {'sha256': 'see results.json'}), flush=True)
        finally:
            x.terminate(); x.wait(timeout=10)
source.observe("render", force=True)
(output/"source-report.json").write_text(json.dumps(source.write_report(output), indent=2)+"\n")
sys.exit(0 if result['passed'] else 1)
