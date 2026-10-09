#!/usr/bin/env python3
"""Render the focused production-hut slope test in its own original 240 s budget."""
import argparse
import json
import math
from pathlib import Path
import struct
import subprocess
import tempfile
import zlib

from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


TEST = "tribal_camera_floor_world_test"
MARKER = "TRIBAL_CAMERA_FLOOR_PASSED"
PNG = "camera-sphere-slope-close-hut.png"


def numerical_oracles(content):
    def unique_keys(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("Duplicate numerical record key: " + key)
            result[key] = value
        return result

    def record(prefix):
        rows = [json.loads(line[len(prefix):].strip(), object_pairs_hook=unique_keys)
                for line in content.splitlines() if line.startswith(prefix)]
        if len(rows) != 1:
            raise ValueError("Expected exactly one numerical record: " + prefix)
        return rows[0]

    def finite(value):
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
            raise ValueError("Missing or non-finite numerical oracle")
        return value

    physical = record("R33_04_PHYSICAL_SURFACE ")
    stopped = record("R33_04_CLOSE_HUT_WORLD ")
    frame = record("TRIBAL_CAMERA_FLOOR_FRAME ")
    restored = record("TRIBAL_CAMERA_FLOOR_RESTORE ")
    reload = record("CAMERA_FLOOR_RELOAD_METRICS ")
    radius = finite(physical["sphere_radius_m"])
    if not math.isclose(radius, 0.1, abs_tol=1e-6) or finite(physical["sphere_hits"]) != 0 or physical["floor_found"] is not True:
        raise ValueError("Finite camera sphere or physical floor failed")
    if not isinstance(physical["floor_path"], str) or not physical["floor_path"]:
        raise ValueError("Actual physical floor identity is missing")
    if finite(physical["floor_eye_clearance_m"]) < radius:
        raise ValueError("Stopped eye is below or touching its actual physical floor")
    if finite(stopped["eye_clearance_m"]) < 1.9 or finite(stopped["move_m"]) <= 1.0:
        raise ValueError("Original sampled clearance or real obstruction failed")
    if not 0 <= finite(stopped["forward_up_abs"]) < 0.15:
        raise ValueError("Original strict low-angle boundary failed")
    samples = frame["samples"]
    if not isinstance(samples, list) or len(samples) != 9 or min(finite(x) for x in samples) < 0.8:
        raise ValueError("Original nine near-plane terrain/water probes failed")
    if ([finite(x) for x in frame["viewport"]] != [1920, 1080]
            or [finite(x) for x in frame["focus_offset_m"]] != [64, 0]
            or finite(frame["yaw_deg"]) != 90):
        raise ValueError("Focused slope capture conditions changed")
    if not 0 <= finite(restored["distance_m"]) < 0.1:
        raise ValueError("Removing the production hut failed to restore the original orbit")
    if not 0 <= finite(reload["focus_distance_m"]) < 0.01:
        raise ValueError("Live reload failed to return the camera to home")
    if not math.isclose(finite(reload["tilt_deg"]), finite(reload["saved_default_deg"]), rel_tol=1e-5):
        raise ValueError("Live reload lost the original saved camera preference")
    return {"physical_surface": physical, "stopped_eye": stopped,
            "frame": frame, "restored_orbit": restored, "reload": reload}


def verify_png(path):
    """Verify a complete native RGB/RGBA8 PNG, including CRCs and image rows."""
    raw = path.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Required slope image is not a PNG")
    offset = 8
    header = None
    compressed = bytearray()
    ended = False
    idat_finished = False
    while offset < len(raw):
        if offset + 12 > len(raw):
            raise ValueError("Truncated PNG chunk")
        length = struct.unpack(">I", raw[offset:offset + 4])[0]
        kind = raw[offset + 4:offset + 8]
        limit = offset + 12 + length
        if limit > len(raw):
            raise ValueError("Truncated PNG chunk data")
        data = raw[offset + 8:offset + 8 + length]
        crc = struct.unpack(">I", raw[offset + 8 + length:limit])[0]
        if zlib.crc32(kind + data) & 0xffffffff != crc:
            raise ValueError("PNG chunk checksum failed")
        if header is None and kind != b"IHDR":
            raise ValueError("PNG must begin with its image header")
        if kind == b"IHDR":
            if header is not None or length != 13:
                raise ValueError("PNG image header is invalid or duplicated")
            header = struct.unpack(">IIBBBBB", data)
            if header[:2] != (1920, 1080) or header[2] != 8 or header[3] not in (2, 6) or header[4:] != (0, 0, 0):
                raise ValueError("Required native RGB/RGBA8 1920x1080 PNG changed")
        elif kind == b"IDAT":
            if idat_finished:
                raise ValueError("PNG image chunks are not contiguous")
            compressed.extend(data)
        elif kind == b"IEND":
            if length != 0 or not compressed or limit != len(raw):
                raise ValueError("PNG image end is invalid or has trailing data")
            ended = True
        else:
            if compressed:
                idat_finished = True
            if kind[0] & 32 == 0 and kind != b"PLTE":
                raise ValueError("Unknown critical PNG chunk")
        offset = limit
    if not ended or header is None:
        raise ValueError("PNG image is incomplete")
    stride = 1 + 1920 * (3 if header[3] == 2 else 4)
    expected = stride * 1080
    decoder = zlib.decompressobj()
    pixels = decoder.decompress(compressed, expected + 1)
    if (len(pixels) != expected or not decoder.eof or decoder.unused_data
            or decoder.unconsumed_tail or any(pixels[y * stride] > 4 for y in range(1080))):
        raise ValueError("PNG compressed image rows are invalid or incomplete")
    return [1920, 1080]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    project = Path(__file__).resolve().parents[1]
    log_path = output / (TEST + ".log")
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="camera-floor-review-") as temporary:
        with log_path.open("w") as log:
            try:
                result = subprocess.run([str(editor), "--path", str(project), "--rendering-method",
                    "gl_compatibility", "--audio-driver", "Dummy", "--script", f"res://tests/{TEST}.gd",
                    "--", "--capture", str(output)], env=isolated_env(Path(temporary)),
                    stdout=log, stderr=subprocess.STDOUT, timeout=240)
                code = result.returncode
            except subprocess.TimeoutExpired:
                code = 124
    content = log_path.read_text()
    failures = []
    if code != 0:
        failures.append("Native process did not exit 0 within 240 seconds")
    if content.splitlines().count(MARKER) != 1 or ERROR.search(content):
        failures.append("Native success marker missing or engine error reported")
    numeric = None
    try:
        numeric = numerical_oracles(content)
    except (ValueError, KeyError, TypeError, IndexError) as error:
        failures.append(str(error))
    dimensions = None
    png = output / PNG
    if png.exists():
        try:
            dimensions = verify_png(png)
        except (ValueError, struct.error, zlib.error) as error:
            failures.append(str(error))
    if dimensions != [1920, 1080]:
        failures.append("Required original-size slope PNG is missing or resized")
    source_commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=project, text=True).strip()
    source_tree = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=project, text=True).strip()
    report = {"passed": not failures, "test": TEST, "renderer": "gl_compatibility",
              "exit_code": code, "native_timeout_s": 240, "source_commit": source_commit,
              "source_tree": source_tree, "required_png": PNG, "png_dimensions": dimensions,
              "numerical_oracles": numeric, "failures": failures}
    (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    if failures:
        print(content[-6000:], flush=True)
    print(json.dumps(report), flush=True)
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
