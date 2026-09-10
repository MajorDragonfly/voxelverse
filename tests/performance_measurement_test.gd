extends SceneTree
const Stats = preload("res://tools/performance_stats.gd")
func _initialize() -> void:
	var failures: Array[String] = []
	# Evidence must distinguish a missing instrument from a genuine zero sample.
	if Stats.distribution([]) != null: failures.append("Unavailable sample was reported as a timing.")
	var zero: Dictionary = Stats.distribution([0.0])
	if zero.count != 1 or zero.max != 0.0: failures.append("Measured zero was discarded.")
	var values: Array = [4.0, 2.0, 1.0, 3.0]
	var result: Dictionary = Stats.distribution(values)
	if result.median != 2.5 or result.p95 != 4.0 or values != [4.0, 2.0, 1.0, 3.0]: failures.append("Median changed samples or rounded the middle.")
	values.clear()
	for i in range(1, 101): values.append(float(i))
	result = Stats.distribution(values)
	if result.median != 50.5 or result.p95 != 95.0 or result.p99 != 99.0: failures.append("Nearest-rank tail timing is off by one.")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PERFORMANCE_MEASUREMENT_PASSED")
	quit(0 if failures.is_empty() else 1)
