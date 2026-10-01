#!/usr/bin/env python3
"""Use the existing change selector for drafts; require full acceptance for code deliveries."""
import argparse
import json
import math
import os
from pathlib import Path
import re

from check_validation_contracts import read_contracts
from validation_plan import build_plan, git

ROOT = Path(__file__).resolve().parents[1]
TIMING_PROFILE = Path("tools/validation/source_timings.json")
SOURCE_SHARDS = 4
# A new/unmeasured test may contain a full production/restart journey. Use the
# longest existing source deadline as its scheduling weight, never as a timeout.
UNKNOWN_TEST_SECONDS = 900.0


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate timing profile key: " + key)
        result[key] = value
    return result


def read_timings(project):
    """Historical durations influence order only; invalid profiles fail closed."""
    try:
        data = json.loads((project / TIMING_PROFILE).read_text(encoding="utf-8"),
                          object_pairs_hook=_unique_object)
        if not isinstance(data, dict) or type(data.get("schema")) is not int or data["schema"] != 1:
            raise ValueError("Expected timing profile schema 1")
        source = data.get("source")
        if not isinstance(source, dict):
            raise ValueError("Timing profile requires source provenance")
        for name in ("commit", "tree"):
            if not isinstance(source.get(name), str) or not re.fullmatch(r"[0-9a-f]{40}", source[name]):
                raise ValueError("Invalid timing source " + name)
        if (type(source.get("workflow_run_id")) is not int or source["workflow_run_id"] <= 0
                or not isinstance(source.get("runner"), str) or not source["runner"]
                or not isinstance(source.get("godot"), str) or not source["godot"].startswith("4.6.3.")):
            raise ValueError("Timing profile requires the measured engine, runner and CI run")
        artifacts = source.get("artifacts")
        if not isinstance(artifacts, list) or not artifacts:
            raise ValueError("Timing profile requires measured artifact identities")
        for artifact in artifacts:
            if not isinstance(artifact, dict):
                raise ValueError("Invalid timing artifact identity")
            path, checksum = artifact.get("path"), artifact.get("sha256")
            if (not isinstance(path, str) or not path or Path(path).is_absolute()
                    or ".." in Path(path).parts or not isinstance(checksum, str)
                    or not re.fullmatch(r"[0-9a-f]{64}", checksum)):
                raise ValueError("Invalid timing artifact path/checksum")
        timings = data.get("seconds")
        if not isinstance(timings, dict) or not timings:
            raise ValueError("Timing profile requires measured test durations")
        for name, seconds in timings.items():
            if (not re.fullmatch(r"[A-Za-z0-9_]+(?:/[A-Za-z0-9_]+)*_test", name)
                    or type(seconds) not in (int, float) or not math.isfinite(seconds)
                    or not 0 < seconds <= 86400):
                raise ValueError("Invalid measured duration for " + name)
        return timings
    except (OSError, ValueError) as error:
        raise ValueError("Cannot use source timing profile: " + str(error)) from error


def source_shards(tests, timings):
    """Balance four disjoint shards, retaining every selected check exactly once."""
    if len(tests) != len(set(tests)):
        raise ValueError("Source test selection contains duplicates")
    count = min(SOURCE_SHARDS, len(tests))
    shards = [{"shard": i, "tests": []} for i in range(count)]
    loads = [0.0] * count
    for name in sorted(tests, key=lambda name: (-timings.get(name, UNKNOWN_TEST_SECONDS), name)):
        index = min(range(count), key=lambda i: (loads[i], i))
        shards[index]["tests"].append(name)
        loads[index] += timings.get(name, UNKNOWN_TEST_SECONDS)
    return shards, [round(value, 3) for value in loads]


def plan(project, event_name, event):
    _, owners = read_contracts(project)
    timings = read_timings(project)
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
    shards, loads = source_shards(tests, timings)
    return {"schema": 1, "mode": mode, "tests_executed": False,
            "head": git(project, "rev-parse", "HEAD").decode().strip(),
            "source": bool(tests), "runtime": runtime, "acceptance": full,
            "matrix": {"include": shards or [{"shard": 0, "tests": []}]},
            "scheduling": {"algorithm": "largest_estimated_duration_first", "shards": len(shards),
                           "timing_profile": str(TIMING_PROFILE), "estimated_shard_seconds": loads,
                           "measured_tests": sum(test in timings for test in tests),
                           "unknown_test_seconds": UNKNOWN_TEST_SECONDS},
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
    loads = result["scheduling"]["estimated_shard_seconds"]
    if loads:
        summary += (f" {len(loads)} source shards; historical scheduling estimate "
                    f"{min(loads) / 60:.1f}-{max(loads) / 60:.1f} minutes, excluding setup. "
                    "Actual CI duration is not yet measured for this tree.")
    print(summary)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
            stream.write(summary + "\n\nThis is a plan, not a test result.\n")


if __name__ == "__main__":
    main()
