import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time

root = Path(__file__).resolve().parent
lock = open('/tmp/voxelverse-r32-db514e109ac6-heavy.lock', 'a')
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
env = os.environ.copy()
env.update(DISPLAY='127.0.0.1:105', LP_NUM_THREADS='2', LIBGL_ALWAYS_SOFTWARE='1',
           LD_LIBRARY_PATH=str(root / 'runtime/xvfb/usr/lib/x86_64-linux-gnu') + ':' + str(root / 'runtime/vulkan/usr/lib/x86_64-linux-gnu'),
           VK_ICD_FILENAMES=str(root / 'runtime/vulkan/usr/share/vulkan/icd.d/lvp_icd.json'))
os.sched_setaffinity(0, {0, 1, 2, 3})
xlog = open(root / ('measurements/xvfb-' + sys.argv[1] + '.log'), 'wb')
xvfb = subprocess.Popen([str(root / 'runtime/xvfb/usr/bin/Xvfb-r32'), ':105', '-screen', '0', '1920x1080x24', '-nolisten', 'unix', '-listen', 'tcp', '-ac'], env=env, stdout=xlog, stderr=subprocess.STDOUT)
time.sleep(1)
godot = str(root / 'runtime/godot')
def run(argv, output=None, timeout=1000):
    print('RUN', ' '.join(map(str, argv)), flush=True)
    if output:
        with open(output, 'wb') as log:
            result = subprocess.run(list(map(str, argv)), env=env, cwd=root, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
    else:
        result = subprocess.run(list(map(str, argv)), env=env, cwd=root, timeout=timeout)
    print('DONE', result.returncode, flush=True)
    if result.returncode:
        raise RuntimeError('Check failed: ' + str(argv))
try:
    if sys.argv[1] == 'focused':
        run([godot, '--headless', '--path', root / 'voxelverse', '--editor', '--import'], root / 'measurements/import-lifecycle.log', 180)
        run([sys.executable, root / 'voxelverse/tools/validate_godot.py', '--godot', godot, '--project', root / 'voxelverse', '--tests', 'scan_circle_test', 'creature_scan_test', 'nest_discovery_test', 'wildlife_colony_test', '--skip-main', '--skip-import', '--output', root / 'measurements/focused-final-head'])
    elif sys.argv[1] == 'smoke':
        run([sys.executable, root / 'voxelverse/tools/review_r32_05_query.py', '--godot', godot, '--project', root / 'r32-05-base', '--output', root / 'measurements/count-smoke', '--save', root / 'measurements/query-reference.json', '--renderer', 'gl_compatibility', '--count', '1'])
    elif sys.argv[1] == 'compare':
        for source in ['r32-05-base', 'r32-05-previous']:
            run([godot, '--headless', '--path', root / source, '--editor', '--import'], root / ('measurements/import-' + source + '.log'), 180)
        for renderer in ['gl_compatibility', 'forward_plus']:
            for source in ['r32-05-base', 'r32-05-previous', 'voxelverse']:
                for count in [1, 12]:
                    run([sys.executable, root / 'voxelverse/tools/review_r32_05_query.py', '--godot', godot, '--project', root / source, '--output', root / ('measurements/triple-' + source + '-' + renderer + '-' + str(count)), '--save', root / 'measurements/query-reference.json', '--renderer', renderer, '--count', str(count)], timeout=260)
    elif sys.argv[1] in ['native', 'native-current']:
        for renderer in ['gl_compatibility', 'forward_plus']:
            for source in (['voxelverse'] if sys.argv[1] == 'native-current' else ['r32-05-base', 'r32-05-previous', 'voxelverse']):
                argv = [sys.executable, root / 'voxelverse/tools/review_r32_05_capture.py', '--godot', godot, '--project', root / source, '--output', root / ('measurements/final-occlusion-' + source + '-' + renderer), '--renderer', renderer, '--case', 'occlusion']
                if source == 'r32-05-base': argv.append('--expect-negative')
                run(argv)
            for case in ['motion', 'nests', 'world']:
                for language in ['de', 'en']:
                    if case == 'world' and language == 'en': continue
                    run([sys.executable, root / 'voxelverse/tools/review_r32_05_capture.py', '--godot', godot, '--project', root / 'voxelverse', '--output', root / ('measurements/final-' + case + '-' + language + '-' + renderer), '--renderer', renderer, '--case', case, '--language', language])
finally:
    xvfb.terminate()
    xvfb.wait(timeout=10)
    xlog.close()
    fcntl.flock(lock, fcntl.LOCK_UN)
