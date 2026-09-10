extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://core/diagnostics/legacy_world.tscn")
	await scene_changed
	root.add_child(load("res://core/diagnostics/menu_input_probe.gd").new())
