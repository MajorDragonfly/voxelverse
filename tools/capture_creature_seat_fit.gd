extends "res://tools/capture_creature_body_contract.gd"
const Fixture = preload("res://tests/creature_body_fit_test.gd")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "user://seat-fit-review"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16):
		await process_frame
	editor.set("blueprint", Fixture.design(2))
	editor.call("_set_mode", "body")
	editor.find_child("ShowBodyFittings", true, false).button_pressed = true
	editor.find_child("ShowRiderDimensions", true, false).emit_signal("pressed")
	editor.find_child("Rider_rider_scale", true, false).value = 140
	editor.call("_change_fitting", 30.0, "offset", 1)
	editor.call("_frame_creature")
	await _shot(output, "seat_floating")
	editor.call("_find_seat_proposal")
	if editor.get("_seat_proposal").is_empty():
		push_error("Capture supported-seat proposal missing")
	editor.call("_apply_seat_proposal")
	await _shot(output, "seat_supported")
	editor.call("_start_motion_review")
	for frame in range(1200):
		await process_frame
		if editor.get("_review_report").get("status") != "running":
			break
	if editor.get("_review_report").get("status") != "completed" or not editor.get("_review_report").get("complete", false):
		push_error("Capture motion review incomplete")
	var scroll: ScrollContainer = editor.get("_inspector").get_parent()
	scroll.ensure_control_visible(editor.get("_review_label"))
	await _shot(output, "seat_motion_review")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	scroll.ensure_control_visible(editor.get("_review_label"))
	await _shot(output, "seat_small_window")
	var label: Control = editor.get("_review_label")
	if label.get_global_rect().end.x > root.size.x + 1:
		push_error("Seat review exceeds the window width")
	editor.free()
	await process_frame
	print("CREATURE_SEAT_FIT_CAPTURE_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
