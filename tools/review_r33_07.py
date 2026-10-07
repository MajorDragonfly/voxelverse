#!/usr/bin/env python3
"""Exclusive host review for R33-07; preserved 300s native/90s load guards."""
import argparse,fcntl,hashlib,json,os,signal,subprocess,sys,tempfile,time
from pathlib import Path
from validation_support import isolated_env,validation_editor
from validation_provenance import SourceRun
from validate_godot import ERROR
ROOT=Path(__file__).resolve().parents[1]
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def inventory():
    found=[]
    for p in Path('/proc').iterdir():
        if not p.name.isdigit(): continue
        try:
            name=(p/'comm').read_text().strip()
            if 'godot' in name.lower() or 'xvfb' in name.lower():
                found.append({'pid':int(p.name),'name':name,'command':(p/'cmdline').read_bytes().replace(b'\0',b' ').decode(errors='replace')})
        except OSError: pass
    return found

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--renderer',choices=['gl_compatibility','forward_plus'])
    parser.add_argument('--reference-save',type=Path)
    parser.add_argument('--skip-import',action='store_true')
    args=parser.parse_args();out=args.output.resolve()
    if out.exists() or out.is_relative_to(ROOT): parser.error('New output directory outside source required')
    out.mkdir(parents=True)
    locks=[]
    try:
        for name in ['/tmp/voxelverse-heavy.lock','/tmp/voxelverse-r32-db514e109ac6-heavy.lock']:
            lock=open(name,'a+');locks.append(lock)
            try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError:
                (out/'blocked.json').write_text(json.dumps({'ran':False,'reason':'occupied host slot','lock':name}))
                print('BLOCKED: occupied host slot',flush=True);return 2
        processes=inventory()
        (out/'host-start.json').write_text(json.dumps({'host':os.uname().nodename,'pid':os.getpid(),'processes':processes,'cpu':Path('/proc/cpuinfo').read_text(),'memory':Path('/proc/meminfo').read_text(),'unix':time.time()},indent=2))
        if processes:
            print('BLOCKED: Godot/Xvfb already active',flush=True);return 2
        if not args.renderer:
            command=[sys.executable,str(ROOT/'tools/validate_godot.py'),'--godot',args.godot,'--tests','r33_07_extreme_weather_test','weather_storm_test','weather_model_test','regional_weather_test','planet_climate_test','weather_forecast_ui_test','weather_runtime_test','--skip-main','--output',str(out/'focused')]
            if args.skip_import: command.append('--skip-import')
            code=subprocess.run(command).returncode
            (out/'host-end.json').write_text(json.dumps({'exit_code':code,'processes':inventory(),'unix':time.time()}))
            return code
        source=SourceRun(ROOT);source.begin_report(out)
        with tempfile.TemporaryDirectory(prefix='r33-07-native-') as userdata,validation_editor(args.godot) as godot:
            env=isolated_env(Path(userdata))
            command=['xvfb-run','-a','-s','-screen 0 960x540x24',str(godot),'--path',str(ROOT),'--display-driver','x11','--rendering-method',args.renderer,'--audio-driver','Dummy','--script','res://tools/review_r33_07_extreme.gd','--','--capture',str(out)]
            if args.reference_save: command+=['--reference-save',str(args.reference_save.resolve())]
            started=time.monotonic();error=None
            try:
                with (out/'render.log').open('w') as log:
                    proc=subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
                    try: code=proc.wait(timeout=300)
                    except subprocess.TimeoutExpired:
                        os.killpg(proc.pid,signal.SIGTERM)
                        try: proc.wait(timeout=10)
                        except subprocess.TimeoutExpired:
                            os.killpg(proc.pid,signal.SIGKILL);proc.wait()
                        raise
            except (OSError,subprocess.TimeoutExpired) as exc:
                code=124 if isinstance(exc,subprocess.TimeoutExpired) else 1;error=str(exc)
        source.observe('native',force=True);provenance=source.write_report(out)
        review=json.loads((out/'review.json').read_text()) if (out/'review.json').exists() else {}
        log=(out/'render.log').read_text() if (out/'render.log').exists() else ''
        frames=sorted(out.glob('frame-*.png'))
        passed=code==0 and not error and not ERROR.search(log) and review.get('passed') and review.get('renderer')==args.renderer and len(frames)==27 and len(list(out.glob('*.png')))==36 and len(review.get('rows',[]))==35 and provenance['reusable']
        if passed:
            subprocess.run(['ffmpeg','-v','error','-y','-framerate','6','-i',str(out/'frame-%04d.png'),'-c:v','libx264','-threads','2','-crf','22','-pix_fmt','yuv420p',str(out/'sandstorm.mp4')],check=True,timeout=60)
        report={'passed':bool(passed),'exit_code':code,'error':error,'renderer_required':args.renderer,'renderer_observed':review.get('renderer'),'command':command,'wall_seconds':time.monotonic()-started,'timeout_seconds':300,'source_provenance':provenance,'target_pc_acceptance':False,'captures':{p.name:digest(p) for p in out.glob('*.png')},'reference_save_sha256':digest(out/'reference-save.json') if (out/'reference-save.json').exists() else None,'environment':{k:env.get(k) for k in ['DISPLAY','VK_DRIVER_FILES','LIBGL_ALWAYS_SOFTWARE','LP_NUM_THREADS']}}
        (out/'runner.json').write_text(json.dumps(report,indent=2)+'\n')
        (out/'host-end.json').write_text(json.dumps({'exit_code':code,'processes':inventory(),'unix':time.time()}))
        print(json.dumps({'passed':bool(passed),'frames':len(frames),'renderer':review.get('renderer'),'error':error}),flush=True)
        return 0 if passed else 1
    finally:
        for lock in reversed(locks): lock.close()
if __name__=='__main__': raise SystemExit(main())
