"""Summarize raw movement frames without treating coarse monitors as causes."""

import csv
import json
import math
from pathlib import Path
import statistics


THRESHOLDS_MS = (33.0, 50.0, 100.0)
ROUTE_STAGES = ("walk_outward", "walk_return")


def _percentile(values, fraction):
    if fraction == 0.50:
        return statistics.median(values)
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)]


def summarize(directory, capture):
    samples = {}
    with (directory / "frames.csv").open(newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            if row["stage"] not in ROUTE_STAGES or not row["frame_ms"]:
                continue
            key = (int(row["cycle"]), row["stage"])
            samples.setdefault(key, []).append((int(row["tick_us"]), float(row["frame_ms"])))
    result = []
    for (cycle, stage), frames in sorted(samples.items()):
        values = [value for _, value in frames]
        first_tick = frames[0][0]
        world = capture.get(f"world_{cycle}", {})
        result.append({
            "cycle": cycle, "stage": stage, "frames": len(frames),
            "p50_ms": _percentile(values, 0.50), "p95_ms": _percentile(values, 0.95),
            "p99_ms": _percentile(values, 0.99), "max_ms": max(values),
            "spikes_over_ms": {str(int(threshold)): sum(value > threshold for value in values)
                               for threshold in THRESHOLDS_MS},
            "largest_frames": [{"route_second": round((tick - first_tick) / 1_000_000, 3),
                                "frame_ms": value} for tick, value in sorted(frames, key=lambda frame: frame[1], reverse=True)[:5]],
            "scene_lifetime_maxima_ms": {key: world.get(key) for key in (
                "population_work_max_ms", "population_spawn_max_ms", "population_spawn_stage_max_ms",
                "terrain_upload_max_ms", "terrain_publish_max_ms", "flora_work_max_ms", "region_io_max_ms")},
        })
    if not result:
        raise ValueError("The raw capture has no movement frames")
    return result


def write_route_summary(directory, capture, compare=None):
    rows = summarize(directory, capture)
    baseline = None
    if compare is not None:
        previous = json.loads((compare / "capture.json").read_text(encoding="utf-8"))
        comparable = ("recipe", "cpu", "renderer", "adapter", "surface")
        old_address = previous.get("initial_address", {})
        new_address = capture.get("initial_address", {})
        same_start = all(old_address.get(key) == new_address.get(key) for key in ("body_id", "face")) \
            and all(math.isclose(float(old_address.get(key, 1e9)), float(new_address.get(key, -1e9)),
                                 rel_tol=0.0, abs_tol=1e-12) for key in ("u", "v")) \
            and abs(float(old_address.get("height", 1e9)) - float(new_address.get("height", -1e9))) <= 0.1
        if any(previous.get(key) != capture.get(key) for key in comparable) or not same_start:
            raise ValueError("Route comparison requires the same recipe, host, renderer, start address and planet; use --replay")
        baseline = summarize(compare, previous)
        if [(row["cycle"], row["stage"]) for row in baseline] != [(row["cycle"], row["stage"]) for row in rows]:
            raise ValueError("Route comparison has different movement stages")
    result = {"protocol": 1, "source": capture.get("source"), "target_pc_acceptance": False,
              "notes": "Wall-clock process-frame intervals; scene-lifetime maxima do not prove same-frame causality. First/reloaded cycles and outward/return routes are separate.",
              "routes": rows}
    if baseline is not None:
        result["comparison"] = [{"cycle": new["cycle"], "stage": new["stage"],
                                  "baseline_p95_ms": old["p95_ms"], "current_p95_ms": new["p95_ms"],
                                  "baseline_p99_ms": old["p99_ms"], "current_p99_ms": new["p99_ms"],
                                  "baseline_max_ms": old["max_ms"], "current_max_ms": new["max_ms"],
                                  "baseline_spikes_over_ms": old["spikes_over_ms"],
                                  "current_spikes_over_ms": new["spikes_over_ms"]}
                                 for old, new in zip(baseline, rows)]
    (directory / "route-summary.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    lines = ["# Movement route", "", "Wall-clock frames; headless/software runs are not target-PC acceptance.",
             "Scene-lifetime maxima identify candidates, not same-frame causality.", "",
             "| Cycle | Stage | Frames | p50 | p95 | p99 | Max | >33 ms | >50 ms | >100 ms |",
             "|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for row in rows:
        counts = row["spikes_over_ms"]
        lines.append(f'| {row["cycle"]} | {row["stage"]} | {row["frames"]} | {row["p50_ms"]:.1f} | '
                     f'{row["p95_ms"]:.1f} | {row["p99_ms"]:.1f} | {row["max_ms"]:.1f} | '
                     f'{counts["33"]} | {counts["50"]} | {counts["100"]} |')
    if baseline is not None:
        lines += ["", "Comparison uses the same recipe, host, renderer, start address and planet;"
                  " inspect the raw frames and fixture before attributing a change.", ""]
        for row in result["comparison"]:
            lines.append(f'{row["cycle"]} {row["stage"]}: p95 {row["baseline_p95_ms"]:.1f} → '
                         f'{row["current_p95_ms"]:.1f} ms; p99 {row["baseline_p99_ms"]:.1f} → '
                         f'{row["current_p99_ms"]:.1f} ms; max {row["baseline_max_ms"]:.1f} → '
                         f'{row["current_max_ms"]:.1f} ms; >100 ms '
                         f'{row["baseline_spikes_over_ms"]["100"]} → {row["current_spikes_over_ms"]["100"]}.')
    (directory / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return result
