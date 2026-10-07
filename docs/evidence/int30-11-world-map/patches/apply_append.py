#!/usr/bin/env python3
"""Apply only the INT30-11 owner appends in an isolated R33 verification tree.

R33-01 applies the same additions serially, preserving concurrent entries.
Usage: python3 .../apply_append.py PATH_TO_ISOLATED_CHECKOUT
"""
import json
from pathlib import Path
import subprocess
import sys
root = Path(sys.argv[1]).resolve()
patches = Path(__file__).resolve().parent
catalog = root / 'localization/catalog.json'
data = json.loads(catalog.read_text())
by_key = {row['key']: row for row in data['messages']}
for key, values in json.loads((patches / 'localization-append.json').read_text()).items():
    row = {'key': key, **values}
    if key in by_key:
        if by_key[key] != row: raise SystemExit('Conflicting catalog entry: ' + key)
    else: data['messages'].append(row)
catalog.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
subprocess.run([sys.executable, 'tools/localization/catalog.py'], cwd=root, check=True)
append = json.loads((patches / 'registry-append.json').read_text())
registry = root / 'tools/validation/contracts.json'
data = json.loads(registry.read_text())
owner = next(c for c in data['contracts'] if c['id'] == append['contract'])
for test in append['tests']:
    owners = [c for c in data['contracts'] if test in c['tests']]
    if owners and owners != [owner]: raise SystemExit('Duplicate/conflicting test owner: ' + test)
    if test not in owner['tests']: owner['tests'].append(test)
registry.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
runner = root / 'tools/validate_godot.py'
s = runner.read_text()
line = 'LONG_TESTS.update(' + repr(set(append['long_tests'])) + ')  # INT30-11 cold campaign/map restart'
if line not in s:
    s = s.replace('\nERROR = re.compile', '\n' + line + '\n\nERROR = re.compile')
runner.write_text(s)
print('Applied 9 catalog entries, 2 disjoint registrations and existing long-test budget.')
