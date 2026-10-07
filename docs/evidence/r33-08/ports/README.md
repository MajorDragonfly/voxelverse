# R33-08 opt-in owner ports

Assigned base: `94de70cacd250337976b8f63031fff4afc72e2bb`, tree
`58506a6feba11be547197223fa319e7265cf4d99`. Protected #246 head and original
branch remain unchanged. These patches are review/diagnosis artifacts, not a
feature integration or a general streaming optimization.

`publication-instrumentation.patch` applies only to the five paths listed in
`source-map.json`. Validate each base blob/hash, then use `git apply --check`
before applying on an isolated QA checkout containing the R33-08 tools. The
existing R32 pre-draw motion synchronization is preserved. There is no change
to simulation priorities, publication budgets, geometry, collision limits,
shader quality, draw count or acceptance guards.

The existing publication trace separates cold resource loads, scene
instantiation, material creation/duplication, MultiMesh submission, detached
instance attachment, compound collision submission and final publication.
Additional opt-in wrappers time entire flora, distant-scenery, atmosphere and
save-preview callbacks, including every early return. CPU-only worker wall elapsed is
read only after the existing join; input duplication and main-thread worker
preparation are separate spans. Ownership texture update and preview
`get_image()` wall time are separate synchronizing renderer API boundaries.
These timings do not establish a hardware CPU/GPU/driver attribution.

The instrumented probe retains the original `_move_observer`, `_targets`,
`_submitted_transform`, `_setup_motion`, `_sweep` and `_snapshot` functions.
The 90-second publication assertions and 360-second process guard remain.
All four families, real capsule collision, origin shifts, retirement,
near/far/return/final completion and final shutdown remain necessary. A valid
partial checkpoint never substitutes for successful final evidence.

`publication-review-workflow.yml` is the optional workflow owner patch. Its
actual `.github/workflows/r33-08-publication-review.yml` exists only on the
separate QA/evidence branch. It uses one native Ubuntu runner for pristine R33
product plus review tools, then the instrumentation overlay. Both GL and
Vulkan Forward+ execute serially under both host locks with recorded real
load. The first pristine GL run creates the source slot; every subsequent run
copies those same bytes and records their SHA-256. Original camera route/FOV,
seed, preset and resolution remain; active simulation time and weather
continue through the regular campaign route.

The historical #246 archives did not contain a pristine initial save file;
their GL/Forward+ body IDs also differ. They are retained historical negative
and positive observations, not an identical-save causal A/B with the current
product. The new same-save comparison is explicitly confined to the current
pristine/overlay quartet. Different machines, driver versions and import/cache
histories do not prove a historical CPU/GPU cause or a product speedup.

Trace bounds: original 16,384 entry/exit events, 256 atomic writes and recent
24-event ring; added at most 262,144 span samples and 2,048 slow-frame records.
Dropped counts and checkpoint write time/errors are retained. Exact reported
quantiles use linear interpolation at `(n-1)*p`; nested wall spans overlap and
must not be added as independent costs. Inclusive maxima/sums and >33/50/100 ms
counts are reported separately from quantiles. RAM telemetry is host/cgroup
memory, not per-game VRAM. Software-GPU evidence is not target-PC acceptance.

Shared owner: R33-01, with original respective flora/visual/atmosphere/frontend
owners retained. Population and actor construction remain R33-02. No common
save, clock, resource, controller, workflow, registry or status source is
changed on the feature branch. No new registered source test is introduced;
these files are review tools using existing focused consumers.
