#!/usr/bin/env python3
"""Serialize R33-05 engine runs on the shared host and record exact source."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import time

LOCKS = ['/tmp/voxelverse-heavy.lock', '/tmp/voxelverse-r32-db514e109ac6-heavy.lock']


def acquire(seconds):
    deadline = time.monotonic() + seconds
    while True:
        held = []
        try:
            for name in LOCKS:
                handle = open(name, 'a+')
                held.append(handle)
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return held
        except BlockingIOError:
            for handle in held:
                handle.close()
            if time.monotonic() >= deadline:
                return []
            time.sleep(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--wait-slot', type=int, default=0, choices=range(46), metavar='0..45')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('engine command is required')
    locks = acquire(args.wait_slot)
    if not locks:
        print('HOST_BUSY: no engine started; no test result')
        return 75
    try:
        for entry in Path('/proc').iterdir():
            if not entry.name.isdigit():
                continue
            try:
                if (entry / 'comm').read_text().lower().startswith('godot'):
                    print('HOST_BUSY: another Godot process; no engine started')
                    return 75
            except OSError:
                pass
        output = args.output.resolve()
        output.mkdir(parents=True, exist_ok=False)
        report = {'host': os.uname().nodename, 'start': time.time(), 'command': command,
                  'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                  'tree': subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], text=True).strip(),
                  'status': subprocess.check_output(['git', 'status', '--porcelain'], text=True)}
        for handle in locks:
            handle.seek(0)
            handle.truncate()
            handle.write(json.dumps({'owner': 'R33-05', 'project': os.getcwd(), 'pid': os.getpid()}))
            handle.flush()
        print('HOST_LOCK_ACQUIRED: R33-05', flush=True)
        try:
            with (output / 'run.log').open('w') as log:
                run = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=650)
            report['exit_code'] = run.returncode
        finally:
            report['end'] = time.time()
            (output / 'host.json').write_text(json.dumps(report, indent=2) + '\n')
        print((output / 'run.log').read_text()[-12000:])
        return run.returncode
    finally:
        for handle in locks:
            handle.seek(0)
            handle.truncate()
            handle.flush()
            fcntl.flock(handle, fcntl.LOCK_UN)
            handle.close()
        print('HOST_LOCK_RELEASED: R33-05', flush=True)


if __name__ == '__main__':
    raise SystemExit(main())
