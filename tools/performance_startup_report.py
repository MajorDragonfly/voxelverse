"""PERF-COLD-START: repeat one frozen slot through the real SessionFlow."""
import json
import math
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import tempfile
import time

from validate_godot import ERROR
from validation_support import isolated_env, validation_editor

PHASES = ("prepare_state", "state_settle", "threaded_load", "scene_instantiation",
          "scene_ready", "start_terrain", "arrival")


def read_progress(output):
    """A killed process may leave an incomplete write; its flushed log is fallback."""
    try:
        return json.loads((output / "startup-progress.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        try:
            lines = (output / "engine.log").read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            return {}
        for line in reversed(lines):
            if line.startswith("STARTUP_PHASE "):
                try:
                    return json.loads(line[len("STARTUP_PHASE "):])
                except ValueError:
                    continue
        return {}


def run_process(command, userdata, output, timeout, preparing=False):
    log_path = output / ("prepare.log" if preparing else "engine.log")
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, env=isolated_env(userdata), stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=os.name != "nt",
                                   creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0)
        phase = (-1, "fixture_preparation" if preparing else "bootstrap", "loading")
        deadline = time.monotonic() + timeout
        while process.poll() is None:
            progress = {} if preparing else read_progress(output)
            trace = progress.get("trace", {})
            current = (progress.get("cycle", -1), trace.get("last_phase", phase[1]), trace.get("status", "loading"))
            if current != phase:
                phase = current
                deadline = time.monotonic() + timeout
            if time.monotonic() >= deadline:
                if os.name == "nt":
                    subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                   stdout=log, stderr=subprocess.STDOUT, check=False)
                else:
                    os.killpg(process.pid, signal.SIGKILL)
                process.wait()
                raise RuntimeError(f"Startup timeout in phase {phase[1]} (cycle {phase[0]}); see {log_path.name}")
            try:
                process.wait(timeout=0.25)
            except subprocess.TimeoutExpired:
                pass
    text = log_path.read_text(encoding="utf-8", errors="replace")
    if process.returncode != 0 or ERROR.search(text):
        progress = read_progress(output)
        last = progress.get("trace", {}).get("last_phase", phase[1])
        raise RuntimeError(f"Startup process failed in phase {last} (exit {process.returncode}); see {log_path.name}")


def validate_capture(capture, recipe, source, userdata, fixture):
    if not capture.get("passed") or capture.get("failures") or capture.get("recipe") != recipe or capture.get("source") != source:
        raise ValueError("Incomplete or mismatched startup capture")
    if not Path(capture["user_data_dir"]).resolve().is_relative_to(userdata.resolve()):
        raise ValueError("Startup process escaped its isolated user directory")
    if capture.get("renderer") != recipe["renderer"]:
        raise ValueError("Unexpected startup renderer")
    if capture.get("world_starts") != recipe["cycles"] or capture.get("save_attempts") != 0:
        raise ValueError("Startup measurement rebuilt an extra world or attempted a save")
    if any(capture.get(key) != fixture["sha256"] for key in ("initial_save_sha256", "final_save_sha256")):
        raise ValueError("Startup measurement changed its frozen input slot")
    loads = capture.get("loads", [])
    if len(loads) != recipe["cycles"]:
        raise ValueError("Missing startup repetitions")
    identity = None
    for cycle, load in enumerate(loads):
        trace = load["trace"]
        if load["cycle"] != cycle or load["cache_state"] != ("cold_process" if cycle == 0 else "warm_process"):
            raise ValueError("Cold/warm startup order is incorrect")
        if trace["status"] != "ready" or trace["last_phase"] != "arrival" or trace.get("error"):
            raise ValueError("Startup trace did not reach readiness")
        context = trace["context"]
        current = (context.get("scene"), context.get("seed"), context.get("body_id"))
        if current[0] != "res://main/spherical_campaign.tscn" or current[1] != recipe["seed"] or not current[2]:
            raise ValueError("Startup used a different world or seed")
        if identity is not None and current != identity:
            raise ValueError("Warm startup changed the measured body")
        identity = current
        segments = trace["segments"]
        if [segment["phase"] for segment in segments] != list(PHASES):
            raise ValueError("Startup timing phases are missing, duplicated or out of order")
        total = 0.0
        for segment in segments:
            duration = segment["duration_ms"]
            start = segment["start_ms"]
            if (not segment["completed"] or not math.isfinite(duration) or duration < 0
                    or not math.isfinite(start) or abs(start - total) > 0.01):
                raise ValueError("Invalid or overlapping startup timing interval")
            total += duration
        if not math.isfinite(trace["total_ms"]) or abs(total - trace["total_ms"]) > 0.01:
            raise ValueError("Startup phases do not cover the measured total")


def write_summary(output, capture):
    lines = ["# Campaign startup measurements", "",
             f"Source: `{capture['source']['commit']}`; tree: `{capture['source'].get('tree')}`; dirty: `{capture['source']['dirty']}`.", "",
             f"Godot {capture['godot']}; {capture['renderer']}; CPU: {capture['cpu']}.", "",
             "Cold = first world load in a fresh Godot process. Warm = subsequent loads in that same process. "
             "OS file caches are not cleared; no target-PC or disk-cold acceptance is implied. "
             "Every load uses the same frozen slot; measurement attempts no saves and builds one world per load.", "",
             "Times are consecutive wall-clock intervals, including scheduling and diagnostic boundary writes. "
             "scene_instantiation covers change_scene_to_packed; scene_ready covers deferred scene attachment/_ready. "
             "start_terrain ends when the existing world_initialized collision gate is ready; it does not certify all distant scenery.", "",
             "| Phase | Cold ms | Warm ms (each repetition) |", "|---|---:|---:|"]
    loads = capture["loads"]
    for phase in PHASES:
        values = [next(s["duration_ms"] for s in load["trace"]["segments"] if s["phase"] == phase) for load in loads]
        lines.append(f"| {phase} | {values[0]:.2f} | {', '.join(f'{v:.2f}' for v in values[1:])} |")
    totals = [load["trace"]["total_ms"] for load in loads]
    lines += [f"| Total | {totals[0]:.2f} | {', '.join(f'{v:.2f}' for v in totals[1:])} |", "",
              f"Frozen slot SHA-256: `{capture['initial_save_sha256']}` (unchanged).", "",
              "Raw traces: capture.json. Last progress, also retained on failure: startup-progress.json and engine.log. "
              "Individual repetitions are observations, not statistical performance claims.", ""]
    (output / "summary.md").write_text("\n".join(lines), encoding="utf-8")


def run_startup(args, project, output, source, source_reader):
    recipe = {"protocol": 1, "mode": "startup", "seed": args.seed, "cycles": args.cycles,
              "frame_cap": args.frame_cap, "resolution": args.size, "renderer": args.renderer,
              "stage_timeout_seconds": args.stage_timeout}
    summary = {"passed": False, "source": source, "recipe": recipe, "target_pc_acceptance": False,
               "host": {"system": platform.system(), "machine": platform.machine(), "processor": platform.processor()}}
    print(f"Startup profile output: {output}", flush=True)
    try:
        with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="voxelverse-startup-") as temporary:
            work = Path(temporary)
            userdata = work / "userdata"
            config = {"output": str(output), "source": source, "recipe": recipe, "operation": "prepare"}
            version = subprocess.check_output([str(editor), "--version"], text=True).strip()
            if not version.startswith("4.6.3."):
                raise ValueError(f"Expected Godot 4.6.3, got {version}")
            config_path = work / "config.json"
            command = [str(editor), "--verbose", "--path", str(project), "--audio-driver", "Dummy"]
            command += ["--headless"] if args.renderer == "headless" else ["--rendering-method", args.renderer]
            command += ["--script", "res://tools/performance_startup_probe.gd", "--", str(config_path)]
            try:
                if args.replay:
                    replay = args.replay.expanduser().resolve()
                    previous = json.loads((replay / "performance.json").read_text(encoding="utf-8"))
                    if not previous.get("passed") or previous["recipe"]["mode"] != "startup" or previous["recipe"]["seed"] != args.seed:
                        raise ValueError("Startup replay requires a passed startup report with the same seed")
                    fixture = json.loads((replay / "startup-fixture.json").read_text(encoding="utf-8"))
                    shutil.copytree(replay / "fixture", userdata)
                    (output / "startup-fixture.json").write_text(json.dumps(fixture), encoding="utf-8")
                else:
                    config_path.write_text(json.dumps(config), encoding="utf-8")
                    run_process(command, userdata, output, args.stage_timeout, preparing=True)
                    fixture = json.loads((output / "startup-fixture.json").read_text(encoding="utf-8"))
                config.update(operation="measure", fixture=fixture)
                config_path.write_text(json.dumps(config), encoding="utf-8")
                run_process(command, userdata, output, args.stage_timeout)
                capture = json.loads((output / "capture.json").read_text(encoding="utf-8"))
                validate_capture(capture, recipe, source, userdata, fixture)
                if source_reader() != source:
                    raise ValueError("Project source changed during startup measurement")
                summary.update(capture)
                summary["source_unchanged"] = True if source.get("commit") else None
                write_summary(output, summary)
            finally:
                if userdata.exists(): shutil.copytree(userdata, output / "fixture")
    except (OSError, ValueError, TypeError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        summary["passed"] = False
        summary["error"] = str(error)
        summary["last_progress"] = read_progress(output)
        print(str(error), flush=True)
    (output / "performance.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": summary["passed"], "output": str(output), "error": summary.get("error")}))
    return 0 if summary["passed"] else 1
