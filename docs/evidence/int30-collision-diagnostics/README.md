# INT30 collision capture diagnostics

Assigned diagnostics-only followup, based on exact `74bbcbcf9854cd35eb0c816f95a65ad17d2e2dfe` / tree `a1a53c20730b1000e703ff1add4dd854fcdb069a`. No production source, route, physical sweep, draw count, assertion, generation policy or guard is changed. The next combined integration tree still requires its normal complete gates and a separately identified native diagnostic capture.

## Retained blocker

Run [36824683412](https://github.com/MajorDragonfly/voxelverse/actions/runs/36824683412): original Forward+ job `110247626277` and the single unchanged repeat `110254636934` both fail at the existing360-second process guard, exit124. Both clean/stable complete5400-file source manifests identify the exact basis above and source SHA256 `c06aed81737a973930f8969b922ac183585dc25dad3ff2dfc8e46f09f0c36ae5`.

Both logs show only bush/rock/pine, so the four-family assertion already fails; oak is missing. The same9 near/rebase motions record positive contacts19/1/1,21/1/1,18/1/1. No returned sweeps, final JSON or completion marker appear. Original GL passes all4 families and all16 checks at the same basis. The old probe delays assertion printing/checkpoint output until completion, so neither failed log proves which subsequent publication wait blocked.

| Observation | Original Forward+ | Single repeat |
| --- | ---: | ---: |
| Sphere load |63.558s|64.401s|
| First PNG after helper invocation, coarse ZIP timestamps|~172s|~179s|
| Three-family state span|~112s|~114s|
| Missing canonical family|oak|oak|
| Result|timeout124|timeout124|

This closely repeated failure remains a real Forward+ acceptance blocker. It does not establish host load as the sole cause, nor prove physical pass-through. Deterministic placement uses world seed/cell coordinates rather than random body IDs. The long preparation is consistent with incomplete publication, but its exact cause needs the new counters.

`retained-evidence.tar.gz` contains exact decoded original/repeat whole-job logs, exact engine logs/results, the GL reference world result, coarse PNG timestamps, detailed read-only diagnosis and focused verification logs/fixture. `MANIFEST.json` records SHA256/size for each payload; all hashes were verified. Original failed ZIP digests are `66ff6b5da020b10f2ae8b71dbb25670f82d9ada353765a5745e65b42aa088f92` and `e8dcba1f9ef01f8f555bb59be5513670f0271437d353590373818905cc21b3e0`. No second repeat was performed.

## Diagnostic schema2

- `int30-collision-progress.json` is atomically replaced before world loading, at phase boundaries, every5s during the existing90s publication waits, and after capture states0/15/29. It always has `complete=false`, `passed=false`; status is `incomplete` or `failed_incomplete`. A process kill retains the prior valid checkpoint; a staged `.tmp` may also be copied but never substitutes acceptance.
- Every phase record contains event/phase, monotonic wall and elapsed milliseconds, total process/physics frame counters, player address, wanted/published cell keys and resident flora/scenery/population/store counters. Store payloads are inspected only through the existing resident cache; no `region()`, `record()`, pinning, lookup, dirty marking or LRU query is added. Resident generated counts are partial cache observations; lifetime maxima are not per-frame attribution.
- Phase records are capped at256, with a dropped count and a separately retained latest checkpoint. Capture timings are capped at120 (the unchanged4x30 states). Each native state reports physics/process await time and separate `force_draw_ms`, `readback_ms`, `png_ms`, plus before/after frame/time counters. Operation-start log records identify a stalled native operation. The encoded10fps video remains synthetic playback, not live FPS. Checkpoint write timing is carried into the next checkpoint; instrumentation adds measured diagnostic overhead.
- Failed assertions print immediately, retain the same failures array, and checkpoint at most once per5s. Near/far/return/final waits retain the existing90s guards; diagnostic writes consume those guards and the existing2s retirement guard. The outer wrapper still uses360s.
- `int30-collision-world.json` is written synchronously after centralized shutdown. Its complete/success flags require the full physical route and return-to-title; early failures can write an incomplete final report. `complete=true` describes completion, while `passed=true` additionally requires no failures. Assertion-free incomplete routes and later diagnostic write failures exit1. The wrapper preserves raw JSON bytes and requires schema2, strict true completion/pass flags and an empty failures array, together with every existing exit/error/marker/source/video check. Missing, unreadable, malformed or partial evidence remains red; timeout124 always yields `failed_incomplete`, reusable=false.

## Focused verification

Godot4.6.3 / Linux headless: explicit probe `--check-only` compile passed. Existing strict `int30_scenery_collision_test` passed in5.044s after one fresh11.363s import; source contracts/art checks passed and that run stayed source-stable. No world/native replay was launched.

The small archived lifecycle fixture opens no campaign: it verifies atomic partial flags, final JSON after centralized shutdown, successful complete exit0 and assertion-free incomplete exit1. Both cases pass on the final diagnostic implementation. It is a diagnostic helper contract check, not a physical/native acceptance substitute.

`python3 tests/tooling/collision_capture_diagnostics_test.py` passes4 behavioral tests (12 cases): retained timeout bytes/124 even with success-looking final evidence; success markers cannot accept missing, malformed, non-object, incomplete, non-boolean or explicitly failed evidence; complete success keeps partial evidence separate; unreadable retained evidence is described without aborting reporting. `py_compile` and `git diff --check` pass. The archived code hash map identifies the checked implementation; the physical subset predates only the subsequent diagnostics-only guard placement and unreadable-report refinements. The conservative changed-since plan still requests full integration checks.
