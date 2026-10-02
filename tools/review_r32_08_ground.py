#!/usr/bin/env python3
"""Run bounded native R32-08 probes, with immutable source and isolated saves.

Campaign mode loads the regular slot through SessionFlow and captures its actual
terrain materials. Probe mode is an explicitly separate shader-only fixture.
Run only in the host's confirmed R32 measurement slot.
"""
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

from validation_provenance import SourceRun
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR

BASE = "2a738a4891a8de11d682c469833ade4dc9b01dfb"
SHADER = "world/surface/visuals/living_ground.gdshader"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--renderer", choices=["forward_plus", "gl_compatibility"], required=True)
    parser.add_argument("--mode", choices=["campaign", "probe"], required=True)
    parser.add_argument("--category", choices=["all", "campaign_spawn", "grassland", "desert", "rocky_highlands", "snow", "coast"], default="all")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--xvfb", type=Path, required=True)
    parser.add_argument("--library-path", type=Path)
    parser.add_argument("--vulkan-icd", type=Path)
    parser.add_argument("--display-number", type=int, default=208)
    parser.add_argument("--camera-reference", type=Path, help="Tracked original GL capture.json for exact camera replay")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if args.camera_reference and (not args.camera_reference.is_file() or not args.camera_reference.resolve().is_relative_to(project)):
        parser.error("Camera reference must be an existing source-monitored file inside the checkout")
    if output.is_relative_to(project) or (output.exists() and any(output.iterdir())):
        parser.error("Choose a new output directory outside the checkout")
    slot = Path("/tmp/voxelverse-r32-db514e109ac6-heavy.lock").open("a+")
    try:
        fcntl.flock(slot.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        parser.error("Shared R32 host slot is occupied; no native review started")
    output.mkdir(parents=True, exist_ok=True)
    baseline = subprocess.check_output(["git", "show", f"{BASE}:{SHADER}"], cwd=project)
    baseline_path = output / "baseline.gdshader"
    baseline_path.write_bytes(baseline)
    source = SourceRun(project)
    source.begin_report(output)
    env = os.environ.copy()
    env.update(DISPLAY=f"127.0.0.1:{args.display_number}", LIBGL_ALWAYS_SOFTWARE="1", LP_NUM_THREADS="2")
    if args.library_path:
        env["LD_LIBRARY_PATH"] = str(args.library_path.resolve()) + ":" + env.get("LD_LIBRARY_PATH", "")
    if args.vulkan_icd:
        env["VK_ICD_FILENAMES"] = str(args.vulkan_icd.resolve())
    command = []
    code = 124
    started = time.monotonic()
    with (output / "display.log").open("w") as display_log:
        display = subprocess.Popen([str(args.xvfb.resolve()), f":{args.display_number}", "-screen", "0", "960x540x24",
                                    "-nolisten", "unix", "-listen", "tcp", "-ac", "-noreset"],
                                   env=env, stdout=display_log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 10
            while True:
                try:
                    with socket.create_connection(("127.0.0.1", 6000 + args.display_number), timeout=0.2):
                        break
                except OSError:
                    if display.poll() is not None or time.monotonic() >= deadline:
                        raise RuntimeError("Display did not start; inspect display.log")
                    time.sleep(0.1)
            with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="r32-ground-") as temporary:
                engine_env = isolated_env(Path(temporary))
                engine_env.update({key: env[key] for key in ["DISPLAY", "LIBGL_ALWAYS_SOFTWARE", "LP_NUM_THREADS", "LD_LIBRARY_PATH", "VK_ICD_FILENAMES"] if key in env})
                command = [str(editor), "--path", str(project), "--rendering-method", args.renderer,
                           "--audio-driver", "Dummy", "--resolution", "960x540", "--script",
                           "res://tools/review_r32_08_ground.gd", "--", str(output), str(baseline_path), args.mode, args.category]
                if args.camera_reference:
                    command.append(str(args.camera_reference.resolve()))
                with (output / "runtime.log").open("w") as log:
                    try:
                        code = subprocess.run(command, env=engine_env, stdout=log, stderr=subprocess.STDOUT, timeout=420).returncode
                    except subprocess.TimeoutExpired:
                        code = 124
        finally:
            display.terminate()
            try:
                display.wait(timeout=5)
            except subprocess.TimeoutExpired:
                display.kill()
                display.wait()
    source.observe("native-review", force=True)
    provenance = source.write_report(output)
    log = (output / "runtime.log").read_text()
    capture = json.loads((output / "capture.json").read_text()) if (output / "capture.json").exists() else {}
    images = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.glob("*.png"))}
    passed = code == 0 and not ERROR.search(log) and capture.get("passed", False) and provenance["reusable"]
    if args.mode == "campaign":
        passed = passed and len(capture.get("samples", [])) == (18 if args.category == "all" else 3)
    result = {"passed": passed, "exit_code": code, "command": command, "mode": args.mode,
              "host": socket.gethostname(), "renderer": args.renderer, "category": args.category, "target_hardware": False,
              "godot": subprocess.check_output([args.godot, "--version"], text=True).strip(),
              "elapsed_seconds": time.monotonic() - started, "baseline_commit": BASE,
              "baseline_shader_sha256": hashlib.sha256(baseline).hexdigest(),
              "candidate_shader_sha256": hashlib.sha256((project / SHADER).read_bytes()).hexdigest(),
              "screenshots": images, "runtime_log_sha256": hashlib.sha256((output / "runtime.log").read_bytes()).hexdigest(),
              "source_provenance": provenance}
    (output / "results.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: result[key] for key in ["passed", "exit_code", "host", "renderer", "mode", "elapsed_seconds"]}))
    if not passed:
        print(log[-6000:])
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
