#!/usr/bin/env python3
"""Fail closed on host contention; hold both R33/R32 locks for the entire command."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import socket
import subprocess
import time
from contextlib import ExitStack

LOCKS = ['/tmp/voxelverse-heavy.lock', '/tmp/voxelverse-r32-db514e109ac6-heavy.lock']

def snapshot():
    godot = []
    for entry in Path('/proc').iterdir():
        if not entry.name.isdigit(): continue
        try:
            name = (entry / 'comm').read_text().strip()
            status = (entry/'stat').read_text().rsplit(')',1)[1].split()
            if status[0] == 'Z': continue
            if name.lower().startswith('godot'):
                godot.append({'pid': int(entry.name), 'ppid': int(status[1]), 'args': (entry/'cmdline').read_bytes().decode(errors='replace').split('\0')})
        except OSError: pass
    record = {'unix_time': time.time(), 'loadavg': os.getloadavg(), 'godot': godot}
    for name in ('cpu.stat','cpu.max','cpu.pressure','memory.current','memory.peak','memory.max','memory.events'):
        try: record[name] = (Path('/sys/fs/cgroup')/name).read_text().strip()
        except OSError: record[name] = None
    return record

def owned_descendant(pid, parent):
    seen=set()
    while pid not in seen and pid > 1:
        if pid == parent: return True
        seen.add(pid)
        try: pid=int((Path('/proc')/str(pid)/'stat').read_text().rsplit(')',1)[1].split()[1])
        except (OSError,ValueError,IndexError): return False
    return False

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--project',type=Path,required=True)
    p.add_argument('command',nargs=argparse.REMAINDER)
    a=p.parse_args()
    command=a.command[1:] if a.command[:1]==['--'] else a.command
    a.output.parent.mkdir(parents=True,exist_ok=True)
    with a.output.open('x') as log, ExitStack() as stack:
        def record(value): log.write(json.dumps(value)+'\n'); log.flush()
        first=snapshot()
        record({'event':'request','host':socket.gethostname(),'command':command,'project':str(a.project.resolve()),**first})
        for path in LOCKS:
            lock=stack.enter_context(open(path,'a+'))
            try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError:
                record({'event':'rejected_lock_busy','lock':path}); return 75
        if first['godot']:
            record({'event':'rejected_godot_active'}); return 75
        record({'event':'start',**snapshot()})
        run=subprocess.Popen(command,cwd=a.project)
        foreign=False
        while run.poll() is None:
            current=snapshot()
            foreign |= any(not owned_descendant(x['pid'],run.pid) for x in current['godot'])
            record(current)
            try: run.wait(timeout=1)
            except subprocess.TimeoutExpired: pass
        last=snapshot()
        record({'event':'end','exit_code':run.returncode,'foreign_godot_observed':foreign,**last})
        if last['godot']: return 76
        return 76 if foreign else run.returncode

if __name__=='__main__': raise SystemExit(main())
