#!/usr/bin/env python3
"""Run a confirmed R33 host section under nonblocking shared heavy locks.

The comment URL records the independently confirmed slot; acquiring a local
lock does not grant a slot. No full process command lines are logged.
"""
import argparse
import contextlib
import fcntl
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import time

SHARED_LOCK = Path('/tmp/voxelverse-heavy.lock')
LEGACY_LOCK = Path('/tmp/voxelverse-r32-db514e109ac6-heavy.lock')


def processes():
    result = []
    for entry in Path('/proc').iterdir():
        if not entry.name.isdigit():
            continue
        try:
            name = (entry / 'comm').read_text().strip()
            fields = (entry / 'stat').read_text().rsplit(')', 1)[1].split()
            value = {'pid': int(entry.name), 'name': name,
                     'ppid': int(fields[1]), 'cpu_ticks': int(fields[11]) + int(fields[12]),
                     'rss_bytes': int(fields[21]) * os.sysconf('SC_PAGE_SIZE')}
            if name.lower().startswith('godot'):
                args = (entry / 'cmdline').read_bytes().decode(errors='replace').split('\0')
                value['project'] = args[args.index('--path') + 1] if '--path' in args else None
            result.append(value)
        except (OSError, ValueError, IndexError):
            continue
    return result


def descendants(values, parent):
    owned = {parent}
    while True:
        extra = {item['pid'] for item in values if item['ppid'] in owned}
        if extra <= owned:
            return owned
        owned |= extra


def snapshot(parent=None):
    values = processes()
    owned = descendants(values, parent) if parent is not None else set()
    result = {'time_unix': time.time(), 'loadavg': os.getloadavg(), 'processes': values,
              'foreign_godot': [item for item in values
                                if item['name'].lower().startswith('godot') and item['pid'] not in owned]}
    for name in ('cpu.stat', 'cpu.pressure', 'memory.current', 'memory.peak', 'memory.events', 'memory.pressure'):
        try:
            result[name] = (Path('/sys/fs/cgroup') / name).read_text().strip()
        except OSError:
            result[name] = None
    return result


def source_stamp(project):
    try:
        return {'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, stderr=subprocess.DEVNULL, text=True).strip(),
                'tree': subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], cwd=project, stderr=subprocess.DEVNULL, text=True).strip(),
                'status': subprocess.check_output(['git', 'status', '--porcelain'], cwd=project, stderr=subprocess.DEVNULL, text=True).strip()}
    except subprocess.CalledProcessError:
        return None


@contextlib.contextmanager
def exclusive_locks(paths, metadata):
    with contextlib.ExitStack() as stack:
        locks = []
        for path in paths:
            lock = stack.enter_context(path.open('a+'))
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise RuntimeError(f'Host slot busy at {path}; no child started') from None
            locks.append(lock)
        # Do not truncate another owner's metadata before owning every lock.
        for lock in locks:
            lock.seek(0)
            lock.truncate()
            lock.write(json.dumps(metadata) + '\n')
            lock.flush()
        yield


def stop_group(process):
    # This session belongs to this wrapper. Never terminate foreign Godot jobs.
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            break
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            pass
    process.wait()


def run_section(command, project, output, label, slot_url, lock_paths=None):
    metadata = {'host': socket.gethostname(), 'label': label, 'project': str(project),
                'pid': os.getpid(), 'slot_comment_url': slot_url, 'source': source_stamp(project)}
    paths = lock_paths if lock_paths is not None else [SHARED_LOCK, LEGACY_LOCK]
    with exclusive_locks(paths, metadata):
        first = snapshot()
        if first['foreign_godot']:
            raise RuntimeError('An existing Godot process is active; no child started')
        with output.open('x', encoding='utf-8') as report:
            def emit(value):
                report.write(json.dumps(value) + '\n')
                report.flush()
            emit({'event': 'start', **metadata, 'command': command, 'locks': list(map(str, paths)), **first})
            process = None
            contaminated = False
            error = None
            try:
                process = subprocess.Popen(command, cwd=project, start_new_session=True)
                while process.poll() is None:
                    value = snapshot(process.pid)
                    emit(value)
                    if value['foreign_godot']:
                        contaminated = True
                        error = 'Foreign Godot process entered confirmed slot; run stopped'
                        stop_group(process)
                        break
                    try:
                        process.wait(timeout=0.25)
                    except subprocess.TimeoutExpired:
                        pass
            except BaseException as failure:
                error = f'{type(failure).__name__}: {failure}'
                if process is not None:
                    stop_group(process)
                raise
            finally:
                if process is not None:
                    # Also terminate leaked children after an early wrapper exit.
                    stop_group(process)
                foreign_seen = contaminated
                final_source = source_stamp(project)
                if final_source != metadata['source']:
                    contaminated = True
                    error = (error + '; ' if error else '') + 'Measured source changed during the section'
                emit({'event': 'end', 'exit_code': process.returncode if process else None,
                      'foreign_godot_observed': foreign_seen,
                      'source_unchanged': final_source == metadata['source'], 'source': final_source,
                      'error': error, **snapshot()})
            return 2 if contaminated else process.returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--slot-comment-url', required=True,
                        help='Existing R33-01 confirmation in #137; do not supply a request URL')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('Expected command after --')
    if not args.slot_comment_url.startswith('https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-'):
        parser.error('The confirmed slot must be recorded in #137')
    project = args.project.resolve()
    if subprocess.check_output(['git', 'status', '--porcelain'], cwd=project).strip():
        parser.error('Commit the measured source first; expected a clean checkout')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    return run_section(command, project, args.output, args.label, args.slot_comment_url)


if __name__ == '__main__':
    raise SystemExit(main())
