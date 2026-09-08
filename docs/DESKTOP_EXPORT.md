# Reproducible desktop exports

Godot is pinned to **4.6.3**. `export_presets.cfg` defines Linux and Windows
x86_64 release packages. V9 remains the active generator. The presets include
`assets/packs/*/manifest.json` and all runtime resources, including the 63
dynamically resolved benchmark meshes. They exclude art sources, review files,
tools, tests and documentation. Asset IDs and save schemas are unchanged.

## Build and validate

Python 3.11 or newer is required. Run from the repository root:

```sh
python tools/install_godot.py --directory godot-toolchain --platform linux
python tools/validate_export.py \
  --godot godot-toolchain/editor/Godot_v4.6.3-stable_linux.x86_64 \
  --platform linux --output builds/linux
```

On Windows, use `--platform windows`,
`godot-toolchain/editor/Godot_v4.6.3-stable_win64_console.exe` and
`--output builds/windows`. Validation runs the platform's native executable;
cross-exporting alone is not considered a native runtime check.

The installer verifies the official download SHA256 digests before extracting
the editor and desktop templates. Its portable editor has an `_sc_` marker, so
export templates do not depend on a developer's global Godot installation.
The complete template archive is about 1.26 GB; CI caches the verified downloads.

Only successful validation creates `voxelverse-<platform>-x86_64.zip` plus
`SHA256SUMS.txt`. Extract the archive and keep the executable, PCK and any adjacent
runtime libraries together. Engine and third-party notices are included.
Logs and machine-readable results remain beside the archive.

## What the gate proves

The validator exports into a fresh directory outside the checkout. Its packaged
processes receive isolated save/configuration directories and no project `--path`.

1. The official release executable starts its real main scene for 300 frames.
2. Existing Creature Builder, modular assembly, gameplay and meta-runtime tests
   run against the exact release PCK, with their scripts copied outside the pack.
3. Three fixed seeds load all 63 mesh variants/LODs, validate semantic UVs, create
   actual terrain/collision/water/instanced vegetation and restore saved health.
   The verdant seed also completes a real A → B → A scene transition.
4. The probe checks that development files and Blockbench sources are absent.
   Expected palette families are verdant (15838), autumn (63352), violet (23757).

Godot's official release templates disable external `--script` overrides. The
untouched release executable is therefore tested through its ordinary main scene.
Instrumented assertions use the same-version editor with `--main-pack` pointing
to the **unchanged release PCK**. Reports identify this as
`editor_with_release_pck`; it is not reported as instrumentation inside the release
executable. No test harness, override switch or validation autoload is shipped.

Nonzero exits, timeouts, logged script/engine errors and ObjectDB leaks fail the
gate. Exporter exit code zero alone does not count as success: exporting first
exposed an unused V6 wildlife script referencing an already removed evolution
generator. Its orphaned streamer/scene and the unused V5 editor layers were
removed. The active V7 editor/wildlife and V5 blueprint migration remain intact.

## CI and remaining acceptance

`Desktop export validation` runs natively on Ubuntu and Windows. Each successful
job uploads its build ZIP/checksum and retains diagnostics for 14 days. These are
development artifacts, not a GitHub Release. PR #9 remains unmerged.

Headless export checks do not certify visuals, shader appearance, driver support
or target-PC frame times. Blockbench review and a dense verdant/exotic scene on
real target hardware remain the next visual/performance gates.

References: [Godot export configuration](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html),
[portable editor paths](https://docs.godotengine.org/en/4.6/tutorials/io/data_paths.html#self-contained-mode),
[release command-line overrides](https://github.com/godotengine/godot/blob/4.6.3-stable/main/main.cpp).
