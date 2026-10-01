#!/usr/bin/env python3
"""INT30-21: reproducible, bounded refinement of six existing original assets.

The input is the immutable INT30 commit, never already processed output. No
normalization, third-party samples, world RNG or changes to other Foley assets.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import wave

import numpy as np
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/audio"))
from generate_foley import pcm, RATE
BASE = "2b1ac023db4074c2ce6b7db8fbab09ab929a8435"
NAMES = ("underwater_loop", "water_dive", "water_surface",
         "underwater_bubbles_0", "underwater_bubbles_1", "underwater_bubbles_2")


def read(data):
    with wave.open(io.BytesIO(data), "rb") as f:
        assert f.getframerate() == RATE and f.getsampwidth() == 2
        return np.frombuffer(f.readframes(f.getnframes()), dtype="<i2").reshape(-1, f.getnchannels()).astype(float) / 32768


def refine(name, samples):
    frequencies = np.fft.rfftfreq(len(samples), 1 / RATE)
    if name == "underwater_loop":
        # Reduce the constant bed by 8 dB, further ease sub-60 Hz rumble.
        response = 0.4 * (1 - np.exp(-(frequencies / 65.0) ** 4))
    elif name == "water_dive":
        response = 0.65 * np.exp(-(frequencies / 1000.0) ** 4)
    elif name == "water_surface":
        response = 0.60 * np.exp(-(frequencies / 1300.0) ** 4)
    else:
        response = 0.70 * np.exp(-(frequencies / 650.0) ** 4)
    filtered = np.fft.irfft(np.fft.rfft(samples, axis=0) * response[:, None], n=len(samples), axis=0)
    # Periodic filtering retains the eight-second wrap. Single cues retain
    # smooth silent endpoints, unchanged duration, channels and event identity.
    return pcm(filtered, loop=name.endswith("_loop"))


def write(output, source_ref):
    output.mkdir(parents=True, exist_ok=True)
    manifest_path = output / "foley-manifest.json"
    manifest = json.loads(manifest_path.read_text() if manifest_path.exists() else
                          subprocess.check_output(["git", "show", source_ref + ":audio/assets/foley-manifest.json"], cwd=ROOT))
    for name in NAMES:
        original = subprocess.check_output(["git", "show", source_ref + ":audio/assets/" + name + ".wav"], cwd=ROOT)
        data = refine(name, read(original))
        path = output / (name + ".wav")
        with wave.open(str(path), "wb") as f:
            f.setnchannels(data.shape[1])
            f.setsampwidth(2)
            f.setframerate(RATE)
            f.writeframes(data.tobytes())
        manifest["assets"][name] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                                    "frames": len(data), "channels": data.shape[1],
                                    "peak": round(float(np.max(np.abs(data.astype(float)))) / 32767, 6)}
    manifest.setdefault("refinements", {})["INT30-21"] = {"source": source_ref, "generator": "audio/tools/refine_underwater.py", "assets": list(NAMES)}
    (output / "foley-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-ref", default=BASE)
    parser.add_argument("--output", type=Path, default=ROOT / "audio/assets")
    args = parser.parse_args()
    write(args.output, args.source_ref)
    print("Refined six original underwater assets")
