"""Exercise the proposed capture runner's real Git provenance checks.

The Godot process alone is stubbed; these are provenance unit cases, not renders.
"""
import hashlib
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--project', type=Path, required=True)
args = parser.parse_args()
sys.path.insert(0, str(args.project.resolve() / 'tools'))
spec = importlib.util.spec_from_file_location('proposal', Path(__file__).with_name('review_surface_transitions.proposed.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
real_run = subprocess.run

def git(path, *args):
    subprocess.check_output(['git', '-C', str(path), *args], stderr=subprocess.DEVNULL)

def case(name, injection=False, expected=True, wrong_hash=False, runtime_dirty=False, tamper=False, head_move=False, allow_injection=True):
    with tempfile.TemporaryDirectory(prefix='int30-provenance-') as folder:
        root = Path(folder)
        project = root / 'source'
        script = project / 'tools/capture_surface_transitions.gd'
        script.parent.mkdir(parents=True)
        runtime = project / 'runtime.gd'
        script.write_text('baseline measurement\n')
        runtime.write_text('unchanged runtime\n')
        git(project, 'init', '-q')
        git(project, 'config', 'user.name', 'INT30 provenance fixture')
        git(project, 'config', 'user.email', 'codex@openai.com')
        git(project, 'add', '.')
        git(project, 'commit', '-qm', 'fixed baseline')
        if injection:
            script.write_text('identical approved injected measurement\n')
        approved = hashlib.sha256(script.read_bytes()).hexdigest() if injection and allow_injection else None
        if wrong_hash:
            approved = '0' * 64
        if runtime_dirty:
            runtime.write_text('unexpected runtime mutation\n')
        output = root / 'capture'

        def render_stub(command, **kwargs):
            if command[0] != 'stub-godot':
                return real_run(command, **kwargs)
            if '--import' not in command:
                output.joinpath('capture.json').write_text(json.dumps({'passed': True}))
                for index in range(8):
                    output.joinpath(str(index) + '.png').write_bytes(b'provenance fixture only')
                if tamper:
                    script.write_text('changed during rendering\n')
                if head_move:
                    git(project, 'commit', '--allow-empty', '-qm', 'unexpected new head')
            return subprocess.CompletedProcess(command, 0)

        accepted = False
        with patch.object(module.subprocess, 'run', render_stub):
            try:
                result = module.capture(project, 'stub-godot', 'gl_compatibility', output, approved)
                accepted = result['source']['unchanged']
            except RuntimeError:
                pass
        assert accepted == expected, name
        return {'case': name, 'expected_acceptance': expected, 'accepted': accepted, 'passed': True}

results = [
    case('unchanged baseline'),
    case('explicit identical measurement injection', injection=True),
    case('implicit measurement injection rejected', injection=True, allow_injection=False, expected=False),
    case('wrong measurement digest rejected', injection=True, wrong_hash=True, expected=False),
    case('runtime mutation rejected', injection=True, runtime_dirty=True, expected=False),
    case('measurement changed during render rejected', injection=True, tamper=True, expected=False),
    case('unmodified-head guard remains strict', head_move=True, expected=False),
]
print(json.dumps({'passed': True, 'scope': 'Git/source provenance only; no graphical acceptance', 'cases': results}, indent=2))
