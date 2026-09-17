#!/usr/bin/env python3
"""ARCH-02: profile the spherical campaign or isolated save-scaling fixtures."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import sys
import tempfile
import time

from validate_godot import ERROR
from validation_support import isolated_env, validation_editor
from performance_developed_report import validate_developed, write_developed_summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, help="New report directory outside the project; defaults to a unique temporary directory")
    parser.add_argument("--renderer", choices=["headless", "gl_compatibility", "forward_plus"], default="headless")
    parser.add_argument("--seed", type=int, default=15838)
    parser.add_argument("--cycles", type=int, help="Developed: 1–3 complete chains (default 1); route/saves/startup: 2–10 (default 2)")
    parser.add_argument("--mode", choices=["route", "saves", "developed", "startup"], default="route")
    parser.add_argument("--production", choices=["milk", "eggs"], default="milk", help="Developed profile's real production chain")
    parser.add_argument("--compare", type=Path, help="Compare a developed report directory with the same recipe/hardware")
    parser.add_argument("--replay", type=Path, help="Prior route/startup report directory: reuse its exact initial save and immutable region blobs")
    parser.add_argument("--walk-seconds", type=float, default=600.0, help="Outward walking with heading changes, followed by a separate physical return; 10 minutes outward by default")
    parser.add_argument("--frame-cap", type=int, default=60)
    parser.add_argument("--settle-frames", type=int, default=60)
    parser.add_argument("--stage-timeout", type=float, default=120.0)
    parser.add_argument("--size", type=int, nargs=2, default=[1920, 1080])
    args = parser.parse_args()
    if args.cycles is None:
        args.cycles = 1 if args.mode == "developed" else 2
    if args.mode == "developed" and not 1 <= args.cycles <= 3:
        parser.error("Developed profiles require 1–3 complete cycles")
    if args.mode != "developed" and not (2 <= args.cycles <= 10 and 4 <= args.walk_seconds <= 600):
        parser.error("Use 2–10 cycles and 4–600 walk seconds")
    if args.mode == "developed" and (args.seed != 15838 or args.replay):
        parser.error("Developed profiles use the existing seed 15838 scenario; --replay belongs to route mode")
    if args.compare and args.mode != "developed":
        parser.error("--compare requires --mode developed")
    if not 1 <= args.seed <= 2147483647:
        parser.error("Seed must be between 1 and 2147483647")
    if not (1 <= args.frame_cap <= 240 and 30 <= args.settle_frames <= 600 and 10 <= args.stage_timeout <= 300):
        parser.error("Use 1–240 FPS cap, 30–600 settle frames and 10–300 seconds per stage")
    if min(args.size) < 180:
        parser.error("Resolution must be at least 180 pixels per side")
    project = args.project.expanduser().resolve()
    output = args.output.expanduser().resolve() if args.output else Path(tempfile.mkdtemp(prefix="voxelverse-performance-"))
    if output.is_relative_to(project):
        parser.error("Performance reports must be outside the source project")
    if any((output / name).exists() for name in ("performance.json", "capture.json", "engine.log", "frames.csv", "process-memory.json", "fixture", "summary.md", "startup-fixture.json", "startup-progress.json", "prepare.log")) or list(output.glob("cycle_*-*.json")):
        parser.error("Choose a new output directory to preserve earlier measurements")
    output.mkdir(parents=True, exist_ok=True)
    recipe = {"protocol": 2, "mode": args.mode, "seed": args.seed, "cycles": args.cycles,
              "walk_seconds": args.walk_seconds, "frame_cap": args.frame_cap, "settle_frames": args.settle_frames,
              "stage_timeout_seconds": args.stage_timeout, "resolution": args.size, "renderer": args.renderer}
    if args.mode == "route":
        recipe["steering"] = "local_collision_v1"
    if args.mode == "developed":
        recipe = {"protocol": 3, "mode": "developed", "seed": args.seed, "cycles": args.cycles,
                  "production": args.production, "frame_cap": args.frame_cap,
                  "resolution": args.size, "renderer": args.renderer,
                  "scenario": "spherical_gameplay_probe", "scenario_simulation_speed": 4.0,
                  "far_debt_frame_cap": 2, "far_production_seconds": 5.0}
    source = source_version(project)
    if args.mode == "startup":
        from performance_startup_report import run_startup
        return run_startup(args, project, output, source, lambda: source_version(project))
    config = {"output": str(output), "recipe": recipe, "source": source}
    print(f"Performance output: {output}", flush=True)
    summary = {"passed": False, "recipe": recipe, "host": {"system": platform.system(),
               "machine": platform.machine(), "processor": platform.processor()}, "target_pc_acceptance": False}
    try:
        with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="voxelverse-performance-user-") as temporary:
            root = Path(temporary)
            if args.replay:
                if args.mode != "route":
                    raise ValueError("Replay is only available for the spherical route")
                replay = args.replay.expanduser().resolve()
                capture = json.loads((replay / "capture.json").read_text(encoding="utf-8"))
                if capture["recipe"]["seed"] != args.seed:
                    raise ValueError("Replay requires the original --seed")
                config["replay_initial_save"] = capture["initial_save"]
                config["replay_slot"] = capture["fixture_slot"]
                shutil.copytree(replay / "fixture", root / "userdata")
            config_path = root / "config.json"
            config_path.write_text(json.dumps(config), encoding="utf-8")
            version = subprocess.check_output([str(editor), "--version"], text=True).strip()
            if not version.startswith("4.6.3."):
                raise RuntimeError(f"Expected Godot 4.6.3, got {version}")
            # Include leaked object classes in failure logs, matching the other
            # Godot validation runners; an exit-code-only report cannot diagnose them.
            command = [str(editor), "--verbose", "--path", str(project), "--audio-driver", "Dummy"]
            command += ["--headless"] if args.renderer == "headless" else ["--rendering-method", args.renderer]
            script = {"route": "performance_route_probe.gd", "saves": "performance_save_probe.gd",
                      "developed": "performance_developed_probe.gd"}[args.mode]
            command += ["--script", "res://tools/" + script, "--", str(config_path)]
            if args.mode == "developed":
                command[-1:] = ["--performance-config", str(config_path)]
            timeout = args.cycles * (4 * args.stage_timeout + 3 * args.walk_seconds + 2 * args.settle_frames / args.frame_cap) + 60
            if args.mode == "developed":
                timeout = args.cycles * 1000 + 60
            log_path = output / "engine.log"
            with log_path.open("w", encoding="utf-8") as log_file:
                process = subprocess.Popen(command, env=isolated_env(root / "userdata"),
                                           stdout=log_file, stderr=subprocess.STDOUT,
                                           start_new_session=(os.name != "nt"),
                                           creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0)
                deadline = time.monotonic() + timeout
                while process.poll() is None and time.monotonic() < deadline:
                    try:
                        process.wait(timeout=1)
                    except subprocess.TimeoutExpired:
                        pass
                code = process.poll()
                if code is None:
                    if os.name == "nt":
                        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                       stdout=log_file, stderr=subprocess.STDOUT, check=False)
                    else:
                        os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                    log_file.write("\nERROR: performance probe timed out\n")
                    code = 124
            # Keep the original slots, immutable history and region blobs for
            # investigation/replay, even when an actual route is blocked.
            shutil.copytree(root / "userdata", output / "fixture")
            log = log_path.read_text(encoding="utf-8", errors="replace")
            if (output / "capture.json").is_file():
                summary.update(json.loads((output / "capture.json").read_text(encoding="utf-8")))
                memory = [{key: s.get(key) for key in ("cycle", "stage", "tick_us", "bodies", "changed_regions_total", "rss_bytes", "peak_rss_bytes")}
                          for s in summary.get("snapshots", summary.get("measurements", []))]
                (output / "process-memory.json").write_text(json.dumps(memory, indent=2) + "\n", encoding="utf-8")
                summary["process_rss_peak_bytes"] = max((s["peak_rss_bytes"] or 0 for s in memory), default=0) or None
            if code != 0 or ERROR.search(log):
                summary["passed"] = False
                print(log[-12000:], file=sys.stderr)
                raise RuntimeError(f"Performance probe failed (exit {code}); see engine.log")
            capture = json.loads((output / "capture.json").read_text(encoding="utf-8"))
            if not capture["passed"] or capture["recipe"] != recipe:
                raise RuntimeError("The probe did not complete the requested measurement protocol")
            if not Path(capture["user_data_dir"]).resolve().is_relative_to(root / "userdata"):
                raise RuntimeError("Godot did not use the isolated user directory")
            if args.renderer != "headless" and capture["renderer"] != args.renderer:
                raise RuntimeError("Unexpected rendering method")
            if args.mode == "route" and args.renderer != "headless" and not any((s.get("draw_calls") or {}).get("max", 0) > 0 for s in capture["segments"]):
                raise RuntimeError("Rendered profiling produced no draw calls")
            if args.mode == "developed":
                capture["process_reports"] = validate_developed(output, capture, root / "userdata")
            summary.update(capture)
            summary["passed"] = True
            if args.mode == "developed":
                write_developed_summary(output, summary, args.compare)
    except (OSError, ValueError, TypeError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        summary["passed"] = False
        summary["error"] = str(error)
        print(str(error), file=sys.stderr)
    if args.mode == "developed":
        memory = [dict({key: s.get(key) for key in ("cycle", "stage", "tick_us", "rss_bytes", "peak_rss_bytes")},
                       process=report.get("process", "main"))
                  for report in [summary, *summary.get("process_reports", [])]
                  for s in report.get("snapshots", [])]
        (output / "process-memory.json").write_text(json.dumps(memory, indent=2) + "\n", encoding="utf-8")
        summary["process_rss_peak_bytes"] = max((s["peak_rss_bytes"] or 0 for s in memory), default=0) or None
        summary["process_rss_note"] = "Largest single-process peak; not combined parent/child RAM. Parent remains allocated during cold child checks."
    (output / "performance.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": summary["passed"], "output": str(output), "observations": summary.get("observations", {})}))
    return 0 if summary["passed"] else 1


def source_version(project):
    try:
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=project, text=True).strip()
        status = subprocess.check_output(["git", "status", "--porcelain"], cwd=project, text=True).strip()
        tree = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=project, text=True).strip()
        paths = subprocess.check_output(["git", "diff", "--name-only", "-z", "HEAD"], cwd=project).split(b"\0")
        paths += subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard", "-z"], cwd=project).split(b"\0")
        hashes = {}
        for raw_path in paths:
            if raw_path:
                relative = os.fsdecode(raw_path)
                path = project / relative
                hashes[relative] = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
        return {"commit": commit, "tree": tree, "dirty": bool(status), "changes": status.splitlines(), "changed_file_sha256": hashes}
    except (OSError, subprocess.SubprocessError):
        return {"commit": None, "dirty": None, "note": "No git metadata available"}



if __name__ == "__main__":
    sys.exit(main())
