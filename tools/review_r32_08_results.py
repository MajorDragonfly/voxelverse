#!/usr/bin/env python3
"""Summarize original native captures; no FPS or integration acceptance."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


def stripe_coverage(phase, footprint):
    """Intersect each pixel interval with stripe segments, without shader math."""
    left, right = phase - footprint / 2.0, phase + footprint / 2.0
    first_cycle = np.floor(left)
    overlap = np.zeros_like(phase)
    for offset in range(int(np.ceil(footprint)) + 1):
        stripe_start = first_cycle + offset + 0.65
        stripe_end = first_cycle + offset + 1.0
        overlap += np.maximum(0.0, np.minimum(right, stripe_end) - np.maximum(left, stripe_start))
    return overlap / footprint


def stripe_error(root, renderer):
    """Independent geometric pixel-area reference for the flat 2m/35-degree view."""
    height = 540
    world_per_pixel = 4.0 * np.tan(np.deg2rad(35.0 / 2.0)) / height
    footprint = world_per_pixel * 2.0
    y = (height / 2.0 - np.arange(height) - 0.5) * world_per_pixel
    results = {}
    for version in ["before", "after"]:
        errors, signals = [], []
        for index in range(24):
            rgb = np.asarray(Image.open(root / f"strata-{version}-{index:02d}.png").convert("RGB"), dtype=float) / 255.0
            gray = rgb[:, 480, 0]
            if renderer == "forward_plus":
                gray = np.where(gray <= 0.04045, gray / 12.92, ((gray + 0.055) / 1.055) ** 2.4)
            coverage = (gray - 0.311) / 0.63
            phase = (96.0 + index * 0.0005 + y) * 2.0
            expected = stripe_coverage(phase, footprint)
            errors.extend((coverage - expected).tolist())
            signals.append(coverage)
        error = np.asarray(errors)
        temporal = np.diff(np.asarray(signals), n=2, axis=0)
        results[version] = {"coverage_rmse": float(np.sqrt(np.mean(error ** 2))),
                            "coverage_max_error": float(np.max(np.abs(error))),
                            "temporal_second_difference_rms": float(np.sqrt(np.mean(temporal ** 2)))}
    results["reference"] = {"world_m_per_pixel": float(world_per_pixel), "stripe_phase_per_pixel": float(footprint),
                            "method": "Projected pixel/stripe segment intersections, independent of shader integral; sRGB decoded for Forward+. Includes PNG quantization and float raster error."}
    return results


def compare(root):
    capture = json.loads((root / "capture.json").read_text())
    samples = []
    for sample in capture["samples"]:
        label = f"{sample['category']}-{int(sample['distance_m'])}m"
        a = np.asarray(Image.open(root / f"{label}-before.png").convert("RGB"), dtype=float) / 255.0
        b = np.asarray(Image.open(root / f"{label}-after.png").convert("RGB"), dtype=float) / 255.0
        change = np.abs(a - b)
        samples.append({"category": sample["category"], "distance_m": sample["distance_m"],
                        "mean_rgb_change": float(change.mean()), "changed_pixels": int(np.count_nonzero(change.max(axis=2))),
                        "before": sample["before"], "after": sample["after"], "geometry_sha256": sample["geometry_sha256"]})
    return {"renderer": capture["renderer"], "adapter": capture["adapter"], "surface_generation": capture["surface_generation"],
            "samples": samples, "rebase": capture["probes"], "target_hardware": False}


def sheet(root, output):
    categories = ["campaign_spawn", "grassland", "desert", "rocky_highlands", "snow", "coast"]
    cell_w, cell_h = 320, 180
    canvas = Image.new("RGB", (cell_w * 3, (cell_h + 22) * 12), "#17212b")
    draw = ImageDraw.Draw(canvas)
    for row, category in enumerate(categories):
        for side, version in enumerate(["before", "after"]):
            for column, distance in enumerate([12, 45, 110]):
                y = (row * 2 + side) * (cell_h + 22)
                path = root / f"{category}-{distance}m-{version}.png"
                draw.text((column * cell_w + 5, y + 5), f"{category} / {distance}m / {version}", fill="white")
                canvas.paste(Image.open(path).convert("RGB").resize((cell_w, cell_h), Image.Resampling.LANCZOS), (column * cell_w, y + 22))
    canvas.save(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True, help="Original artifact directory containing campaign/ and probe/")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    result = compare(args.root / "campaign")
    result["stripe_reference"] = stripe_error(args.root / "probe", result["renderer"])
    (args.output / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    sheet(args.root / "campaign", args.output / "comparison.png")
    print(json.dumps({"renderer": result["renderer"], "samples": len(result["samples"]), "stripe_reference": result["stripe_reference"]}))


if __name__ == "__main__":
    main()
