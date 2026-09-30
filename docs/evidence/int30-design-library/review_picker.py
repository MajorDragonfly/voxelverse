#!/usr/bin/env python3
"""Render the real picker inputs; isolate saves and require actual images.

Use under an existing DISPLAY, or --xvfb /path/to/Xvfb for portable TCP X11.
Companion catalog/registry patches belong to Chat 1; this tool changes neither.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / "tools"))
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--project", type=Path, default=PROJECT)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--renderer", default="gl_compatibility", choices=["gl_compatibility", "forward_plus"])
    parser.add_argument("--xvfb", type=Path)
    parser.add_argument("--display-number", type=int, default=214)
    parser.add_argument("--editor", action="store_true", help="Run existing real editor/new-game consumer, too")
    parser.add_argument("--timeout", type=int, choices=[300, 600], default=300, help="Bound each unchanged case; 600 is for an explicitly recorded loaded-host diagnosis")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    server = None
    with validation_editor(args.godot) as godot, tempfile.TemporaryDirectory(prefix="int30-picker-") as temporary:
        environment = isolated_env(Path(temporary))
        environment["LIBGL_ALWAYS_SOFTWARE"] = "1"
        if args.xvfb:
            environment["DISPLAY"] = f"127.0.0.1:{args.display_number}.0"
            server_log = (output / "display.log").open("w")
            server = subprocess.Popen([str(args.xvfb), f":{args.display_number}", "-screen", "0", "1920x1080x24", "-nolisten", "unix", "-nolisten", "local", "-listen", "tcp", "-ac"], env=environment, stdout=server_log, stderr=subprocess.STDOUT)
            time.sleep(0.5)
            if server.poll() is not None:
                raise RuntimeError("Portable X11 failed; see display.log")
        records = []
        try:
            cases = [("picker", "int30_design_library_picker_test", "INT30_DESIGN_LIBRARY_RESULT ", 9)]
            if args.editor:
                cases.append(("editor", "creature_library_ui_test", "CREATURE_LIBRARY_UI_PASSED", 9))
            for name, script, marker, count in cases:
                directory = output / name
                directory.mkdir()
                command = [str(godot), "--path", str(args.project.resolve()), "--rendering-method", args.renderer, "--audio-driver", "Dummy", "--script", f"res://tests/{script}.gd", "--", "--capture", str(directory)]
                start = time.monotonic()
                with (directory / "render.log").open("w") as log:
                    try:
                        result = subprocess.run(command, env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout)
                        exit_code = result.returncode
                    except subprocess.TimeoutExpired:
                        exit_code = 124
                        log.write("\nERROR: render case exceeded its recorded budget\n")
                log_text = (directory / "render.log").read_text()
                images = sorted(directory.glob("*.png"))
                passed = exit_code == 0 and not ERROR.search(log_text) and marker in log_text and len(images) >= count
                record = {"case": name, "passed": bool(passed), "exit_code": exit_code, "budget_seconds": args.timeout, "seconds": round(time.monotonic() - start, 3), "command": command, "renderer": args.renderer, "screenshots": [str(p.relative_to(output)) for p in images]}
                records.append(record)
                print(json.dumps(record), flush=True)
                if not passed:
                    print(log_text[-5000:], flush=True)
            (output / "results.json").write_text(json.dumps({"passed": all(r["passed"] for r in records), "records": records}, indent=2) + "\n")
            return 0 if all(r["passed"] for r in records) else 1
        finally:
            if server:
                server.terminate()
                server.wait(timeout=10)
                server_log.close()


if __name__ == "__main__":
    raise SystemExit(main())
