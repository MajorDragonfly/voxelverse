#!/usr/bin/env python3
"""Capture four canonical day phases in one actual, fixed-camera campaign."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import time

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / "tools"))
from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--renderer", choices=["forward_plus", "gl_compatibility"], required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = SourceRun(PROJECT)
    source.begin_report(output)
    started = time.monotonic()
    with validation_editor(args.godot) as godot, tempfile.TemporaryDirectory(prefix="campaign-day-review-") as userdata:
        command = [str(godot), "--path", str(PROJECT), "--rendering-method", args.renderer,
                   "--audio-driver", "Dummy", "--script", "res://tests/weather_runtime_test.gd",
                   "--", "--capture", str(output), "--capture-days-only"]
        with (output / "render.log").open("w") as log:
            try:
                code = subprocess.run(command, env=isolated_env(Path(userdata)), stdout=log,
                                      stderr=subprocess.STDOUT, timeout=600).returncode
            except subprocess.TimeoutExpired:
                code = 124
    source.observe("native_campaign", force=True)
    provenance = source.write_report(output)
    log_bytes = (output / "render.log").read_bytes()
    log = log_bytes.decode("utf-8", "replace")
    captures = {}
    for phase in ("dawn", "noon", "dusk", "night"):
        path = output / f"campaign-{phase}.png"
        data = path.read_bytes() if path.is_file() else b""
        dimensions = struct.unpack(">II", data[16:24]) if data.startswith(b"\x89PNG") else None
        captures[path.name] = {"dimensions": dimensions, "sha256": hashlib.sha256(data).hexdigest(),
                               "passed": len(data) > 4096 and dimensions == (960, 540)}
    samples_file = output / "campaign-days.json"
    samples = json.loads(samples_file.read_text()) if samples_file.is_file() else {}
    passed = (code == 0 and not ERROR.search(log) and provenance["reusable"]
              and re.search(r"WEATHER_RUNTIME:.*\btrue\b", log, re.IGNORECASE) is not None
              and all(item["passed"] for item in captures.values())
              and len(samples.get("samples", [])) == 4
              and all(s["campaign_seconds"] == s["ui_seconds"] for s in samples.get("samples", [])))
    report = {"passed": passed, "renderer": args.renderer, "command": command, "exit_code": code,
              "seconds": time.monotonic() - started, "log_sha256": hashlib.sha256(log_bytes).hexdigest(),
              "source": provenance, "captures": captures,
              "scope": "Native canonical day captures in actual spherical campaign. Pause/save/travel belong to the default weather_runtime contract, not this capture-only invocation."}
    (output / "review.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"passed": passed, "renderer": args.renderer, "exit_code": code, "captures": captures}))
    if not passed:
        print(log[-3000:])
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
