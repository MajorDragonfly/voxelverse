#!/usr/bin/env python3
"""DIAGNOSTIC ONLY: observe the existing frontend smoke in a Windows release.

This does not run or approve general desktop export acceptance or a main merge.
The normal validate_export.py and its required checks remain unchanged.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import time

from install_godot import VERSION
from validate_export import PRESETS
from validate_godot import ERROR
from validation_provenance import SourceRun
from validation_support import isolated_env


def evaluate_log(status, text, marker=None, require_jump_observation=False):
    """Use the existing strict filter, exit status and original completion marker."""
    strict_error = ERROR.search(text) is not None
    marker_present = marker is None or marker in text
    result = {"process_passed": status == 0 and not strict_error and marker_present,
              "strict_error": strict_error, "completion_marker_present": marker_present}
    if require_jump_observation:
        prefix = "FRONTEND_JUMP_DIAGNOSTIC:"
        payloads, errors = [], []
        lines = [line[len(prefix):].strip() for line in text.splitlines() if line.startswith(prefix)]
        for line in lines:
            try:
                payload = json.loads(line)
                if not isinstance(payload, dict):
                    raise ValueError("Jump observation must be a JSON object")
                payloads.append(payload)
            except ValueError as error:
                errors.append(str(error))
        result.update(jump_observation_present=bool(lines), jump_observation_errors=errors,
                      jump_observations=payloads, jump_observation_passed=bool(payloads) and not errors)
    return result


def export_files(package):
    result = []
    for path in sorted(package.rglob("*")):
        if path.is_file():
            with path.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            result.append({"path": path.relative_to(package).as_posix(),
                           "bytes": path.stat().st_size, "sha256": digest})
    return result


def diagnose(args):
    args.project = args.project.expanduser().resolve()
    args.output = args.output.expanduser().resolve()
    args.godot = str(Path(shutil.which(args.godot) or args.godot).expanduser().resolve())
    if args.output.is_relative_to(args.project):
        raise ValueError("Diagnostic exports and reports must be outside the source project")
    if args.output.exists() and (not args.output.is_dir() or any(args.output.iterdir())):
        raise ValueError("Choose a new output directory to preserve earlier evidence")
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "run-owner.json").write_text(json.dumps({
        "pid": os.getpid(), "started_unix": time.time(), "diagnostic_only": True}) + "\n")
    logs = args.output / "logs"
    logs.mkdir()
    package = args.output / "package"
    package.mkdir()
    source_run = SourceRun(args.project)
    source_run.begin_report(args.output)
    summary = {"diagnostic_only": True, "main_release_approved": False,
               "full_export_acceptance": False, "diagnostic_passed": False,
               "scope": "Only Windows release export and unchanged --frontend-smoke; no general export checks claimed.",
               "platform": "windows", "environment": platform.platform(), "godot": None,
               "source": SourceRun.summary(source_run.start), "checks": [], "export_files": []}

    def observe(phase, force=False):
        observation = source_run.observe(phase, force=force)
        if source_run.blocked:
            raise RuntimeError(f"Diagnostic source changed or became unavailable: {phase}")
        return observation

    def run(name, command, cwd, env=None, marker=None):
        observe("before_" + name)
        started = time.monotonic()
        try:
            process = subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                                     errors="replace", timeout=240)
            text, status = process.stdout, process.returncode
        except subprocess.TimeoutExpired as error:
            data = error.stdout or b""
            text = data.decode(errors="replace") if isinstance(data, bytes) else data
            text += "\nERROR: exported runtime timed out\n"
            status = 124
        except (OSError, KeyboardInterrupt) as error:
            text = f"ERROR: export process interrupted: {error}\n"
            status = 130 if isinstance(error, KeyboardInterrupt) else 127
        log = logs / f"{name}.log"
        log.write_text(text, encoding="utf-8")
        assessment = evaluate_log(status, text, marker, require_jump_observation=name == "packaged_frontend")
        observation = source_run.observe(name)
        result = {"name": name, **assessment,
                  "passed": assessment["process_passed"] and assessment.get("jump_observation_passed", True)
                            and not source_run.blocked,
                  "exit_code": status, "seconds": round(time.monotonic() - started, 3),
                  "command": command, "cwd": str(cwd), "timeout_seconds": 240,
                  "source_status": observation["status"],
                  "source_sha256": observation["source"].get("source_sha256"),
                  "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()}
        summary["checks"].append(result)
        print(json.dumps(result), flush=True)
        if not result["passed"]:
            print(text[-12000:], flush=True)
            raise RuntimeError(f"DIAGNOSTIC ONLY check failed: {name}")

    try:
        if os.name != "nt":
            raise ValueError("This diagnostic requires a native Windows runner")
        if source_run.blocked:
            raise RuntimeError("Source identity unavailable before diagnosis")
        version = subprocess.check_output([args.godot, "--version"], text=True, timeout=20).strip()
        summary["godot"] = version
        if not version.startswith(VERSION + ".stable."):
            raise ValueError(f"Expected pinned Godot {VERSION} stable, got {version}")
        observe("engine_version")
        run("import", [args.godot, "--headless", "--path", str(args.project), "--import"], args.project)
        preset, executable_name = PRESETS["windows"]
        executable = package / executable_name
        run("release_export", [args.godot, "--headless", "--path", str(args.project),
                               "--export-release", preset, str(executable)], args.project)
        summary["export_source"] = SourceRun.summary(source_run.current)
        if not executable.is_file() or not executable.with_suffix(".pck").is_file():
            raise RuntimeError("Release export did not produce both executable and PCK")
        summary["export_files"] = export_files(package)
        with tempfile.TemporaryDirectory(prefix="voxelverse-frontend-diagnostic-") as temporary:
            userdata = Path(temporary).resolve()
            if userdata.is_relative_to(args.project):
                raise RuntimeError("Diagnostic user data must be outside the source checkout")
            summary["user_data"] = {"isolated": True, "directory": str(userdata)}
            # Same release executable/arguments as validate_export.py; no source --path.
            run("packaged_frontend", [str(executable), "--headless", "--verbose", "--", "--frontend-smoke"],
                package, isolated_env(userdata), marker="FRONTEND_PASSED")
        if export_files(package) != summary["export_files"]:
            raise RuntimeError("Exported package changed during the diagnostic")
        summary["diagnostic_passed"] = True
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError, KeyboardInterrupt) as error:
        summary["error"] = str(error)
        print(str(error), file=sys.stderr)
    finally:
        source_run.observe("finish", force=True)
        summary["provenance"] = source_run.write_report(args.output)
        summary["diagnostic_passed"] &= not source_run.blocked and "error" not in summary
        summary["provenance"]["reusable"] &= summary["diagnostic_passed"]
        try:
            summary["export_files_after"] = export_files(package)
        except OSError as error:
            summary["export_files_after"] = []
            summary["export_hash_error"] = str(error)
            summary["diagnostic_passed"] = False
            summary["provenance"]["reusable"] = False
        (args.output / "export-files.json").write_text(json.dumps(summary["export_files_after"], indent=2) + "\n")
        (args.output / "results.json").write_text(json.dumps(summary, indent=2) + "\n")
        print(json.dumps({"diagnostic_only": True, "diagnostic_passed": summary["diagnostic_passed"],
                          "main_release_approved": False}), flush=True)
    return 0 if summary["diagnostic_passed"] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        return diagnose(args)
    except ValueError as error:
        parser.error(str(error))


if __name__ == "__main__":
    sys.exit(main())
