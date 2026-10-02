#!/usr/bin/env python3
"""Start the software display in the same network namespace as its capture."""
import argparse
import os
from pathlib import Path
import socket
import subprocess
import sys
import time


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--xvfb", required=True)
    p.add_argument("--godot", required=True)
    p.add_argument("--renderer", choices=["gl_compatibility", "forward_plus", "both"], required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["DISPLAY"] = "127.0.0.1:87"
    with args.output.with_suffix(".xvfb.log").open("w") as log:
        display = subprocess.Popen([args.xvfb, ":87", "-screen", "0", "960x540x24",
                                    "-listen", "tcp", "-nolisten", "unix", "-nolisten", "local", "-ac"],
                                   env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                if display.poll() is not None:
                    raise RuntimeError("Software display failed; preserve its log")
                try:
                    with socket.create_connection(("127.0.0.1", 6087), timeout=0.5):
                        break
                except OSError:
                    time.sleep(0.1)
            else:
                raise RuntimeError("Software display did not become ready")
            renderers = ["gl_compatibility", "forward_plus"] if args.renderer == "both" else [args.renderer]
            failed = False
            for renderer in renderers:
                target = args.output / renderer if args.renderer == "both" else args.output
                command = [sys.executable, str(Path(__file__).with_name("review_r32_07_distance.py")),
                           "--godot", args.godot, "--renderer", renderer, "--output", str(target),
                           "--baseline-ref", "2a738a4891a8de11d682c469833ade4dc9b01dfb"]
                failed = subprocess.run(command, env=env).returncode != 0 or failed
            return 1 if failed else 0
        finally:
            display.terminate()
            try:
                display.wait(timeout=5)
            except subprocess.TimeoutExpired:
                display.kill()
                display.wait()


if __name__ == "__main__":
    raise SystemExit(main())
