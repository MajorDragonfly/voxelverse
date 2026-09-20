#!/usr/bin/env python3
"""Exercise pause/settings through the public entry and capture both phases."""
import argparse
import json
from pathlib import Path
import subprocess
import struct
import tempfile
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    def git(*command):
        return subprocess.check_output(["git", *command], cwd=project, text=True).strip()
    source = {"commit": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
              "dirty": bool(git("status", "--porcelain"))}
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="pause-review-") as temporary:
        env = isolated_env(Path(temporary))
        env["VOXELVERSE_PAUSE_CAPTURE_DIR"] = str(output)
        command = [str(editor), "--path", str(project), "--rendering-method", "gl_compatibility",
                   "--audio-driver", "Dummy", "--", "--pause-menu-smoke"]
        with (output / "render.log").open("w") as log:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=300)
    log = (output / "render.log").read_text()
    images = [f"{phase}-{locale}-{page}.png" for phase in ["creature", "tribe"]
              for locale in ["de", "en"] for page in ["pause", "graphics", "audio"]]
    sizes = {}
    for name in images:
        path = output / name
        if path.is_file():
            header = path.read_bytes()[:24]
            if len(header) == 24 and header[:8] == b"\x89PNG\r\n\x1a\n":
                sizes[name] = list(struct.unpack(">II", header[16:24]))
    unchanged = source["commit"] == git("rev-parse", "HEAD") and not git("status", "--porcelain")
    passed = (result.returncode == 0 and "PAUSE_MENU_PASSED" in log and not ERROR.search(log)
              and all(sizes.get(name) == [1280, 720] for name in images) and unchanged and not source["dirty"])
    report = {**source, "passed": passed, "source_unchanged": unchanged, "command": command,
              "images": images, "image_sizes": sizes, "scope": "Public entry, real sphere/tribal handoff; DE/EN, 720p/1080p, 80%/130% UI, keyboard/mouse, pause/focus/back and graphics apply/discard. Native Linux rendering; no target-PC acceptance."}
    (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    if not passed:
        print(log[-8000:])
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
