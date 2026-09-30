#!/usr/bin/env python3
"""Replay real gallery inputs, with isolated data and optional native screenshots."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools'))
from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--render', action='store_true', help='Requires an actual X11/Wayland display')
parser.add_argument('--translation-appendix', action='store_true', help='Before central catalog integration only')
args = parser.parse_args()
args.output = args.output.resolve()
args.output.mkdir(parents=True, exist_ok=True)
if any(args.output.iterdir()):
    parser.error('Use a new output directory to preserve existing evidence')
source_run = SourceRun(ROOT)
source_run.begin_report(args.output)
paths = sorted([*ROOT.glob('ui/blueprints/community_gallery_*.gd'), *ROOT.glob('tests/int30_community_gallery*.gd'),
                ROOT / 'docs/evidence/int30-16-community-gallery/translations.json'])
source = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
with tempfile.TemporaryDirectory(prefix='int30-gallery-userdata-') as temporary, validation_editor(args.godot) as engine:
    env = isolated_env(Path(temporary))
    version = subprocess.check_output([str(engine), '--version'], text=True).strip()
    if not version.startswith('4.6.3.'):
        raise SystemExit('Expected Godot 4.6.3: ' + version)
    command = [str(engine), '--path', str(ROOT), '--audio-driver', 'Dummy']
    command += ['--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3'] if args.render else ['--headless']
    command += ['--script', 'res://tests/int30_community_gallery_test.gd', '--']
    if args.translation_appendix: command += ['--translation-appendix']
    if args.render: command += ['--capture-dir', str(args.output)]
    started = time.monotonic()
    with (args.output / 'gallery.log').open('w') as log:
        try:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = 124
    if code == 0:
        # Start a separate process after the first engine has fully closed,
        # reusing only the isolated data directory, with no live network nodes.
        cold_command = [str(engine), '--headless', '--audio-driver', 'Dummy', '--path', str(ROOT),
                        '--script', 'res://tests/int30_community_gallery_test.gd', '--', '--offline-reopen']
        with (args.output / 'offline-reopen.log').open('w') as cold_log:
            try:
                cold_result = subprocess.run(cold_command, env=env, stdout=cold_log, stderr=subprocess.STDOUT, timeout=30)
                cold_code = cold_result.returncode
            except subprocess.TimeoutExpired:
                cold_code = 124
        cold_text = (args.output / 'offline-reopen.log').read_text()
        if cold_code != 0 or 'INT30_COMMUNITY_GALLERY_OFFLINE_PASSED' not in cold_text or re.search(r'SCRIPT ERROR|(?:^|\n)ERROR:|ObjectDB instances leaked', cold_text):
            code = cold_code or 1
    log = (args.output / 'gallery.log').read_text()
    unchanged = source == {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    source_run.observe('gallery_complete', force=True)
    provenance = source_run.write_report(args.output)
    passed = code == 0 and unchanged and provenance['reusable'] and 'INT30_COMMUNITY_GALLERY_PASSED' in log and not re.search(r'SCRIPT ERROR|(?:^|\n)ERROR:|ObjectDB instances leaked', log)
    images = sorted(args.output.glob('*.png'))
    if args.render: passed = passed and len(images) == 45 and (args.output / 'capture-manifest.json').is_file()
    report = dict(passed=passed, exit_code=code, seconds=round(time.monotonic()-started, 3), engine=version,
                  command=command, source_sha256=source, source_unchanged=unchanged,
                  log_sha256=hashlib.sha256(log.encode()).hexdigest(),
                  images={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in images},
                  source_provenance=provenance, platform=sys.platform,
                  scope='INT30-16 focused checks; not full integration/export/target-PC acceptance')
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(log)
    raise SystemExit(0 if passed else 1)
