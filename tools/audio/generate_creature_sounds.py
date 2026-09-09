#!/usr/bin/env python3
"""Original nonverbal creature calls: three timbres, six reactions, two takes.

Offline synthesis only. No recordings or voice models are used.
"""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "audio/assets/creatures"
FAMILIES = {"chirp": (430, 1400, 3200), "throat": (115, 650, 1600),
            "rasp": (170, 1050, 2300)}
REACTIONS = {"contact": 0.65, "warn": 0.95, "attack": 0.32,
             "hurt": 0.43, "death": 1.05, "friend": 0.8}


def synth(family, reaction, take, seed):
    rng = np.random.default_rng(seed)
    duration = REACTIONS[reaction] * (1 + take * 0.07)
    t = np.arange(round(RATE * duration)) / RATE
    u = t / duration
    base, formant_a, formant_b = FAMILIES[family]
    contour = {"contact": 1 + 0.18 * np.sin(u * 3 * np.pi),
               "warn": 0.95 - 0.12 * u,
               "attack": 1.4 - 0.5 * u,
               "hurt": 1.7 - 0.8 * u,
               "death": 1.0 - 0.55 * u,
               "friend": 0.9 + 0.35 * u}[reaction]
    f0 = base * (1 + take * 0.055) * contour
    f0 *= 1 + 0.025 * np.sin(2 * np.pi * (17 if family == "rasp" else 7) * t)
    phase = 2 * np.pi * np.cumsum(f0) / RATE
    samples = np.zeros_like(t)
    for harmonic in range(1, 23):
        hz = harmonic * f0
        weight = np.exp(-0.5 * ((hz - formant_a) / 390) ** 2)
        weight += 0.55 * np.exp(-0.5 * ((hz - formant_b) / 520) ** 2)
        weight += 0.3 / harmonic
        samples += np.sin(phase * harmonic) * weight / harmonic
    breath = rng.normal(0, 1, len(t))
    breath = np.convolve(breath, np.ones(5) / 5, mode="same")
    samples += breath * (0.24 if family == "rasp" else 0.06)
    envelope = np.sin(np.pi * u) ** 1.1
    if reaction in ("contact", "friend"):
        envelope *= (0.5 + 0.5 * np.sin(u * np.pi * 5 - np.pi / 2)) ** 2
    if reaction in ("attack", "hurt"):
        envelope *= np.exp(-u * 2)
    if reaction == "death":
        envelope *= (1 - u) ** 0.7
    samples *= envelope
    samples -= samples.mean()
    fade = min(300, len(t) // 4)
    samples[:fade] *= np.linspace(0, 1, fade)
    samples[-fade:] *= np.linspace(1, 0, fade)
    samples *= 0.52 / max(np.max(np.abs(samples)), 0.001)
    samples[0] = samples[-1] = 0
    return np.round(samples * 32767).astype("<i2")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for family_index, family in enumerate(FAMILIES):
        for event_index, reaction in enumerate(REACTIONS):
            for take in range(2):
                pcm = synth(family, reaction, take, 91009 + family_index * 100 + event_index * 3 + take)
                with wave.open(str(OUT / f"{family}_{reaction}_{take}.wav"), "wb") as output:
                    output.setnchannels(1)
                    output.setsampwidth(2)
                    output.setframerate(RATE)
                    output.writeframes(pcm.tobytes())
    library = ['extends RefCounted', 'const SOUNDS := {']
    for family in FAMILIES:
        for reaction in REACTIONS:
            clips = ', '.join(f'preload("res://audio/assets/creatures/{family}_{reaction}_{take}.wav")' for take in range(2))
            library.append(f'\t&"creature_{family}_{reaction}": [{clips}],')
    library.append('}')
    (OUT.parents[1] / "runtime/creature_sound_library.gd").write_text('\n'.join(library) + '\n')
    print("36 original creature WAVs and resource manifest generated")


if __name__ == "__main__":
    main()
