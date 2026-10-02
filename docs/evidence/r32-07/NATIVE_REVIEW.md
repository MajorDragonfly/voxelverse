# R32-07 native review / PT17-03

Fix: reserve the accepted 64 m worker drift outside the existing 256 m shader ring. This is a bounded scenery attachment, not complete acceptance of #169.

## Source and conditions

Basis `2a738a4891a8de11d682c469833ade4dc9b01dfb`; tested published source `5d05c23ca71c7be824972c7adb7f9c3d97076100`, tree `fc4f73b67a8759424333e2b801eb2addf129226e`. Local `234ce08eec8ba5081d81f1f2878b6350035c933f` is exactly tree-identical. Final evidence is a source-independent follow-up; runtime and test hashes are in `source-map.json`.

Godot 4.6.3; actual SessionFlow spherical campaign, Seed 15838. An initial save is replayed byte-for-byte within each pair, including body UUID. Each pair checks camera position/forward, clock/sun, weather, graphics and floating origin for all 11 views; additional review also checks surface addresses, terrain tile counts and near-patch counts. Atmosphere/weather receive the low preset. Other campaign consumers use the same isolated default preferences; no claim that every graphics subsystem received a separate low-preset call. Shader TIME is not a pixel-identity assertion.

Ground-relative eye 1.7 m, FOV 75, 960×540; daylight clock 120 s, fog disabled. Route 0→20→100→200→100→20→0 m, orthogonal horizon view, and three held-set views. The separate 25-frame 0→63.5→0 m clip is an explicitly held slow-worker address diagnostic using ordinary bounded terrain requests, not physical walking. Movies play at 6 fps, unrelated to measured game FPS.

## Results and observed costs

| Renderer | view | wall p50 ms base → fix | wall p95/p99/max ms base → fix | generated proxies base → fix | cells base → fix | draw calls base → fix |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| gl_compatibility | route-00-0m | 887.899 → 931.376 | 1789.952 → 1884.187 | 1135 → 1370 | 354 → 430 | 1222 → 1218 |
| gl_compatibility | side-horizon | 558.638 → 564.882 | 1113.193 → 1092.056 | 1135 → 1370 | 354 → 430 | 674 → 674 |
| gl_compatibility | route-01-20m | 866.096 → 916.746 | 1822.196 → 2129.864 | 1135 → 1370 | 354 → 430 | 1226 → 1222 |
| gl_compatibility | route-02-100m | 827.429 → 860.010 | 1646.544 → 1683.540 | 1098 → 1379 | 355 → 427 | 1340 → 1340 |
| gl_compatibility | route-03-200m | 982.171 → 962.968 | 1896.299 → 1933.075 | 1124 → 1391 | 360 → 427 | 1257 → 1267 |
| gl_compatibility | route-04-100m | 909.172 → 912.080 | 1759.857 → 1770.056 | 1098 → 1379 | 355 → 427 | 1278 → 1283 |
| gl_compatibility | route-05-20m | 878.754 → 904.492 | 1862.840 → 1828.893 | 1130 → 1362 | 361 → 429 | 1275 → 1283 |
| gl_compatibility | route-06-0m | 857.500 → 881.144 | 1633.792 → 1706.348 | 1130 → 1362 | 361 → 429 | 1278 → 1288 |
| gl_compatibility | held-00 | 506.091 → 569.330 | 980.632 → 1053.396 | 1135 → 1370 | 354 → 430 | 691 → 687 |
| gl_compatibility | held-12 | 144.647 → 165.001 | 284.792 → 330.785 | 1135 → 1370 | 354 → 430 | 356 → 356 |
| gl_compatibility | held-24 | 518.794 → 507.206 | 1018.199 → 1057.036 | 1135 → 1370 | 354 → 430 | 708 → 710 |
| forward_plus | route-00-0m | 1078.314 → 1127.313 | 2060.744 → 2164.883 | 1135 → 1370 | 354 → 430 | 324 → 324 |
| forward_plus | side-horizon | 662.011 → 659.782 | 1234.511 → 1316.829 | 1135 → 1370 | 354 → 430 | 244 → 244 |
| forward_plus | route-01-20m | 1094.040 → 1099.054 | 2382.556 → 2250.783 | 1135 → 1370 | 354 → 430 | 295 → 295 |
| forward_plus | route-02-100m | 1078.803 → 1159.444 | 2311.175 → 2329.779 | 1098 → 1379 | 355 → 427 | 303 → 301 |
| forward_plus | route-03-200m | 1260.845 → 1271.492 | 2386.136 → 2319.694 | 1124 → 1391 | 360 → 427 | 301 → 303 |
| forward_plus | route-04-100m | 1153.145 → 1145.082 | 2332.351 → 2210.943 | 1098 → 1379 | 355 → 427 | 309 → 307 |
| forward_plus | route-05-20m | 1229.728 → 1168.779 | 2565.088 → 2382.874 | 1130 → 1362 | 361 → 429 | 334 → 330 |
| forward_plus | route-06-0m | 1192.889 → 1068.248 | 2384.651 → 2222.129 | 1130 → 1362 | 361 → 429 | 348 → 340 |
| forward_plus | held-00 | 651.720 → 620.179 | 1245.809 → 1384.042 | 1135 → 1370 | 354 → 430 | 249 → 249 |
| forward_plus | held-12 | 181.883 → 243.050 | 404.370 → 413.100 | 1135 → 1370 | 354 → 430 | 161 → 161 |
| forward_plus | held-24 | 676.852 → 734.379 | 1539.453 → 1402.814 | 1135 → 1370 | 354 → 430 | 256 → 252 |

Each static distribution contains only 12 paused measured frames after six warm frames. p95, p99 and max are therefore the same sample. GPU/CPU API timings, primitives, node counts, distance rings, motion wall times and PNG readback costs remain in the original capture JSON and `native/summary.json`. They are observations on Mesa software rendering, not a target-PC FPS result.

| Renderer | maximum worker ms base → fix | maximum one-unit publication ms base → fix |
| --- | ---: | ---: |
| gl_compatibility | 839.091 → 1042.868 | 0.757 → 1.022 |
| forward_plus | 773.314 → 1040.066 | 3.633 → 6.523 |

The reserve increases retained objects by 232–281 on these settled route views. Eight far batches, one worker, one staged set, at most one near/scenery allocation per frame and 2,048 ownership cells remain the structural bounds. Visible shader range stays 224–256 m. CPU generation and publication costs increased; no performance improvement is claimed. The canonical cap probe reached 1,977 cells. Natural population remains active during unmeasured setup, so total node counts differ; Population belongs to R32-02.

GL and Vulkan Forward+ both pass strict logs, unchanged source, exact save/instrumentation and all 11 condition matches. Both active and staging origin shifts have 0 m error. Six-face collision SHA256 is `ec3dd66af91a5c486b2d014d27b7f08b49a8db007b08db84936dd541730f50ed`; maximum top-normal error 0 before/after. All terrain tile and near-patch counts match within each pair, including the intentionally moving held clip.

The host flock was held, but R32-18 reported an overlapping local section from 06:46–06:51. The `/proc` monitor saw only one Godot in its namespace; its raw `performance_isolated` field means that limited observation, not host-wide proof. All load/cgroup originals are retained. No causal speedup or isolated performance budget acceptance follows from these pairs.

## Visual review and owners

| Requested symptom | Observed scope and remaining result |
| --- | --- |
| Raster lines | Repeated raster/checker grain remains visible on the ground and is unchanged at the paired 20/100 m views. This does not establish that it is the original screenshot A line cause. No evidence here permits calling it Z-fighting. Ground/material review remains with R32-08/09 and central mesh owners. |
| Terrain openings | No new opening is visible in the reviewed 20/100/200 m and horizon stills; the sampled collision geometry is identical. This is not an all-route seam certificate. |
| Hard colour changes | Existing grass/soil and near/far shading distinctions remain. No terrain or material shader is changed. Combined 06/08/09 lighting/material acceptance is still required. |
| Forest cut-off | Actual canonical CPU counterprobe has 35/47 omitted nominal-visible proxies on the base and 0/0 after the reserve fix. Of those original omissions, 29/41 also exceed the minimum existing Bayer coverage threshold (1/32), calculated from preserved distances. The held camera comparison shows a small outer-ring difference, not complete horizon restoration. The deliberate finite 224–256 m fade and sparsely vegetated distant horizon remain. |
| Existing blends | Existing canonical near/far palette/placement and complementary 0.35 s ownership blend were checked first; the 2,326-assertion distance consumer remains positive. A separate hard near-mesh choice at 80 m patch-centre distance remains in surface_ecosystem.gd; it needs its own visual counterprobe and owner integration. |

`surface_ecosystem.gd` is explicitly treated as an R32-01 shared Surface/publication attachment under [central assignment 5946206999](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-5946206999), not an R32-07 leaf. No ecosystem, Population, shader, collision or shared registry file was edited. Active terrain is `surface_terrain.gd` → `adaptive_sphere_tiles.gd`; the historical planar `landscape_horizon.gd` is not the normal spherical campaign attachment and was not rewritten.

R32-01: append `integration/registry.patch` once; preserve the 32 m recenter / 64 m accepted drift and agree the 256 m shader support with R32-09 if its fade thresholds change. Integrate the material/light branches serially, retain #189/#246, then run the full suite, main/runtime, native exports and four required gates. The exact original screenshot pose, continuous physical walking, additional daylight phases and Lars' target-PC view/frame acceptance remain open. #169 must not be closed from this partial draft.

## Files and reproduction

- [GL overview](native/gl_compatibility/overview.png), [held peak](native/gl_compatibility/held-peak.png), [base clip](native/gl_compatibility/before.mp4), [fix clip](native/gl_compatibility/after.mp4).
- [Forward+ overview](native/forward_plus/overview.png), [held peak](native/forward_plus/held-peak.png), [base clip](native/forward_plus/before.mp4), [fix clip](native/forward_plus/after.mp4).
- `native/{gl_compatibility,forward_plus}/{before,after}.zip` contains all original frames, initial save fixture, engine/load logs, capture JSON, invocation and video. File inventories retain individual original SHA256 values; `artifacts.json` covers delivered artifacts. Four sources yield 44 stills + 100 motion PNGs + 4 movies.
- `negative/` retains original failed logs/reports and hashes of their media: first X display failure, stale inherited readiness helper, UUID replay mismatch and Vulkan-to-GL fallback. Rejected media itself stays in scratch and is not used as acceptance evidence.
- `vulkan-environment.json` records the separately extracted Mesa package/library/ICD digests and exact driver environment. No system driver or project shader changes.

Command: shared flock around `python3 tools/review_r32_07_local.py --xvfb XVFB --godot GODOT --renderer both --output OUTPUT`; after the documented Vulkan fallback, repeat only `--renderer forward_plus` with the exact `VK_DRIVER_FILES` and `LD_LIBRARY_PATH` from `vulkan-environment.json`. Native guards stay 180 s load, 60 s settle, 600 s/source. Setup explicitly drains up to 64 existing near operations/frame without claiming that as production streaming.

The inherited helper could pause before Node `_process` saw the new observer. The own override now explicitly requests current near cells and checks actual IDs plus active far-anchor drift <32 m. Final matching replays original save bytes instead of relaxing UUID/weather comparisons. Active and hidden staging holders both use the real origin-change signal. All rejected attempts remain negative.
