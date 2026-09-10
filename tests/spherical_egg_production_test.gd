extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var probe := preload("res://core/diagnostics/spherical_gameplay_probe.gd").new()
	probe.production_kind = "eggs"
	root.add_child(probe)
