#!/usr/bin/env python3
"""Prepare isolated owner-patch copies; run bounded R32-10 functional evidence."""
import argparse
from contextlib import contextmanager, ExitStack
import fcntl
import hashlib
import json
import os
import platform
from pathlib import Path
import shutil
import select
import subprocess
import tempfile
import time

from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun
from validate_godot import ERROR

BASE = "2a738a4891a8de11d682c469833ade4dc9b01dfb"
OWNED = ["creatures/behavior/creature_emotion_cue.gd", "ui/creature_inspection_hud.gd"]


@contextmanager
def native_display(env, executable, output):
    # Managed command namespaces require display and game in the same process
    # family. TCP loopback avoids unavailable Unix-domain display sockets.
    read_fd, write_fd = os.pipe()
    with (output / "xvfb.log").open("w") as log:
        process = subprocess.Popen([str(executable), "-displayfd", str(write_fd), "-screen", "0", "1920x1080x24",
                                    "-nolisten", "local", "-nolisten", "unix", "-listen", "tcp", "-ac"],
                                   env=env, stdout=log, stderr=subprocess.STDOUT, pass_fds=(write_fd,))
        os.close(write_fd)
        try:
            if not select.select([read_fd], [], [], 5)[0]:
                raise RuntimeError("Native display did not start")
            number = os.read(read_fd, 32).decode().strip()
            if not number.isdecimal():
                raise RuntimeError("Native display number unavailable")
            env["DISPLAY"] = "127.0.0.1:" + number
            yield
        finally:
            os.close(read_fd)
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def run():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot", required=True)
    p.add_argument("--phase", choices=["before", "after"], required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--capture", choices=["gl_compatibility", "forward_plus"])
    p.add_argument("--xvfb", type=Path)
    p.add_argument("--campaign", action="store_true")
    p.add_argument("--prepare-only", action="store_true")
    args = p.parse_args()
    source = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    project = output / "checkout"
    subprocess.run(["git", "clone", "--quiet", "--no-hardlinks", str(source), str(project)], check=True)
    subprocess.run(["git", "-C", str(project), "switch", "--quiet", "--detach", BASE], check=True)
    inputs = [*source.glob("tests/r32_10_*.gd*"), *source.glob("tools/review_r32_10_*.gd*")]
    if args.phase == "after":
        inputs += [source / name for name in OWNED]
    for path in inputs:
        target = project / path.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    patches = source / "docs/evidence/r32-10/patches"
    if args.phase == "after":
        subprocess.run(["git", "apply", "--unidiff-zero", str(patches / "wildlife-marker-priority.patch")], cwd=project, check=True)
        path = project / "localization/catalog.json"
        catalog = json.loads(path.read_text())
        catalog["messages"] += json.loads((patches / "localization-append.json").read_text())
        path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
        subprocess.run(["python3", "tools/localization/catalog.py"], cwd=project, check=True)
    path = project / "tools/validation/contracts.json"
    registry = json.loads(path.read_text())
    contract = next(row for row in registry["contracts"] if row["id"] == "wildlife")
    contract["tests"].append("r32_10_state_signs_test")
    path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n")
    (output / "checked-source.patch").write_bytes(subprocess.check_output(["git", "diff", "--binary"], cwd=project))
    if args.prepare_only:
        print(project)
        return
    with validation_editor(args.godot) as engine, tempfile.TemporaryDirectory(prefix="r32-signs-") as tmp, ExitStack() as stack:
        env = isolated_env(Path(tmp))
        if args.capture and args.xvfb:
            stack.enter_context(native_display(env, args.xvfb.resolve(), output))
        imported = subprocess.run([str(engine), "--headless", "--path", str(project), "--import"],
                                  env=env, capture_output=True, text=True, timeout=120)
        (output / "import.log").write_text(imported.stdout + imported.stderr)
        if imported.returncode or ERROR.search(imported.stdout + imported.stderr):
            raise RuntimeError("Import failed")
        provenance = SourceRun(project)
        provenance.begin_report(output)
        commands = []
        tests = ["creature_expression_test", "wildlife_ai_test", "r32_10_state_signs_test"]
        if args.capture:
            tests = []
        for test in tests:
            command = [str(engine), "--headless", "--path", str(project), "--script", f"res://tests/{test}.gd"]
            started = time.monotonic()
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=120)
            log = result.stdout + result.stderr
            (output / (test + ".log")).write_text(log)
            expected_failure = args.phase == "before" and test == "r32_10_state_signs_test"
            ok = not ERROR.search(log) and (result.returncode == 1 if expected_failure else result.returncode == 0)
            commands.append({"command": command, "seconds": time.monotonic() - started,
                             "exit_code": result.returncode, "accepted": ok, "expected_negative": expected_failure,
                             "log_sha256": hashlib.sha256(log.encode()).hexdigest()})
            print(test, "expected negative" if expected_failure else "passed" if ok else "FAILED", flush=True)
            provenance.observe(test)
            if not ok:
                print(log[-5000:], flush=True)
                break
        if args.capture:
            images = output / "render"
            script = "res://tools/review_r32_10_campaign.gd" if args.campaign else "res://tools/review_r32_10_signs.gd"
            command = [str(engine), "--path", str(project), "--rendering-method", args.capture,
                       "--audio-driver", "Dummy", "--fixed-fps", "15", "--script",
                       script, "--", str(images), "encounters"]
            started = time.monotonic()
            try:
                result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=180)
                log = result.stdout + result.stderr
                marker = "R32_CAMPAIGN_SIGNS_PASSED" if args.campaign else "INT30_CREATURE_CAPTURE_PASSED"
                ok = result.returncode == 0 and not ERROR.search(log) and marker in log
                commands.append({"command": command, "seconds": time.monotonic() - started,
                                 "exit_code": result.returncode, "accepted": ok,
                                 "log_sha256": hashlib.sha256(log.encode()).hexdigest()})
            except subprocess.TimeoutExpired as error:
                log = (error.stdout or b"").decode(errors="replace") + "\nR32_CAPTURE_TIMEOUT: 180 seconds\n"
                commands.append({"command": command, "seconds": 180, "accepted": False, "timeout": True})
            (output / "render.log").write_text(log)
            print(log[-3000:], flush=True)
            provenance.observe("render")
        source_report = provenance.write_report(output)
        report = {"phase": args.phase, "base": BASE, "authoring_head": subprocess.check_output(
            ["git", "rev-parse", "HEAD", "HEAD^{tree}"], cwd=source, text=True).splitlines(),
            "engine": subprocess.check_output([str(engine), "--version"], text=True).strip(),
            "host": platform.node(), "commands": commands, "source_provenance": source_report,
            "scope": "Isolated owner-patch checkout. Flat encounter/UI fixture; no target-PC or full integration acceptance."}
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        if not all(row["accepted"] for row in commands) or provenance.blocked:
            raise SystemExit(1)


if __name__ == "__main__":
    # All Godot work, including import and functional captures, is serialized
    # on the concrete shared R32 host. No unguarded fallback or indefinite wait.
    with open("/tmp/voxelverse-r32-db514e109ac6-heavy.lock", "a") as lock:
        deadline = time.monotonic() + 60
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise SystemExit("R32 shared host occupied; no Godot started")
                time.sleep(0.25)
        run()
