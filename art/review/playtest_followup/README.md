# Playtest follow-up evidence

Actual Godot 4.6.3 Forward+ and Compatibility viewport captures, unedited.
Runtime source: `defb38d1f6226635464d9cb89ad5ab3c148b1eac`.

- `*_15838_*`: natural palette, open coast and distant ridge.
- `*_23757_*`: exotic palette, woody biome and coastal formations.
- `*_species.png`: three authored Near structures, left to right variants 0/1/2.
- `*_render_results.json`: all 36 captures per renderer, frame distributions and
  exact geometry/cluster comparisons. The archive has all original images.
- `ci_validation.json`: 41 strict checks; `ci_*_export.json`: ten checks per OS.
- `streaming_cadence.json`: cold-process main-scene comparison at 60 Hz; four raw logs.
- `landscape_samples.json`: before/after terrain measurements around each spawn.

Full render artifacts: [workflow run](https://github.com/MajorDragonfly/voxelverse/actions/runs/34197542246).

The world captures hold a review player at the deterministic scenic spawn;
survival and predator damage are disabled only in this tool. The mountain camera
can still be blocked by nearby trees, so the shore view provides a second actual
vantage point. Software rendering and four measured frames establish functional
rendering, not target-GPU frame-rate acceptance. Water and coarse horizon handoff
remain open to human art feedback. No image synthesis or image editing was used.
