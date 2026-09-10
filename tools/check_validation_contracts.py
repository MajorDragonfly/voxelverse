#!/usr/bin/env python3
"""Check test ownership and generated translations without starting Godot.

This is source evidence only. Registered gameplay tests are still discovered
and executed by validate_godot; pending scenarios are never reported as passes.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = Path("tools/validation/contracts.json")
TEST_NAME = re.compile(r"(?:[a-zA-Z0-9_-]+/)*[a-zA-Z0-9_-]+_test")


def discover_tests(project):
    return sorted(path.relative_to(project / "tests").with_suffix("").as_posix()
                  for path in (project / "tests").rglob("*_test.gd"))


def read_contracts(project):
    data = json.loads((project / MANIFEST).read_text(encoding="utf-8"))
    if not isinstance(data, dict) or type(data.get("schema")) is not int or data["schema"] != 1:
        raise ValueError("Unsupported validation contract schema")
    errors, owners, ids = [], {}, set()
    contracts = data.get("contracts")
    if not isinstance(contracts, list) or not contracts:
        raise ValueError("No validation contracts registered")
    for contract in contracts:
        if not isinstance(contract, dict):
            raise ValueError("Contract must be an object")
        for key in ["id", "title", "work"]:
            if not isinstance(contract.get(key), str) or not contract[key].strip():
                raise ValueError(f"Contract requires {key}")
        name = contract["id"]
        if name in ids:
            errors.append(f"Duplicate contract: {name}")
        ids.add(name)
        tests = contract.get("tests")
        if not isinstance(tests, list) or not tests:
            raise ValueError(f"Contract {name} has no tests")
        for test in tests:
            if not isinstance(test, str) or not TEST_NAME.fullmatch(test):
                raise ValueError(f"Invalid test name in {name}: {test!r}")
            if test in owners:
                errors.append(f"Duplicate test owner: {test} ({owners[test]}, {name})")
            owners[test] = name
    discovered = set(discover_tests(project))
    errors.extend(f"Unregistered test: {test}" for test in sorted(discovered - owners.keys()))
    errors.extend(f"Missing test: {test}" for test in sorted(owners.keys() - discovered))
    scenarios = data.get("scenarios")
    if not isinstance(scenarios, list) or not scenarios:
        raise ValueError("No acceptance scenarios registered")
    ids.clear()
    for scenario in scenarios:
        if not isinstance(scenario, dict):
            raise ValueError("Scenario must be an object")
        for key in ["id", "scope", "limits"]:
            if not isinstance(scenario.get(key), str) or not scenario[key].strip():
                raise ValueError(f"Scenario requires {key}")
        name = scenario["id"]
        if name in ids:
            errors.append(f"Duplicate scenario: {name}")
        ids.add(name)
        status, tests = scenario.get("status"), scenario.get("tests")
        if not isinstance(status, str) or status not in {"pending", "partial", "implemented"}:
            raise ValueError(f"Invalid scenario status: {name}")
        if not isinstance(tests, list) or any(not isinstance(t, str) for t in tests):
            raise ValueError(f"Invalid scenario tests: {name}")
        if len(tests) != len(set(tests)):
            errors.append(f"Duplicate scenario test: {name}")
        if (status == "pending") != (not tests):
            errors.append(f"Pending scenarios need no tests; other scenarios need evidence: {name}")
        errors.extend(f"Unknown scenario test: {name}: {test}" for test in tests if test not in owners)
    if errors:
        raise ValueError("\n".join(errors))
    return data, owners


def revision(project):
    """A source revision identifies the run, never a successful remote CI result."""
    try:
        sha = subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"],
                                      text=True, stderr=subprocess.DEVNULL, timeout=10).strip()
        status = subprocess.check_output(["git", "-C", str(project), "status", "--porcelain",
                                          "--untracked-files=no"], text=True,
                                         stderr=subprocess.DEVNULL, timeout=10)
        return {"commit": sha, "tracked_worktree_dirty": bool(status)}
    except (OSError, subprocess.SubprocessError):
        return {"commit": None, "tracked_worktree_dirty": None}


def check(project):
    data, owners = read_contracts(project)
    # Run the existing generator in read-only mode, including with --skip-import.
    result = subprocess.run([sys.executable, "-I", str(project / "tools/localization/catalog.py"), "--check"],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
    if result.returncode:
        raise ValueError("Localization catalog check failed:\n" + result.stdout)
    return {"schema": 1, "kind": "source_contract", "source": revision(project),
            "contracts": len(data["contracts"]), "registered_tests": len(owners),
            "catalog": result.stdout.strip(), "scenarios": data["scenarios"],
            "scenario_counts": dict(Counter(s["status"] for s in data["scenarios"]))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, help="Optional JSON report, including failures")
    args = parser.parse_args()
    try:
        report = check(args.project.expanduser().resolve())
        report["passed"] = True
        print(report["catalog"])
        print(f"VALIDATION_CONTRACTS_PASSED: {report['registered_tests']} tests, "
              f"{report['contracts']} contracts; scenarios={report['scenario_counts']} (not executed)")
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        report = {"schema": 1, "kind": "source_contract", "passed": False, "error": str(error)}
        print("VALIDATION_CONTRACTS_FAILED: " + str(error), file=sys.stderr)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
