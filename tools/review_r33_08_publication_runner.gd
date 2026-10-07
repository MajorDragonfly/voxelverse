extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void: root.add_child(preload("res://tools/review_r33_08_publication_probe.gd").new())
