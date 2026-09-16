#!/usr/bin/env python3
"""Render the real shipyard and check pointer input with isolated user data.

Requires a display; on Linux CI run under Xvfb. No campaign saves are touched.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

from check_validation_contracts import revision
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source = revision(project)
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="shipyard-review-") as temp:
        command = [str(editor), "--path", str(project), "--rendering-method", "gl_compatibility",
                   "--audio-driver", "Dummy", "--script", "res://tests/shipyard_test.gd",
                   "--", "--capture", str(output)]
        with (output / "render.log").open("w") as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                    env=isolated_env(Path(temp)), timeout=120)
    log_text = (output / "render.log").read_text()
    screenshots = sorted(p.name for p in output.glob("shipyard-*.png"))
    passed = (result.returncode == 0 and not ERROR.search(log_text)
              and '"passed":true,"test":"shipyard"' in log_text and len(screenshots) == 9)
    report = {"passed": passed, "source": source, "command": command,
              "engine": subprocess.check_output([args.godot, "--version"], text=True).strip(),
              "renderer": "gl_compatibility", "screenshots": screenshots,
              "scope": "Standalone authoring, real module meshes, three sizes, pointer add/cancel, paged hangar picker, symmetric placement and blocked preview"}
    (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"passed": passed, "screenshots": screenshots}), flush=True)
    if not passed:
        print(log_text[-10000:])
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
