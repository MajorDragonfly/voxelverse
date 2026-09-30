#!/usr/bin/env python3
"""Render production scanner cases; provide a display (xvfb-run on CI)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--renderer", choices=["gl_compatibility", "forward_plus"], default="gl_compatibility")
    parser.add_argument("--languages", nargs="+", choices=["de", "en"], default=["de", "en"])
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    for language in args.languages:
        output = args.output.resolve() / language
        output.mkdir(parents=True, exist_ok=True)
        command = [args.godot, "--path", str(project), "--rendering-method", args.renderer,
                   "--audio-driver", "Dummy", "--script", "res://tools/capture_scanner_motion.gd", "--", str(output), language]
        with tempfile.TemporaryDirectory(prefix="scanner-render-") as userdata:
            env = os.environ.copy()
            for name in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
                env[name] = str(Path(userdata) / name)
            with (output / "render.log").open("wb") as log:
                result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=900)
        text = (output / "render.log").read_text()
        if result.returncode or any(token in text for token in ["SCRIPT ERROR", "ERROR:", "ObjectDB instances leaked"]):
            raise RuntimeError(f"Scanner render failed: {output / 'render.log'}")
        measurements = json.loads((output / "measurements.json").read_text())
        if measurements["failures"] or not measurements["rendered"] or measurements["captured_frames"] < 580:
            raise RuntimeError(f"Incomplete scanner capture: {output}")
        video = output / "scanner-motion.mp4"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "30", "-i", str(output / "frame-%05d.png"),
                        "-c:v", "libx264", "-threads", "2", "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(video)], check=True)
        records.append({"language": language, "renderer": args.renderer, "command": command,
                        "frames": measurements["captured_frames"], "video_sha256": hashlib.sha256(video.read_bytes()).hexdigest()})
        print(json.dumps(records[-1]), flush=True)
    (args.output / "results.json").write_text(json.dumps(records, indent=2) + "\n")


if __name__ == "__main__":
    main()
