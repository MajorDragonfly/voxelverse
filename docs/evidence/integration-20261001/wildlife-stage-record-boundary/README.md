# Wildlife staging record boundary

The final patch reloads a selected generated animal through its stable ID after
the fixture's region generation and terrain/clearance waits. It checks both
record existence and the real `storage.move` result, and returns before changing
`home` or spawning when either operation fails. It changes only
`core/diagnostics/wildlife_hunting_world_probe.gd` (+8/-1). There is no extra pin,
storage/production change, larger cache, timeout change or relaxed assertion.

## Controlled causal evidence

The original CI failure had two spawn failures and `observations={}`. The first
local run with the unchanged fixture sequence plus a read-only move observer
passed on another random body identity. Campaign/body identities are random;
the body-scoped cell key also contributes to the generated animal role seed.
That positive run is retained, not described as a reproduced failure.

The next diagnostic run overrides only the newly created seed-15838 body's ID
with the original CI ID, `body_d28e2b290d3cf5b3f44c93eb99e25aab`. It uses the
same production generation, terrain, collision clearance and original move/spawn
sequence. No eviction forcing or resource/state reset was added. Its two IDs,
unchanged failure locations and final failure messages match the original CI
payload exactly.

For `object_756cd585a7c8861370f412eab8cd2ca7`, the original source page was no
longer cached. `move` loaded the canonical region but rejected the retained
Dictionary with `Veraltetes Individuenabbild beim Regionswechsel.`. The reloaded
record had the same ID/location but was a different Dictionary reference; the
selected old location remained unchanged. The ignored `false` was followed by
a spawn at that original location. For the second ID,
`object_bbf064677e9854a2e92e8fc75d1fba4f`, the selected record was still current,
but `move` also returned false because the first storage error was sticky.

With the final reload-only patch on that same diagnostic body, the first old
reference differs from the refreshed canonical one, both moves return true with
empty error, and both records match their destination's canonical Dictionary.
The full meal, failed-save rollback, shared live needs, unload/respawn and fresh
process checks then pass. This is controlled local causal evidence; the original
historical CI log did not itself record move return values or native references.

An earlier draft added a fixture source-page pin while the population tick was
disabled. Its positive runs and patch are retained as superseded evidence.
The complete reload-only counterfactual passed without that addition, so the
final patch removes it. Actual source/destination pin flags were not measured;
no measured necessity of a new pin is claimed.

## Exact tested sources

| Source case | Source classification | Result |
| --- | --- | --- |
| Original CI 9866 / 2b9 | Clean CI source | FAIL, exit 1, 34.911 s |
| original-random-observed | Dirty diagnostic content over 8084ba3 | PASS, exit 0, 92.381 s |
| ci-body-original-observed | Dirty diagnostic content over 8084ba3 | FAIL, exit 1, 51.505 s |
| pinned-draft-clean | Clean committed source d2ba145 | PASS, exit 0, 99.515 s |
| ci-body-pinned-draft-observed | Dirty diagnostic content over d2ba145 | PASS, exit 0, 99.720 s |
| ci-body-reload-only-observed | Dirty diagnostic content over 1206b8a | PASS, exit 0, 122.388 s |
| reload-only-clean | Clean committed source 1206b8a | PASS, exit 0, 126.796 s |

Final code commit: `1206b8a3329fcb9b1b91e3c89638cf9a243aa961`; tree `3b1b1a52cb9c6b361e3327a1a8a9bd3be3e95355`; parent
`8084ba3e7e7a15804696b9e487cc18321978f2ff`. Final clean source inventory SHA-256:
`81af1abc55bbcdab19250484a22d24afc9cea99740b2bcb1239292d8f39c0983`.

All actual source-start/end manifests and every local check log were verified.
Stable diagnostic content remains dirty content over its declared base, rather
than a clean commit. `proof.json` contains exact commands, environment, source
hashes, manifest hashes, results and relative companion paths for every started
run. A successful parent launches the existing fresh-process restart command in
the same checkout and inherits the isolated user-data environment. The negative
reconstruction stops before that child. `*.results.json.gz` retain raw results;
`*.log.gz` retain raw logs and `*.trace.json.gz` retain full parsed observer data.

Godot is pinned at `4.6.3.stable.official.7d41c59c4`. All local runs used the
existing strict runner, `--tests wildlife_hunting_world_test --skip-main
--skip-import`, isolated per-check data, and its unchanged 420-second world-test
deadline and ERROR/leak filter. The import cache was copied physically to each
owned worktree from a previously successful import of the unchanged resource
inputs; no shared cache was mutated. The actual environment/version and native
arguments are in `proof.json` and the raw runner results.

## Portable reconstruction and limits

The original remote head `9866ca99ae5d47701a6c131725ca7b5dea25df59` and local
base `8084ba3` have the same tree `2b9fbad25cd79a8dafab64564bab2dd9f4135eba`.
Use a fresh worktree of that remote head and decompress the desired patch outside
the source checkout before applying it. `fixture-fix.patch.gz` is the exact
minimal final patch against this baseline. For the original random observer or
negative reconstruction, apply respectively `original-move-observer.patch.gz`
or `ci-body-original-observer.patch.gz` directly to the baseline. For the final
controlled positive, first apply `fixture-fix.patch.gz`, then
`ci-body-reload-only-observer.patch.gz`. To reconstruct only the superseded
experiment, apply `superseded-pinned-draft.patch.gz` then
`ci-body-fixed-observer.patch.gz`. Observer and body-override patches are evidence
only and are absent from the delivered code.

The scoped runs do not approve the complete source suite, native exports, FPS,
target-PC behavior or main integration. Root must run the complete required
gates on its new common tree. The old CI negative remains a negative result.
