#!/usr/bin/env python3
"""Capture actual Godot rendering and frame distributions with isolated saves."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--renderer", choices=["forward_plus", "gl_compatibility"], default="forward_plus")
    parser.add_argument("--cases", nargs="+", choices=["world", "assets", "species", "cluster", "creature", "water", "hydrology", "planet_lab", "large_planet", "galaxy", "galaxy_visit", "underwater"], default=["world", "assets", "species", "cluster", "creature", "water", "hydrology"])
    parser.add_argument("--seeds", nargs="+", type=int, default=[15838, 23757])
    parser.add_argument("--size", nargs=2, type=int, default=[1280, 720], metavar=("WIDTH", "HEIGHT"))
    parser.add_argument("--frames", type=int, default=240)
    parser.add_argument("--warmup", type=int, default=30)
    parser.add_argument("--fast-setup", action="store_true", help="Suppress rendering during initial world setup; setup times are then not gameplay frame times")
    args = parser.parse_args()
    if args.frames < 4 or args.warmup < 4 or min(args.size) < 180:
        parser.error("Use at least 4 measured/warmup frames and a resolution of at least 180 pixels per side.")
    with validation_editor(args.godot) as editor:
        return capture(args, str(editor))


def capture(args, godot):
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([godot, "--version"], text=True).strip()
    if not version.startswith("4.6.3."):
        sys.exit(f"Expected Godot 4.6.3, got {version}")
    summary = {"godot": version, "captures": [], "passed": True}
    try:
        for seed in args.seeds:
            for case in args.cases:
                directory = output / f"{case}_{seed}"
                directory.mkdir(parents=True, exist_ok=True)
                config = {"output": str(directory), "seed": seed, "case": case,
                          "width": args.size[0], "height": args.size[1], "frames": args.frames,
                          "warmup": args.warmup, "fast_setup": args.fast_setup}
                with tempfile.TemporaryDirectory(prefix="voxelverse-render-") as temporary:
                    root = Path(temporary)
                    config_path = root / "capture_config.json"
                    config_path.write_text(json.dumps(config), encoding="utf-8")
                    command = [godot, "--path", str(project), "--rendering-method", args.renderer,
                               "--audio-driver", "Dummy", "--script", "res://tools/capture_environment.gd",
                               "--", str(config_path)]
                    try:
                        process = subprocess.run(command, env=isolated_env(root / "userdata"),
                                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                                 text=True, encoding="utf-8", errors="replace", timeout=900)
                        log, code = process.stdout, process.returncode
                    except subprocess.TimeoutExpired as error:
                        log = (error.stdout or b"").decode(errors="replace") + "\nERROR: render capture timed out\n"
                        code = 124
                (directory / "engine.log").write_text(log, encoding="utf-8")
                for line in log.splitlines():
                    if line.startswith(("REVIEW_PREVIEW ", "HYDROLOGY_RENDER ", "PLANET_TRANSITION_REVIEW ")):
                        print(line, flush=True)
                if code != 0 or ERROR.search(log):
                    # Large streaming inventories can push the real failure out
                    # of the retained log tail. Keep the acceptance reason visible.
                    try:
                        failed = json.loads((directory / "capture.json").read_text(encoding="utf-8"))
                        diagnostic = {key: failed.get(key) for key in
                                      ("case", "seed", "renderer", "software_renderer", "setup_ms",
                                       "setup_limit_seconds", "passed", "failures")}
                        streaming = failed.get("streaming_state", {})
                        diagnostic["streaming"] = {key: streaming.get(key) for key in
                                                   ("world_initialized", "pending_chunks", "horizon_ready",
                                                    "forest_ready", "player_dead")}
                        print("CAPTURE_FAILURE " + json.dumps(diagnostic), file=sys.stderr, flush=True)
                    except (OSError, ValueError, AttributeError):
                        pass
                    print(log[-12000:], file=sys.stderr)
                    raise RuntimeError(f"Render capture failed: {case}/{seed}")
                result = json.loads((directory / "capture.json").read_text(encoding="utf-8"))
                if not result["passed"] or result["renderer"] != args.renderer:
                    raise RuntimeError(f"Capture used an unexpected renderer or failed: {case}/{seed}")
                summary["captures"].append({"directory": directory.name, **result})
                print(json.dumps({"case": case, "seed": seed, "adapter": result["adapter"],
                                  "software_renderer": result["software_renderer"],
                                  "setup_ms": result.get("setup_ms"),
                                  "setup_limit_seconds": result.get("setup_limit_seconds"),
                                  "samples": len(result["samples"]), "passed": True}), flush=True)
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        summary["passed"] = False
        summary["error"] = str(error)
        print(str(error), file=sys.stderr)
    (output / "results.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
