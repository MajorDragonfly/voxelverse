# Player-feedback pass — collision, streaming and readable landscapes

Follow-on work: [continuous water and horizon recentering](WATER_CONTINUITY_REPORT.md).

Based on PR #9 head `9eb22b7d49b45e30e4c6fe30b004a8f1f3d86339`, fetched before editing.
The development branch remains `agent/meta-runtime-v8`. PR #9 stays unmerged.

## Changes

- **Solid obstacles:** trunks, woody bushes and all three rock structures have
  compact manifest-authored colliders. One compound body per chunk uses shape
  owners; visual MultiMesh/LOD and creature/editor contracts are preserved.
  Ferns, flowers and grass stay traversable.
- **Earlier loading:** at most two private CPU placement jobs replace main-thread
  sampling. Chunks share main-thread upload/resource budgets. Distance and travel
  priorities refresh every 150 ms, with an extra leading strip and the complete
  surrounding neighbourhood. Height no longer misclassifies vegetation LOD.
- **Landscape visibility:** 192 m formation cells produce ridges, mesas, recessed
  basins and coastal teeth. The same generator supplies a bounded 768 m-wide
  distant land/water mesh, masked wherever playable chunks finish loading.
  There is no underground generation or distant collision/vegetation hierarchy.
- **Breathing room:** a continuous canopy field creates meadows and soft forest
  edges without reducing ground-cover attempt budgets. Trees have 6 m local
  spacing; scenic spawn favours open edges and estimates nearby canopy occlusion.
- **Species silhouettes:** umbrella and slender forked oaks, open and wind-shaped
  conifers, upright/spreading shrubs, rock blades and boulder groups replace eight
  similar structural variants. All seven stable family IDs and 63 LOD bindings
  remain. Eight additional editable `.bbmodel` sources are registered; 15 source
  exports now round-trip exactly.
- **Water:** world-space ripples, depth absorption, moving shore foam, Fresnel sky
  tint and guarded screen refraction share the semantic planetary palette.
  Vulkan and OpenGL use their respective depth reconstruction conventions.

## Verified locally

Godot `4.6.3.stable.official.7d41c59c4`: **41/41** strict validation checks passed,
including import, 15 source round-trips, real collision motion/rays on 12 obstacle
variants, four streaming directions, horizon generation/coverage input, 96 planet
seeds, main scene, save/planet transitions, gameplay/editors, LOD/HLOD and shutdown
at resource-owning stages. The native Linux export and packaged acceptance checks
also passed (import reused from the full validation run).

The four-direction fixture travels at 6 m/s toward chunks two cells away. Those
chunks finished vegetation with **44.26–47.97 m** remaining before their entry
boundary. This is an automated controlled CPU measurement, not a guarantee for
all PCs. It retains the 499 placement attempts per chunk. Main-thread resource and
mesh/collider uploads remain indivisible steps and can exceed the 1.8 ms admission
budget; target-PC frame-time profiling is still required.

| Seed | Archetype | Previous highest nearby terrain | New highest nearby terrain |
|---|---|---:|---:|
| 7919 | Alpine Crown | 9.23 m | 51.31 m |
| 15838 | Ancient Basin | 4.74 m | 35.14 m |
| 23757 | Archipelago | 9.79 m | 22.11 m |
| 31676 | Mesa World | 16.90 m | 37.52 m |
| 39595 | Broken Highlands | 6.98 m | 42.99 m |
| 47514 | Verdant Frontier | 17.81 m | 41.38 m |

Each measurement uses a 17 × 17 grid, 24 m spacing, around that version's scenic
spawn. Spawn positions may differ; this compares the actual starting experience,
not identical coordinates. The dry meadow/forest mix has a separate acceptance
gate. Raw results are in [playtest_followup](review/playtest_followup/).

## Render and delivery gate

All ten push/PR workflow runs passed for runtime commit
`defb38d1f6226635464d9cb89ad5ab3c148b1eac`. Native Windows and Linux exports each
passed ten checks. The [render run](https://github.com/MajorDragonfly/voxelverse/actions/runs/34197542246)
produced **36 actual viewport PNGs per renderer**: scenic/mountain/shore views,
authored LODs, three-species comparisons and HLOD/creature A/B checks. Both
Forward+ and Compatibility passed shader, draw-count and image-parity gates.
Eighteen unedited selected captures and all measurements are preserved in the
[review folder](review/playtest_followup/README.md). The tall-pine comparison
camera was subsequently widened in the offline capture tool; runtime is unchanged.

A second CPU measurement used the real main scene at a fixed 60 process frames/s
and a stationary review player. Survival and predator damage were disabled only
for measurement; normal streaming remained active. Each case used a cold process:

| Seed | First assets before → after | All 25 chunks before → after | Instances before → after |
|---|---:|---:|---:|
| 15838 | 2.81 → 1.36 s | 27.35 → 7.91 s | 2,274 → 838 |
| 23757 | 3.00 → 1.35 s | 30.71 → 7.31 s | 3,093 → 3,336 |

These compare the delivered starting experiences, not identical terrain or asset
workloads. The second planet improves despite more placed instances; the first
now has more open coast and meadow. Horizon completion, GPU rendering and HLOD
settling are not part of the "all 25" timestamp. Reproduce with
`tools/benchmark_streaming_cadence.gd -- 15838` or `-- 23757` using Godot's
`--headless --script` entry point. Raw logs and source commits are recorded in
`review/playtest_followup/streaming_cadence.json`. Software-renderer capture setup
is measured separately and is not a target-PC loading-time guarantee.

## Next useful playtest

Check walking into trunks, large bushes and each rock shape; change direction
several times while moving; compare a meadow, forest edge and distant ridge; inspect
shore water at grazing angles and planet transitions. The additional Blockbench
files are listed in [the source README](source/blockbench/environment/benchmark_v2/README.md).

Remaining production work: target-PC cold-load and frame-time measurements, human
approval of the new silhouettes and water, smoother distant/near terrain handoff,
expanded alien architecture families and downhill river networks. Existing saves
and their formats are preserved; procedural terrain/vegetation is regenerated
with the improved grammar, so old positions can now have a different landscape.
