# Final QA source bundle and restoration

This is a diagnostic source-retention package. It is not a product merge or an
acceptance claim. R33-02 completed as a measured, rejected candidate: lower
movement percentiles did not resolve the original cold-return and readiness
regressions. R33-08 preserves the original Vulkan failure, including the
360-second timeout and 5/25 near patches; no product cause or exact engine-source
binding was established. Source closure does not change either disposition.
Camera refs retain candidates and historical sources without implying their
acceptance. The closure branch is for QA evidence only.

The bundle is `qa-final-source.bundle`, 224,988 bytes, SHA256
`214978a6b3a7e9e7652d4f4036270f70a7e7b1abff3888ce07348a64ff0c64be`.
It retains 26 exact commit/tree bindings in `qa-final-source-used-refs.json`,
including all original nine tips. No full worktree copies are included. The
bundle is incremental, so its four actual header prerequisites must already be
available in the restoration object store.

| Actual bundle-header prerequisite | Existing source that supplies it |
| --- | --- |
| `d183867556db574b26199b817711166b66611282` | Ancestor of original performance PR #272 head `29b7557ffa3fa1ccd665b664af5b69851c071ef9` |
| `2ec14bbd2e1dbc01e7f50f5e9b41c8cae35c8132` | Original UI source with the same commit; also ancestor of historical remote `bbfa2649389397651669c63b094121f26ebc8643` |
| `18559dda756ac9254f871ee9ad60c7bc61f240ff` | Original Forward PR #273 head with the same commit |
| `9ecc8a7bb4ca44c26d162191c61650147b15011c` | Historical main with the same commit; also ancestor of historical remote `bbfa2649389397651669c63b094121f26ebc8643` |

These mappings preserve the independently verified original prerequisite
mapping in the earlier source-bundle evidence. Original #272 head
`29b7557ffa3fa1ccd665b664af5b69851c071ef9` and #273 head
`18559dda756ac9254f871ee9ad60c7bc61f240ff` remain protected historical heads;
closing their measured work does not replace those heads with a candidate.
The old intended exclusion `29b7557f` is not the actual prerequisite:
`d1838675` is. Verification uses the actual header.

To restore elsewhere, make a new bare repository, obtain the four prerequisite
histories from the existing Voxelverse repository, and verify before importing.
The following commands are instructions only; they were not run as part of the
publication preparation. They create no game checkout and invoke no engine:

```sh
printf '%s  %s\n' '214978a6b3a7e9e7652d4f4036270f70a7e7b1abff3888ce07348a64ff0c64be' 'qa-final-source.bundle' | sha256sum --check
git init --bare restore.git
git --git-dir=restore.git fetch https://github.com/MajorDragonfly/voxelverse.git \
  29b7557ffa3fa1ccd665b664af5b69851c071ef9 \
  2ec14bbd2e1dbc01e7f50f5e9b41c8cae35c8132 \
  18559dda756ac9254f871ee9ad60c7bc61f240ff \
  9ecc8a7bb4ca44c26d162191c61650147b15011c
git --git-dir=restore.git cat-file -e d183867556db574b26199b817711166b66611282^{commit}
git --git-dir=restore.git cat-file -e 2ec14bbd2e1dbc01e7f50f5e9b41c8cae35c8132^{commit}
git --git-dir=restore.git cat-file -e 18559dda756ac9254f871ee9ad60c7bc61f240ff^{commit}
git --git-dir=restore.git cat-file -e 9ecc8a7bb4ca44c26d162191c61650147b15011c^{commit}
git --git-dir=restore.git bundle verify qa-final-source.bundle
git --git-dir=restore.git fetch ./qa-final-source.bundle \
  'refs/heads/qa-source/*:refs/heads/qa-source/*'
```

Fetching a current main alone is not a documented substitute for supplying the
four exact prerequisite histories. In an offline restore, an already verified
object store containing those histories may be supplied as an alternate.

The actual QA export and independent fresh bare restore ran under Root #137
START `2026-10-08T21:22:37.563Z` and completed with Exit 0 in 1.903 seconds.
The actual host START was `2026-10-08T21:24:36.175662Z`, END
`2026-10-08T21:24:38.078238Z`.
Both heavy locks were held throughout. Actual END reports active Godot zero,
foreign Godot false, unchanged ref configuration, and both locks released and
nonblocking free. `qa-final-source-actual-end.json` records these observations.
It preserves the actual host START/END events together with the post-release
receipt; configuration stability is recorded in the host END event.

The independent strict check in `qa-final-source-strict-closure.json` compared
the exported and restored object sets, subtracted only the actual header's
prerequisite closure, and counted newly imported physical `verify-pack` IDs.
Alternates did not count as imported objects. There were 22,325 wanted objects,
21,891 objects in the actual prerequisite closure, 434 required new objects and
502 physically imported objects. Missing required objects: **0**. All 3,988
unavailable historical boundaries remained covered by that prerequisite
closure. All 26 tip commits were physically imported and all 26 expected trees
matched. The original closure result remains recorded alongside the new one.

`qa-final-source-bundle-export.py` and `qa-final-source-bundle-verify.py` are the
exact scripts used for this result. The used ref configuration records the
original local paths, a6 host-guard checksum and Root slot; these are historical
execution bindings, not portable path assumptions. Any new guarded export
requires its own explicit Root slot/GO and local configuration. The scripts
refuse an unguarded strict-verifier entry point, a reused restore directory,
unexpected header prerequisites, missing physical objects or any tip/tree
mismatch. Late host or lock failures preserve a negative final status.

This publication is based on QA commit
`60bb98f1806a6a7f1c10681a5cc046a8cdceb6c7`, tree
`8c680027d0f395407ae132bed2373b4c3afb180d`. The previously published R33-02 and
R33-08 reports remain unchanged by this source-bundle addition.
