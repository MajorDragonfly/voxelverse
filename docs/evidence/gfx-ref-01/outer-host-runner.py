import fcntl
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT / 'voxelverse'
ENGINE = ROOT / 'toolchain/editor/Godot_v4.6.3-stable_linux.x86_64'
DISPLAY_ROOT = ROOT / 'toolchain/display'
locks = []
for name in ['/tmp/voxelverse-heavy.lock', '/tmp/voxelverse-r32-db514e109ac6-heavy.lock']:
    lock = open(name, 'a+')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    locks.append(lock)
env = os.environ.copy()
env.update(LD_LIBRARY_PATH=str(DISPLAY_ROOT / 'usr/lib/x86_64-linux-gnu'),
           LIBGL_ALWAYS_SOFTWARE='1', LP_NUM_THREADS='4',
           GODOT_SILENCE_ROOT_WARNING='1')
icd = list((DISPLAY_ROOT / 'usr/share/vulkan/icd.d').glob('*lvp*json'))[0]
driver = json.loads(icd.read_text())
driver['ICD']['library_path'] = str(DISPLAY_ROOT / 'usr/lib/x86_64-linux-gnu/libvulkan_lvp.so')
icd_path = ROOT / 'toolchain/lvp.json'
icd_path.write_text(json.dumps(driver))
env['VK_ICD_FILENAMES'] = str(icd_path)
display_number = 1234
env['DISPLAY'] = f'127.0.0.1:{display_number}'
with (ROOT / 'checks/display.log').open('w') as log:
    display = subprocess.Popen([str(DISPLAY_ROOT / 'usr/bin/Xvfb'), f':{display_number}',
        '-screen', '0', '1280x720x24', '-nolisten', 'unix', '-listen', 'tcp', '-ac',
        '-xkbdir', str(DISPLAY_ROOT / 'usr/share/X11/xkb')], env=env, stdout=log, stderr=log)
try:
    for i in range(50):
        if display.poll() is not None:
            raise RuntimeError((ROOT / 'checks/display.log').read_text())
        with socket.socket() as sock:
            if sock.connect_ex(('127.0.0.1', 6000 + display_number)) == 0:
                break
        time.sleep(.1)
    else:
        raise RuntimeError('X display unavailable')
    command = [arg.replace('{godot}', str(ENGINE)) for arg in sys.argv[1:]]
    print('GFX-REF-01 HOST START', socket.gethostname(), command, flush=True)
    result = subprocess.run(command, cwd=PROJECT, env=env)
    print('GFX-REF-01 HOST END', result.returncode, flush=True)
    sys.exit(result.returncode)
finally:
    display.terminate()
    display.wait(timeout=10)
