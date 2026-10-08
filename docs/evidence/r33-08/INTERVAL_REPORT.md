# R33-08 continuation — implicit draw / physics catch-up hypothesis

08 October 2026. **New result: the original instrumented Forward+ publication
wait contains pre-draw signal callbacks even with `--disable-render-loop`
requested. The near interval also advances exactly eight physics ticks per
process frame. Neither observation establishes the expensive interval's cause.**
This is a new offline analysis of preserved originals, not another negative
native quartet, a product fix, or hardware acceptance. No Godot process was
started for this continuation; #274 and protected #246 were not changed/merged.

The original [REPORT.md](REPORT.md), logs, checkpoints, fixture, owner patches
and provenance are unchanged. Its conclusion remains negative. Its statement
that only explicit capture frames are rendered needs the narrower reading below:
the capture loop requests only those frames, but cannot by itself exclude
engine-initiated drawing while the render loop is disabled.

## Audited inputs and actual new observations

The [offline analyzer](../../../tools/review_r33_08_interval_report.py) binds the
entire `native-raw.tar.gz` to the original [provenance.json](provenance.json):
6,195,927 bytes, SHA-256
`ba3c32261f338cb14e3e634b343e271ae3deb03bea6889a9e65b8f003fbe25bc`.
It verifies each run-log hash, complete equal start/end source inventories and
their hashes, requested/actual renderer and backend header, identical fixture
bytes, span counts/drop/write-error bounds, and monotonic frame timestamps.
Hashes of all consumed members are in [interval-comparison.json](interval-comparison.json).
The original run is [37609830257](https://github.com/MajorDragonfly/voxelverse/actions/runs/37609830257),
not a run of today's tool.

| Original near interval | Process frames | Physics ticks | Timestamped awaits / all awaits | Measured pre-draw callback calls |
|---|---:|---:|---:|---:|
| Baseline GL | 532 | 226 | 17 / 532 | uninstrumented |
| Baseline Vulkan Forward+ | 88 | 704 | 88 / 88 | uninstrumented |
| Overlay GL | 499 | 237 | 17 / 499 | 0 |
| Overlay Vulkan Forward+ | 88 | 704 | 88 / 88 | 88 |

Every timestamped near await in **both** Forward+ variants advances +1 process
frame and +8 physics ticks, including the first boundary. This is complete near
counter evidence: no interpolation across missing points. GL only records
timestamped waits above 33 ms; its sparse deltas cannot support an every-frame
physics claim. Far timestamp coverage is also incomplete: 231/232 for baseline
Vulkan and 234/235 for overlay Vulkan. Their whole-phase physics totals are
1,849 and 1,874, respectively. The analyzer reports these gaps explicitly.

The instrumented consumer `surface_ecosystem._sync_transition_motion` has
88 near and 235 far calls in Vulkan, versus none in either GL publication
phase. It is connected to `RenderingServer.frame_pre_draw`; the checked
production source has no other caller. Its wrapper records a sample after
every call, including early returns; its near inclusive time is only 1.519 ms.
The exact four inspected QA script bytes match the measured source inventory
at `63dca21728a7b8018c810d89be9ff1662020ff56` / tree
`ea6413422ee7e9f158545859d2a90228b99c48d8`, as recorded in
[interval-engine-source-review.json](interval-engine-source-review.json).

The publication await does not call `force_draw`. No explicit capture record
overlaps near/far in any variant; the first near sweep starts after publication
has already exceeded 90 seconds. This separates the signal observations from
the later 90 explicit Vulkan captures. It does **not** measure actual engine
draw duration, presentation, driver execution, or the number of viewport draws.
The runtime render-loop-enabled flag was not captured, so the command-line
request must not be represented as a newly observed runtime-state value.

Of the overlay's 87 near waits after the first partial boundary, 71 have no
>33-ms sample from any of the four instrumented top-level callbacks in the
preceding process frame. Those waits sum to 70,206.667 ms. This aligns callback
frame f with await ending at f+1, rather than subtracting unrelated phase
totals. It still excludes neither small measured callbacks nor uninstrumented
callbacks/physics/engine waits. This is **not** a measured residual or a CPU/GPU
attribution. Full retained wait quantiles remain unchanged:

| Near await wall ms | p50 | p95 | p99 | max | >33 / >50 / >100 ms |
|---|---:|---:|---:|---:|---:|
| Baseline Vulkan | 871.066 | 1719.645 | 3509.680 | 8012.612 | 88 / 88 / 88 |
| Overlay Vulkan | 883.678 | 1447.366 | 4232.535 | 8070.940 | 88 / 88 / 88 |

Original host telemetry records no increase in `nr_throttled` or
`throttled_usec` during either complete Vulkan command; both end without live
Godot processes or an observed foreign Godot descendant. `cpu.max` was
unavailable. These whole-command observations give no positive evidence for
quota throttling as the explanation; they do not exclude scheduler, CPU
contention, physics or driver waits and do not imply an unlimited quota.

## Concrete source hypothesis and unresolved engine identity

The inspected nominal Godot 4.6.3 source offers a specific possible mechanism:

- `Main::iteration` runs `RenderingServer::sync` regardless of the presentation
  request. Pending RenderingDevice resources can cause `draw(false)` even when
  presentation/render-loop drawing was not requested.
- `RenderingServerDefault::draw` emits `frame_pre_draw`. Its `_draw` path still
  processes scene/canvas updates, particles, probes, viewports and end-frame
  work with the presentation flag false. The signal consumer's duration does
  not cover that later work or a following sync wait.
- RenderingDevice resource disposal can reset its pending-resource frame
  counter; frame cleanup decrements it. Repeated disposal/cleanup is a concrete
  candidate trigger for repeated non-presented drawing. No actual RID type,
  producer, reset event or call stack was measured in the original artifacts.

Source references, including exact blob and SHA-256 values, are retained in the
source-review JSON. Upstream paths inspected:
[main.cpp](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/main/main.cpp),
[rendering_server_default.cpp](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/servers/rendering/rendering_server_default.cpp),
[rendering_device.h](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/servers/rendering/rendering_device.h),
[rendering_device.cpp](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/servers/rendering/rendering_device.cpp).

**These source bytes are not bound to the original binary.** The original
log header is `4.6.3.stable.official.7d41c59c4`; the currently resolved upstream
`4.6.3-stable` tag points to `35e80b3a8822a9df9be390814b62f44c0a9c69e8`.
The commit lookup for `7d41c59c4` returned 422/no matching commit. Explicit
short-ref file reads returned the same blobs, which alone is insufficient
commit evidence. No substitute engine was built or measured. The source path
is a falsifiable hypothesis; exact original-build implementation remains open.

## Next discriminating experiment, rather than another negative quartet

Hypothesis H1: **the major wait occurs after gameplay callbacks and across
non-presented draw / subsequent renderer-sync intervals; repeated pending
resource processing sustains that path.** Eight physics ticks are a possible
consequence of that wall time, rather than evidence of expensive physics.

1. Retain the original binary and establish its binary SHA-256 and exact source
   identity. A matching version label alone is insufficient. If only stock
   signal boundaries are available, report them without claiming internal
   engine attribution; do not silently switch the engine for the comparison.
2. Add a bounded passive QA trace of `process_frame`, each `physics_frame`,
   late diagnostic process/physics callback boundaries, `frame_pre_draw` and
   `frame_post_draw`, with wall timestamps, process/physics/drawn counters,
   render-loop-enabled state, phase and explicit-capture state. Keep production
   priorities and callbacks untouched. Late diagnostic callbacks bracket only
   their scheduled group; deferred queues and threaded post-draw delivery must
   remain separate. No extra draw/readback or automatic-loop toggle is allowed.
3. If those boundaries support H1, instrument the **bound** engine's existing
   sync/draw/end-frame calls: entry/exit, pending-resource predicate, present
   flag and pending-counter resets with bounded resource-type/producer records.
   These are opt-in QA/owner patches. Separate render-thread queue wait,
   resource/fence wait and driver/readback; signal wall time is not GPU time.
   If long waits instead lie before/between physics boundaries or inside
   uninstrumented callbacks, reject H1 and identify that measured consumer with
   R33-02. Do not disable physics/preview/quality to manufacture a pass.
4. Register and obtain R33-01's concrete host-slot confirmation **before** any
   new heavy run. R33-02 keeps the shared interactive host. Use an isolated QA
   tree, actual load/process checks and both locks for the whole command; GL
   then true Vulkan serially on the same host. Copy the original fixture
   (`f01e33bb1506bff40ab2641a58f9211dfcbd1aa0db686dde71e0421d1d682569`),
   seed 15838, exact original route/camera/FOV/preset/960×540 conditions and
   original 90/360-second guards. Preserve active-clock/weather limitations,
   all families/collision/rebase/retirement/return assertions, draws and budgets.
   Report all quantiles/spikes, overhead, dropped events, survival failures and
   timeouts, including incomplete boundaries. Do not repeat the old four cases
   without these new discriminating boundaries.

This experiment is now specified but **has not run**. Only after a measured
responsible product consumer is identified can a bounded lifecycle-correct
product patch and matched original-route before/after result be justified.
If the wait remains internal or unbound, hand off that narrower negative.

## Camera coordination and delivery checks

R33-01/R33-02/R33-04 were notified in the existing #137 process
([continuation](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6055498264),
[hypothesis/source-boundary update](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6055566493)).
No new host-slot confirmation is claimed. Today's actual interactive host is
`7f573e0a2ae8`; this continuation did not acquire/use a heavy slot.

R33-04's #277 handoff reports zero comparable Forward+ gameplay images after
its unchanged preparation, including both two- and four-Mesa-thread negatives.
A future passive trace must also be coordinated with that owner on **that
original preparation path**, keeping its save/camera/1080p and 240-second guard
separate from this 960×540 scenery fixture. The paths cannot be assumed to have
the same cause, and weather pictures do not close the camera-image acceptance.
#276 and #274 remain non-mergeable QA evidence; #189/#246 remain protected.

Reproduction from repository root:

```sh
python3 tools/review_r33_08_interval_report.py \
  --archive docs/evidence/r33-08/native-raw.tar.gz \
  --provenance docs/evidence/r33-08/provenance.json \
  --output /tmp/r33-08-interval-comparison.json
python3 tools/review_r33_08_interval_report_test.py -v
```

Nine actual Python checks passed: original counters/unmeasured baseline,
sparse-GL boundaries and rejection of changed archive/log/source inventory,
GL fallback, missing slow timestamps, nonmonotonic counters and dropped spans.
Original checked product-source bindings and the engine-source identity gap
are explicit. Today's changed files are offline tools/evidence only. No new
Godot, full-suite, export, FPS, hardware or completed camera-route result is
claimed; the original Vulkan exit 124 and failed 90-second assertions remain.
