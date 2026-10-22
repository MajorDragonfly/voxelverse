from pathlib import Path
import subprocess
import sys
import tempfile
sys.path.insert(0, str(Path(__file__).resolve().parent / 'voxelverse/tools'))
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR

root = Path(__file__).resolve().parent
engine, renderer = sys.argv[1:]
folder = root / 'checks' / ('wind-' + renderer)
folder.mkdir(exist_ok=False)
with validation_editor(engine) as editor, tempfile.TemporaryDirectory(prefix='gfx-wind-') as user:
    command = [str(editor), '--path', str(root / 'voxelverse'), '--audio-driver', 'Dummy',
               '--rendering-method', renderer, '--resolution', '960x540', '--script',
               'res://tools/review_r32_09_wind.gd', '--', str(folder), str(root / 'checks/wind-control')]
    result = subprocess.run(command, env=isolated_env(Path(user)), capture_output=True, text=True, timeout=90)
log = result.stdout + result.stderr
(folder / 'run.log').write_text(log)
if result.returncode or ERROR.search(log):
    print(log[-5000:])
    raise SystemExit(1)
print(log[-1800:])
