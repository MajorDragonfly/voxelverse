#!/usr/bin/env python3
"""Capture the actual forecast canvas and diagnostic warning in both languages."""
import argparse
import json
import re
import struct
import subprocess
import tempfile
from pathlib import Path

from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--renderer", choices=["forward_plus", "gl_compatibility"], required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    with validation_editor(args.godot) as godot, tempfile.TemporaryDirectory(prefix="forecast-review-") as userdata:
        command = [str(godot), "--path", str(project), "--rendering-method", args.renderer,
                   "--audio-driver", "Dummy", "--script", "res://tests/weather_forecast_ui_test.gd",
                   "--", "--capture", str(output)]
        with (output / "render.log").open("w") as log:
            result = subprocess.run(command, env=isolated_env(Path(userdata)), stdout=log,
                                    stderr=subprocess.STDOUT, timeout=120)
    log = (output / "render.log").read_text()
    images = {}
    for locale in ("de", "en"):
        for size in ("800x600", "1280x720", "1920x1080"):
            images[f"forecast-{size}-{locale}.png"] = tuple(map(int, size.split("x")))
        for size in ("800x600", "1280x720"):
            images[f"warning-{size}-{locale}.png"] = tuple(map(int, size.split("x")))
    captured = {}
    for name, expected in images.items():
        data = (output / name).read_bytes() if (output / name).is_file() else b""
        dimensions = struct.unpack(">II", data[16:24]) if data.startswith(b"\x89PNG") else None
        captured[name] = {"dimensions": dimensions, "passed": len(data) > 4096 and dimensions == expected}
    passed = (result.returncode == 0 and not ERROR.search(log)
              and re.search(r"WEATHER_FORECAST_UI:.*\btrue\b", log, re.IGNORECASE) is not None
              and all(entry["passed"] for entry in captured.values()))
    (output / "review.json").write_text(json.dumps({"passed": passed, "renderer": args.renderer,
        "exit_code": result.returncode, "captures": captured}, indent=2) + "\n")
    print(json.dumps({"passed": passed, "renderer": args.renderer, "captures": captured}))
    if not passed: print(log[-5000:])
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
