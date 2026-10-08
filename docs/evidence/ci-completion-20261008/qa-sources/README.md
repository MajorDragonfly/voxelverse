# Restorable QA source snapshots

`qa-source.bundle` contains the exact nine local QA/runtime commit heads listed
in `qa-source-bindings.json`, advertised as `refs/heads/qa-source/*`.
The bundle is a bounded thin Git pack, not a full repository or checkout copy.

Before restoring, fetch all five `excluded_prerequisites` from the existing
MajorDragonfly/voxelverse remote repository. These existing commits supply the
required old history and objects. The JSON maps each of Git's actual four header
prerequisites to the full existing remote source commits which contain it.

```text
git bundle verify qa-source.bundle
git fetch qa-source.bundle refs/heads/qa-source/scroll-product:refs/heads/qa-restored/scroll-product
```

The same command can restore any other named ref. No engine run or validation is
implied by restoration. Runtime/QA trees and Git identities are pinned separately
from their reports.

Verification unpacked the bundle into a separate bare Git. Its physical pack
contains all nine advertised tip commits. Strict closure was checked independently:
22,148 reachable object IDs from the wanted heads minus the 21,891 IDs reachable
from only the four actual header prerequisites leaves 257 required new objects.
All 257 are physically present in the imported pack (318 objects including thin
pack bases); the missing-object set is empty. The shared 3,988 unavailable historic
objects are all covered by those actual prerequisites. A bounded rev-list using
only the actual header prerequisites independently returns the same 257 IDs.
The verification does not count alternate-store objects as imported objects.

The current remote commit `bbfa2649389397651669c63b094121f26ebc8643` was excluded
during bundling and is not an actual header prerequisite. The strict object-set
check proves that exclusion leaves no source object missing in this exact bundle.
All nine restored tree SHAs matched the bindings; bundle SHA256 and size are in
the JSON.

This evidence branch adds source restoration and reports to root runtime tree
`73f8d79cf941a8d291f759a4989d23b0c50db4b8`. It does not mark source, native export,
target-PC performance or Forward+ hardware acceptance as passed.
