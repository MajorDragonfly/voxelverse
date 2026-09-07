# Voxelverse Art Asset Pipeline

## Shared scale

- 1 Godot unit = 1 metre.
- Building Builder placement grid = 0.25 m by default.
- Fine environment voxel rhythm = 0.125 m where useful for visual detail.
- Asset origin should normally sit at the logical attachment/base point.
- Forward direction for authored modular parts is `-Z`.
- Up is `+Y`.

## Blockbench

Use Blockbench as the default authoring tool for stylized voxel assets:

- trees and vegetation;
- rocks and environmental props;
- creature attachments;
- building modules;
- simple vehicle and spaceship modules.

Keep editable source files under:

```text
art/source/blockbench/
```

Export runtime files as GLB to the corresponding `assets/` folder.

Example:

```text
art/source/blockbench/civilization/roof_harbor_01.bbmodel
assets/civilization/buildings/roof_harbor_01.glb
```

A GLB building part can be connected to the assembly framework by adding a `scene_path` to its part definition. Existing player building blueprints continue to reference the same stable `part_id`.

## Blender

Use Blender when an asset needs work that is inefficient in Blockbench:

- more complex modular silhouettes;
- mesh cleanup;
- UV work;
- authored animation;
- collision helpers;
- LOD generation;
- large structures, ships and landmarks.

Keep `.blend` sources under:

```text
art/source/blender/
```

Export runtime assets as `.glb`.

Do not apply high-detail geometry merely because it is available. Runtime assets need Near/Mid/Far budgets appropriate to their use.

## Krita / Aseprite

Krita is the default 2D source-art tool. Aseprite is optional for pixel-specific work.

Use them for:

- UI icons;
- builder part thumbnails;
- civilization emblems;
- biome/planet palettes;
- decals and masks;
- stylized texture atlases.

Keep source art under:

```text
art/source/krita/
```

Export runtime images to `assets/ui/`, `assets/environment/` or another relevant runtime folder.

## Stable part IDs

The most important rule is that an authored asset and a player save are decoupled.

A saved design stores:

```text
part_id + position + rotation + scale
```

It does not store a hardcoded mesh.

Therefore a primitive prototype such as `roof_gable_red` can later be replaced by a high-quality Blockbench GLB while old player designs continue to load.

## LOD policy

For dense worlds and cities, authored assets should ultimately provide:

```text
Near: full stylized geometry
Mid: simplified geometry / reduced small detail
Far: cluster, impostor or very low detail silhouette
```

Small repeated objects should prefer MultiMesh or merged chunk batches instead of individual Nodes.

## City phase rule

Cities are not authored as complete static maps. The player authors reusable building designs in the Building Builder. Settlement generation then places and varies those designs according to district, terrain and civilization rules.
