# Environment render and frame-time review

`tools/profile_environment.py` runs Godot 4.6.3 with a real rendering driver.
It uses fresh save/display directories, so installed player saves and settings
are not modified. Review tools remain excluded from desktop release packages.

## Run on the target PC

From the repository root, with Python 3.11 or newer:

```powershell
python tools/install_godot.py --directory godot-toolchain --platform windows
python tools/validate_godot.py --godot godot-toolchain/editor/Godot_v4.6.3-stable_win64_console.exe --tests environment_production_test --skip-main --output builds/render-import
python tools/profile_environment.py --godot godot-toolchain/editor/Godot_v4.6.3-stable_win64_console.exe --output builds/environment-review --frames 600 --warmup 60
```

The default is Forward+, using the project's native driver. On Linux, install
with `--platform linux` and use `Godot_v4.6.3-stable_linux.x86_64` instead. A
working graphical session is required. `--renderer gl_compatibility` explicitly
tests Compatibility. Unexpected renderer fallback fails the run.

Options include `--size 1920 1080`, `--seeds 15838 23757` and
`--cases world assets cluster creature`. The default resolution is 1280 × 720.

| Case | Captures and measurements |
|---|---|
| world | Real main scene, 25 fully populated chunks, fixed scenic camera, runtime atmosphere/water/wildlife; initial streaming and settled frame distributions |
| assets | All seven imported families with Near, Mid and Far from left to right; consistent framing and planet palette |
| cluster | Identical Far vegetation before/after clustering, with unchanged camera, placements and palette |
| creature | Identical generated grazer before/after runtime voxel batching, preserving its articulated roots |

Each directory contains PNGs, `capture.json` and the engine log. The combined
`results.json` records adapter/API, renderer, resolution, sample count and
median/p95/p99/max for wall-frame time, render CPU/GPU time and draw counts.
Render CPU time includes viewport rendering plus frame setup, not every gameplay
subsystem. GPU timings with unavailable timestamp queries are identified explicitly.

The world case holds the player at the actual scenic spawn, disables that review
player's survival updates and sets spawned predators' attack damage to zero.
Wildlife movement/animation and chunk generation remain active. This prevents a
long capture from measuring a respawned, empty area. The two dense reference seeds
must contain at least 1,000 vegetation instances across 25 chunks. Streaming-stage
diagnostics are retained on success and failure; gameplay/combat use separate tests.

The cluster/creature comparisons also require fewer recorded draw calls and a
mean RGB difference no greater than 0.004 (normalized 0–1) from the unbatched image.
This allows small raster/shadow rounding differences while catching palette or
geometry corruption. Script errors, shader failures and resource-leak warnings
fail the run.

## CI scope

`Environment render validation` uses Mesa software rendering through Xvfb, on
both Forward+ (Lavapipe/Vulkan) and Compatibility (llvmpipe/OpenGL). It renders
at 960 × 540 and uses short samples to check actual rendering and A/B parity.
PNG/log artifacts are retained for 14 days.

CI passes `--fast-setup`, which suppresses drawing during initial scene assembly.
Its setup times are therefore **not gameplay frame-time measurements**. The
normal target-PC command above renders throughout setup. Software GPU timings
and short CI samples must not be presented as target-PC FPS or p99 guarantees.
`target_hardware_acceptance` remains false: passing technical gates does not
automatically grant human visual approval or certify a performance target.

Review the seven original `.bbmodel` sources in Blockbench as well as these
actual Godot captures. Inspect silhouettes, fern connections, ground contact,
color relationships and the Near/Mid/Far transitions. Then profile a dense
verdant and violet world at the intended display resolution on target hardware.

Technical references: [Godot HLOD](https://docs.godotengine.org/en/4.6/tutorials/3d/visibility_ranges.html),
[RenderingServer timing and counters](https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html),
[vertex color handling](https://docs.godotengine.org/en/4.6/classes/class_basematerial3d.html#class-basematerial3d-property-vertex-color-is-srgb).
