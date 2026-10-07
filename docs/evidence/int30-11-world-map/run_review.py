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
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import time
p = argparse.ArgumentParser()
p.add_argument('--project', type=Path, required=True)
p.add_argument('--godot', required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--xvfb', required=True)
p.add_argument('--xlibs', required=True)
p.add_argument('--wait-seconds', type=int, default=0)
p.add_argument('--probe-only',action='store_true')
a = p.parse_args()
project = a.project.resolve()
output = a.output.resolve()
if output.is_relative_to(project) or output.exists(): raise SystemExit('Choose a new output outside source.')
sys.path.insert(0, str(project / 'tools'))
from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun
from validate_godot import ERROR
def segment(cmd,env,path,timeout):
    started=time.monotonic()
    with path.open('w') as log:
        proc=subprocess.Popen(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        try:code=proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid,signal.SIGTERM)
            try:proc.wait(timeout=5)
            except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait(timeout=5)
            log.write('\nERROR: review segment timed out\n');code=124
    return {'command':cmd,'exit':code,'seconds':round(time.monotonic()-started,3),'timeout_seconds':timeout}
deadline = time.monotonic() + min(max(a.wait_seconds, 0), 60)
while True:
    handles = []
    try:
        for path in ['/tmp/voxelverse-heavy.lock', '/tmp/voxelverse-r32-db514e109ac6-heavy.lock']:
            h = open(path, 'a'); handles.append(h)
            fcntl.flock(h, fcntl.LOCK_EX | fcntl.LOCK_NB)
        break
    except BlockingIOError:
        for h in handles: h.close()
        if time.monotonic() >= deadline: raise SystemExit('HOST_WAIT_BUSY: no engine started')
        time.sleep(0.1)
print('HOST_LOCK_ACQUIRED: native map review', flush=True)
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
            cmd = [str(editor), '--path', str(project), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--script', 'res://tests/int30_world_map_campaign_test.gd', '--'] + (['--input-probe'] if a.probe_only else ['--capture',str(output/'images'),'--ui-only'])
            print('COMMAND ' + json.dumps(cmd), flush=True)
            run=segment(cmd,env,output/'render.log',120 if a.probe_only else 420)
            text = (output/'render.log').read_text()
            images = sorted((output/'images').glob('*.png'))
            ok=run['exit']==0 and not ERROR.search(text) and 'INT30_WORLD_MAP_CAMPAIGN_OK' in text and len(images)==(0 if a.probe_only else 56)
            segments=[run]
            if ok and not a.probe_only:
                cold=[str(editor),'--headless','--path',str(project),'--script','res://tests/int30_world_map_campaign_test.gd','--','--map-restart']
                restart=segment(cold,env,output/'restart.log',420);segments.append(restart)
                cold_text=(output/'restart.log').read_text()
                ok=restart['exit']==0 and not ERROR.search(cold_text) and 'INT30_WORLD_MAP_RESTART_OK' in cold_text
            result = {'passed':ok,'images':len(images),'segments':segments,'scope':'Short existing-panel X11 input diagnosis' if a.probe_only else 'Actual X11 input; title/new spherical campaign/map/seam/save and separate cold restart/body travel in the same isolated data','sha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in images}}
            result.update(
                          environment={'renderer':'gl_compatibility','graphics':'Mesa llvmpipe','audio':'Dummy','display':env['DISPLAY'],'user_data':'isolated; shared only with the cold-restart child'},
                          godot=subprocess.check_output([str(editor),'--version'],env=env,text=True,timeout=10).strip())
            (output/'results.json').write_text(json.dumps(result, indent=2)+'\n')
            print(json.dumps(result | {'sha256': 'see results.json'}), flush=True)
        finally:
            x.terminate(); x.wait(timeout=10)
source.observe("render", force=True)
provenance = source.write_report(output)
(output/"source-report.json").write_text(json.dumps(provenance, indent=2)+"\n")
result['provenance'] = {'status':provenance['status'],'reusable':provenance['reusable']}
result['passed'] = result['passed'] and not source.blocked and provenance['reusable']
(output/'results.json').write_text(json.dumps(result,indent=2)+'\n')
sys.exit(0 if result['passed'] else 1)
