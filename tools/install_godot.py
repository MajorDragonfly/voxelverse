#!/usr/bin/env python3
"""Install the pinned Godot editor and desktop templates in a portable directory."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import urllib.request
import zipfile

VERSION = "4.6.3"
BASE = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable"
ASSETS = {
    "linux": (f"Godot_v{VERSION}-stable_linux.x86_64.zip",
              "d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3"),
    "windows": (f"Godot_v{VERSION}-stable_win64.exe.zip",
                "e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90"),
    "templates": (f"Godot_v{VERSION}-stable_export_templates.tpz",
                  "3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8"),
}


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def download_verified(directory, asset):
    name, checksum = asset
    target = directory / name
    if target.is_file() and digest(target) == checksum:
        return target
    partial = target.with_suffix(target.suffix + ".part")
    print(f"Downloading {name}", flush=True)
    with urllib.request.urlopen(f"{BASE}/{name}", timeout=180) as response, partial.open("wb") as output:
        shutil.copyfileobj(response, output, length=1024 * 1024)
    actual = digest(partial)
    if actual != checksum:
        raise RuntimeError(f"SHA256 mismatch for {name}: expected {checksum}, got {actual}")
    partial.replace(target)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--platform", choices=["linux", "windows"],
                        default="windows" if os.name == "nt" else "linux")
    args = parser.parse_args()
    directory = args.directory.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    archive = download_verified(directory, ASSETS[args.platform])
    editor_dir = directory / "editor"
    editor_dir.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        # Select known top-level files, never arbitrary archive paths.
        for member in bundle.namelist():
            if "/" not in member and member.startswith(f"Godot_v{VERSION}-stable_"):
                with bundle.open(member) as source, (editor_dir / member).open("wb") as output:
                    shutil.copyfileobj(source, output)
    (editor_dir / "_sc_").touch()
    editor_name = (f"Godot_v{VERSION}-stable_win64_console.exe" if args.platform == "windows"
                   else f"Godot_v{VERSION}-stable_linux.x86_64")
    editor = editor_dir / editor_name
    editor.chmod(0o755)
    templates = editor_dir / "editor_data/export_templates" / f"{VERSION}.stable"
    templates.mkdir(parents=True, exist_ok=True)
    template_archive = download_verified(directory, ASSETS["templates"])
    names = ["linux_debug.x86_64", "linux_release.x86_64",
             "windows_debug_x86_64.exe", "windows_release_x86_64.exe"]
    with zipfile.ZipFile(template_archive) as bundle:
        for name in names:
            with bundle.open(f"templates/{name}") as source, (templates / name).open("wb") as output:
                shutil.copyfileobj(source, output)
            (templates / name).chmod(0o755)
    metadata = {"version": VERSION, "editor": str(editor), "templates": str(templates)}
    (directory / "toolchain.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(json.dumps(metadata), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, zipfile.BadZipFile, KeyError) as error:
        sys.exit(str(error))
