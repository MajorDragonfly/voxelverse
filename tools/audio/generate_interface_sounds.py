#!/usr/bin/env python3
"""Original scanner and order feedback, no external recordings or samples."""
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'audio/assets/interface'
RATE = 22050
# Short melodic shapes deliberately stay consistent between repeated commands.
SCORES = {
 'scan_acquire': (.22, [(0, 740, .8), (.08, 990, .55)]),
 'scan_abort': (.20, [(0, 520, .6), (.07, 390, .45)]),
 'order_move': (.32, [(0, 440, .8), (.10, 660, .65)]),
 'order_gather': (.38, [(0, 620, .6), (.09, 780, .7), (.18, 930, .45)]),
 'order_attack': (.34, [(0, 165, .8), (.07, 220, .75), (.14, 330, .6)]),
 'order_build': (.44, [(0, 330, .8), (.12, 440, .65), (.24, 550, .6)]),
 'order_wait': (.30, [(0, 440, .7), (.10, 440, .45)]),
 'order_feed': (.38, [(0, 520, .75), (.13, 660, .55)]),
 'order_reject': (.30, [(0, 290, .7), (.10, 220, .6)]),
}


def write(name, samples, peak):
    samples -= samples.mean()
    samples *= peak/max(float(np.abs(samples).max()), .001)
    pcm = np.round(samples*32767).astype('<i2')
    if name != 'scan_loop':
        pcm[0]=pcm[-1]=0
    with wave.open(str(OUT/(name+'.wav')), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes(pcm.tobytes())
    assert np.abs(pcm).max() < 18000
    return pcm


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    names=[]
    for name,(duration,notes) in SCORES.items():
        t=np.arange(round(duration*RATE))/RATE
        samples=np.zeros_like(t)
        for start,hz,gain in notes:
            x=np.maximum(t-start,0)
            env=(t>=start)*(1-np.exp(-x*500))*np.exp(-x*23)
            samples += gain*env*(np.sin(2*np.pi*hz*x)+.12*np.sin(2*np.pi*hz*2*x))
        fade=np.minimum(t/.006,1)*np.clip((duration-t)/.065,0,1)
        samples *= fade
        # Repeat the endpoint envelope after removing DC to preserve exact zeros.
        samples -= samples.mean(); samples *= fade
        samples[0]=samples[-1]=0
        write(name,samples,.42)
        names.append(name)
    t=np.arange(RATE)/RATE
    loop=(np.sin(2*np.pi*220*t)+.23*np.sin(2*np.pi*440*t)+.09*np.sin(2*np.pi*880*t))
    loop *= .72+.28*np.cos(2*np.pi*4*t)
    pcm=write('scan_loop',loop,.22)
    assert abs(int(pcm[0])-int(pcm[-1]))/32768 < .025
    names.append('scan_loop')
    entries=['\t&"%s": [preload("res://audio/assets/interface/%s.wav")],' % (name,name) for name in names]
    (ROOT/'audio/runtime/interface_sound_library.gd').write_text('extends RefCounted\nconst SOUNDS := {\n'+'\n'.join(entries)+'\n}\n')
    print(len(names),'interface sounds generated; loop seam verified')

if __name__=='__main__':
    main()
