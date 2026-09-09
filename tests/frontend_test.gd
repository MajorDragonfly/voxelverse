extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Reproduce the rendered exit race deterministically: a new chunk queues
	# its first LOD update, then leaves the tree before deferred calls drain.
	var chunk := Node3D.new()
	root.add_child(chunk)
	chunk.add_child(load("res://world/streaming/chunk_lod_controller_v7.gd").new())
	root.remove_child(chunk)
	await process_frame
	chunk.free()
	change_scene_to_file("res://ui/frontend/main_menu.tscn")
	await scene_changed
	root.add_child(load("res://core/diagnostics/frontend_probe.gd").new())
