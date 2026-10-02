#!/usr/bin/env python3
"""Verify and assemble six original Forward+ artifacts against native GL data."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

CATEGORIES = ["campaign_spawn", "grassland", "desert", "rocky_highlands", "snow", "coast"]
FIELDS = ["camera_transform", "origin", "clock_seconds", "sun_direction", "sun_energy",
          "tonemap_white", "ambient_energy", "geometry_sha256"]


def read(path):
    return json.loads(path.read_text())


def normalized(value):
    if isinstance(value, dict):
        return {k: normalized(v) for k, v in value.items() if k != "body_id"}
    if isinstance(value, list):
        return [normalized(v) for v in value]
    return value


def production_manifest(directory):
    # Exact whole-repository comparison except this packet's review/evidence
    # files: the coast camera replay has its own immutable, separately logged
    # source tree. No production path is allowed to differ between cases.
    return [json.loads(line) for line in (directory / "source-files-start.jsonl").read_text().splitlines()
            if not (json.loads(line)["path"].startswith("tools/review_r32_08_")
                    or json.loads(line)["path"].startswith("docs/evidence/r32-08/"))]


def verify(directory):
    result = read(directory / "results.json")
    capture = read(directory / "capture.json")
    assert result["passed"] and result["exit_code"] == 0 and capture["passed"]
    assert result["source_provenance"]["reusable"]
    assert not result["source_provenance"]["start"]["tracked_worktree_dirty"]
    if result["mode"] == "campaign":
        assert capture["surface_generation"] == "living_planet_v2"
    for name, digest in result["screenshots"].items():
        assert hashlib.sha256((directory / name).read_bytes()).hexdigest() == digest, name
    assert hashlib.sha256((directory / "runtime.log").read_bytes()).hexdigest() == result["runtime_log_sha256"]
    for boundary in ["start", "end"]:
        entry = result["source_provenance"]["manifests"][boundary]
        assert hashlib.sha256((directory / entry["path"]).read_bytes()).hexdigest() == entry["sha256"]
    return result, capture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cases", type=Path, required=True, help="Unzip each artifact into its category folder")
    parser.add_argument("--reference", type=Path, required=True, help="Original Compatibility campaign directory")
    parser.add_argument("--output", type=Path, required=True, help="New combined artifact directory")
    args = parser.parse_args()
    assert not args.output.exists(), "Output must be new"
    gl_result, gl = verify(args.reference)
    assert len(gl["samples"]) == 18
    combined, observations, sources = None, [], []
    production = production_manifest(args.reference)
    checked = []
    for category in CATEGORIES:
        directory = args.cases / category / "campaign"
        result, capture = verify(directory)
        assert result["renderer"] == "forward_plus" and result["category"] == category
        assert result["candidate_shader_sha256"] == gl_result["candidate_shader_sha256"]
        assert result["baseline_shader_sha256"] == gl_result["baseline_shader_sha256"]
        assert len(capture["samples"]) == 3 and not capture["failures"]
        for field in ["seed", "resolution", "preset", "measurement_mode"]:
            assert capture[field] == gl[field], field
        source = result["source_provenance"]["start"]
        current_production = production_manifest(directory)
        assert current_production == production, category + " changed production source"
        sources.append({"category": category, "host": result["host"],
                        "source": [source["commit"], source["tree"], source["source_sha256"]]})
        for sample in capture["samples"]:
            reference = next(s for s in gl["samples"] if s["category"] == category and s["distance_m"] == sample["distance_m"])
            for field in FIELDS:
                assert sample[field] == reference[field], (category, sample["distance_m"], field)
            for field in ["place", "weather"]:
                assert normalized(sample[field]) == normalized(reference[field]), (category, field)
            for version in ["before", "after"]:
                assert sample[version]["primitives"] == reference[version]["primitives"]
                for timing in ["frame_ms", "render_cpu_ms", "render_gpu_ms"]:
                    assert sample[version][timing]["count"] == 16
            assert sample["before"]["draw_calls"] == sample["after"]["draw_calls"]
            checked.append({"category": category, "distance_m": sample["distance_m"], "matched_fields": FIELDS + ["place_without_body_id", "weather_without_body_id", "primitives"]})
        for motion in capture["motion"]:
            reference = next(m for m in gl["motion"] if (m["category"], m["version"], m["index"]) == (category, motion["version"], motion["index"]))
            assert motion["camera_transform"] == reference["camera_transform"]
        assert len(capture["motion"]) == (48 if category in ["campaign_spawn", "rocky_highlands", "snow"] else 0)
        if combined is None:
            combined = {k: v for k, v in capture.items() if k not in ["samples", "motion", "probes"]}
            combined.update(samples=[], motion=[], probes=[])
        for key in ["samples", "motion", "probes"]:
            combined[key].extend(capture[key])
        observations.append((directory, result))
    probe, _ = verify(args.cases / "campaign_spawn" / "probe")
    assert probe["candidate_shader_sha256"] == gl_result["candidate_shader_sha256"]
    # Write only after every original and the cross-renderer contract passed.
    target = args.output / "campaign"
    target.mkdir(parents=True)
    for directory, result in observations:
        for name in result["screenshots"]:
            shutil.copy2(directory / name, target / name)
    assert len(list(target.glob("*.png"))) == 185
    combined["category"] = "all"
    combined["aggregation"] = "Six independent native campaign processes; within-case before/after costs only. See original per-case provenance."
    combined["case_sources"] = sources
    (target / "capture.json").write_text(json.dumps(combined, indent=2) + "\n")
    shutil.copytree(args.cases / "campaign_spawn" / "probe", args.output / "probe")
    contract = {"passed": True, "samples": 18, "motion_samples": 144, "original_pngs": 185,
                "matched_inputs": checked, "case_sources": sources, "target_hardware": False,
                "note": "Body IDs vary between fresh isolated saves and are excluded only from address/weather identity comparison. Renderer draw-call totals can differ; before/after totals must match within each renderer."}
    (args.output / "comparison-contract.json").write_text(json.dumps(contract, indent=2) + "\n")
    print(json.dumps({"passed": True, "samples": 18, "motion_samples": 144, "original_pngs": 185}))


if __name__ == "__main__":
    main()
