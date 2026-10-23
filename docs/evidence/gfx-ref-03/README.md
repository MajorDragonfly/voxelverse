# GFX-REF-03 — reviewed local voxel occlusion

Current code: [`7eddc208d3554be6fceaead1dc15915b3d311429`](https://github.com/MajorDragonfly/voxelverse/commit/7eddc208d3554be6fceaead1dc15915b3d311429); tree `bc77ee592c84d0dc06a4253f5d6829d18738c120`, base `a8d19667d88e0c095eb8e238cdaff6aee10c8992`. [PR #292](https://github.com/MajorDragonfly/voxelverse/pull/292). This evidence branch must not be merged into main.

## Reviewed corrections

Every retained native pair must show AO and restore its complete baseline image exactly. The mesher includes all four unit-corner AO values in its key and merges only along an axis without a gradient. This preserves middle-edge creases and permits straight affine strips.

Nine physical/export tests pass, including a raised neighbor in the middle of a long face and the straight occluded edge. A fresh import and six actual Godot consumers pass on the exact current source tree. Source round-trip checks 21 Near files, 12 connected tree LOD exports and seven original negative controls. Four foliage-authoring tests pass. See `final/authoring.zip`, `final/focused.zip` and `final/source.json` for raw outputs, commands and source binding. The focused local commit differs only in Git commit metadata from the published commit; both have the same tree and complete content fingerprint.

The geometric proof now compares exact exposed grid tiles, normals, semantic slots, bounds and filled voxels across all 63 models, plus all 21 editable sources excluding the AO opt-in. These are identical to the base. Vertex and index streams intentionally change with AO subdivisions. The first proof-script attempt incorrectly compared the GLTF position accessor count as part of its bounds metadata; its original failure and corrected explicit min/max comparison are retained.

## Cost

Model triangles: 200626 to 307636 (+53.3%); vertices: 401252 to 615272. GLB bytes: 15368680 to 25976580 (+10607900). Instance/cell budgets remain unchanged. This is a visual quality tradeoff, not a gameplay FPS or target-PC acceptance.

## Current acceptance

The corrected native GL and Forward+ 0/1/0 comparisons and four official CI gates are being rerun on the current tree. This checkpoint does not claim their completion. The new native runs both use the identical original saved-game replay and views.

## Preserved earlier candidate

`candidate-1.md` and the original root ZIPs/images document code `55b27e1` / tree `14615fa6`, including the negative additional cross-session full-state comparison. Those originals remain intact and do not approve the corrected tree. The earlier candidate kept original geometry streams but could miss AO inside a large merged face; the reviewed mesh split supersedes that approximation.

All renderer timings use software GPUs. Full reference-look and target-PC acceptance remain separate.
