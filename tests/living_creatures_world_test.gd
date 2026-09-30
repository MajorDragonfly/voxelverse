extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var checks: RefCounted = load("res://tests/fixtures/campaign_population_streaming_checks.gd").new()
	var failures: Array[String] = checks.run(self)
	if not failures.is_empty():
		for failure in failures: push_error(failure)
		quit(1)
		return
	root.add_child(load("res://core/diagnostics/living_creatures_probe.gd").new())
