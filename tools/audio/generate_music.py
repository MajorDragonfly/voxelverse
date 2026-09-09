#!/usr/bin/env python3
"""Compose original, seamless Voxelverse loops. Requires NumPy and ffmpeg.

No recordings, sample packs or pre-existing melodies. Score is deliberately
editable below; the game needs only the shipped Ogg files, not Python/ffmpeg.
Circular placement includes releases and delay returns across the loop seam.
"""
from pathlib import Path
import json
import subprocess
import tempfile
import wave

import numpy as np

RATE = 32000
BPM = 96
BEAT = 60 / BPM
OUT = Path(__file__).resolve().parents[2] / 'audio/assets/music'
TAU = 2 * np.pi
TRACKS = {
    'menu': ('Kleine Umlaufbahn', 16, 4301),
    'exploration': ('Unter fremden Blättern', 24, 4302),
    'danger': ('Etwas im Unterholz', 16, 4303),
}
# Two bars each: Dm9 / G6 / Cmaj9 / Am7, all within D Dorian.
CHORDS = [(50, [62, 65, 69, 72, 76]), (43, [62, 64, 67, 71]),
          (48, [60, 64, 67, 71, 74]), (45, [60, 64, 67, 69])]
# Four original question/answer phrases, sparse syncopation with rests.
MELODY = [
    [(0, 74, .65), (1.5, 76, .35), (2.5, 81, .75), (4.5, 79, .45), (6, 76, 1.2)],
    [(.5, 74, .7), (2, 71, .6), (3.5, 69, .4), (5, 67, 1.5)],
    [(0, 76, .7), (1.5, 79, .45), (3, 74, 1.0), (5.5, 71, .5), (7, 72, .7)],
    [(.5, 76, .6), (2.5, 72, .5), (4, 69, 1.6), (6.5, 71, .45), (7.25, 72, .45)],
]


def envelope(t, duration, attack=.015, release=.13):
    return np.minimum(t / attack, 1) * np.clip((duration - t) / release, 0, 1)


def instrument(midi, beats, kind, rng):
    duration = beats * BEAT
    release = .5 if kind == 'keys' else .2
    if kind == 'pad':
        release = 1.35
    length = duration + release
    t = np.arange(round(length * RATE)) / RATE
    f = 440 * 2 ** ((midi - 69) / 12)
    phase = TAU * f * t
    if kind == 'pad':
        a = rng.uniform(0, TAU)
        s = (.48 * np.sin(phase + a) + .22 * np.sin(phase * 1.0015 + a)
             + .18 * np.sin(phase * .9985 + a) + .07 * np.sin(phase * 2 + .2))
        env = envelope(t, length, .65, release)
        return s * env * (.94 + .06 * np.sin(TAU * .2 * t))
    if kind == 'keys':
        # A rounded, bell-like electric key with gentle FM on the attack.
        s = np.sin(phase + .65 * np.exp(-t * 7) * np.sin(phase * 2))
        s += .13 * np.sin(phase * 3) * np.exp(-t * 6)
        return s * np.exp(-t * 2.8) * envelope(t, length, .007, release)
    if kind == 'bass':
        s = .78 * np.sin(phase) + .17 * np.sin(phase * 2) + .05 * np.sin(phase * 3)
        return s * np.exp(-t * .75) * envelope(t, length, .012, release)
    # Soft triangle-like lead; no aliased saw/square wave.
    s = np.sin(phase) - .09 * np.sin(phase * 3) + .028 * np.sin(phase * 5)
    s *= 1 + .018 * np.sin(TAU * 5 * t)
    return s * np.exp(-t * 1.5) * envelope(t, length, .02, release)


def drum(kind, rng):
    duration = {'kick': .32, 'snare': .19, 'hat': .085, 'rim': .065}[kind]
    t = np.arange(round(duration * RATE)) / RATE
    noise = rng.normal(0, 1, len(t))
    bright = noise - np.convolve(noise, np.ones(9) / 9, mode='same')
    if kind == 'kick':
        phase = TAU * (47 * t + 85 * .023 * (1 - np.exp(-t / .023)))
        s = np.sin(phase) * np.exp(-t * 15) + bright * .025 * np.exp(-t * 130)
    elif kind == 'snare':
        s = .30 * bright * np.exp(-t * 28) + .17 * np.sin(TAU * 178 * t) * np.exp(-t * 32)
    elif kind == 'rim':
        s = (.28 * np.sin(TAU * 760 * t) + .18 * np.sin(TAU * 1210 * t)) * np.exp(-t * 90)
    else:
        s = bright * .18 * np.exp(-t * 68)
    return s * envelope(t, duration, .0015, .012)


def add(buffer, sound, at_beat, gain, pan=0):
    start = round(at_beat * BEAT * RATE) % len(buffer)
    stereo = sound[:, None] * gain * np.array([np.sqrt((1-pan)/2), np.sqrt((1+pan)/2)])
    first = min(len(stereo), len(buffer) - start)
    buffer[start:start+first] += stereo[:first]
    if first < len(stereo):
        buffer[:len(stereo)-first] += stereo[first:]


def compose(context, bars, seed):
    rng = np.random.default_rng(seed)
    length = round(bars * 4 * BEAT * RATE)
    melodic = np.zeros((length, 2), np.float64)
    rhythm = np.zeros_like(melodic)
    for bar in range(bars):
        root, chord = CHORDS[(bar // 2) % 4]
        beat = bar * 4
        phrase = bar // 8
        if bar % 2 == 0:
            for i, note in enumerate(chord):
                add(melodic, instrument(note-12, 8, 'pad', rng), beat,
                    .037 if context == 'danger' else .06, (i / (len(chord)-1) - .5) * 1.1)
        # Each section changes density and answers rather than repeating a bar.
        if context == 'menu':
            key_positions = [0, 1.5, 2.75] if bar % 2 == 0 else [.5, 2, 3.5]
        elif context == 'exploration':
            key_positions = [0.5, 3] if phrase != 1 else [1.5]
        else:
            key_positions = [.5, 1.75, 2.5, 3.75]
        for i, pos in enumerate(key_positions):
            note = chord[(bar + i * 2) % len(chord)]
            add(melodic, instrument(note, .8, 'keys', rng), beat + pos,
                .09 if context != 'exploration' else .068, (-1 if i % 2 else 1) * .32)
        bass_steps = [(0, root, .9), (1.75, root, .5), (2.5, root+7, .6)]
        if context == 'exploration':
            bass_steps = [(0, root, 2.2)] if bar % 2 == 0 else [(2.5, root+7, 1.0)]
        elif context == 'danger':
            bass_steps = [(0, root, .65), (.75, root, .4), (1.5, root+12, .4),
                          (2.5, root, .5), (3.25, root+7, .45)]
        for pos, note, duration in bass_steps:
            add(rhythm, instrument(note-12, duration, 'bass', rng), beat+pos,
                .19 if context != 'exploration' else .15)
        if context != 'exploration' or phrase == 1:
            kicks = [0, 2.5] if context != 'danger' else [0, 1.5, 2.75]
            for pos in kicks:
                add(rhythm, drum('kick', rng), beat+pos, .22 if context != 'exploration' else .10)
            for pos in [1, 3]:
                add(rhythm, drum('rim' if context == 'exploration' else 'snare', rng), beat+pos, .18)
            for i in range(8):
                # A little swing, bounded dynamics and soft stereo hats.
                pos = i * .5 + (.07 if i % 2 else 0)
                add(rhythm, drum('hat', rng), beat+pos,
                    (.095 if i % 2 else .14) * (.6 if context == 'exploration' else 1), .25)
            if context == 'danger' and bar % 4 == 3:
                for pos in [3.25, 3.75]:
                    add(rhythm, drum('rim', rng), beat+pos, .11, -.3)
        elif bar % 2 == 1:
            add(rhythm, drum('rim', rng), beat+3, .08, -.2)
        if bar % 2 == 0:
            motif = MELODY[(bar // 2) % 4]
            if context == 'exploration' and phrase == 1:
                motif = motif[::2]
            if context == 'danger':
                motif = [(pos, note-12, duration*.7) for pos, note, duration in motif[::2]]
            for pos, note, duration in motif:
                # Leave more air in the last exploratory section.
                if context == 'exploration' and phrase == 2 and pos < 2:
                    continue
                add(melodic, instrument(note, duration, 'lead', rng), beat+pos,
                    .062 if context != 'danger' else .05, -.08)
    # Circular stereo delays preserve tails at the end without a silence gap.
    delay = round(.75 * BEAT * RATE)
    wet = np.roll(melodic[:, ::-1], delay, axis=0) * .20
    wet += np.roll(melodic, delay*2, axis=0) * .09
    mix = rhythm + melodic + wet
    mix -= mix.mean(axis=0)
    rms = float(np.sqrt(np.mean(mix**2)))
    mix *= min(.115 / rms, .59 / np.abs(mix).max())
    return mix


def write_wav(path, mix):
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((np.clip(mix, -1, 1) * 32767).astype('<i2').tobytes())


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {'bpm': BPM, 'meter': '4/4', 'tonality': 'D Dorian', 'sample_rate': RATE, 'tracks': {}}
    with tempfile.TemporaryDirectory(prefix='voxelverse-music-') as tmp:
        for context, (title, bars, seed) in TRACKS.items():
            mix = compose(context, bars, seed)
            assert np.isfinite(mix).all() and np.abs(mix).max() <= .60
            assert np.max(np.abs(mix[0] - mix[-1])) < .035, 'PCM seam discontinuity'
            wav = Path(tmp) / (context + '.wav')
            write_wav(wav, mix)
            destination = OUT / (context + '.ogg')
            subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(wav),
                            '-map_metadata', '-1', '-c:a', 'libvorbis', '-q:a', '4',
                            '-metadata', f'title={title}', '-metadata', 'artist=Voxelverse prototype',
                            str(destination)], check=True)
            decoded = subprocess.check_output(['ffmpeg', '-hide_banner', '-loglevel', 'error',
                                               '-i', str(destination), '-f', 'f32le', '-acodec',
                                               'pcm_f32le', '-'])
            audio = np.frombuffer(decoded, dtype='<f4').reshape(-1, 2)
            assert abs(len(audio)-len(mix)) <= 1, 'Codec changes loop duration'
            assert np.isfinite(audio).all() and np.abs(audio).max() < .8
            seam = float(np.max(np.abs(audio[0] - audio[-1])))
            assert seam < .035, 'Encoded loop seam discontinuity'
            manifest['tracks'][context] = {'title': title, 'bars': bars,
                'seconds': len(mix) / RATE, 'file': destination.name,
                'decoded_peak': round(float(np.abs(audio).max()), 5),
                'decoded_rms': round(float(np.sqrt(np.mean(audio**2))), 5),
                'seam_max_delta': round(seam, 6)}
            print(context, title, len(mix) / RATE, 'seconds', destination.stat().st_size, 'bytes', 'seam', round(seam, 6))
    (OUT / 'score.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')


if __name__ == '__main__':
    main()
