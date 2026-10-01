extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void: root.add_child(preload("res://tools/int30_scenery_collision_probe.gd").new())
