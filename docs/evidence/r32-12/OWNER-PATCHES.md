# R32-12 owner attachments

R32-01 owns the shared SculptMotion/preview integration. Apply the contact patch to the fixed R32 basis (the feature does not directly edit that shared production file). Apply the turn test attachment after the feature face regression has been integrated. No registry append is needed: it extends the existing registered continuity test.

```bash
git apply docs/evidence/r32-12/owner-patches/recoil-contact.patch
git apply docs/evidence/r32-12/owner-patches/turn-continuity-test.patch
```

Both apply checks succeed on the clean feature source. `recoil-contact.patch` replaces the earlier recoil-only proposal: it includes physical/yaw contact orientation, bounded planar turn relocation, cache reset and direct random-access course sampling. Physical translation/origin shifts and exact normal-axis target heights are not delayed. Cosmetic contact speed is capped at 4.8 normalized metres/second; the cap is a continuity policy inherited from the existing 16 cm/30 Hz test budget, not a target-PC requirement or a full stance-lock solution.

The test attachment exercises actual Preview → Motion → LimbRig soles on the SpeciesVisual/CharacterBody frame, three shapes/scales/leg counts, 30/60/144 Hz, a sudden heading change and an origin shift. The original heading implementation is a required negative; the connected candidate must pass this plus the original continuity/eye/expression checks.

| Patch | SHA-256 |
|---|---|
| `recoil-contact.patch` | 245886c2d33aa2df0f78251384dbe0ce48c6431e86eac5d056755a89324cb09e |
| `turn-continuity-test.patch` | 0f4f8405e5d4dab65d64273bac9f7c28566b6903591ca2f80ea67377bff1945c |

The native contact-transition follow-up source is `126b124812e86eac55bf19f10cd77012b8fbd4fb`, tree `25195aaf5e2e7893550d5a88de3740508bbda39a`; state videos and focused/negative checks pass; the benchmark fixture negative is preserved. Final quiet/flight and near-view results pass at `56235292896c123d0030cab3c89ab635d03eedb1` / tree `aef86d3461ee6e06a339f9eb38d6337482282b9c`, with byte-identical assigned production/test leaves. Results are in native/REPORT.md. Its diagnostic branch directly applies both attachments; that branch is for evidence and must not be merged as the feature.
