# Developed spherical campaign measurements

Source: `9fc27268f758486e9601868a74c46a415d9bc453`; dirty: `False`.

Godot 4.6.3-stable (official); headless; CPU: AMD EPYC 9V74 80-Core Processor.

Diagnostic recipe: conserved starting reserve, 4× production simulation and a 2 FPS far-debt exercise. These timings are not normal-speed gameplay or target-PC acceptance. Each cold restart is a separate measured process. OS file caches are not cleared. Frame intervals include the cap and measurement overhead.

| Process / cycle | Stage | Wall time ms | Frame median / p95 / p99 ms | GPU p95 ms | Baseline wall Δ ms |
|---|---|---:|---:|---:|---:|
| main / 0 | process_start | 21.61 | unavailable | unavailable | — |
| main / 0 | open_campaign | 0.18 | unavailable | unavailable | — |
| main / 0 | cold_world | 13720.38 | 16.66 / 17.48 / 12808.30 | unavailable | — |
| main / 0 | near_village | 2652.39 | 16.62 / 25.81 / 161.24 | unavailable | — |
| main / 0 | village_handoff | 4807.88 | 16.61 / 32.46 / 56.00 | unavailable | — |
| main / 0 | wood_freight | 8465.84 | 16.65 / 30.37 / 182.26 | unavailable | — |
| main / 0 | village_save_reload | 330.03 | unavailable | unavailable | — |
| main / 0 | load_paused_checkpoint | 14375.11 | 52.23 / 14253.01 / 14253.01 | unavailable | — |
| main / 0 | checkpoint_ready | 24154.39 | 16.66 / 19.62 / 45.17 | unavailable | — |
| main / 0 | build_workshops | 46573.47 | 16.62 / 20.00 / 25.11 | unavailable | — |
| main / 0 | approach_wildlife | 5636.42 | 16.70 / 54.11 / 322.54 | unavailable | — |
| main / 0 | animal_book_and_home | 2225.98 | 16.71 / 20.91 / 33.66 | unavailable | — |
| main / 0 | prepare_pen_navigation | 23849.93 | 16.67 / 19.45 / 22.13 | unavailable | — |
| main / 0 | build_pen | 37331.77 | 16.63 / 20.73 / 23.68 | unavailable | — |
| main / 0 | follow_to_pen | 3496.22 | 16.72 / 21.26 / 38.87 | unavailable | — |
| main / 0 | supply_pen | 20668.15 | 16.59 / 21.68 / 27.86 | unavailable | — |
| main / 0 | produce_and_collect_eggs | 77068.43 | 16.54 / 22.52 / 30.81 | unavailable | — |
| main / 0 | block_loaded_carrier | 479.48 | 185.71 / 187.07 / 187.07 | unavailable | — |
| main / 0 | animal_returns_after_obstacle | 184.67 | unavailable | unavailable | — |
| main / 0 | animal_travel_failed_write | 103.12 | unavailable | unavailable | — |
| main / 0 | animal_travel_depart | 13303.88 | 52.68 / 13002.81 / 13002.81 | unavailable | — |
| main / 0 | animal_travel_far_work | 9996.43 | 499.72 / 617.51 / 617.51 | unavailable | — |
| main / 0 | animal_travel_pause_save | 381.32 | 16.63 / 16.77 / 16.77 | unavailable | — |
| main / 0 | animal_travel_far_restart | 0.25 | unavailable | unavailable | — |
| main / 0 | far_restart_completed | 0.65 | unavailable | unavailable | — |
| main / 0 | animal_travel_return | 36362.37 | 16.62 / 20.28 / 137.89 | unavailable | — |
| main / 0 | home_restart_completed | 0.36 | unavailable | unavailable | — |
| main / 0 | fresh_process_returned | 0.25 | unavailable | unavailable | — |
| main / 0 | load_paused_checkpoint | 13714.84 | 89.22 / 13521.75 / 13521.75 | unavailable | — |
| main / 0 | checkpoint_ready | 21130.26 | 16.69 / 19.77 / 31.71 | unavailable | — |
| main / 0 | freight_delivery | 2192.67 | 16.99 / 19.96 / 35.36 | unavailable | — |
| main / 0 | eggs_delivered | 0.14 | unavailable | unavailable | — |
| main / 0 | egg_meal | 608.36 | 358.00 / 358.00 / 358.00 | unavailable | — |
| cycle_0_far_restart / 0 | process_start | 2.60 | unavailable | unavailable | — |
| cycle_0_far_restart / 0 | load_paused_checkpoint | 13646.80 | 16.68 / 17.03 / 12656.12 | unavailable | — |
| cycle_0_far_restart / 0 | checkpoint_ready | 230.25 | unavailable | unavailable | — |
| cycle_0_home_restart / 0 | process_start | 3.98 | unavailable | unavailable | — |
| cycle_0_home_restart / 0 | load_paused_checkpoint | 13705.70 | 16.64 / 17.52 / 12726.13 | unavailable | — |
| cycle_0_home_restart / 0 | checkpoint_ready | 174.06 | unavailable | unavailable | — |

Child wall times (excluded from parent frame percentiles):

- cycle_0_far_restart: 15362.93 ms; exit 0.
- cycle_0_home_restart: 15459.95 ms; exit 0.

Raw samples: frames.csv and cycle_*-frames.csv. Object, village, freight and memory snapshots: capture.json and cycle_*-capture.json. Preserved isolated saves and region archives: fixture/.
