# INT30-22 — Cosmetic appearance controls

Fixed specialist basis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`, tree
`5f815f478ceeabefcfc50a6388e3e4b0daa2ac45`. Delivery targets
`agent/integration-pt19-20260930`; no main merge or ARCH-24 body-parts takeover.

## Delivered behavior

- Five explicit channels: base, accent, belly, eye and horn; labeled picker,
  editable `#RRGGBB`, and clearly targeted existing swatches. Invalid hex entry
  keeps the draft intact and shows a translated explanation.
- Six existing CreatureSkinStyle palettes preview all five colors before Apply.
  Merely choosing a palette does not edit the creature. An exact palette match
  displays its name; individually changed colors display Custom.
- Five existing skin types. Texture strength shows percent; actual pattern size
  shows a factor. The old slider represents fineness (`skin_scale`); the new size
  control maps inversely so increasing displayed size enlarges texture features.
  No UV/material/geometry implementation is replaced. Smooth skin disables its
  ineffective texture controls and explains why. Paint-pattern opacity continues
  using the existing `paint.intensity`, with a percent readout.
- Reset removes only known appearance overrides and resets paint opacity. Body,
  parts, paint-part identity, design identity, unknown appearance extensions and
  progression remain untouched. Existing normalization supplies skin defaults
  on history restoration/loading; reset tests compare these canonical values.
- Host owns the existing undo/history, preview, save/load and protected-source
  handling. A color popup or dragged range records one pre-edit state even when
  global mouse release handling ends the host's other gestures. Selecting or
  refreshing controls creates no history entry.

## Owner attachments

The feature branch does **not** modify shared production files:

1. `editor-owner.patch`: narrow hook in `creature_editor_studio.gd`. Hide legacy
   cosmetics visually (preserve their existing consumer API), mount the new panel,
   sync after restore/load and submit accepted commands to existing history and
   `_refresh_preview()`. This is required to make the panel available in game.
2. `translations.append.json`: append DE/EN entries to the authoritative catalog,
   then run `python3 tools/localization/catalog.py`.
3. `registry.append.json`: register `int30_creature_appearance_test` exactly once
   in `creature_body`. Source-contract CI of the unconnected feature branch is
   expected to report the pending registration; do not remove/skip the test.
4. `validation-owner.patch`: use the existing bounded 240-second composite-test
   budget for this test only. It performs the full UI/history matrix and starts
   a second cold editor process to verify actual persisted data. A recorded run
   reached the restart at the default 120-second aggregate cutoff. Assertions,
   fresh-process coverage and strict error detection remain mandatory. This is
   not a global timeout change; earlier 120/240-second failures remain evidence.

Chat 1 applies these attachments sequentially. Runtime presentation stays with
Chat 7; ARCH-24 geometry, parts, IDs and editor owner files remain with their owner.
No second preview renderer, history or persistence store is introduced.

## Reproduction

Use a disposable checkout, isolated user directories and Godot 4.6.3:

```sh
python3 tools/review_int30_creature_appearance.py \
  --godot /absolute/path/to/godot \
  --checkout /absolute/path/to/new-qa-checkout \
  --output /absolute/path/to/new-report-directory \
  --worker-threads 2 --render
```

Rendering requires a display. The recorded environment uses Linux, portable
Xvfb (TCP loopback display), GL Compatibility, Mesa llvmpipe and
`LIBGL_ALWAYS_SOFTWARE=1`, `LP_NUM_THREADS=2`. The QA-only `override.cfg` bounds
`threading/worker_pool/max_threads`; the production project is unchanged. No FPS
or target-PC claim is derived from software rendering.

The tool applies all four attachments in its disposable checkout, imports,
uses the unchanged host for a comparable baseline, restores the hook in a
`finally` block, then executes focused validation and actual rendered UI actions.
It requires all five expected captures and treats engine errors/timeouts as
failures. The original source checkout and real saves are never used as QA data.

Focused checks cover actual palette Apply/reset clicks, typed individual color,
invalid entry, popup history despite mouse releases, every skin type, grouped
size change/undo/redo, channel targeting, cosmetic-only stats/geometry/IDs,
DE/EN drafts, small-window scrolling, real saving/loading and a fresh process.
Slider/type selections also have control-signal cases; this is not a claim that
all popup/pointer/drag variations or Windows input were manually played through.
Existing direct consumers are `creature_studio_test`,
`creature_parts_studio_test` and `editor_localization_test`.

The conservative applied-source plan selects the full integration scope because
of shared catalog/registry hooks. Full gates, native export/Windows input,
Forward+ and target-PC acceptance belong to integration and remain separate.


## Recorded acceptance

[Rendered inspector comparison](comparison.png), [DE before](before-de-1280x720.png),
[DE after](after-de-1280x720.png), [EN after](after-en-1280x720.png),
[800×600 / 150% colors](after-en-800x600-150-top.png) and
[800×600 / 150% skin controls](after-en-800x600-150-skin.png).
The comparison is a pair of crops from the real screenshots, not a mockup.
All five final screenshots were visually inspected. Numeric units remain clear
of the scrollbar and all controls are reachable by scrolling.

| Check | Result | Seconds |
| --- | --- | ---: |
| Source contracts with owner attachments | Pass; 248 registered tests | 0.123 |
| `int30_creature_appearance_test` | Pass; 64 checks, actual fresh editor process | 24.286 |
| `creature_studio_test` | Pass | 10.709 |
| `creature_parts_studio_test` | Pass | 21.687 |
| `editor_localization_test` | Pass; 1266 checks | 47.741 |
| Final GL rendered appearance test | Pass; 64 checks, save/load and fresh process | 58.478 |

The four headless checks are recorded in `validation-final/results.json` on QA
commit `2c291ed9261b3d7c37ce68e88a1193054b57aa77`, tree
`9840cc460aef52a55650a865f350c0b54599ea91`, source SHA-256
`938466072c4f8681a699d8cd920821eef472b2b2f0998b10c2abcb8b30949f10`.
The source was clean and unchanged throughout the runner. Complete start/end
source manifests are gzip-compressed; decompress the `.jsonl.gz` files before
checking the raw manifest hashes reported by SourceRun.

The final rendered run is recorded in `render-results.json`. It uses the same
product code and owner attachments; the only subsequent executable change is
`capture-fixture.patch`, which moves the pointer to a neutral title area before
screenshots, dismissing transient hover tooltips. All 64 assertions run again in
GL with this final fixture. `tested-source.json` identifies both source stages,
per-file hashes and the engine binary hash. Later delivery commits add evidence
only. Native render logs and image SHA-256 hashes are retained.

The initial Ocean/scales preview is identical in the 816×541 comparable viewport
crop: **0 differing pixels out of 441,456** (`preview-comparison.json`). This
checks the UI refactor at the same appearance and camera; intended cosmetic
changes naturally render different colors/textures later in the test.

Exact focused command (same imported resource cache, isolated saves):

```sh
python3 tools/validate_godot.py --project /absolute/path/to/qa-checkout \
  --godot /absolute/path/to/godot --skip-import --skip-main \
  --tests int30_creature_appearance_test creature_studio_test \
  creature_parts_studio_test editor_localization_test \
  --output /absolute/path/to/validation
```

`applied-shared-files.patch` records the QA-only applied shared source, including
PO generation and the worker-pool override. It is evidence, not an extra patch
to apply in production: use the four owner attachments above. `plan-applied.txt`
selects full integration (248/248 plus main); it is **a plan, not executed full
acceptance**. The unconnected feature branch deliberately leaves the registry
append to Chat 1. Its pending registration is not a green CI claim.

Historical reports in `history/` retain a 120-second timeout reached at the
fresh-process restart, a separate 240-second native startup timeout on an earlier
source, and the earlier 63-check success. Other diagnosis runs also hit bounded
import/startup budgets. No assertion was removed, no engine error was ignored,
and no driver/root-cause diagnosis is claimed. The final recorded runs above
pass; these earlier reports are not substitutes for final-source evidence.

Remaining integration work: apply/rebase the shared editor, catalog, registry
and timeout attachments sequentially, run all required gates on the resulting
integration tree, and perform the existing native/Forward+/Windows/target-PC
acceptance. No merge is requested by this specialist delivery.
