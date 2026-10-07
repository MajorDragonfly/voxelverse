#!/usr/bin/env python3
"""Run pristine R33 product and diagnosis overlay serially on one exclusive CI host."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

BASE='94de70cacd250337976b8f63031fff4afc72e2bb'

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    project=Path(__file__).resolve().parents[1]
    output=a.output.resolve(); output.mkdir(parents=True,exist_ok=False)
    baseline=output.parent/'r33-08-baseline'
    subprocess.run(['git','fetch','--depth=1','origin',BASE],cwd=project,check=True)
    subprocess.run(['git','worktree','add','--detach',str(baseline),BASE],cwd=project,check=True)
    for file in (project/'tools').glob('review_r33_08_*'):
        if file.is_file(): shutil.copy2(file,baseline/'tools'/file.name)
    subprocess.run(['git','add','tools'],cwd=baseline,check=True)
    subprocess.run(['git','-c','user.name=R33 diagnosis','-c','user.email=diagnosis@example.invalid',
                    'commit','-m','QA: diagnostic route on unchanged R33 product'],cwd=baseline,check=True)
    statuses=[]
    fixture=None
    env=os.environ.copy()
    for label,source,trace in [('baseline',baseline,False),('overlay',project,True)]:
        import_dir=output/(label+'-checks')
        command=['python3',str(source/'tools/validate_godot.py'),'--godot',a.godot,'--project',str(source),
            '--tests','int30_scenery_collision_test','surface_population_budget_test','campaign_atmosphere_test',
            'r32_07_scenery_margin_test','--skip-main','--output',str(import_dir)]
        # Every import/test/capture is under both locks. There is no local duplicate.
        code=subprocess.run(['python3',str(source/'tools/review_r33_08_host.py'),'--project',str(source),
            '--output',str(output/(label+'-checks-host.jsonl')),'--',*command],cwd=source,env=env).returncode
        statuses.append({'label':label+'-checks','code':code})
        if code:
            (output/'suite-status.json').write_text(json.dumps(statuses,indent=2)+'\n')
            return 1
        for renderer in ('gl_compatibility','forward_plus'):
            name=label+'-'+renderer
            if fixture: env['R33_SAVE_FIXTURE']=str(fixture)
            command=['python3',str(source/'tools/review_r33_08_publication_check.py'),'--godot',a.godot,
                '--world','--renderer',renderer,'--xvfb','/usr/bin/Xvfb','--output',str(output/name)]
            if trace: command.append('--publication-trace')
            code=subprocess.run(['python3',str(source/'tools/review_r33_08_host.py'),'--project',str(source),
                '--output',str(output/(name+'-host.jsonl')),'--',*command],cwd=source,env=env).returncode
            statuses.append({'label':name,'code':code})
            if fixture is None and (output/name/'int30-collision-source-slot.json').is_file():
                fixture=output/name/'int30-collision-source-slot.json'
                statuses[-1]['fixture_sha256']=hashlib.sha256(fixture.read_bytes()).hexdigest()
            if fixture is None:
                (output/'suite-status.json').write_text(json.dumps(statuses,indent=2)+'\n')
                return 1
    (output/'suite-status.json').write_text(json.dumps(statuses,indent=2)+'\n')
    args=['python3',str(project/'tools/review_r33_08_publication_report.py'),'--output',str(output/'comparison.json')]
    for label in ('baseline','overlay'):
        for renderer in ('gl_compatibility','forward_plus'): args+=['--run',str(output/(label+'-'+renderer))]
    subprocess.run(args,check=True)
    return 0 if all(x['code']==0 for x in statuses) else 1

if __name__=='__main__': raise SystemExit(main())
