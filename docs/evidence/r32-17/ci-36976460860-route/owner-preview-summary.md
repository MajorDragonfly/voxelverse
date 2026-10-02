# Movement route

Wall-clock frames; headless/software runs are not target-PC acceptance.
Scene-lifetime maxima identify candidates, not same-frame causality.

| Cycle | Stage | Frames | p50 | p95 | p99 | Max | >33 ms | >50 ms | >100 ms |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | walk_outward | 330 | 16.7 | 85.5 | 145.1 | 212.8 | 28 | 27 | 9 |
| 0 | walk_return | 434 | 16.6 | 18.5 | 20.8 | 23.1 | 0 | 0 | 0 |
| 1 | walk_outward | 392 | 16.6 | 22.0 | 117.3 | 174.4 | 10 | 10 | 5 |
| 1 | walk_return | 434 | 16.6 | 19.2 | 21.6 | 23.1 | 0 | 0 | 0 |

Comparison uses the same recipe, host, renderer, start address and planet; inspect the raw frames and fixture before attributing a change.

0 walk_outward: p95 80.0 → 85.5 ms; p99 144.9 → 145.1 ms; max 224.7 → 212.8 ms; >100 ms 9 → 9.
0 walk_return: p95 19.7 → 18.5 ms; p99 21.3 → 20.8 ms; max 23.9 → 23.1 ms; >100 ms 0 → 0.
1 walk_outward: p95 21.9 → 22.0 ms; p99 107.2 → 117.3 ms; max 177.8 → 174.4 ms; >100 ms 5 → 5.
1 walk_return: p95 18.7 → 19.2 ms; p99 21.1 → 21.6 ms; max 22.8 → 23.1 ms; >100 ms 0 → 0.
