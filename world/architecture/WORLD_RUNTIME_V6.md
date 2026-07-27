# Voxelverse Layered World Runtime V7

## Target experience

Voxelverse combines two separate design goals:

- deterministic planetary scale and discovery: a compact hierarchy of seeds reproduces star systems, planets, regions, ecosystems and modular species without storing rendered worlds;
- a Spore-like creature phase: the player builds one creature from body shaping and modular parts, then returns to the builder later and changes that same current creature.

There is no genetics, genome or mutation system. Player-creature development is represented only by deliberate rebuilding, newly available parts and the saved assembly revision.

## Runtime hierarchy

```text
System seed
  -> deterministic planet catalogue
    -> active planet / world seed
      -> PlanetProfile
        -> continuous macro region field
          -> streamed terrain chunks
            -> integrated Near / Mid terrain material
            -> worker-built Far terrain proxy
            -> ecology MultiMeshes
          -> chunk-independent region simulation
            -> regional resource state
            -> modular species catalogue
              -> bounded visible wildlife representatives
```

## Terrain rules

1. Region transitions use overlapping weights. No threshold may switch the complete terrain-height formula.
2. The visible pixel pattern is part of the real terrain material. No second surface may float above the collision terrain.
3. Near and Mid use the collision-matching voxel terrain mesh. Far may use a lower-resolution proxy because it is not traversed locally.
4. Worker threads receive value data only. Nodes, resources and rendering objects are changed on the main thread.
5. Far ArrayMesh containers are pooled when chunks unload.
6. Repeated trees, plants, rocks and cliffs use shared meshes and MultiMesh groups.

## Creature-builder rules

1. The saved player creature is an assembly, not a genome.
2. The body is shaped through the editable spine and body profile.
3. Mouths, eyes, limbs, tails, horns, plates, spikes and decoration are modular placements.
4. Placements use body-surface sockets and may use bilateral symmetry.
5. Undo and redo operate on complete assembly snapshots.
6. A saved revision records that the player rebuilt the creature; it does not represent a mutation.
7. Part-derived abilities and movement stats are calculated from the current assembly.
8. Old V5 saves are migrated once and all genetic or mutation metadata is discarded.

## Ecology rules

1. Wild species are deterministic modular assemblies built from the same part catalogue.
2. A species seed is only a procedural world identifier; it is not biological genetic data.
3. Region simulation stores populations and resource quantities, not thousands of invisible animal Nodes.
4. Visible wildlife is selected from the simulated regional populations.
5. Ecological roles currently include foragers, grazers, scavengers, predators, climbers and swimmers.
6. Population changes depend on plants, water, carcasses, carrying capacity and predation.

## Current V7 implementation

- `planet_catalog_v7.gd`: deterministic systems containing three to six planets;
- `star_system_runtime_v7.gd`: active-planet service and temporary F8 planet travel;
- `terrain_surface.gdshader`: integrated 0.125-unit Near detail and blended Mid detail;
- `terrain_chunk_v7.gd`: full local terrain plus worker-built Far proxy;
- `terrain_far_mesh_job_v7.gd`: thread-safe value-data mesh construction;
- `terrain_mesh_pool_v7.gd`: reusable Far ArrayMesh containers;
- `ocean_surface.gdshader`: depth-aware water, shoreline foam and refraction;
- `region_background_simulation_v7.gd`: chunk-independent food-web state;
- `fauna_streamer_v7.gd`: bounded visible population representatives;
- `species_assembly_factory_v7.gd`: modular wildlife species without genetics;
- `creature_editor_v7.gd`: body shaping, modular parts, sockets, symmetry and history;
- `creature_assembly_blueprint_v7.gd`: genetics-free player-creature save format.

## Remaining milestones

1. Persist regional simulation deltas and discoveries in save games.
2. Add a real planet-selection and travel scene instead of the F8 debug switch.
3. Pool complete chunk render resources and scenery MultiMeshes, not only Far ArrayMeshes.
4. Add social behaviour, feeding interactions, combat and reproduction as gameplay systems without introducing a genetics model.
5. Add unlockable creature parts tied to exploration and creature-phase progress.
6. Add foot placement and procedural gait adaptation for arbitrary limb layouts.
7. Add full planet-scale streaming and eventually spherical planetary terrain.
