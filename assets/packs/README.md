# Runtime Asset Packs

Only Godot-ready runtime assets belong here. Editable Blockbench, Blender and Krita files stay under `art/source/`.

Each pack owns a `manifest.json` and its exported files:

```text
assets/packs/<pack_id>/
├── manifest.json
├── environment/
├── creatures/
├── civilization/
└── ui/
```

## Manifest schema

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

`asset_id` must remain stable. Runtime file names, source programs and LOD meshes may change without invalidating player saves.

## LOD naming

- `_lod0` = Near, full stylized form
- `_lod1` = Mid, remove small silhouette-neutral detail
- `_lod2` = Far, strong silhouette simplification

If Mid or Far is not supplied, the runtime falls back to the closest available higher-detail asset.

## Performance rules

Environment assets intended for dense placement should use as few MeshInstance/material surfaces as possible so they can later be extracted into MultiMesh batches. A tree should normally be one or two mesh/material groups, not dozens of child meshes.

Building modules may be richer in the editor, but city runtime rendering should ultimately operate on building-level HLOD/merged geometry rather than hundreds of individually rendered modules.
