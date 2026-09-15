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
    from .check_validation_contracts import discover_tests, read_contracts
    from .validation_support import isolated_env, validation_editor
    from .validation_plan import build_plan
    from .validation_provenance import SourceRun, check_output_directory
else:
    from check_validation_contracts import discover_tests, read_contracts
    from validation_support import isolated_env, validation_editor
    from validation_plan import build_plan
    from validation_provenance import SourceRun, check_output_directory

# These acceptance flows include real 300-second production or 90-second growth
# plus transport and restart. Keep short checks bounded independently.
LONG_TESTS = {"settlement_runtime_test", "body_travel_test", "spherical_gameplay_test", "tribal_age_husbandry_test", "tribal_age_growth_test", "tribal_age_economy_test", "tribal_economy_progress_world_test"}

ERROR = re.compile(r"SCRIPT ERROR|(?:^|\n)ERROR:|Shader compilation failed|Parse Error|ObjectDB instances leaked at exit")


def select_contract_tests(project, names):
    """Use the existing ownership registry; reject typos instead of running nothing."""
    data, _ = read_contracts(project)
    contracts = {item["id"]: item["tests"] for item in data["contracts"]}
    unknown = sorted(set(names) - contracts.keys())
    if unknown:
        raise ValueError("Unknown contracts: " + ", ".join(unknown))
    if not names:
        raise ValueError("Select at least one contract")
    return sorted({test for name in names for test in contracts[name]})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, help="Log directory; omitted creates a unique temporary directory")
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--tests", nargs="*", help="Test basenames; omit to discover all tests")
    selection.add_argument("--contracts", nargs="+", help="Contract IDs from tools/validation/contracts.json")
    selection.add_argument("--changed-since", metavar="REF", help="Plan tests from the checkout versus this exact local Git commit, including staged/unstaged/untracked files")
    parser.add_argument("--plan", action="store_true", help="Print the --changed-since plan as JSON without starting tests or creating output")
    parser.add_argument("--list-tests", action="store_true", help="Print selection without starting Godot; not test evidence")
    parser.add_argument("--skip-import", action="store_true")
    parser.add_argument("--skip-main", action="store_true")
    args = parser.parse_args()
    args.project = args.project.expanduser().resolve()
    args.change_plan = None
    if args.plan and (args.changed_since is None or args.list_tests):
        parser.error("--plan requires --changed-since and cannot be combined with --list-tests")
    # Capture before selection so a later edit cannot silently stale a change plan.
    args.source_run = None if args.plan or args.list_tests else SourceRun(args.project)
    if args.changed_since is not None:
        try:
            args.change_plan = build_plan(args.project, args.changed_since)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            parser.error(str(error))
        args.tests = args.change_plan["selected_tests"]
        if args.plan:
            print(json.dumps(args.change_plan, ensure_ascii=True, indent=2))
            return 0
        if args.skip_main and args.change_plan["requires_main"] and not args.list_tests:
            parser.error("This change plan requires full main checks; inspect --plan. Use an explicit --contracts selection for a separately scoped diagnosis.")
        args.skip_main = not args.change_plan["requires_main"]
    if args.contracts is not None or args.list_tests:
        try:
            if args.contracts is not None:
                args.tests = select_contract_tests(args.project, args.contracts)
            else:
                _, owners = read_contracts(args.project)
                selected = args.tests if args.tests is not None else sorted(owners)
                unknown = sorted(set(selected) - owners.keys())
                if unknown:
                    raise ValueError("Unknown tests: " + ", ".join(unknown))
                args.tests = list(dict.fromkeys(selected))
        except (OSError, ValueError) as error:
            parser.error(str(error))
    if args.list_tests:
        print("\n".join(args.tests))
        return 0
    args.output = (args.output.expanduser().resolve() if args.output is not None
                   else Path(tempfile.mkdtemp(prefix="voxelverse-validation-")))
    try:
        check_output_directory(args.project, args.output)
    except ValueError as error:
        parser.error(str(error))
    print(f"Validation output: {args.output}", flush=True)
    if args.change_plan is not None and not args.tests:
        return validate(args)
    with validation_editor(args.godot) as editor:
        args.godot = str(editor)
        return validate(args)


def validate(args):
    check_output_directory(args.project, args.output)
    source_run = getattr(args, "source_run", None) or SourceRun(args.project)
    args.output.mkdir(parents=True, exist_ok=True)
    # Survives abrupt termination even when no final report can be written.
    (args.output / "source-start.json").write_text(json.dumps(source_run.start, indent=2) + "\n", encoding="utf-8")
    change_plan = getattr(args, "change_plan", None)
    source_only = change_plan is not None and not args.tests
    version = None if source_only else subprocess.check_output([args.godot, "--version"], text=True).strip()
    if version is not None and not version.startswith("4.6.3."):
        sys.exit(f"Expected Godot 4.6.3, got {version}")
    tests = args.tests if args.tests is not None else discover_tests(args.project)
    commands = [("source_contracts", [], 45)]
    if not args.skip_import and not source_only:
        commands.append(("import", ["--import"], 180))
        commands.append(("art_sources", [], 120))
    # SceneTree tests load gameplay scenes after autoloads exist, like the game.
    # The full sphere chain includes real taming/production, A-B-A with the held
    # animal, cold terrain loads and fresh processes on both sides of the trip.
    commands += [(name, ["--script", f"res://tests/{name}.gd"],
                  900 if name in {"spherical_gameplay_test", "spherical_egg_production_test"} else 420 if name in LONG_TESTS else 120) for name in tests]
    if not args.skip_main and not source_only:
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
        source_run.record("before:" + name)
        if not source_run.valid:
            break
        source_before = source_run.observations[-1]["snapshot"]
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
            except OSError as error:
                with log_path.open("ab") as stream:
                    stream.write(("\nERROR: could not start validation: " + str(error) + "\n").encode())
                status = 127
        log = log_path.read_text(encoding="utf-8", errors="replace")
        failed = status != 0 or ERROR.search(log) is not None
        kind = ("source_contract" if name in {"source_contracts", "art_sources"} else
                "editor_import" if name == "import" else "headless_godot")
        result = {"name": name, "kind": kind, "passed": not failed, "exit_code": status,
                  "seconds": round(time.monotonic() - started, 3), "command": argv, "timeout_seconds": timeout}
        source_run.record("after:" + name, allow_import_uids=name == "import" and not failed)
        result["source_before"] = source_before
        result["source_after"] = source_run.observations[-1]["snapshot"]
        if name in owners:
            result["contract"] = owners[name]
        results.append(result)
        print(json.dumps(result), flush=True)
        if failed or name == "streaming_cpu":
            print(log[-12000:], flush=True)
        if not source_run.valid:
            break
        if name in {"source_contracts", "import"} and failed:
            break
        if name == "source_contracts":
            try:
                _, owners = read_contracts(args.project)
            except (OSError, ValueError) as error:
                results.append({"name": "test_selection", "kind": "source_contract", "passed": False,
                                "error": str(error)})
                break
            unknown = sorted(set(tests) - owners.keys())
            if unknown:
                results.append({"name": "test_selection", "kind": "source_contract", "passed": False,
                                "error": "Unknown tests: " + ", ".join(unknown)})
                print(json.dumps(results[-1]), flush=True)
                break
    source_run.record("run_end")
    completed = {r["name"] for r in results}
    unexecuted = [name for name, _, _ in commands if name not in completed]
    checks_passed = bool(results) and not unexecuted and all(r["passed"] for r in results)
    passed = checks_passed and source_run.valid
    print(json.dumps({"kind": "source_provenance", "status": source_run.status,
                      "passed": source_run.valid, "events": source_run.events}), flush=True)
    (args.output / "results.json").write_text(json.dumps({"godot": version, "source": source_run.start,
        "execution": "source_only" if source_only else "headless_source_project", "selected_tests": tests,
        "change_plan": change_plan, "checks": results, "checks_passed": checks_passed, "passed": passed,
        "unexecuted_checks": unexecuted, "source_provenance": source_run.report()}, indent=2) + "\n", encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
