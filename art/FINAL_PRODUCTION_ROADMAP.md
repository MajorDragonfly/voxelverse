# Voxelverse Final Production Roadmap

## North-star target

Voxelverse combines:

- fine voxel readability and organic silhouette work;
- dense, handcrafted-looking biome composition;
- strong planet-to-planet procedural diversity;
- player-authored creatures, buildings, vehicles and spaceships;
- scalable runtime rendering suitable for large worlds and later cities.

The project does **not** spend its complexity budget on a deep underground or cave world. Surface composition, atmosphere, flora, fauna, landmarks and civilization receive that budget instead.

## Final-generation architecture

```text
Planet seed
  -> Planet Profile V9
      -> terrain archetype
      -> climate
      -> visual color family
      -> material slots
      -> atmosphere
      -> biome recipe
      -> flora morphology
      -> rare world traits
  -> macro terrain
  -> biome grammar
  -> local biome variants
  -> authored asset families
  -> procedural species variants
  -> instance variation
  -> Near / Mid / Far LOD
  -> streamed final world
```

A planet is therefore not a recolored map. It has a coherent visual fingerprint.

## Phase A - Final foundation

Status: **active**

Deliverables:

1. `PlanetProfileV9`
   - coherent natural and exotic foliage families;
   - purple, cyan, coral, crimson, gold and pale worlds are possible;
   - climate and atmosphere stay deterministic per seed;
   - material slots are independent from authored geometry;
   - rare traits create stronger planet identities.

2. `BiomeGrammarV9`
   - biomes are composition packages, not only terrain colors;
   - each biome defines tree, shrub, ground-cover, rock and hero-asset density;
   - each biome has local sub-variants such as ancient grove, flower meadow, wind cliff and swamp grove;
   - transitions remain broad enough to avoid hard biome seams.

3. `FloraSpeciesFactoryV9`
   - one authored family can generate multiple species recipes;
   - species vary height, width, crown density, branch density, taper, twist and asymmetry;
   - individual instances vary scale, lean, rotation and hero-tree probability;
   - palette comes from the planet, not from a permanently green tree mesh.

4. Asset catalog and manifests
   - stable `asset_id` values;
   - optional `family`, `tags`, `palette_slots`, `morphology` and LOD metadata;
   - authored source remains outside Godot import through `art/source/.gdignore`.

## Phase B - Art benchmark V2

Build six production-quality reference families before mass production:

- Ancient Oak / broad ancient tree;
- Tall Pine / conifer;
- Dense Bush;
- Fern cluster;
- Flower cluster;
- Layered rock outcrop.

Each benchmark must pass:

- recognizable silhouette as a black shape;
- meaningful asymmetry;
- no large Minecraft-like cube masses;
- proper root / branch / leaf layering where relevant;
- palette-slot compatibility;
- clean pivot and scale;
- Near / Mid / Far plan;
- acceptable repeated-instance cost.

Only after these six are approved do we expand the pack.

## Phase C - Temperate / Verdant Production Pack

Target authored families:

- 5-7 tree architecture families;
- 4 shrub families;
- 8-12 ground plants;
- 5 flowers / fungi;
- 5 rock families;
- 3 deadwood / root families;
- 3 shore / wetland families;
- 2 hero landmarks.

The runtime should produce far more visible variants than authored source models.

## Phase D - Planet diversity packs

Add reusable morphology and asset families for:

- autumn woodland;
- pine highlands;
- wetland / swamp;
- rocky plateau / mesa;
- island / coast;
- alien bloom;
- fungal world;
- sparse giant-flora world;
- wind-shaped alpine world;
- pale / high-contrast alien world.

These are not mutually exclusive planet presets. PlanetProfileV9 can mix compatible traits and palettes so a world can become, for example, a violet alpine archipelago or a crimson ancient basin.

## Phase E - Runtime scalability

Required before dense production scenes:

- MultiMesh for repeated vegetation;
- chunk-local batches for small ground clutter;
- Near / Mid / Far vegetation LOD;
- terrain Far LOD / horizon solution;
- collision only for nearby gameplay-relevant assets;
- hero assets as separate streamed objects;
- generation budgets split across frames;
- later worker-thread pure-data generation where profiling justifies it.

## Phase F - Civilization continuity

The same production philosophy continues into the city phase:

```text
Player building designs
  -> stable modular blueprint
  -> architecture family / palette
  -> district rules
  -> procedural city placement
  -> building HLOD
```

Cities use the player's architecture instead of developer-authored fixed house sets.

## Non-negotiable rules

- authored geometry must not hardcode a planet's final foliage color;
- player saves reference stable IDs, never disposable mesh filenames;
- every repeated environment family must have an LOD strategy;
- visual detail is spent on silhouette and layering before tiny hidden geometry;
- exotic planets still use coherent palettes, not arbitrary random RGB values;
- biome diversity comes from composition, morphology and atmosphere as well as color;
- no system should require a future rewrite merely to add a new planet color, biome family or tree architecture.
