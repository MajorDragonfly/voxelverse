# UI-DESIGN-01 completion — 2026-10-08

The existing UI #281 was integrated with main `9ecc8a7b`, then the eight owner
styling ports were completed in `0e9646bf`. The final combination also contains
the independently diagnosed resident-width/scroll correction `6160c25d`.
The FOOD/WATER semantic colors, canonical gameplay sources, save IDs, test
registration and original assertion/deadline requirements were preserved.

## Source bindings

| Stage | Commit | Tree | Source SHA-256 |
| --- | --- | --- | --- |
| Original complete owner ports | `0e9646bfb8f62dae699485a081ee4fae692ed9e4` | `c96f3e50b06563b269906a4fd3694bbe711c533f` | `40c72b2ac7b77eb67b5107c78d9854ab97a81be18219d25d7aa4007eb14b5602` |
| First combined caption/forecast/scroll correction | `1ee3ed2a4c4ea3b7610a71d7faf1b4b50ebc5d72` | `3998fee9c8a34d048ba3dee4df90841a7223ff14` | `f957c0d72458fe72e76ce13d985d270b20a9e77ed6457bb6d9e1931ddd2f2deb` |
| Finite forecast lane correction | `6b5d4b4d85a3ad71a5f8d673adac6321f6874d68` | `65c047b13abc2d9b0e1a959e278ee592d12bcd1f` | `231bddf191726162307cc01225aacab0919a973c8d7ee82b1562fe6e3d0ac695` |
| Paired wheel fixture correction (test only) | `29e0eb818923660efa13e709fe5f9783904b5127` | `8afe6f9398b45e2dfc988fc8749faa8d79314aa5` | `ccbe1d723ffb02a394ffca65e78386f8583a13d6a7dda515b98febbcabf33ce0` |

Godot: `4.6.3.stable.official.7d41c59c4`, editor SHA-256
`f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3`.
Original PR #281 was read again after final native acceptance: still open/draft,
protected branch `agent/ui-design-language-20261007` head unchanged at
`2ec14bbd2e1dbc01e7f50f5e9b41c8cae35c8132`. This agent performed no remote writes.

Native renderer: `gl_compatibility`, Mesa llvmpipe on host `7f573e0a2ae8`.
This is functional/native UI evidence; it does not certify target-PC FPS,
Windows packaging or a Forward+ hardware tier.

## Original evidence and demonstrated corrections

| Run | Result | Preserved finding |
| --- | --- | --- |
| `ui-focus-01` | 9/9 selected tests + import/art/contracts PASS | HUD 966 original checks/36 cases; equipment 583 checks plus cold child 4/4 |
| `ui-native-01` | NEGATIVE | `libXtst.so.6` absent on host; native M input failed; no pictures. Portable official Ubuntu dependency then installed, without product/test changes. |
| `ui-native-02` | All test processes PASS; 165 full PNGs | Map 56, equipment 36, resource 41, forecast 32. Full-image review nevertheless identified a real forecast overlap at EN 800×600/150%. |
| `ui-map-draw-01` | NEGATIVE | External diagnostic helper had an erroneous `+` at its first line. Log and exact original helper bytes/hash retained. |
| `ui-map-draw-02` | Original scenario PASS; 112 original/additional-draw PNGs | Map captions remained clipped after two extra draws. Legend needed 105px text + 40px normal margins, while its actual minimum/width was 133px. |
| `ui-focus-02` | NEGATIVE | First finite forecast stack failed one original HUD collision criterion at creature DE 800×600/150%, among 984 checks/36 cases. Forecast/tribe layout checks passed. Source unchanged. |
| `ui-focus-03` | PASS | Corrected forecast; HUD 984 criteria/36 cases including all 966 original criteria; original resident UI consumer PASS39.135s. |
| `ui-native-03` | NEGATIVE | Map 652 criteria PASS78.676s/56 PNGs, including original509 and143 additive caption checks; resource47 PNGs including six forecast ports, then original save checkpoint rejected contradictory area membership and coroutine aborted; original 600 s guard expired. Forecast 32 route not reached. |
| `ui-native-04` | PASS | Original Resource600 route PASS488.658s/47 PNGs, with six additive forecast ports, paired wheel13/21/21 and canonical village equality; original forecast32 PASS29.156s. 79 final PNGs. Source29e0 unchanged. |

The atlas overrode only the normal Button style with wider padding than its
hover/pressed states. Removing that redundant override makes the themed state
margins consistent. An additive caption-width check now runs on every visible
navigation/close caption in the original native and headless map matrix.

The forecast originally moved left when its normal rows could not fit above
the minimap. At EN 800×600/150%, that lane intersected the real village-action
HUD and hid all forecast rows. The forecast now uses a full 292px column and
an ordinary vertical scroll area, bounded by actual top/bottom HUD rectangles
and the useful minimap minimum. A left lane remains available before village
activation only when the right lane cannot show a complete control and the
measured left lane is free, larger and sufficient for the actual panel/control
minimum. No text scaling or minimap minimum was reduced.

The real saved resource-campaign consumer adds an EN 800×600/150% check for
normal, warning and exposure presentation states. It records actual forecast,
village-action, resource-bar, scroll and minimap rectangles, checks all rows,
clock and timeline can be reached, exercises the ordinary mouse wheel, and
retains the full original world/input/save path and its 600-second guard.
Warning/exposure samples are clones supplied only to the presentation port;
they do not schedule storms or alter the real campaign weather/model/save.

## Resource negative diagnosis

`ui-resource-save-probe-01` retained the original input/frame/600-second guard
sequence, adding read-only model/input receipts and stopping after the failed
original checkpoint instead of dereferencing a missing simulation record.
It failed in 518.658 seconds, before the guard, with two original failures:
area deletion did not run, then the save validator correctly rejected
contradictory area orders. Both Delete controls were geometrically visible
and hovered, but neither set `_confirm_delete`; both areas remained.
The complete canonical village dictionary was exactly equal before and after
the forecast fixture. The fixture changed presentation/input state, not the model.

The new fixture had emitted wheel presses without their matching releases.
The pinned Godot 4.6.3 viewport source retains GUI mouse focus for another
button when its private mouse-focus mask is already nonempty; only the
release clears that bit. The separate primary mechanism source is
[Godot viewport.cpp](https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/scene/main/viewport.cpp),
191767 bytes, SHA-256 `8499322e9bba800abbd4e930a5dd578c549a950c7f993ce5c2dd207f58b93cf2`,
lines 1907–1915/1928 and 1992/2008–2010. Public `Input` mouse masks stayed zero
for synthetic viewport input and do not expose that private GUI mask.

Commit `29e0eb81` adds matching wheel releases, receipts and a canonical-village
equality assertion only inside the new presentation fixture. Its six added
lines change one tool file. Every original route, input, assertion and guard
remains unchanged. Runtime, map and focus files are byte-identical to `6b5d4b4d`;
map/focus positive evidence is reused with both source bindings. The final native rerun passed the complete original resource path and all
additional assertions; the second Delete center changed to 531 px and Assign
returned to 908.25 px, matching the successful pre-fixture route. Corrected
wheel pairing restored the intended clicks while preserving canonical save
validation and every original input/frame/guard.

## Coordination and artifact integrity

All engine sections use both nonblocking host locks through
`tools/review_r33_02_host_slot.py`, the confirmed
[completion host slot](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-6035774590),
actual foreign-process inventories and clean source start/end stamps.
The native display uses the unmodified portable Xvfb binary via isolated
loopback TCP because Unix sockets are unavailable in this sandbox.
Original source inventories, process logs, full PNGs and negative results
remain separate from the final source. `baseline-runs.json` binds all ten result/host files, including negatives and
final positives. `reuse-bindings.json` records identical runtime/map/focus
bytes between the final two source commits. Each native result JSON binds every
full PNG by SHA-256; source inventory hashes remain attached to its run.
Root maintains a durable full-evidence checkpoint independently of this compact
Git report. No local full 295-test suite was duplicated; final combined CI and
merge gates belong to root integration.

## Final validation status

UI completion is functionally and visually accepted on the exact combined
runtime source, with its original criteria and deadlines preserved:

- Current clean QA: `29e0eb818923660efa13e709fe5f9783904b5127` / tree
  `8afe6f9398b45e2dfc988fc8749faa8d79314aa5` / source SHA-256
  `ccbe1d723ffb02a394ffca65e78386f8583a13d6a7dda515b98febbcabf33ce0`.
- `ui-focus-03`: forecast 2.874 s, original HUD 984 criteria/36 cases, 167.595 s,
  original resident UI 39.135 s. All passed on 6b5d; runtime and these consumer
  bytes are identical to 29e0. The separate tribe-layout 63.177 s PASS remains bound to
  `1ee3ed2a`; its tribe-panel/layout and consumer bytes were unchanged by the
  later forecast placement/input-fixture corrections. It is a component
  result on that earlier source, rather than a rerun of the final tree.
- `ui-native-03` map: 652 criteria, 78.676 s, original 509 plus 143 additive
  caption checks, 56 full PNGs. Relevant bytes are identical in 29e0. Full-image
  review confirms Legend/Orte/Zur Karte are complete and navigation remains
  reachable.
- `ui-native-04`: the complete real resource-campaign route passed 488.658 s
  under the original 600 s guard, 47 full PNGs including six forecast ports.
  Create/redraw/assign/delete, physical pickup/held cargo, read-only rollback,
  live save/load and exactly-once far return all passed. Forecast 32 passed
  29.156s under the original 120 s inner/150 s outer guards. This final run
  produced 79 full PNGs, together with the reused map 56 yielding 135 current
  runtime-equivalent UI full images.
- Read-only reviewer confirmed all six final normal/warning/exposure top/bottom
  views: no HUD/minimap collision, all three forecast rows and warning/exposure
  text fully reachable by ordinary scrolling, enlarged fonts preserved.
- Final host END: exit0, source_unchanged=true, foreign_godot_observed=false;
  SourceRun stable/reusable=true, both locks released, no new tracked UID.

The first combined HUD collision failure and two resource negatives remain
explicit archived negatives. Neither a negative run's integrity/reusable flag
nor positive pictures alone are presented as functional acceptance.
The separate Git report changes evidence only; it does not change the tested
product source. Root owns final full CI, packaging and merge decisions.
