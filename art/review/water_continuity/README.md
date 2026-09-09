# Water continuity evidence

- `local_validation.json`: 42 strict Godot 4.6.3 checks, including the new continuity test.
- `local_water_continuity.log`: actual topology and runtime ownership checks.
- `local_linux_export.json`: nine packaged checks; import reused from full validation.
- `local_streaming_cpu.json`: existing six-chunk CPU regression benchmark.
- `streaming_cadence.json` and `cadence_*.log`: sequential cold-process before/after measurements on two unchanged scenes.

The render workflow is configured to run the new `water` case in Forward+ and
Compatibility. Publication has been explicitly approved; graphical results
will be recorded after that run. There are no new rendered images here yet.
Its four captures test a shared surface, fully clipped fallback, partial overlap,
and an intentionally overlapping negative control. Water shader time is fixed
only for that fixture; actual world/shore captures keep animated water.

Human visual approval and target-Windows-PC performance acceptance remain open.
