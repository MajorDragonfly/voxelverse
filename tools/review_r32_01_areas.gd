extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void: root.add_child(load("res://tools/review_r32_01_area_probe.gd").new())
