#!/usr/bin/env python3
"""Prepare an isolated R32-11 QA tree with explicit central-owner attachments.

Never edits source owner files. Focused tests use the existing strict runner;
native captures are separate and require the confirmed shared-host heavy slot.
"""
import argparse
import json
from pathlib import Path
import subprocess

EVIDENCE = Path('docs/evidence/r32-11')
TESTS = ['r32_11_friendship_test', 'creature_behavior_gameplay_test',
         'wildlife_social_play_test', 'creature_expression_test',
         'encounter_archive_test', 'behavior_progression_test']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--checkout', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    source, checkout, output = args.project.resolve(), args.checkout.resolve(), args.output.resolve()
    if subprocess.check_output(['git', '-C', str(source), 'status', '--porcelain'], text=True).strip():
        parser.error('Commit the exact source before preparing the QA tree')
    output.mkdir(parents=True, exist_ok=False)
    subprocess.run(['git', 'clone', '--shared', str(source), str(checkout)], check=True)
    subprocess.run(['git', '-C', str(checkout), 'apply', str(checkout / EVIDENCE / 'gameplay-test-owner.patch')], check=True)
    registry = checkout / 'tools/validation/contracts.json'
    data = json.loads(registry.read_text())
    append = json.loads((checkout / EVIDENCE / 'registry.append.json').read_text())
    contract = next(item for item in data['contracts'] if item['id'] == append['contract'])
    for test in append['tests']:
        if any(test in item['tests'] for item in data['contracts']):
            parser.error('Test already registered: ' + test)
        contract['tests'].append(test)
    registry.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    subprocess.run(['git', '-C', str(checkout), 'add', '-A'], check=True)
    subprocess.run(['git', '-C', str(checkout), 'commit', '-m', 'QA only: apply R32-11 central test attachments'], check=True)
    source_sha = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    qa_sha = subprocess.check_output(['git', '-C', str(checkout), 'rev-parse', 'HEAD'], text=True).strip()
    qa_tree = subprocess.check_output(['git', '-C', str(checkout), 'rev-parse', 'HEAD^{tree}'], text=True).strip()
    # Same validated resource files; import is owned by this runner once.
    command = ['python3', str(checkout / 'tools/validate_godot.py'), '--project', str(checkout),
               '--godot', args.godot, '--tests', *TESTS, '--skip-main', '--output', str(output / 'validation')]
    result = subprocess.run(command)
    report = {'feature_commit': source_sha, 'qa_commit': qa_sha, 'qa_tree': qa_tree,
              'attachments': ['gameplay-test-owner.patch', 'registry.append.json'],
              'tests': TESTS, 'exit_code': result.returncode, 'command': command,
              'scope': 'Focused source/consumer tests with central-owner test attachments; no full integration or target-PC acceptance'}
    (output / 'execution.json').write_text(json.dumps(report, indent=2) + '\n')
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
