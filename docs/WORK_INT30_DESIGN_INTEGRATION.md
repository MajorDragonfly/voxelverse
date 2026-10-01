# INT30 design, gallery, owned animals and underwater consolidation

Integration base: `0ab9d20b0f448864c6e104c093b3ce97532e95e5`.
Branch: `agent/int30-consolidate-design-20261001`.
This is a local consolidation authorized by Lars on 1 October 2026, not a
main merge, PR closure, target-PC acceptance or full merged-tree gate result.

## Pinned deliveries

Each delivery was merged with `--no-ff` and without a conflict:

| Delivery | PR | Pinned head |
| --- | --- | --- |
| Local design library | #230 | `9c65be2d9ccf142520f9f3244582f7e6e854a12b` |
| Owned animals | #228 | `ddb09045fe4b148326c37e40ab007b1392dd094b` |
| Optional community gallery | #232 | `47cd7b39a6f353f95a9f70efd8d196c625dc8db7` |
| Cosmetic creature editor | #244 | `0a02afba0661dbc46f4d35421e9f74497bef3d67` |
| Underwater audio | #237 | `9251dcca52edc59d59954e0cbb58ed12fefcb074` |

## Production ports

- Applied the local-library frontend comparison callback so the new-game picker
  compares against its already selected starter form through the existing pure
  template preparer.
- Adapted `library-opening.patch` to the completed INT30-12 panel. The endpoint
  defaults to empty; the launcher validates it before exposing a button. Neither
  attachment nor opening initiates a network request. Gallery imports call the
  existing library `reload(key)` port, preserve the existing storage path and
  restore library input on close.
- Applied `editor-owner.patch` to the existing creature studio. Cosmetic edits
  use its existing history, preview, stats and persistence; the old controls
  remain available to existing consumers but are hidden in the product UI.
  `EditorText.refresh()` already recursively calls the new panel's
  `refresh_translation()`; no second language subscription was added.
- Preserved the owned-animal journal register already included in the delivery.
  `git apply --reverse --check --unidiff-zero journal-register.patch` passed;
  the journal port must not be applied twice.
- Applied the underwater `foley-mixer-timing.patch` unchanged. The existing
  accelerated fixture now waits at most 1.2 seconds for the real second cue;
  its same two-cue and pause assertions remain. No AudioManager production
  patch is necessary.

## Central append requirements

The integration owner must append the provided translation messages once and
regenerate the existing POs: design-library `catalog-append.json` (36),
owned-animals `localization-append.json` (12), community-gallery
`translations.json` (33), appearance `translations.append.json` (18).

Register `int30_design_library_picker_test` and `int30_community_gallery_test`
under `blueprints`, `int30_creature_appearance_test` under `creature_body`, and
`audio/int30_underwater_audio_test` under `audio`. The existing
`owned_animal_localization_test` is already registered and needs no new entry.
The appearance handoff supplies `validation-owner.patch` for the existing
bounded 240-second UI/restart test set; shared validation remains centrally owned.

## Checks on this consolidation

- `git diff --check`: passed.
- `tools/audio/check_foley.py` against the fixed Fachbasis: 29 assets passed,
  no errors. Signal/file/seam checks do not replace subjective listening.
- Re-ran `audio/tools/refine_underwater.py` into a scratch directory: all six
  committed WAVs reproduced byte for byte.
- All six delivered Python review/measurement helper sources parsed successfully.
- Final source/diff review confirmed opt-in gallery semantics and existing
  original-design, progress, protected-version and cosmetic-only boundaries.

The root integration owner runs the common import and relevant Godot tests on
the fully combined tree after central catalogs/registry are connected. No
repeated heavyweight import or full Godot suite was run in this subgroup.
The original delivery evidence remains historical evidence for its own source
tree. Full mandatory gates, native exports, Forward+ and Windows/target-PC input,
visual and hearing acceptance remain separate from these subgroup checks.
