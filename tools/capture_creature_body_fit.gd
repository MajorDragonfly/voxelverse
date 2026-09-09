extends "res://tools/capture_creature_body_contract.gd"
const Fixture = preload("res://tests/creature_body_fit_test.gd")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "user://body-fit-review"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16):
		await process_frame
	editor.set("blueprint", Fixture.design(3))
	editor.call("_set_mode", "body")
	editor.find_child("ShowBodyFittings", true, false).button_pressed = true
	editor.call("_frame_creature")
	await _shot(output, "fit_findings")
	var report: Dictionary = editor.get("_fit_report").duplicate(true)
	var seen: Dictionary = {}
	for leg: Dictionary in report["stretched_legs"]:
		if not seen.has(leg["part_uid"]):
			seen[leg["part_uid"]] = true
			if not editor.call("_fit_leg_lengths", leg["part_uid"]):
				push_error("Capture leg correction rejected")
	for id in Fixture.Fit.Contract.Data.IDS:
		editor.set("_fitting_id", id)
		editor.call("_find_fit_proposal")
		if editor.get("_fit_proposal").is_empty():
			push_error("Capture fitting proposal missing: " + id)
		editor.call("_apply_fit_proposal")
	editor.set("_fitting_id", "saddle.primary")
	editor.find_child("BodySocketChoice", true, false).select(0)
	editor.call("_refresh_attachment_controls")
	await _shot(output, "fit_corrected")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await _shot(output, "fit_small_window")
	var status: Control = editor.find_child("BodyFitStatus", true, false)
	if status.get_global_rect().end.x > root.size.x + 1:
		push_error("Fit status exceeds the window width")
	editor.call("_set_mode", "test")
	editor.call("_choose_course", "slope")
	editor.call("_choose_motion", "walk")
	var preview: Node3D = editor.get("_preview")
	preview.set_process(false)
	preview.get("_motion").call("sample", "walk", 1.4)
	editor.call("_check_fit_now")
	await _shot(output, "fit_motion_sample")
	editor.free()
	await process_frame
	print("CREATURE_BODY_FIT_CAPTURE_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
