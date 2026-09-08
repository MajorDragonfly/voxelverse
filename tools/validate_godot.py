#!/usr/bin/env python3
"""Run real Godot entry points with timeouts, isolated saves and strict log checks."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

ERROR = re.compile(r"SCRIPT ERROR|(?:^|\n)ERROR:|Shader compilation failed|Parse Error|ObjectDB instances leaked at exit")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, default=Path(tempfile.gettempdir()) / "voxelverse-validation")
    parser.add_argument("--tests", nargs="*", help="Test basenames; omit to discover all tests")
    parser.add_argument("--skip-import", action="store_true")
    parser.add_argument("--skip-main", action="store_true")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not version.startswith("4.6.3."):
        sys.exit(f"Expected Godot 4.6.3, got {version}")
    tests = args.tests if args.tests is not None else [p.stem for p in sorted((args.project / "tests").glob("*.gd"))]
    commands = [] if args.skip_import else [("import", ["--import"], 180)]
    if not args.skip_import:
        commands.append(("art_sources", [], 120))
    # SceneTree tests load gameplay scenes after autoloads exist, like the game.
    commands += [(name, ["--script", f"res://tests/{name}.gd"], 120) for name in tests]
    if not args.skip_main:
        for frames in [45, 150, 300]:
            name = "main" if frames == 300 else f"main_shutdown_{frames}"
            commands.append((name, ["--verbose", "--quit-after", str(frames)], 120))
        # Stop the real scene at resource-owning stages, not only arbitrary frames.
        # Separate processes keep the resource cache cold for every case.
        for seed in [15838, 63352, 23757]:
            for stage in ["terrain", "placement", "resources", "complete", "cluster_build", "cluster_complete"]:
                name = f"shutdown_{seed}_{stage}"
                commands.append((name, ["--verbose", "--script", "res://tools/main_shutdown_probe.gd",
                                        "--", str(seed), stage], 120))
        commands.append(("streaming_cpu", ["--script", "res://tools/benchmark_streaming.gd"], 120))
    results = []
    for name, command, timeout in commands:
        started = time.monotonic()
        with tempfile.TemporaryDirectory(prefix="voxelverse-test-") as userdata:
            env = os.environ.copy()
            env["XDG_DATA_HOME"] = userdata
            try:
                argv = ([sys.executable, str(args.project / "tools/art/export_benchmark_source.py"), "--check"]
                        if name == "art_sources" else [args.godot, "--headless", "--path", str(args.project), *command])
                process = subprocess.run(argv,
                                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                         text=True, env=env, timeout=timeout)
                log, status = process.stdout, process.returncode
            except subprocess.TimeoutExpired as exc:
                log = (exc.stdout or b"").decode(errors="replace") + "\nERROR: validation timed out\n"
                status = 124
        (args.output / f"{name}.log").write_text(log)
        failed = status != 0 or ERROR.search(log) is not None
        result = {"name": name, "passed": not failed, "exit_code": status,
                  "seconds": round(time.monotonic() - started, 3)}
        results.append(result)
        print(json.dumps(result), flush=True)
        if failed or name == "streaming_cpu":
            print(log[-12000:], flush=True)
        if name == "import" and failed:
            break
    (args.output / "results.json").write_text(json.dumps({"godot": version, "checks": results}, indent=2) + "\n")
    return 1 if any(not r["passed"] for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
