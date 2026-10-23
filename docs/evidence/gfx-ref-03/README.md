# GFX-REF-03 — native voxel occlusion evidence

Code: `55b27e1fe009e99ca2163cff20a472528c385aa5`; source tree `14615fa6244834ef51fe131a9d581aeabf434d8f`; PR [#292](https://github.com/MajorDragonfly/voxelverse/pull/292), base `a8d19667d88e0c095eb8e238cdaff6aee10c8992`.

This branch preserves evidence and must not be merged into main.

## Completed checks

- Godot 4.6.3, regular public `SessionFlow` campaign, `res://main/spherical_campaign.tscn`, seed 15838; GL Compatibility on llvmpipe/Mesa 25.2.8, host `9af39460c6a7`.
- Six day/night pairs across forest, forest floor and original spawn close view. Every pair captures AO strength 0 / 1 / 0 with four warmup and six retained draws per phase. All six restored full images are pixel-exact, all six AO-enabled images differ.
- Full body, camera, clock, palette, lighting, draw calls and primitives are asserted equal within each pair. SSAO is disabled equally and explicitly only for this diagnostic; saved graphics preferences are retained. No gameplay FPS or target-PC acceptance.
- Native GL run: exit 0, 278.263 s, all 18 original PNGs, full original save bytes/region blobs, recipes, source manifests, process inventories, timing distributions and raw logs in `native-gl-originals.zip`.
- Six focused Godot consumer tests pass. This run used local commit `43310ee191fade0ba7df0aec3abe5639fb5175cd`, with the exact same source tree and source-content fingerprint as the published code. All original outputs in `focused-originals.zip`.
- Source-content fingerprint: `c39c9f4d6808a69544a6b4854ee73598153132c2a76d97fca6f06a2f715b5b79`, 10018 source files, complete inventory, stable and clean.
- The authoring proof compares all 63 POSITION/NORMAL/semantic-UV/index byte streams against the fixed base and all 21 editable sources excluding only their opt-in AO metadata. All are exact. Source round-trip checks 21 near exports, 12 connected tree LOD exports and original seven under-sampling negative controls.
- The seven new AO/export Python tests and four foliage-authoring tests passed; complete tooling also passes the current CI contracts job. The authoring proof, baseline hashes, export log, import log, asset costs and setup failure originals are in `authoring-and-setup.zip`.

## Asset cost

All 63 models still total 200626 triangles and 401252 vertices, with unchanged non-byte metrics. GLB size rises from 15368680 to 16987576 bytes (+1618896, about 10.5%); the normalized RGBA vertex stream itself adds 1605008 bytes. Palette RGB is white in this stream, alpha stores local AO, GLBs stay opaque. No runtime voxel bake is added.

## Pending

Forward+ replays the exact GL initial save bytes and views next. Full current source/runtime/export/render gates are running for PR #292; this checkpoint does not claim them complete. Original setup attempts failed before Godot launch because Xvfb's keyboard compiler and then its library were missing; both logs are retained, the successful run resolves both dependencies. Full reference-look and target-PC acceptance remain separate.
