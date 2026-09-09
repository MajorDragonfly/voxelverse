#!/usr/bin/env python3
"""Original Voxelverse prototype sounds. Requires numpy; no downloaded samples.

Run from any directory. WAVs are committed: players do not need Python.
Periodic FFT noise makes the ambience loop without crossfade discontinuities.
"""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "audio/assets"
RNG = np.random.default_rng(90609)


def noise(n, low=40, high=5000):
    frequencies = np.fft.rfftfreq(n, 1 / RATE)
    spectrum = np.fft.rfft(RNG.normal(size=n))
    spectrum *= (1 - np.exp(-(frequencies / low) ** 2))
    spectrum *= np.exp(-(frequencies / high) ** 2)
    result = np.fft.irfft(spectrum, n=n)
    return result / max(np.std(result), 0.001)


def save(name, samples, loop=False):
    samples = samples - np.mean(samples, axis=0)
    if not loop:
        fade = min(int(RATE * 0.012), len(samples) // 4)
        samples[:fade] *= np.linspace(0, 1, fade)
        samples[-fade:] *= np.linspace(1, 0, fade)
        samples[0] = samples[-1] = 0
    peak = np.max(np.abs(samples))
    samples *= min(1.0, 0.65 / max(peak, 0.001))
    pcm = np.round(samples * 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as output:
        output.setnchannels(1 if samples.ndim == 1 else samples.shape[1])
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def impact(surface, variant):
    duration, high, grit, bass = {
        "grass": (0.25, 3900, 0.28, 110),
        "sand": (0.29, 5100, 0.22, 85),
        "stone": (0.19, 7300, 0.14, 185),
        "snow": (0.34, 3200, 0.30, 95),
        "wood": (0.23, 2000, 0.12, 220),
        "water": (0.42, 4700, 0.26, 320),
    }[surface]
    t = np.arange(int(RATE * duration)) / RATE
    decay = np.exp(-t * (16 if surface == "stone" else 11))
    crunch = noise(len(t), 180, high) * grit
    pulse = np.sin(2 * np.pi * (bass + variant * 8) * t) * np.exp(-t * 40) * 0.28
    if surface == "water":
        pulse += 0.13 * np.sin(2 * np.pi * (850 * t - 620 * t * t)) * np.exp(-t * 8)
    save(f"step_{surface}_{variant}", crunch * decay + pulse)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for surface in ["grass", "sand", "stone", "snow", "wood", "water"]:
        for variant in range(3):
            impact(surface, variant)
    for name, duration, high in [("jump", 0.20, 1900), ("land", 0.35, 1600),
                                 ("splash", 0.72, 4700), ("swim", 0.62, 2600)]:
        t = np.arange(int(RATE * duration)) / RATE
        envelope = np.sin(np.pi * t / duration) ** 1.4 * np.exp(-t * 4)
        samples = noise(len(t), 80, high) * envelope * 0.26
        if name in ("splash", "swim"):
            samples += np.sin(2 * np.pi * (420 * t + 600 * t * t)) * envelope * 0.10
        if name == "land":
            samples += np.sin(2 * np.pi * 65 * t) * np.exp(-t * 22) * 0.42
        save(name, samples)
    for name, notes in [("ui_confirm", [620, 880]), ("ui_back", [520, 390]),
                        ("discovery", [440, 550, 660, 880])]:
        duration = 0.14 * len(notes) + 0.22
        t = np.arange(int(RATE * duration)) / RATE
        samples = np.zeros_like(t)
        for i, frequency in enumerate(notes):
            local = np.maximum(t - i * 0.14, 0)
            envelope = (1 - np.exp(-local * 160)) * np.exp(-local * 13)
            samples += np.sin(2 * np.pi * frequency * local) * envelope * 0.24
        save(name, samples)
    n = RATE * 8
    t = np.arange(n) / RATE
    for name, low, high, gain in [("wind_loop", 40, 650, 0.065),
                                  ("foliage_loop", 800, 5500, 0.028),
                                  ("water_loop", 80, 3900, 0.07),
                                  ("underwater_loop", 25, 290, 0.09)]:
        channels = []
        for channel in range(1 if name == "water_loop" else 2):
            envelope = 0.72 + 0.18 * np.sin(2 * np.pi * t / 8 + channel)
            envelope += 0.10 * np.sin(2 * np.pi * t * 3 / 8 + channel * 2)
            channels.append(noise(n, low, high) * envelope * gain)
        samples = channels[0] if len(channels) == 1 else np.column_stack(channels)
        save(name, samples, loop=True)
    print(f"Generated {len(list(OUT.glob('*.wav')))} original WAV files in {OUT}")


if __name__ == "__main__":
    main()
