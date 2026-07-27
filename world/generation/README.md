# World Evolution V2

This layer extends the existing Voxelverse chunk, terrain, collision and visual systems. It does not replace them.

## Generation pipeline

`world_generator_v2.gd` is the global `WorldGenerator` autoload. A world seed configures independent deterministic noise layers for:

- continentality and coast placement
- broad terrain and regional landforms
- mountain regions and ridgelines
- erosion-like valley suppression
- temperature and moisture
- river corridors and inland lake basins
- small-scale terrain detail and regional color variation

The logical height remains continuous. `get_visual_terrain_height()` snaps that height to half-voxel terraces so the terrain keeps a voxel identity without relying on full block staircases.

## Compatibility

The existing terrain chunk calls the same stable API as before:

- `get_terrain_height()`
- `get_visual_terrain_height()`
- `get_biome()`
- `get_biome_color()`
- `get_sea_level()`
- density and world-palette methods

`terrain_chunk_v2.gd` and `terrain_scenic_dressing_v2.gd` only extend biome-specific material and placement rules. Geometry, collision creation, resources, existing objects and shaders remain in the original systems.

## Runtime systems

- `world_manager_v2.gd` stages chunk creation across frames and retains nearby chunks with unload hysteresis.
- `procedural_biome_assets.gd` batches generated trees, shrubs, flowers and mushrooms into a small number of MultiMeshes per chunk.
- `world_presentation_director.gd` tunes the existing environment and adds seeded voxel clouds.

## Controls

- **F7** creates and stores a new seed, then reloads the world.
- **F9** reloads the current seed.
- **F8** opens display settings.
- **F10** cycles display mode.
- **F11** toggles windowed and borderless fullscreen.

## Current limits

Rivers are deterministic noise-guided valleys rather than a full downhill flow-accumulation simulation. The erosion term shapes mountain regions but is not an offline hydraulic erosion pass. Both can later be upgraded behind the same public generator API without changing terrain chunks.
