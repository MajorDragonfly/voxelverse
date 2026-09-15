#!/usr/bin/env python3
"""M10-FOLEY: original layered foot contacts and water textures (NumPy only).

Each asset owns a fixed RNG seed, independent of generation order. No samples,
voices or third-party recordings. Runtime consumes committed PCM, not synthesis.
"""
import argparse
import hashlib
import json
from pathlib import Path
import wave
import numpy as np

RATE = 22050
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'audio/assets'
REVISION = 1
SURFACES = ('grass', 'sand', 'stone', 'snow', 'wood', 'water')


def rng_for(name):
    return np.random.default_rng(int.from_bytes(hashlib.sha256(('foley-v1:'+name).encode()).digest()[:8], 'little'))


def filtered(n, rng, low, high):
    frequencies = np.fft.rfftfreq(n, 1 / RATE)
    spectrum = np.fft.rfft(rng.normal(size=n))
    spectrum *= (1 - np.exp(-(frequencies / low) ** 2)) * np.exp(-(frequencies / high) ** 4)
    result = np.fft.irfft(spectrum, n=n)
    return result / max(np.std(result), 0.001)


def contact(t, start, attack, decay):
    local = np.maximum(t-start, 0)
    return (1-np.exp(-(local/attack)**2)) * np.exp(-local/decay)


def grain_bed(t, rng, low, high, count, start, finish, attack, decay):
    envelope = np.zeros_like(t)
    for _ in range(count):
        envelope += contact(t, rng.uniform(start, finish), attack, decay) * rng.uniform(0.4, 1.0)
    return filtered(len(t), rng, low, high) * envelope / max(1.0, np.max(envelope))


def bubbles(t, rng, count, start=0.02, finish=None, base=260):
    result = np.zeros_like(t)
    finish = max(start+0.01, t[-1]-0.12) if finish is None else finish
    for _ in range(count):
        onset = rng.uniform(start, finish)
        local = np.maximum(t-onset, 0)
        frequency = base * rng.uniform(0.65, 1.7)
        # Short rising resonances, confined to the lower underwater passband.
        phase = 2*np.pi*frequency*(local + 0.18*local*local)
        result += np.sin(phase) * contact(t, onset, 0.008, rng.uniform(0.022, 0.055)) * rng.uniform(0.025, 0.065)
    return result


def footstep(surface, variant):
    rng = rng_for(f'step_{surface}_{variant}')
    duration, low, high, texture, body = {
        'grass': (0.38, 650, 4200, 0.052, 0.095),
        'sand': (0.42, 450, 3100, 0.062, 0.085),
        'stone': (0.30, 900, 4300, 0.032, 0.11),
        'snow': (0.48, 450, 3400, 0.072, 0.070),
        'wood': (0.37, 550, 2200, 0.035, 0.095),
        'water': (0.56, 230, 2800, 0.065, 0.035),
    }[surface]
    t = np.arange(int(RATE*duration)) / RATE
    heel = contact(t, 0.006, 0.022, 0.065)
    toe = contact(t, rng.uniform(0.075, 0.10), 0.026, 0.078)
    weight = filtered(len(t), rng, 45, 320) * (heel + 0.6*toe) * body
    # A rolling sole and later material displacement, rather than a single bang.
    scuff = grain_bed(t, rng, low, high, 14 if surface!='stone' else 5,
                      0.022, duration*0.65, 0.009, 0.030) * texture
    if surface == 'wood':
        weight += (np.sin(2*np.pi*155*t)+0.25*np.sin(2*np.pi*355*t))*heel*0.023
    elif surface == 'stone':
        scuff += filtered(len(t), rng, 1400, 4400)*toe*0.02
    elif surface == 'water':
        scuff += bubbles(t, rng, 7, base=430)
    return weight+scuff


def water_effect(name):
    rng=rng_for(name)
    duration={'splash':0.82, 'swim':0.78, 'water_exit':0.65,
              'water_dive':0.75, 'water_surface':0.82}.get(name,0.9)
    t=np.arange(int(RATE*duration))/RATE
    if name.startswith('underwater_bubbles'):
        return bubbles(t,rng,9,base=250)+filtered(len(t),rng,50,450)*contact(t,0.02,0.07,0.28)*0.009
    if name=='water_dive':
        return filtered(len(t),rng,45,1100)*contact(t,0,0.055,0.20)*0.075+bubbles(t,rng,13,base=290)
    if name=='water_surface':
        return grain_bed(t,rng,180,1900,12,0.01,0.48,0.016,0.060)*0.065+bubbles(t,rng,6,base=410)
    if name=='water_exit':
        return grain_bed(t,rng,450,2900,10,0.02,0.48,0.012,0.025)*0.045+bubbles(t,rng,5,base=580)
    strength=0.085 if name=='splash' else 0.05
    result=filtered(len(t),rng,150,2400)*contact(t,0.0,0.048,0.21)*strength
    result+=grain_bed(t,rng,400,3400,18,0.12,duration*0.8,0.012,0.04)*strength*0.5
    return result+bubbles(t,rng,14 if name=='splash' else 6,base=380)


def ambience(name):
    rng=rng_for(name)
    n=RATE*8
    t=np.arange(n)/RATE
    if name=='water_loop':
        # Several lapping waves, with irregular droplets, on one spatial voice.
        swell=0.36+0.18*np.sin(2*np.pi*3*t/8)+0.14*np.sin(2*np.pi*5*t/8+1.1)
        samples=filtered(n,rng,100,2300)*swell*0.045
        for index in range(9):
            local_t=np.arange(RATE//2)/RATE
            drop=bubbles(local_t,rng,5,base=510)*0.28
            start=int(rng.uniform(0,n))
            samples[(np.arange(len(drop))+start)%n]+=drop
        return samples
    channels=[]
    # Quiet submerged bed plus discrete cavity/bubble textures, without breaths.
    for channel in range(2):
        swell=0.62+0.20*np.sin(2*np.pi*t/8+channel*0.4)+0.12*np.sin(2*np.pi*3*t/8+1.2)
        bed=filtered(n,rng,28,210)*swell*0.026
        for index in range(16):
            local_t=np.arange(int(RATE*0.7))/RATE
            cluster=bubbles(local_t,rng,4,base=180)*0.23
            start=int(rng.uniform(0,n))
            bed[(np.arange(len(cluster))+start)%n]+=cluster
        channels.append(bed)
    return np.column_stack(channels)


def assets():
    result={f'step_{surface}_{i}':footstep(surface,i) for surface in SURFACES for i in range(3)}
    for name in ('splash','swim','water_exit','water_dive','water_surface',
                 'underwater_bubbles_0','underwater_bubbles_1','underwater_bubbles_2'):
        result[name]=water_effect(name)
    rng=rng_for('land')
    t=np.arange(int(RATE*0.44))/RATE
    result['land']=filtered(len(t),rng,40,400)*contact(t,0,0.023,0.12)*0.14
    result['land']+=grain_bed(t,rng,350,2000,12,0.03,0.27,0.014,0.04)*0.045
    for name in ('water_loop','underwater_loop'):
        result[name]=ambience(name)
    return result


def pcm(samples, loop=False):
    samples=np.array(samples,dtype=np.float64,copy=True)
    samples-=np.mean(samples,axis=0)
    if not loop:
        fade=min(int(RATE*0.014),len(samples)//4)
        end=min(int(RATE*0.050),len(samples)//4)
        if samples.ndim==1:
            samples[:fade]*=np.linspace(0,1,fade)**2
            samples[-end:]*=np.linspace(1,0,end)**2
        else:
            samples[:fade]*=(np.linspace(0,1,fade)**2)[:,None]
            samples[-end:]*=(np.linspace(1,0,end)**2)[:,None]
        samples[0]=samples[-1]=0
    samples*=min(1.0,0.40/max(np.max(np.abs(samples)),0.001))
    return np.round(samples*32767).astype('<i2')


def write(directory=OUT):
    directory=Path(directory)
    directory.mkdir(parents=True,exist_ok=True)
    records={}
    for name,samples in assets().items():
        data=pcm(samples,name.endswith('_loop'))
        path=directory/(name+'.wav')
        with wave.open(str(path),'wb') as output:
            output.setnchannels(1 if data.ndim==1 else data.shape[1])
            output.setsampwidth(2);output.setframerate(RATE);output.writeframes(data.tobytes())
        records[name]={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                       'frames':len(data),'channels':1 if data.ndim==1 else data.shape[1],
                       'peak':round(float(np.max(np.abs(data.astype(float))))/32767,6)}
    (directory/'foley-manifest.json').write_text(json.dumps({'revision':REVISION,'rate':RATE,'assets':records},indent=2)+'\n')
    return records


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=OUT)
    args=parser.parse_args()
    print(f'Generated {len(write(args.output))} original M10-FOLEY assets')
