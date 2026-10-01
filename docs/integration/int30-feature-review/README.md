# INT30 native review commands

`.github/workflows/int30-feature-review.yml` runs eight independent jobs on the
actual PR test merge or selected `workflow_dispatch` ref. Each job imports through
the established strict runner, uses Godot 4.6.3/Xvfb/Compatibility and uploads the
original helper logs, PNGs, results and complete common-source manifests. Helper
errors, existing timeouts, incomplete captures or changed source fail the job.
This workflow supplements the four required gates; software rendering supplies no
target-PC, FPS or subjective acceptance.

In the commands below, `GODOT` is the verified editor and `OUT` is a fresh directory
outside the checkout. Run under `xvfb-run -a -s '-screen 0 1920x1080x24'` with
`LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2`.

| Flow | Supplied helper command | Existing limits |
|---|---|---|
| Design library and editor consumer | `python3 docs/evidence/int30-design-library/review_picker.py --project "$PWD" --godot "$GODOT" --editor --output "$OUT"` | 300 s per scene; the documented 600-s loaded-host diagnostic is not enabled |
| Owned animals | `python3 tools/review_int30_owned_animals.py --godot "$GODOT" --output "$OUT"` | 180 s; 27 images and fresh process |
| Shipyard | `python3 tools/review_shipyard_presentation.py --godot "$GODOT" --capture --authoring-profile --output "$OUT"` | 240 s per case; 18 images and restart; unchanged authoring sources, LocaleManager/DisplaySettings-only host |
| Tribal guidance | `python3 tools/review_int30_tribal_guidance.py --godot "$GODOT" --mode ui --output "$OUT/ui"` and the same command with `--mode world --output "$OUT/world"` | 900 s per mode; both isolated UI and real spherical-world flows |
| Appearance | `python3 tools/review_int30_creature_appearance.py --project "$BASELINE" --checkout "$CANDIDATE" --reuse-checkout --godot "$GODOT" --render --output "$OUT"` | Existing 180-s import, 240-s captures and registered focused budgets; five before/after images |
| Medieval preview | `python3 civilization/technology/run_preview.py --godot "$GODOT" --verify --capture --renderer gl_compatibility --output "$OUT"` | 120 s per isolated catalog/UI/entry process; ten images |
| Galaxy browser | `python3 docs/evidence/int30-24-galaxy-browser/review.py --project "$PWD" --godot "$GODOT" --output "$OUT"` | 120 s; twelve current browser images |
| Building templates | `python3 tools/review_int30_building_templates.py --godot "$GODOT" --output "$OUT"` | 150 s per case; fifteen images and fresh-process reload |

Appearance uses two disposable detached worktrees: `BASELINE` at the fixed
predecessor `0ab9d20b0f448864c6e104c093b3ce97532e95e5`, and `CANDIDATE` at the exact
combined job commit. `--reuse-checkout` prevents applying the already integrated
owner patches again. The existing helper temporarily uses the predecessor editor
host for its `--before` capture, restores the candidate, runs the focused checks
and captures the integrated UI. No worker override is introduced. The workflow
checks that the candidate has returned to the common tree with a clean status;
the outer immutable checkout supplies the combined provenance. The helper's
`source_commit` therefore identifies the explicit baseline, while its
`applied_owner_tree` and the outer manifests identify the tested combined tree.
