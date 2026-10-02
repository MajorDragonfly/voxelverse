#!/usr/bin/env python3
"""Focused book probes using the existing strict log and source rules."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
from validate_godot import ERROR
from validation_provenance import SourceRun
from validation_support import isolated_env, validation_editor


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--campaign", action="store_true")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output.is_relative_to(project):
        parser.error("Capture output must be outside the checkout")
    output.mkdir(parents=True, exist_ok=False)
    source = SourceRun(project)
    source.begin_report(output)
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="r32-13-") as temporary:
        env = isolated_env(Path(temporary))
        env.update(VOXELVERSE_R32_13_OUTPUT=str(output), LIBGL_ALWAYS_SOFTWARE="1")
        command = [str(editor), "--path", str(project), "--audio-driver", "Dummy"]
        command += ["--headless"] if args.headless else ["--rendering-method", "gl_compatibility"]
        script = "res://tools/review_r32_13_campaign.gd" if args.campaign else "res://tests/r32_13_book_test.gd"
        command += ["--script", script]
        if args.baseline:
            command += ["--", "--baseline"]
        timed_out = False
        with (output / "run.log").open("w") as log:
            try:
                result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=360)
                code = result.returncode
            except subprocess.TimeoutExpired:
                timed_out = True
                code = -1
    source.observe("book probe", force=True)
    provenance = source.write_report(output)
    log = (output / "run.log").read_text()
    cases_path = output / "cases.json"
    cases = json.loads(cases_path.read_text()) if cases_path.is_file() else {}
    marker = "R32_13_CAMPAIGN_PASSED" if args.campaign else "R32_13_BOOK_PASSED"
    passed = code == 0 and not timed_out and not ERROR.search(log) and marker in log and provenance["reusable"]
    images = {}
    for p in output.glob("*.png"):
        data = p.read_bytes()
        if len(data) >= 24 and data.startswith(b"\x89PNG\r\n\x1a\n"):
            images[p.name] = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                              "size": list(struct.unpack(">II", data[16:24]))}
    if not args.headless:
        if args.campaign:
            passed = passed and len(images) == 100 and len(cases.get("cases", [])) == 84
        else:
            for case in cases.get("cases", []):
                width, height = case["size"]
                name = f'{case["language"]}-{width}x{height}-{round(case["ui_scale"] * 100)}-{case["chapter"]}-top.png'
                passed = passed and images.get(name, {}).get("size") == [width, height]
            passed = passed and len(cases.get("cases", [])) == 108
    report = {"passed": passed, "exit_code": code, "timed_out": timed_out, "source": provenance,
              "engine": subprocess.check_output([args.godot, "--version"], text=True).strip(),
              "command": command, "host": os.uname().nodename, "headless": args.headless,
              "checks": cases.get("checks"), "failures": cases.get("failures"), "images": images,
              "log_sha256": hashlib.sha256((output / "run.log").read_bytes()).hexdigest()}
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: report[k] for k in ["passed", "exit_code", "timed_out", "checks", "failures"]}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
