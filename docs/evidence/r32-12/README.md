# R32-12 · PT17-10 / #176

Fixed basis: `2a738a4891a8de11d682c469833ade4dc9b01dfb`, tree `f2bda4f815df1c73b9d740ca5282917523faf618`.
Godot `4.6.3.stable.official.7d41c59c4`. This is a feature/owner-patch delivery; #176 remains open.

The sculpted body has a continuous skin. Rotating eyes and mouths around a common face centroid moved their root attachments away from that skin. The existing Continuity test now covers nine contexts on three authored forms with 2/4/6 legs at visual scales 0.65/1/1.45. Before the production fix, maximum face-root displacement was 0.050001 / 0.102796 / 0.201520 metres. Keeping the roots on their authored surface gives zero displacement; orientation, jaw/pupil articulation and the legacy non-sculpted face pivot remain active. No blueprint, mesh, collider, socket ID, spawn or cache changes.

`creature_expression_pose.gd` and the existing `creature_animation_continuity_test.gd` are the only changed assigned production/test leaves. No new registry entry is needed. ExpressionDriver stays with R32-10 per Lars' direct R32-12 instruction; SocialPlayBrain stays with R32-11. EyeExpression and locomotion animator code are unchanged after checks.

## Shared contact attachment

`owner-patches/recoil-contact.patch` is an explicit R32-01 attachment for `creature_sculpt_motion.gd`; the owner file is unchanged on this feature branch. External damage tilts `SpeciesVisual` by 11 degrees, and the old motion sampler tilted its contact reference too. A real six-leg flight/damage sequence reproduced up to 22.2 cm penetration of the loaded flat shore floor. The patch uses physical actor orientation and visual yaw for contact targets while the visible body recoils. The controlled post-animation sequence passes with no floor penetration. Regular workshop/course parent transforms retain their existing path. This patch has not been centrally accepted or integrated.

## Functional evidence

`functional/` contains original logs, source reports and file hashes. The complete original source-file manifests are losslessly packed in `functional/source-manifests.tar.xz`; unpack there to restore the report paths. The initial three basis tests pass; the added face regression fails before the fix; all three focused tests pass after the assigned fix and in a separate owner-patch checkout. The tests cover eyes in four families, mirrored/nonuniform geometry, blink/gaze/reset/rebuild, 30/60/144 Hz gait transitions, radial floors, origin shifts, real public social/damage calls, pause and process restart. They are scoped checks, not the 267-test integration suite.

The controlled live-state sampler uses real wildlife scenes, normal AI sensing, finite berry stock, loaded dry shore/submerged bed validation, hydration, one shared naturally selected SocialSession, player threat perception, external damage and simulation pause. It never assigns intent, AI state, emotion or expression pose. Three forms each reach rest, forage, eat, seek_water, drink, play_approach/greet/play/rest and flee; social/pain reactions end and the paused body clock stays fixed. The final sampler additionally observes a real predator warning and target loss; its native evidence is pending at this documentation commit. The first fixture accidentally reused the same consumed food identity; only the fixture was corrected to independent food keys. Early contact observations before idle animation callbacks were discarded as a measurement boundary; final samples occur after callbacks.

Original `functional/ownerpatch-live` is from local validation commit `b989b9b`, tree reported by that checkout, with three forms / 2515 samples; zero face-root drift and floor penetration. Peak absolute foot displacement is 0.592483 m per observation including travel/turns, and is retained as a limit: it does not prove absence of stance sliding or visual comfort. Do not claim comprehensive foot-contact acceptance from this scalar.

## Native videos and costs

The separate diagnostic PR/runner applies the owner patch solely for evidence. `owner-patches/animation-evidence-workflow.yml` is the CI attachment, not an active workflow on this feature branch. It creates before/after native videos and stills using the identical sampler, fixed seed 15838, 960×540, fixed 30 Hz, same camera recipe, fixture light and renderer. Compatibility/Forward+ use separate runners. The original gameplay basis is fetched once and remains unmodified except the identical review sampler/UID. Baseline floor penetration is an expected **negative**, not acceptance; candidate failures are fatal. Each process has isolated userdata, exact source-file manifests, raw log, measurements and hashes.

The twelve-actor comparison times only ExpressionDriver plus Preview animation after 30 warm-up frames, for 180 observations. CPU p50/p95/p99/max and render wait/draw counts are separate. Physics/AI, full spherical campaign frame times and target-PC performance are outside this measurement. Software GPU values cannot establish Lars' PC's FPS. The initial Compatibility candidate completed 2515 samples with no game failures; its wrapper stopped at the exact unsupported-VSync warning from Xvfb/llvmpipe. The runner now retains that one host warning in summary metadata and rejects every other warning and every candidate ERROR. Native evidence is not yet asserted successful here; final report/PR will link the actual run and artifacts.

## Remaining acceptance

R32-01 must review/integrate the contact attachment and run full integration/native export gates. The combined spherical-campaign sight review, stance sliding/turn comfort, all body/eye/mouth views and groups on Lars' PC remain open. This delivery does not close #176 or tick #166.
