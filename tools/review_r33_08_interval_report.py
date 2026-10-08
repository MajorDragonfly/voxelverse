#!/usr/bin/env python3
"""Offline frame-counter audit of hash-bound R33-08 originals; no engine launch."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import tarfile

from review_r33_08_publication_report import distribution

RUNS = ("baseline-gl_compatibility", "baseline-forward_plus",
        "overlay-gl_compatibility", "overlay-forward_plus")
CALLBACKS = ("surface_ecosystem._process", "surface_distant_scenery._process",
             "campaign_atmosphere._process", "save_feedback._process")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def audit_run(read, name):
    bindings = {}

    def raw(filename):
        data = read(f"r33-08-results/{name}/{filename}")
        bindings[filename] = {"bytes": len(data), "sha256": sha(data)}
        return data

    result = json.loads(raw("results.json"))
    log_bytes = raw("run.log")
    if sha(log_bytes) != result["log_sha256"]:
        raise ValueError(f"{name}: log hash mismatch")
    log = log_bytes.decode("utf-8")
    progress = json.loads(raw("int30-collision-progress.json"))
    spans = json.loads(raw("int30-collision-spans.json"))
    fixture = raw("int30-collision-source-slot.json")
    source = result["provenance"]
    if source["status"] != "stable":
        raise ValueError(f"{name}: unstable original source")
    manifests = [raw(f"source-files-{edge}.jsonl") for edge in ("start", "end")]
    if manifests[0] != manifests[1]:
        raise ValueError(f"{name}: changed source inventory")
    for edge, data in zip(("start", "end"), manifests):
        if sha(data) != source["manifests"][edge]["sha256"]:
            raise ValueError(f"{name}: source manifest hash mismatch")
        if not source[edge]["complete"] or source[edge]["tracked_worktree_dirty"]:
            raise ValueError(f"{name}: incomplete/dirty source inventory")
    requested = result["renderer"]
    if requested != progress["renderer"] or requested not in ("forward_plus", "gl_compatibility"):
        raise ValueError(f"{name}: renderer mismatch")
    if requested == "forward_plus" and not any(
            line.startswith("Vulkan ") and " - Forward+ - " in line for line in log.splitlines()):
        raise ValueError(f"{name}: Forward+ backend not verified")
    if requested == "gl_compatibility" and not any(
            line.startswith("OpenGL ") and "Compatibility" in line for line in log.splitlines()):
        raise ValueError(f"{name}: GL backend not verified")
    if "--disable-render-loop" not in result["command"]:
        raise ValueError(f"{name}: render loop condition changed")
    overlay = "--publication-trace" in result["command"]
    if overlay != name.startswith("overlay-"):
        raise ValueError(f"{name}: wrong instrumentation variant")
    summary = spans["summary"]
    if summary["dropped"] or summary["write_errors"]:
        raise ValueError(f"{name}: incomplete span collection")
    slow = spans["slow"]
    if len(slow) >= 2048:
        raise ValueError(f"{name}: slow timestamp buffer may be truncated")
    stages = {}
    for stage in ("near", "far"):
        phase = f"publication-{stage}-start"
        key = f"{phase}|await-process.{stage}"
        values = spans["samples"][key]
        total = summary["totals"][key]
        if len(values) != total["count"] or not math.isclose(sum(values), total["sum_ms"], abs_tol=.001):
            raise ValueError(f"{name}/{stage}: incomplete wait samples")
        points = [row for row in slow if row["phase"] == phase and row["operation"] == f"await-process.{stage}"]
        if len(points) != total["over_33_ms"]:
            raise ValueError(f"{name}/{stage}: incomplete slow timestamps")
        phase_start = next(row["time"] for row in progress["phase_records"] if row["phase"] == phase)
        publication = next(row for row in progress["publication_waits"] if row["stage"] == stage)
        begin, end = publication["start"], publication["end"]
        process_delta = end["process_frames"] - begin["process_frames"]
        physics_delta = end["physics_frames"] - begin["physics_frames"]
        if process_delta != len(values):
            raise ValueError(f"{name}/{stage}: wait/frame count mismatch")
        previous_process, previous_physics = phase_start["process_frames"], phase_start["physics_frames"]
        previous_wall = phase_start["wall_ms"] * 1000
        histogram = Counter()
        for point in points:
            dp = point["process_frame"] - previous_process
            dh = point["physics_frame"] - previous_physics
            if dp <= 0 or dh < 0 or point["wall_us"] <= previous_wall:
                raise ValueError(f"{name}/{stage}: unordered counters/timestamps")
            histogram[(dp, dh)] += 1
            previous_process, previous_physics, previous_wall = point["process_frame"], point["physics_frame"], point["wall_us"]
        complete_timestamps = len(points) == len(values)
        if complete_timestamps and ([p["ms"] for p in points] != values or
                                    previous_physics != end["physics_frames"]):
            raise ValueError(f"{name}/{stage}: timestamp/value boundary mismatch")
        measured = None
        no_slow_callback = None
        predraw = None
        if overlay:
            measured = {}
            slow_frames = set()
            for callback in CALLBACKS:
                callback_key = f"{phase}|{callback}"
                callback_total = summary["totals"][callback_key]
                callback_points = [p for p in slow if p["phase"] == phase and p["operation"] == callback]
                if len(callback_points) != callback_total["over_33_ms"]:
                    raise ValueError(f"{name}/{stage}: incomplete callback timestamps")
                slow_frames.update(p["process_frame"] for p in callback_points)
                measured[callback] = distribution(spans["samples"][callback_key])
            predraw_key = f"{phase}|surface_ecosystem._sync_transition_motion"
            predraw = summary["totals"].get(predraw_key, {"count": 0, "sum_ms": 0.0})
            if complete_timestamps:
                # SceneTree.process_frame is emitted before Node._process.
                # Await ending at f includes the previous f-1 callbacks. The
                # first boundary is partial, so exclude it conservatively.
                selected = [p for p in points[1:] if p["process_frame"] - 1 not in slow_frames]
                no_slow_callback = {"count": len(selected), "wait_ms": distribution([p["ms"] for p in selected]),
                    "note": "No >33-ms sample among the four instrumented top-level callbacks in preceding frame; other callbacks, physics, sync and draw remain unmeasured. Not a residual or causal subtraction."}
        captures = [row for row in progress["capture_frames"]
                    if row["start"]["wall_ms"] < end["wall_ms"] and row["end"]["wall_ms"] > begin["wall_ms"]]
        stages[stage] = {"wait_ms": distribution(values), "publication_ms": publication["milliseconds"],
            "timed_out": publication.get("timed_out", False), "process_frame_delta": process_delta,
            "physics_frame_delta": physics_delta, "physics_per_process_aggregate": physics_delta / process_delta,
            "timestamped_waits": len(points), "complete_wait_timestamps": complete_timestamps,
            "counter_step_histogram": [{"process_delta": dp, "physics_delta": dh, "count": n}
                                       for (dp, dh), n in sorted(histogram.items())],
            "histogram_note": "Sparse timestamp gaps are aggregated deltas; only complete_wait_timestamps supports an every-frame claim.",
            "pre_draw_callback": predraw, "instrumented_callbacks": measured,
            "waits_without_slow_measured_callback": no_slow_callback,
            "explicit_capture_records_overlapping_stage": len(captures)}
    host_name = f"r33-08-results/{name}-host.jsonl"
    host_bytes = read(host_name)
    bindings[host_name] = {"bytes": len(host_bytes), "sha256": sha(host_bytes)}
    host = [json.loads(line) for line in host_bytes.splitlines()]
    start = next(row for row in host if row.get("event") == "start")
    finish = host[-1]

    def cpu_stat(row):
        return {k: int(v) for k, v in (line.split() for line in (row.get("cpu.stat") or "").splitlines())}

    cpu_begin, cpu_end = cpu_stat(start), cpu_stat(finish)
    host_report = {"host": host[0].get("host"), "records": len(host),
        "end_event": finish.get("event"), "end_no_live_godot": finish.get("godot") == [],
        "foreign_godot_observed": finish.get("foreign_godot_observed"),
        "max_loadavg_1m": max(row["loadavg"][0] for row in host if "loadavg" in row),
        "cpu_max_available": any(row.get("cpu.max") is not None for row in host),
        "nr_throttled_delta": cpu_end["nr_throttled"] - cpu_begin["nr_throttled"]
                              if "nr_throttled" in cpu_begin and "nr_throttled" in cpu_end else None,
        "throttled_usec_delta": cpu_end["throttled_usec"] - cpu_begin["throttled_usec"]
                                if "throttled_usec" in cpu_begin and "throttled_usec" in cpu_end else None,
        "note": "Whole-command host/cgroup observations, not engine-thread interval attribution. Missing cpu.max is unknown, not an unlimited quota claim."}
    return {"case": name, "engine_header": next(line for line in log.splitlines() if line.startswith("Godot Engine ")),
        "renderer": requested, "fixture_sha256": sha(fixture), "source": source["start"],
        "original_route_passed": result["passed"], "original_exit_code": result["exit_code"],
        "source_reusable_for_successful_route": source["reusable"], "host_telemetry": host_report,
        "bindings": bindings, "stages": stages}


def analyze_archive(archive, provenance):
    expected = provenance["files"]["native-raw.tar.gz"]
    data = archive.read_bytes()
    if len(data) != expected["bytes"] or sha(data) != expected["sha256"]:
        raise ValueError("Original archive bytes/hash mismatch")
    with tarfile.open(archive, "r:gz") as tar:
        names = tar.getnames()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate archive members")

        def read(name):
            member = tar.getmember(name)
            if not member.isfile() or member.size > 64 * 1024 * 1024:
                raise ValueError(f"Invalid/oversized evidence member: {name}")
            return tar.extractfile(member).read()

        runs = [audit_run(read, name) for name in RUNS]
    if len({r["fixture_sha256"] for r in runs}) != 1:
        raise ValueError("Quartet save bytes differ")
    if len({r["engine_header"] for r in runs}) != 1:
        raise ValueError("Quartet engine headers differ")
    return {"schema": 1, "kind": "offline-original-interval-audit", "new_engine_runs": 0,
        "archive": expected, "original_run": provenance["native"]["run"],
        "quantile_method": "linear interpolation at (n-1)*p, all retained duration samples",
        "product_cause_established": False, "product_fix": False, "hardware_acceptance": False,
        "note": "pre_draw_callback counts the measured signal consumer, not draw wall time; null means uninstrumented. Eight physics ticks may be a consequence. No overlapping spans are subtracted.",
        "runs": runs}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--provenance", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = analyze_archive(args.archive, json.loads(args.provenance.read_text()))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    for run in report["runs"]:
        stage = run["stages"]["near"]
        print(run["case"], "frames", stage["process_frame_delta"], "physics", stage["physics_frame_delta"],
              "pre-draw", stage["pre_draw_callback"]["count"] if stage["pre_draw_callback"] is not None else "unmeasured")


if __name__ == "__main__":
    main()
