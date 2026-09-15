"""Validate process coverage and summarize measured developed-campaign stages."""
import json
from pathlib import Path

REQUIRED_STAGES = {
    "cold_world", "village_handoff", "wood_freight", "village_save_reload",
    "build_workshops", "approach_wildlife", "supply_pen", "block_loaded_carrier",
    "animal_travel_failed_write", "animal_travel_depart", "animal_travel_return",
    "fresh_process_returned", "animal_travel_far_work", "animal_travel_pause_save", "freight_delivery",
}


def validate_developed(output, capture, userdata):
    """A passing parent alone cannot certify that its fresh children were measured."""
    recipe = capture["recipe"]
    # Godot JSON serializes its Variant numbers as floating-point literals.
    # A validated whole-number recipe must remain usable after that round trip.
    if recipe["cycles"] not in (1, 2, 3):
        raise ValueError("Invalid developed cycle count")
    cycles = int(recipe["cycles"])
    children = capture.get("children", [])
    expected = {f"cycle_{cycle}_{kind}" for cycle in range(cycles)
                for kind in ("far_restart", "home_restart")}
    actual = [child["process"] for child in children]
    if len(actual) != len(expected) or set(actual) != expected:
        raise ValueError("Missing or duplicate developed restart measurements")
    required = REQUIRED_STAGES | {"produce_and_collect_" + recipe["production"], recipe["production"] + "_delivered"}
    for cycle in range(cycles):
        stages = {s["stage"] for s in capture["segments"] if s["cycle"] == cycle}
        if required - stages:
            raise ValueError(f"Incomplete developed cycle {cycle}: {sorted(required - stages)}")
    reports = []
    for child in children:
        path = output / (child["process"] + "-capture.json")
        report = json.loads(path.read_text(encoding="utf-8"))
        if (child["exit_code"] != 0 or not report.get("passed") or report.get("failures")
                or report.get("process") != child["process"] or report.get("recipe") != recipe
                or report.get("source") != capture["source"]):
            raise ValueError(f"Invalid fresh-process report: {child['process']}")
        if not Path(report["user_data_dir"]).resolve().is_relative_to(userdata.resolve()):
            raise ValueError("Developed child escaped isolated user data")
        stages = {s["stage"] for s in report["segments"]}
        if not {"load_paused_checkpoint", "checkpoint_ready"} <= stages:
            raise ValueError("Developed child did not measure checkpoint loading")
        reports.append(report)
    for report in [capture, *reports]:
        if not any((s.get("frame_ms") or {}).get("count", 0) > 0 for s in report["segments"]):
            raise ValueError("Developed process recorded no frame intervals")
        filename = "frames.csv" if report["process"] == "main" else report["process"] + "-frames.csv"
        with (output / filename).open(encoding="utf-8") as raw:
            if not raw.readline().strip() or not raw.readline().strip():
                raise ValueError("Developed process has no raw frame evidence")
        if report["renderer"] != recipe["renderer"]:
            raise ValueError("Unexpected developed renderer")
        if recipe["renderer"] != "headless" and not any((s.get("draw_calls") or {}).get("max", 0) > 0 for s in report["segments"]):
            raise ValueError("Developed rendered process produced no draw calls")
    if not any(v.get("owner") == "far" and v.get("cargo_units", {}).get(recipe["production"], 0) > 0
               for snapshot in capture.get("snapshots", []) if snapshot.get("stage") == "animal_travel_far_work"
               for v in snapshot.get("villages", [])):
        raise ValueError("Developed recorder missed the actual remote product freight")
    return reports


def stage_rows(capture):
    for report in [capture, *capture.get("process_reports", [])]:
        for stage in report["segments"]:
            yield report["process"], stage["cycle"], stage


def write_developed_summary(output, capture, comparison=None):
    previous = None
    if comparison:
        previous = json.loads((comparison.expanduser().resolve() / "performance.json").read_text(encoding="utf-8"))
        fields = ("recipe", "cpu", "logical_cpus", "adapter", "godot", "renderer", "software_renderer", "host")
        if not previous.get("passed") or any(previous.get(k) != capture.get(k) for k in fields):
            raise ValueError("Comparison needs a passed report with identical recipe, engine and reported hardware")
    before = {(process, cycle, s["stage"]): s for process, cycle, s in stage_rows(previous)} if previous else {}
    lines = ["# Developed spherical campaign measurements", "",
             f"Source: `{capture['source']['commit']}`; dirty: `{capture['source']['dirty']}`.", "",
             f"Godot {capture['godot']}; {capture['renderer']}; CPU: {capture['cpu']}.", "",
             "Diagnostic recipe: conserved starting reserve, 4× production simulation and a 2 FPS far-debt exercise. "
             "These timings are not normal-speed gameplay or target-PC acceptance. Each cold restart is a separate measured process. "
             "OS file caches are not cleared. Frame intervals include the cap and measurement overhead.", "",
             "| Process / cycle | Stage | Wall time ms | Frame median / p95 / p99 ms | GPU p95 ms | Baseline wall Δ ms |",
             "|---|---|---:|---:|---:|---:|"]
    for process, cycle, stage in stage_rows(capture):
        frames = stage.get("frame_ms")
        gpu = stage.get("render_gpu_ms")
        frame_text = " / ".join(f"{frames[k]:.2f}" for k in ("median", "p95", "p99")) if frames else "unavailable"
        gpu_text = f"{gpu['p95']:.2f}" if gpu else "unavailable"
        old = before.get((process, cycle, stage["stage"]))
        delta = f"{stage['elapsed_ms'] - old['elapsed_ms']:+.2f}" if old else "—"
        lines.append(f"| {process} / {cycle} | {stage['stage']} | {stage['elapsed_ms']:.2f} | {frame_text} | {gpu_text} | {delta} |")
    lines += ["", "Child wall times (excluded from parent frame percentiles):", ""]
    for child in capture["children"]:
        lines.append(f"- {child['process']}: {child['elapsed_ms']:.2f} ms; exit {child['exit_code']}.")
    if previous:
        lines += ["", f"Baseline source: `{previous['source']['commit']}`. "
                  "Single runs show differences, not statistical significance; generated campaign IDs and scheduling may vary."]
    lines += ["", "Raw samples: frames.csv and cycle_*-frames.csv. Object, village, freight and memory snapshots: "
              "capture.json and cycle_*-capture.json. Preserved isolated saves and region archives: fixture/.", ""]
    (output / "summary.md").write_text("\n".join(lines), encoding="utf-8")
