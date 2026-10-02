#!/usr/bin/env python3
"""Capture the existing audio page or the actual public two-phase audio route.

Run only in the assigned native host slot. PCM comes from Godot's Master mix;
Dummy driver captures do not attest a physical device or target-PC listening.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import wave

from validate_godot import ERROR
from validation_provenance import SourceRun
from validation_support import isolated_env, validation_editor


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--mode", choices=["page", "campaign"], required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output.is_relative_to(project):
        parser.error("Write evidence outside the source checkout")
    output.mkdir(parents=True, exist_ok=False)
    source = SourceRun(project)
    source.begin_report(output)
    campaign = args.mode == "campaign"
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="r32-audio-") as temporary:
        env = isolated_env(Path(temporary))
        env["LIBGL_ALWAYS_SOFTWARE"] = "1"
        if campaign:
            env["VOXELVERSE_R32_AUDIO_CAPTURE_DIR"] = str(output)
        command = [str(editor), "--path", str(project), "--rendering-method", "gl_compatibility",
                   "--audio-driver", "Dummy", "--script",
                   "res://tools/review_r32_16_audio_entry.gd" if campaign else "res://tests/audio/audio_settings_test.gd"]
        if not campaign:
            command += ["--", "--audio-settings-capture", str(output)]
        timed_out = False
        with (output / "run.log").open("w") as log:
            try:
                result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                        timeout=360 if campaign else 120)
                exit_code = result.returncode
            except subprocess.TimeoutExpired:
                timed_out = True
                exit_code = 124
    source.observe("native audio route", force=True)
    provenance = source.write_report(output)
    log = (output / "run.log").read_text()
    if campaign:
        expected = {f"{phase}-{locale}-{area}.png": [1280, 720]
                    for phase in ["creature", "tribe"] for locale in ["de", "en"]
                    for area in ["audio", "background-muted"]}
        required_audio = [f"{phase}-{sample}.wav" for phase in ["creature", "tribe"]
                          for sample in ["live-world", "companion-friend", "action-eat"]]
        required_audio += [f"{phase}-{locale}-{sample}.wav"
                           for phase in ["creature", "tribe"] for locale in ["de", "en"]
                           for sample in ["preview-master", "preview-music", "preview-ambience",
                                          "preview-effects", "preview-ui", "master-zero"]]
        marker = "R32_AUDIO_CAMPAIGN_PASSED"
    else:
        expected = {f"audio-{width}x{height}-{locale}-{area}.png": [width, height]
                    for width, height in [(800, 600), (1280, 720), (1920, 1080)]
                    for locale in ["de", "en"] for area in ["top", "bottom"]}
        required_audio = []
        marker = "AUDIO_SETTINGS_PASSED"
    images, recordings = {}, {}
    for filename, dimensions in expected.items():
        path = output / filename
        if path.is_file():
            data = path.read_bytes()
            if len(data) >= 24 and data.startswith(b"\x89PNG\r\n\x1a\n"):
                images[filename] = {"dimensions": list(struct.unpack(">II", data[16:24])),
                                    "sha256": hashlib.sha256(data).hexdigest()}
    for filename in required_audio:
        path = output / filename
        if path.is_file():
            with wave.open(str(path)) as sample:
                recordings[filename] = {"frames": sample.getnframes(), "sample_rate": sample.getframerate(),
                                        "channels": sample.getnchannels(), "sample_width": sample.getsampwidth(),
                                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    passed = (exit_code == 0 and not timed_out and not ERROR.search(log) and marker in log
              and provenance["reusable"]
              and all(images.get(name, {}).get("dimensions") == size for name, size in expected.items())
              and all(recordings.get(name, {}).get("frames", 0) > 0 for name in required_audio))
    report = {"passed": passed, "mode": args.mode, "exit_code": exit_code, "timed_out": timed_out,
              "source": provenance, "command": command,
              "engine": subprocess.check_output([str(args.godot), "--version"], text=True).strip(),
              "images": images, "recordings": recordings,
              "log_sha256": hashlib.sha256((output / "run.log").read_bytes()).hexdigest(),
              "scope": ("Actual public spherical campaign/ordinary confirmed tribe transition; Esc->Settings->Audio, "
                        "both phases DE/EN, 720p at runtime 150%, keyboard/mouse/mute/reset/back/pause and fresh-process settings. "
                        "30 Master PCM recordings: normal world, explicitly scripted existing companion reactions/action-audio ports, real category "
                        "previews and Master zero. Focus signals explicitly injected. No unscripted hearing, native Windows/export "
                        "or target-PC acceptance; normal settings 150% persistence remains R32-15/01." if campaign else
                        "Existing once-registered page test with native GL, 800x600/720p/1080p DE/EN at runtime 150%, "
                        "mouse/keyboard/focus signals, synthetic routing signal and real production preview streams, restart. "
                        "No combined campaign, physical audio-device or target-PC acceptance.")}
    (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"passed": passed, "mode": args.mode, "images": len(images), "recordings": len(recordings)}))
    if not passed:
        print(log[-8000:])
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
