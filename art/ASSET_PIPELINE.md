# Voxelverse Art Asset Pipeline

## Principle

Editable source art and runtime art are separate.

```text
Blockbench / Blender / Krita
            ↓
      art/source/              <- editable source, ignored by Godot
            ↓ export
      assets/packs/            <- GLB / PNG / SVG used by Godot
            ↓
      AssetCatalog             <- stable asset_id + Near/Mid/Far paths
            ↓
 Modular Assembly / World Runtime
```

The game never depends on `.bbmodel`, `.blend`, `.kra` or `.aseprite` at runtime.

## Shared coordinate standard

- 1 Godot unit = 1 metre.
- Building Builder grid = 0.25 m by default.
- Fine voxel rhythm = about 0.125 m where silhouette/detail benefits from it.
- Up = `+Y`.
- Forward = `-Z`.
- The asset origin sits at its logical attachment point or ground contact.
- Apply/normalize transforms before final export.

Do not permanently fix a bad source scale by changing player blueprint values. If a tool export needs correction, use the authored asset correction metadata or fix the source/export setting so every future asset follows the same scale.

## Blockbench

Blockbench is the default authoring tool for the visual language of Voxelverse.

Use it for:

- trees and vegetation;
- rocks and environmental props;
- creature attachments;
- building modules;
- simple vehicle and spaceship modules.

Use a generic model/project suitable for GLB export rather than a Minecraft-specific format. Keep editable files under:

```text
art/source/blockbench/
```

Export GLB files into their runtime pack under `assets/packs/`.

Example:

```text
art/source/blockbench/environment/trees/oak_ancient_01.bbmodel
assets/packs/temperate_forest_v1/environment/trees/oak_ancient_01_lod0.glb
```

### Blockbench modeling rules

- Spend cubes/voxels on silhouette, not invisible internal geometry.
- Avoid dozens of separate mesh groups for a repeated tree or rock.
- Keep pivots intentional.
- Build repeated families from a common scale convention.
- Prefer palette/material reuse across one biome pack.
- Create LOD1/LOD2 by deleting silhouette-neutral detail rather than simply scaling the whole asset down.

## Blender

Blender is the technical and complex-asset tool.

Use it when Blockbench becomes inefficient:

- complex modular silhouettes;
- mesh cleanup;
- UV work;
- authored animation;
- technical pivots;
- LOD generation;
- large structures;
- ships and landmarks;
- optimization of imported Blockbench geometry.

Keep `.blend` sources under:

```text
art/source/blender/
```

Export GLB to `assets/packs/`.

Blender is not required for every voxel asset. A clean Blockbench GLB should go directly to Godot when no Blender processing is needed.

## Krita / Aseprite

Krita is the default 2D source-art tool. Aseprite is optional for pixel-specific UI work.

Use them for:

- UI icons;
- builder part thumbnails;
- civilization emblems;
- biome/planet palettes;
- decals and masks;
- stylized texture atlases.

Keep source art under `art/source/krita/` or `art/source/aseprite/`. Export only runtime PNG/SVG assets into the appropriate pack or UI folder.

## Runtime asset packs

Every authored runtime asset belongs to an asset pack with a `manifest.json`.

Example:

```json
{
  "schema": 1,
  "enabled": true,
  "pack_id": "temperate_forest_v1",
  "display_name": "Temperate Forest V1",
  "assets": [
    {
      "asset_id": "tree_oak_ancient_01",
      "kind": "environment_tree",
      "source": "art/source/blockbench/environment/trees/oak_ancient_01.bbmodel",
      "lod": {
        "near": "res://assets/packs/temperate_forest_v1/environment/trees/oak_ancient_01_lod0.glb",
        "mid": "res://assets/packs/temperate_forest_v1/environment/trees/oak_ancient_01_lod1.glb",
        "far": "res://assets/packs/temperate_forest_v1/environment/trees/oak_ancient_01_lod2.glb"
      },
      "tags": ["temperate", "forest", "broadleaf"]
    }
  ]
}
```

The runtime `AssetCatalog` discovers enabled manifests under `res://assets/packs/`.

## Stable IDs

There are two deliberately separate IDs:

```text
part_id  -> gameplay/editor identity
asset_id -> authored visual identity
```

A player save stores the stable `part_id` plus transform. A part definition may point to an `asset_id`. The asset catalog then decides which GLB is currently used for that authored asset.

This means we can replace a prototype, add LODs, re-export it from Blender or move to a better art pack without rewriting saved player buildings.

## Procedural fallback

A modular part may retain its current procedural geometry while an authored asset is being created. The assembler uses the authored asset when a registered runtime scene exists; otherwise it renders the procedural geometry.

This allows gradual art replacement instead of a destructive one-time conversion.

## LOD policy

Frequently repeated authored assets should ultimately have:

```text
LOD0 / Near -> full stylized silhouette and important details
LOD1 / Mid  -> remove small branches, trim, recesses and tiny props
LOD2 / Far  -> recognizable mass/color silhouette only
```

If Mid or Far is missing, the catalog falls back to the closest higher-detail asset.

LOD is not only triangle reduction. Also reduce:

- material surfaces;
- tiny alpha/details;
- child nodes;
- shadows;
- collision;
- animation complexity.

## Performance rules

### Environment

Trees, rocks and plants intended for high density must be compatible with shared-mesh instancing / MultiMesh. Prefer one or two mesh/material groups per asset family.

### Buildings

The Building Builder can remain modular while editing. A populated city must use building-level merged geometry/HLOD for runtime distance rendering. Do not render every authored window and balcony as an independent far-distance draw call.

### Collision

Visual mesh detail and collision detail are separate budgets. Repeated decorative detail should not automatically create collision.

## First production pack

The first authored environment pack is:

```text
temperate_forest_v1
```

Initial target:

- 5 tree architecture families;
- 3 shrubs;
- 6 ground plants;
- 3 flowers;
- 4 rock families;
- 2 fallen-log/root families;
- 1 mushroom family.

The procedural biome system will create most visible variation through scale, rotation, palette, density, clustering and family mixing instead of requiring hundreds of manually unique models.

## Quality gate before an asset enters a manifest

1. Correct scale relative to 1 m / 0.25 m reference.
2. Ground/attachment pivot is correct.
3. Front direction is `-Z` where direction matters.
4. No hidden/internal cubes that do not affect silhouette.
5. Material count is justified.
6. Naming uses lower snake case.
7. Near asset loads in Godot without warnings.
8. Mid/Far are supplied for dense or large assets when needed.
9. Asset can be replaced without changing its `asset_id`.
10. The related gameplay `part_id` remains stable.


## Integrated benchmark V2

The first seven semantic environment families now ship in the existing
`temperate_forest_v1` manifest. See [the production architecture](PRODUCTION_ARCHITECTURE.md)
and [source editing/export instructions](source/blockbench/environment/benchmark_v2/README.md).
Each family has three structural variants and authored Near/Mid/Far meshes. The
runtime uses shared meshes, a UV-slot palette shader and staged MultiMesh batches.
The original pipeline prototypes remain historical authoring experiments; the
active environment placement uses the new benchmark manifest entries.
