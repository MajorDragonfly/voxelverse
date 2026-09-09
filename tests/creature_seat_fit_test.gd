extends SceneTree
const Fixture = preload("res://tests/creature_body_fit_test.gd")
const Assembly = Fixture.Assembly
const Fit = Fixture.Fit
const Preview = Fixture.Preview
const Rider = Fit.Shapes.Rider
const Support = preload("res://creatures/runtime/creature_saddle_support.gd")
const Review = preload("res://creatures/runtime/creature_fit_motion_review.gd")
const SAVE: String = "user://seat_fit_restart.json"
var failures: Array[String] = []
var evidence: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--seat-restart" in OS.get_cmdline_user_args():
		var saved: Dictionary = Assembly.load_from_file(SAVE)
		_expect(is_equal_approx(float(Rider.read(saved)["rider_scale"]), 1.4), "Saved rider size lost")
		_check_seated(_preview(saved))
	else:
		_check_data()
		_check_support()
		for pairs in range(1, 4):
			await _check_motion(pairs)
		await _check_editor()
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/creature_seat_fit_test.gd", "--", "--seat-restart"], output, true)
		_expect(status == 0 and str(output).contains("CREATURE_SEAT_FIT_PASSED") and not str(output).contains("SCRIPT ERROR"), "Restart check failed: " + str(output))
	for failure in failures:
		push_error(failure)
	print(("CREATURE_SEAT_FIT_PASSED " if failures.is_empty() else "SEAT_FAILURE_EVIDENCE ") + JSON.stringify(evidence))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _preview(blueprint: Dictionary) -> Preview:
	var preview := Preview.new()
	root.add_child(preview)
	preview.show_body_attachments = true
	preview.set_editor_state(blueprint, -1, -1, false)
	return preview


func _check_data() -> void:
	var blueprint: Dictionary = Fixture.design(2)
	var before: String = var_to_str(blueprint)
	_expect(Rider.read(blueprint) == Rider.DEFAULT and before == var_to_str(blueprint), "Legacy read mutates the design")
	for value in [{}, {"schema": 99}, null]:
		blueprint["assembly"][Fit.Contract.Data.KEY][Rider.KEY] = value
		before = var_to_str(blueprint)
		_expect(not Rider.validate(Rider.read(blueprint)).is_empty(), "Invalid profile accepted")
		_expect(not Rider.store_in(blueprint, Rider.DEFAULT) and before == var_to_str(blueprint), "Future profile silently replaced")
	for bad in [NAN, INF, "large", 0.0, 9.0]:
		var profile: Dictionary = Rider.DEFAULT.duplicate(true)
		profile["rider_scale"] = bad
		_expect(not Rider.validate(profile).is_empty(), "Invalid rider dimension accepted")
	blueprint = Fixture.design(2)
	var profile: Dictionary = Rider.DEFAULT.duplicate(true)
	profile["rider_scale"] = 1.4
	profile["leg_spacing"] = 0.9
	_expect(Rider.store_in(blueprint, profile), "Valid profile not stored")
	var preview := _preview(blueprint)
	var shapes: Array = Fit.Shapes.boxes("saddle.primary", profile)
	for shape: Dictionary in shapes:
		var guide: MeshInstance3D = preview.get_node("BodyV4/BodyAttachments/saddle_primary/FitGuide/" + shape["id"])
		_expect(guide.mesh.size.is_equal_approx(shape["bounds"].size) and guide.position.is_equal_approx(shape["bounds"].get_center()), "Displayed dimensions differ from collision query")
	_expect(Fit.inspect(preview)["profile"] == Fit.Shapes.ADJUSTABLE_PROFILE, "Custom rider reported as fixed reference")
	preview.free()


func _check_support() -> void:
	var cells: Dictionary = {}
	for x in range(-12, 12):
		for z in range(-12, 12):
			cells[Vector3i(x, -1, z)] = Color.WHITE
	var slab: ArrayMesh = Fixture.Voxels.from_cells(cells, 0.035, true)
	var pose := Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 0))
	var report: Dictionary = Support.inspect_socket(slab, pose, 1, Rider.DEFAULT)
	_expect(report["supported"] and report["rider_seated"] and report["supported_samples"] == 9, "Flat saddle support missed")
	pose.origin.y = 0.2
	_expect(not Support.inspect_socket(slab, pose, 1, Rider.DEFAULT)["supported"], "Floating saddle accepted")
	pose.origin.y = -0.02
	_expect(not Support.inspect_socket(slab, pose, 1, Rider.DEFAULT)["supported"], "Buried underside accepted")
	pose.origin = Vector3(0.7, 0.04, 0)
	_expect(not Support.inspect_socket(slab, pose, 1, Rider.DEFAULT)["supported"], "Saddle outside the back accepted")
	pose = Transform3D(Basis(Vector3.FORWARD, PI / 3), Vector3(0, 0.04, 0))
	_expect(not Support.inspect_socket(slab, pose, 1, Rider.DEFAULT)["supported"], "Excessively tilted saddle accepted")
	for size in [0.5, 1.0, 1.8]:
		var profile: Dictionary = Rider.DEFAULT.duplicate(true)
		profile["rider_scale"] = size
		profile["seat_height"] = 0.12 + 0.08 * size
		_expect(Support.inspect_socket(slab, Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 0)), 1, profile)["rider_seated"], "Scaled pelvis misses saddle")


func _fit_seat(preview: Preview) -> bool:
	var proposal: Dictionary = Support.proposal(preview)
	_expect(not proposal.is_empty(), "No supported seat proposal for reference anatomy")
	if proposal.is_empty():
		return false
	var blueprint: Dictionary = preview.blueprint
	Rider.store_in(blueprint, proposal["rider_profile"])
	Fit.Contract.Data.set_socket(blueprint, "saddle.primary", proposal["socket"])
	preview.set_editor_state(blueprint, -1, -1, false)
	var support: Dictionary = Support.inspect(blueprint)
	_expect(support["supported"] and support["rider_seated"], "Seat proposal fails support after applying")
	return true


func _check_seated(preview: Preview) -> void:
	var support: Dictionary = Support.inspect(preview.blueprint)
	_expect(support["supported"] and support["rider_seated"], "Loaded saddle/pelvis no longer supported")
	for hit: Dictionary in Fit.inspect(preview)["collisions"]:
		_expect(hit["socket_id"] != "saddle.primary", "Supported rider still collides")
	preview.free()


func _check_motion(pairs: int) -> void:
	var preview := _preview(Fixture.design(pairs))
	_fit_seat(preview)
	for id in ["harness.left", "harness.right"]:
		var proposal: Dictionary = Fit.socket_proposal(preview, id)
		_expect(not proposal.is_empty(), "Harness clearance unavailable for motion fixture")
		if not proposal.is_empty():
			Fit.Contract.Data.set_socket(preview.blueprint, id, proposal["socket"])
			preview.set_editor_state(preview.blueprint, -1, -1, false)
	var before: String = var_to_str(preview.blueprint)
	preview.set_motion("run")
	preview.set_process(false)
	preview.get("_motion").sample("run", 0.8)
	var pose: Transform3D = preview.transform
	var review := Review.new()
	review.start(root, preview.blueprint)
	for collider in review.get("_lab").find_children("*", "CollisionObject3D", true, false):
		_expect(collider.collision_layer == 0 and not collider.input_ray_pickable, "Review copy participates in editor picking/physics")
	if pairs == 2:
		# This small arm-end voxel enters the rider later in the actual arm
		# swing. Static body/trace contacts must not hide the additional hit.
		var trial: Preview = review.get("_preview")
		var socket: Transform3D = trial.body_socket("saddle.primary")["body_transform"]
		var probe := Node3D.new()
		probe.set_meta("creature_part_uid", "motion_probe")
		probe.set_meta("creature_part_category", "arms")
		probe.set_meta("creature_part_side", 1.0)
		probe.position = socket.origin + Vector3(0, float(Rider.read(trial.blueprint)["seat_height"]) - 0.4, 0)
		trial.add_child(probe)
		var piece := MeshInstance3D.new()
		piece.mesh = Fixture.Voxels.primitive(Vector3.ONE * 0.06)
		piece.position = Vector3(0, 0.6, 0.15)
		probe.add_child(piece)
		trial.set_motion("walk")
		trial.set_process(false)
	while not review.step(64):
		await process_frame
	var report: Dictionary = review.report
	_expect(report["complete"] and report["scenarios"].size() == 6, "Motion suite incomplete")
	_expect(report["coverage"] == "sampled_poses" and not report["continuous_clearance"], "Finite sampling falsely claims continuous clearance")
	_expect(before == var_to_str(preview.blueprint) and pose == preview.transform and not preview.is_processing(), "Review changed source design/playback")
	_expect(review.get("_lab") == null, "Completed review leaves live geometry")
	for scenario: Dictionary in report["scenarios"]:
		_expect(scenario["sample_count"] >= 33 and scenario["max_foot_penetration"] <= 0.002, "Motion range/contact evidence invalid")
		if pairs != 2:
			_expect(scenario["collision_samples"] == 0, "Corrected reference fittings collide during motion")
	if pairs == 2:
		var found_later: bool = false
		for finding: Dictionary in report["scenarios"][0]["findings"]:
			if finding["collision"]["part_uid"] == "motion_probe" and float(finding["time"]) > 0.0:
				found_later = true
		_expect(found_later, "Collision appearing after motion starts was missed")
		_expect(float(report["scenarios"][0]["first_collision"].get("time", 0)) > 0.0, "Dynamic collision fixture already collides at rest")
	evidence[str(pairs * 2) + "_legs"] = report
	preview.free()


func _check_editor() -> void:
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	var design: Dictionary = Fixture.design(2)
	preload("res://creatures/editor/creature_attachment_normalizer.gd").normalize(design)
	editor.set("blueprint", design)
	editor.call("_set_mode", "body")
	editor.find_child("ShowBodyFittings", true, false).button_pressed = true
	editor.find_child("ShowRiderDimensions", true, false).emit_signal("pressed")
	editor.find_child("Rider_rider_scale", true, false).value = 140
	_expect(is_equal_approx(float(Rider.read(editor.get("blueprint"))["rider_scale"]), 1.4), "Rider control not saved")
	var before: String = var_to_str(editor.get("blueprint"))
	editor.find_child("FindSupportedSeat", true, false).emit_signal("pressed")
	_expect(editor.find_child("ApplySupportedSeat", true, false).visible, "Supported proposal not reviewable")
	editor.find_child("ApplySupportedSeat", true, false).emit_signal("pressed")
	var after: String = var_to_str(editor.get("blueprint"))
	_expect(after != before, "Supported seat not applied")
	editor.call("_undo_edit")
	_expect(var_to_str(editor.get("blueprint")) == before, "Seat/profile correction undo not atomic")
	editor.call("_redo_edit")
	_expect(var_to_str(editor.get("blueprint")) == after, "Seat/profile correction redo failed")
	_expect(Assembly.save_to_file(editor.get("blueprint"), SAVE) == OK, "Seat save failed")
	editor.find_child("ReviewBodyMotion", true, false).emit_signal("pressed")
	await process_frame
	_expect(editor.get("_review_report").get("status") == "running", "Review UI did not start")
	editor.find_child("ReviewBodyMotion", true, false).emit_signal("pressed")
	_expect(editor.get("_review_report").get("status") == "cancelled" and editor.get("_review").get("_lab") == null, "Review cancellation leaks geometry or claims completion")
	editor.find_child("ReviewBodyMotion", true, false).emit_signal("pressed")
	await process_frame
	editor.free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
