# GFX-REF-04 native graphics evidence

Source candidate `a6fe4a600552a74335242689c542a7d622b48cc4`, tree `062f512579ac40e852ed617006edde879f5fea35`, base `148ba0bb578e9a01db501444fd11823fa09e8212`, PR #293. Integration is pending; this branch contains evidence only and must not be merged into main.

The current production change combines quieter shared leaf/shrub pigment, warm direct/cool ambient day lighting and earlier depth haze. The merged legacy HLOD also uses the shared palette response. Geometry, semantic slot identities, placement budgets and saved data are unchanged.

## Current checks

The original cluster lab comparison passes at the current tree: mean RGB error 0.0027672098 under the unchanged 0.004 threshold; draw calls 10 to 4. Current regular-campaign GL passes in 342.354s with 16 original images, exact restores and exact night-lighting controls. Current Forward+ and complete CI originals are being added. No current full integration or target-PC/FPS acceptance is claimed yet.

## Preserved earlier evidence

`candidate-ad/` contains the complete **preceding** tree `455e558b` native runs (GL 334.328s, Forward+ 526.507s, 32 images). These are historical and are not current-tree acceptance. Both used the same original cold replay; full bodies/cameras/clock/weather/palette/haze/material strengths matched exactly, all four source manifests were byte equal. All eight restore pairs were pixel exact; all four lighting-only night images were pixel exact.

`initial-native-negative.zip` is the first atmosphere-only comparison, rejected because its separate baseline instance had not received the star seed (132/83 sky pixels). Current probe feeds the actual seed and retains exact night-lighting and restore assertions.

`overcast-negative.zip` plus `overcast-negative.patch` reproduce two low-sun/cloud-cover errors before the actual sunset neutralization fix. `overcast-fixed.zip` records the fix passing with the same assertions. The atmosphere/material focus archives are explicitly earlier-tree checks, with their own source fingerprints. `input-selection-failure.zip` is a rejected CLI test selection, no product failure.

The official prior Environment GL job failed for `far_cluster` at 0.00506856 > 0.004 because the old cluster shader bypassed the shared palette/pigment path. Its original artifact 12493464664 from run 39936507091 and decoded job log are retained under `candidate-ad/`; the threshold and capture code are unchanged.

Independent process images are not byte baselines: `candidate-ad/baseline-image-identity.json` records small differences and differing rendered primitive totals despite identical canonical body/camera inputs. Only the within-process frozen before/after/restore captures are used for the visual change comparison. No specific cause of cross-process raster differences is claimed.

All native captures are software Mesa evidence, not target-PC performance. The task-local helpers record exact commands and external input hashes; adjust their PROJECT path only when reproducing elsewhere. Original input reference images are not published.

Large ZIPs are retained as ordered parts listed in `archive-index.json`; concatenate parts in index order and verify the recorded original size/SHA256. `SHA256SUMS` hashes the files actually present in the evidence tree.
