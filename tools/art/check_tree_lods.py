#!/usr/bin/env python3
"""Check actual tree LOD exports and ground-to-tip voxel connectivity."""
import hashlib
import math
from pathlib import Path
import random
import tempfile

from build_benchmark import BUILDERS, FAMILIES, RUNTIME, Voxels, greedy_faces, write_glb


class ObservedVoxels(Voxels):
    def __init__(self, step, seed, connected):
        super().__init__(step, seed, connected)
        self.stem = None

    def path(self, points, radii, slot, rough=0.0):
        if self.stem is None:
            self.stem = points
        super().path(points, radii, slot, rough)


def reaches_tip(vox):
    def cell(point):
        return tuple(max(0, math.floor(v/vox.step)) if i == 1 else math.floor(v/vox.step)
                     for i, v in enumerate(point))
    start, end = cell(vox.stem[0]), cell(vox.stem[-1])
    if start not in vox.cells or end not in vox.cells:
        return False
    seen, pending = {start}, [start]
    while pending:
        point = pending.pop()
        if point == end:
            return True
        for axis in range(3):
            for direction in [-1, 1]:
                neighbor = list(point)
                neighbor[axis] += direction
                neighbor = tuple(neighbor)
                if neighbor in vox.cells and neighbor not in seen:
                    seen.add(neighbor)
                    pending.append(neighbor)
    return False


def check():
    checked = controls = 0
    with tempfile.TemporaryDirectory(prefix="tree-lod-check-") as folder:
        for family in FAMILIES[:2]:
            for variant in range(3):
                seed = 7177 + FAMILIES.index(family)*917 + variant*7907
                for tier, step, label in [(1, 0.25, "mid"), (2, 0.5, "far")]:
                    vox = ObservedVoxels(step, seed, True)
                    BUILDERS[family](vox, random.Random(seed), tier, variant)
                    assert reaches_tip(vox), f"{family}/{variant}/{label}: disconnected stem"
                    old = ObservedVoxels(step, seed, False)
                    BUILDERS[family](old, random.Random(seed), tier, variant)
                    controls += not reaches_tip(old)
                    suffix = "" if variant == 0 else f"_species{variant}"
                    name = family + suffix + "_" + label
                    rebuilt = Path(folder) / (name + ".glb")
                    write_glb(rebuilt, greedy_faces(vox), name)
                    expected = RUNTIME / rebuilt.name
                    assert hashlib.sha256(rebuilt.read_bytes()).digest() == hashlib.sha256(expected.read_bytes()).digest(), f"{name}: stale exported LOD"
                    checked += 1
    assert controls > 0, "Connectivity check did not detect the original under-sampling defect"
    print(f"Tree LOD check: {checked} exact exports with connected stems; {controls} original failures detected")


if __name__ == "__main__":
    check()
