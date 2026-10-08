#!/usr/bin/env python3
"""Apply narrow R33-05 owner attachments to an explicitly isolated checkout."""
import argparse
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    args = parser.parse_args()
    root = args.project.resolve()
    ports = Path(__file__).resolve().parents[1] / 'docs/evidence/r33-05/ports'
    for name in ['domain-owner.patch', 'runner-owner.patch']:
        subprocess.run(['git', 'apply', '--check', str(ports / name)], cwd=root, check=True)
        subprocess.run(['git', 'apply', str(ports / name)], cwd=root, check=True)
    path = root / 'localization/catalog.json'
    catalog = json.loads(path.read_text())
    additions = json.loads((ports / 'localization-append.json').read_text())
    existing = {row['key'] for row in catalog['messages']}
    if any(row['key'] in existing for row in additions):
        raise ValueError('Localization append already present')
    catalog['messages'].extend(additions)
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
    subprocess.run(['python3', 'tools/localization/catalog.py'], cwd=root, check=True)
    path = root / 'tools/validation/contracts.json'
    registry = json.loads(path.read_text())
    append = json.loads((ports / 'registry-append.json').read_text())
    contract = next(row for row in registry['contracts'] if row['id'] == append['contract'])
    for test in append['tests']:
        if any(test in row['tests'] for row in registry['contracts']):
            raise ValueError('Duplicate registration: ' + test)
        contract['tests'].append(test)
    path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + '\n')
    subprocess.run(['python3', 'tools/check_validation_contracts.py'], cwd=root, check=True)


if __name__ == '__main__':
    main()
