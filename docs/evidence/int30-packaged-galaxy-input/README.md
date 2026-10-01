# Native Galaxy click target correction

Base: local `16fe06e72ccd0f6b5e7577d9b61e6b1b06221089`, tree
`00c718e2a10f6d2a540174d66214eb232a96b63f`, identical to published
`4513216a61cbab8d660b8a8405eb4a9c879b8ff3`.

The actual Windows and Linux FULL export gates failed the native Galaxy note,
reopen, Visit and precise-save/return chain. The completed Galaxy browser moved
long details into `GalaxyScroll`; the older packaged input probe clicked a
control's transformed center without scrolling it into view. This was a stale
probe target, not a failing catalogue/journal/travel operation.

The full unchanged source route reproduced all five CI failures. Save's center
was `(903.75, 1435.5)` and Visit's `(1182.75, 1218)`, outside the logical
`1920×1080` viewport for the physical `1280×720` headless window. Both had
`scroll_vertical=0`. The separate completed catalogue native fixture already
uses `ensure_control_visible()` and three settled frames before its clicks.

The narrow correction applies that same normal scroll port to the two native
probe actions, then injects the same viewport mouse motion/button events. Every
original state, note, modal Escape, physical planet and millimetre-precision
save/return assertion remains. Extra assertions require the actual click center
to be inside the viewport and each enclosing scroll clip. No product, event,
storage, timeout, error filter or catalogue data changed.

The same full real route then passed, exit 0, 38.232 s; baseline exit 1,
34.517 s. Save scrolls to 254 and Visit to 109, placing both centers at y=1054.5.
These elapsed times describe functional runs, not a performance comparison.
Godot `4.6.3.stable.official.7d41c59c4`, Linux/headless, isolated XDG/APPDATA paths.

`diagnosis.json` preserves exact geometry, exit codes, timings and log SHA256s;
compressed original logs retain the failure and successful route. The `.gd.txt`
files are the external diagnostic subclass and SceneTree launcher. To reproduce,
copy them to their recorded absolute scratch `.gd` paths, then run Godot with
`--headless --path <this checkout> --script <baseline_runner.gd>` using the
existing `tools.validation_support.validation_editor` and `isolated_env` helpers.
The subclass prints geometry and otherwise delegates to the actual probe.

The clean, uninstrumented production `--input-smoke` entry also passed, exit 0,
45.914 s, with no Godot error. Exact code commit:
`6aa16ba221bd1f279f74d491c42c81b13c036062`, tree
`7bc19e7e4745cedc0850a38a78a6550874a34da6`. SourceRun captured 5,375 source
entries before and after execution: complete, tracked worktree clean, unchanged,
no source or Git changes, SHA256
`5e84eab394af48eb7f98de31099721a92f0da45dc8b28f9b30ea1d575805ec82`.
`clean-entry-results.json`, `clean-entry-run-start.json`, `entry.log.gz` and the
compressed start source manifest preserve this separate check. The log emits
`MENU_INPUT_PASSED` after actual GUI clicks, note reopen, physical catalog travel
and precise saved return. This final commit adds only these evidence files.

Actual packaged Windows and Linux confirmation remains mandatory in the new CI
gates; no export acceptance is claimed from this source diagnosis.
