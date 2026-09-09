# Voxel water, distant mountains and physical depth

Playtest correction, 8 September 2026. Branch `agent/meta-runtime-v8`, Draft PR #9.

## What the screenshot exposed

The water continuity checks passed, but did not establish that refractive water matched the voxel art. Distant terrain still used a smooth triangle heightfield. Lakes were shallow trays (2.8 m), rivers 1.35 m, and the underlying ocean floor was usually only a few metres below sea level.

## Changes

- Both the 4 m horizon and 2 m chunk proxy now have horizontal column tops, vertical risers and flat normals. Near terrain retains its 0.5 m columns. A shared indexed mesher carries all three height endpoints; risers needed by a later LOD start collapsed and open during the existing gradual transition. Negative-coordinate edges and collision remain covered by acceptance checks.
- Water uses restrained, square colour patches, matte lighting and discrete depth colours. Screen-colour emission, refractive distortion and smooth ripple normals are removed. Shallow water remains translucent; deeper water obscures the bed. Colour detail fades with distance to prevent moire. The continuous shared surface and partial fallback clipping remain in use.
- Below a 0.75 m ocean shelf, bathymetry adds up to 24 m of physical depth. Dry terrain and the coastline remain fixed. Rivers have deeper channels; lake bowls retain a shallow rim and deepen toward their centre. Terrain meshes, collision and world sampling use the same field.
- The player floats at the local water height in deep water, swims at reduced speed, and can rise with Space. Returning to shallow water restores normal walking and step snapping. Drinking works while afloat even when the bed is beyond the interaction ray. This is basic surface swimming, without a diving/oxygen system or new animation assets.
- The sky below the distant sea horizon now uses atmospheric colours, removing the black ground-sky band visible in the playtest.

## Acceptance and scope

`water_depth_test.gd` samples actual generated terrain across seeds 15838, 23757 and 424242. Maximum sampled depths are 29.20, 28.80 and 29.35 m. Their lake centre minimum depths are 5.60, 5.93 and 5.74 m. A ray into the real chunk collision confirms the deep lake floor; the real player settles at its elevated surface, drinks and returns to walking on dry land.

Terrain acceptance checks flat tops at every LOD endpoint, vertical faces, closed shared boundaries and gradual/reversible handoff. The published horizon fixture contains 36,864 columns, 341,988 indexed vertices and 170,994 triangles. This is a bounded increase from the old smooth proxy; target-PC frame pacing must be assessed in the test build.

Renderer review now includes mountain/shore previews and controlled checker beds at 0.3 / 2 / 8 m depth. Its image gate requires visible shallow-floor contrast and an obscured deep floor. Existing water overlap negative controls and geometry-batching comparisons remain enabled. Final renderer results and fresh Windows/Linux packages are recorded in PR #9 when CI completes.

The full local suite and focused rechecks are recorded in `art/review/voxel_style_depth/`. The old -9 m world-range assertion is updated to the intended -33 m bathymetry bound. GPU-decoded normal checks allow packing error while still requiring axis-aligned faces. Front-face acceptance now checks every morph endpoint and rejects inward or permanently degenerate triangles; temporarily collapsed risers are intentional.

Builder designs, progression, combat, save/restore and planet switching retain their existing validation. No genetics, mutation, new asset families or continental fluid simulation are introduced. PR #9 stays a draft and unmerged.
