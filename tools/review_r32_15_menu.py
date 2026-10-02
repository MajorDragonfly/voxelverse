#!/usr/bin/env python3
"""Scoped R32-15 settings/public-campaign checks with real native captures.

Windows editor: omit --xvfb. Linux: use an existing DISPLAY or provide --xvfb.
This does not claim release-export or target-PC acceptance.
"""
import argparse
import contextlib
import hashlib
import json
import os
import platform
from pathlib import Path
import socket
import struct
import subprocess
import tempfile
import time

from validate_godot import ERROR
from validation_provenance import SourceRun
from validation_support import isolated_env, validation_editor


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--settings-only", action="store_true")
    parser.add_argument("--xvfb", type=Path)
    parser.add_argument("--renderer", choices=["gl_compatibility", "forward_plus"], default="gl_compatibility")
    parser.add_argument("--lock", type=Path, default=Path(tempfile.gettempdir()) / "voxelverse-r32-db514e109ac6-heavy.lock")
    parser.add_argument("--wait-seconds", type=int, default=0, choices=range(56), metavar="0..55")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output.is_relative_to(project):
        parser.error("Evidence must be outside the source checkout")
    with args.lock.open("a") as lock:
        try:
            if os.name == "nt":
                import msvcrt
                lock.write("\0")
                lock.flush()
                lock.seek(0)
                msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                if args.wait_seconds:
                    import signal
                    def expired(_signal, _frame):
                        raise TimeoutError("Host slot wait expired")
                    old_handler = signal.signal(signal.SIGALRM, expired)
                    signal.alarm(args.wait_seconds)
                    try:
                        fcntl.flock(lock, fcntl.LOCK_EX)
                    finally:
                        signal.alarm(0)
                        signal.signal(signal.SIGALRM, old_handler)
                else:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (OSError, TimeoutError):
            print("R32_15_SLOT_BUSY: no Godot or capture process started")
            return 2
        print("R32_15_SLOT_ACQUIRED: exclusive functional review starts", flush=True)
        output.mkdir(parents=True, exist_ok=False)
        source = SourceRun(project)
        source.begin_report(output)
        entry = "r32_15_settings_navigation_test" if args.settings_only else "r32_15_campaign_menu_test"
        with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="r32-15-user-") as directory, contextlib.ExitStack() as stack:
            env = isolated_env(Path(directory))
            env["LIBGL_ALWAYS_SOFTWARE"] = "1"
            xvfb = None
            if args.xvfb and not args.headless:
                env["DISPLAY"] = "127.0.0.1:177"
                xlog = stack.enter_context((output / "xvfb.log").open("w"))
                xvfb = subprocess.Popen([str(args.xvfb), ":177", "-screen", "0", "1920x1080x24", "-nolisten", "unix", "-nolisten", "local", "-listen", "tcp", "-ac"], env=env, stdout=xlog, stderr=subprocess.STDOUT)
                deadline = time.monotonic() + 10
                while time.monotonic() < deadline and xvfb.poll() is None:
                    try:
                        with socket.create_connection(("127.0.0.1", 6177), timeout=0.2):
                            break
                    except OSError:
                        time.sleep(0.1)
            command = [str(editor), "--path", str(project), "--audio-driver", "Dummy"]
            command += ["--headless"] if args.headless else ["--rendering-method", args.renderer]
            command += ["--script", "res://tests/" + entry + ".gd"]
            if not args.headless:
                env["VOXELVERSE_R32_15_CAPTURE_DIR"] = str(output)
            timed_out = False
            try:
                with (output / "run.log").open("w") as log:
                    try:
                        result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=60 if args.settings_only else 720)
                        exit_code = result.returncode
                    except subprocess.TimeoutExpired:
                        timed_out, exit_code = True, 124
            finally:
                if xvfb is not None:
                    xvfb.terminate()
                    xvfb.wait(timeout=10)
        source.observe("completed R32-15 route", force=True)
        provenance = source.write_report(output)
        log = (output / "run.log").read_text()
        images = {}
        for image in sorted(output.glob("*.png")):
            raw = image.read_bytes()
            if raw[:8] == b"\x89PNG\r\n\x1a\n":
                images[image.name] = {"size": list(struct.unpack(">II", raw[16:24])), "sha256": hashlib.sha256(raw).hexdigest()}
        marker = "R32_15_SETTINGS_NAVIGATION_PASSED" if args.settings_only else "R32_15_CAMPAIGN_MENU_PASSED"
        expected = {}
        if not args.headless:
            if args.settings_only:
                for width, height in [(800, 600), (1280, 720), (1920, 1080)]:
                    for scale in [100, 125, 150]:
                        for locale in ["de", "en"]:
                            for page in ["graphics", "controls"]:
                                expected[f"{page}-{width}x{height}-{scale}-{locale}.png"] = [width, height]
            else:
                for phase in ["creature", "tribe"]:
                    for width, height, scale in [(800, 600, 150), (1280, 720, 125), (1920, 1080, 100)]:
                        for locale in ["de", "en"]:
                            for page in ["pause", "graphics", "controls", "language"]:
                                expected[f"{phase}-{locale}-{width}x{height}-{scale}-{page}.png"] = [width, height]
                    expected[f"{phase}-title.png"] = [1920, 1080]
        passed = exit_code == 0 and not timed_out and marker in log and not ERROR.search(log) and provenance["reusable"] and all(images.get(name, {}).get("size") == size for name, size in expected.items())
        report = {"passed": passed, "exit_code": exit_code, "timed_out": timed_out, "source": provenance, "command": command, "engine": subprocess.check_output([args.godot, "--version"], text=True).strip(), "platform": platform.platform(), "headless": args.headless, "settings_only": args.settings_only, "renderer": args.renderer, "images": images, "log_sha256": hashlib.sha256((output / "run.log").read_bytes()).hexdigest(), "scope": "Settings-only controls or public spherical campaign via disposable developer launcher and ordinary phase confirmation. Native GL/Forward+ editor captures when headless=false; OS recorded separately. No release-export or target-PC acceptance. Audio page owned by R32-16. Rendering paused between public campaign captures; no continuous footage or performance claim."}
        (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"passed": passed, "exit_code": exit_code, "images": len(images), "source_reusable": provenance["reusable"]}))
        if not passed:
            print(log[-5000:])
        return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
