# M6-ORDER-LATENCY-FOLLOWUP: save validation pass

The first M6 delivery preserved an atomic save before acknowledging each tribal
order. Its 100-command sample showed the synchronous save as the largest local
stage. This follow-up removes one repeated full validation of the save tree:
`SaveGameService` still serializes the snapshot, parses the exact bytes that a
loader will read, and validates that readback before history, backup or live
file replacement. The atomic writer still checks the JSON object, verifies its
staged bytes and retains the prior valid backup. The controller still rolls an
order back when the save fails.

## Local measurement

Godot 4.6.3 headless in the development container, on main
`0e0a1cda0d645f872cecd42881b3f6e53b3ba34e` and this branch, alternating
three fresh processes per version. Each process ran
`res://tests/tribal_order_latency_test.gd`: 100 mixed wood, stone, food, wait and
resume orders, alternating one resident/all three residents, including disk
verification after each acknowledged order. Values below are milliseconds.

| Pair | Main order median / p95 | Changed order median / p95 | Main save median / p95 | Changed save median / p95 |
| --- | ---: | ---: | ---: | ---: |
| 1 | 8.668 / 13.328 | 7.130 / 11.143 | 6.373 / 9.148 | 5.310 / 7.446 |
| 2 | 6.922 / 9.621 | 6.469 / 8.174 | 5.319 / 7.127 | 4.834 / 6.013 |
| 3 | 7.736 / 11.465 | 6.681 / 9.881 | 5.787 / 8.944 | 4.951 / 7.303 |

The removed validation stage took a median 0.583–0.726 ms on main. All three
paired runs improved the order and save medians, but absolute times varied
between processes. These headless measurements do not establish the target PC
p95 feedback ≤100 ms, warm assignment ≤250 ms or absence of >50 ms command
frames in a rendered, grown village. Those acceptance items remain open.

## Verification

`tribal_order_latency_test` checks 100 durable receipts, unchanged visual
rebuild count on pure assignments, failed-write rollback with cargo, reload and
compact command UI. `coordinate_persistence_test` checks exact bytes, atomic
staging and backup failure paths. `save_participants_test`, `save_slots_test`
and `tribal_age_growth_test` cover save contracts, slots and six-resident
growth. These are functional checks, not a hardware performance gate.
