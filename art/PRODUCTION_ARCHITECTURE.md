# Planet diversity and environment production

The active generator remains an extension of the Adventure generator. V9 adds
composable palette, climate, ecology and surface-formation fields; it does not
replace creature, building, save or assembly contracts. No new version ladder or
underground generation was introduced.

## Palette contract

`assets/catalog/planet_material_slots.gd` owns an append-only list of 23 slots.
The exported mesh has one surface. Each face stores `(slot_index + 0.5) / 32` in
UV.x and `0.5` in UV.y. A nearest-filtered 32 × 1 palette texture supplies the
planet/species colors. Adding a slot must preserve all existing indices.

The shared `planet_foliage.gdshader` resolves these slots; MultiMesh custom data
carries bounded individual shade and wind phase. Meshes are shared across planets.
Materials are shared per species on the current planet. This avoids duplicating
geometry for a palette and avoids one material surface/draw per semantic slot.
Vertex colors remain available to other asset pipelines. UV-slot encoding is an
explicit manifest capability, not a global reinterpretation of all GLB assets.

Curated companion hues keep foliage, shrubs, bark, soil, minerals and water in
separate roles. For example, seed 23757 uses violet crowns, turquoise shrubs,
dark indigo bark and blue minerals. Seed 15838 is verdant; seed 63352 is autumnal.
Terrain strata/wet surfaces, water, sky, horizon, mist and sunlight consume the
same profile. Local biome mist interpolates gradually around the player.

## Ecology and surface grammar

Categorical biome IDs remain available for inspection and gameplay. Rendering
and placement use normalized continuous weights, including desert. Local variants
blend seeded 96 m patches with smooth interpolation at negative and positive cell
boundaries. Forest composition changes tree, fern, flower and shrub density.
Alpine regions favor conifers and rocks. Fauna weights select visible regional
representatives without rewriting persisted populations.

Landscape formations live in seeded 192 m cells: curved ridges, flat-topped mesas,
basins, rock spires, grove hills and coastal teeth. Compact-support functions
join without seams; existing mountains, canyons, lakes and islands remain in the
Adventure terrain stack. The terrain height cache evaluates canonical centimetre
coordinates, so its results do not depend on which nearby point was queried first.

Scenic spawn evaluates 84 safe candidates, then terrain viewsheds for the best
twelve. Twelve rays sample 15–360 m; an angular horizon rejects occluded water and
relief. Landmark visibility uses additional intervening height samples. Searches
expand when the starting area is water. Nearby ecology estimates canopy occlusion; buildings are not included. Spawn
selection prefers meadow/forest edges, with 9 m tree clearance and 3.5 m woody
obstacle clearance. A continuous 125 m canopy field adds walk-scale openings.
Ridges reach 32–58 m before composition; total terrain remains bounded to -9–96 m.
See the [playtest follow-up](PLAYTEST_FOLLOWUP.md) for sampled relief.

## Family → species → individual

Seven authored benchmark families each supply three structural variants and three
semantic LODs. Species are deterministic by planet seed, biome key, family and
species index. They select a structural variant, bounded height/breadth and a
related leaf palette. Individuals add modest scale, yaw, lean, age/health shade
and occasional giant-tree scale. Species ordering does not depend on family-list
ordering. Save-facing asset IDs and existing assembly schemas are preserved.

The current runtime uses three compiled structures per family. Arbitrary branch
count, trunk twist, taper and canopy-layer recipes are an authoring/compiler
extension point; they are not all synthesized into new topology at runtime.
Do not describe the current seven-family pack as unlimited alien morphology.
Additional architecture families should follow visual approval of this benchmark.

## Streaming and lifecycle

Terrain workers own private, detached generators with explicit seed overrides.
They return value arrays for Near and Far terrain and collision heights. They
never touch the shared WorldGenerator, scene tree or RenderingServer. The main
thread commits at most one completed chunk per frame; the manager caps concurrent
terrain jobs at two. The first spawn collider is ready before player physics
resumes. Every terrain task is joined when its chunk exits.

Player physics is frozen in WorldManager's `_ready()`, before the two save-restore
frames. Otherwise a slow rendered frame can move the default player before scenic
spawn selection. Its previous physics state is restored after the spawn collider.

Near worker quads, Far proxy indices and water indices use Godot's clockwise
front-face convention. The worker rewrite had lost the older terrain builder's
winding correction, hiding top surfaces with back-face culling. Production tests
now compare triangle winding with outward normals for the actual generated arrays.
The real-driver screenshots caught this defect that parser/mesh-existence tests
could not. See [ArrayMesh winding](https://docs.godotengine.org/en/4.6/classes/class_arraymesh.html).

Vegetation uses a cancellable `_process` state machine, with a shared 1.8 ms
budget checked between bounded placement/resource/batch steps. This is a scheduling
target, not a hard upper bound on any individual allocation or OS scheduling delay.
The state owns its RNG and dictionaries; no suspended generation coroutine can
strand them during planet reload or engine shutdown. Terrain material readiness
uses a one-shot signal connection disconnected at tree exit; legacy retries run
through node processing. Pending terrain callbacks hold no coroutine state.

Authored resources enter a shared queue. At most one uncached imported scene is
loaded and reduced to its shared mesh on the main thread per frame, across all
chunks. Requests are deduplicated and all LODs are prepared before a batch appears.
Queued, unstarted loads are cancelled at world teardown; no resource work starts
during teardown. Meshes remain cached for subsequent chunks and planets.

Resource creation stays on the main thread because the Godot 4.6.3 shutdown
probes exposed zero-reference loader tokens/mesh RIDs with status-polled threaded
loading, and concurrent texture-allocation errors with owned background loads.
The latter allocator is not thread-safe in the
[4.6.3 dummy renderer](https://github.com/godotengine/godot/blob/4.6.3-stable/servers/rendering/dummy/storage/texture_storage.h).
Terrain generation continues on data-only workers. Cold resource parsing/upload
is an indivisible step which can exceed the shared 1.8 ms scheduling target, so
the full CI job records actual cold/warm streaming timings after the shutdown
probes. A hard latency cap would require an additional predecoded mesh format or
a loading-stage warmup; asset density remains governed by biome composition.

Each chunk contains at most 21 MultiMesh nodes. Explicit conservative AABBs include individual transforms and wind margin.
LOD switching reuses meshes and has distance hysteresis. Small plants disappear at
Far; trees/rocks/shrubs retain mass. Shadows are enabled only for Near trees.

Far chunks lazily compile two additional ArrayMesh groups: trees and low vegetation
(shrubs/rocks), keeping their separate visibility distances. The compiler transforms
the existing Far mesh vertices/normals and preserves semantic UV slots, species
palette rows and individual shade; it does not remove instances or simplify the
silhouette. A 32-column palette atlas supplies all species in a group. Tiny foliage
wind is omitted at Far. Near/Mid MultiMeshes remain available for immediate return.

Cluster construction advances in 256-vertex steps under the same 1.8 ms budget.
Terrain and clusters share one mesh-commit admission per frame. Each group has a
65,536-vertex/196,608-index cap; invalid input or capacity exhaustion retains the
original Far MultiMeshes. Groups become visible atomically and cached clusters
are reused across LOD changes. Leaving Far pauses construction; chunk teardown
releases partial arrays without suspended coroutines. The maximum is 23 geometry
nodes per chunk. This trades bounded, duplicated Far geometry for fewer draws;
the separate horizon renderer covers distant surface destinations.

Terrain retains its 65 × 65 heightmap collider. Each populated chunk additionally
owns one compound `EnvironmentObstacles` StaticBody3D under `Objects`. Manifest
recipes define trunk/shrub capsules and rock hulls, including variant-specific
hulls. Shape owners are not nodes; dimensions include individual scale while body
transforms remain orthonormal. Grass, flowers and ferns remain traversable.
Collision is published with its visible batch and survives visual LOD changes.
See [Godot shape owners](https://docs.godotengine.org/en/4.6/classes/class_collisionobject3d.html).

Environment placement now runs in at most two owned CPU jobs, using private
seeded generators and the chunk's immutable surface grid. Resource loading,
MultiMesh uploads and physics remain on the main thread. Jobs are joined on exit.
Streaming priorities update every 150 ms from horizontal distance and predicted
travel, including an extra leading strip. The full surrounding square remains
required. Terrain uploads and environment processing follow the same priority;
altitude no longer incorrectly chooses a distant vegetation LOD.

A separate CPU horizon job samples the same terrain/biome functions over a 768 m
square at 8 m spacing. Two mesh nodes display distant land and water, without
vegetation or collision. The old horizon stays visible until its successor is
ready after 64 m movement. A 16 × 16 nearest-filtered coverage texture excludes
finished terrain chunks. This is a bounded surface preview, not extra gameplay
chunks. Its triangle spacing and the transitions still require target-PC review.

Water uses world-space waves and fragment ripples, depth absorption, moving
intersection foam, Fresnel sky tint and guarded screen refraction. Foreground
samples are rejected. Depth reconstruction handles Vulkan and OpenGL NDC ranges
explicitly, following [Godot's depth reconstruction](https://docs.godotengine.org/en/4.6/tutorials/shaders/advanced_postprocessing.html).
The shared shader also covers distant water; planets retain their semantic slots.

## Runtime creature geometry

Actual rendered-world counters exposed thousands of individual voxel boxes in
runtime creature previews. Rigid boxes now share one unit BoxMesh/vertex-color
material and one MultiMesh per existing animated body slice or attachment root.
The editor preview, blueprint/save format, attachment metadata and animation roots
remain unchanged. Leg boxes remain individual because the adaptive animator
reparents them into knee rigs; parity tests exercise that real reparenting and motion.

Vegetation and creature batches upload one packed instance buffer. Tests inspect
these exact transforms/colors rather than individual instance getters, which are
no-ops in Godot 4.6.3's dummy renderer. Real-driver image and draw-count comparisons
provide an additional gate; see [ENVIRONMENT_REVIEW.md](../docs/ENVIRONMENT_REVIEW.md).

## Validation and export

Run `python3 tools/validate_godot.py --godot /path/to/Godot_4.6.3`.
It isolates test saves, imposes timeouts and fails on logged engine/script errors
even when Godot returns zero. CI imports the project, checks source/GLB round trips,
runs every `tests/*.gd` entry point and starts the actual main scene. Tests cover
96 profiles, loaded meshes and UV slots, missing-LOD fallback, worker parity,
actual staged MultiMesh placement, terrain/water resources and A → B → A scene
reloads. Existing builder, combat, persistence and assembly tests remain enabled.
The full runner also probes actual main shutdown during terrain work, placement,
pending resource loads, completed vegetation, partial HLOD and published HLOD on
three fixed palette seeds. Together with runtime cluster/buffer parity tests,
main-scene probes and the CPU benchmark, the full runner now has 40 checks.
Each case starts a separate process with cold asset caches. These catch teardown
leaks that a short frame-count-only smoke test can miss.

Packed exports must include `assets/packs/**/manifest.json` through the export
preset's non-resource include filter and retain the catalog-referenced runtime
GLBs. Source `.bbmodel` files and review PNGs are excluded by their `.gdignore`.
Desktop release exports now have presets and a separate native-platform CI gate;
see [DESKTOP_EXPORT.md](../docs/DESKTOP_EXPORT.md) for the executable/PCK checks and
their precise limits. GPU acceptance remains separate from headless validation.

Technical basis: [Godot MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html),
[background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html),
[Blockbench model format](https://www.blockbench.net/wiki/docs/bbmodel/).
