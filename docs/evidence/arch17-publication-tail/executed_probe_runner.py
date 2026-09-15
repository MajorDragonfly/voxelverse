import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

project = Path(__file__).parent / 'voxelverse'
sys.path.insert(0, str(project / 'tools'))
from validation_support import isolated_env, validation_editor
from check_validation_contracts import revision

output = Path(__file__).parent / 'evidence' / sys.argv[1]
output.mkdir(parents=True, exist_ok=False)
source = revision(project)
source['files'] = {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in [project / 'tools/benchmark_terrain_publication.gd',
                             project / 'world/planet_lab/adaptive_sphere_tiles.gd']}
editor_path = '/workspace/scratch/d2f8e8a15ebb/godot-toolchain/editor/Godot_v4.6.3-stable_linux.x86_64'
with validation_editor(editor_path) as editor, tempfile.TemporaryDirectory(prefix='terrain-tail-') as userdata:
    argv = [str(editor), '--headless', '--path', str(project), '--script',
            'res://tools/benchmark_surface_publication.gd', '--', '--terrain']
    start = time.monotonic()
    with (output / 'probe.log').open('w') as stream:
        run = subprocess.run(argv, env=isolated_env(Path(userdata)), stdout=stream,
                             stderr=subprocess.STDOUT, timeout=180)
    log = (output / 'probe.log').read_text()
    metrics = next((json.loads(line.split(' ', 1)[1]) for line in log.splitlines()
                    if line.startswith('TERRAIN_PUBLICATION_METRICS ')), None)
    result = {'source': source, 'command': argv, 'exit_code': run.returncode,
              'seconds': time.monotonic() - start, 'metrics': metrics,
              'passed': run.returncode == 0 and metrics is not None and metrics['passed']
              and not any(error in log for error in ['SCRIPT ERROR', 'ERROR:', 'ObjectDB instances leaked'])}
    (output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    if not result['passed']:
        print(log[-10000:])
        sys.exit(1)
