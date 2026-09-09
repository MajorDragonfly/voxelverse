extends SceneTree
## Real renderer screenshots of the active editor, not a UI mockup.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var output: String = "user://creature-studio-review"
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.is_empty():
		output = arguments[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1600, 900)
	var scene: PackedScene = load("res://creatures/editor/creature_editor.tscn")
	var editor: Node = scene.instantiate()
	root.add_child(editor)
	for frame in range(16):
		await process_frame
	editor.call("_change_color", Color("89bfa0"), "base_color")
	editor.call("_change_color", Color("30566c"), "accent_color")
	var detail_metrics: Array[Dictionary] = []
	for entry in [["round", "body"], ["grazer", "parts"], ["upright", "paint"], ["crawler", "test"]]:
		editor.call("_set_mode", "body")
		editor.call("_apply_body_preset", entry[0])
		detail_metrics.append(_measure_shape_edits(editor, entry[0]))
		editor.call("_set_mode", entry[1])
		if entry[1] == "parts":
			editor.call("_on_category_button_pressed", "eyes")
		if entry[1] == "test":
			editor.call("_choose_motion", "walk")
		for frame in range(20):
			await process_frame
		await RenderingServer.frame_post_draw
		var screenshot: Image = root.get_texture().get_image()
		var error: Error = screenshot.save_png(output.path_join("%s_%s.png" % entry))
		if error != OK:
			push_error("Could not save editor screenshot.")
			quit(1)
			return
	var metrics := FileAccess.open(output.path_join("detail_metrics.json"), FileAccess.WRITE)
	metrics.store_string(JSON.stringify({"presets": detail_metrics, "timing": "synchronous editor shape changes, warm part cache; excludes rendering"}, "\t") + "\n")
	metrics.close()
	editor.free()
	await process_frame
	print("Creature studio rendered review saved to ", output)
	quit(0)


func _measure_shape_edits(editor: Node, preset: String) -> Dictionary:
	var selected: int = editor.get("selected_body_segment")
	editor.set("selected_body_segment", 3)
	var original: float = editor.SpineProfile.get_segment(editor.get("blueprint"), 3)["width_scale"]
	var samples: Array[float] = []
	editor.call("_begin_gesture")
	for index in range(7):
		var start: int = Time.get_ticks_usec()
		editor.call("_change_shape", original + float(index + 1) * 0.006, "width_scale")
		samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
	editor.call("_end_gesture")
	editor.call("_undo_edit")
	editor.set("selected_body_segment", selected)
	editor.call("_refresh_preview")
	var preview: Node3D = editor.get("_preview")
	var skin: MeshInstance3D = preview.get_node("BodyV4/SculptedSkin")
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	return {"preset": preset, "body_cell_size": skin.mesh.get_meta("voxel_size"),
		"body_voxels": skin.mesh.get_meta("voxel_count"),
		"body_triangles": skin.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3,
		"edit_samples_ms": samples, "edit_median_ms": sorted[sorted.size() / 2], "edit_max_ms": sorted[-1]}
