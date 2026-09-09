#!/usr/bin/env python3
"""Run the real progression GUI with isolated saves and retain viewport captures."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--gameplay", action="store_true", help="Exercise real F/H behavior input and earned purchases")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="voxelverse-progression-gui-") as temporary:
        isolation = Path(temporary)
        # The standard installer is portable (_sc_). A separate executable
        # without that marker makes XDG_DATA_HOME actually isolate this run.
        editor = isolation / "godot"
        shutil.copy2(args.godot, editor)
        editor.chmod(0o755)
        env = {**os.environ, "XDG_DATA_HOME": str(isolation / "data"),
               "XDG_CONFIG_HOME": str(isolation / "config"), "LIBGL_ALWAYS_SOFTWARE": "1"}
        process = subprocess.run([str(editor), "--path", str(args.project.resolve()),
                                  "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                                  "--script", "res://tools/review_behavior_gameplay.gd" if args.gameplay else "res://tests/behavior_skill_tree_test.gd", "--", "--capture", str(output)],
                                 env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
    (output / "gui.log").write_text(process.stdout)
    error = re.search(r"SCRIPT ERROR|(?:^|\n)ERROR:|Parse Error|ObjectDB instances leaked", process.stdout)
    expected = {"skilltree_empty.png": None, "skilltree_available.png": None,
                "skilltree_1600x900.png": (1600, 900), "skilltree_1280x720.png": (1280, 720),
                "skilltree_800x900.png": (800, 900), "journal.png": (1600, 900)}
    if args.gameplay:
        expected = {name + ".png": (1600, 900) for name in ["befriending", "befriended", "earned_skill", "tribe_preview", "helped"]}
    images = []
    for name, dimensions in expected.items():
        path = output / name
        data = path.read_bytes() if path.exists() else b""
        actual = struct.unpack(">II", data[16:24]) if data.startswith(b"\x89PNG") else None
        images.append({"file": name, "dimensions": actual, "passed": len(data) > 4096 and actual is not None and (dimensions is None or actual == dimensions)})
    marker = "BEHAVIOR_GUI_OK" if args.gameplay else "PROGRESSION_UI_OK"
    passed = process.returncode == 0 and not error and marker in process.stdout and all(image["passed"] for image in images)
    (output / "review.json").write_text(json.dumps({"passed": passed, "renderer": "gl_compatibility", "exit_code": process.returncode, "captures": images}, indent=2) + "\n")
    print(process.stdout[-6000:])
    print(json.dumps({"passed": passed, "captures": images}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
