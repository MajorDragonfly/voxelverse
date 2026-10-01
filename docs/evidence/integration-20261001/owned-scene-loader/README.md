# Owned scene loader: Godot 4.6.3 teardown recovery

Basis: `f57b7fe9b6be7b699b23c51230ef9fb690bb3a4d`, tree
`a03aac092a5e6993a9aa635d3bf9ce06c1142f5f` (same tree as the f58 #246 candidate).
Engine: `4.6.3.stable.official.7d41c59c4`. This is a focused lifecycle fix;
shared integration, native exports and target-PC acceptance remain separate.

## Confirmed engine mechanism

The exact [ResourceLoader source](https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/resource_loader.cpp)
(blob `952a7e93cc597d88c55fba11d75731f5654e50c1`) publishes LOADED status
before its worker releases its final raw LoadToken reference. Its completion
path joins the worker only while status remains IN_PROGRESS. A correctly
paired Get can therefore release the user reference first; the later worker
unreference reaches zero without deleting the token.

The default-CACHE_REUSE cold-scene baseline performs 3000 successful,
path-matched Request/Get pairs. It leaves a predicted native instance with
signed ID `-9223371696646388302`; the exit log names native RefCounted
`9223372377063163314`, reference count 0. Adding 2^64 normalizes the signed ID
and produces the exact same instance. No Get was omitted. The allocation
marker follows the exact [ObjectDB allocator](https://github.com/godotengine/godot/blob/4.6.3-stable/core/object/object.cpp)
(blob `af26407a73cac03fe42a40fcbfcf8b8bacab2192`); this technique appears only
in diagnosis, never in production code. The baseline's final `pending` field
queries the old shared path, not each cold path, and is not used as evidence.

The race is intermittent. A later 3000-request control with an additional
immediate status query after every Get observed 3000 INVALID statuses and no
leak. One clean retry therefore does not establish a repaired lifecycle.
The attached joined-user-Thread counterpart loads 3000 distinct cold scenes
with the same default cache mode and exits cleanly in 0.841 s. Logs are gzip
compressed; `proof.json` records their uncompressed hashes and the ID match.

## Production change

SessionFlow owns one user Thread performing synchronous ResourceLoader.load.
The exact engine source runs that call inline on a user thread, retaining its
ordinary Ref until the load returns; it does not create the racy public
threaded user token. Loading UI remains responsive and indeterminate during
resource loading, then returns to existing terrain preparation. Existing
startup phases, save/version guards, selection and scene publication remain
owned by SessionFlow.

The owner polls completion and joins before delivering exactly one scene.
Failure/discard and shutdown advance main frames before joining, allowing
resource changed-signal callbacks to run. A queued start checks shutdown again
before creating a slot or starting a worker. A departing node retains its
loader through asynchronous retirement. This helper has one exclusive owner;
start, take and discard are not a concurrent multi-client API.

All explicit product quit calls route through runtime_shutdown.finish,
preserving shipyard dirty-design and domestication checkpoint guards.
The isolated medieval preview retains its existing automatic window close;
that standalone project has no campaign autoloads or background scene loader.
Its button/error exits use the coordinator. SessionFlow's
existing window/user quit guard keeps a loading session open. The coordinator
awaits prepare_shutdown before engine/audio teardown. Raw SceneTree.quit
bypasses this protocol and is unsupported while a background load is active:
a focused negative probe confirmed leaked Thread/resources and compilation
during language teardown. There is no public API interception for arbitrary
external calls to SceneTree.quit. Standalone test/diagnostic callers must
finish their work first or use the coordinator.

## Focused checks

- Real frontend consumer: strict PASS, 156.555 s; four public loads, save/copy,
  history restore, campaign isolation, failed-save retention and future-save guard.
- Body travel consumer: strict PASS, 284.376 s; actual A-B-A, conserved cargo,
  far work, failed departure/target rollback and cold-process resume.
- First owned-loader lifecycle/startup checks: strict PASS, 3.176 / 2.522 s.
- Final owned-loader / real lab window-close checks: strict PASS, 5.334 /
  23.910 s, including immediate coordinated retirement of the spherical scene.
- Final close-hook checks are recorded in `narrow-checks.json` with their source
  hashes. The runner keeps its strict log filter, isolated saves and deadlines.

The first consumers checked source SHA256
`1b526f093637330e2a59977233c1cb0fbe905461c30be3550087dd529275264b`, before
adding the three product close adapters. The final close/lifecycle checks
identify their own source. The terminal test source is SHA256
`985353b2af1ee1325c5d903d1f9a26a66f288e3efd64ea4142d055a1996a1d9d`;
only evidence files were added afterward. These are partial checks, not a full
merge-tree gate.

The lab test formerly removed its notification owner and quit while the new
coordinator was awaiting audio-release frames. Both that first sequence and a
retry with only the raw quit removed leaked one GDScriptFunctionState despite
passing their payload. The retained negative log records the latter. The test
now keeps the owner alive and lets the initiated coordinator terminate, while
assertion failures still exit 1. Strict checks were retained throughout.
