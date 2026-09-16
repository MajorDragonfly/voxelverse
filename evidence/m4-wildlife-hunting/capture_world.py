import sys,subprocess,tempfile,json,time,hashlib
from pathlib import Path
repo=Path('/workspace/scratch/176ae31ef22c/voxelverse-hunting')
sys.path.insert(0,str(repo/'tools'))
from validation_support import isolated_env
out=Path(sys.argv[1]);out.mkdir(exist_ok=False)
argv=['/workspace/scratch/2c2866d70564/godot','--headless','--path',str(repo),'--script','res://tests/wildlife_hunting_world_test.gd']
def source():
    return {name:subprocess.check_output(command,cwd=repo,text=True).strip() for name,command in {'commit':['git','rev-parse','HEAD'],'tree':['git','rev-parse','HEAD^{tree}'],'status':['git','status','--porcelain']}.items()}
before=source()
with tempfile.TemporaryDirectory(prefix='voxelverse-hunting-pipe-') as tmp:
    start=time.monotonic()
    r=subprocess.run(argv,env=isolated_env(Path(tmp)),capture_output=True,text=True,timeout=180)
    log=r.stdout+'\n'+r.stderr
    (out/'world.log').write_text(log)
    markers=[json.loads(line) for line in r.stdout.splitlines() if line.startswith('{') and '"test":"wildlife_hunting_world"' in line]
    report={'command':argv,'exit_code':r.returncode,'seconds':time.monotonic()-start,'source_before':before,'source_after':source(),'environment':'Linux headless; isolated XDG/APPDATA directories; stdout/stderr captured via pipes','engine':'4.6.3.stable.official.7d41c59c4','log_sha256':hashlib.sha256(log.encode()).hexdigest(),'complete_result':markers[-1] if markers else {}}
    report['passed']=r.returncode==0 and report['complete_result'].get('passed') is True and report['complete_result'].get('observations',{}).get('restart_exit')==0 and report['source_before']==report['source_after'] and not before['status'] and 'SCRIPT ERROR' not in log and '\nERROR:' not in log
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
    if not report['passed']: print(log[-16000:])
    sys.exit(0 if report['passed'] else 1)
