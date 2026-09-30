#!/usr/bin/env python3
"""Reproduce the isolated INT30 village checks; keep output outside the checkout."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--phase", choices=["functional", "render", "captions"], default="functional")
    parser.add_argument("--source", type=Path, help="A genuine held construction checkpoint; omit for fresh public entry")
    parser.add_argument("--snapshots", type=Path, help="Functional output directory for rendering")
    parser.add_argument("--xvfb", help="Optional Xvfb executable on Linux without a desktop display")
    parser.add_argument("--display", type=int, default=93)
    args = parser.parse_args()
    project, output = args.project.resolve(), args.output.resolve()
    if output.is_relative_to(project):
        parser.error("Output must be outside the source checkout.")
    output.mkdir(parents=True, exist_ok=False)
    sys.path.insert(0, str(project / "tools"))
    from validation_provenance import SourceRun
    from validation_support import isolated_env
    from validate_godot import ERROR
    source = SourceRun(project)
    source.begin_report(output)
    env = isolated_env(output / "userdata")
    script = "int30_village_view_probe" if args.phase == "captions" else "int30_village_resume_probe"
    command = [args.godot, "--verbose", "--path", str(project), "--script", f"res://tests/{script}.gd"]
    if args.phase != "render":
        command.insert(1, "--headless")
    if args.phase != "captions":
        command += ["--", "--capture", str(output)]
    if args.source:
        checkpoint = output / "physical-construction-source.save.json"
        shutil.copy2(args.source, checkpoint)
        command += ["--start-from-checkpoint", str(checkpoint)]
    if args.phase == "render":
        if not args.snapshots:
            parser.error("Rendering requires --snapshots.")
        command[1:1] = ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"]
        command += ["--capture-snapshots", str(args.snapshots.resolve())]
    xserver = None
    started = time.monotonic()
    try:
        if args.phase == "render" and args.xvfb:
            with (output / "xvfb.log").open("w") as log:
                xserver = subprocess.Popen([args.xvfb, f":{args.display}", "-screen", "0", "1280x800x24", "-ac", "-nolisten", "unix", "-listen", "tcp"], stdout=log, stderr=subprocess.STDOUT)
            for attempt in range(60):
                try:
                    with socket.create_connection(("127.0.0.1", 6000 + args.display), 1):
                        break
                except OSError:
                    time.sleep(0.1)
            env["DISPLAY"] = f"127.0.0.1:{args.display}"
        with (output / "godot.log").open("w") as log:
            try:
                code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=1800).returncode
            except subprocess.TimeoutExpired:
                log.write("\nERROR: INT30 review timed out\n")
                code = 124
    finally:
        if xserver:
            xserver.terminate()
            xserver.wait(timeout=10)
    log = (output / "godot.log").read_text()
    source.observe(args.phase, force=True)
    provenance = source.write_report(output)
    passed = code == 0 and not ERROR.search(log) and provenance["reusable"]
    if args.phase == "functional":
        passed = passed and all("INT30_RESTART_PASSED:" + case in log for case in ["construction_cargo", "gathered_cargo", "far_cargo"])
    if args.phase == "render":
        passed = passed and len(list(output.glob("*.png"))) == 4
    result = {"passed": bool(passed), "exit_code": code, "seconds": round(time.monotonic() - started, 3), "command": command,
              "engine": subprocess.check_output([args.godot, "--version"], text=True).strip(),
              "source": provenance, "log_sha256": hashlib.sha256(log.encode()).hexdigest(),
              "environment": {"user_data": str(output / "userdata"), "isolated": True}}
    (output / "results.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: value for key, value in result.items() if key != "source"}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
