#!/usr/bin/env python3
"""Offline verification of preserved exact-tree FULL CI; does not rerun Godot."""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parent
SUPPORT = {"source_contracts", "import", "art_sources", "source_integrity"}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    meta = json.loads((ROOT / "manifest.json").read_text())
    query = json.loads((ROOT / meta["retrieval"]["request_file"]).read_text())
    assert query["request"] == {"commit_sha": meta["head"], "repo_full_name": meta["repository"]}
    queried_runs = query["response"]["structuredContent"]["workflow_runs"]
    expected_gates = {
        "Godot validation gate": 36824683190,
        "Desktop export gate": 36824683231,
        "Environment render gate": 36824683225,
        "Project dashboard gate": 36824683092,
    }
    gates = []
    for name, run_id in expected_gates.items():
        record = next(x for x in meta["gates"] if x["run_id"] == run_id)
        found = [j for j in record["jobs"] if j["name"] == name]
        assert len(found) == 1 and found[0]["status"] == "completed" and found[0]["conclusion"] == "success", name
        run = next(x for x in meta["workflow_runs"] if x["id"] == run_id)
        assert run["status"] == "completed" and run["conclusion"] == "success", name
        assert run == next(x for x in queried_runs if x["id"] == run_id), name
        gates.append({"name": name, "run_id": run_id, "job_id": found[0]["id"]})

    opened, reports = {}, {}
    assert len(meta["artifacts"]) == 8
    for spec in meta["artifacts"]:
        data = (ROOT / spec["bundle_path"]).read_bytes()
        api = spec["artifact"]
        assert digest(data) == api["digest"].removeprefix("sha256:"), spec["label"]
        assert len(data) == api["size_in_bytes"], spec["label"]
        assert api["workflow_run"]["head_sha"] == meta["head"] and api["workflow_run"]["id"] == spec["run"]
        opened[spec["label"]] = ZipFile(ROOT / spec["bundle_path"])

    plan = json.loads(opened["plan"].read("ci-plan.json"))
    assert plan["mode"] == "full" and plan["source"] and plan["runtime"] and plan["acceptance"]
    assert plan["head"] == meta["ci_merge"] and plan["registered_tests"] == plan["selected_tests"] == 266
    planned = [t for s in plan["matrix"]["include"] for t in s["tests"]]
    assert len(planned) == len(set(planned)) == 266
    assert [len(s["tests"]) for s in plan["matrix"]["include"]] == [67, 67, 66, 66]

    reference = opened["runtime"].read("source-files-start.jsonl")
    manifest_sha = digest(reference)
    actual, logs, packages, details = [], 0, {}, []
    for spec in meta["artifacts"]:
        if spec["kind"] == "plan":
            continue
        z = opened[spec["label"]]
        result = json.loads(z.read("results.json"))
        reports[spec["label"]] = result
        assert result["passed"] and result["godot"].startswith("4.6.3.")
        assert all(x["passed"] for x in result["checks"])
        names = [x["name"] for x in result["checks"]]
        assert len(names) == len(set(names))
        source, provenance = result["source"], result["provenance"]
        for state in (source, provenance["start"], provenance["end"]):
            assert state["complete"] and not state["tracked_worktree_dirty"]
            assert state["commit"] == meta["ci_merge"] and state["tree"] == meta["tree"]
            assert state["source_sha256"] == meta["source_sha256"] and state["file_count"] == 5400
        assert provenance["reusable"] and provenance["status"] == "prepared"
        for record in provenance["manifests"].values():
            assert record["sha256"] == manifest_sha
            if spec["kind"] != "export":
                assert z.read(record["path"]) == reference
        for check in result["checks"]:
            if "source_sha256" in check:
                assert check["source_sha256"] == meta["source_sha256"]
            if "log_sha256" in check:
                prefix = "logs/" if spec["kind"] == "export" else ""
                log = prefix + check["name"].replace("/", "_") + ".log"
                assert digest(z.read(log)) == check["log_sha256"], check["name"]
                logs += 1
        if spec["kind"] == "source":
            chosen = result["selected_tests"]
            assert set(chosen) == set(plan["matrix"]["include"][spec["shard"]]["tests"])
            assert set(names) - SUPPORT == set(chosen)
            actual.extend(chosen)
            details.append({"shard": spec["shard"], "actual_tests": len(chosen), "passed": True})
        elif spec["kind"] == "runtime":
            assert len(result["checks"]) == 27 and result["selected_tests"] == []
        elif spec["kind"] == "export":
            assert result["complete"] and len(result["checks"]) == 41
            assert len(result["probes"]) == 3 and all(p["passed"] for p in result["probes"])
            # CI diagnostics omit manifest payloads and package bytes. Their
            # manifest references match the preserved runtime/source payload;
            # accepted package identity is a CI report, not a rehashed binary.
            assert not any("source-files-" in p for p in z.namelist())
            packages[spec["label"]] = result["archive"]
    assert len(actual) == len(set(actual)) == 266 and set(actual) == set(planned)
    assert logs == 384

    render_jobs = next(x for x in meta["gates"] if x["run_id"] == 36824683225)["jobs"]
    review_steps = {
        "environment": "Render world, assets, Far clusters and creature comparisons",
        "resources": "Render procedural food and home meshes",
        "planets": "Render underwater optics, voxel planets, orbit and system",
        "spherical_campaign": "Render shared spherical creature, editor and freshwater flow",
    }
    capture_names = set()
    for renderer in ("forward_plus", "gl_compatibility"):
        for review, step_name in review_steps.items():
            name = f"capture ({renderer}, {review})"
            job = next(x for x in render_jobs if x["name"] == name)
            assert job["status"] == "completed" and job["conclusion"] == "success"
            step = next(x for x in job["steps"] if x["name"] == step_name)
            assert step["status"] == "completed" and step["conclusion"] == "success"
            capture_names.add(name)
    render_artifacts = [a for a in meta["render_artifacts"] if not a["name"].startswith("ci-plan-")]
    assert len(render_artifacts) == 8
    assert all(a["workflow_run"]["head_sha"] == meta["head"] and a["workflow_run"]["id"] == 36824683225 for a in render_artifacts)
    builds = [a for a in meta["export_artifacts"] if a["name"].startswith("voxelverse-")]
    assert len(builds) == 2 and all(a["workflow_run"]["head_sha"] == meta["head"] for a in builds)
    assert all(a["workflow_run"]["id"] == 36824683231 for a in builds)
    output = {
        "passed": True, "head": meta["head"], "ci_merge": meta["ci_merge"], "tree": meta["tree"],
        "source_sha256": meta["source_sha256"], "gates": gates,
        "source_tests_passed": 266, "source_shards": sorted(details, key=lambda x: x["shard"]),
        "runtime_checks_passed": 27, "exports": {k: {"checks_passed": 41, "accepted_archive": v} for k, v in packages.items()},
        "native_capture_jobs_passed": 8, "checked_log_digests": logs,
        "accepted_build_artifacts": [{"id": a["id"], "name": a["name"], "bytes": a["size_in_bytes"], "github_zip_digest": a["digest"]} for a in builds],
        "checked_actual_source_manifest_sha256": manifest_sha,
        "export_manifest_payloads": "Omitted by CI diagnostics; reported digests match preserved source/runtime payloads.",
        "package_bytes_rehashed": False, "render_archives_downloaded": False,
        "target_pc_acceptance": False, "visual_acceptance": False, "later_tree_acceptance": False,
    }
    print(json.dumps(output, indent=2))
    for z in opened.values():
        z.close()
    return output


if __name__ == "__main__":
    main()
