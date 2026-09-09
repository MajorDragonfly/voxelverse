extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://ui/frontend/main_menu.tscn")
	await scene_changed
	root.add_child(load("res://core/diagnostics/frontend_probe.gd").new())
