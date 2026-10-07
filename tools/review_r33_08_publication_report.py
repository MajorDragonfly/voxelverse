#!/usr/bin/env python3
"""Report retained publication spans, exact quantiles and incomplete routes honestly."""
import argparse
from collections import defaultdict
import gzip
import hashlib
import json
import math
from pathlib import Path

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def distribution(values):
    if not values: return None
    data=sorted(values)
    def q(p):
        position=(len(data)-1)*p
        lo=math.floor(position); hi=math.ceil(position)
        return data[lo]+(data[hi]-data[lo])*(position-lo)
    return {'count':len(data),'sum_ms':sum(data),'p50_ms':q(.50),'p95_ms':q(.95),
            'p99_ms':q(.99),'max_ms':data[-1],
            **{f'over_{n}_ms':sum(x>n for x in data) for n in (33,50,100)}}

def read_run(folder):
    result=json.loads((folder/'results.json').read_text())
    log=(folder/'run.log').read_text(errors='replace')
    if result['log_sha256']!=digest(folder/'run.log'):
        raise ValueError(f'{folder}: wrapper/log digest mismatch')
    world=None
    for name in ('int30-collision-world.json','int30-collision-progress.json'):
        if (folder/name).is_file():
            world=json.loads((folder/name).read_text()); break
    actual=world.get('renderer') if world else None
    requested=result['renderer']
    backend_ok=actual==requested and (requested!='forward_plus' or ('Vulkan' in log and 'Forward+' in log))
    passed=(result['passed'] is True and result['exit_code']==0 and backend_ok
            and bool(world) and world.get('complete') is True and world.get('passed') is True
            and world.get('failures')==[])
    spans=defaultdict(list)
    for line in log.splitlines():
        if line.startswith('INT30_FLORA_TRACE '):
            row=json.loads(line[len('INT30_FLORA_TRACE '):])
            if row.get('edge')=='end' and 'duration_ms' in row:
                spans[row['phase']+'|'+row['operation']].append(row['duration_ms'])
    raw=folder/'int30-collision-spans.json'
    extras=json.loads(raw.read_text()) if raw.is_file() else None
    if extras:
        for key,values in extras['samples'].items(): spans[key]=values
    captures=world.get('capture_frames',[]) if world else []
    for key in ('physics_wait_ms','process_wait_ms','force_draw_ms','readback_ms','png_ms'):
        for frame in captures: spans['explicit-capture|'+key].append(frame[key])
    host=folder.parent/(folder.name+'-host.jsonl')
    load=[json.loads(x) for x in host.read_text().splitlines()] if host.is_file() else []
    end=load[-1] if load else {}
    slot=folder/'int30-collision-source-slot.json'
    source=result.get('provenance',{})
    return {'folder':str(folder),'reported_passed':result['passed'],'strict_complete_passed':passed,
        'exit_code':result['exit_code'],'status':result.get('status'),'actual_renderer':actual,
        'backend_verified':backend_ok,'adapter':world.get('adapter') if world else None,
        'engine':world.get('engine') if world else None,'cpu':world.get('cpu') if world else None,
        'source':result.get('source'),'source_stable':source.get('status'),
        'log_sha256':digest(folder/'run.log'),'fixture_sha256':digest(slot) if slot.is_file() else None,
        'complete':world.get('complete') if world else False,'failures':world.get('failures') if world else None,
        'last_phase':world.get('phase') if world else None,'publication_waits':world.get('publication_waits',[]) if world else [],
        'publication_process_waits':world.get('publication_process_waits',{}) if world else {},
        'startup_conditions':world.get('startup_conditions') if world else None,
        'capture_frames':len(captures),'quantiles':{key:distribution(vals) for key,vals in sorted(spans.items())},
        'span_summary':extras.get('summary') if extras else None,
        'slow_samples':extras.get('slow') if extras else None,
        'host':{'present':bool(load),'exclusive_end':end.get('event')=='end' and not end.get('foreign_godot_observed') and not end.get('godot'),
            'start':load[0] if load else None,'end':end,'max_memory_current':max([int(x.get('memory.current') or 0) for x in load],default=0),
            'max_loadavg':max([x['loadavg'][0] for x in load if 'loadavg' in x],default=None)}}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run',type=Path,action='append',required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    report={'schema':1,'quantile_method':'linear interpolation at (n-1)*p, all retained samples',
        'warning':'Inclusive wall spans overlap. Process-frame waits include scheduling, callbacks and renderer. Software GPU is not hardware acceptance.',
        'runs':[read_run(folder) for folder in a.run]}
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(report,indent=2)+'\n')
    for r in report['runs']:
        print(r['folder'],r['strict_complete_passed'],r['actual_renderer'],r['exit_code'])

if __name__=='__main__': main()
