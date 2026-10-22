import json,os,subprocess,sys,tempfile,time
from pathlib import Path
ROOT=Path('/workspace/scratch/bac0d501b6e8')
PROJECT=ROOT/'voxelverse'
sys.path.insert(0,str(PROJECT/'tools'))
from validation_support import isolated_env,validation_editor
from validation_provenance import SourceRun
from validate_godot import ERROR
renderer=sys.argv[2];out=Path(sys.argv[3]);out.mkdir(parents=True,exist_ok=False)
source=SourceRun(PROJECT);source.begin_report(out)
with validation_editor(sys.argv[1]) as editor,tempfile.TemporaryDirectory(prefix='gfx02-rebase-') as tmp:
 env=isolated_env(Path(tmp))
 for key in ['DISPLAY','LD_LIBRARY_PATH','VK_ICD_FILENAMES','LIBGL_ALWAYS_SOFTWARE','LP_NUM_THREADS','GODOT_SILENCE_ROOT_WARNING']:
  if key in os.environ:env[key]=os.environ[key]
 command=[str(editor),'--path',str(PROJECT),'--rendering-method',renderer,'--audio-driver','Dummy','--resolution','640x360','--disable-render-loop','--script','res://tools/review_ground_origin.gd','--',str(out)]
 if len(sys.argv)>4:command.append(sys.argv[4])
 start=time.monotonic()
 with (out/'run.log').open('w') as log:r=subprocess.run(command,env=env,stdout=log,stderr=log,timeout=90)
source.observe('finish',force=True);provenance=source.write_report(out)
text=(out/'run.log').read_text();report=json.loads((out/'rebase.json').read_text()) if (out/'rebase.json').exists() else {}
result=dict(passed=r.returncode==0 and report.get('passed') is True and not ERROR.search(text) and not source.blocked,exit_code=r.returncode,seconds=time.monotonic()-start,command=command,provenance=provenance,probe=report)
(out/'results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['provenance','command']}))
if not result['passed']:print(text[-2500:])
sys.exit(0 if result['passed'] else 1)
