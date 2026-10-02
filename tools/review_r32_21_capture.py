#!/usr/bin/env python3
"""One serialized real campaign/UI capture, isolated settings/saves and strict logs."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import time

from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--wait-slot", type=int, default=0, choices=range(61))
    parser.add_argument("--xvfb", type=Path, help="Executable for native software-GL capture")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError("Choose a new output directory")
    lock = open("/tmp/voxelverse-r32-db514e109ac6-heavy.lock", "a+")
    deadline = time.monotonic() + args.wait_slot
    while True:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except BlockingIOError:
            if time.monotonic() >= deadline:
                print("SLOT_BUSY: no Godot process started")
                return 75
            time.sleep(0.5)
    env = isolated_env(output / "isolated-user")
    env["LIBGL_ALWAYS_SOFTWARE"] = "1"
    xserver = None
    xlog = None
    start = time.time()
    project = args.project.resolve()
    # Runtime evidence stays outside the source tree; record actual source files.
    subprocess.run(["git", "ls-files", "-s"], cwd=project, stdout=(output / "source-index.txt").open("w"), check=True)
    report = {"host": os.uname().nodename, "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=project, text=True).strip(),
              "source_tree": subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=project, text=True).strip(),
              "started_unix": start, "load_before": os.getloadavg(), "target_pc_acceptance": False,
              "scope": "Functional real spherical campaign/UI evidence; Linux software renderer, no 60-FPS acceptance."}
    try:
        if args.xvfb:
            xvfb = args.xvfb.resolve()
            prefix = xvfb.parents[2]
            libraries = [prefix / "lib/x86_64-linux-gnu", prefix / "usr/lib/x86_64-linux-gnu"]
            env["LD_LIBRARY_PATH"] = ":".join(str(path) for path in libraries if path.is_dir())
            env["DISPLAY"] = ":221"
            xlog = (output / "xvfb.log").open("w")
            xserver = subprocess.Popen([str(xvfb), ":221", "-screen", "0", "1920x1080x24", "-nolisten", "tcp", "-ac", "-noreset"], env=env, stdout=xlog, stderr=subprocess.STDOUT)
            for _ in range(30):
                if Path("/tmp/.X11-unix/X221").exists(): break
                if xserver.poll() is not None: raise RuntimeError("Xvfb failed: " + (output / "xvfb.log").read_text())
                time.sleep(0.1)
        with validation_editor(args.godot) as editor:
            command = [str(editor), "--path", str(project), "--audio-driver", "Dummy", "--max-fps", "30"]
            if args.xvfb: command += ["--rendering-method", "gl_compatibility", "--resolution", "1280x720"]
            else: command += ["--headless"]
            command += ["--script", "res://tests/r32_21_resource_area_world_test.gd", "--", "--capture-dir", str(output / "captures")]
            report["command"] = command
            report["engine"] = subprocess.check_output([str(editor), "--version"], env=env, text=True).strip()
            with (output / "world.log").open("w") as log:
                completed = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=360)
            content = (output / "world.log").read_text()
            report["exit_code"] = completed.returncode
            report["passed"] = completed.returncode == 0 and not ERROR.search(content) and "R32_21_AREA_WORLD_PASSED" in content
            if args.xvfb:
                report["images"] = [str(path.relative_to(output)) for path in sorted(output.glob("captures/*.png"))]
                report["passed"] = report["passed"] and len(report["images"]) >= 18
    finally:
        if xserver:
            xserver.terminate()
            xserver.wait(timeout=10)
        if xlog: xlog.close()
        report["seconds"] = time.time() - start
        report["load_after"] = os.getloadavg()
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        fcntl.flock(lock, fcntl.LOCK_UN)
        lock.close()
    print(json.dumps(report))
    return 0 if report.get("passed") else 1


if __name__ == "__main__":
    raise SystemExit(main())
