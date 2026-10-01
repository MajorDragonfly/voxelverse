#!/usr/bin/env python3
"""Run the retained default-cache cold-load baseline and joined-Thread control."""
import argparse, hashlib, json, pathlib, subprocess, time
p = argparse.ArgumentParser()
p.add_argument('--engine', required=True)
p.add_argument('--output', required=True)
a = p.parse_args()
bundle = pathlib.Path(__file__).resolve().parent
out = pathlib.Path(a.output); out.mkdir(parents=True, exist_ok=False)
(out/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Owned Scene Loader proof"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
for i in range(3000):
 (out/('empty%d.tscn'%i)).write_text('[gd_scene format=3]\n[node name="Empty" type="Node"]\n')
summary = {'engine': a.engine, 'version': subprocess.check_output([a.engine,'--version'],text=True).strip(), 'count':3000, 'cases':[]}
for name in ['baseline-default-cold', 'owned-default-cold']:
 code = (bundle/(name+'.gd')).read_text(); (out/(name+'.gd')).write_text(code)
 command = [a.engine,'--headless','--verbose','--path',str(out),'--script','res://'+name+'.gd']
 started = time.monotonic(); result = subprocess.run(command,capture_output=True,text=True,timeout=60)
 log = result.stdout + result.stderr; (out/(name+'.log')).write_text(log)
 summary['cases'].append({'name':name,'exit_code':result.returncode,'seconds':round(time.monotonic()-started,3),'command':command,'log_sha256':hashlib.sha256(log.encode()).hexdigest(),'leaked_refcount0':[line for line in log.splitlines() if line.startswith('Leaked instance: RefCounted:') and 'Reference count: 0' in line],'observations':[line for line in log.splitlines() if line.startswith(('NORMAL_GET_RACE_PROBE','OWNED_THREAD_DEFAULT_COLD','NATIVE_PRESERVED'))]})
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
