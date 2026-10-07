import argparse,fcntl,json,os,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--output',required=True);p.add_argument('command',nargs=argparse.REMAINDER);a=p.parse_args();out=Path(a.output);out.mkdir(parents=True,exist_ok=False)
locks=[]
for name in ['/tmp/voxelverse-heavy.lock','/tmp/voxelverse-r32-db514e109ac6-heavy.lock']:
 f=open(name,'a+');fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB);locks.append(f)
for entry in Path('/proc').iterdir():
 if not entry.name.isdigit():continue
 try:
  if (entry/'comm').read_text().lower().startswith('godot'):raise RuntimeError('Another Godot process present')
 except OSError:pass
cmd=a.command[1:] if a.command[:1]==['--'] else a.command
report={'host':os.uname().nodename,'start':time.time(),'command':cmd,'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'tree':subprocess.check_output(['git','rev-parse','HEAD^{tree}'],text=True).strip(),'status':subprocess.check_output(['git','status','--porcelain'],text=True)}
for f in locks:
 f.seek(0);f.truncate();f.write(json.dumps({'owner':'R33-05','project':os.getcwd(),'pid':os.getpid()}));f.flush()
try:
 with (out/'run.log').open('w') as log:r=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=650)
 report['exit_code']=r.returncode
finally:
 report['end']=time.time();(out/'host.json').write_text(json.dumps(report,indent=2)+'\n')
 for f in locks:
  f.seek(0);f.truncate();f.flush();fcntl.flock(f,fcntl.LOCK_UN);f.close()
print((out/'run.log').read_text()[-12000:]);raise SystemExit(r.returncode)
