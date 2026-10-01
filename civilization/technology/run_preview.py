#!/usr/bin/env python3
"""Launch the prototype in a temporary Godot project without campaign autoloads.

Source folders are referenced by symlink (copied on systems without symlink
permission). Only the isolated project and device user data are writable.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from validation_support import isolated_env, validation_editor
from validation_provenance import SourceRun

ERROR = re.compile(r"SCRIPT ERROR|(?:^|\n)ERROR:|Parse Error|ObjectDB instances leaked at exit")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--verify", action="store_true", help="Run catalog and actual UI input checks")
    parser.add_argument("--capture", action="store_true", help="With --verify, render the UI matrix; requires a display")
    parser.add_argument("--renderer", choices=["gl_compatibility", "forward_plus"], default="gl_compatibility")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.capture and not args.verify: parser.error("--capture requires --verify")
    if args.verify and args.output is None: parser.error("--verify requires --output")
    # Observe the engine from the checked process itself. A separate --version
    # process ignores our bounded project worker pool and provides no UI proof.
    version = None
    output = args.output.resolve() if args.output else None
    if output: output.mkdir(parents=True, exist_ok=True)
    if output and output.is_relative_to(ROOT): parser.error("Write check output outside the checkout, then copy the evidence for delivery")
    source_run = SourceRun(ROOT)
    before = source_run.summary(source_run.start)
    results = []
    with tempfile.TemporaryDirectory(prefix="int30-medieval-preview-") as temporary, validation_editor(args.godot) as godot:
        directory = Path(temporary)
        project = directory / "project"
        project.mkdir()
        for source in ROOT.iterdir():
            if not source.is_dir() or source.name.startswith("."): continue
            target = project / source.name
            try:
                target.symlink_to(source, target_is_directory=True)
            except OSError:
                shutil.copytree(source, target, ignore=shutil.ignore_patterns("__pycache__", ".godot"))
        (project / "project.godot").write_text('''config_version=5
[application]
config/name="Voxelverse Medieval Technology Preview"
run/main_scene="res://civilization/technology/preview_host.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/subwindows/embed_subwindows=true
[rendering]
renderer/rendering_method="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
[internationalization]
locale/fallback="de"
[debug]
file_logging/enable_file_logging=false
file_logging/enable_file_logging.pc=false
[threading]
worker_pool/max_threads=8
''', encoding="utf-8")
        env = isolated_env(directory / "userdata")
        base = [str(godot), "--path", str(project), "--rendering-method", args.renderer, "--audio-driver", "Dummy"]
        if not args.verify:
            return subprocess.call(base, env=env)
        for name in ["technology_catalog_test", "technology_preview_ui_test", "preview_entry"]:
            command = base + ([] if args.capture and name == "technology_preview_ui_test" else ["--headless"])
            command += ["--quit-after", "5"] if name == "preview_entry" else ["--script", f"res://civilization/technology/tests/{name}.gd"]
            if args.capture and name == "technology_preview_ui_test": command += ["--", "--capture", str(output)]
            print("MEDTECH_CHECK_STARTED: " + name, flush=True)
            started = time.monotonic()
            with (output / (name + ".log")).open("w", encoding="utf-8") as log:
                try:
                    process = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
                    code = process.returncode
                except subprocess.TimeoutExpired:
                    code = 124
            content = (output / (name + ".log")).read_text(encoding="utf-8")
            marker = {"technology_catalog_test": "MEDTECH_CATALOG_PASSED", "technology_preview_ui_test": "MEDTECH_UI_PASSED", "preview_entry": "MEDTECH_ENTRY_READY"}[name]
            engine = re.search(r"Godot Engine v([^\s]+)", content)
            observed_version = engine.group(1) if engine else None
            version = observed_version or version
            passed = (code == 0 and not ERROR.search(content) and marker in content
                      and observed_version is not None and observed_version.startswith("4.6.3."))
            results.append({"test": name, "passed": passed, "exit_code": code, "engine": observed_version,
                            "seconds": round(time.monotonic() - started, 3), "command": command})
            if not passed: print(content[-6000:])
        # The sandbox has no autoloads and neither test may create user data.
        userdata_files = [str(path.relative_to(directory)) for path in (directory / "userdata").rglob("*") if path.is_file()]
    images = {}
    for path in output.glob("*.png"):
        data = path.read_bytes()
        dimensions = list(struct.unpack(">II", data[16:24])) if data.startswith(b"\x89PNG\r\n\x1a\n") else None
        images[path.name] = {"sha256": hashlib.sha256(data).hexdigest(), "dimensions": dimensions}
    expected_images = 10 if args.capture else 0
    source_run.observe("prototype_checks", force=True)
    stable = not source_run.blocked
    persistent_files = [path for path in userdata_files if "/shader_cache/" not in path and "/xdg_cache_home/" not in path]
    passed = (all(item["passed"] for item in results) and not persistent_files and len(images) == expected_images
              and all(image["dimensions"] in [[800, 600], [1280, 720], [1920, 1080]] for image in images.values()) and stable)
    report = {"passed": passed, "engine": version, "renderer": args.renderer if args.capture else "headless",
              "source": before, "source_unchanged": stable, "results": results,
              "userdata_files": userdata_files, "persistent_userdata_files": persistent_files, "images": images,
              "scope": "Isolated prototype only; campaign autoloads absent, no production or save integration"}
    (output / "results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": passed, "tests": results, "captures": len(images), "persistent_userdata_files": persistent_files, "source_unchanged": stable}), flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
