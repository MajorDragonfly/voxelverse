extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void: root.add_child(load("res://core/diagnostics/surface_distance_probe.gd").new())
