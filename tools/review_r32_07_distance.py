#!/usr/bin/env python3
"""Serial native comparison of the R32 base and a committed scenery fix.

Hold the centrally coordinated host flock around this whole command. Output
must be outside both checkouts. Address seeks and slow-worker video are
diagnostics, not a physical walking or target-PC performance claim.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import time

from profile_performance import source_version
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def git(project, *args):
    return subprocess.check_output(["git", *args], cwd=project, text=True).strip()


def run_capture(project, editor, renderer, output, env, replay_fixture=None):
    output.mkdir(parents=True)
    source = source_version(project)
    command = [str(editor), "--verbose", "--path", str(project), "--audio-driver", "Dummy",
               "--rendering-method", renderer, "--script", "res://tools/review_r32_07_capture.gd",
               "--", str(output)]
    if replay_fixture:
        command.append(str(replay_fixture))
    metadata = {"source": source, "command": command, "display": env.get("DISPLAY"),
                "capture_sha256": hashlib.sha256((project / "tools/review_r32_07_capture.gd").read_bytes()).hexdigest(),
                "load_before": os.getloadavg(), "target_pc_acceptance": False}
    (output / "invocation.json").write_text(json.dumps(metadata, indent=2) + "\n")
    stopped = threading.Event()
    def monitor():
        with (output / "host-load.jsonl").open("w") as logfile:
            while not stopped.is_set():
                godot = []
                for path in Path("/proc").glob("[0-9]*/comm"):
                    try:
                        name = path.read_text().strip()
                        if "godot" in name.lower():
                            godot.append({"pid": int(path.parent.name), "name": name})
                    except (OSError, ValueError):
                        pass
                pressures = {}
                for label in ["cpu.pressure", "memory.pressure", "cpu.stat", "memory.current"]:
                    path = Path("/sys/fs/cgroup") / label
                    if path.exists():
                        pressures[label] = path.read_text()
                logfile.write(json.dumps({"unix_seconds": time.time(), "load": os.getloadavg(),
                                          "godot": godot, "cgroup": pressures}) + "\n")
                logfile.flush()
                stopped.wait(0.5)
    observer = threading.Thread(target=monitor, daemon=True)
    observer.start()
    try:
        with (output / "engine.log").open("w") as log:
            try:
                run = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, env=env, timeout=600)
                metadata["exit_code"] = run.returncode
            except subprocess.TimeoutExpired:
                metadata["timeout_seconds"] = 600
                metadata["exit_code"] = 124
    finally:
        stopped.set()
        observer.join()
    metadata["load_after"] = os.getloadavg()
    metadata["source_unchanged"] = source_version(project) == source
    log_text = (output / "engine.log").read_text()
    metadata["log_sha256"] = hashlib.sha256((output / "engine.log").read_bytes()).hexdigest()
    metadata["strict_log_passed"] = not ERROR.search(log_text)
    observations = [json.loads(line) for line in (output / "host-load.jsonl").read_text().splitlines()]
    metadata["multiple_godot_observations"] = sum(len(row["godot"]) > 1 for row in observations)
    metadata["performance_isolated"] = metadata["multiple_godot_observations"] == 0
    report_path = output / "capture.json"
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    metadata["passed"] = (metadata["exit_code"] == 0 and metadata["strict_log_passed"]
                           and metadata["source_unchanged"] and report.get("passed", False)
                           and len(list(output.glob("motion-*.png"))) == 25
                           and len(report.get("samples", [])) == 11)
    (output / "invocation.json").write_text(json.dumps(metadata, indent=2) + "\n")
    if report:
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-framerate", "6", "-i",
                        str(output / "motion-%03d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
                        str(output / "held-out-return.mp4")], check=True)
    print(json.dumps({"output": str(output), **metadata}), flush=True)
    return metadata, report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--baseline-ref", required=True)
    parser.add_argument("--renderer", choices=["gl_compatibility", "forward_plus"], required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    if git(project, "status", "--porcelain"):
        raise RuntimeError("Commit the candidate before capturing")
    output = args.output.resolve()
    if output.is_relative_to(project):
        raise RuntimeError("Keep raw comparison outputs outside the source checkout")
    output.mkdir(parents=True, exist_ok=False)
    baseline = git(project, "rev-parse", args.baseline_ref + "^{commit}")
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="r32-07-before-") as tmp:
        checkout = Path(tmp) / "source"
        git(project, "worktree", "add", "--detach", str(checkout), baseline)
        try:
            # Exact same instrumentation; no source runtime changes on the base.
            measurement = project / "tools/review_r32_07_capture.gd"
            shutil.copy2(measurement, checkout / "tools/review_r32_07_capture.gd")
            # Same resources: reuse this checkout's successfully imported assets.
            shutil.copytree(project / ".godot", checkout / ".godot")
            with tempfile.TemporaryDirectory(prefix="r32-07-userdata-") as userdata:
                env = isolated_env(Path(userdata))
                before_meta, before = run_capture(checkout, editor, args.renderer, output / "before", env)
            with tempfile.TemporaryDirectory(prefix="r32-07-userdata-") as userdata:
                env = isolated_env(Path(userdata))
                after_meta, after = run_capture(project, editor, args.renderer, output / "after", env,
                                               output / "before/fixture.json")
        finally:
            git(project, "worktree", "remove", "--force", str(checkout))
    conditions = []
    for a, b in zip(before.get("samples", []), after.get("samples", [])):
        # Random campaign UUIDs differ, all geometric addresses and settings must match.
        conditions.append({"label": a["label"], "equal": all(a[key] == b[key] for key in
                           ["clock", "sun", "camera_position", "camera_forward", "graphics", "origin", "weather"])})
    comparison = {"before": before_meta, "after": after_meta, "conditions": conditions,
                  "same_initial_save": before.get("initial_save_sha256") == after.get("initial_save_sha256"),
                  "same_instrumentation": before_meta["capture_sha256"] == after_meta["capture_sha256"],
                  "collision_equal": before.get("geometry", {}).get("collision_sha256") == after.get("geometry", {}).get("collision_sha256"),
                  "target_pc_acceptance": False, "physical_walking_acceptance": False,
                  "passed": before_meta["passed"] and after_meta["passed"] and len(conditions) == 11
                            and all(c["equal"] for c in conditions)
                            and before.get("initial_save_sha256") == after.get("initial_save_sha256")
                            and before_meta["capture_sha256"] == after_meta["capture_sha256"]}
    (output / "comparison.json").write_text(json.dumps(comparison, indent=2) + "\n")
    return 0 if comparison["passed"] and comparison["collision_equal"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
