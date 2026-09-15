#!/usr/bin/env python3
"""Inspect committed PCM and loop seams; measurements do not replace listening."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[2]


def read(data):
    with wave.open(io.BytesIO(data),'rb') as stream:
        width,rate,channels=stream.getsampwidth(),stream.getframerate(),stream.getnchannels()
        if width!=2 or rate!=22050 or channels not in (1,2):
            raise ValueError('Expected 22050 Hz 16-bit mono/stereo PCM')
        samples=np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').astype(float)/32768.0
    return rate,samples.reshape(-1,channels)


def measure(data):
    rate,samples=read(data)
    mono=np.mean(samples,axis=1)
    energy=float(np.sum(samples*samples))
    spectrum=np.abs(np.fft.rfft(mono))**2
    frequencies=np.fft.rfftfreq(len(mono),1/rate)
    frame=int(rate*.02)
    windows=[float(np.mean(samples[i:i+frame]**2)) for i in range(0,len(samples)-frame+1,frame)]
    return {'duration':len(samples)/rate,'channels':samples.shape[1],
            'peak':float(np.max(np.abs(samples))), 'rms':float(np.sqrt(np.mean(samples*samples))),
            'dc':float(np.max(np.abs(np.mean(samples,axis=0)))),
            'first_35ms_energy_fraction':float(np.sum(samples[:int(rate*.035)]**2))/max(energy,1e-15),
            'centroid_hz':float(np.sum(spectrum*frequencies))/max(float(np.sum(spectrum)),1e-15),
            'energy_above_4khz':float(np.sum(spectrum[frequencies>4000]))/max(float(np.sum(spectrum)),1e-15),
            'envelope_peak_ms':int(np.argmax(windows))*20,
            'loop_seam':float(np.max(np.abs(samples[-1]-samples[0]))),
            'endpoints_zero':bool(np.all(samples[[0,-1]]==0))}


def check(root=ROOT,baseline=None):
    assets=root/'audio/assets'
    manifest=json.loads((assets/'foley-manifest.json').read_text())
    errors=[];results={};comparisons={}
    for name,record in manifest['assets'].items():
        path=assets/(name+'.wav')
        data=path.read_bytes()
        if hashlib.sha256(data).hexdigest()!=record['sha256']: errors.append(name+': checksum')
        report=measure(data);results[name]=report
        if not (0.0005<report['rms']<0.12 and report['peak']<=0.401 and report['dc']<0.005): errors.append(name+': levels')
        if name.endswith('_loop'):
            if abs(report['duration']-8.0)>1e-6 or report['loop_seam']>0.035: errors.append(name+': loop seam/length')
        elif not report['endpoints_zero']: errors.append(name+': untrimmed endpoints')
        if report['channels']!=(2 if name=='underwater_loop' else 1): errors.append(name+': channels')
        if name.startswith('step_') and report['first_35ms_energy_fraction']>0.16: errors.append(name+': front-loaded impact')
        if baseline and (name.startswith('step_') or name in ('water_loop','underwater_loop','land','splash','swim')):
            old=subprocess.check_output(['git','show',baseline+':audio/assets/'+name+'.wav'],cwd=root)
            comparisons[name]={'before':measure(old),'after':report}
    if len(manifest['assets'])!=29: errors.append('Expected complete 29-asset inventory')
    for material in ('grass','sand','stone','snow','wood','water'):
        variants=[read((assets/f'step_{material}_{i}.wav').read_bytes())[1].ravel() for i in range(3)]
        for i in range(3):
            for j in range(i+1,3):
                if abs(float(np.corrcoef(variants[i],variants[j])[0,1]))>0.85:
                    errors.append(material+': variants too similar')
    return {'passed':not errors,'errors':errors,'assets':results,'comparison':comparisons,
            'limits':'Signal, file and seam checks only. No subjective hearing acceptance.'}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--baseline-ref')
    args=parser.parse_args()
    result=check(baseline=args.baseline_ref)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'passed':result['passed'],'errors':result['errors'],'assets':len(result['assets'])}))
    raise SystemExit(0 if result['passed'] else 1)
