# Editable Voxelverse Art Sources

This directory contains authoring files only. Godot ignores this tree through `.gdignore`.

## Tool ownership

```text
blockbench/  -> .bbmodel voxel assets
blender/     -> .blend complex meshes, LOD work, technical cleanup
krita/       -> .kra UI, palettes, decals and texture source
aseprite/    -> .aseprite optional pixel-specific source
```

## Folder layout

Keep the source hierarchy close to the runtime hierarchy:

```text
art/source/
├── blockbench/
│   ├── environment/
│   │   ├── trees/
│   │   ├── plants/
│   │   ├── rocks/
│   │   └── landmarks/
│   ├── creatures/
│   │   └── parts/
│   └── civilization/
│       ├── buildings/
│       ├── vehicles/
│       └── spaceships/
├── blender/
│   ├── environment/
│   ├── civilization/
│   └── technical/
└── krita/
    ├── ui/
    ├── palettes/
    └── textures/
```

## Runtime exports

Editable source files are never referenced by gameplay code. Exported runtime assets go under `res://assets/packs/` as GLB/PNG/SVG and are registered through a pack `manifest.json`.

Example:

```text
art/source/blockbench/environment/trees/oak_ancient_01.bbmodel
assets/packs/temperate_forest_v1/environment/trees/oak_ancient_01_lod0.glb
assets/packs/temperate_forest_v1/environment/trees/oak_ancient_01_lod1.glb
assets/packs/temperate_forest_v1/environment/trees/oak_ancient_01_lod2.glb
```

The source file can change freely. Player saves keep stable `part_id` / `asset_id` references instead of a hardcoded file path.
