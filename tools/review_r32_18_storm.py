#!/usr/bin/env python3
"""Bounded native campaign weather evidence; hold the R32 host mutex throughout."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

from validate_godot import ERROR
from validation_provenance import SourceRun
from validation_support import isolated_env, validation_editor

LOCK = Path("/tmp/voxelverse-r32-db514e109ac6-heavy.lock")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--xvfb", type=Path, required=True)
    parser.add_argument("--display", type=int, default=188)
    parser.add_argument("--renderer", choices=["gl_compatibility", "forward_plus"], default="gl_compatibility")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reference-save", type=Path, help="Replay the exact same campaign/body/camera in another renderer")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    with LOCK.open("a+") as lock:
        start = time.monotonic()
        while True:
            try:
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() - start >= 60:
                    (output / "blocked.json").write_text(json.dumps({"ran": False, "reason": "R32 host mutex occupied for 60 s"}) + "\n")
                    print("R32_18_BLOCKED: no Godot process started", flush=True)
                    return 2
                time.sleep(0.25)
        print("R32_18_LOCK_ACQUIRED", flush=True)
        provenance = SourceRun(project)
        provenance.begin_report(output)
        with tempfile.TemporaryDirectory(prefix="r32-18-native-") as userdata, validation_editor(args.godot) as godot:
            env = isolated_env(Path(userdata))
            env["DISPLAY"] = f"localhost:{args.display}"
            library = args.xvfb.resolve().parent.parent / "lib/x86_64-linux-gnu"
            env["LD_LIBRARY_PATH"] = str(library) + ":" + env.get("LD_LIBRARY_PATH", "")
            with (output / "xvfb.log").open("w") as xlog:
                display = subprocess.Popen([str(args.xvfb.resolve()), f":{args.display}", "-screen", "0", "960x540x24", "-ac", "-nolisten", "unix", "-listen", "tcp"],
                                           env=env, stdout=xlog, stderr=subprocess.STDOUT)
                try:
                    ready = False
                    for attempt in range(40):
                        if display.poll() is not None:
                            break
                        try:
                            with socket.create_connection(("127.0.0.1", 6000 + args.display), timeout=0.2):
                                ready = True
                                break
                        except OSError:
                            time.sleep(0.1)
                    if not ready:
                        raise RuntimeError("Xvfb did not become ready: " + (output / "xvfb.log").read_text())
                    command = [str(godot), "--path", str(project), "--display-driver", "x11", "--rendering-method", args.renderer,
                               "--audio-driver", "Dummy", "--script", "res://tools/review_r32_18_storm.gd", "--", "--capture", str(output)]
                    if args.reference_save:
                        command += ["--reference-save", str(args.reference_save.resolve())]
                    with (output / "render.log").open("w") as log:
                        result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=300)
                    observation = provenance.observe("native_capture", force=True)
                    review = json.loads((output / "review.json").read_text()) if (output / "review.json").exists() else {}
                    frames = sorted(output.glob("frame-*.png"))
                    passed = result.returncode == 0 and not ERROR.search((output / "render.log").read_text()) and review.get("passed") and len(frames) == 125 and observation["status"] == "unchanged"
                    if passed:
                        # Video is sampled at 3 campaign seconds per frame, 10
                        # playback frames/s. No wall-time/FPS claim is implied.
                        subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", "10", "-i", str(output / "frame-%04d.png"),
                                        "-c:v", "libx264", "-threads", "2", "-crf", "22", "-pix_fmt", "yuv420p", str(output / "regular-storm.mp4")], check=True, timeout=60)
                    report = {"passed": bool(passed), "command": command, "exit_code": result.returncode, "provenance": provenance.write_report(output),
                              "scope": "Native software-rendered actual campaign; fixed clock sampled 3 s/frame and played at 10 fps. No overall FPS or target-PC approval.",
                              "log_sha256": digest(output / "render.log"), "captures": {p.name: digest(p) for p in output.glob("*.png")},
                              "source_observation": observation["status"]}
                    (output / "runner.json").write_text(json.dumps(report, indent=2) + "\n")
                    print(json.dumps({"passed": bool(passed), "frames": len(frames), "renderer": args.renderer, "source": observation["status"]}), flush=True)
                    if not passed:
                        print((output / "render.log").read_text()[-6000:], flush=True)
                    return 0 if passed else 1
                finally:
                    display.terminate()
                    display.wait(timeout=10)


if __name__ == "__main__":
    raise SystemExit(main())
