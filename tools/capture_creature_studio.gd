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
	for entry in [["round", "body"], ["grazer", "parts"], ["upright", "paint"], ["crawler", "test"]]:
		editor.call("_set_mode", "body")
		editor.call("_apply_body_preset", entry[0])
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
	editor.free()
	await process_frame
	print("Creature studio rendered review saved to ", output)
	quit(0)
