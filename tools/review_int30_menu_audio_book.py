#!/usr/bin/env python3
"""Render combined INT30 menu/audio/book consumer cases with strict provenance.

This scoped runner is supplied to Chat 1 with its registry/CI connection patch.
It does not change or bypass the shared validation gate.
"""
import argparse
import hashlib
import json
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
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--headless", action="store_true")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output.is_relative_to(project):
        parser.error("Evidence must be outside the source checkout")
    output.mkdir(parents=True, exist_ok=False)
    source = SourceRun(project)
    source.begin_report(output)
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="int30-menu-audio-book-") as temporary:
        env = isolated_env(Path(temporary))
        env["LIBGL_ALWAYS_SOFTWARE"] = "1"
        if not args.headless:
            env["VOXELVERSE_INT30_CAPTURE_DIR"] = str(output)
            env["VOXELVERSE_PAUSE_CAPTURE_DIR"] = str(output)
            env["VOXELVERSE_INT30_CAPTURE_ON_DEMAND"] = "1"
        command = [str(editor), "--path", str(project), "--audio-driver", "Dummy"]
        command += ["--headless"] if args.headless else ["--rendering-method", "gl_compatibility"]
        command += ["--script", "res://tests/int30_menu_audio_book_test.gd"]
        if not args.headless:
            # The full inherited 16-case matrix runs headless. Native captures
            # exercise eight additional small-window cases in both real phases.
            command += ["--", "--int30-focused"]
        timed_out = False
        with (output / "run.log").open("w") as log:
            try:
                result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=720)
                exit_code = result.returncode
            except subprocess.TimeoutExpired:
                timed_out = True
                exit_code = -1
    source.observe("combined route", force=True)
    provenance = source.write_report(output)
    log = (output / "run.log").read_text()
    images = {}
    expected = {}
    if not args.headless:
        for phase in ["creature", "tribe"]:
            for language in ["de", "en"]:
                for width, height in [(800, 600), (1280, 720)]:
                    prefix = f"{phase}-{language}-{width}x{height}"
                    for suffix in ["pause", "graphics", "audio"] + ["book-" + chapter for chapter in ["creature", "nest_group", "tribe", "medieval", "modern", "space"]]:
                        expected[f"{prefix}-{suffix}.png"] = [width, height]
                    for chapter in ["tribe", "medieval", "modern"]:
                        expected[f"{prefix}-book-{chapter}-top.png"] = [width, height]
        for filename in expected:
            path = output / filename
            if path.is_file():
                data = path.read_bytes()
                if len(data) >= 24 and data.startswith(b"\x89PNG\r\n\x1a\n"):
                    images[filename] = {"size": list(struct.unpack(">II", data[16:24])),
                                        "sha256": hashlib.sha256(data).hexdigest()}
    passed = (exit_code == 0 and not timed_out and not ERROR.search(log)
              and "INT30_MENU_AUDIO_BOOK_PASSED" in log and "PAUSE_MENU_PASSED" in log
              and provenance["reusable"]
              and all(images.get(name, {}).get("size") == size for name, size in expected.items()))
    report = {"passed": passed, "exit_code": exit_code, "timed_out": timed_out,
              "source": provenance, "engine": subprocess.check_output([args.godot, "--version"], text=True).strip(),
              "command": command, "headless": args.headless, "images": images,
              "capture_on_demand": not args.headless,
              "log_sha256": hashlib.sha256((output / "run.log").read_bytes()).hexdigest(),
              "scope": "Public spherical campaign; ordinary confirmed tribal transition; real mouse/keyboard routes, all six read-only book chapters DE/EN at actual 130% viewport scale, combined preview/mute/reset, paused time, fresh settings process. Each capture is real GL; continuous rendering is disabled during loading and between captures. Full inherited sixteen-case menu matrix separately headless. No continuous footage, target-PC listening or native Windows acceptance."}
    (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"passed": passed, "exit_code": exit_code, "images": len(images), "log_sha256": report["log_sha256"]}))
    if not passed:
        print(log[-10000:])
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
