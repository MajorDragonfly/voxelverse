#!/usr/bin/env python3
"""Run INT30-15 real editor inputs, optional rendered capture and fresh-process reload.

Use an existing display (for example xvfb-run) for --capture. The headless path
still sends actual Godot GUI inputs but provides no visual acceptance.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
import subprocess
import tempfile

from check_validation_contracts import revision
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--capture', action='store_true')
    parser.add_argument('--authoring-profile', action='store_true',
                        help='Keep LocaleManager/DisplaySettings; omit unrelated campaign autoloads in a temporary project')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    paths = ['space/ships/shipyard.gd', 'space/ships/shipyard_presentation.gd',
             'tests/shipyard_presentation_test.gd', 'localization/catalog.json',
             'localization/de.po', 'localization/en.po', 'tools/validation/contracts.json']
    source = revision(project)
    source['files_sha256'] = {p: hashlib.sha256((project / p).read_bytes()).hexdigest() for p in paths}
    results = []
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='shipyard-presentation-') as temp:
        env = isolated_env(Path(temp))
        runtime_project = project
        if args.authoring_profile:
            runtime_project = Path(temp) / 'authoring'
            runtime_project.mkdir()
            for path in project.iterdir():
                if path.name not in {'.git', '.godot', 'project.godot'}:
                    (runtime_project / path.name).symlink_to(path, target_is_directory=path.is_dir())
            config = (project / 'project.godot').read_text()
            begin = config.index('[autoload]')
            end = config.index('\n[', begin + 1)
            section = '\n'.join(line for line in config[begin:end].splitlines()
                                if not re.match(r'\w+=', line) or line.startswith(('LocaleManager=', 'DisplaySettings=')))
            config = config[:begin] + section + '\n' + config[end:]
            (runtime_project / 'project.godot').write_text(config)
            cache = runtime_project / '.godot'
            cache.mkdir()
            for name in ['imported', 'uid_cache.bin', 'global_script_class_cache.cfg']:
                path = project / '.godot' / name
                if path.exists(): (cache / name).symlink_to(path, target_is_directory=path.is_dir())
            source['authoring_profile_sha256'] = hashlib.sha256(config.encode()).hexdigest()
        base = [str(editor), '--path', str(runtime_project), '--audio-driver', 'Dummy', '--verbose']
        base += ['--rendering-method', 'gl_compatibility'] if args.capture else ['--headless']
        cases = [('input-' + case, ['--case', case, '--capture', str(output)]) for case in ['expedition', 'lander', 'presentation', 'layout']] if args.capture else [('input', [])]
        cases.append(('restart', ['--restart']))
        for name, extra in cases:
            command = base + ['--script', 'res://tests/shipyard_presentation_test.gd', '--'] + extra
            timed_out = False
            with (output / (name + '.log')).open('w') as log:
                try:
                    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, env=env, timeout=240 if args.capture else 120)
                    exit_code = result.returncode
                except subprocess.TimeoutExpired:
                    timed_out = True
                    exit_code = 124
            log_text = (output / (name + '.log')).read_text()
            summaries = []
            for line in log_text.splitlines():
                try:
                    record = json.loads(line)
                    if record.get('test') == 'shipyard_presentation': summaries.append(record)
                except (ValueError, AttributeError):
                    pass
            passed = exit_code == 0 and not ERROR.search(log_text) and len(summaries) == 1 and summaries[0]['passed']
            results.append({'name': name, 'passed': passed, 'command': command, 'summary': summaries,
                            'exit_code': exit_code, 'timed_out': timed_out,
                            'log_sha256': hashlib.sha256(log_text.encode()).hexdigest()})
            if not passed:
                print(log_text[-15000:])
                break
    screenshots = sorted(p.name for p in output.glob('shipyard-*.png'))
    passed = len(results) == len(cases) and all(r['passed'] for r in results) and (not args.capture or len(screenshots) == 18)
    report = {'passed': passed, 'source': source, 'results': results, 'screenshots': screenshots,
              'engine': subprocess.check_output([args.godot, '--version'], text=True).strip(),
              'renderer': 'gl_compatibility' if args.capture else 'headless',
              'autoload_profile': 'LocaleManager/DisplaySettings only' if args.authoring_profile else 'original project',
              'software_rendering': env.get('LIBGL_ALWAYS_SOFTWARE'), 'llvmpipe_threads': env.get('LP_NUM_THREADS'),
              'scope': 'Standalone expedition and lander editing; real pointer/key input, DE/EN, copy protection, fresh process; no campaign or target-PC acceptance'}
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'passed': passed, 'screenshots': len(screenshots), 'results': [r['passed'] for r in results]}))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
