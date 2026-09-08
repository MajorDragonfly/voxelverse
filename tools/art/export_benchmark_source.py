#!/usr/bin/env python3
"""Export editable, grid-aligned semantic Blockbench cubes into one culled GLB.

The source remains untouched. Rotated/off-grid cubes fail explicitly: apply the
rotation to the voxel sculpture first. Use separately authored sources for LODs.
--check verifies all registered Near GLBs against their .bbmodel sources.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import tempfile
from build_benchmark import ROOT, PACK, Voxels, SLOT, SLOTS, greedy_faces, write_glb


def read_source(path):
    doc = json.loads(path.read_text())
    meta = doc['voxelverse']
    if meta['palette_slots'] != SLOTS:
        raise ValueError(f'{path}: incompatible semantic slot order')
    step = float(meta['voxel_size_metres'])
    metres_per_unit = float(meta['metres_per_unit'])
    vox = Voxels(step, 0)
    for group in doc.get('groups', []):
        if any(abs(v) > 1e-6 for v in group.get('rotation', [0, 0, 0])):
            raise ValueError(f'{path}: bake group rotation before voxel export')
    for cube in doc['elements']:
        if cube.get('type', 'cube') != 'cube' or any(abs(v) > 1e-6 for v in cube.get('rotation', [0, 0, 0])):
            raise ValueError(f'{path}: only unrotated voxel cubes are supported')
        endpoints = [[v * metres_per_unit / step for v in cube[k]] for k in ['from', 'to']]
        if any(abs(v - round(v)) > 1e-5 for point in endpoints for v in point):
            raise ValueError(f'{path}: cube {cube["name"]} is off the {step} m grid')
        lo, hi = [[round(v) for v in point] for point in endpoints]
        if min(hi[i] - lo[i] for i in range(3)) <= 0 or lo[1] < 0:
            raise ValueError(f'{path}: invalid cube bounds')
        face_slots = {math.floor((f['uv'][0] + f['uv'][2]) / 2) for f in cube['faces'].values()}
        if len(face_slots) != 1 or next(iter(face_slots)) not in SLOT.values():
            raise ValueError(f'{path}: each voxel cube must use one valid semantic material slot')
        slot = next(iter(face_slots))
        for x in range(lo[0], hi[0]):
            for y in range(lo[1], hi[1]):
                for z in range(lo[2], hi[2]):
                    if (x, y, z) in vox.cells:
                        raise ValueError(f'{path}: overlapping source cubes')
                    vox.cells[(x, y, z)] = slot
    return vox


def export(source, output, name):
    vox = read_source(source)
    return write_glb(output, greedy_faces(vox), name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, nargs='?')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        manifest = json.loads((PACK / 'manifest.json').read_text())
        count = 0
        with tempfile.TemporaryDirectory(prefix='voxelverse-source-check-') as directory:
            for asset in manifest['assets']:
                if 'benchmark' not in asset.get('tags', []):
                    continue
                sources = asset.get('variant_sources', {'0': asset['source']})
                variants = asset.get('geometry_variants', {'0': asset['lod']})
                for variant, source in sources.items():
                    runtime = ROOT / variants[variant]['near'].removeprefix('res://')
                    rebuilt = Path(directory) / runtime.name
                    export(ROOT / source, rebuilt, runtime.stem)
                    if hashlib.sha256(rebuilt.read_bytes()).digest() != hashlib.sha256(runtime.read_bytes()).digest():
                        raise ValueError(f'{asset["asset_id"]}/{variant}: source/GLB mismatch; re-export the edited source')
                    count += 1
        if count < 7:
            raise ValueError('Missing benchmark source/runtime pairs')
        print(f'Art source round-trip passed: {count} byte-identical Near GLBs')
    elif args.source and args.output:
        if args.output.suffix != '.glb':
            parser.error('--output must be a .glb path')
        print(json.dumps(export(args.source, args.output, args.output.stem), indent=2))
    else:
        parser.error('Use --check, or SOURCE.bbmodel --output RUNTIME.glb')


if __name__ == '__main__':
    main()
