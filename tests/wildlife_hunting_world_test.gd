extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void: root.add_child(load("res://core/diagnostics/wildlife_hunting_world_probe.gd").new())
