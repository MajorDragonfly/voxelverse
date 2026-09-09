# Voxelverse Visual Style Guide

## Target identity

Voxelverse combines four design references without copying any single game's assets:

- fine, tactile voxel readability and layered surfaces;
- dense, adventurous biome composition;
- strong planet-to-planet procedural diversity;
- player-authored creatures, buildings and later vehicles/spaceships.

The result must not read as Minecraft. Large forms are organic and scenic; voxel detail is the rendering language, not the terrain-generation rule.

## Scale hierarchy

Visual detail is built in layers:

```text
Planet / continent     -> hundreds to thousands of metres
Region / landmark      -> tens to hundreds of metres
Terrain silhouette     -> metres
Authored asset form    -> 0.25-1.0 m modules
Fine voxel rhythm      -> ~0.125 m where useful
```

Do not force 0.125 m geometry everywhere. Fine voxel rhythm can come from authored silhouette, material treatment or shader detail. Geometry density is spent where it changes the silhouette.

## Terrain

- no underground world requirement;
- no extensive cave-generation budget;
- terrain generation prioritizes mountains, valleys, cliffs, plateaus, coasts, islands, rivers and lakes;
- biome borders must blend through ecological transition zones instead of hard material seams;
- mountains require long-range ridge structure plus local peaks, not only amplified noise;
- navigable local slopes and ledges must remain compatible with creature movement.

## Biomes

A biome is a composition package, not a color switch. Each biome controls:

- terrain palette;
- water palette;
- fog / atmosphere bias;
- tree families;
- shrub and ground-cover families;
- rock and cliff families;
- density rules;
- landmark probabilities;
- fauna weighting;
- transition rules to adjacent biomes.

Biome packs should share some assets so transitions feel natural while retaining distinctive hero assets.

## Authored environment assets

### Trees

Use recognizable architecture families rather than random cubes:

- broad crown;
- columnar / tall;
- windswept;
- ancient / massive;
- young / sparse;
- conifer;
- wetland;
- coastal;
- dead / fallen.

Variation comes from scale, palette, crown density, branch modules and procedural placement. Do not create a unique Node hierarchy for every individual tree.

### Rocks

Prioritize silhouette groups:

- field stones;
- boulders;
- slab rock;
- cliff teeth;
- layered strata;
- monolith / landmark.

### Plants

Ground plants are authored as small reusable clusters, then rendered through MultiMesh/instancing and density fields.

## Materials and palette

Favor a controlled stylized palette over photorealistic PBR. Materials should preserve readable planes and voxel edges.

- roughness generally high;
- metallic only when semantically appropriate;
- avoid noisy high-frequency textures that fight the voxel form;
- use a small number of material surfaces per repeated asset;
- palette variation should happen through shared material parameters where possible.

## LOD and scalability

Every frequently repeated authored asset is designed for Near / Mid / Far from the beginning.

Near preserves silhouette-defining detail. Mid removes small branches, trim and recesses. Far reduces the object to its recognizable mass and color grouping.

Dense scenes must be assembled from shared meshes, MultiMesh batches, chunk clusters or building-level HLOD. A city must never render every window, balcony and roof module as a separate long-distance draw call.

## Creatures and civilization

Player identity is authored through modular builders.

- Creature Builder: body + modular anatomy;
- Building Builder: architecture modules;
- Vehicle Builder: later;
- Spaceship Builder: later.

The same saved `part_id` survives visual asset replacement. Player creativity is persistent even as the art quality improves.
