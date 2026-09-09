extends SceneTree
## Capture the shipped workshop and an external payload on a tilted body frame.
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "user://body-contract-review"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16):
		await process_frame
	var blueprint: Dictionary = Assembly.create_default()
	Assembly.BaseBlueprint.add_part(blueprint, "legs_hoof")
	Anatomy.reset_all_anchors(blueprint)
	for part: Dictionary in blueprint["parts"]:
		if part["category"] == "legs":
			part["end_part_id"] = "feet_hooves"
			part["scale"] = 0.82
	editor.set("blueprint", blueprint)
	editor.call("_set_mode", "body")
	editor.call("_apply_body_preset", "grazer")
	editor.find_child("ShowBodyFittings", true, false).button_pressed = true
	editor.call("_frame_creature")
	await _shot(output, "body_fittings")
	editor.call("_set_mode", "test")
	editor.call("_choose_course", "slope")
	editor.call("_choose_motion", "walk")
	var preview: Node3D = editor.get("_preview")
	preview.set_process(false)
	preview.get("_motion").call("sample", "walk", 1.4)
	await _shot(output, "fittings_slope")
	editor.call("_set_mode", "body")
	Assembly.BaseBlueprint.add_part(editor.get("blueprint"), "legs_spider")
	Anatomy.reset_all_anchors(editor.get("blueprint"))
	editor.call("_refresh_all")
	editor.call("_set_mode", "test")
	editor.call("_choose_course", "flat")
	editor.call("_choose_motion", "idle")
	preview.set_process(false)
	preview.get("_motion").call("sample", "idle", 0.0)
	editor.call("_frame_creature")
	await _shot(output, "six_leg_fittings")
	editor.free()
	await process_frame
	print("CREATURE_BODY_CAPTURE_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)


func _shot(output: String, label: String) -> void:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	if error != OK:
		push_error("Could not save body-contract screenshot: " + label)
