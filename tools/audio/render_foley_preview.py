#!/usr/bin/env python3
"""Build a short before/after audition from actual PCM; no per-clip normalization."""
import argparse
import io
import json
from pathlib import Path
import subprocess
import tempfile
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
RATE=22050


def load(data):
    with wave.open(io.BytesIO(data),'rb') as f:
        samples=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float)/32768
        samples=samples.reshape(-1,f.getnchannels())
    return np.repeat(samples,2,axis=1) if samples.shape[1]==1 else samples


def build(baseline,output):
    frames=np.zeros((RATE*38,2))
    entries=[]
    def add(time,clip,gain=1.0):
        offset=round(time*RATE)
        length=min(len(clip),len(frames)-offset)
        frames[offset:offset+length]+=clip[:length]*gain
    def current(name): return load((ROOT/'audio/assets'/(name+'.wav')).read_bytes())
    for index,surface in enumerate(['grass','sand','stone','snow','wood','water']):
        start=index*4.2
        entries.append({'seconds':round(start,1),'material':surface,'order':'three old steps, then three revised steps'})
        for variant in range(3):
            name=f'step_{surface}_{variant}'
            previous=load(subprocess.check_output(['git','show',baseline+':audio/assets/'+name+'.wav'],cwd=ROOT))
            add(start+0.15+variant*.55,previous,.85)
            add(start+2.1+variant*.55,current(name),.85)
    add(25.5,current('water_loop')[:RATE*4],.7)
    add(25.5,current('splash'),.85)
    add(27.1,current('swim'),.85)
    add(28.3,current('water_exit'),.85)
    add(30,current('underwater_loop'),.8)
    add(30,current('water_dive'),.85)
    add(32.6,current('underwater_bubbles_0'),.85)
    add(34.4,current('underwater_bubbles_1'),.85)
    add(36.2,current('water_surface'),.85)
    entries += [{'seconds':25.5,'material':'water','order':'shore, entry, stroke, exit'},
                {'seconds':30,'material':'underwater','order':'dive, bed and bubble movement, emerge'}]
    fade=int(RATE*.3)
    frames[-fade:]*=np.linspace(1,0,fade)[:,None]
    assert np.max(np.abs(frames))<.95, 'Preview mix clips'
    output.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory() as directory:
        wav=Path(directory)/'preview.wav'
        with wave.open(str(wav),'wb') as f:
            f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE)
            f.writeframes(np.round(frames*32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','5',str(output)],check=True)
    output.with_suffix('.json').write_text(json.dumps({'baseline':baseline,'duration':38,
      'note':'Actual assets, equal 0.85 gain on old/new steps; no per-clip normalization. Water mix is an audition, not a gameplay recording.','timeline':entries},indent=2)+'\n')
    print(output)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-ref',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    build(args.baseline_ref,args.output)
