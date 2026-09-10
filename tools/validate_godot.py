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

if __package__:
    from .check_validation_contracts import discover_tests, read_contracts, revision
    from .validation_support import isolated_env, validation_editor
else:
    from check_validation_contracts import discover_tests, read_contracts, revision
    from validation_support import isolated_env, validation_editor

# These acceptance flows include real 300-second production or 90-second growth
# plus transport and restart. Keep short checks bounded independently.
LONG_TESTS = {"body_travel_test", "spherical_gameplay_test", "tribal_age_husbandry_test", "tribal_age_growth_test", "tribal_age_economy_test", "tribal_economy_progress_world_test"}

ERROR = re.compile(r"SCRIPT ERROR|(?:^|\n)ERROR:|Shader compilation failed|Parse Error|ObjectDB instances leaked at exit")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, help="Log directory; omitted creates a unique temporary directory")
    parser.add_argument("--tests", nargs="*", help="Test basenames; omit to discover all tests")
    parser.add_argument("--skip-import", action="store_true")
    parser.add_argument("--skip-main", action="store_true")
    args = parser.parse_args()
    args.project = args.project.expanduser().resolve()
    args.output = (args.output.expanduser().resolve() if args.output is not None
                   else Path(tempfile.mkdtemp(prefix="voxelverse-validation-")))
    print(f"Validation output: {args.output}", flush=True)
    with validation_editor(args.godot) as editor:
        args.godot = str(editor)
        return validate(args)


def validate(args):
    args.output.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not version.startswith("4.6.3."):
        sys.exit(f"Expected Godot 4.6.3, got {version}")
    tests = args.tests if args.tests is not None else discover_tests(args.project)
    commands = [("source_contracts", [], 45)]
    if not args.skip_import:
        commands.append(("import", ["--import"], 180))
        commands.append(("art_sources", [], 120))
    # SceneTree tests load gameplay scenes after autoloads exist, like the game.
    # The full sphere chain includes several cold terrain loads and a native
    # child restart; successful Windows runs already take about 395 seconds.
    commands += [(name, ["--script", f"res://tests/{name}.gd"],
                  600 if name == "spherical_gameplay_test" else 420 if name in LONG_TESTS else 120) for name in tests]
    if not args.skip_main:
        commands.append(("planet_lab_entry", ["--", "--planet-lab", "--runtime-exit-frames", "600"], 120))
        for frames in [45, 150, 300]:
            name = "main" if frames == 300 else f"main_shutdown_{frames}"
            commands.append((name, ["res://core/diagnostics/legacy_world.tscn", "--", "--runtime-exit-frames", str(frames)], 120))
        # Stop the real scene at resource-owning stages, not only arbitrary frames.
        # Separate processes keep the resource cache cold for every case.
        for seed in [15838, 63352, 23757]:
            for stage in ["terrain", "placement", "resources", "complete", "cluster_build", "cluster_complete"]:
                name = f"shutdown_{seed}_{stage}"
                commands.append((name, ["--verbose", "--script", "res://tools/main_shutdown_probe.gd",
                                        "--", str(seed), stage], 120))
        commands.append(("streaming_cpu", ["--script", "res://tools/benchmark_streaming.gd", "--",
                                           "--report", str(args.output / "streaming_cpu_measurements.json")], 120))
    results, owners = [], {}
    for name, command, timeout in commands:
        started = time.monotonic()
        log_path = args.output / f"{name.replace(chr(47), chr(95))}.log"
        with tempfile.TemporaryDirectory(prefix="voxelverse-test-") as userdata:
            env = isolated_env(Path(userdata))
            try:
                if name == "source_contracts":
                    argv = [sys.executable, str(args.project / "tools/check_validation_contracts.py"),
                            "--project", str(args.project), "--output", str(args.output / "contracts.json")]
                elif name == "art_sources":
                    argv = [sys.executable, str(args.project / "tools/art/export_benchmark_source.py"), "--check"]
                else:
                    argv = [args.godot, "--headless", "--verbose", "--path", str(args.project), *command]
                # Long travel/restart probes expose progress while they run;
                # strict validation still inspects the complete final log.
                with log_path.open("wb") as stream:
                    process = subprocess.run(argv, stdout=stream, stderr=subprocess.STDOUT,
                                             env=env, timeout=timeout)
                status = process.returncode
            except subprocess.TimeoutExpired:
                with log_path.open("ab") as stream:
                    stream.write(b"\nERROR: validation timed out\n")
                status = 124
        log = log_path.read_text(encoding="utf-8", errors="replace")
        failed = status != 0 or ERROR.search(log) is not None
        kind = ("source_contract" if name in {"source_contracts", "art_sources"} else
                "editor_import" if name == "import" else "headless_godot")
        result = {"name": name, "kind": kind, "passed": not failed, "exit_code": status,
                  "seconds": round(time.monotonic() - started, 3)}
        if name in owners:
            result["contract"] = owners[name]
        results.append(result)
        print(json.dumps(result), flush=True)
        if failed or name == "streaming_cpu":
            print(log[-12000:], flush=True)
        if name in {"source_contracts", "import"} and failed:
            break
        if name == "source_contracts":
            _, owners = read_contracts(args.project)
            unknown = sorted(set(tests) - owners.keys())
            if unknown:
                results.append({"name": "test_selection", "kind": "source_contract", "passed": False,
                                "error": "Unknown tests: " + ", ".join(unknown)})
                print(json.dumps(results[-1]), flush=True)
                break
    (args.output / "results.json").write_text(json.dumps({"godot": version, "source": revision(args.project),
        "execution": "headless_source_project", "selected_tests": tests, "checks": results}, indent=2) + "\n", encoding="utf-8")
    return 1 if any(not r["passed"] for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
