#!/usr/bin/env python3
"""Original action feedback. NumPy synthesis only, no recordings or samples."""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'audio/assets/actions'
DURATIONS = {'eat': .72, 'drink': .94, 'gather': .48, 'evolve': 2.2}


def synth(event, take):
    rng = np.random.default_rng(43100 + list(DURATIONS).index(event)*10 + take)
    duration = DURATIONS[event] * (1 + .035 * take)
    t = np.arange(round(duration*RATE)) / RATE
    signal = np.zeros_like(t)
    noise = rng.normal(0, 1, len(t))
    low = np.convolve(noise, np.ones(7)/7, mode='same')
    if event == 'eat':
        # Three soft, crunchy bites with a low organic resonance.
        for start in [.035, .245, .47]:
            x = np.maximum(t-start, 0)
            env = (t >= start) * (1-np.exp(-x*650)) * np.exp(-x*29)
            signal += env * (.46*(noise-low) + .32*low + .07*np.sin(2*np.pi*185*x))
    elif event == 'drink':
        for i, start in enumerate([.04, .19, .36, .57]):
            x = np.maximum(t-start, 0)
            f = (440 + 65*i + take*20)
            phase = 2*np.pi*(f*x + 190*.05*(1-np.exp(-x/.05)))
            env = (t >= start) * (1-np.exp(-x*130)) * np.exp(-x*19)
            signal += env * (.34*np.sin(phase) + .12*low)
        signal += low * .045 * np.sin(np.pi*t/duration)**2
    elif event == 'gather':
        env = (1-np.exp(-t*180))*np.exp(-t*15)
        signal = env*(.36*low + .045*noise)
        for start, note in [(.035, 74), (.13, 81)]:
            x = np.maximum(t-start, 0)
            f = 440*2**((note-69 + take*.15)/12)
            signal += (t>=start)*(1-np.exp(-x*420))*np.exp(-x*16)*.14*np.sin(2*np.pi*f*x)
    else:
        # A short ascending D-Dorian confirmation, distinct from discovery.
        for i, note in enumerate([62, 65, 69, 74, 76]):
            start = .055 + i*.18
            x = np.maximum(t-start, 0)
            f = 440*2**((note-69)/12)
            env = (t>=start)*(1-np.exp(-x*65))*np.exp(-x*(2.8 + .1*take))
            signal += env*(.14*np.sin(2*np.pi*f*x) + .025*np.sin(2*np.pi*f*2*x))
        signal += low*.018*np.sin(np.pi*t/duration)**2
    signal -= signal.mean()
    fade = min(240, len(t)//5)
    signal[:fade] *= np.linspace(0,1,fade)
    signal[-fade:] *= np.linspace(1,0,fade)
    signal *= .5 / max(float(np.abs(signal).max()), .001)
    signal[0] = signal[-1] = 0
    assert np.isfinite(signal).all() and float(np.sqrt(np.mean(signal**2))) > .015
    return np.round(signal*32767).astype('<i2')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for event in DURATIONS:
        paths = []
        for take in range(3):
            pcm = synth(event, take)
            path = OUT / f'{event}_{take}.wav'
            with wave.open(str(path), 'wb') as f:
                f.setnchannels(1)
                f.setsampwidth(2)
                f.setframerate(RATE)
                f.writeframes(pcm.tobytes())
            assert pcm[0] == pcm[-1] == 0 and np.abs(pcm).max() <= 16384
            paths.append(f'preload("res://audio/assets/actions/{path.name}")')
        entries.append(f'\t&"action_{event}": [{", ".join(paths)}],')
        print(event, '3 variants', DURATIONS[event], 'seconds nominal')
    (ROOT / 'audio/runtime/action_sound_library.gd').write_text(
        'extends RefCounted\n## Generated references preserve all action sounds in exports.\nconst SOUNDS := {\n'
        + '\n'.join(entries) + '\n}\n')


if __name__ == '__main__':
    main()
