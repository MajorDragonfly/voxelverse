#!/usr/bin/env python3
"""Use the existing change selector for drafts; require full acceptance for code deliveries."""
import argparse
import json
import os
from pathlib import Path
import re

from check_validation_contracts import read_contracts
from validation_plan import build_plan, git

ROOT = Path(__file__).resolve().parents[1]


def plan(project, event_name, event):
    _, owners = read_contracts(project)
    selection = None
    draft = False
    if event_name == "pull_request":
        pull = event["pull_request"]
        base, head = pull["base"]["sha"], pull["head"]["sha"]
        if not all(re.fullmatch(r"[0-9a-f]{40}", sha) for sha in (base, head)):
            raise ValueError("Pull request must supply exact base and head commits")
        # checkout's merge tree must contain both sides; a head-only checkout is
        # not sufficient evidence for integration. Missing history fails closed.
        for sha in (base, head):
            git(project, "merge-base", "--is-ancestor", sha, "HEAD")
        selection = build_plan(project, base)
        draft = pull["draft"] is True
    docs = selection is not None and selection["scope"] in ("documentation", "unchanged")
    full = not docs and not draft
    tests = sorted(owners) if full or selection is None else selection["selected_tests"]
    mode = "documentation" if docs else "full" if full else "draft"
    # Even draft changes to shared/unknown infrastructure retain the selector's
    # full source/runtime checks. Graphics/exports wait for ready_for_review.
    runtime = full or bool(selection and selection["requires_main"])
    shards = [{"shard": i, "tests": tests[i::4]} for i in range(min(4, len(tests)))]
    return {"schema": 1, "mode": mode, "tests_executed": False,
            "head": git(project, "rev-parse", "HEAD").decode().strip(),
            "source": bool(tests), "runtime": runtime, "acceptance": full,
            "matrix": {"include": shards or [{"shard": 0, "tests": []}]},
            "selected_tests": len(tests), "registered_tests": len(owners),
            "selection": selection,
            "reason": {"documentation": "Only documented non-runtime paths changed.",
                       "draft": "Draft feedback uses contracts; ready code deliveries run every test.",
                       "full": "Ready PR, main or manual run: full source, runtime, graphics and exports."}[mode]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--event-name", default=os.environ.get("GITHUB_EVENT_NAME", "workflow_dispatch"))
    parser.add_argument("--event-file", type=Path, default=os.environ.get("GITHUB_EVENT_PATH"))
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    event = json.loads(args.event_file.read_text()) if args.event_file else {}
    result = plan(args.project.resolve(), args.event_name, event)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as stream:
            for name in ("source", "runtime", "acceptance", "matrix"):
                stream.write(name + "=" + json.dumps(result[name], separators=(",", ":")) + "\n")
            stream.write("mode=" + result["mode"] + "\n")
    summary = f"CI plan: {result['mode']}; {result['selected_tests']}/{result['registered_tests']} source tests. {result['reason']}"
    print(summary)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
            stream.write(summary + "\n\nThis is a plan, not a test result.\n")


if __name__ == "__main__":
    main()
