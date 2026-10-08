# TribalAge: action moved after responsive HUD layout

The product fix sizes resident buttons from the current responsive HUD width
during `_layout()`. It removes the previous dependency on the old `_hud.size.x`
in `refresh()`. Only `ui/tribe/tribe_panel.gd` changed; original test inputs,
assertions, frame counts, timer periods and guards remain unchanged.

Product commit: `6160c25dd5cd9dbb96cc8312559b85ef9c86b00c`.
Product tree: `72237b37c614a77572b1e2f54aeaaed4e4976d1a`.
Product source SHA256: `dd2841e146a976aaee4feeabf6cee0252e0f5662bc38e44e130d706df6014c72`.

## Original negative

[Domestication D2 run 37806704227](https://github.com/MajorDragonfly/voxelverse/actions/runs/37806704227)
checked CI merge commit `2c0d4d73f2a880ffeabd68ba26d2d54fc92b1374`, tree
`bc3966cbd2116a0f2578db6c72c9b5c0203b0725`. This tree equals both remote
`d499309d28ef915def5877d4c11059d39f0c56b1` and local `edf9bd5d10357c4fab4685f7723ff6e1ea9e3d4e`.
The artifact start/end manifests confirm the same unchanged test, tribe-panel
and resource-panel bytes. This was neither a stale checkout nor a timeout.

All six Domestication tests, `save_slots_test` and `campaign_foundation_test`
passed. `tribal_age_test` failed after 75.336 s: `AddAreaWorker` was outside
the visible scroll at `(101.0, 392.5)`, covered by the HUD's outer
`VBoxContainer`. Its assignment assertion then failed because the real click
was correctly rejected. Original job: `113412752680`; artifact: `11564185233`.

Original TribalAge log SHA256:
`d4034b276d74e737ea0ca396ff21cd9d3399399b2b321480df48693d08e6b825`.
Original entire-source SHA256:
`fde0dbad8dc2599526e676d3c49c866c70eb06a6fadd456f09f46a201c989975`.

## Callback observation

Two isolated, serial, log-only diagnostic runs retained all original input
steps and budgets. Both passed locally (76.962 s and 79.130 s), so they are
not claimed as additional negative test runs. The second run buffered the
layout, scroll-offset and detail-scroll callback events to avoid writing logs
at input edges. The diagnostic branches are retained separately and must not
be merged as product changes.

In that run, after restoring the original 1280×800 window and 100% UI from
800×600 / 150%, the Add button initially occupied physical Y=398..433;
the scroll clip started at Y=399. It therefore satisfied the helper's existing
one-pixel rounding allowance. The next natural village refresh changed the
content minimum height from 858 to 835 and moved the button to Y=375..410:
its center was exactly Y=392.5, the original CI failure coordinate.

The local refresh happened before `_show_in_scroll`, which corrected
scroll offset 287→263 and restored the button to Y=399..434. In the failed CI
ordering, the click reached the displaced geometry. The observations reproduce
the offending geometric state; the difference in callback ordering is inferred
from the original CI hit test and the recorded local callbacks.

The detail-scroll coroutine had already completed well before the final
button preparation; no late `_scroll_to_detail` callback caused this shift.
The implementation instead calculated resident caption widths from the old
actual HUD width in `refresh()`, then updated the responsive HUD width in
`_layout()`. A later refresh repaired those widths and changed wrapping.
The fix computes the HUD width once in `_layout()` and uses that same value
for both resident captions and the HUD before geometry is consumed.

## Verification on clean product source

Godot 4.6.3, editor SHA256
`f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3`;
host `7f573e0a2ae8`; four software threads. Both shared heavy locks were held
through the existing host wrapper, with no foreign Godot process and unchanged
clean source at the end. Slot:
[issue #137 confirmation](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6035774590).

```text
python3 tools/validate_godot.py --godot GODOT_4_6_3
  --tests tribal_age_test r33_06_equipment_ui_test
  --skip-main --skip-import --output OUTPUT
```

`--skip-import` reused the successful 9.112-s import of the same resources in
the same isolated QA checkout. Each validation invocation used isolated saves.

| Test | Result | Duration | Log SHA256 |
|---|---|---:|---|
| Original `tribal_age_test` | PASS | 76.007 s | `52d8110cc58ae0798b6a35f762d8e63c2d45ca75e08fb3c9e22833f410472fcb` |
| Direct resident/Equipment UI consumer | PASS | 120.290 s | `bf9b4e1f93858ae0f4d33aef9765493ed62b75aa21239a77b1c4ce3d0e964f63` |

The final source-integrity result is stable and reusable. The report keeps
the original negative; these focused passes do not substitute for CI on the
combined integration tree, complete native pictures or target-PC acceptance.
The dedicated 18-case `r32_14_tribe_layout_test` and the final combined UI
picture checks remain with the integration/UI owner.

Included evidence: original run metadata/results and selected start/end source
records, full compressed negative and diagnostic logs, buffered callback
records, clean product-run metadata/results/logs, and host boundaries.


## Earlier Windows export mapping

The restored original artifact `11557291448` (`export-diagnostics-windows-pull_request`)
records packaged Windows Godot `4.6.3.stable.official.7d41c59c4`, exported from
clean source commit `53e13dc8aee4544e204f772cf665bb7cea8b0b86`, tree
`ba479d78c9f73beaea2d42f993425ceb997d63e9`, source SHA256
`efcbf612cca607eb67d8be105d5ba9870017dfd34e24170e853bd316119a551d`.
The original ZIP SHA256 is
`5b9779e2bf324d9bdd836a74fef96e0b3f94185f9c61d13d56ea697397565a0f`.

Its `packaged_tribal_age_test` failed in 71.844 s with the same three assertions:
`AddAreaWorker` outside the visible scroll at `(85.0, 392.5)`, covered by outer
`VBoxContainer@287`, then no committed assignment. Log SHA256:
`961b5678644aa4803ba618d42f9a3386c122bc3ff40079672ad5eacc76be33ce`.
This artifact tests the actual release PCK through the Windows instrumented
engine; it is not a source/headless-Linux substitution.

Direct reads of both that source and integrated main `9ecc8a7b` confirm the
same old-width calculation in `refresh()` followed by the responsive HUD width
in `_layout()`. The matched Y coordinate, assertions and implementation strongly
support the shared inherited responsive-layout mechanism. The original Windows
artifact has no callback trace, so this mapping does not independently prove its
precise callback ordering or certify a new Windows export of the fix.

## Additional old-HEAD Godot shard negative

[Godot run 37806704303, source-0 job 113414571574](https://github.com/MajorDragonfly/voxelverse/actions/runs/37806704303/job/113414571574)
checked the same old PR merge commit `2c0d4d73`, tree `bc3966cb`, entire source
SHA256 `fde0dbad8dc2599526e676d3c49c866c70eb06a6fadd456f09f46a201c989975`.
The import passed in 9.544 s. Of its 36 tests, 35 passed and exactly one failed:
`r32_19_resident_ui_test`, 39.404 s, exit 1, unchanged source. Its existing
120-s test guard and 60-minute shard guard did not fire.

The only failed assertion was `Detail line remains clipped: ResidentName/800-100-de`.
The recorded label occupied Y=264..290 while its scroll viewport began at Y=286
and ended at Y=504; scroll offset was 205. Original test-log SHA256:
`fbf7d110730ffb7813d005f48c5106bc501c935e17c24e6de63a6efa015d6256`.
The full original job is archived as `source0-original-job.log.gz`.

This is an adjacent resident-detail geometry failure in the same responsive HUD,
with its existing six correction attempts of two frames each plus two final
frames. It is not a timeout, checkout failure or canceled test. The width fix
is a plausible shared cause, but the old job has no callback trace and its
ResidentName case differs from the AddAreaWorker case. Its resolution remains
open until the unchanged `r32_19_resident_ui_test` passes on the combined current
product tree. It must not be silently marked covered by the two focused passes
above. The integration/UI owner has queued this exact test.
