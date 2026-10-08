#!/usr/bin/env python3
"""Apply R33-06 owner connections only in an explicitly selected isolated QA tree.

R33-01 applies the same scoped changes serially with R33-05. This helper does not
modify its source checkout, central assignment data, or any remote branch.
"""
import argparse
import json
from pathlib import Path
import subprocess

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True, type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    source = Path(__file__).resolve().parents[1]
    if project == source:
        parser.error('Use a separate QA checkout; owner production files stay unchanged.')
    patches = source / 'docs/evidence/r33-06/patches'
    subprocess.run(['git','apply','--check',str(patches/'owners.patch')],cwd=project,check=True)
    subprocess.run(['git','apply',str(patches/'owners.patch')],cwd=project,check=True)
    path = project / 'localization/catalog.json'
    catalog = json.loads(path.read_text())
    appendix = json.loads((patches/'localization-append.json').read_text())
    known = {m['key'] for m in catalog['messages']}
    assert not known & {m['key'] for m in appendix['messages']}
    catalog['messages'].extend(appendix['messages'])
    path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
    subprocess.run(['python3','tools/localization/catalog.py'],cwd=project,check=True)
    path = project / 'tools/validation/contracts.json'
    registry = json.loads(path.read_text())
    appendix = json.loads((patches/'test-registry-append.json').read_text())
    known = {t for c in registry['contracts'] for t in c['tests']}
    assert not known & set(appendix['tests'])
    contract = next(c for c in registry['contracts'] if c['id'] == appendix['contract'])
    contract['tests'].extend(appendix['tests'])
    path.write_text(json.dumps(registry,ensure_ascii=False,indent=2)+'\n')
    print('R33_06_QA_OWNER_CONNECTIONS_APPLIED')

if __name__ == '__main__':
    main()
