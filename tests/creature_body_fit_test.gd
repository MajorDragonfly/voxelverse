extends SceneTree
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Fit = preload("res://creatures/runtime/creature_body_fit.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Voxels = preload("res://creatures/editor/creature_voxel_mesh.gd")
const SAVE: String = "user://body_fit_restart.json"
var failures: Array[String] = []
var evidence: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--fit-restart" in OS.get_cmdline_user_args():
		var loaded: Dictionary = Assembly.load_from_file(SAVE)
		var preview := _preview(loaded)
		var report: Dictionary = Fit.inspect(preview)
		_expect(report["complete"] and report["stretched_legs"].is_empty(), "Saved leg correction did not survive restart")
		var sample: Dictionary = _socket_report(preview, "saddle.primary")
		_expect(sample["complete"] and sample["collisions"].is_empty(), "Saved fitting correction did not survive restart")
		preview.free()
	else:
		_check_voxels()
		for pairs in range(1, 4):
			_check_anatomy(pairs)
		await _check_editor()
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/creature_body_fit_test.gd", "--", "--fit-restart"], output, true)
		_expect(status == 0 and str(output).contains("CREATURE_BODY_FIT_PASSED") and not str(output).contains("SCRIPT ERROR"), "Fresh-process fit reload failed: " + str(output))
	for failure in failures:
		push_error(failure)
	if not failures.is_empty():
		print("FIT_FAILURE_EVIDENCE " + JSON.stringify(evidence))
	if failures.is_empty():
		print("CREATURE_BODY_FIT_PASSED " + JSON.stringify(evidence))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


static func design(pairs: int) -> Dictionary:
	var blueprint: Dictionary = Assembly.create_default()
	blueprint["parts"] = []
	for index in range(pairs):
		Assembly.BaseBlueprint.add_part(blueprint, ["legs_walker", "legs_stubby", "legs_spider"][index])
	Anatomy.reset_all_anchors(blueprint)
	for index in range(pairs):
		var part: Dictionary = blueprint["parts"][index]
		part["anchor_t"] = 0.25 + index * 0.24
		part["scale"] = 0.8 + index * 0.24
		part["joint"] = {"upper": 1.35 + index * 0.1, "lower": 0.75, "offset": Vector3(0.1, 0.04, 0.12)}
		part["rotation"] = Vector3(8, -15, 12)
		part["end_part_id"] = "feet_claws" if index == 0 else "feet_hooves"
		part["end_rotation"] = Vector3(3, 14, -5)
	Anatomy.rebind_all_parts(blueprint)
	Assembly.normalize(blueprint)
	return blueprint


func _preview(blueprint: Dictionary) -> Preview:
	var preview := Preview.new()
	root.add_child(preview)
	preview.show_body_attachments = true
	preview.set_editor_state(blueprint, -1, -1, false)
	return preview


func _check_voxels() -> void:
	var mesh: ArrayMesh = Voxels.from_cells({Vector3i.ZERO: Color.WHITE}, 1.0, true)
	var turn := Transform3D(Basis(Vector3.BACK, PI / 4), Vector3.ZERO)
	_expect(not Fit.Overlap.query(mesh, turn, AABB(Vector3(0.63, 0.08, 0.45), Vector3.ONE * 0.05))["hit"], "AABB corner falsely collides with rotated voxel")
	_expect(Fit.Overlap.query(mesh, turn, AABB(Vector3(-0.02, 0.7, 0.45), Vector3.ONE * 0.05))["hit"], "Contained box missed")
	_expect(not Fit.Overlap.query(mesh, Transform3D.IDENTITY, AABB(Vector3(1, 0, 0), Vector3.ONE))["hit"], "Surface contact classified as penetration")
	_expect(Fit.Overlap.query(mesh, Transform3D.IDENTITY, AABB(Vector3(0.999, 0, 0), Vector3.ONE))["hit"], "Small penetration missed")
	_expect(not Fit.Overlap.query(mesh, Transform3D.IDENTITY, AABB(Vector3.ZERO, Vector3.ONE), 0)["complete"], "Exhausted query falsely complete")
	var empty_corner: ArrayMesh = Voxels.from_cells({Vector3i.ZERO: Color.WHITE, Vector3i(2, 2, 2): Color.WHITE}, 1.0, true)
	_expect(not Fit.Overlap.query(empty_corner, Transform3D.IDENTITY, AABB(Vector3.ONE, Vector3.ONE * 0.2))["hit"], "Empty voxel space classified as solid bounds")
	var foreign := BoxMesh.new()
	_expect(not Fit.Overlap.query(foreign, Transform3D.IDENTITY, AABB(Vector3.ZERO, Vector3.ONE))["complete"], "Unknown geometry falsely verified")
	for kind in ["ellipsoid", "diamond", "capsule", "cone"]:
		var primitive: ArrayMesh = Voxels.primitive(Vector3(0.5, 0.8, 0.4), kind)
		var check: Dictionary = Fit.Overlap.query(primitive, Transform3D.IDENTITY, AABB(Vector3.ONE * -0.01, Vector3.ONE * 0.02))
		_expect(check["complete"] and check["hit"], "Compact primitive occupancy missing: " + kind)


func _check_anatomy(pairs: int) -> void:
	var blueprint: Dictionary = design(pairs)
	var preview := _preview(blueprint)
	var before: String = var_to_str(blueprint)
	var report: Dictionary = Fit.inspect(preview)
	_expect(before == var_to_str(blueprint), "Fit query mutated authoring data")
	_expect(report["complete"] and not report["collisions"].is_empty(), "Reference rider/body overlap missing")
	var original: String = JSON.stringify(report)
	if pairs == 3:
		evidence["reference_report"] = report.duplicate(true)
	preview.transform = Transform3D(Basis.from_euler(Vector3(1.1, -0.7, 0.35)).scaled(Vector3(1.3, 0.9, 1.15)), Vector3(1500, -700, 2300))
	_expect(JSON.stringify(Fit.inspect(preview)) == original, "Radial/nonuniform world frame changed local collision evidence")
	preview.transform = Transform3D.IDENTITY
	# Inject a real voxel horn in the reference torso; the report must identify
	# the anatomical UID even through rotated/scaled child transforms.
	var horn := Node3D.new()
	horn.set_meta("creature_part_uid", "test_horn")
	horn.set_meta("creature_part_category", "details")
	horn.transform = preview.body_socket("saddle.primary")["body_transform"]
	preview.add_child(horn)
	var piece := MeshInstance3D.new()
	piece.mesh = Voxels.primitive(Vector3(0.12, 0.65, 0.12), "cone")
	piece.position.y = 0.30
	piece.rotation_degrees.z = 12
	piece.scale = Vector3(1.4, 1, 0.8)
	horn.add_child(piece)
	var with_horn: Dictionary = Fit.inspect(preview)
	var horn_hit: bool = false
	for hit: Dictionary in with_horn["collisions"]:
		horn_hit = horn_hit or hit["part_uid"] == "test_horn"
	_expect(horn_hit, "Transformed horn collision/UID missing")
	horn.set_meta("editor_guide", true)
	_expect(JSON.stringify(Fit.inspect(preview)) == original, "Guide contaminates anatomy query")
	horn.free()
	var proposal: Dictionary = Fit.socket_proposal(preview, "saddle.primary")
	_expect(not proposal.is_empty(), "No correction found for reference rider")
	if not proposal.is_empty():
		Fit.Contract.Data.set_socket(blueprint, "saddle.primary", proposal["socket"])
		preview.set_editor_state(blueprint, -1, -1, false)
		var corrected: Dictionary = _socket_report(preview, "saddle.primary")
		_expect(corrected["complete"] and corrected["collisions"].is_empty(), "Clearance proposal still collides")
		preview.set_motion("walk")
		preview.set_process(false)
		preview.get("_motion").sample("walk", 0.65)
		_expect(Fit.inspect(preview)["pose"] == "single_motion_sample", "Motion evidence falsely labeled rest")
		_expect(Fit.socket_proposal(preview, "saddle.primary").is_empty(), "Authoring correction offered for moving geometry")
		preview.set_motion("edit")
	for id in ["harness.left", "harness.right"]:
		var harness: Dictionary = Fit.socket_proposal(preview, id)
		_expect(not harness.is_empty(), "No outward harness proposal: " + id)
		if not harness.is_empty():
			Fit.Contract.Data.set_socket(blueprint, id, harness["socket"])
			preview.set_editor_state(blueprint, -1, -1, false)
			_expect(_socket_report(preview, id)["collisions"].is_empty(), "Harness proposal still intersects: " + id)
	for id in Fit.Contract.Data.IDS:
		var socket: Dictionary = Fit.Contract.Data.read(blueprint)["sockets"][id]
		socket["enabled"] = false
		Fit.Contract.Data.set_socket(blueprint, id, socket)
	preview.set_editor_state(blueprint, -1, -1, false)
	_expect(Fit.inspect(preview)["checked_sockets"].is_empty(), "Disabled fittings still tested")
	blueprint["assembly"][Fit.Contract.Data.KEY]["schema"] = 99
	preview.set_editor_state(blueprint, -1, -1, false)
	var invalid: Dictionary = Fit.inspect(preview)
	_expect(not invalid["complete"] and not invalid["errors"].is_empty(), "Unsupported attachment schema reported as clear")
	_expect(Fit.socket_proposal(preview, "saddle.primary").is_empty(), "Proposal overwrites unknown future schema")
	evidence[str(pairs * 2) + "_legs"] = {"collisions_before": report["collisions"].size(), "stretched_legs": report["stretched_legs"].size(), "cells_tested": report["cells_tested"]}
	preview.free()


func _socket_report(preview: Preview, id: String) -> Dictionary:
	return Fit.inspect_socket(Fit.collect(preview), id, preview.get_node("BodyV4").transform * preview.body_socket(id)["body_transform"], Assembly.BaseBlueprint.get_body_scale(preview.blueprint))


func _check_editor() -> void:
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.set("blueprint", design(3))
	editor.call("_set_mode", "body")
	editor.find_child("ShowBodyFittings", true, false).button_pressed = true
	var preview: Preview = editor.get("_preview")
	var report: Dictionary = editor.get("_fit_report")
	_expect(not report["stretched_legs"].is_empty(), "Six-leg extreme fixture has no targeted stretch warning")
	_expect(preview.get_node_or_null("BodyFitFindings") != null, "No visible fit markers")
	var queried: Dictionary = Fit.inspect(preview)
	_expect(queried["complete"] and JSON.stringify(queried) == JSON.stringify(report), "Finding markers affect repeated checks")
	var before: String = var_to_str(Fit.Contract.Data.read(editor.get("blueprint")))
	editor.find_child("FindBodyFit", true, false).emit_signal("pressed")
	_expect(editor.find_child("ApplyBodyFit", true, false).visible, "No reviewable fitting proposal")
	# A proposal must not apply after any unrefreshed external design change.
	var name_before: String = editor.get("blueprint")["name"]
	editor.get("blueprint")["name"] = "Changed after proposal"
	editor.find_child("ApplyBodyFit", true, false).emit_signal("pressed")
	_expect(var_to_str(Fit.Contract.Data.read(editor.get("blueprint"))) == before, "Stale proposal changed the design")
	editor.get("blueprint")["name"] = name_before
	editor.find_child("ApplyBodyFit", true, false).emit_signal("pressed")
	var corrected: String = var_to_str(Fit.Contract.Data.read(editor.get("blueprint")))
	_expect(corrected != before, "Proposal button did not change socket")
	editor.call("_undo_edit")
	_expect(var_to_str(Fit.Contract.Data.read(editor.get("blueprint"))) == before, "Socket correction undo failed")
	editor.call("_redo_edit")
	_expect(var_to_str(Fit.Contract.Data.read(editor.get("blueprint"))) == corrected, "Socket correction redo failed")
	report = Fit.inspect(preview)
	if not report["stretched_legs"].is_empty():
		var uid: String = report["stretched_legs"][0]["part_uid"]
		var original_parts: String = var_to_str(editor.get("blueprint")["parts"])
		var before_parts: Array = editor.get("blueprint")["parts"].duplicate(true)
		var changed: bool = editor.call("_fit_leg_lengths", uid)
		_expect(changed, "Targeted leg correction rejected")
		for index in range(before_parts.size()):
			var updated: Dictionary = editor.get("blueprint")["parts"][index].duplicate(true)
			if before_parts[index].get("uid", "") == uid:
				before_parts[index].erase("joint")
				updated.erase("joint")
			_expect(var_to_str(before_parts[index]) == var_to_str(updated), "Leg correction changed unrelated authoring fields")
		var rest: Dictionary = Fit.Contract.inspect_rest(preview)
		evidence["corrected_rest"] = rest
		_expect(rest["all_feet_on_plane"], "Corrected legs lost foot contact")
		for foot: Dictionary in rest["feet"]:
			if foot["part_uid"] == uid:
				_expect(foot["rest_stretch"] <= Fit.STRETCH_NOTICE, "Targeted pair still overstretched")
		editor.call("_undo_edit")
		_expect(var_to_str(editor.get("blueprint")["parts"]) == original_parts, "Leg correction undo failed")
		editor.call("_redo_edit")
		# Each button changes only its own pair; handle the other marked pair.
		var remaining: Dictionary = Fit.inspect(preview)
		var done: Dictionary = {}
		for leg: Dictionary in remaining["stretched_legs"]:
			if not done.has(leg["part_uid"]):
				done[leg["part_uid"]] = true
				_expect(editor.call("_fit_leg_lengths", leg["part_uid"]), "Second marked pair could not be corrected")
		evidence["all_corrected_rest"] = Fit.Contract.inspect_rest(preview)
	_expect(Assembly.save_to_file(editor.get("blueprint"), SAVE) == OK, "Corrected design save failed")
	editor.call("_set_mode", "test")
	editor.find_child("CheckBodyFit", true, false).emit_signal("pressed")
	_expect(editor.get("_course_paused") and not preview.is_processing(), "Motion fit check did not freeze sampled pose")
	_expect(editor.get("_fit_report")["pose"] == "single_motion_sample", "UI snapshot is mislabeled")
	editor.call("_toggle_course_pause")
	await process_frame
	_expect(editor.get("_fit_report").is_empty() and preview.get_node_or_null("BodyFitFindings") == null, "Old collision marks persist while moving")
	editor.free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
