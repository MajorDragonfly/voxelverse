#!/usr/bin/env python3
"""Native regular-world shore capture; product code is unchanged from the focused run."""
import argparse
import json
from pathlib import Path
from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun
from review_r32_04 import run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = SourceRun(project)
    source.begin_report(output)
    checks = []
    try:
        if source.blocked: raise RuntimeError("Source inventory unavailable")
        env = isolated_env(output / "userdata")
        env["LIBGL_ALWAYS_SOFTWARE"] = "1"
        env["LP_NUM_THREADS"] = "2"
        with validation_editor(args.godot) as editor:
            checks.append(run([str(editor), "--headless", "--path", str(project), "--import"],
                              project, output / "import.log", env, 120))
            source.observe("import")
            if not checks[-1]["passed"]: return 1
            checks.append(run([str(editor), "--path", str(project), "--rendering-method", "gl_compatibility",
                               "--audio-driver", "Dummy", "--script", "res://tools/review_r32_04_shore_capture.gd",
                               "--", "--capture", str(output)], project, output / "render.log", env, 360,
                              "R32_04_SHORE_CAPTURE_PASSED"))
        return 0 if all(c["passed"] for c in checks) else 1
    finally:
        source.observe("capture_finished")
        provenance = source.write_report(output)
        report = dict(passed=bool(checks) and all(c["passed"] for c in checks) and provenance["reusable"],
                      checks=checks, provenance=provenance)
        (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"passed":report["passed"],"source":provenance["end"]}),flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
