# Exact-head automatic collision capture

Read-only evaluation of [run36832635164](https://github.com/MajorDragonfly/voxelverse/actions/runs/36832635164), head `c5c22efde7d220169190710037da4f4f12666f02`, tree `667d4c8963137da3b8c2703f33868e120080b850`. Both artifacts have complete clean/stable start/end source manifests and the same source SHA256 `93f1ff89616f442b042f343dee55b42b0dd5293f980dae89585e0197831b0bec`. No retries, edits, production patches or additional engine tests were performed.

| Result | GL job110272526454 | Forward+ job110272526238 |
| --- | --- | --- |
| Wrapper |passed / exit0|failed_incomplete / exit124|
| Final evidence |schema2, complete=true, passed=true, failures=[]|absent|
| Progress evidence |retained, always incomplete|valid, complete=false/passed=false,2 failures|
| Canonical families |4 including oak|3; oak missing|
| Physical cases |16 ray/motion cases passed|9 saved near/rebase ray/motion cases passed; return unattempted|
| Capture |120 states /4 videos|90 states /3 videos|
| Provenance reuse |true|false|

Forward's first failed expectation is now explicit: **near publication exceeds90s**. It completes only4/25 desired cells in90.957s, with staged=1/workers=0/prepared=0, publication_steps54. During that wait only79 process frames and632 physics-counter increments occur. GL completes25 cells in4.730s with504 process frames/284 physics-counter increments. These counters describe scheduler progress; they are not target-PC FPS or physical simulation elapsed-time acceptance.

The missing oak is connected to an actual desired cell: GL's canonical oak cell `land1:18:0:131072:15727` exists in Forward's wanted keys but remains unpublished. Forward has only the central cells131071/131072 ×15728/15729. Bush, rock and pine have matching canonical cells, scales and slopes in both renderers. This establishes incomplete desired publication rather than a different seed family or invented camera fixture.

The360s process guard then interrupts **publication-far**. Last atomic checkpoint: probe elapsed349.606s, far wait72.905s, process14577/physics3323;7/25 cells, staged1/workers0/prepared0, publication_steps273. The corresponding monotonic engine wall clock is359.199s; probe elapsed starts later at its `_run`, so it must not be compared directly with the whole-process360s budget. Far began at probe elapsed276.702s, process14389/physics1828,0 cells/pub144. Thus the recorded far interval advances188 process frames,1495 physics counters and129 publication units. The far90s guard itself has not yet expired; the aggregate360s guard ends the process first. Return, final monitor and teardown were not reached. This is slow continuing progress, not evidence of a deadlock.

GL's near/far/return/final waits are4.730/18.112/5.289/2.917s, with process/physics deltas504/284,5086/1088,1130/320,316/183 respectively. All complete with25 cells and no worker/prepared/staged remainder. Final monitor has180 samples (coarse physics median7.496ms/p958.530ms), and completion follows centralized shutdown. Its10fps videos remain synthetic playback.

| Explicit native capture cost | GL120 states | Forward90 states |
| --- | ---: | ---: |
| Force draw median / sum |331.697ms /48.443s|616.575ms /52.928s|
| Readback median / sum |2.428ms /0.297s|532.800ms /45.743s|
| PNG median / sum |82.041ms /9.543s|50.564ms /5.466s|
| Physics await sum |3.358s|4.461s|
| Process await sum |5.446s|4.939s|

Forward's recorded draw plus readback alone consumes98.671s. Its three30-state spans are40.171/39.906/33.588s; each advances30 process/240 physics counters. GL spans21.188/16.858/13.866/15.263s for bush/rock/pine/oak. Different sample counts and GL's first-draw7.182s outlier preclude treating totals as identical workloads; component medians expose the substantial Forward readback cost. GPU execution, render-thread synchronization and software-driver work are not distinguished by these wall timers.

Native preparation also shows measured main-thread costs: Forward max flora publication 1079.572 ms / cold asset 819.249 ms, versus GL 1.509 / 2.643 ms; Forward population actor_ready lifetime max 801.740 ms (GL 134.631 ms). These maxima identify expensive observed operations, not the duration of every frame or a uniquely proven driver/source mechanism.

The exact-head source bounds these measurements. `world/surface/surface_ecosystem.gd:256-258` measures `max_asset_prepare_ms` around `Assets.prepare_lods` in the mesh phase. A `false` return exits before `publication_steps` and `max_publish_ms` are recorded; preparation and publication maxima therefore are neither disjoint stage sums nor a complete per-frame account. `:227-307` records `max_publish_ms` across the successful publication unit, which may include attachment and synchronous signals, exclusions, MultiMesh/material setup, a collider, or a phase change. `world/visuals/scenery/authored_environment_assets.gd:20-40` explicitly permits one cold resource load per process frame across chunks. The near wait's 79 process frames therefore constrain preparation opportunities, but the current fields cannot attribute every long frame or establish the renderer mechanism. `world/surface/campaign_population.gd:339-345` measures synchronous property setters and `add_child`, including the actor's `_ready` construction. `core/persistence/region_store.gd:175-214` measures successful read/parse/hash or write/stringify/hash/temporary-write/verification windows, not all LRU/cache/tick work. All maxima are lifetime values from scene creation; checkpoint differences in cumulative counters are temporal evidence, while maxima are not a time series.

Near store counters are0 reads/129 writes, max single IO0.694ms; GL near completes with0/0. Forward far starts4 reads/327 writes and reaches5/705 with max IO3.715ms. From far31.228s onward, reads5/writes705 stay constant while cells continue2→7 and publication_steps177→273. Thus additional page reads/writes cannot explain that continuing late far interval. This does not measure all CPU/cache work or prove IO never contributes. Diagnostic context only inspects resident cache/counters, so it adds no region query/LRU pollution. Previous checkpoint-write sample at termination is9.851ms; no phase records were dropped.

The bounded next owner investigation is native publication/main-thread submission and readback attribution: distinguish the mesh/cold-art/shape publication operations and renderer synchronization on the existing route, with matched environment/source and unchanged budgets. There is no evidence supporting a speculative storage-generation fix, timeout increase, family assertion relaxation or another blind retry. GL success and separate mandatory green gates do not complete Forward acceptance. Original74bb exit124 evidence remains preserved alongside this new concrete failed/incomplete result.

## Verified retained artifacts

- Forward artifact11148353301: ZIP SHA256 `4c30cae258e867f29cbbf05f03d71f16a3c6ae2200adddc5fa9e21301ad7f1c9`; engine log SHA256 `18008403e06c1a7b767ee1d3729efc5114cac94680500dcc7bd804e21757b6a2`.
- GL artifact11147854149: ZIP SHA256 `8594902f71b6ca5f495a9311a6c61fccb253ca46717cab797a4e1f30e4b52460`; engine log SHA256 `81dc07f4a465475f5743f70c4500ce71c94c472f88050874338845b5b520d06b`.
- Raw ZIPs remain in attachments; extracted artifacts are `c5c22ef-collision-forward-artifact` and `c5c22ef-collision-gl-artifact`. Exact decoded whole-job logs are preserved as JSON strings (losslessly decoded into the compact evidence archive).
- `c5c22ef-collision-comparison.json` retains reduced machine-readable phase/counter/timing data; original checkpoint/results bytes remain intact. `c5c22ef-collision-evidence.tar.gz` bundles both exact logs/results, final/progress JSON, this report and comparison with member hashes for persistence by the integration owner.
