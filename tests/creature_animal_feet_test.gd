extends "res://tests/creature_foot_provider_test.gd"
## Additive models use the shipped editor and the existing saved end_part_id.
const NEW_IDS: Array[String] = ["feet_feline_paws", "feet_bear_paws", "feet_horse_hooves"]
const SAVE: String = "user://animal_feet_restart.json"


func run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--verify-animal-feet" in OS.get_cmdline_user_args():
		_verify_restart()
	else:
		_check_shapes()
		for id: String in NEW_IDS:
			_check_preview(id)
			_check_radial_contact(id)
			for pairs in [1, 2]: _check_pair_count(id, pairs)
		await _check_editor_forms()
		_save_design()
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/creature_animal_feet_test.gd", "--", "--verify-animal-feet"], output, true)
		check(status == 0 and str(output).contains("ANIMAL_FEET_RESTART_PASSED") and not str(output).contains("SCRIPT ERROR"), "New feet failed restart: " + str(output))
	for error: String in failures: push_error(error)
	print(("ANIMAL_FEET_RESTART_PASSED" if "--verify-animal-feet" in OS.get_cmdline_user_args() else "ANIMAL_FEET_PASSED") + " " + JSON.stringify({"failures": failures, "new_ids": NEW_IDS}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _check_shapes() -> void:
	var signatures: Dictionary = {}
	for id: String in Snapshot.FootIds + NEW_IDS:
		var node := Node3D.new()
		preload("res://creatures/editor/creature_part_geometry.gd")._terminal(node, id, Color("8fb39b"), Color("e5d5ab"))
		var shapes: Array = Snapshot.describe(node)
		var hashes: Array = []
		for entry: Dictionary in shapes: hashes.append([entry.vertex_hash, entry.position, entry.basis])
		var signature: String = JSON.stringify(hashes)
		check(not signatures.has(signature), "Foot model is only a rename/color variant: " + id)
		signatures[signature] = id
		if id in NEW_IDS:
			var mirrored := Node3D.new()
			mirrored.set_meta("creature_part_side", -1.0)
			preload("res://creatures/editor/creature_part_geometry.gd")._terminal(mirrored, id, Color("8fb39b"), Color("e5d5ab"))
			for child: Node3D in node.get_children():
				var opposite: Node3D = mirrored.get_node(NodePath(str(child.name)))
				check((child.position * Vector3(-1, 1, 1)).is_equal_approx(opposite.position), "New foot lost mirrored detail: " + id)
			mirrored.free()
			check(shapes.size() <= 13 and not shapes.is_empty(), "Foot exceeded 13 geometry nodes: " + id)
			check(not Feet.supports(id, "domestic_support"), "New shape granted unproven D1 support")
			check(Feet.get_profile(id, 2).is_empty(), "New model downgraded future revision")
			check(not Geometry.legacy_voxels(id).is_empty(), "Missing historical renderer representation")
			var expected: int = {"feet_feline_paws": 4, "feet_bear_paws": 5, "feet_horse_hooves": 0}[id]
			var toes: int = 0
			for child: Node in node.get_children():
				if str(child.name).begins_with("PawToe") or str(child.name).begins_with("BearToe"): toes += 1
			check(toes == expected, "Authored toe anatomy missing: " + id)
		node.free()


func _design(pairs: int, foot_id: String = "") -> Dictionary:
	var result: Dictionary = Assembly.create_default()
	result.parts = []
	for index in range(pairs):
		Assembly.BaseBlueprint.add_part(result, ["legs_walker", "legs_stubby", "legs_spider"][index])
	Anatomy.reset_all_anchors(result)
	for index in range(pairs):
		var part: Dictionary = result.parts[index]
		part.anchor_t = 0.25 + 0.23 * index
		part.end_part_id = foot_id if not foot_id.is_empty() else NEW_IDS[index]
		part.end_scale = 0.85 + float(index) * 0.15
		part.end_shape_scale = Vector3(0.85, 1.1, 1.25)
		part.end_rotation = Vector3(8, -23, 12)
	Anatomy.rebind_all_parts(result)
	return result


func _check_pair_count(id: String, pairs: int) -> void:
	var frame := Node3D.new()
	root.add_child(frame)
	frame.rotation = Vector3(0.8, 0.4, -0.6)
	var preview := Preview.new()
	frame.add_child(preview)
	preview.set_editor_state(_design(pairs, id), -1, -1, false)
	check(Body.inspect_rest(preview).leg_count == pairs * 2 and Body.inspect_rest(preview).all_feet_on_plane, "New foot lost two/four-leg stance: " + id)
	preview.set_motion("run")
	preview.set_process(false)
	for index in range(12):
		preview._motion.sample("run", float(index) * 0.13)
		var grounded: int = 0
		for rig: Dictionary in preview._motion._legs:
			var gap: float = frame.to_local(rig.foot.global_position).y - float(preview.get_meta("ground_y"))
			check(gap >= -0.002, "New running foot penetrated tilted floor: " + id)
			if absf(gap) <= 0.002: grounded += 1
		check(grounded >= pairs, "New running form lost support: " + id)
	frame.free()


func _check_editor_forms() -> void:
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16): await process_frame
	editor.call("_set_mode", "parts")
	editor.call("_select_part_by_index", 2)
	var limb_uid: String = str(editor.get("blueprint").parts[2].uid)
	for id: String in NEW_IDS:
		editor.call("_on_category_button_pressed", "feet")
		editor.call("_on_part_button_pressed", id)
		check(editor.get("blueprint").parts[2].end_part_id == id, "Editor did not attach new foot: " + id)
		var old_rotation: Vector3 = editor.get("blueprint").parts[2].rotation
		editor.call("_change_part_field", 31.0, "rotation", 1)
		check(is_equal_approx(editor.get("blueprint").parts[2].end_rotation.y, 31.0), "New foot rotation ignored")
		check(editor.get("blueprint").parts[2].rotation == old_rotation and str(editor.get("blueprint").parts[2].uid) == limb_uid, "Foot replacement altered parent limb")
		editor.call("_change_part_field", 1.2, "scale", 0)
		check(is_equal_approx(editor.get("blueprint").parts[2].end_scale, 1.2), "New foot scaling ignored")
		editor.call("_undo_edit")
		editor.call("_redo_edit")
		check(editor.get("blueprint").parts[2].end_part_id == id and is_equal_approx(editor.get("blueprint").parts[2].end_scale, 1.2), "New foot undo/redo lost shape")
	editor.free()
	await process_frame


func _save_design() -> void:
	var design: Dictionary = _design(3)
	check(Assembly.save_to_file(design, SAVE) == OK, "Could not save new animal feet")
	var file := FileAccess.open("user://animal_feet_expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"design_id": design.design_id, "parts": Assembly.BaseBlueprint._serialize_blueprint(design).parts}))
	file.close()


func _verify_restart() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://animal_feet_expected.json"))
	var loaded: Dictionary = Assembly.load_from_file(SAVE)
	check(loaded.get("design_id") == expected.design_id, "Restart changed design identity")
	check(JSON.parse_string(JSON.stringify(Assembly.BaseBlueprint._serialize_blueprint(loaded).parts)) == expected.parts, "Restart lost foot IDs/rotation/scale or parent limb data")
	var preview := Preview.new()
	root.add_child(preview)
	preview.set_editor_state(loaded, -1, -1, false)
	check(Body.inspect_rest(preview).leg_count == 6 and Body.inspect_rest(preview).all_feet_on_plane, "Restart lost mixed six-foot stance")
	preview.free()
