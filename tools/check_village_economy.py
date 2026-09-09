#!/usr/bin/env python3
"""Exercise the M6 village in real Godot processes with isolated campaign saves."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, default=Path(tempfile.gettempdir()) / "voxelverse-m6-checks")
    parser.add_argument("--skip-import", action="store_true")
    parser.add_argument("--only", nargs="+", help="Run named checks (restart checks need their preceding save-group check).")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    checks = [] if args.skip_import else [("import", ["--import"], "import")]
    checks += [(name, ["--script", "res://tests/" + name + ".gd"], name) for name in
               ["tribal_age_economy_contract_test", "tribal_age_growth_contract_test", "tribal_age_husbandry_contract_test", "tribal_age_housing_recovery_test", "tribal_age_test", "tribal_age_supply_test", "tribal_age_economy_test"]]
    checks += [("husbandry", ["--script", "res://tests/tribal_age_husbandry_test.gd"], "husbandry"),
               ("husbandry_restart", ["--script", "res://tests/tribal_age_husbandry_test.gd", "--", "--restart-check"], "husbandry")]
    checks += [("growth", ["--script", "res://tests/tribal_age_growth_test.gd"], "growth"),
               ("growth_restart", ["--script", "res://tests/tribal_age_growth_test.gd", "--", "--restart-check"], "growth")]
    checks += [("world", ["--script", "res://tests/tribal_age_world_test.gd", "--", "--economy", "--housing"], "world"),
               ("restart", ["--script", "res://tests/tribal_age_world_test.gd", "--", "--restart-check", "--economy", "--housing"], "world")]
    if args.only:
        unknown = set(args.only) - {name for name, _, _ in checks}
        if unknown:
            parser.error("Unknown check(s): " + ", ".join(sorted(unknown)))
        checks = [check for check in checks if check[0] in args.only]
    results = []
    with tempfile.TemporaryDirectory(prefix="voxelverse-m6-") as scratch:
        for name, argv, save_group in checks:
            started = time.monotonic()
            env = {**os.environ, "XDG_DATA_HOME": str(Path(scratch) / save_group)}
            try:
                run = subprocess.run([args.godot, "--headless", "--path", str(args.project), *argv],
                                     env=env, capture_output=True, text=True, timeout=420)
                output, code = run.stdout + run.stderr, run.returncode
            except subprocess.TimeoutExpired as exc:
                output, code = (exc.stdout or b"").decode(errors="replace") + "\nERROR: timeout", 124
            failed = code != 0 or re.search(r'SCRIPT ERROR|ERROR:|Parse Error|ObjectDB instances leaked|"passed":false', output)
            if name != "import" and '"passed":true' not in output:
                failed = True
            (args.output / (name + ".log")).write_text(output)
            result = {"name": name, "passed": not bool(failed), "exit_code": code,
                      "seconds": round(time.monotonic() - started, 2)}
            results.append(result)
            print(json.dumps(result), flush=True)
            if failed:
                print(output[-10000:], flush=True)
                break
    (args.output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return int(any(not result["passed"] for result in results))


if __name__ == "__main__":
    raise SystemExit(main())
