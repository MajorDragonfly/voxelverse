#!/usr/bin/env python3
"""Reject orphan metadata, generated duplicates and development files in exports.

This is a source check, not a dead-code detector: dynamic loaders, migration
fixtures and inherited versions still require review before removal.
"""
import argparse
import configparser
import fnmatch
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BENCHMARK = "assets/packs/temperate_forest_v1/environment/benchmark_v2/"
DEV_DIRS = ("art", "tools", "tests", "docs", "validation", "evidence")
IGNORED_TREES = ("art/source", "art/review", "docs", "validation", "evidence")


def read_config(path):
    config = configparser.ConfigParser(interpolation=None)
    config.read_string(path.read_text(encoding="utf-8"))
    return config


def check(project):
    inventory = subprocess.check_output(
        ["git", "-C", str(project), "ls-files", "--cached", "--others",
         "--exclude-standard", "-z"], text=True)
    paths = {name for name in inventory.split("\0") if name and (project / name).is_file()}
    errors = []
    for name in sorted(paths):
        path = Path(name)
        if any(part in {".godot", "__pycache__"} for part in path.parts) or path.parts[0] in {"builds", "godot-toolchain"}:
            errors.append(f"Generated cache/build file in source inventory: {name}")
        if path.suffix in {".uid", ".import"} and name.removesuffix(path.suffix) not in paths:
            errors.append(f"Orphan metadata without source: {name}")
        if name.startswith(BENCHMARK):
            if name.endswith(".glb.import"):
                config = read_config(project / name)
                if config.get("params", "gltf/embedded_image_handling", fallback="") != "3":
                    errors.append(f"Keep benchmark palettes embedded losslessly (mode 3): {name}")
            elif name.endswith(".png.import") and "generator_parameters" in (project / name).read_text():
                errors.append(f"Generated palette duplicate; keep its GLB image embedded: {name}")
    for directory in IGNORED_TREES:
        if f"{directory}/.gdignore" not in paths:
            errors.append(f"Missing import boundary: {directory}/.gdignore")
    exports = read_config(project / "export_presets.cfg")
    presets = [section for section in exports.sections() if section.startswith("preset.") and section.count(".") == 1]
    if not presets:
        errors.append("No export presets to check")
    for preset in presets:
        excluded = json.loads(exports.get(preset, "exclude_filter", fallback='""')).split(",")
        for directory in DEV_DIRS:
            if not all(any(fnmatch.fnmatchcase(probe, pattern.strip()) for pattern in excluded)
                       for probe in (f"{directory}/example.gd", f"{directory}/nested/example.png")):
                errors.append(f"{preset} can package development resources: {directory}/")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        errors = check(args.project.expanduser().resolve())
    except (OSError, ValueError, configparser.Error, subprocess.SubprocessError) as error:
        errors = [str(error)]
    if errors:
        print("PROJECT_HYGIENE_FAILED:\n" + "\n".join(errors), file=sys.stderr)
        return 1
    print("PROJECT_HYGIENE_PASSED: metadata, embedded palettes, import and export boundaries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
