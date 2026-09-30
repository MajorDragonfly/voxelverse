# INT30-16-COMMUNITY-GALLERY

User assignment, 30 September 2026. Branch `agent/int30-16-community-gallery-20260930`,
immutable INT30 base `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`,
base tree `5f815f478ceeabefcfc50a6388e3e4b0daa2ac45`.
Target: `agent/integration-pt19-20260930`. No main merge or public-service deployment.

## Delivery and ownership

- New `ui/blueprints/community_gallery_panel.gd`: separate service gallery with explicit
  search, cached previous/next pages, exact author/service/design/revision/byte metadata,
  request state, cancellation and import into the existing atomic local library.
- New `community_gallery_presentation.gd`: native DE/EN presentation, honest unknown
  requirements before package validation and actual required/locked parts afterwards.
- New `community_gallery_launcher.gd`: optional library opening port with restored focus
  and input ownership on return. Configuring/opening does not perform a request.
- New `tests/int30_community_gallery_test.gd`, corresponding UIDs and this evidence.
- Existing community client, service contract, loopback fixture, library storage,
  campaign/progression, package format and library panel are unchanged on the Fachbranch.

The host must provide an endpoint. The opening patch reads the explicitly configured
`community/catalog_endpoint` project setting, defaulting to the empty string, or lets
its caller set `community_catalog_endpoint` before opening the library. The gallery
button is absent for an empty/invalid endpoint. The production launcher accepts HTTPS;
only the dedicated test directly opts into numeric loopback HTTP. No default service,
accounts, uploads, startup search, polling or automatic campaign adoption is added.

Service v1 has **no requirements field**. Remote entries therefore display an explicit
unknown-requirements notice until that exact revision passes the existing client checks
and atomic library import. Existing local entries with the same identity are not taken
as proof of service content. The library/editor retains its normal adoption command and
progression checks. Package bytes/digest/revision validation and immutable revision
conflict protection remain in their existing owners.

## Integration appendices (Chat 1 / Chat 12)

1. Chat 12 applies/adapts `library-opening.patch` to its current library panel. It only
   adds an opt-in endpoint variable and three launcher construction/attachment lines.
2. Chat 1 appends the **33** records in `translations.json` to `localization/catalog.json`
   and runs `python3 tools/localization/catalog.py`. No duplicate keys.
3. Chat 1 adds `int30_community_gallery_test` **once** to the existing `blueprints` test
   contract as described in `registry.json`. No second registry.
4. `ci-opening.patch` is an optional dedicated native review job for Chat 1 to apply.
   The registered source test also runs through normal contract validation.

The Fachbranch deliberately does not edit shared catalogs, registry, project settings,
workflows or the library panel. Consequently its ordinary conservative change-plan
command currently reports `Unregistered test: int30_community_gallery_test`; this is a
pending integration dependency, not a test failure disguised as a pass. The isolated QA
checkout applies exactly the three necessary catalog/registry/library appendices. Its
normal native catalogs, source contracts and direct consumer checks are tested separately.

## Reproduction

Focused pre-integration check, using the exact appendix as native Godot translations:

```sh
python3 docs/evidence/int30-16-community-gallery/review.py \
  --godot /path/to/Godot_v4.6.3-stable_linux.x86_64 \
  --translation-appendix --output /tmp/gallery-headless-new
```

After central integration, omit `--translation-appendix` and use the normal catalog:

```sh
python3 tools/validate_godot.py --godot /path/to/godot \
  --tests int30_community_gallery_test community_catalog_client_test \
  community_blueprint_package_test creature_design_library_test \
  creature_library_favorites_test --skip-main --output /tmp/gallery-checks-new
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s '-screen 0 1920x1080x24' \
  python3 docs/evidence/int30-16-community-gallery/review.py \
  --godot /path/to/godot --render --output /tmp/gallery-render-new
```

The runner uses isolated saves/preferences, strict script/error/leak checks, a fresh
output directory, source observations and real viewport images. Headless captures are
explicitly rejected. The local managed environment requires an X server and Godot in
the same execution network namespace; Xvfb uses TCP with Unix/local transports disabled.
This is an environment launch detail, not a change to the game or external service.

## Checks and evidence

The test exercises real mouse and keyboard input against the **existing** loopback
service: opt-in configuration/no implicit contact; Enter search and encoded Unicode;
next-page cursors and cached backwards/forwards navigation; empty/malformed/unsupported
and HTTP error replies; UTF-8 query limits; offline/reconfiguration; pending download,
button disablement and cancellation; digest rejection; successful paused-menu import;
duplicate import; existing library reopen; immutable revision conflict with unchanged
bytes/favorites; next-page cancellation/retry; closing during download; a fresh offline
process; campaign progression preservation; library launcher focus/Escape return.

DE/EN × 800×600/1280×720/1920×1080 × 100/125/150% checks cover both list and detail views.
The native renderer produces **45 PNGs**: 36 matrix views, eight state views and the
library opening view. `checks/` contains fixed-source reports/logs; `renders/` contains
the actual native images and their manifest/digests. Technical scope is limited to this
feature and its direct consumers. Full integration gates, exports and Lars' target-PC
acceptance belong to the integration owner. Public service operation and accounts remain
follow-up work.
