#!/usr/bin/env python3
"""Compare fixed real spherical terrain meshes under the old and new shaders."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--renderer", choices=["forward_plus", "gl_compatibility"], required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--baseline", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    project = Path(__file__).resolve().parents[1]
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="ground-materials-") as userdata:
        result = subprocess.run([
            str(editor), "--path", str(project), "--rendering-method", args.renderer,
            "--audio-driver", "Dummy", "--resolution", "960x540",
            "--script", "res://tools/capture_ground_materials.gd", "--",
            str(output), str(args.baseline.resolve()),
        ], env=isolated_env(Path(userdata)), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace", timeout=1200)
    (output / "runtime.log").write_text(result.stdout, encoding="utf-8")
    if result.returncode or ERROR.search(result.stdout):
        print(result.stdout[-9000:])
        raise RuntimeError("Native ground review failed; inspect runtime.log")
    report = json.loads((output / "capture.json").read_text(encoding="utf-8"))
    samples = report["samples"]
    if not report["passed"] or report["renderer"] != args.renderer or len(samples) != 15:
        raise RuntimeError(f"Incomplete native ground review: {report}")
    if len(list(output.glob("*.png"))) != 30:
        raise RuntimeError("Missing before/after frames")
    if max(sample["mean_rgb_change"] for sample in samples) < 0.004:
        raise RuntimeError("Candidate shader did not visibly change the terrain")
    if min(sample["draw_calls"] for sample in samples) < 1:
        raise RuntimeError("Ground was not drawn in a review frame")
    print(json.dumps({"renderer": args.renderer, "views": len(samples),
                      "rgb_change": [round(sample["mean_rgb_change"], 5) for sample in samples],
                      "draw_calls": [sample["draw_calls"] for sample in samples],
                      "gpu_ms_before_after": [[round(sample["baseline_gpu_ms"], 2), round(sample["candidate_gpu_ms"], 2)] for sample in samples]}))


if __name__ == "__main__":
    main()
