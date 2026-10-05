# R32-07 / PT17-03: bounded scenery reserve

Issue #169, fixed R32 basis `2a738a4891a8de11d682c469833ade4dc9b01dfb`,
tree `f2bda4f815df1c73b9d740ca5282917523faf618`.
Draft PR #252 targets `agent/integration-r32-20261002`.

The existing 0.35 s complementary near/far blend is retained. The reproduced
fault is a different boundary: a completed/staged set could be accepted 64 m
behind the player although generation stopped at 288 m and shader coverage
remained nonzero up to 256 m. The missing outer crescent could appear when the
complete set was replaced. This is not evidence of the original screenshot's
grid-line cause or a complete horizon fix.

Production changes are limited to `surface_distant_scenery.gd` and
`surface_scenery_job.gd`. Generation now reserves 320 m = 256 m visible radius +
64 m accepted drift. Drift checks use the explicit 64 m bound rather than a
radius-dependent subtraction. The shader still fades over 224–256 m; no
visible-range, terrain, actor, collider, material or atmosphere changes.
One worker, one staged set, one submission per frame and 2,048 ownership cells
remain the production bounds.

## Actual canonical placement reproduction

Godot `4.6.3.stable.official.7d41c59c4`, Linux container `db514e109ac6`.
`tests/r32_07_scenery_margin_test.gd` obtains canonical scenery from the real
Seed-15838 surface factory. Two observer positions 63.5 m along opposite
tangent directions count positions inside the actual visible ring that are
outside the accepted old set. This is a CPU placement diagnostic, not a
pixel/physical walking or hardware-performance acceptance test.

| Quantity | Fixed R32 base | Candidate |
| --- | ---: | ---: |
| Missing visible canonical proxies, negative direction | 35 | 0 |
| Missing visible canonical proxies, positive direction | 47 | 0 |
| Same visible reference objects, negative / positive | 887 / 854 | 887 / 854 |
| Generated instances, negative / positive | 1108 / 1124 | 1362 / 1407 |
| Generated cells, negative / positive | 356 / 354 | 424 / 430 |
| Maximum cells over six faces, edges, corners and four supported radius probes | 1617 | 1977 |
| Single unisolated worker sample, negative / positive, ms | 663.208 / 788.204 | 916.086 / 1108.280 |

The extra reserve costs additional CPU work, retained instances and vertex
processing even outside the visible ring. These single worker observations
were not isolated from the other chats and are not a performance estimate.
They are preserved rather than replaced by a favourable repeat.

## Focused checks and source identity

The first standard runner attempt correctly refused the unregistered new
test. Its original failure is in `checks/unregistered-first-attempt/`.
The direct fixed-base reproduction is `checks/margin-before-direct.log`;
the same measurement on the fix is `checks/margin-after-direct.log`.

The standard focused runner was then executed on a separate verification
checkout at `d03cf97bbc454500ee51311a5a404bc4587a4caa`, committed tree
`ce1d27c79755cb2e7c667614527d11c1f2395fdd`, with **only** the supplied
`integration/registry.patch` applied. The main feature checkout's shared
registry remained unchanged. Runtime/test hashes of both production files
and the margin test were independently matched to the delivered files.

Command: `python3 tools/validate_godot.py --tests r32_07_scenery_margin_test
surface_distance_test --skip-import --skip-main --godot GODOT --project QA_COPY
--output OUTPUT`. Isolated userdata; same successful import cache.

- Source contracts: passed, 268 tests / 18 contracts, no execution implied.
- New margin test: 76 assertions, passed in 4.679 s.
- Existing distance test: 2,326 assertions, passed in 13.113 s. Actual
  near/far placement and basis error 0 m, maximum top-normal error 0.
- Start/end source SHA256 identical:
  `a7d7013d09eb2ae955cd0b8fb430ec59387b47f7d565d55e80fda65047c6edf1`.

Original full reports/logs are under `checks/focused/`. Large original JSONL
manifests are losslessly gzip-compressed; `checks/compressed-originals.json`
records original byte counts/SHA256 plus compressed hashes. Decompress before
using the original paths in the unchanged reports. The negative first attempt
and positive check's source manifests are each byte-identical start/end.

The conservative full selection in `checks/plan.txt` remains a **plan only**.
The full suite, common runtime, native exports and four mandatory gates are
R32-01's integration checks, not silently omitted or claimed here.

## Native comparison protocol

`tools/review_r32_07_distance.py` runs the exact same measurement helper on the
fixed base and a clean committed candidate. Only that helper is injected into
the base, with its digest recorded. Imported assets are reused; runtime files
remain at the base. Both captures use isolated userdata and the regular
SessionFlow → spherical campaign path. Source, command, renderer, clock/sun,
weather, camera, origin, graphics values, frame/readback times and host process
load are recorded. Capture is serial under the shared host flock.

Static route: 0 → 20 → 100 → 200 → 100 → 20 → 0 m, plus a perpendicular
horizon view; 1.7 m ground-relative eye height, FOV 75, 960×540, low preset,
real campaign clock 120 s. These are settled address seeks with explicitly
unmeasured accelerated near-publication setup, not physical walking FPS.

The separate 25-frame outward/return clip deliberately holds one already
published scenery set to reproduce a slow-worker boundary. It uses ordinary
bounded terrain requests while moving the observation address. It is a
diagnostic camera path, not survival/pathfinding or a continuous physical
walk. The clip plays at 6 frames/s; raw wall times are in its report.

## Owners and remaining acceptance

`surface_ecosystem.gd` is a shared R32-01 Surface/publication attachment; this
branch does not edit it. Its existing hard near-mesh swap at 80 m patch-centre
distance is a separate candidate for a visible counterprobe, not fixed here.
R32-09 also owns the existing transition shader/wind attachment. Population
stays with R32-02; terrain/material/lighting changes stay with 01/08/09/06.
Protected #189/#246 and their branches are unchanged.

R32-01 must register the single new test once with the supplied owner patch.
Original screenshot pose, all grid/crack/colour causes, full natural horizon
vegetation, physical long route, combined light/ground/material tree,
Forward+ target GPU and Lars' target-PC view/frame acceptance remain separate.
Issue #169 stays open; this draft is not a blanket FPS or merge approval.

## Completed native delivery

Both final GL and genuine Vulkan Forward+ pairs pass strict logs, exact save/pose/daylight/weather comparison and both origin-holder tests. See [native review and complete cost tables](NATIVE_REVIEW.md), [GL images](native/gl_compatibility/overview.png), [Forward+ images](native/forward_plus/overview.png) and their linked four videos/raw archives. Source tree `fc4f73b67a8759424333e2b801eb2addf129226e` is the exact tested native tree. Retained instances and worker/publication costs increased; the 256 m visible limit stays fixed. Software samples and overlapping host work do not grant FPS or target-PC acceptance.
