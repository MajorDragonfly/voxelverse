from pathlib import Path
import os,sys,json,subprocess,secrets,socket,time
from argparse import Namespace
repo=Path('/workspace/scratch/bac0d501b6e8/gfx-ref-03/voxelverse')
sys.path.insert(0,str(repo/'tools'))
from profile_environment import main
from validation_provenance import SourceRun
out=Path('/workspace/scratch/bac0d501b6e8/gfx-ref-04/evidence/cluster-fixed')
out.mkdir(exist_ok=False)
source=SourceRun(repo);source.begin_report(out)
base=repo.parent/'toolchain'
os.environ.update(LIBGL_ALWAYS_SOFTWARE='1',LP_NUM_THREADS='2',GODOT_SILENCE_ROOT_WARNING='1',LD_LIBRARY_PATH=str(base/'display/usr/lib/x86_64-linux-gnu'),VK_ICD_FILENAMES=str(base/'lvp-absolute.json'))
keyboard=Path('/usr/bin/xkbcomp');target=base/'display/usr/bin/xkbcomp'
if not keyboard.exists() and not keyboard.is_symlink():keyboard.symlink_to(target)
assert keyboard.resolve()==target
number=20000+secrets.randbelow(20000);os.environ['DISPLAY']=f'127.0.0.1:{number}'
with (out/'display.log').open('w') as log:
 display=subprocess.Popen([str(base/'display/usr/bin/Xvfb'),f':{number}','-screen','0','960x540x24','-nolisten','unix','-listen','tcp','-ac','-xkbdir','/usr/share/X11/xkb'],stdout=log,stderr=log)
try:
 for _ in range(50):
  if display.poll() is not None:raise RuntimeError('Xvfb stopped')
  with socket.socket() as s:
   s.settimeout(.2)
   if s.connect_ex(('127.0.0.1',6000+number))==0:break
  time.sleep(.1)
 else:raise RuntimeError('Xvfb not ready')
 sys.argv=['profile_environment','--godot',str(base/'editor/Godot_v4.6.3-stable_linux.x86_64'),'--renderer','gl_compatibility','--cases','cluster','--seeds','15838','--size','960','540','--frames','4','--warmup','4','--fast-setup','--output',str(out)]
 code=main()
 source.observe('finish',force=True)
 provenance=source.write_report(out)
 assert not source.blocked
 summary={'passed':code==0,'source':source.summary(source.current),'provenance':provenance,'scope':'Existing actual cluster lab comparison; original 0.004 colour threshold and draw-call reduction assertion unchanged; not regular campaign/FPS acceptance.'}
 (out/'source-results.json').write_text(json.dumps(summary,indent=2)+'\n')
 raise SystemExit(code)
finally:
 display.terminate();display.wait(timeout=10)
