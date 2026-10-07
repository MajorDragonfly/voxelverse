# R33-08 — Forward+ publication: retained negative on current main

The original slow flora-publication failure remains reproducible on main `94de70cacd250337976b8f63031fff4afc72e2bb`. Both unmodified-product and instrumented Vulkan Forward+ cases exceed the unchanged 90-second near/far assertions and terminate at the unchanged 360-second process guard. Both GL cases complete the full route with all four solid families. This is a software-renderer diagnosis, not hardware acceptance. No isolated product cause was established, so this packet contains diagnosis/review tools and evidence, with no invented fix or general streaming optimization.

## Sources and ownership

- Protected original: PR [#246](https://github.com/MajorDragonfly/voxelverse/pull/246), branch `agent/int30-collision-publication-trace-20261001`, head `d5610eaafe43eb6246fc2a99676d064ba035bc78`, tree `34fe420ef8186e1805e564969f33526a20633506`. The branch still has that head after the investigation; PR/branch were not edited.
- Original measured source: `f58ce198be80245fd0b1721b326d6216c2dcf11c`, tree `a03aac092a5e6993a9aa635d3bf9ce06c1142f5f` (original artifact provenance is authoritative). Historical GL/Forward+ run [36846116115](https://github.com/MajorDragonfly/voxelverse/actions/runs/36846116115). Exact downloaded artifact identifiers and SHA-256 values are in [historical-provenance.json](historical-provenance.json).
- Read AGENTS.md, PROJECT_STATUS.md and the R33 owner table in [#137 comment 6035774590](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6035774590). Shared instrumentation and optional workflow attachment were handed to R33-01 in comments 6036157312 and 6036226113. Population/Actor work remains R33-02.
- Feature branch `agent/r33-08-forward-publication` starts at fixed base `94de70cacd250337976b8f63031fff4afc72e2bb`, base tree `58506a6feba11be547197223fa319e7265cf4d99`. It adds only own review tools and evidence/owner-patch attachments. Final delivery head/tree are recorded in Draft [#273](https://github.com/MajorDragonfly/voxelverse/pull/273) and the #137 handoff (a commit cannot contain its own hash).
- Isolated QA branch/Draft [#274](https://github.com/MajorDragonfly/voxelverse/pull/274), head `63dca21728a7b8018c810d89be9ff1662020ff56`, tree `ea6413422ee7e9f158545859d2a90228b99c48d8`: applies the five-file instrumentation patch and optional workflow. This measured QA branch is **not for merge**.
- Baseline CI checkout has unchanged product code from the fixed base plus the seven own review tools, locally committed as `2a945519fb7f5303e869cc1b30dccaa2c14ab580`, tree `5ac2e0539831374fad32d6470ca549ad672ccd77`. This commit is local to the runner, not a published feature branch.

The file-exact mapping is [ports/source-map.json](ports/source-map.json), with base blobs and before/after SHA-256 values. [ports/README.md](ports/README.md) describes the additive wrappers. Existing R32 pre-draw synchronization is preserved. No mesh, collision, publication budget, actor population, quality, gameplay clock or save policy was changed. The actual shared scripts/workflow exist only on the isolated QA branch; the feature carries their reviewable patch/attachment.

## Controlled input and remaining equivalence boundary

All four new cases use the same pristine save bytes (16,167 bytes, SHA-256 `f01e33bb1506bff40ab2641a58f9211dfcbd1aa0db686dde71e0421d1d682569`), seed 15838, body `body_44f7509974a1af912242e5284ab2e941`, preset 1, identical logged graphics dictionary, FOV 55, 960×540 resolution and original observer/family-sweep camera route. Baseline GL creates the fixture before opening the world; subsequent cases copy those exact bytes. The six original route/transform/sweep functions are byte-identical to the protected probe; [tool-contract-checks.json](tool-contract-checks.json) records their digests and unchanged guards. Twenty-five target cells and one publication unit per process step remain unchanged.

The original probe leaves time/weather/vegetation motion active; it does not freeze state to make pixels identical. The observed startup clocks and player heights below therefore differ. Observer movement and selected family camera transforms retain the original functions; this is an identical-input/route comparison, not a pixel-identical A/B or an FPS benchmark. The old #246 artifacts do not contain the pristine original input save, and their GL/Forward+ body IDs differ. We cannot claim an identical-save historical before/after comparison or infer a historical CPU/GPU root cause. R32 HUD/weather renders cover another route and are not used as evidence of this route's completion.

| Case | Observed clock | Observed player height |
|---|---:|---:|
| baseline-gl_compatibility | 0.227354333 | 26.122462924 |
| baseline-forward_plus | 0.092236000 | 26.160612938 |
| overlay-gl_compatibility | 0.228817333 | 26.122462924 |
| overlay-forward_plus | 0.115588111 | 26.081587914 |

## Exclusive host and commands

New quartet: [run 37609830257](https://github.com/MajorDragonfly/voxelverse/actions/runs/37609830257), job `112754119622`, artifact `11477678812`, `r33-08-publication-originals`. The job deliberately remains **failure** because both native Forward+ cases fail. It runs the four cases sequentially on the same isolated GitHub host `runnervm8df0l`, holding `/tmp/voxelverse-heavy.lock` and `/tmp/voxelverse-r32-db514e109ac6-heavy.lock` for each focused-check/native command. Host logs contain request/start, approximately one-second load/process samples and end records. All ends have no live Godot process and no observed foreign Godot descendant. The shared interactive host was not used for heavy work.

Godot 4.6.3 official, Ubuntu 24.04, Intel Xeon Platinum 8573C / 4 logical CPUs, Xvfb, Mesa 25.2.8, llvmpipe LLVM 20.1.2. `LP_NUM_THREADS=2`, `LIBGL_ALWAYS_SOFTWARE=1`, explicit lavapipe Vulkan ICD. Backend log headers are separately verified: `OpenGL ... Compatibility` versus `Vulkan 1.4.318 - Forward+`. No GL fallback is accepted as Forward+. Full environment files, commands and CPU-pressure/cgroup observations are archived. Memory cgroup fields were unavailable; RSS/VRAM were not measured. A missing memory field is not a zero-memory claim.

Each native command uses `--resolution 960x540 --disable-render-loop --script res://tools/review_r33_08_publication_runner.gd -- --capture`; overlay also uses `--publication-trace`. The wrapper preserves the original 360-second guard. Exact commands/paths are in each `results.json` and host log. Reproduction entry point: `python3 tools/review_r33_08_ci.py --help`; the optional pinned CI workflow is attached in `ports/` and applied only to QA.

## Full route result and process-frame waits

Elapsed publication values below are milliseconds. `—` means the stage did not complete before the process guard, not a zero duration. The Vulkan last checkpoint is `publication-return-start`; full return/final collision assertions remain unproven. Both Vulkan runs report three failures: near 90-second assertion, missing fourth solid family, far 90-second assertion. Each captures 90 explicit frames for pine/shrub/rock; ancient oak is absent. Both GL runs capture all 120 frames/four families and pass the original complete collision route.

| Case | Near ms / cells | Far ms / cells | Return ms | Final ms | Exit / complete | Max 1-min load |
|---|---:|---:|---:|---:|---|---:|
| baseline-gl_compatibility | 3840 / 25/25 | 17276 / 25/25 | 4829 | 2971 | 0 / true | 1.689 |
| baseline-forward_plus | 90583 / 4/25 | 90255 / 9/25 | — | — | 124 / false | 2.013 |
| overlay-gl_compatibility | 3987 / 25/25 | 17510 / 25/25 | 5386 | 2534 | 0 / true | 1.616 |
| overlay-forward_plus | 90892 / 4/25 | 90354 / 9/25 | — | — | 124 / false | 2.120 |

Near `await process_frame` distributions (ms; inclusive elapsed wait, not CPU time or GPU time):

| Case | n | Sum ms | p50 | p95 | p99 | max | >33 / >50 / >100 ms |
|---|---:|---:|---:|---:|---:|---:|---|
| baseline-gl_compatibility | 532 | 3827.677 | 3.237 | 9.981 | 101.856 | 177.112 | 17 / 17 / 6 |
| baseline-forward_plus | 88 | 90494.686 | 871.066 | 1719.645 | 3509.680 | 8012.612 | 88 / 88 / 88 |
| overlay-gl_compatibility | 499 | 3966.200 | 3.646 | 14.150 | 104.558 | 175.048 | 17 / 17 / 8 |
| overlay-forward_plus | 88 | 90552.683 | 883.678 | 1447.366 | 4232.535 | 8070.940 | 88 / 88 / 88 |

## Separated near-publication phases

Instrumented Vulkan case, `publication-near-start`, milliseconds. These are inclusive wall spans and **must not be summed across nested rows**. `flora-worker-cpu` is elapsed time in the CPU-only worker body, including scheduling; it is not a CPU-profiler reading. Constructor/assets/material creation calls can contain engine/driver synchronization. Synchronization wrappers measure the call's elapsed time, not all asynchronous GPU work.

| Operation | n | Sum ms | p50 | p95 | p99 | max |
|---|---:|---:|---:|---:|---:|---:|
| `flora-worker-input-duplicate` | 4 | 0.085 | 0.020 | 0.026 | 0.027 | 0.027 |
| `flora-worker-prepare` | 4 | 0.618 | 0.147 | 0.179 | 0.183 | 0.184 |
| `flora-worker-cpu` | 4 | 71.264 | 6.833 | 45.387 | 50.665 | 51.984 |
| `shader-duplicate` | 20 | 1.881 | 0.089 | 0.117 | 0.124 | 0.126 |
| `instantiate` | 9 | 0.411 | 0.038 | 0.078 | 0.094 | 0.098 |
| `batch-add-child` | 20 | 0.172 | 0.006 | 0.012 | 0.030 | 0.034 |
| `final-add-child` | 4 | 0.661 | 0.174 | 0.224 | 0.229 | 0.230 |
| `surface_ecosystem._sync_transition_motion` | 88 | 1.519 | 0.012 | 0.056 | 0.063 | 0.071 |
| `distant-ownership-texture-update` | 16 | 0.193 | 0.011 | 0.016 | 0.017 | 0.017 |
| `cold-load` | 9 | 5000.924 | 601.413 | 695.524 | 695.574 | 695.587 |
| `get-material` | 20 | 4343.597 | 0.013 | 826.236 | 975.018 | 1012.214 |
| `palette-texture` | 6 | 4334.473 | 667.081 | 962.857 | 1002.020 | 1011.811 |
| `prepare-lods` | 38 | 5020.167 | 0.148 | 643.869 | 697.656 | 698.151 |
| `surface_ecosystem._refresh` | 44 | 217.609 | 4.332 | 6.363 | 6.552 | 6.669 |
| `surface_ecosystem._process` | 88 | 9680.238 | 4.229 | 680.598 | 848.308 | 1018.956 |
| `surface_distant_scenery._process` | 88 | 4.956 | 0.052 | 0.079 | 0.102 | 0.106 |
| `campaign_atmosphere._process` | 88 | 30.086 | 0.326 | 0.475 | 0.518 | 0.545 |
| `save_feedback._process` | 88 | 1639.235 | 0.027 | 0.033 | 651.937 | 1021.870 |
| `save_feedback._capture_preview` | 3 | 1636.748 | 596.597 | 979.286 | 1013.303 | 1021.807 |
| `save-preview-get-image` | 3 | 1588.387 | 580.384 | 963.231 | 997.262 | 1005.770 |

For GL overlay, near callback totals are ecosystem 386.268 ms, distant scenery 24.026 ms, atmosphere 11.078 ms, save feedback 7.250 ms. Worker input duplication totals 0.414 ms, preparation 3.446 ms, CPU-only worker elapsed 557.660 ms; shader duplication 7.712 ms, scene instantiation 0.244 ms, batch attachment 0.559 ms and final attachment 1.985 ms. The differing numbers of published cells/samples preclude treating these totals as a matched per-object speedup.

The Vulkan near process waits total 90,552.683 ms. Measured top-level callback totals (ecosystem 9,680.238; distant scenery 4.956; atmosphere 30.086; save feedback 1,639.235 ms) do not explain most of that interval. Cold loading and palette creation sit inside ecosystem time; preview readback sits inside save-feedback time. Phase edges/frame callbacks are not aligned well enough to subtract a precise residual. Sub-ms duplication, attachment, ownership uploads and measured transition-motion synchronization cannot alone explain the guard failure. We have not separated the remaining engine/driver/render-thread waits, scheduler effects and other uninstrumented gameplay/population callbacks; those remain the proof boundary. No claim of a GPU bottleneck, CPU bottleneck, deadlock, or historical root cause follows from these spans.

The raw Vulkan flora log contains 2,478 paired start/end records; its final pair is a 0.004 ms `batch-add-child`. Atomic checkpoints can lag later log events and have an active operation recorded before its eventual end; an active checkpoint entry is not evidence of a stuck operation. Both raw logs and checkpoints are retained.

## Explicit rendering and image readback

Explicit capture distributions are separate from publication waits. `RenderingServer.force_draw()` elapsed calls can contain render waits; `ViewportTexture.get_image()` elapsed calls include synchronization/readback. No GPU timestamp or driver profiler was used. These synthetic explicit captures are not gameplay frame-rate measurements.

| Case / call | n | Sum ms | p50 | p95 | p99 | max |
|---|---:|---:|---:|---:|---:|---:|
| baseline-gl_compatibility / force_draw_ms | 120 | 47939.933 | 330.989 | 437.492 | 877.523 | 6405.127 |
| baseline-gl_compatibility / readback_ms | 120 | 245.633 | 1.954 | 2.602 | 2.637 | 2.663 |
| baseline-forward_plus / force_draw_ms | 90 | 49240.485 | 559.131 | 627.815 | 644.991 | 690.275 |
| baseline-forward_plus / readback_ms | 90 | 40159.821 | 460.763 | 526.502 | 530.987 | 531.678 |
| overlay-gl_compatibility / force_draw_ms | 120 | 48127.711 | 329.531 | 436.207 | 914.418 | 6396.024 |
| overlay-gl_compatibility / readback_ms | 120 | 251.639 | 1.958 | 2.794 | 2.899 | 3.437 |
| overlay-forward_plus / force_draw_ms | 90 | 49265.134 | 558.176 | 625.875 | 650.945 | 740.096 |
| overlay-forward_plus / readback_ms | 90 | 40388.412 | 468.515 | 528.748 | 531.283 | 533.333 |

Inspected middle-frame contact views show actual GL and Vulkan render output for available families; the Vulkan oak frames are absent. This inspection does not certify full motion videos or pixel equality. All original PNGs/videos remain in the linked CI artifact; raw data below excludes only those binary image/video files.

## Instrumentation cost, validation and retained harness negative

Span samples / dropped / cumulative atomic-span write ms:

| Case | Samples | Dropped | Write ms | Write errors |
|---|---:|---:|---:|---:|
| baseline-gl_compatibility | 10717 | 0 | 194.583 | 0 |
| baseline-forward_plus | 320 | 0 | 170.516 | 0 |
| overlay-gl_compatibility | 111468 | 0 | 1923.628 | 0 |
| overlay-forward_plus | 35245 | 0 | 1331.628 | 0 |

The baseline tool also records process waits/checkpoints, so “baseline” means unchanged product with the review harness, not zero observer overhead. Overlay JSON/logging changes scheduling and incurs additional write cost; no performance improvement/regression claim is based on its small GL duration differences. Completed distributions use all retained samples and linear interpolation at `(n-1)*p`; full per-phase quantiles/counts and >33/50/100-ms counts are in [comparison.json](comparison.json). The slow-record list is separately bounded; quantiles do not use only the slow-record list.

Focused checks/import pass on both baseline and overlay: `int30_scenery_collision_test`, `surface_population_budget_test`, `campaign_atmosphere_test` (including fresh restart), `r32_07_scenery_margin_test`, source contracts and art-source checks. Python compilation and report rejection cases pass (GL fallback, incomplete route and modified-log hash). Source-file manifests match start/end byte for byte for all native cases; [verification.json](verification.json) records verified SHA-256 values. Forward+ provenance is source-stable but intentionally `reusable=false` because the route failed. No full integration suite/export or target-PC acceptance is claimed; those gates remain with R33-01/Lars.

The first isolated CI attempt [37609274050](https://github.com/MajorDragonfly/voxelverse/actions/runs/37609274050) ran the focused baseline checks successfully, then stopped with host code 76 before any native capture. The first host monitor compared exact `--path` strings and misclassified its own fresh-restart descendant with a trailing slash. The review-tool fix checks real process ancestry and ignores exited zombies. The original failed job/logs remain in `telemetry-negative-raw.tar.gz`. It was a harness defect, not a product diagnosis or a successful capture.

## Durable originals and final conclusion

- [native-raw.tar.gz](native-raw.tar.gz): byte-preserving new run logs, result JSON, progress/spans/flora checkpoints, exact fixture, source manifests, focused-check logs and host/environment files.
- [historical-raw.tar.gz](historical-raw.tar.gz): byte-preserving available #246 original raw evidence; [historical-comparison.json](historical-comparison.json) is a fresh report, not a rewritten original log.
- [telemetry-negative-raw.tar.gz](telemetry-negative-raw.tar.gz): retained first harness-negative artifact.
- [provenance.json](provenance.json): artifact download hashes and durable archive hashes. The full new artifact ZIP SHA-256 is `e8c917cc5db1499a5566d66f682ced9dcd4761c20152c6d673e71d738c48ad41`; images/videos can also be retrieved from its CI artifact while available.

The historical GL route completed in 3,129 / 12,497 / 3,152 / 2,125 ms (near/far/return/final). Historical Forward+ reached six of 25 near cells after 90,894 ms, produced 120 near-capture frames and remained incomplete in the far phase at the 360-second guard. The new run reproduces the class of failure on current main, with four near cells and nine far cells; it does not establish historical identical-input timing causality.

**Delivery is a retained negative with narrower measured boundaries, not a production fix.** R33-01 can review/apply the opt-in instrumentation; population/actor work remains R33-02. Future attribution requires a controlled engine/driver/profile investigation across the unmeasured intervals. Software llvmpipe/lavapipe results provide no hardware release. Lars' later target-PC playtest remains open.
