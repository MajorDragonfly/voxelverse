# Developed spherical campaign measurements

Source: `9fc27268f758486e9601868a74c46a415d9bc453`; dirty: `False`.

Godot 4.6.3-stable (official); headless; CPU: AMD EPYC 9V74 80-Core Processor.

Diagnostic recipe: conserved starting reserve, 4× production simulation and a 2 FPS far-debt exercise. These timings are not normal-speed gameplay or target-PC acceptance. Each cold restart is a separate measured process. OS file caches are not cleared. Frame intervals include the cap and measurement overhead.

| Process / cycle | Stage | Wall time ms | Frame median / p95 / p99 ms | GPU p95 ms | Baseline wall Δ ms |
|---|---|---:|---:|---:|---:|
| main / 0 | process_start | 23.07 | unavailable | unavailable | — |
| main / 0 | open_campaign | 0.15 | unavailable | unavailable | — |
| main / 0 | cold_world | 14103.62 | 16.65 / 17.82 / 13268.81 | unavailable | — |
| main / 0 | near_village | 2710.57 | 16.65 / 24.38 / 154.24 | unavailable | — |
| main / 0 | village_handoff | 5275.76 | 16.42 / 30.88 / 49.62 | unavailable | — |
| main / 0 | wood_freight | 8347.95 | 16.51 / 29.14 / 186.16 | unavailable | — |
| main / 0 | village_save_reload | 369.79 | unavailable | unavailable | — |
| main / 0 | load_paused_checkpoint | 13792.13 | 4.48 / 13690.58 / 13690.58 | unavailable | — |
| main / 0 | checkpoint_ready | 23876.58 | 16.65 / 19.05 / 49.25 | unavailable | — |
| main / 0 | build_workshops | 46460.45 | 16.71 / 21.00 / 29.01 | unavailable | — |
| main / 0 | approach_wildlife | 7882.36 | 16.49 / 39.17 / 299.31 | unavailable | — |
| main / 0 | animal_book_and_home | 3816.74 | 16.56 / 20.14 / 33.63 | unavailable | — |
| main / 0 | prepare_pen_navigation | 22864.70 | 16.72 / 19.08 / 20.82 | unavailable | — |
| main / 0 | build_pen | 35455.25 | 16.68 / 19.84 / 23.05 | unavailable | — |
| main / 0 | follow_to_pen | 3385.82 | 16.63 / 20.02 / 48.49 | unavailable | — |
| main / 0 | supply_pen | 20867.56 | 16.62 / 24.28 / 34.70 | unavailable | — |
| main / 0 | produce_and_collect_milk | 77088.48 | 16.65 / 21.76 / 29.03 | unavailable | — |
| main / 0 | block_loaded_carrier | 450.93 | 165.68 / 180.40 / 180.40 | unavailable | — |
| main / 0 | animal_returns_after_obstacle | 211.44 | unavailable | unavailable | — |
| main / 0 | animal_travel_failed_write | 117.52 | unavailable | unavailable | — |
| main / 0 | animal_travel_depart | 12215.48 | 99.18 / 11918.21 / 11918.21 | unavailable | — |
| main / 0 | animal_travel_far_work | 9995.59 | 499.34 / 637.84 / 637.84 | unavailable | — |
| main / 0 | animal_travel_pause_save | 394.49 | 16.64 / 16.90 / 16.90 | unavailable | — |
| main / 0 | animal_travel_far_restart | 0.34 | unavailable | unavailable | — |
| main / 0 | far_restart_completed | 0.50 | unavailable | unavailable | — |
| main / 0 | animal_travel_return | 35508.35 | 16.64 / 19.87 / 70.47 | unavailable | — |
| main / 0 | home_restart_completed | 0.47 | unavailable | unavailable | — |
| main / 0 | fresh_process_returned | 0.34 | unavailable | unavailable | — |
| main / 0 | load_paused_checkpoint | 13466.19 | 103.06 / 13244.86 / 13244.86 | unavailable | — |
| main / 0 | checkpoint_ready | 22568.50 | 16.66 / 20.02 / 35.47 | unavailable | — |
| main / 0 | freight_delivery | 2215.45 | 16.60 / 23.90 / 34.45 | unavailable | — |
| main / 0 | milk_delivered | 251.97 | unavailable | unavailable | — |
| cycle_0_far_restart / 0 | process_start | 2.72 | unavailable | unavailable | — |
| cycle_0_far_restart / 0 | load_paused_checkpoint | 14815.84 | 16.65 / 19.43 / 13661.64 | unavailable | — |
| cycle_0_far_restart / 0 | checkpoint_ready | 200.74 | unavailable | unavailable | — |
| cycle_0_home_restart / 0 | process_start | 3.85 | unavailable | unavailable | — |
| cycle_0_home_restart / 0 | load_paused_checkpoint | 14200.65 | 16.64 / 17.43 / 13179.64 | unavailable | — |
| cycle_0_home_restart / 0 | checkpoint_ready | 177.98 | unavailable | unavailable | — |

Child wall times (excluded from parent frame percentiles):

- cycle_0_far_restart: 16764.48 ms; exit 0.
- cycle_0_home_restart: 15830.52 ms; exit 0.

Raw samples: frames.csv and cycle_*-frames.csv. Object, village, freight and memory snapshots: capture.json and cycle_*-capture.json. Preserved isolated saves and region archives: fixture/.
