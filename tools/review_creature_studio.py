#!/usr/bin/env python3
"""Capture the real workshop with isolated saves and strict runtime diagnostics."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile

from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--renderer", choices=["gl_compatibility", "forward_plus"], default="gl_compatibility")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    project = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="creature-review-user-") as userdir:
        environment = dict(os.environ, XDG_DATA_HOME=userdir)
        command = [args.godot, "--path", str(project), "--rendering-method", args.renderer,
                   "--audio-driver", "Dummy", "--script", "res://tools/capture_creature_studio.gd",
                   "--", str(output)]
        run = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=120)
    log = run.stdout + run.stderr
    (output / "render.log").write_text(log)
    if run.returncode or ERROR.search(log):
        raise RuntimeError(log[-10000:])
    images = []
    for name in ["round_body", "grazer_parts", "upright_paint", "crawler_test"]:
        path = output / f"{name}.png"
        data = path.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            raise RuntimeError(f"Invalid screenshot: {path}")
        width, height = struct.unpack(">II", data[16:24])
        if width < 1280 or height < 720:
            raise RuntimeError(f"Unexpected review resolution: {width}x{height}")
        images.append({"file": path.name, "width": width, "height": height,
                       "sha256": hashlib.sha256(data).hexdigest()})
    if len({image["sha256"] for image in images}) != 4:
        raise RuntimeError("Workshop modes produced duplicate screenshots.")
    result = {"renderer": args.renderer, "screenshots": images, "runtime_errors": 0}
    (output / "review.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
