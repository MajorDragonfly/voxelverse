#!/usr/bin/env python3
"""Same full campaign views at fixed R33 basis and candidate, with original guards."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from review_r32_04 import run
from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun

BASE = '94de70cacd250337976b8f63031fff4afc72e2bb'
HELPERS = ['review_r33_04_capture.gd', 'review_r33_04_capture.gd.uid']


def comparison(before, after):
    previous = json.loads((before / 'views.json').read_text())['rows']
    current = json.loads((after / 'views.json').read_text())['rows']
    if len(previous) != 12 or len(current) != 12:
        raise RuntimeError('Missing original nine full views or three additional hut views')
    pairs = []
    for a, b in zip(previous, current):
        for key in ['label', 'seed', 'clock_s', 'yaw_deg', 'requested_tilt_deg', 'zoom', 'viewport', 'projection']:
            if a[key] != b[key]:
                raise RuntimeError('Comparison condition changed: ' + key)
        for key in ['body_id', 'face', 'u', 'v', 'height']:
            lhs, rhs = a['focus_address'][key], b['focus_address'][key]
            equal = lhs == rhs if key in ['body_id', 'face'] else abs(lhs-rhs) <= (0.001 if key == 'height' else 1e-10)
            if not equal:
                raise RuntimeError('Reference campaign/focus changed: ' + key)
        if b['minimum_frame_clearance_m'] < 0.8:
            raise RuntimeError('Candidate buried frame corner: ' + b['label'])
        if b['requested_tilt_deg'] == 3 and b['forward_up_abs'] >= 0.15:
            raise RuntimeError('Original low-angle requirement failed: ' + b['label'])
        if 'eye_clearance_m' in b and b['eye_clearance_m'] < 1.9:
            raise RuntimeError('Stopped eye still violates original 2 m clearance')
        for folder in [before, after]:
            path = folder / (b['label'] + '.png')
            if not path.is_file():
                raise RuntimeError('Full screenshot missing: ' + str(path))
        pairs.append({'label': b['label'], 'before_eye_clearance_m': a.get('eye_clearance_m'),
                      'after_eye_clearance_m': b.get('eye_clearance_m'),
                      'after_forward_up_abs': b['forward_up_abs'],
                      'after_frame_clearance_m': b['minimum_frame_clearance_m']})
    negative = next(row for row in previous if row['label'] == 'home-eye-level-close-hut')
    if negative['eye_clearance_m'] >= 1.9:
        raise RuntimeError('Fixed R33 basis did not reproduce the close-hut product defect')
    return pairs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--renderer', choices=['gl_compatibility', 'forward_plus'], required=True)
    parser.add_argument('--reference-from', type=Path, help='Supplemental identical saved campaign; does not replace failed ordinary title entry')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    baseline = out / 'baseline-checkout'
    checks = []
    report = {'passed': False, 'renderer': args.renderer, 'software_renderer': True,
              'basis': BASE, 'source_head': subprocess.check_output(['git','rev-parse','HEAD'],cwd=project,text=True).strip(),
              'source_tree': subprocess.check_output(['git','rev-parse','HEAD^{tree}'],cwd=project,text=True).strip(),
              'route': 'supplemental same reference slot' if args.reference_from else 'ordinary title/confirmation route',
              'checks': checks, 'limits': ['Mesa software / no target-PC or comfort acceptance',
              'Hut is production geometry placed on actual campaign height; no saved housing mutation',
              'Original nine views retained plus three hut views; no changed production budgets or original guards']}
    owners = []
    subprocess.run(['git','worktree','add','--detach',str(baseline),BASE],cwd=project,check=True)
    try:
        for name in HELPERS:
            shutil.copy2(project/'tools'/name,baseline/'tools'/name)
        for root, label in [(baseline,'baseline-source'),(project,'candidate-source')]:
            folder=out/label;folder.mkdir()
            source=SourceRun(root);source.begin_report(folder)
            if source.blocked: raise RuntimeError('Source inventory unavailable: '+label)
            owners.append((source,folder))
        with validation_editor(args.godot) as editor:
            before=out/'before';after=out/'after';before.mkdir();after.mkdir()
            base_user=out/'before-userdata';candidate_user=out/'after-userdata'
            if args.reference_from:
                shutil.copytree(args.reference_from/'before-userdata',base_user,dirs_exist_ok=True)
            base_env=isolated_env(base_user)
            for env in [base_env]:
                env['LIBGL_ALWAYS_SOFTWARE']='1';env['LP_NUM_THREADS']='2'
            checks.append(run([str(editor),'--headless','--path',str(baseline),'--import'],baseline,out/'baseline-import.log',base_env,180))
            owners[0][0].observe('import')
            if not checks[-1]['passed']: raise RuntimeError('Baseline import failed')
            if args.reference_from:
                slot=json.loads((args.reference_from/'before'/'reference.json').read_text())['slot']
                # Reference uses the before user's absolute path. Map only the
                # isolated prefix; preserve the exact slot and campaign bytes.
                old_prefix=str((args.reference_from/'before-userdata').resolve())
                slot=slot.replace(old_prefix,str(base_user.resolve()),1)
                route=['--reference-slot',slot]
            else: route=[]
            cmd=[str(editor),'--path',str(baseline),'--rendering-method',args.renderer,'--audio-driver','Dummy',
                 '--script','res://tools/review_r33_04_capture.gd','--','--capture',str(before),*route]
            checks.append(run(cmd,baseline,before/'render.log',base_env,240,'R32_04_CAMPAIGN_CAPTURE_PASSED'))
            owners[0][0].observe('before_finished')
            if not checks[-1]['passed']: raise RuntimeError('Baseline ordinary/native capture failed; retain original negative')
            ref=json.loads((before/'reference.json').read_text())
            report['reference']=ref
            shutil.copytree(base_user,candidate_user,dirs_exist_ok=True)
            slot=ref['slot'].replace(str(base_user.resolve()),str(candidate_user.resolve()),1)
            env=isolated_env(candidate_user);env['LIBGL_ALWAYS_SOFTWARE']='1';env['LP_NUM_THREADS']='2'
            checks.append(run([str(editor),'--headless','--path',str(project),'--import'],project,out/'candidate-import.log',env,180))
            owners[1][0].observe('import')
            if not checks[-1]['passed']: raise RuntimeError('Candidate import failed')
            cmd=[str(editor),'--path',str(project),'--rendering-method',args.renderer,'--audio-driver','Dummy',
                 '--script','res://tools/review_r33_04_capture.gd','--','--capture',str(after),'--reference-slot',slot]
            checks.append(run(cmd,project,after/'render.log',env,240,'R32_04_CAMPAIGN_CAPTURE_PASSED'))
            if not checks[-1]['passed']: raise RuntimeError('Candidate native capture failed')
            report['pairs']=comparison(before,after)
            report['passed']=all(row['passed'] for row in checks)
    except Exception as error:
        report['error']=str(error)
    finally:
        for source,folder in owners:
            source.observe('finished');provenance=source.write_report(folder)
            (folder/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
            if not provenance['reusable']: report['passed']=False;report.setdefault('provenance_errors',[]).append(folder.name)
        report['logs']=[{'path':str(p.relative_to(out)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in out.rglob('*.log') if 'baseline-checkout' not in p.parts]
        (out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({'passed':report['passed'],'error':report.get('error'),'output':str(out)}),flush=True)
        subprocess.run(['git','worktree','remove','--force',str(baseline)],cwd=project,check=True)
    return 0 if report['passed'] else 1


if __name__=='__main__':
    raise SystemExit(main())
