extends "res://tools/scanner_visibility_cases.gd"
## Extend the existing shared cases with explicit tails/spike counts.
func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"samples": values.size(), "median": values[values.size() / 2], "p50": values[values.size() / 2],
		"p95": values[mini(values.size() - 1, ceili(values.size() * 0.95) - 1)],
		"p99": values[mini(values.size() - 1, ceili(values.size() * 0.99) - 1)], "max": values.back(),
		"over_33_ms": values.filter(func(value: float) -> bool: return value > 33).size(),
		"over_50_ms": values.filter(func(value: float) -> bool: return value > 50).size(),
		"over_100_ms": values.filter(func(value: float) -> bool: return value > 100).size()}
