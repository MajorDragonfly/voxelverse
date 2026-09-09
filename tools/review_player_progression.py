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
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--gameplay", action="store_true", help="Exercise real F/H behavior input and earned purchases")
    mode.add_argument("--development", action="store_true", help="Exercise phase wallets, development path and saved home-group contract")
    mode.add_argument("--tribe", action="store_true", help="Exercise confirmed transition, group orders and the village economy")
    mode.add_argument("--supply", action="store_true", help="Exercise renewable food, supply targets and resumed meals")
    mode.add_argument("--tribe-world", action="store_true", help="Exercise a tribe in the generated main world")
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
        script = ("res://tests/tribal_age_world_test.gd" if args.tribe_world else
                  "res://tests/tribal_age_supply_test.gd" if args.supply else
                  "res://tests/tribal_age_test.gd" if args.tribe else
                  "res://tests/development_path_test.gd" if args.development else
                  "res://tools/review_behavior_gameplay.gd" if args.gameplay else
                  "res://tests/behavior_skill_tree_test.gd")
        try:
            process = subprocess.run([str(editor), "--path", str(args.project.resolve()),
                                      "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                                      "--script", script, "--", "--capture", str(output)],
                                     env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=240 if args.tribe_world else 180)
        except subprocess.TimeoutExpired as error:
            log = error.stdout or b""
            log = log.decode(errors="replace") if isinstance(log, bytes) else log
            (output / "gui.log").write_text(log + "\nERROR: graphical validation timed out\n")
            print(log[-6000:])
            return 1
    (output / "gui.log").write_text(process.stdout)
    error = re.search(r"SCRIPT ERROR|(?:^|\n)ERROR:|Parse Error|ObjectDB instances leaked", process.stdout)
    expected = {"skilltree_empty.png": None, "skilltree_available.png": None,
                "skilltree_1600x900.png": (1600, 900), "skilltree_1280x720.png": (1280, 720),
                "skilltree_800x900.png": (800, 900), "journal.png": (1600, 900)}
    if args.gameplay:
        expected = {name + ".png": (1600, 900) for name in ["befriending", "befriended", "earned_skill", "tribe_preview", "helped"]}
    elif args.development:
        expected = {name + ".png": (1600, 900) for name in ["development_empty", "development_saved", "tribe_wallet", "development_legacy"]}
        expected.update({name + ".png": (800, 900) for name in ["development_800x900", "tribe_800x900"]})
    if args.tribe:
        expected = {name + ".png": (1280, 800) for name in ["01_confirmation", "02_group", "03_transport", "04_tool", "05_village"]}
    elif args.tribe_world:
        expected = {"06_generated_village.png": None}
    elif args.supply:
        expected = {name + ".png": (1280, 800) for name in ["07_garden", "08_supply", "09_meal"]}
        expected["10_supply_narrow.png"] = (800, 900)
    images = []
    for name, dimensions in expected.items():
        path = output / name
        data = path.read_bytes() if path.exists() else b""
        actual = struct.unpack(">II", data[16:24]) if data.startswith(b"\x89PNG") else None
        images.append({"file": name, "dimensions": actual, "passed": len(data) > 4096 and actual is not None and (dimensions is None or actual == dimensions)})
    marker = '"test":"tribal_age_supply"' if args.supply else '"test":"tribal_age_world"' if args.tribe_world else '"test":"tribal_age"' if args.tribe else "DEVELOPMENT_PATH_OK" if args.development else "BEHAVIOR_GUI_OK" if args.gameplay else "PROGRESSION_UI_OK"
    passed = process.returncode == 0 and not error and marker in process.stdout and all(image["passed"] for image in images)
    (output / "review.json").write_text(json.dumps({"passed": passed, "renderer": "gl_compatibility", "exit_code": process.returncode, "captures": images}, indent=2) + "\n")
    print(process.stdout[-6000:])
    print(json.dumps({"passed": passed, "captures": images}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
