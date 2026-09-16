#!/usr/bin/env python3
"""Install the reviewed main ruleset and enable native auto-merge using an authenticated gh CLI."""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REPO = "MajorDragonfly/voxelverse"


def matches(actual, desired):
    """GitHub can add default object fields and reorder rules on read-back."""
    if isinstance(desired, dict):
        return isinstance(actual, dict) and all(key in actual and matches(actual[key], value) for key, value in desired.items())
    if isinstance(desired, list):
        return isinstance(actual, list) and len(actual) == len(desired) and all(
            any(matches(item, expected) for item in actual) for expected in desired)
    return type(actual) is type(desired) and actual == desired


def api(path, method="GET", data=None):
    command = ["gh", "api", "--method", method, f"repos/{REPO}/{path}".rstrip("/")]
    if data is not None:
        command += ["--input", "-"]
    result = subprocess.run(command, input=json.dumps(data) if data is not None else None,
                            text=True, capture_output=True, check=True, timeout=30)
    return json.loads(result.stdout) if result.stdout.strip() else None


def configure(apply=False, request=api):
    desired = json.loads((ROOT / "tools/workflow/main-ruleset.json").read_text())
    settings = {"allow_auto_merge": True, "allow_update_branch": True}
    # Default is a fully reviewable offline plan. It does not change permissions.
    if not apply:
        return {"repository": REPO, "settings": settings, "ruleset": desired, "applied": False}
    repo = request("")
    if repo["default_branch"] != "main" or not repo.get("permissions", {}).get("admin"):
        raise ValueError("An authenticated repository administrator for main is required")
    # Install only after the new stable gates have appeared on main; otherwise
    # a typo or a pre-integration application could block every PR.
    checks = request("commits/main/check-runs?filter=latest&per_page=100")
    available = {c["name"] for c in checks["check_runs"] if c.get("app", {}).get("id") == 15368}
    required = {c["context"] for c in desired["rules"][-1]["parameters"]["required_status_checks"]}
    if not required <= available:
        raise ValueError("First integrate and run the new CI gates: " + ", ".join(sorted(required - available)))
    rules = request("rulesets?per_page=100")
    if len(rules) >= 100:
        raise ValueError("Unexpected ruleset count; inspect before updating")
    named_rules = [r for r in rules if r["name"] == desired["name"]]
    if len(named_rules) > 1:
        raise ValueError("Duplicate named rulesets require manual reconciliation")
    if named_rules:
        previous = request(f"rulesets/{named_rules[0]['id']}")
        if not matches(previous, desired):
            raise ValueError("An existing rule with this name differs; preserving it for review")
        saved = previous
    else:
        saved = request("rulesets", "POST", desired)
    # Protection comes first. Auto-merge never waits for optional checks alone.
    request("", "PATCH", settings)
    actual_rule = request(f"rulesets/{saved['id']}")
    actual_repo = request("")
    if not matches(actual_rule, desired):
        raise ValueError("Ruleset read-back differs from the reviewed configuration")
    if not all(actual_repo.get(key) == value for key, value in settings.items()):
        raise ValueError("Repository settings were not applied")
    return {"repository": REPO, "ruleset_id": saved["id"], "settings": settings, "applied": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    try:
        print(json.dumps(configure(args.apply), indent=2))
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        parser.exit(2, f"GitHub configuration not completed: {error}\n")


if __name__ == "__main__":
    main()
