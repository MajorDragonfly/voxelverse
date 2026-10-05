#!/usr/bin/env python3
"""Run the shared fixed-camera weather consumer with the original 300 s limit."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import socket
import shutil
import subprocess
import tempfile
import time

from validate_godot import ERROR
from validation_provenance import SourceRun
from validation_support import isolated_env, validation_editor

ROOT = Path(__file__).resolve().parents[1]
LOCK = Path("/tmp/voxelverse-r32-db514e109ac6-heavy.lock")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--xvfb", type=Path, required=True)
    parser.add_argument("--display", type=int, default=188)
    parser.add_argument("--renderer", choices=["gl_compatibility", "forward_plus"], required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reference-save", type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.is_relative_to(ROOT) or output.exists():
        parser.error("Use a new evidence directory outside the source checkout")
    output.mkdir(parents=True)
    with LOCK.open("a+") as lock:
        started = time.monotonic()
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() - started >= 60:
                    (output / "blocked.json").write_text(json.dumps({"ran": False, "reason": "host slot occupied"}))
                    return 2
                time.sleep(0.25)
        source = SourceRun(ROOT)
        source.begin_report(output)
        with tempfile.TemporaryDirectory(prefix="r32-01-weather-") as userdata, validation_editor(args.godot) as godot:
            env = isolated_env(Path(userdata))
            env["DISPLAY"] = f"localhost:{args.display}"
            library = args.xvfb.resolve().parent.parent / "lib/x86_64-linux-gnu"
            env["LD_LIBRARY_PATH"] = str(library) + ":" + env.get("LD_LIBRARY_PATH", "")
            command = [str(godot), "--path", str(ROOT), "--display-driver", "x11",
                       "--rendering-method", args.renderer, "--audio-driver", "Dummy",
                       "--script", "res://tools/review_r32_01_weather.gd", "--", "--capture", str(output)]
            if args.reference_save:
                command += ["--reference-save", str(args.reference_save.resolve())]
            code, error = None, None
            with (output / "xvfb.log").open("w") as xlog:
                display = subprocess.Popen([str(args.xvfb.resolve()), f":{args.display}", "-screen", "0",
                                            "960x540x24", "-ac", "-nolisten", "unix", "-listen", "tcp"],
                                           env=env, stdout=xlog, stderr=subprocess.STDOUT)
                try:
                    for attempt in range(40):
                        if display.poll() is not None:
                            raise RuntimeError("Xvfb exited before readiness")
                        try:
                            with socket.create_connection(("127.0.0.1", 6000 + args.display), timeout=0.2):
                                break
                        except OSError:
                            time.sleep(0.1)
                    else:
                        raise RuntimeError("Xvfb readiness deadline")
                    with (output / "render.log").open("w") as log:
                        code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=300).returncode
                except subprocess.TimeoutExpired:
                    code, error = 124, "Original 300-second native deadline reached"
                except (OSError, RuntimeError) as failure:
                    error = str(failure)
                finally:
                    display.terminate()
                    display.wait(timeout=10)
                    # Preserve the actual isolated save/preferences after negative
                    # lifecycle probes; no incomplete run becomes a positive proof.
                    if code != 0:
                        shutil.copytree(userdata, output / "isolated-userdata")
        source.observe("native_capture", force=True)
        provenance = source.write_report(output)
        log = (output / "render.log").read_text() if (output / "render.log").exists() else ""
        review = json.loads((output / "review.json").read_text()) if (output / "review.json").exists() else {}
        frames = sorted(output.glob("frame-*.png"))
        passed = (code == 0 and not error and not ERROR.search(log) and review.get("passed")
                  and review.get("renderer") == args.renderer and len(frames) == 129
                  and len(list(output.glob("*.png"))) == 137 and len(review.get("rows", [])) == 135
                  and provenance["reusable"])
        report = {"passed": bool(passed), "exit_code": code, "error": error, "command": command,
                  "source_provenance": provenance, "timeout_seconds": 300,
                  "renderer_required": args.renderer, "renderer_observed": review.get("renderer"),
                  "host": socket.gethostname(), "target_pc_acceptance": False,
                  "captures": {p.name: digest(p) for p in sorted(output.glob("*.png"))},
                  "environment": {key: env.get(key) for key in ["DISPLAY", "LD_LIBRARY_PATH", "VK_DRIVER_FILES", "LP_NUM_THREADS"]},
                  "xvfb_sha256": digest(args.xvfb), "log_sha256": digest(output / "render.log") if log else None}
        (output / "runner.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"passed": bool(passed), "frames": len(frames), "renderer": report["renderer_observed"], "error": error}), flush=True)
        return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
