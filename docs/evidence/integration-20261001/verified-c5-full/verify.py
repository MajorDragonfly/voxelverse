#!/usr/bin/env python3
"""Verify preserved CI evidence offline, including real failure/incomplete records."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parent
SUPPORT = {"source_contracts", "import", "art_sources", "source_integrity"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    meta = json.loads((ROOT / "manifest.json").read_text())
    query = json.loads((ROOT / "exact-head-query.json").read_text())
    assert query["request"] == {"commit_sha": meta["head"], "repo_full_name": meta["repository"]}
    queried = query["response"]["structuredContent"]["workflow_runs"]
    gates = []
    for record in meta["gates"]:
        run = next(r for r in queried if r["id"] == record["run_id"])
        gate = next(j for j in record["jobs"] if j["name"] == record["gate_name"])
        assert run["status"] == gate["status"] == "completed"
        assert run["conclusion"] == gate["conclusion"]
        gates.append({"name": gate["name"], "run_id": record["run_id"], "job_id": gate["id"], "status": gate["status"], "conclusion": gate["conclusion"]})
    assert {g["name"] for g in gates} == {"Godot validation gate", "Desktop export gate", "Environment render gate", "Project dashboard gate"}

    specs = {s["label"]: s for s in meta["artifacts"]}
    assert set(specs) == {"source0", "source1", "source2", "source3", "runtime", "plan", "windows", "linux"}
    opened, artifacts = {}, []
    for label, spec in specs.items():
        data = (ROOT / spec["bundle_path"]).read_bytes()
        api = spec["artifact"]
        assert sha(data) == api["digest"].removeprefix("sha256:") and len(data) == api["size_in_bytes"]
        assert api["workflow_run"]["head_sha"] == meta["head"] and api["workflow_run"]["id"] == spec["run"]
        opened[label] = ZipFile(ROOT / spec["bundle_path"])
        artifacts.append({"label": label, "run_id": spec["run"], "job_id": spec["job"], "artifact_id": api["id"], "bytes": len(data), "sha256": sha(data), "bytes_verified": True})
    plan = json.loads(opened["plan"].read("ci-plan.json"))
    assert plan["mode"] == "full" and plan["source"] and plan["runtime"] and plan["acceptance"]
    assert plan["head"] == plan["selection"]["source"]["head_commit"] == meta["ci_merge"]
    assert plan["selection"]["source"]["head_tree"] == meta["tree"]
    assert plan["registered_tests"] == plan["selected_tests"] == 266 and plan["tests_executed"] is False
    planned = [t for s in plan["matrix"]["include"] for t in s["tests"]]
    assert len(planned) == len(set(planned)) == 266
    assert [len(s["tests"]) for s in plan["matrix"]["include"]] == [67, 67, 66, 66]
    reference = opened["runtime"].read("source-files-start.jsonl")
    manifest_sha = sha(reference)
    assert manifest_sha == meta["source_manifest_sha256"]
    rows = [json.loads(line) for line in reference.splitlines()]
    assert len(rows) == meta["source_files"]
    canonical = [{k:v for k,v in row.items() if k not in {"tracked", "godot_uid"}} for row in rows if row["kind"] != "missing"]
    assert sha(json.dumps(canonical, ensure_ascii=True, sort_keys=True, separators=(",", ":")).encode()) == meta["source_sha256"]
    executed, source_passed, shard_reports, logs, exports, failures = [], [], [], [], {}, []
    runtime_report = None
    for label, spec in specs.items():
        if label == "plan":
            continue
        z = opened[label]
        result = json.loads(z.read("results.json"))
        assert result["godot"] == "4.6.3.stable.official.7d41c59c4"
        names = [c["name"] for c in result["checks"]]
        assert len(names) == len(set(names))
        pv = result["provenance"]
        assert pv["status"] == "prepared"
        for state in (result["source"], pv["start"], pv["end"]):
            assert state["complete"] and not state["tracked_worktree_dirty"]
            assert state["commit"] == meta["ci_merge"] and state["tree"] == meta["tree"]
            assert state["source_sha256"] == meta["source_sha256"] and state["file_count"] == meta["source_files"]
        for manifest in pv["manifests"].values():
            assert manifest["sha256"] == manifest_sha
            if spec["kind"] != "export":
                assert z.read(manifest["path"]) == reference
        for check in result["checks"]:
            if "source_sha256" in check:
                assert check["source_sha256"] == meta["source_sha256"]
            if not check["passed"]:
                failures.append({"artifact": label, "check": check["name"], "exit_code": check.get("exit_code"), "seconds": check.get("seconds"), "log_sha256": check.get("log_sha256")})
            if "log_sha256" in check:
                prefix = "logs/" if spec["kind"] == "export" else ""
                path = prefix + check["name"].replace("/", "_") + ".log"
                actual_sha = sha(z.read(path))
                assert actual_sha == check["log_sha256"]
                logs.append({"artifact": label, "check": check["name"], "log_path": path, "sha256": actual_sha, "verified": True})
        if spec["kind"] == "source":
            planned_shard = set(plan["matrix"]["include"][spec["shard"]]["tests"])
            assert set(result["selected_tests"]) == planned_shard
            observed = set(names) - SUPPORT
            assert observed <= planned_shard
            successful = [c["name"] for c in result["checks"] if c["name"] in observed and c["passed"]]
            executed.extend(observed)
            source_passed.extend(successful)
            shard_reports.append({"shard": spec["shard"], "planned": len(planned_shard), "actual_tests": len(observed), "passed_tests": len(successful), "result_passed": result["passed"], "reusable": pv["reusable"]})
        elif spec["kind"] == "runtime":
            assert len(result["checks"]) == 27 and result["selected_tests"] == []
            runtime_report = {"checks": 27, "passed_checks": sum(c["passed"] for c in result["checks"]), "result_passed": result["passed"], "reusable": pv["reusable"]}
        else:
            assert not any("source-files-" in path for path in z.namelist())
            exports[label] = {"check_records": len(result["checks"]), "passed_checks": sum(c["passed"] for c in result["checks"]), "failed_checks": [c["name"] for c in result["checks"] if not c["passed"]], "passed": result["passed"], "complete": result["complete"], "probes": len(result["probes"]), "passed_probes": sum(p["passed"] for p in result["probes"]), "accepted_archive": result.get("archive"), "reusable": pv["reusable"]}
    assert len(executed) == len(set(executed)), "Source shards overlapped"
    missing = sorted(set(planned) - set(executed))

    render = next(g for g in meta["gates"] if g["gate_name"] == "Environment render gate")
    review_steps = {"environment": "Render world, assets, Far clusters and creature comparisons", "resources": "Render procedural food and home meshes", "planets": "Render underwater optics, voxel planets, orbit and system", "spherical_campaign": "Render shared spherical creature, editor and freshwater flow"}
    captures = []
    for renderer in ("forward_plus", "gl_compatibility"):
        for review, step in review_steps.items():
            job = next(j for j in render["jobs"] if j["name"] == f"capture ({renderer}, {review})")
            actual_step = next(s for s in job["steps"] if s["name"] == step)
            assert job["status"] == actual_step["status"] == "completed"
            captures.append({"job_id": job["id"], "name": job["name"], "conclusion": job["conclusion"], "actual_render_step_conclusion": actual_step["conclusion"]})
    render_artifacts = [a for a in meta["render_artifacts"] if not a["name"].startswith("ci-plan-")]
    assert len(render_artifacts) == 8
    assert all(a["workflow_run"]["head_sha"] == meta["head"] and a["workflow_run"]["id"] == render["run_id"] for a in render_artifacts)
    builds = [a for a in meta["export_artifacts"] if a["name"].startswith("voxelverse-")]
    assert all(a["workflow_run"]["head_sha"] == meta["head"] for a in builds)
    expected_failures = [(f["artifact"], f["check"]) for f in meta["expected_failures"]]
    assert sorted((f["artifact"], f["check"]) for f in failures) == sorted(expected_failures)
    for expected in meta["expected_failures"]:
        log = opened[expected["artifact"]].read("logs/" + expected["check"] + ".log").decode(errors="replace")
        assertions = [line for line in log.splitlines() if line.startswith("TRIBAL_CHECK_FAILED:")]
        assert assertions and assertions[0] == expected["first_assertion"]
        next(f for f in failures if (f["artifact"], f["check"]) == (expected["artifact"], expected["check"]))["first_assertion"] = assertions[0]
    native_run = subprocess.run([sys.executable, str(ROOT / "native" / "verify.py")], check=True, capture_output=True, text=True)
    native = json.loads(native_run.stdout)
    assert native["passed"] and native["head"] == meta["head"] and native["tree"] == meta["tree"] and native["source_sha256"] == meta["source_sha256"]
    full = all(g["conclusion"] == "success" for g in gates) and len(source_passed) == 266 and runtime_report["passed_checks"] == 27 and all(e["passed"] and e["complete"] and e["check_records"] == 41 and e["passed_probes"] == 3 for e in exports.values()) and all(c["conclusion"] == c["actual_render_step_conclusion"] == "success" for c in captures)
    output = {"evidence_verified": True, "full_technical_acceptance": full, "head": meta["head"], "ci_merge": meta["ci_merge"], "tree": meta["tree"], "source_sha256": meta["source_sha256"], "source_files": meta["source_files"], "gates": gates, "raw_artifacts": artifacts, "source": {"registered": 266, "planned": 266, "actual_executed": len(executed), "actual_passed": len(source_passed), "disjoint": True, "missing_tests": missing, "shards": sorted(shard_reports, key=lambda s:s["shard"])}, "runtime": runtime_report, "exports": exports, "failures": failures, "actual_render_jobs": captures, "checked_log_digests": len(logs), "log_digest_checks": logs, "checked_actual_source_manifest_sha256": manifest_sha, "accepted_build_artifacts": [{"id": a["id"], "name": a["name"], "bytes": a["size_in_bytes"], "github_zip_digest": a["digest"]} for a in builds], "export_manifest_payloads": "Omitted by CI diagnostics; reported digests match preserved source/runtime payloads.", "package_bytes_rehashed": False, "render_archives_downloaded": False, "target_pc_acceptance": False, "visual_acceptance": False, "additional_native_flow_acceptance": False, "later_tree_acceptance": False}
    output["native_feature_building_gallery_audio"] = native
    print(json.dumps(output, indent=2))
    for z in opened.values():
        z.close()


if __name__ == "__main__":
    main()
