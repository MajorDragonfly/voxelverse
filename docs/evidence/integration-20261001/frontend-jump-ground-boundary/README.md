# Frontend jump input boundary — focused evidence

The original Windows release failed its real jump assertion. Its state at the
press was not recorded, so these records do not establish the exact cause of
that historical failure. Both later Windows observation attempts passed on a
different, explicitly diagnostic tree. Their positives are not a fix proof or
general export acceptance.

An independent fixture gap is visible in the source: the old floor check ran
before two process-frame waits and optional capture. It did not ensure current
floor and terrain readiness when Space was actually pressed. The minimal patch
checks both after all physics updates in the main iteration and presses without
yielding. It retains the two original post-press physics signals, release and
real jump assertion. The wait limit remains **180 physics ticks**, including
catch-up ticks; the existing 240-second deadline and strict ERROR filter remain.

Godot 4.6.3 emits `physics_frame` before node physics updates; the process phase
follows the complete physics-step loop. Official source references, inspected
source hashes and the independent patch review are in [patch-review.json](patch-review.json).

| Record | Actual result | Source classification |
|---|---|---|
| Original e8 Windows export | FAIL, exit 1, 170.937 s | CI merge `92714f60`, tree `782909a3`, clean; no jump-state payload |
| Windows diagnostic 151, attempt 1 | PASS, exit 0, 188.656 s | Tree `b1d30e89`; observation code and separate diagnostic runner |
| Windows diagnostic 151, attempt 2 | PASS, exit 0, 186.907 s | Same diagnostic source; a second separate observation |
| Linux original sequence, controlled cadence | PASS, exit 0, 186.035 s | Dirty base `31455ca`, tree `782909a3`, source `26a2e32a…` |
| Linux candidate, controlled cadence | PASS, exit 0, 179.301 s | Dirty base `31455ca`, tree `782909a3`, source `3089404d…` |
| Linux exact clean minimal candidate | PASS, exit 0, 185.974 s | Commit `3f661798`, tree `7279086a`, source `8ad23d23…` |

[cases.json](cases.json) contains complete Windows commit/tree/source,
run/job/artifact identities and digests, native command, environment and retained
log/trace references. Original e8 used runner image `20260922.246.2`; the two
diagnostic attempts used `20260925.250.1`, in different regions. Their PCK hashes
also differ. These are not byte-identical execution environments or packages.
The original artifact recorded source-manifest hashes but did not upload the
manifest files; both diagnostic artifacts did include verified manifests.

[focused-runs.json](focused-runs.json) records all three actual focused Linux
runner results, engine, command, environment, complete source hashes and
manifest digests. Both cadence experiments set `Engine.max_fps=10000` only from
movement release through the original jump assertion and retained an observer.
They are instrumented dirty sources with stable manifests, not clean commits.
The original cadence experiment passed: **no jump negative was reproduced**.
An initial invalid test selector failed before Godot started and is excluded.

The candidate cadence trace records its helper starting at physics tick 388,
then confirming floor and terrain readiness at a process boundary at tick 390.
It presses immediately there, consuming two physics ticks of the 180-tick
budget. The next player physics update produces about 0.106706 m of upward
movement, upward velocity 6.4, one jump event and completed guidance. The
unchanged assertion passes at tick 392. These observed candidate facts do not
retroactively supply the missing e8 Windows state.

The clean candidate is only `core/diagnostics/frontend_probe.gd`, 18 additions
and 5 removals. Its SHA256 is
`9a677c0baed885945b776388d1d3b53b1c0e129c19eb4b359956b0e36a2b183a`.
No observer, cadence override, diagnostic runner or workflow is integrated by
the production patch. This evidence change contains documentation only.

To repeat a cadence control, decompress its companion `*-source.patch.gz` to
an external temporary file and apply it to a fresh checkout of `31455ca` or
remote `e8f2fede` (same tree `782909a35d6d78eea36e69c863943db234a5f7b8`).
For the normal check, decompress [minimal-ground-boundary.patch.gz](minimal-ground-boundary.patch.gz)
externally and apply it to that fresh base. This reconstructs the exact tested `3f661798` content / tree
`7279086a` without depending on that local commit ID being published. From the
reconstructed checkout:

```sh
python3 tools/validate_godot.py --godot /absolute/path/to/Godot_v4.6.3-stable_linux.x86_64 --tests frontend_test --skip-main --output /fresh/directory/outside/the/checkout
```

The relative companion paths and compressed hashes are listed in
[verification.json](verification.json). The source patches are evidence files;
they are not applied by the normal candidate. Final common-tree full validation,
native release acceptance and target-PC acceptance remain separate.
