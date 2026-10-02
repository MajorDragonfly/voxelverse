#!/usr/bin/env python3
"""Run one heavy host measurement under the shared R32 lock; record foreign load."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import socket
import subprocess
import time


def godot_processes():
    result = []
    for entry in Path('/proc').iterdir():
        if not entry.name.isdigit():
            continue
        try:
            name = (entry / 'comm').read_text().strip()
            if not name.lower().startswith('godot'):
                continue
            args = (entry / 'cmdline').read_bytes().decode(errors='replace').split('\0')
            project = args[args.index('--path') + 1] if '--path' in args else None
            result.append({'pid': int(entry.name), 'name': name, 'project': project})
        except (OSError, ValueError, IndexError):
            pass
    return result


def snapshot(project):
    result = {'time_unix': time.time(), 'loadavg': os.getloadavg(), 'godot': godot_processes()}
    result['foreign_godot'] = [p for p in result['godot'] if p['project'] != str(project)]
    for name in ('cpu.stat', 'cpu.pressure', 'memory.current', 'memory.peak', 'memory.events', 'memory.pressure'):
        try:
            result[name] = (Path('/sys/fs/cgroup') / name).read_text().strip()
        except OSError:
            result[name] = None
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('Expected command after --')
    host = socket.gethostname()
    lock_path = Path('/tmp') / f'voxelverse-r32-{host}-heavy.lock'
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open('a+') as lock:
        deadline = time.monotonic() + 60
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise RuntimeError('Host slot busy; no measurement started')
                time.sleep(0.25)
        project = args.project.resolve()
        first = snapshot(project)
        while first['godot']:
            if time.monotonic() >= deadline:
                raise RuntimeError('Another Godot process is active; no heavy measurement started')
            time.sleep(0.25)
            first = snapshot(project)
        lock.seek(0)
        lock.truncate()
        lock.write(json.dumps({'host': host, 'label': args.label, 'project': str(project), 'pid': os.getpid()}))
        lock.flush()
        contaminated = False
        with args.output.open('x', encoding='utf-8') as report:
            report.write(json.dumps({'host': host, 'label': args.label, 'event': 'start', **first}) + '\n')
            report.flush()
            process = subprocess.Popen(command, cwd=project)
            while process.poll() is None:
                value = snapshot(project)
                contaminated |= bool(value['foreign_godot'])
                report.write(json.dumps(value) + '\n')
                report.flush()
                try:
                    process.wait(timeout=0.25)
                except subprocess.TimeoutExpired:
                    pass
            report.write(json.dumps({'event': 'end', 'exit_code': process.returncode,
                                     'foreign_godot_observed': contaminated, **snapshot(project)}) + '\n')
        return process.returncode


if __name__ == '__main__':
    raise SystemExit(main())
