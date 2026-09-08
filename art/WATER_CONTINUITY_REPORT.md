# Continuous water and horizon recentering — 8 September 2026

**Delivery status:** Publication to `agent/meta-runtime-v8` was explicitly
authorized by Lars on 8 September 2026. All local runtime and Linux export
checks passed. The new graphical comparisons are implemented and parser-checked;
Forward+ and Compatibility results will be recorded after the publishing run.
No target-PC performance or human visual acceptance is claimed.

Continues PR #9 on `agent/meta-runtime-v8`, based on verified remote head
`378574bc52fa7dbd2badc2fbededf3a15508b60d`. The previous collision, vegetation,
landscape and silhouette pass is already included. This pass addresses the
remaining water handoff rather than redoing that work.

## Behaviour

The active world now uses one water mesh spanning 768 × 768 metres. Its inner
256 × 256 metres use a 2 m grid, with 8 m spacing outside. A shared, indexed grid
connects those regions without independent edges or overlapping transparent
tiles. The horizon worker builds the arrays using its private generator; the
main thread publishes them under the existing upload budget.

Until that surface is ready, chunks retain their local water. Publication hides
fully covered local meshes in the same frame. Partially covered chunks clip only
their intersection; water outside the previous surface remains available during
a teleport. Removing the horizon restores the local surfaces. The terrain's
loaded-chunk mask is independent of water ownership.

Both paths now use the same inspector settings and planetary material slots.
This fixes different near/distant opacity, per-chunk wave speeds, and ignored
foam, refraction, secondary-wave and specular settings. A world-anchored 32 m
stillness field smoothly reduces wave/ripple amplitude around calm regions;
wave phase remains shared. Absorption and shore foam use the rendered bed depth,
without a separate per-chunk depth estimate that can create colour bands.

The horizon retains its current centre until the player moves more than 96 m
along either horizontal axis, then recentres on the existing 64 m grid. Repeated
movement across a rounding boundary no longer launches repeated terrain jobs.
Old geometry remains visible until the new arrays are published.

## Cost and acceptance

The shared water has a fixed **37,249 vertices / 73,728 triangles**, with no
interior open edges. Settled water uses one visible mesh instead of a distant
mesh plus up to 25 local water meshes at the default streaming radius. The new
water has more triangles than the previous approximately 38,432-triangle
combined water workload; fewer draws do not establish a target-GPU speedup.
Local fallback meshes remain allocated for continuity.

One sequential cold-process comparison at 60 process frames/s used the same
scenic spawns and the same 838 / 3,336 instances before and after:

| Seed | First objects before → after | All 25 chunks before → after |
|---|---:|---:|
| 15838 | 1.51 → 1.50 s | 6.56 → 7.21 s |
| 23757 | 1.56 → 1.30 s | 8.31 → 8.08 s |

This single sample per case does not establish a speedup. The smaller scene took
0.65 s longer to fully populate; the denser one finished 0.23 s earlier. These
are CPU-only observations, not GPU frame-rate measurements. Raw logs preserve
the comparison rather than hiding the slower case.

`water_continuity_test.gd` verifies the actual mesh topology and winding, negative
world coordinates, calm-region interpolation, material settings, complete and
partial coverage, a 1,448 m diagonal teleport, fallback restoration on teardown,
and recentering in four directions. The render tool adds actual GPU image
comparisons with an intentionally overlapping negative control; see
[environment review](../docs/ENVIRONMENT_REVIEW.md).

Local Godot 4.6.3 validation passed **42/42** strict checks, and the Linux
release export passed **9/9** checks with import reused from that run.
Validation evidence is recorded in `art/review/water_continuity/`. Headless
checks establish runtime correctness; the two-renderer image gate establishes
rendering behaviour. Neither substitutes for Lars' visual review or measurements
on his Windows PC.

## Remaining work

The distant **land** mesh still uses coarse geometry and hard loaded-chunk
masking; this pass does not claim to solve land silhouette or seam transitions.
Water continues to use the generator's existing sea level. Downhill river
networks, different lake levels and additional alien asset families remain
separate work. Creature/Building Builders, combat, progression, collisions,
ecology, planet generation and save formats retain their existing contracts.
