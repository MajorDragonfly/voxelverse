#!/usr/bin/env python3
"""Capture the actual R33-06 input/work/save flow on an owner-connected clean tree."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun
from validate_godot import ERROR

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    parser.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    project=args.project.resolve()
    output=args.output.resolve()
    if output.exists(): raise SystemExit('Choose a new evidence directory')
    output.mkdir(parents=True)
    source=SourceRun(project)
    source.begin_report(output)
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='r33-06-native-') as temporary:
        command=[str(editor),'--path',str(project),'--rendering-method','gl_compatibility',
                 '--audio-driver','Dummy','--script','res://tests/r33_06_equipment_ui_test.gd',
                 '--','--capture',str(output)]
        with (output/'render.log').open('w') as log:
            try: code=subprocess.run(command,env=isolated_env(Path(temporary)),stdout=log,stderr=subprocess.STDOUT,timeout=240).returncode
            except subprocess.TimeoutExpired: code=124
    source.observe('native_equipment',force=True)
    provenance=source.write_report(output)
    logs=(output/'render.log').read_text()
    images=sorted(p.name for p in output.glob('equipment-*.png'))
    passed=code==0 and not ERROR.search(logs) and '"passed":true' in logs and len(images)==36 and provenance['reusable']
    (output/'results.json').write_text(json.dumps(dict(passed=passed,exit_code=code,images=images,command=command,
        source=provenance,renderer='gl_compatibility',target_pc_accepted=False,
        scope='actual flat fixture input, resource work, paid tool/fiberbed, equipment, write rollback, cold restart; 18 DE/EN/scale cases'),indent=2)+'\n')
    print(json.dumps(dict(passed=passed,exit_code=code,images=len(images))))
    return 0 if passed else 1
if __name__=='__main__': raise SystemExit(main())
