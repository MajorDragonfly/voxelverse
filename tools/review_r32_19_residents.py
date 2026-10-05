#!/usr/bin/env python3
"""Bounded native resident UI capture on an already integrated owner-patch tree.

Run under the shared R32 host lock and the assigned slot. This is a flat fixture
with real controller, input, work, well production, consumption and save/load;
not a spherical campaign, GPU benchmark or target-PC acceptance.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    project = args.project.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source = SourceRun(project)
    source.begin_report(output)
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="r32-19-residents-") as temporary:
        env = isolated_env(Path(temporary))
        command = [str(editor), "--path", str(project), "--rendering-method", "gl_compatibility",
                   "--audio-driver", "Dummy", "--script", "res://tests/r32_19_resident_ui_test.gd",
                   "--", "--capture", str(output)]
        with (output / "render.log").open("w") as log:
            try:
                completed = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
                code = completed.returncode
            except subprocess.TimeoutExpired:
                code = 124
    source.observe("native_capture", force=True)
    provenance = source.write_report(output)
    logs = (output / "render.log").read_text()
    images = sorted(p.name for p in output.glob("resident-*.png"))
    passed = code == 0 and not ERROR.search(logs) and '"passed":true' in logs and len(images) == 36 and provenance["reusable"]
    report = {"passed": passed, "exit_code": code, "images": images, "command": command,
              "source": provenance, "renderer": "gl_compatibility",
              "scope": "flat fixture, runtime 100/125/150 scale, DE/EN, real input/work/water/save",
              "target_pc_accepted": False, "spherical_campaign_accepted": False}
    (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"passed": passed, "exit_code": code, "images": len(images)}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
