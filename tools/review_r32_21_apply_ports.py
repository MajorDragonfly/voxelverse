#!/usr/bin/env python3
"""Apply R32-21 owner attachments to an explicit QA/integration checkout.

The feature branch deliberately does not change the shared writers. Run on a
disposable checkout for verification, or let R32-01 apply these ports serially.
"""
import argparse
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    args = parser.parse_args()
    root = args.project.resolve()
    ports = Path(__file__).resolve().parents[1] / "docs/evidence/r32-21/ports"
    for name in ["village-owner.patch", "hud-owner.patch", "runner-owner.patch"]:
        patch = ports / name
        subprocess.run(["git", "apply", "--check", str(patch)], cwd=root, check=True)
        subprocess.run(["git", "apply", str(patch)], cwd=root, check=True)
    catalog = root / "localization/catalog.json"
    data = json.loads(catalog.read_text())
    additions = json.loads((ports / "localization-append.json").read_text())
    existing = {row["key"] for row in data["messages"]}
    if existing.intersection(row["key"] for row in additions):
        raise ValueError("Translation append already present; do not duplicate it")
    data["messages"].extend(additions)
    catalog.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    subprocess.run(["python3", "tools/localization/catalog.py"], cwd=root, check=True)
    registry = root / "tools/validation/contracts.json"
    data = json.loads(registry.read_text())
    append = json.loads((ports / "registry-append.json").read_text())
    contract = next(item for item in data["contracts"] if item["id"] == append["contract"])
    for test in append["tests"]:
        if any(test in item["tests"] for item in data["contracts"]):
            raise ValueError("Test already registered: " + test)
        contract["tests"].append(test)
    registry.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
