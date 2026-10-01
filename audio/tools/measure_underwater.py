#!/usr/bin/env python3
"""Measure all PCM channels and compare INT30 underwater assets without gain matching."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

import numpy as np
from refine_underwater import BASE, NAMES, ROOT, read, RATE


def measure(data):
    samples = read(data)
    power = (abs(np.fft.rfft(samples, axis=0)) ** 2).sum(axis=1)
    frequencies = np.fft.rfftfreq(len(samples), 1 / RATE)
    total = float(power.sum())
    rms = float(np.sqrt(np.mean(samples ** 2)))
    steps = abs(np.diff(samples, axis=0))
    seam = float(np.max(abs(samples[-1] - samples[0])))
    return {"sha256": hashlib.sha256(data).hexdigest(), "duration_seconds": len(samples) / RATE,
            "channels": samples.shape[1], "rms": rms, "rms_dbfs": float(20 * np.log10(rms)),
            "peak": float(np.max(abs(samples))), "dc": float(np.max(abs(samples.mean(axis=0)))),
            "centroid_hz": float((power * frequencies).sum() / total),
            "bands_energy_fraction": {str(low) + "-" + str(high): float(power[(frequencies >= low) & (frequencies < high)].sum() / total)
                                       for low, high in [(0, 60), (60, 150), (150, 350), (350, 750), (750, 2000), (2000, 11025)]},
            "loop_boundary_step": seam, "ordinary_step_p99": float(np.quantile(steps, .99)),
            "endpoints_zero": bool(np.all(samples[[0, -1]] == 0))}


def compare(base):
    result = {"source_basis": base, "assets": {}, "checks": {},
              "limits": "PCM signal checks and real mixer captures are separate; subjective listening on target hardware remains open."}
    for name in NAMES:
        old = subprocess.check_output(["git", "show", base + ":audio/assets/" + name + ".wav"], cwd=ROOT)
        new = (ROOT / "audio/assets" / (name + ".wav")).read_bytes()
        before, after = measure(old), measure(new)
        row = {"before": before, "after": after, "rms_change_db": after["rms_dbfs"] - before["rms_dbfs"]}
        result["assets"][name] = row
        result["checks"][name + ": bounded level"] = .0005 < after["rms"] < .12 and after["peak"] < .401 and after["dc"] < .005
        result["checks"][name + ": preserved format"] = before["channels"] == after["channels"] and before["duration_seconds"] == after["duration_seconds"]
        if name == "underwater_loop":
            result["checks"]["loop: no seam outlier"] = after["loop_boundary_step"] < after["ordinary_step_p99"] * 2
            result["checks"]["loop: quieter bed"] = -14 < row["rms_change_db"] < -7
            result["checks"]["loop: less sub-60 Hz rumble"] = after["bands_energy_fraction"]["0-60"] < before["bands_energy_fraction"]["0-60"] * .25
        else:
            result["checks"][name + ": smooth cue endpoints"] = after["endpoints_zero"]
            result["checks"][name + ": quieter cue"] = row["rms_change_db"] < -2
    result["passed"] = all(result["checks"].values())
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-ref", default=BASE)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = compare(args.baseline_ref)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"passed": result["passed"], "failed_checks": [key for key, passed in result["checks"].items() if not passed],
                      "rms_change_db": {key: round(row["rms_change_db"], 2) for key, row in result["assets"].items()}}))
    raise SystemExit(0 if result["passed"] else 1)
