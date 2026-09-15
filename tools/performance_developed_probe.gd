extends SceneTree
## Standalone instrumentation around the existing real D1/D2/D3 scenario.
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.add_child(load("res://tools/performance_developed_scenario.gd").new())
