# INT30 world integration candidate, 2026-10-01

This group integrates fixed delivered heads onto `0ab9d20b0f448864c6e104c093b3ce97532e95e5`.
It is a candidate for central validation, not a main merge or new gameplay/FPS acceptance.
All source PRs, original failed evidence, and unfinished-work exclusions remain intact.

| Delivery | Pinned integrated commit |
| --- | --- |
| INT30-02 population priority | `6a0881d95df682e6675c6ee19cbe5d4bb3fedd50` |
| INT30-03 materials | `f8742c4eeade9fd4a34e68d4d815900b539085df` |
| INT30-04 camera/drinking | `298ef65c284c61b033e3aaa3b4e08e94210b0878` |
| INT30-05 scanner/nests | `a3c31235e9c0d0deb98603838e89b1f147e82f9d` |
| INT30-08 weather/water | `c41d75fbe59599a7d64f93ff72167be95825d778` |
| INT30-20 scenery collisions | `b5f98110ade47ac3e8cb1fe0c05d3d81f4a1fdb4` |

Each was merged locally with `--no-ff`; there were no merge conflicts.

## Owner connections

- Player scanner getters delegate to the production `CreatureScanner`. The existing
  `scan_circle_test` now verifies public getter/contact parity and hidden-target clearing.
- The spherical terrain water presentation receives `GameState.campaign.data.elapsed_seconds`
  at setup and on each advance. Laboratory/material fixtures retain the local-delta fallback.
  The existing `weather_runtime_test` adds real campaign tempo, pause, rewind, actual save/reload
  and planet A–B–A assertions for every current/fading/retiring water shader. It also verifies
  presentation cannot advance the authoritative clock.
- The approved surface comparison runner accepts only the exact SHA256 of its intentionally
  injected measurement script; other tracked changes, script tampering and HEAD changes fail.
  Existing explicit scene cleanup in `capture_surface_transitions.gd` remains untouched.
- Minimap profile names use translation keys already passed through the HUD's existing `tr`
  path. Central catalog additions are required before final validation.

## Checks performed here

The applied `tools/review_surface_transitions.py` is byte-identical to the supplied,
tested proposal. Seven real temporary-Git provenance cases passed; only their Godot
subprocess is stubbed. See `surface-provenance-cases.json`. These are not render tests.
All three `tests/tooling/performance_route_report_test.py` tests passed. Python compilation
and `git diff --check` passed. No import, heavy Godot runtime or full suite was repeated in
this group: those run serially on the common integration tree.

Relevant central tests: `weather_runtime_test`, `weather_forecast_ui_test`,
`living_surface_materials_test`, `scan_circle_test`, `creature_scan_test`,
`nest_discovery_test`, `minimap_test`, plus population/reload and collision consumers.
Both actual surface render comparisons must be rerun after the provenance fix.

## Required central additions

Registry/runner patch: `../int30-20-scenery-collision/patches/chat1-validation.patch`.
Register `int30_scenery_collision_test` and `int30_scenery_collision_world_test` once,
and classify the latter under the existing bounded long-world-test runner.
The separate two-renderer capture proposal is `chat1-capture.patch` in the same folder.
Neither shared registry, runner, workflows nor localization catalogs were edited here.

| Key | DE | EN |
| --- | --- | --- |
| MINIMAP_PROFILE_SURROUNDINGS | Umgebung | Surroundings |
| MINIMAP_PROFILE_TRIBAL_TERRITORY | Stammesgebiet | Tribal territory |
| MINIMAP_PROFILE_REGION | Region | Region |
| MINIMAP_PROFILE_COUNTRY | Land | Country |
| MINIMAP_PROFILE_PLANET_SURFACE | Planetenoberfläche | Planet surface |

## Preserved acceptance limits

INT30-02's final eight-test run failed reload/loading and D1.2; its measured route p95/p99
and first publications became slower. No concurrency-only explanation or performance
acceptance is claimed. The bounded production diff does not touch load readiness,
terrain publication or player grounding. A plausible code-level latency mechanism
remains: `_generation_cell` reads up to 25 wanted region payloads before `_generate`.
Those lookups now count toward the generation-frame budget, whereas most payload reads
previously occurred in the candidates stage. Cold reads/evictions could therefore defer
spawning on already-generated cells. This is an inference, not a reproduced cause;
the source delivery is preserved without a speculative scheduling change. Its archived
metrics hit the 96-entry cache limit, which includes region and individual-pointer entries.

Camera evidence still reports approximately 8 cm/0.1 s loss of grounding on a 0.5 m step
from shared `Space.step`, sphere onboarding/capture timeouts and untested target-PC behavior.
Scanner cold/dense queries remain expensive, and arbitrary partial occlusion/Forward+
acceptance is unfinished. Normal weather revision 1 still has no natural extreme storms:
diagnostic storms and synthetic positive warning fixtures remain separate. Night readability,
material GPU costs, wind/LOD movement, scenery Forward+ and target-PC acceptance remain open.
No expectations, budgets or failure filters were weakened during this integration.
