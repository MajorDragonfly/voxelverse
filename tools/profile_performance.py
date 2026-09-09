#!/usr/bin/env python3
"""Measure a scripted streaming route and repeated real world/menu transitions."""
import argparse
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile

from validate_godot import ERROR
from validation_support import isolated_env, validation_editor


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, help="New report directory outside the project; defaults to a unique temporary directory")
    parser.add_argument("--renderer", choices=["headless", "gl_compatibility", "forward_plus"], default="headless")
    parser.add_argument("--seed", type=int, default=15838)
    parser.add_argument("--cycles", type=int, default=3)
    parser.add_argument("--distance", type=float, default=192.0, help="One-way route in metres; exceeds the normal loaded neighbourhood")
    parser.add_argument("--step", type=float, default=1.0, help="Scripted metres per process frame, independent of wall-clock frame duration")
    parser.add_argument("--frame-cap", type=int, default=60)
    parser.add_argument("--settle-frames", type=int, default=60)
    parser.add_argument("--stage-timeout", type=float, default=120.0)
    parser.add_argument("--size", type=int, nargs=2, default=[1280, 720])
    args = parser.parse_args()
    if not (2 <= args.cycles <= 10 and 160 <= args.distance <= 1024 and 0.1 <= args.step <= 4):
        parser.error("Use 2–10 cycles, 160–1024 metres and 0.1–4 metres per frame")
    if not (1 <= args.frame_cap <= 240 and 30 <= args.settle_frames <= 600 and 10 <= args.stage_timeout <= 300):
        parser.error("Use 1–240 FPS cap, 30–600 settle frames and 10–300 seconds per stage")
    if min(args.size) < 180:
        parser.error("Resolution must be at least 180 pixels per side")
    project = args.project.expanduser().resolve()
    output = args.output.expanduser().resolve() if args.output else Path(tempfile.mkdtemp(prefix="voxelverse-performance-"))
    if output.is_relative_to(project):
        parser.error("Performance reports must be outside the source project")
    if any((output / name).exists() for name in ("performance.json", "capture.json", "engine.log")):
        parser.error("Choose a new output directory to preserve earlier measurements")
    output.mkdir(parents=True, exist_ok=True)
    recipe = {"protocol": 1, "seed": args.seed, "cycles": args.cycles, "distance_m": args.distance,
              "step_m": args.step, "frame_cap": args.frame_cap, "settle_frames": args.settle_frames,
              "stage_timeout_seconds": args.stage_timeout, "resolution": args.size, "renderer": args.renderer}
    config = {"output": str(output), "recipe": recipe}
    print(f"Performance output: {output}", flush=True)
    summary = {"passed": False, "recipe": recipe, "host": {"system": platform.system(),
               "machine": platform.machine(), "processor": platform.processor()}, "target_pc_acceptance": False}
    try:
        with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="voxelverse-performance-user-") as temporary:
            root = Path(temporary)
            config_path = root / "config.json"
            config_path.write_text(json.dumps(config), encoding="utf-8")
            version = subprocess.check_output([str(editor), "--version"], text=True).strip()
            if not version.startswith("4.6.3."):
                raise RuntimeError(f"Expected Godot 4.6.3, got {version}")
            command = [str(editor), "--path", str(project), "--audio-driver", "Dummy"]
            command += ["--headless"] if args.renderer == "headless" else ["--rendering-method", args.renderer]
            command += ["--script", "res://tools/performance_route_probe.gd", "--", str(config_path)]
            timeout = args.cycles * (4 * args.stage_timeout + 2 * args.distance / args.step / args.frame_cap) + 60
            log_path = output / "engine.log"
            with log_path.open("w", encoding="utf-8") as log_file:
                process = subprocess.Popen(command, env=isolated_env(root / "userdata"),
                                           stdout=log_file, stderr=subprocess.STDOUT)
                try:
                    code = process.wait(timeout=timeout)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                    log_file.write("\nERROR: performance probe timed out\n")
                    code = 124
            log = log_path.read_text(encoding="utf-8", errors="replace")
            if code != 0 or ERROR.search(log):
                print(log[-12000:], file=sys.stderr)
                raise RuntimeError(f"Performance probe failed (exit {code}); see engine.log")
            capture = json.loads((output / "capture.json").read_text(encoding="utf-8"))
            if not capture["passed"] or capture["recipe"] != recipe:
                raise RuntimeError("The probe did not complete the requested measurement protocol")
            if not Path(capture["user_data_dir"]).resolve().is_relative_to(root / "userdata"):
                raise RuntimeError("Godot did not use the isolated user directory")
            if args.renderer != "headless" and capture["renderer"] != args.renderer:
                raise RuntimeError("Unexpected rendering method")
            if args.renderer != "headless" and not any(s["draw_calls"].get("max", 0) > 0 for s in capture["segments"]):
                raise RuntimeError("Rendered profiling produced no draw calls")
            summary.update(capture)
            summary["passed"] = True
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        summary["error"] = str(error)
        print(str(error), file=sys.stderr)
    (output / "performance.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": summary["passed"], "output": str(output), "observations": summary.get("observations", {})}))
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
