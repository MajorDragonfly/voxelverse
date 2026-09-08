> Latest player-feedback pass: [PLAYTEST_FOLLOWUP.md](PLAYTEST_FOLLOWUP.md).
> The earlier milestones and measurements below are historical.

# Planet Diversity / Biome / Art Production Pass

## Continuation: actual rendering and bounded HLOD — 2026-09-08

Continued from remote `8a7266d2802ead98ac5adea9bed6d6f8f4d7162e` on the same
development branch. Runtime commit `3ae819fb480a964ff476cda51a45006d65e32775`
passed **all ten push/PR workflow runs**: 40 full runtime checks, native Windows
and Linux exports with 10 checks each, and actual Forward+/Compatibility renders.
PR #9 remains draft, open and unmerged; main was not modified.

- Added repeatable real-driver world/asset captures and frame/draw distributions,
  with isolated saves and explicit software-renderer/target-hardware scope.
  The two reference worlds contain 25 chunks and **2,274 / 3,093 vegetation
  instances**. All seven families are captured in both palettes at all three LODs.
- Added lazy Far vegetation clusters: at most two extra mesh nodes per chunk,
  incremental construction, shared terrain/cluster upload admission, semantic
  palette atlas, preserved Far geometry and immediate Near/Mid return. Capacity
  fallback retains original vegetation. No streaming-radius or density reduction.
- Batched rigid runtime creature voxels per existing animated root. The two
  fixtures drop from **933 / 2,182 geometry nodes to 158 each**. Editor selection,
  attachment roots, saves and adaptive knee articulation retain their contracts.
- Real screenshots exposed inward-facing terrain tops. Restored the legacy
  builder's clockwise front-face correction in the worker path and corrected Far
  and water indices. Tests now validate actual triangle orientation against normals.
- Froze player physics before save-restore/scenic-spawn setup. Review-only combat
  suppression and dense-world/spawn assertions prevent a long software capture
  from silently recording an empty area after the player respawns at the nest.

Controlled Forward+ viewport counters: Far fixtures **14 → 5 / 13 → 5** draws;
creatures **933 → 158 / 2,182 → 158**. Each A/B pair retains its primitive count.
All image comparisons pass; maximum normalized mean RGB error is below 0.000718.
These are measured draw-count reductions, not target-PC FPS claims.

The six CI CPU samples record cluster uploads up to **3.265 ms**, incremental
cluster steps up to **0.698 ms**, and one explicit tree-capacity fallback. The
shared 1.8 ms budget remains an admission target. Cold software-Vulkan world setup
took about **59 / 65 seconds**; neither those times nor four-frame software samples
certify gameplay frame-time stability. Target-PC profiling is still required.

[Render review with 24 preserved Forward+ PNGs and terrain before/after](review/runtime_render/README.md),
[machine-readable evidence](review/runtime_render/evidence.json),
[full runtime CI](https://github.com/MajorDragonfly/voxelverse/actions/runs/34192635647),
[native desktop builds](https://github.com/MajorDragonfly/voxelverse/actions/runs/34192635639),
[actual render CI](https://github.com/MajorDragonfly/voxelverse/actions/runs/34192635631).
Run the target-PC review using [ENVIRONMENT_REVIEW.md](../docs/ENVIRONMENT_REVIEW.md).

Next production work: review the benchmark in motion, measure the target PC, then
improve sightlines through nearby vegetation at scenic spawns. The captured worlds
show dense foreground canopies, while the current scenic viewshed only considers
terrain. Expand approved silhouettes and landmark composition after that review.

## Initial production pass and earlier acceptance

Date: 2026-09-07. Branch: `agent/meta-runtime-v8`. PR #9 remains open and unmerged.
Started from remote head `3689a9cbb0782567ec7ab67dbf7941d5d91caccd` after inspecting
the PR and failed V9 workflow. The base/main branch was not modified.

## Delivered

- Fixed the reserved `trait` identifier in the V9 signature builder and removed
  the generator's dependency on compile-time autoload initialization order.
  V9 was activated only after its candidate project passed import, all tests and
  the real main scene. It remains the active generator in `project.godot`.
- Integrated 23 semantic material slots, curated natural/exotic companion colors,
  planet/species palette textures, atmosphere and water (preserving water opacity).
- Added continuous biome composition, five forest variants, family placement,
  fauna selection weights, local mist and deterministic family/species/individual
  variation. Existing asset IDs, saves and modular assembly interfaces stay valid.
- Added surface landmark grammar and a bounded scenic terrain viewshed. Search
  expands beyond ocean starting areas. Canonical height-cache samples remove
  query-order dependence. No cave/underground work was added.
- Delivered seven editable benchmark sources and 63 one-surface GLBs: three
  structural variants × three authored LODs. Added a source exporter and a
  byte-identical source/GLB round-trip gate. Source and review trees are ignored
  by Godot import.
- Moved Near/Far terrain generation to owned worker jobs, bounded concurrent jobs
  and main-thread uploads, and staged vegetation/resources across frames.
  Removed the prototype vegetation inheritance from the active placement path.
  Explicit generation states, cancellable terrain callbacks and main-thread
  resource creation address the reproduced shutdown leaks.

## Art inventory

Triangle counts for default structural variant (all variants are validated):

| Asset ID | Near | Mid | Far |
|---|---:|---:|---:|
| ancient_oak_v2 | 28524 | 5810 | 1448 |
| tall_pine_v2 | 18324 | 3748 | 792 |
| dense_bush_v2 | 7256 | 1238 | 326 |
| fern_cluster_v2 | 9260 | 3136 | 1414 |
| flower_cluster_v2 | 6692 | 1914 | 242 |
| layered_rock_v2 | 1804 | 482 | 112 |
| grass_tuft_v2 | 2824 | 694 | 146 |

Sources: `art/source/blockbench/environment/benchmark_v2/`.
Runtime: `assets/packs/temperate_forest_v1/environment/benchmark_v2/`.
Review: `art/review/benchmark_v2/benchmark_lineup.png`, `lod_comparison.png` and
`planet_palette_comparison.png`. These show actual GLB geometry in CPU previews.
They are not screenshots of Godot's rendered world.

## Validation evidence

Godot `4.6.3.stable.official.7d41c59c4`: clean import; source round trip; all 14
GDScript test entry points; actual main scene for 300 frames. The complete local
run passed with no engine errors or leak warnings. Evidence is recorded in
`art/review/benchmark_v2/validation_results.json`; CI uses the same strict runner.

The CI runner also quits the real main scene after 45/150/300 frames and runs
12 separate cold-process shutdown cases: terrain work, plant placement, pending
resource loads and completed vegetation, each on verdant/autumn/violet seeds.
The expanded full job has **32 checks**, including a cold/warm streaming benchmark,
with strict error and ObjectDB leak detection. Full logs are uploaded as workflow artifacts.
All six push/PR workflow runs for runtime commit
`247997c9bc81e3fc9ad530f0c9dc5e3ca203dce0` passed, including every shutdown case.
[Full CI run](https://github.com/MajorDragonfly/voxelverse/actions/runs/34155137475).
The 32 results and final CPU samples are preserved in
`art/review/benchmark_v2/ci_validation_results.json`.

These stage-specific cases reproduced an intermittent exit warning missed by
the original 300-frame smoke run. Terrain visuals still awaited a signal on
chunks that could unload before emitting it. They now use one-shot callbacks
disconnected at tree exit and process-based retries. The remaining zero-reference
resource/mesh warnings, followed by texture allocation errors under owned worker
loads, led to main-thread resource creation: a shared queue admits one uncached
scene per frame. Terrain computation remains on data-only workers. Pending asset
loads are cancelled on teardown. The regression probes remain in CI; errors are
not ignored and failed jobs are not retried into success.

Runtime coverage includes Creature Builder data/editor, legacy creature migration,
bite/combat and inspection, persistence/progression, modular assembly/building
contracts, terrain continuity, planet catalog and real A → B → A scene reloads.
New checks exercise all 63 imported meshes, UV slots, palette upload, missing LOD
fallback, worker/synchronous data parity, actual terrain/water/MultiMesh nodes,
LOD swaps, deterministic chunk reload and cancellation releasing generation state.

Across 96 seeds: **50 natural and 46 exotic palettes**, six surface-formation
kinds and five forest variants. Every tested seed provided a dry, walkable spawn.
Seed examples: verdant `15838`, autumn `63352`, violet `23757`.

## CPU performance evidence

Same comparison seed `424242`, chunks `(0,0)`, `(1,0)`, `(2,0)`: the original V9
candidate blocked main-thread chunk creation for **201 / 182 / 171 ms**. The final
worker path measured **3.10 / 0.19 / 0.17 ms** for creation plus **9.57 / 7.31 /
5.72 ms** for mesh/collision upload. Only one upload is committed per frame.

A populated seed-7919 chunk produces **241 instances in 15 MultiMesh nodes**;
the scene caps batches at 21 per chunk. After the final resource-lifetime change,
six cold/warm samples in the green CI run measured **0.09–0.52 ms** chunk creation,
**3.59–4.35 ms** mesh/collision upload, **5.50 ms** maximum resource step and
**0.46 ms** maximum placement step. The actual CPU benchmark is part of the full
CI job and its samples are in `ci_validation_results.json`.

Only one uncached scene resource is created per frame across all chunks. The shared
1.8 ms budget is checked between steps and is not a hard frame-time guarantee.
Earlier local samples remain in `streaming_cpu_measurements.json`; absolute times
from local and CI hosts are not directly comparable. These headless measurements
identify CPU costs. GPU draw time, shader compilation hitches and target-PC FPS
still require target-hardware testing.

## Desktop export acceptance

Commit `dc50d56d23155eb1636af45ca6ce6df9a8da175c` passed all eight push/PR
workflow runs, including **10 export checks each on native Windows and Linux**.
The existing full Godot suite remains green with **32 checks**.
[Export run and downloadable builds](https://github.com/MajorDragonfly/voxelverse/actions/runs/34188063652).
Exact job results, artifact digests and expiry dates are recorded in
[export_validation_evidence.json](../docs/export_validation_evidence.json).

The release executable receives a main-scene smoke check outside the repository.
Instrumented gameplay, all 63 meshes, three palettes, persistence and A-B-A planet
transitions use the **unchanged release PCK** with the same-version editor,
because official release templates disable external test-script overrides.
Builds include catalog manifests and engine notices; art sources and test tools
are excluded. Headless checks do not certify GPU or visual quality. See
[DESKTOP_EXPORT.md](../docs/DESKTOP_EXPORT.md) for build commands and test scope.

## Open production gates and next step

1. Visually approve the seven `.bbmodel` files listed in the source README in
   Blockbench, then in Godot with real lighting/shadows/wind. Check fern connections,
   ground contact, repeated silhouettes and every LOD transition. Art is delivered
   for review, not declared finally approved.
2. Profile GPU/CPU frame times on the target PC in a dense biome. Tune plant LOD
   distances and the new bounded HLOD/capacity fallback before extending the
   streaming radius. Benchmark props are decorative; selected hero-tree collision
   remains a separate task.
3. The current family compiler supplies three structures per family. Arbitrary
   branch count/twist/taper recipes, additional alien architectures, functional
   natural arches, distant horizon streaming and downhill river networks remain
   future production work. Existing rivers/lakes remain procedural height fields.

Next: approve the benchmark and capture one dense verdant scene plus one violet
scene on target hardware, then expand approved families and distant landscape
composition using the measured budgets. Architecture details and source/export
commands are in [PRODUCTION_ARCHITECTURE.md](PRODUCTION_ARCHITECTURE.md).
