# Voxelverse World Runtime V6

## Target experience

Voxelverse combines two different design goals:

- No-Man's-Sky-like deterministic scale and discovery: a small seed hierarchy must reproduce planets, regions, ecosystems and species without storing the generated world.
- Spore-like creature-phase play: the player edits one creature, moves through an ecosystem, encounters species and later influences evolution and civilization.

## Runtime hierarchy

```text
Universe seed
  -> star-system descriptor (future)
    -> PlanetProfileV6
      -> macro region field
        -> continuous terrain and biome weights
          -> streamed terrain chunks
            -> Near / Mid / Far visual tiers
              -> ecology instances
              -> regional species catalogue
                -> procedural wildlife individuals
```

## Rules

1. Generation code returns deterministic data. It must not depend on scene-tree order.
2. Planet identity is stored in a compact profile, not in generated meshes.
3. Region transitions use overlapping weights. No threshold may directly switch the terrain-height formula.
4. Physical terrain and visual detail are separate. The player does not mine terrain, so collision can remain coarser than the rendered micro-voxel surface.
5. Repeated scenery uses shared meshes and MultiMesh groups.
6. Fauna has a bounded streamer. Chunks never own unlimited AI populations.
7. Species use stable regional seeds; individuals use a species seed plus an individual seed.
8. Saves will eventually persist only deltas: discovered regions, creature lineage, depleted resources, structures and simulation state.

## Current V6 implementation

- `planet_profile_v6.gd`: deterministic planet parameters, palette, flora scale and species count.
- `world_generator_v6.gd`: continuous regional terrain, cached height samples and biome-color blending.
- `micro_voxel_surface_v6.gd`: visual-only 4x4 near-field surface tiles.
- `chunk_lod_controller_v6.gd`: Near/Mid/Far detail selection.
- `procedural_ecosystem_v6.gd`: multiple tree architectures, plant fields and cliff clusters.
- `fauna_streamer_v6.gd`: bounded regional species streaming.
- `procedural_wildlife_v6.gd`: generated creature bodies used as wildlife.

## Next architecture milestones

1. Star-system and multi-planet descriptors.
2. Background region simulation independent of rendered chunks.
3. Species catalogues with diet, locomotion, aggression, social behaviour and environmental fitness.
4. Terrain data workers and mesh pooling.
5. Separate near, mid and far terrain meshes rather than only detail-layer LOD.
6. Save-game deltas and discovery records.
7. Evolution loop connecting encountered species, food web and the creature editor.
