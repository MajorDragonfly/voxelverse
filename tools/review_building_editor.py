#!/usr/bin/env python3
"""Run the real building-editor input test and require seven native captures."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile

from validate_godot import ERROR
from validation_support import isolated_env, validation_editor


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--renderer', choices=['gl_compatibility', 'forward_plus'], default='gl_compatibility')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    project, output = args.project.resolve(), args.output.resolve()
    if output.is_relative_to(project):
        parser.error('Keep capture evidence outside the checked source tree')
    output.mkdir(parents=True, exist_ok=False)

    def git(*command):
        return subprocess.check_output(['git', *command], cwd=project, text=True).strip()

    def source():
        paths = [*git('ls-files').splitlines(), *git('ls-files', '--others', '--exclude-standard').splitlines()]
        hashes = {path: hashlib.sha256((project / path).read_bytes()).hexdigest()
                  for path in sorted(set(paths)) if (project / path).is_file()}
        return {'commit': git('rev-parse', 'HEAD'), 'tree': git('rev-parse', 'HEAD^{tree}'),
                'dirty': bool(git('status', '--porcelain')), 'file_hashes': hashes}

    before = source()
    with validation_editor(args.godot) as godot, tempfile.TemporaryDirectory(prefix='building-editor-review-') as userdata:
        command = [str(godot), '--path', str(project), '--rendering-method', args.renderer,
                   '--audio-driver', 'Dummy', '--script', 'res://tests/building_editor_input_test.gd',
                   '--', '--capture', str(output), '--external-restart']
        environment = isolated_env(Path(userdata))
        with (output / 'render.log').open('w') as log:
            result = subprocess.run(command, env=environment, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=180)
        # Forking from an active software GL renderer stalled in the local run.
        # Re-open exactly the saved design with the same isolated data after exit.
        native_log = (output / 'render.log').read_text()
        requests = [json.loads(line.removeprefix('BUILDING_EDITOR_RESTART_REQUEST '))
                    for line in native_log.splitlines() if line.startswith('BUILDING_EDITOR_RESTART_REQUEST ')]
        restart_code = -1
        if result.returncode == 0 and len(requests) == 1:
            restart_command = [str(godot), '--headless', '--path', str(project), '--script',
                               'res://tests/building_editor_input_test.gd', '--', '--building-restart', *requests[0]]
            with (output / 'restart.log').open('w') as log:
                restart = subprocess.run(restart_command, env=environment, stdout=log,
                                         stderr=subprocess.STDOUT, timeout=60)
            restart_code = restart.returncode
    after = source()
    log = (output / 'render.log').read_text() + ((output / 'restart.log').read_text() if (output / 'restart.log').exists() else '')
    records = [json.loads(line.removeprefix('BUILDING_EDITOR_INPUT_RESULT '))
               for line in log.splitlines() if line.startswith('BUILDING_EDITOR_INPUT_RESULT ')]
    images = {}
    expected = {f'building-{locale}-{width}x{height}.png': [width, height]
                for locale in ['de', 'en'] for width, height in [(800, 600), (1280, 720), (1920, 1080)]}
    expected['building-empty.png'] = [1920, 1080]
    for name, dimensions in expected.items():
        path = output / name
        data = path.read_bytes() if path.is_file() else b''
        valid = len(data) > 4096 and data[:8] == b'\x89PNG\r\n\x1a\n' and list(struct.unpack('>II', data[16:24])) == dimensions
        images[name] = {'passed': valid, 'dimensions': dimensions,
                        'sha256': hashlib.sha256(data).hexdigest() if data else None}
    passed = (result.returncode == 0 and not ERROR.search(log) and records
              and all(record['passed'] for record in records) and records[0]['display'] != 'headless'
              and restart_code == 0 and 'BUILDING_EDITOR_RESTART_OK' in log
              and before == after and all(image['passed'] for image in images.values()))
    report = {'passed': bool(passed), 'source': before, 'source_unchanged': before == after,
              'command': command, 'renderer': args.renderer, 'images': images, 'test_results': records,
              'scope': 'Real scene/GUI input, transforms/grid/history, DE/EN drafts/focus/scroll, IDs, save/load/fresh process, empty design, three native sizes.'}
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({key: value for key, value in report.items() if key != 'source'}, indent=2))
    if not passed:
        print(log[-10000:])
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
