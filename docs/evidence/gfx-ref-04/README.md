# GFX-REF-04 native graphics evidence

Source candidate `a6fe4a600552a74335242689c542a7d622b48cc4`, tree `062f512579ac40e852ed617006edde879f5fea35`, base `148ba0bb578e9a01db501444fd11823fa09e8212`, PR #293. All current technical checks passed; main adopted the exact tested tree via merge `0cc3e2c34037990535672b626601aac535ab2467`; this branch contains evidence only and must not be merged into main.

The current production change combines quieter shared leaf/shrub pigment, warm direct/cool ambient day lighting and earlier depth haze. The merged legacy HLOD also uses the shared palette response. Geometry, semantic slot identities, placement budgets and saved data are unchanged.

## Current checks

The original cluster lab comparison passes at the current tree: mean RGB error 0.0027672098 under the unchanged 0.004 threshold; draw calls 10 to 4. Current regular-campaign GL passes in 342.354s with 16 original images, exact restores and exact night-lighting controls. Current Forward+ also passes in 509.549s, with 16 originals; both remain below the unchanged 600s guard. All 32 current images are retained. Exact original replay bytes/regions/views, complete body and actual camera/clock/weather/palette/haze/material inputs match across both renderers; all four complete source manifests are byte equal. Every restore and each lighting-only night control is pixel exact. Complete CI originals are being added. All298 source tests passed exactly once across eight disjoint current shards; every original log hash and unchanged complete source fingerprint was verified. Runtime27/27 passed. Current Godot, Environment and Dashboard gates are successful; Linux export42/42 and all41 original log hashes are verified, including the three real release probes. Windows42/42 and all41 original checklog hashes are also verified. All four actual required gates from App15368 are successful at the exact current head. Actual main/tree/ordered parents were verified after adoption. Target-PC/FPS acceptance remains open.

## Preserved earlier evidence

`candidate-ad/` contains the complete **preceding** tree `455e558b` native runs (GL 334.328s, Forward+ 526.507s, 32 images). These are historical and are not current-tree acceptance. Both used the same original cold replay; full bodies/cameras/clock/weather/palette/haze/material strengths matched exactly, all four source manifests were byte equal. All eight restore pairs were pixel exact; all four lighting-only night images were pixel exact.

`initial-native-negative.zip` is the first atmosphere-only comparison, rejected because its separate baseline instance had not received the star seed (132/83 sky pixels). Current probe feeds the actual seed and retains exact night-lighting and restore assertions.

`overcast-negative.zip` plus `overcast-negative.patch` reproduce two low-sun/cloud-cover errors before the actual sunset neutralization fix. `overcast-fixed.zip` records the fix passing with the same assertions. The atmosphere/material focus archives are explicitly earlier-tree checks, with their own source fingerprints. `input-selection-failure.zip` is a rejected CLI test selection, no product failure.

The official prior Environment GL job failed for `far_cluster` at 0.00506856 > 0.004 because the old cluster shader bypassed the shared palette/pigment path. Its original artifact 12493464664 from run 39936507091 and decoded job log are retained under `candidate-ad/`; the threshold and capture code are unchanged.

Independent process images are not byte baselines: `candidate-ad/baseline-image-identity.json` records small differences and differing rendered primitive totals despite identical canonical body/camera inputs. Only the within-process frozen before/after/restore captures are used for the visual change comparison. No specific cause of cross-process raster differences is claimed.

All native captures are software Mesa evidence, not target-PC performance. The task-local helpers record exact commands and external input hashes; adjust their project/work paths when reproducing elsewhere. Original input reference images are not published.

Large ZIPs are retained as ordered parts listed in `archive-index.json`; concatenate parts in index order and verify the recorded original size/SHA256. `SHA256SUMS` hashes the files actually present in the evidence tree.

Current official Environment originals: all8 artifacts,222 decodable PNGs and50 strict error/leak-free raw logs verified. CI originals in `ci/` retain their exact upstream ZIP bytes/digests, split only by the archive index. Source manifests were physically hashed and counted (10018files/916018890bytes), not just read from summaries. Export raw source JSONLs are not uploaded by the upstream workflow; Linux declared manifest digests match the actual separately retained runtime manifests. Both platform fingerprints are retained separately. The Windows raw source fingerprint differs from Linux; both self-match before/after and share the exact same clean complete Git tree/index/file-count/byte-count.

Final CI originals:21 validation artifacts plus3 original plans, each with upstream ID/run/head/size/digest in `ci/artifact-index.json`. Desktop build wrapper metadata is in `build-artifacts.json`; build binaries were not copied into this evidence branch. Their upstream retention remains14days. Release ZIP sizes/digests are declarations retained in each verified export report; all42 actual checks and41 original log hashes per platform were verified.

Actual adoption is recorded in `integration.json`: main `0cc3e2c34037990535672b626601aac535ab2467`, exact tested tree `062f512579ac40e852ed617006edde879f5fea35`, ordered parents base148ba0bb and sourcea6fe4a60. The evidence branch itself is not merged into main.
