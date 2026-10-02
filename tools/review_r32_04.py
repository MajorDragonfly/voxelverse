#!/usr/bin/env python3
"""Focused R32-04 tests and real 1080p before/after campaign views."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun
from validate_godot import ERROR

BASE = "2a738a4891a8de11d682c469833ade4dc9b01dfb"


def run(command, project, log, env, timeout, marker=None):
    with log.open("w") as stream:
        try:
            result = subprocess.run(command, cwd=project, env=env, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=timeout)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = 124
    content = log.read_text()
    passed = code == 0 and not ERROR.search(content) and (not marker or marker in content)
    result = dict(command=[str(s) for s in command], exit_code=code, passed=bool(passed),
                  log_sha256=hashlib.sha256(log.read_bytes()).hexdigest())
    print(json.dumps(result), flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--baseline", default=BASE, choices=[BASE])
    parser.add_argument("--renderer", default="gl_compatibility", choices=["gl_compatibility", "forward_plus"])
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    baseline = output / "baseline-checkout"
    checks = []
    subprocess.run(["git", "worktree", "add", "--detach", str(baseline), args.baseline], cwd=project, check=True)
    try:
        # Identical observation code, no counterfactual camera implementation.
        for name in ["review_r32_04_campaign_capture.gd", "review_r32_04_campaign_capture.gd.uid"]:
            shutil.copy2(project / "tools" / name, baseline / "tools" / name)
        source = SourceRun(project)
        (output / "candidate-source").mkdir()
        source.begin_report(output / "candidate-source")
        base_source = SourceRun(baseline)
        (output / "baseline-source").mkdir()
        base_source.begin_report(output / "baseline-source")
        if source.blocked or base_source.blocked:
            raise RuntimeError("Source inventory unavailable")
        with validation_editor(args.godot) as editor:
            if args.renderer == "gl_compatibility":
                focused = output / "focused-tests"
                command = [sys.executable, str(project / "tools/validate_godot.py"), "--godot", str(editor),
                           "--tests", "tribal_camera_preferences_test", "tribal_camera_test", "tribal_camera_world_test",
                           "minimap_test", "tribal_building_preview_test", "--skip-main", "--output", str(focused)]
                checks.append(run(command, project, output / "focused-run.log", isolated_env(output / "test-userdata"), 240))
            else:
                checks.append(run([str(editor), "--headless", "--path", str(project), "--import"],
                                  project, output / "candidate-import.log", isolated_env(output / "test-userdata"), 120))
            source.observe("import")
            before = output / "before"
            after = output / "after"
            before.mkdir()
            after.mkdir()
            before_env = isolated_env(output / "before-userdata")
            after_env = isolated_env(output / "after-userdata")
            for env in (before_env, after_env):
                env["LIBGL_ALWAYS_SOFTWARE"] = "1"
                env["LP_NUM_THREADS"] = "2"
            checks.append(run([str(editor), "--headless", "--path", str(baseline), "--import"],
                              baseline, output / "baseline-import.log", before_env, 120))
            base_source.observe("import")
            before_command = [str(editor), "--path", str(baseline), "--rendering-method", args.renderer,
                              "--audio-driver", "Dummy", "--script", "res://tools/review_r32_04_campaign_capture.gd",
                              "--", "--capture", str(before)]
            checks.append(run(before_command, baseline, before / "render.log", before_env, 240,
                              "R32_04_CAMPAIGN_CAPTURE_PASSED"))
            if not checks[-1]["passed"]:
                raise RuntimeError("Baseline capture failed; retain its actual negative evidence")
            reference = json.loads((before / "reference.json").read_text())
            shutil.copytree(output / "before-userdata", output / "after-userdata", dirs_exist_ok=True)
            after_command = [str(editor), "--path", str(project), "--rendering-method", args.renderer,
                             "--audio-driver", "Dummy", "--script", "res://tools/review_r32_04_campaign_capture.gd",
                             "--", "--capture", str(after), "--reference-slot", reference["slot"]]
            checks.append(run(after_command, project, after / "render.log", after_env, 240,
                              "R32_04_CAMPAIGN_CAPTURE_PASSED"))
            if not checks[-1]["passed"]:
                raise RuntimeError("Candidate capture failed; retain its actual negative evidence")
            # The production water modules already have a narrow real-sampler
            # contract. Publication remains explicitly a fixture here.
            if args.renderer == "gl_compatibility":
                checks.append(run([str(editor), "--path", str(project), "--rendering-method", args.renderer,
                                   "--audio-driver", "Dummy", "--script", "res://tools/review_r32_04_drink.gd"],
                                  project, output / "drink-native.log", isolated_env(output / "drink-userdata"), 45,
                                  "INT30_DRINK_CONTRACT_PASSED"))
            previous = json.loads((before / "views.json").read_text())["rows"]
            current = json.loads((after / "views.json").read_text())["rows"]
            if len(previous) != 9 or len(current) != 9:
                raise RuntimeError("Missing comparable real campaign views")
            for a, b in zip(previous, current):
                for key in ["label", "seed", "clock_s", "yaw_deg", "requested_tilt_deg", "zoom", "viewport", "projection"]:
                    if a[key] != b[key]: raise RuntimeError("Mismatched comparison condition: " + key)
                for key in ["body_id", "face", "u", "v", "height"]:
                    lhs, rhs = a["focus_address"][key], b["focus_address"][key]
                    same = lhs == rhs if key in ["body_id", "face"] else abs(lhs-rhs) <= (0.001 if key == "height" else 1e-10)
                    if not same:
                        raise RuntimeError("Reference slot/focus changed: " + key)
                if b["minimum_frame_clearance_m"] < 0.8:
                    raise RuntimeError("Candidate still has a buried frame edge: " + b["label"])
                if b["label"] in ["home-eye-level", "home-eye-level-side"] and b["forward_up_abs"] >= 0.15:
                    raise RuntimeError("Candidate violated the original eye-level criterion")
            negative = next(row for row in previous if row["label"] == "lens-25-wide")
            if negative["minimum_frame_clearance_m"] >= 0.0:
                raise RuntimeError("Regular-world baseline did not reproduce the diagnosed boundary")
            report = dict(passed=all(c["passed"] for c in checks), renderer=args.renderer,
                          source_commit=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=project, text=True).strip(),
                          source_tree=subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=project, text=True).strip(),
                          baseline_commit=args.baseline, reference=reference, checks=checks,
                          pairs=[dict(label=a["label"], before_clearance_m=a["minimum_frame_clearance_m"],
                                      after_clearance_m=b["minimum_frame_clearance_m"],
                                      after_forward_up_abs=b["forward_up_abs"]) for a,b in zip(previous,current)],
                          limits=["Software rendering / no target-PC or FPS acceptance.",
                                  "Native view pair reloads the exact reference campaign slot.",
                                  "Capture clock is held at the existing campaign clock source, 120 s.",
                                  "Drinking publication/collider probe is a fixture; camera images use the regular world."])
            (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps(report), flush=True)
            source.observe("capture_finished")
            base_source.observe("capture_finished")
            for owner, name in [(source,"candidate-source"),(base_source,"baseline-source")]:
                provenance = owner.write_report(output / name)
                (output / name / "provenance.json").write_text(json.dumps(provenance,indent=2) + "\n")
                if not provenance["reusable"]: raise RuntimeError("Source changed during capture: " + name)
            return 0 if report["passed"] else 1
    finally:
        subprocess.run(["git", "worktree", "remove", "--force", str(baseline)], cwd=project, check=True)


if __name__ == "__main__":
    raise SystemExit(main())
