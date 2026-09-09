#!/usr/bin/env python3
"""D1 cold-restart gate: two real Godot processes, one isolated save directory."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--probe', choices=('d1', 'd11', 'd12'), default='d1')
args = parser.parse_args()
project = Path(__file__).resolve().parents[1]
args.output.mkdir(parents=True, exist_ok=True)
results = []
with tempfile.TemporaryDirectory(prefix='voxelverse-d1-restart-') as userdata:
    for mode in ('write', 'read'):
        env = dict(os.environ, XDG_DATA_HOME=userdata, D1_RESTART_MODE=mode)
        probe = ('res://tools/domestic_fauna_restart_probe.gd' if args.probe == 'd1'
                 else f'res://tools/domestic_fauna_{args.probe}_restart_probe.gd')
        process = subprocess.run([args.godot, '--headless', '--path', str(project), '--script',
                                  probe], env=env, text=True,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240 if args.probe == 'd12' else 120)
        (args.output / f'restart-{mode}.log').write_text(process.stdout)
        passed = process.returncode == 0 and not re.search(r'SCRIPT ERROR|(?:^|\n)ERROR:|ObjectDB instances leaked', process.stdout)
        result = {'process': mode, 'passed': passed, 'exit_code': process.returncode}
        results.append(result)
        print(json.dumps(result), flush=True)
        if not passed:
            print(process.stdout[-8000:])
            break
(args.output / 'restart-results.json').write_text(json.dumps(results, indent=2) + '\n')
raise SystemExit(0 if len(results) == 2 and all(r['passed'] for r in results) else 1)
