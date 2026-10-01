# INT30 assembly consolidation

Integrated seven fixed delivery heads without conflicts, retaining each complete history:

- #233 `93411209f42b2913a6aa0e4c5712b8b9a35409a5` building editor.
- #241 `12656d6b374a5c257495c1abc8291512a22182d3` shipyard presentation.
- #236 `7a198173d0ead2a82e6b245e9b055c02e40295a0` building exchange.
- #235 `2c5826c02f2ba140a1108611394ee315d7b69e17` ship exchange.
- #240 `42dcba8dfa0304e8dbe01434abbc7562eea23ef8` isolated medieval technology preview.
- #239 `142ff1d4f987dcbd85cf9af24762f7153856f58d` galaxy browser.
- #238 `d931d7edf141d890fa81d809150b146d7fca4c4d` building templates.

Basis: `0ab9d20b0f448864c6e104c093b3ce97532e95e5`; branch `agent/int30-consolidation-assembly`.

## Production adapters

The supplied owner patches were adapted to the final editor/shipyard sources, rather than applying old line-number-only hunks:

- Building editor displays the existing built-in template picker and connects its copy/history adapter.
- Explicit file-dialog Import installs a portable building revision in the immutable device-local inbox, then requests user confirmation before adopting a distinct editor copy. Cancellation keeps the draft. Adoption checks active campaign, completed transition, medieval phase and target-source protection; Undo retains the previous complete draft.
- Received/template building copies cannot overwrite unrelated named designs in either the active save snapshot or the loose file. Their own subsequent revisions remain writable through the normal editor path.
- Shipyard Import installs a received native revision using the existing authoring library. It preserves the open draft and fleet. Export requires a committed unchanged revision.
- Imported ship paths are read-only originals in the editor Save action; Save as Copy creates the separately editable saved design. Existing native authored designs keep the normal Save behavior.
- Applied the galaxy lab’s null-guarded read-only visit port and the scroll/Canvas-coordinate click fixture without removing assertions or increasing budgets.
- Added the integration-only medieval test wrapper from the owner's patch, with UID. The prototype has no campaign UI host, persistent research state or production effects.

No epoch entry, save schema, catalog, fleet instance, production cost or unlock was changed. No shared files were edited.

## Required central attachments

Consume the append data once and register each test once:

- Building editor: `docs/integration/int30-14-building-editor/catalog-messages.json`, `registry.patch`.
- Shipyard: `docs/evidence/int30-15-shipyard/catalog-additions.json`, registry entry from `chat1-shared.patch`.
- Building exchange: `docs/evidence/int30-17-building-exchange/test-registration.patch`; `runner-budget.patch` classifies only the bounded three-process persistence test.
- Ship exchange: `docs/evidence/int30-18-ship-exchange/localization-append.json`, `registry.patch`.
- Templates: `docs/evidence/int30-building-templates/integration/localization.append.json`, `validation.append.json`.
- Medieval prototype: `civilization/technology/messages.json`; registry portion of `docs/evidence/int30-23-medieval-tech/test-registration.patch`. Wrapper already applied here.
- Galaxy browser: `docs/evidence/int30-24-galaxy-browser/translations.json`, `registry.patch`. The lab and click-fixture patches are already applied here. Owner assertions and budgets remain unchanged.
- New adapter strings: this directory's `localization-append.json` (nine DE/EN messages).

Do not reapply the supplied building editor/template/shipyard adapter patches; those functions/UI actions are already integrated.

## Checks and limits

Godot `4.6.3.stable.official.7d41c59c4` parsed both modified production scripts, both extended registered input tests and the medieval wrapper successfully. `parser-checks.json` records the five exits. The temporary parser project omitted campaign autoloads and reused existing import/class caches; this was syntax checking, not gameplay/import/render acceptance.

Added bounded assertions to the existing building and shipyard interaction tests for production dialog wiring, explicit adoption/cancellation, medieval/session/transition guards, immutable originals, copied identities, saved-only export and Undo. Root integration must execute these tests after shared translations and registry wiring on the final common tree. No complete import or heavy group suite was run concurrently with other consolidation groups. Full suite, four required gates, native exports, graphical acceptance and target-PC performance remain central open checks; all historical failed/timeout evidence remains intact.
