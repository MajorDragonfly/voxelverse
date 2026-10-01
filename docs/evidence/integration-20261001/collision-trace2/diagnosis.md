# Collision trace2: bounded diagnosis, no unsupported fix

Read-only evaluation of the retained `collision-forward-trace2.zip` and
`collision-gl-trace2.zip` from PR #246. Both ran commit
`f58ce198be80245fd0b1721b326d6216c2dcf11c`, tree
`a03aac092a5e6993a9aa635d3bf9ce06c1142f5f`, Godot 4.6.3, on llvmpipe software
rendering. Local diagnostic base `f57b7fe9b6be7b699b23c51230ef9fb690bb3a4d`
has that same tree. Start/end manifests match byte-for-byte and log hashes match
their wrappers. [comparison.json](comparison.json) retains the verified hashes,
commands, phase boundaries and measured values. No engine retry or product
change was made in this recovery.

| Observed result | Forward+ | Compatibility |
| --- | ---: | ---: |
| Wrapper | failed/incomplete, exit 124 | passed, exit 0 |
| Complete world evidence | absent | passed, no failures |
| Near publication wait | 90.894 s, timed out | 3.129 s, complete |
| Published cells at near guard | 6/25 | 25/25 |
| Near process-frame waits | 115, mean 790.008 ms | 515, mean 6.065 ms |
| Cold-load maximum | 613.833 ms | 1.384 ms |
| Palette-texture maximum | 797.758 ms | 0.100 ms |
| Captured near states | 120, all four families | 120, all four families |
| Explicit capture draw/readback total | 52.407 / 44.624 s | 33.082 / 0.178 s |

Forward+ continues making progress. Its last world checkpoint is far publication,
at engine wall time 356.676 s, with 13 cells and 431 publication units. The
360-second process guard interrupts the route before return, final physics
sampling and shutdown. The retained flora trace ends at 358.386 s. Its final
active operation is a start-edge checkpoint, not evidence of a permanently
blocked `prepare_lods`. The only recorded world assertion is the near 90-second
publication failure. All four near families and their 120 captured states do
not substitute for the missing route completion.

The finer material trace attributes the largest measured `get_material` call to
`Slots.create_texture`, rather than shader duplication or material setters.
Nine cold loads total 4.240 s and six near palette creations total 3.457 s.
Other traced near publication operations are mostly fractions of a millisecond.
Across the near trace's 89.958-second first-to-last-event interval, the sum of
each traced process frame's first-to-last-event span is only 7.787 s; 82.171 s
lies outside those spans. These are wall intervals, include tracing overhead,
and do not isolate CPU, GPU, driver or scheduling time. Nested operation sums
overlap. They cannot justify attributing the persistent frame delay to palette
creation, cache misses, collisions or a specific driver defect.

The current source trace covers `surface_ecosystem._step_publication` and
`authored_environment_assets` preparation/material steps. It does not cover
whole frame callbacks or deferred engine/renderer synchronization. Concrete
unmeasured consumers for the next bounded native profile are:

- `surface_ecosystem._advance_scenery_transitions`, which runs before the
  `max_frame_work_ms` clock; `_refresh`, including recurring existing-batch
  `MultiMesh.mesh` assignments.
- `surface_distant_scenery._update_ownership`, including its image upload,
  outside the distant publication timer.
- `campaign_atmosphere._process` / `update_view`, including sky/environment
  setters and realtime sky radiance work.
- `save_feedback._capture_preview`: active displayed sessions read back the
  viewport every five simulation seconds, even when autosave is disabled.
  This is separate from the probe's explicitly timed capture readbacks.

The next profile should time these whole stages with opt-in count/sum/max and a
small bounded slow-frame sample keyed by existing process/physics frame IDs.
If callbacks remain short, inspect the engine/render synchronization boundary.
Keep the 90/360-second guards, four-family assertion, one publication unit,
25-body and 24-shape limits. Do not disable production consumers or loosen
acceptance to manufacture a pass.

No native display/Xvfb is available in the recovery container, so another
Forward+ capture was not started. Headless results would use a different
renderer and could not settle this attribution. Compatibility completion is
retained; Forward+ software-CI completion and Lars' target-PC visibility/FPS
acceptance remain separate, open boundaries. No production fix is supported by
the retained measurements alone.
