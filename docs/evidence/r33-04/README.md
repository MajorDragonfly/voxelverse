# R33-04 · stopped eye clearance after a close building

Fixed basis: `94de70cacd250337976b8f63031fff4afc72e2bb`, tree `58506a6feba11be547197223fa319e7265cf4d99`.

## Original low-angle contract

The original #189 world sequence centres home after rebase, holds Right/PageDown to 3°, settles zoom 72, then 12 and measures `abs((-camera.global_basis.z).dot(Space.up(tribe,camera.global_position))) < 0.15`. This is the sine of the actual optical axis angle relative to the horizontal at the eye, not the configured tilt or an angle at the focus. `<0.15` bounds its magnitude below 8.627°; `<0.55` allowed up to 33.367°. The ordinary aim-to-eye clearance samples are a separate condition, not an equivalent camera-direction measurement.

R32 #260 already restored `<0.15`, bounded additional downward pitch at 8°, and checked nine real near-plane points for both lenses. Those fixes are present in the R33 basis and are retained. The original input, rebase, low zoom, 40 position/yaw/zoom cases and load route remain in `tribal_camera_world_test.gd`; the new grounded production-hut case is added after them. No assertion, renderer budget, timeout or original route was relaxed. #189 and its original branch are untouched.

## Reproduced additional product defect

At seed 15838, genuine campaign time 120 s and the production hut mesh/collider on actual sampled ground, the close hut shortens the orbit **after** the initial eye clearance. The actual stopped eye is only **1.711816 m** above sampled terrain/water (original 2 m clearance; existing test tolerance 1.9 m), despite low-dot 0.066341 and safe near-plane corners. Reapply the same 2 m eye clearance immediately after a building shortens the orbit; preserve focus and low-angle orientation. Product diff is six lines in `tribe_camera.gd`.

Baseline raw log/views are actual headless geometry evidence, **not images**. Its overall provenance is negative (`Git source state changed during observation`); actual unchanged production/test file hashes are supplied in the final comparison. Earlier original-world run also has a negative source guard because an own helper was added while it ran. Its actual original test completed positively, but it is not delivered as clean acceptance. Native CI comparisons and final source checks are separate.

## Verification and CI owner patch

`tools/review_r33_04.py` preserves all nine original full 1080p views and adds three actual-ground production-hut views, comparing fixed basis and candidate with the exact reference save. It rejects changed focus/seed/clock/yaw/tilt/zoom/projection, missing images, any candidate near-plane clearance <0.8, low-dot >=0.15 and stopped-eye clearance <1.9. Original 240-s capture deadline is retained. GL and Forward+ run sequentially. If ordinary Forward+ preparation fails, its original negative remains; a same-slot supplemental view run is labelled separately and cannot make ordinary entry green.

`ci-owner.patch` is an **opt-in owner patch** for R33-01: new `.github/workflows/r33-04-camera-review.yml`, applies at the fixed basis plus these own helpers; no existing workflow modified. Apply only in an isolated diagnostic tree to execute original registered consumers, original visible world/input route, full before/after views and original shore route. The actual workflow file is absent from the feature delivery. Test registry unchanged: only an existing registered test was extended. No InputPreferences, TribeController, player, Surface, Save, Minimap, localization or status patch required.

Software-Mesa/native source evidence does not settle Lars' target-PC, FPS or operating-comfort acceptance. #179/#210 remain open. Final CI SHA/tree, logs, view pairs and remaining renderer limits are added after execution.
