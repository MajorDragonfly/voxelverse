# R32-12 native source evidence

Final result: face-root drift and loaded-floor penetration are zero; the owner-connected turn policy removes the localized stationary 59 cm sole jump. Three forms reach every requested real state and terminate temporary reactions. Final focused tests, heading negatives, native near-view and twelve-animal rest/flight checks pass. Exact final costs/sources are in the final-results table below. Software rendering supplies no target-PC FPS acceptance.

Exact overview run: [36973684991](https://github.com/MajorDragonfly/voxelverse/actions/runs/36973684991), both jobs successful. Source commit `777f1d78b67dbdb41a4ac70acadbe93e4eb70dcc`, tree `42119e7b441632fbe5d8e948d4e9c4c4e6889707`. This diagnostic tree includes the proposed shared contact patch. It is not the feature PR tree.

All four state sequences (two sources × two renderers) record 3139 observations each. All three forms reach rest, forage/curiosity, feeding, water search/drinking, approach/greet/play/rest, perceived flight and hostile warning. Food stock and hydration really change; pause holds the body clock; the shared social session completes and pain/warning expire. No intent/state/emotion/pose is assigned by the review driver.

Before: face-root drift **0.208678 m**, loaded shore-floor penetration **0.188232 m**. After pose fix plus owner patch: **0 / 0 m**, identical states and maximum absolute foot displacement **0.592484 m per observation**. The earlier 0.222 m figure is a separate exploratory smoke sample; the paired final result supersedes it. The initial scalar included translation and turns. The additional counter-aware run localizes its worst case: six legs, stationary play_rest, actor displacement zero, 0.033333 s body clock, one process frame, and 0.592484 m sole relocation (frame 2574). A 12-actor actual-flight initialization reaches 0.810645 m in one process frame. These are a further contact-transition defect; the previous zero-penetration result is not full transition acceptance.

## Initial dense-cohort animation cost

30 warm-up iterations, 180 timed iterations. One iteration explicitly calls ExpressionDriver + Preview for twelve actors with dt=1/30 s. Physics/AI initialization and rendering are outside this CPU timer; this table describes the animation budget, not a full game frame. The initial dense cohort contains 10 herd / 2 rest at observation 10 in all four corresponding sources; its cost must not be labeled pure rest. It uses the same three forms, four of each. One serial before/after run per renderer; differences are descriptive, not a speedup claim.

| Renderer | Source | CPU p50 ms | p95 ms | p99 ms | max ms | render wait p50 / max ms | draw calls median / max |
|---|---|---:|---:|---:|---:|---:|---:|
| Compatibility | basis | 3.6305 | 3.925 | 3.994 | 4.153 | 103.032 / 106.047 | 414 / 420 |
| Compatibility | pose + owner patch | 3.6885 | 3.912 | 3.985 | 4.127 | 87.706 / 105.903 | 411 / 419 |
| Forward+ | basis | 3.9070 | 4.205 | 4.289 | 5.040 | 156.697 / 167.533 | 414 / 420 |
| Forward+ | pose + owner patch | 3.8420 | 4.128 | 4.252 | 5.316 | 155.278 / 161.171 | 411 / 419 |

Linux GitHub runners; Godot 4.6.3; llvmpipe LLVM 20.1.2, Mesa 25.2.8. 960×540 capture, fixed engine FPS 30, PNG sequence encoded at 30 fps. Render wait means awaiting frame_post_draw after the pose observation, not total GPU or game-frame duration. Actual simulation/capture cadence is distinguished by clock/physics/process counters in the additional camera report. Software rendering cannot establish target-PC FPS.

Compatibility records the exact virtual-display warning `Could not set V-Sync mode`; Forward+ has none. Every other warning, candidate ERROR, script/parse failure, source mutation or shutdown leak remains fatal. The first wrapper negative and original log are retained in `initial-warning-negative/`. Baseline penetration is an explicit expected negative, never a positive acceptance result.

Original artifacts include videos, stills, source-file manifests, logs, command/environment/source metadata, source-provenance reports and per-file SHA-256 inventories. Artifact IDs/digests live beside the extracted metrics; original focus test reports are also retained.

The additional view/flight run [36974866452](https://github.com/MajorDragonfly/voxelverse/actions/runs/36974866452) passes its declared state/penetration checks. Exact source `705bac5a8559f69fb861830b1ef399397baf2f99`, tree `e7a0f900e76ed87fb3182ca3613ebfd839dfb09b`. All twelve group actors really enter flee before physics/AI is excluded from the timed interval. The newly localized turn defect is retained above; the next owner-patch revision addresses it with a normalized planar contact-speed bound while keeping body translation/rebase and target height explicit. Its heading/rebase regression is an owner-test attachment, separate from the core face regression.

## First actual-flight group cost (old turn behavior)

| Source | CPU p50 / p95 / p99 / max ms | render wait p50 / max ms | draw median / max |
|---|---|---|---|

| original basis | 2.774 / 3.046 / 3.170 / 3.460 | 94.430 / 107.475 | 442 / 443 |
| face + recoil correction | 2.827 / 3.112 / 3.289 / 5.425 | 94.936 / 114.644 | 441 / 443 |

The corrected turn candidate is not asserted validated until its separate native/focused run completes.


## Contact-turn candidate and benchmark fixture negative

Run [36977516165](https://github.com/MajorDragonfly/voxelverse/actions/runs/36977516165), source `126b124812e86eac55bf19f10cd77012b8fbd4fb`, tree `25195aaf5e2e7893550d5a88de3740508bbda39a`: both focused three-test suites pass including the 9 heading/rebase cases; reverting only the contact owner file makes the heading regression fail. Both native state videos pass (3139 observations, face drift / floor penetration 0/0). The overall foot delta falls from 0.592484 to 0.315233 m; the new worst case is active play with 0.0819 m actor movement plus foot motion, rather than a stationary turn teleport. Each process captures one body-clock step (1/30 s) between observations; physics counts differ by 2.

The workflow then correctly fails the new strict quiet-cohort assertion: the dense fixture has 10 herd and 2 rest. This is an evidence-fixture mistake, not a loosened game assertion or a validated quiet benchmark. Original artifacts, failed group metrics and logs are retained. The first reports' rest label is corrected above, using their actual frame-10 state traces. Actual-flight costs from the separate 705 view run still describe twelve actual flee states.

The follow-up fixture places quiet animals beyond the real 13 m neighbour search radius. Its actual twelve rest states remain mandatory. Flight retains the original dense positions and mandatory twelve flee states. Expression-sampling intervals are recorded so camera-distance throttling is explicit. Only fixture/cost evidence changes in `56235292896c123d0030cab3c89ab635d03eedb1`, tree `aef86d3461ee6e06a339f9eb38d6337482282b9c`; assigned pose/contact production and the heading regression are byte-identical to 126b124. Already positive full state videos are reused at their exact 126b124 source identity; the final near-view and group fixture are separately checked.


## Final quiet/flight fixture and near-view results

Run [36980469292](https://github.com/MajorDragonfly/voxelverse/actions/runs/36980469292) succeeds in Compatibility and Forward+. Source `56235292896c123d0030cab3c89ab635d03eedb1`, tree `aef86d3461ee6e06a339f9eb38d6337482282b9c`. Both corrected focused suites and old-contact heading negatives are retained. All twelve quiet animals report rest; all twelve threat-exposed animals report flee. The Compatibility near-view repeats all 3139 real-state observations, face drift / penetration 0/0 and maximum absolute foot movement 0.315233 m during active play with body movement.

| Renderer | Actual state/source | CPU p50 ms | p95 ms | p99 ms | max ms | render wait p50 / max ms | draw median / max |
|---|---|---:|---:|---:|---:|---:|---:|
| Compatibility | 12 rest, old turn code | 2.6625 | 3.092 | 3.270 | 3.784 | 15.582 / 23.467 | 82 / 82 |
| Compatibility | 12 rest, bounded contact | 2.6885 | 3.059 | 3.203 | 4.127 | 15.242 / 18.182 | 82 / 82 |
| Compatibility | 12 flee, bounded contact | 2.3805 | 2.566 | 2.621 | 2.652 | 75.999 / 78.629 | 441 / 443 |
| Forward+ | 12 rest, old turn code | 3.7630 | 4.335 | 4.494 | 4.503 | 37.108 / 38.455 | 82 / 82 |
| Forward+ | 12 rest, bounded contact | 3.8305 | 4.390 | 4.552 | 4.620 | 37.191 / 42.059 | 82 / 82 |
| Forward+ | 12 flee, bounded contact | 3.1450 | 3.446 | 3.935 | 5.343 | 157.422 / 179.622 | 441 / 443 |

Quiet layout is wider than the original dense herd layout. Eight expression drivers sample at the near interval 0 s, four at 0.12 s; all twelve fleeing drivers sample at 0 s. Preview/foot animation advances all twelve per iteration. The quiet camera draws part of the wider cohort (82 calls); dense flight draws 441/443. This is a CPU animation budget plus observed viewport costs, not a full rendered twelve-animal campaign frame. No target-PC FPS is derived.

Assigned pose/contact/test leaves are byte-identical between 126b124's positive state videos and 5623529's positive final fixtures. Exact source identities are retained; this does not claim a complete feature or integration-tree run.

## Visual review

Three forms (2/4/6 legs, 0.65/1/1.45 scale) were inspected in overview and frontal near frames. Eye stalks/mouth bases stay on their authored skin attachments. The near frames show pupil/lid changes between curiosity, fear and warning; the mouth shows actual feeding/drinking jaw cycles and returns after the need ends. No further eye/lid/jaw defect was established. Existing eye tests cover four families, mirrored/nonuniform bounds, closure/reset/rebind; those additional catalog families were not all filmed as AI specimens.

Overview views show both participants through greet/play/rest and return to movement. The frontal tracking camera can be occluded by the partner during social closeups; those frames are retained and the overview is used for the pair review. Pause, natural session completion, pain expiry and warning termination pass on all three forms. Course/random-access posing remains direct; the owner-test attachment checks origin shifts. The contact speed policy removes the large stationary turn jump without a mesh/socket/blueprint change. It is not a world-space stance lock or comprehensive curved-terrain/slip comfort certification.

Broader eye/mouth catalogs, combined spherical-campaign play, full merge-tree/native export gates and Lars' PC remain acceptance work. #176 stays open.

All original extracted native measurements/logs/source reports are losslessly stored in `native-records.tar.xz`, preserving their relative paths. Artifact references are retained alongside the report.
