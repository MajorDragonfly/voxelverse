extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.add_child(preload("res://tools/review_r32_05_world_probe.gd").new())
