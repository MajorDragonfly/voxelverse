# Terrain transitions and connected rivers / lakes

Date: 8 September 2026. Development branch: `agent/meta-runtime-v8`, Draft PR #9.

## Behavior

The detailed block surface now starts on the same world-aligned triangles as the distant landscape and morphs into its final shape over 0.65 seconds. An 8 m border band keeps the outer terrain attached to the horizon. A shared coverage image also carries neighboring LOD progress. Entering Far LOD morphs onto the nested 2 m proxy before releasing the detailed mesh; approaching reverses the same transition. Unloading fades geometry back toward the horizon, and returning during retirement reverses that fade. Collision stays on the playable terrain throughout. Render bounds include both morph endpoints.

The active planet generator now adds deterministic drainage features in 384 m regions. Routes choose terrain-guided meanders and monotonically descending water profiles. Elevated spring lakes have a flat surface through their outlet; routes continue toward a receiving basin or the ocean. Lake and river beds, containing banks, biome colors, vegetation exclusion, terrestrial fauna placement, safe scenic spawns, drinking and the contextual drink hint all use the local water level. Ocean mouths preserve existing submerged connections. The original terrain formula is read separately while routing, avoiding recursive generation and order-dependent results.

The existing continuous 768 m water surface retains its budget of 37,249 vertices / 73,728 triangles. It now follows local water heights and carries flowing-river / still-lake styling. Local fallback subdivisions are rounded onto a nested grid; during partial horizon coverage their edge matches the actual old water triangles. This avoids opening a vertical seam when teleporting across an elevated river. Shared ownership, opacity settings and recenter hysteresis remain in use.

## Scope

This is a deterministic terrain-generation model, not a fluid simulation. Regional routes remain bounded and independent; continental drainage between catchments, tributary junctions, dynamic erosion, swimming and waterfalls are future work. There are no new asset families in this package. Creature development remains discovery and deliberate building, without genetics or mutation gameplay.

## Acceptance

- `drainage_network_test.gd`: 37 routes, 246 chunk crossings and 10 elevated lakes across seeds 15838, 23757 and 424242; downstream water levels, submerged continuous beds, flat lakes, repeatability, dry scenic spawns, actual player-ray drinking, and fallback geometry matched against the actual shared mesh.
- `terrain_transition_test.gd`: negative-coordinate chunk edges, horizon/proxy endpoints, delayed handoff, reversal, retirement and retained collision.
- Existing streaming and production tests now check the new coverage channels and wait for the intentional LOD morph before requiring the Far proxy.
- **44/44** full local checks and **9/9** native Linux package checks passed. Full local validation and native Linux release evidence are in `art/review/terrain_hydrology/`.
- Renderer CI adds five real viewport captures per seed: drainage overview, lake shore and terrain presence 0 / 50 / 100. The image gate requires distinct intermediate geometry. Forward+ and Compatibility run the full existing visual suite as well. Compact JPEG previews in CI logs allow review alongside the original PNG artifacts.

Publication and final graphical results are recorded in PR #9 after the runs complete. Software-renderer functional checks do not establish performance on the target Windows PC.

## Places to inspect

Seed 15838, world X/Z and absolute water height (sea = 0):

| Lake | X | Z | Water height |
|---|---:|---:|---:|
| Upland spring | 103.3 | -526.2 | 13.79 |
| Western spring | -461.8 | 278.7 | 5.37 |
| Eastern spring | 617.1 | 292.4 | 7.42 |

Approach and leave the shore, follow the outlet downhill, and walk back across a previously loaded area. Check the transition from the distant silhouette to the blocks and the contextual drinking action near a shallow bank.
