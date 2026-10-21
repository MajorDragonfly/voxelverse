#!/usr/bin/env python3
"""Capture the real D2 taming/map/follow/cold-restart route in DE and EN.

Needs a native display (xvfb-run in Linux CI). This bounded planar fixture
checks the production UI and D2 lifecycle; it is not a target-PC benchmark.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

from validate_godot import ERROR
from validation_provenance import SourceRun
from validation_support import isolated_env, validation_editor


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source_dir = output / 'source'
    source_dir.mkdir()
    source = SourceRun(project)
    source.begin_report(source_dir)
    log_path = output / 'domestication_campaign_test.log'
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix='animal-navigation-') as temporary:
        engine = subprocess.check_output([str(editor), '--version'], text=True).strip()
        command = [str(editor), '--path', str(project), '--rendering-method',
                   'gl_compatibility', '--audio-driver', 'Dummy', '--script',
                   'res://tests/domestication_campaign_test.gd', '--', '--capture', str(output)]
        with log_path.open('w') as log:
            try:
                code = subprocess.run(command, env=isolated_env(Path(temporary)),
                                      stdout=log, stderr=subprocess.STDOUT, timeout=240).returncode
            except subprocess.TimeoutExpired:
                code = 124
    content = log_path.read_text()
    expected = {f'animal-navigation-{locale}-{width}x{height}-{scale}.png'
                for locale in ('de', 'en') for width, height in ((800, 600), (1280, 720), (1920, 1080))
                for scale in (100, 125, 150)}
    images = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
              for p in output.glob('animal-navigation-*.png')}
    invalid_images = [name for name in images if not (output / name).read_bytes().startswith(b'\x89PNG\r\n\x1a\n')]
    source.observe('native_animal_navigation', force=True)
    provenance = source.write_report(source_dir)
    passed = (code == 0 and 'ANIMAL_NAVIGATION_UI_PASSED' in content
              and 'D2_CAMPAIGN_PASS' in content and not ERROR.search(content)
              and set(images) == expected and not invalid_images and provenance['reusable'])
    result = {'passed': passed, 'exit_code': code, 'command': command, 'engine': engine,
              'renderer': 'gl_compatibility', 'screenshots': images,
              'missing': sorted(expected - images.keys()), 'invalid_images': invalid_images,
              'log_sha256': hashlib.sha256(log_path.read_bytes()).hexdigest(),
              'source': provenance, 'scope': 'Real D1 taming, animal navigation UI, follow/home, copy, cold restart and persisted death in a bounded planar campaign fixture; no hardware/FPS acceptance.'}
    (output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'source'}), flush=True)
    if not passed:
        print(content[-8000:], flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
