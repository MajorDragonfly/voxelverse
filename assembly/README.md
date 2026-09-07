# Voxelverse Modular Assembly Framework

The long-term rule is simple: procedural worlds provide opportunities, while the player designs the identity of their species and civilization.

The same assembly concepts are shared by:

```text
Modular Assembly Framework
├── Creature Builder
├── Building Builder
├── Vehicle Builder
└── Spaceship Builder
```

## Core contract

Every assembly is a compact blueprint containing:

- assembly type;
- display name and revision;
- modular part IDs;
- position, rotation and scale per part;
- optional sockets, mirror groups and tags;
- type-specific metadata.

`assembly/core/modular_assembly.gd` owns the generic transform and serialization rules. `modular_assembly_history.gd` provides generic snapshot undo/redo.

## Runtime rendering

Procedural voxel definitions are merged into a single `ArrayMesh` by `modular_voxel_mesh_builder.gd`. This avoids one Node per cube.

`modular_asset_assembler.gd` also supports authored external assets. A part definition may specify:

```gdscript
{
    "id": "roof_custom_01",
    "scene_path": "res://assets/civilization/roofs/roof_custom_01.glb"
}
```

This allows Blockbench or Blender GLB exports to enter the same blueprint system without changing saved player designs.

## Source-art layout

Recommended repository layout:

```text
art/
├── references/
└── source/
    ├── blockbench/
    ├── blender/
    └── krita/

assets/
├── environment/
├── creatures/
├── civilization/
└── ui/
```

Source files (`.bbmodel`, `.blend`, `.kra`) remain editable source art. Godot runtime assets should normally be `.glb`, `.png` or `.svg` under `assets/`.

## Building Builder V1

The first non-creature consumer is `civilization/buildings/building_builder.tscn`.

It supports:

- structural masses;
- roofs;
- towers;
- doors and windows;
- balconies;
- supports;
- utilities;
- decoration;
- grid snapping;
- translation, rotation and scale;
- duplicate/delete;
- undo/redo;
- building type and gameplay stats;
- multiple saved player designs.

The city phase can later populate settlements using the player's saved residential, commercial, industrial, civic, military and harbor blueprints instead of fixed developer-authored buildings.

## Creature migration

The current Creature Builder remains active and stable. `creature_assembly_adapter.gd` exposes its existing parts in the common assembly format. This is intentionally an adapter first: the live Creature Builder can be migrated subsystem-by-subsystem without invalidating current creature saves.

## Next consumers

Vehicle and spaceship builders should use the same blueprint, history, external-asset and transform rules. Their differences belong in part libraries, socket rules, stats and runtime behavior—not in a new editor architecture.
