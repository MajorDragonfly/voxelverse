extends SceneTree
func _initialize() -> void:
	root.add_child(load("res://tools/review_r32_10_campaign_probe.gd").new())
