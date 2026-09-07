# Art benchmark V2 — review sources

Open these editable Generic/Free Blockbench models:

- `ancient_oak_v2.bbmodel`
- `tall_pine_v2.bbmodel`
- `dense_bush_v2.bbmodel`
- `fern_cluster_v2.bbmodel`
- `flower_cluster_v2.bbmodel`
- `layered_rock_v2.bbmodel`
- `grass_tuft_v2.bbmodel` (additional ground-cover reference)

The models are original voxel sculptures, not assets extracted from reference
games. One metre equals 16 Blockbench authoring units. Large forms use 0.125 m
Near voxels; the bush uses 0.0625 m and fine plant stems/leaflets use 0.03125 m.
All pivots are at the base and face UVs identify semantic material slots. The
embedded preview atlas is only an authoring palette. Runtime recoloring uses the
planet/species atlas without changing geometry.

Review silhouette at player distance, branch/root continuity, fern leaflet
connections, petal readability, ground contact and the transitions shown in
`art/review/benchmark_v2/lod_comparison.png`. The CPU previews show actual exported
geometry but do not certify Godot lighting, shadows, wind or target GPU performance.
The art benchmark still needs that visual acceptance before expanding the pack.

## Editing and export

Keep cubes aligned to the model's voxel grid, do not rotate cube/group transforms,
and keep each cube assigned to one semantic slot. The exporter rejects unsupported
rotations, off-grid coordinates, overlapping cubes and invalid palette indices.

Export an edited source without regenerating it:

```sh
python3 tools/art/export_benchmark_source.py \
  art/source/blockbench/environment/benchmark_v2/ancient_oak_v2.bbmodel \
  --output assets/packs/temperate_forest_v1/environment/benchmark_v2/ancient_oak_v2_near.glb
python3 tools/art/export_benchmark_source.py --check
```

Review/update Mid and Far silhouettes whenever the Near silhouette changes. Export
separately authored LOD sources to the corresponding manifest paths; preserve the
asset ID and slot order. Mid removes twigs/leaflet density; Far preserves silhouette
masses and broad palette groups. Automatic Godot mesh LOD generation is disabled
for these assets so it cannot silently replace the authored decisions.

`tools/art/build_benchmark.py` is the deterministic family authoring compiler. It
recreates the baseline seven sources and 63 GLBs (three structures × three LODs).
Running it again overwrites the corresponding source sculptures: commit artist
edits first and use the source exporter for subsequent manual changes. Its
`--families` option limits regeneration to specified families. Structural variants
are generated from the same family construction rules, not arbitrary vertex noise.
