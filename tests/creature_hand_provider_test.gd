extends "res://tests/creature_foot_provider_test.gd"
const Hands = preload("res://creatures/catalog/creature_hand_catalog.gd")
const HandGeometry = preload("res://creatures/editor/creature_hand_geometry.gd")
const OLD_HANDS: Array = ["hands_grasp", "hands_claws", "hands_pincers"]
const CRAB: String = "hands_crab_claws"
const SAVE: String = "user://crab_claws_restart.json"


func run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--verify-crab-claws" in OS.get_cmdline_user_args():
		_verify_restart()
	else:
		_check_catalog()
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_hands_v1.json"))
		check(expected.size() == 18, "Incomplete pre-extraction hand baseline")
		check(JSON.parse_string(JSON.stringify(Snapshot.capture(OLD_HANDS))) == expected, "Legacy hand meshes, colors or transforms changed")
		_check_hand_profiles()
		_check_crab_geometry()
		for id: String in OLD_HANDS + [CRAB]: _check_preview(id)
		for arm: String in ["arms_grasping", "arms_climber", "arms_claws"]:
			_check_arm_motion(_arm_design(arm))
		await _check_editor_hand()
		_save_design()
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/creature_hand_provider_test.gd", "--", "--verify-crab-claws"], output, true)
		check(status == 0 and str(output).contains("CRAB_CLAWS_RESTART_PASSED") and not str(output).contains("SCRIPT ERROR"), "Crab restart failed: " + str(output))
	for problem: String in failures: push_error(problem)
	print(("CRAB_CLAWS_RESTART_PASSED" if "--verify-crab-claws" in OS.get_cmdline_user_args() else "HAND_PROVIDER_PASSED") + " " + JSON.stringify({"failures": failures, "legacy_cases": 18, "new_id": CRAB}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _check_hand_profiles() -> void:
	var profile: Dictionary = Hands.get_profile(CRAB)
	check(profile.attachment == "arm_end", "Crab does not require an arm socket")
	profile.features.clear()
	profile.capabilities.append("climb")
	check(Hands.get_profile(CRAB).features.size() == 4 and Hands.get_profile(CRAB).capabilities.is_empty(), "Caller mutated hand anatomy")
	var definitions: Array = Hands.get_parts()
	definitions[0].stats.attack = 1000
	check(Hands.get_parts()[0].stats.is_empty(), "Caller mutated hand stats")
	for id: String in OLD_HANDS + [CRAB]:
		check(Library.get_part(id).stats.is_empty() and Library.get_part(id).complexity == 2, "Hand silently gained stats or cost")
		check(Hands.get_profile(id).supported_limb_actions.is_empty(), "Hand anatomy granted an unimplemented action")
		check(Hands.get_profile(id, 2).is_empty() and HandGeometry.recipe(id, Color.WHITE, Color.WHITE, 2).is_empty() and HandGeometry.legacy_voxels(id, 2).is_empty(), "Future revision downgraded")
	for id: String in ["hands_future", "feet_pads", ""]:
		check(Hands.get_profile(id).is_empty() and HandGeometry.recipe(id, Color.WHITE, Color.WHITE).is_empty() and HandGeometry.legacy_voxels(id).is_empty(), "Unknown hand identity rendered as another hand")


func _check_crab_geometry() -> void:
	var signatures: Dictionary = {}
	for id: String in OLD_HANDS + [CRAB]:
		var node := Node3D.new()
		Snapshot.Geometry._terminal(node, id, Color("8fb39b"), Color("e5d5ab"))
		var hashes: Array = []
		for entry: Dictionary in Snapshot.describe(node): hashes.append([entry.vertex_hash, entry.position, entry.basis])
		var signature: String = JSON.stringify(hashes)
		check(not signatures.has(signature), "Hand model is only a recolor or rename")
		signatures[signature] = id
		node.free()
	for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9)]:
		var pair: Array[Node3D] = []
		for side: float in [1.0, -1.0]:
			var node := Node3D.new()
			node.set_meta("part_shape", shape)
			node.set_meta("creature_part_side", side)
			Snapshot.Geometry._terminal(node, CRAB, Color.WHITE, Color.WHITE)
			pair.append(node)
		check(pair[0].get_child_count() == 15, "Crab exceeded fixed 15-node model budget")
		check(pair[0].find_children("*Tooth*", "MeshInstance3D", false, false).size() == 6, "Crab lacks six inner teeth")
		for child: MeshInstance3D in pair[0].get_children():
			var mirrored: MeshInstance3D = pair[1].get_node(NodePath(str(child.name)))
			check((child.position * Vector3(-1, 1, 1)).is_equal_approx(mirrored.position), "Crab detail did not mirror: " + str(child.name))
			check(child.mesh.get_aabb().size.is_equal_approx(mirrored.mesh.get_aabb().size), "Mirrored crab changed dimensions")
			# Directed jaw/tooth centerlines must reflect, including nonuniform scale.
			if str(child.name).contains("Tip") or str(child.name).contains("Tooth") or str(child.name).contains("Finger"):
				check((child.basis.y * Vector3(-1, 1, 1)).is_equal_approx(mirrored.basis.y), "Crab jaw direction did not reflect")
		for node: Node3D in pair: node.free()
	check(HandGeometry.legacy_voxels(CRAB).size() == 15, "Legacy adapter lost crab anatomy")


func _arm_design(arm: String) -> Dictionary:
	var design: Dictionary = Assembly.create_default()
	design.parts = []
	Assembly.BaseBlueprint.add_part(design, "legs_walker")
	Assembly.BaseBlueprint.add_part(design, arm)
	Anatomy.reset_all_anchors(design)
	design.parts[1].end_part_id = CRAB
	design.parts[1].end_rotation = Vector3(18, -23, 12)
	design.parts[1].end_scale = 1.15
	design.parts[1].end_shape_scale = Vector3(0.8, 1.1, 1.4)
	Anatomy.rebind_all_parts(design)
	return design


func _check_arm_motion(design: Dictionary) -> void:
	var frame := Node3D.new()
	root.add_child(frame)
	frame.transform = Transform3D(Basis.from_euler(Vector3(0.9, -0.7, 0.4)), Vector3(1500, -700, 2300))
	var preview := Preview.new()
	frame.add_child(preview)
	preview.set_editor_state(design, -1, -1, false)
	var arms: Array[Node3D] = []
	for child: Node in preview.get_children():
		if child is Node3D and str(child.get_meta("creature_part_category", "")) == "arms": arms.append(child)
	check(arms.size() == 2, "Crab arm pair missing")
	var before: String = var_to_str(design)
	for mode: String in ["idle", "walk", "run"]:
		preview.set_motion(mode)
		preview.set_process(false)
		var poses: Dictionary = {}
		for time: float in [0.0, 0.19, 0.47, 0.81]:
			preview._motion.sample(mode, time)
			for arm: Node3D in arms:
				var rig: Dictionary = arm.get_meta("sculpt_limb_rig")
				var socket: Node3D = rig.socket
				check(socket.get_parent() == rig.knee and socket.get_node_or_null("CrabPalm") != null, "Animated crab detached from arm socket")
				poses[var_to_str(arm.rotation)] = true
				for mesh: MeshInstance3D in socket.find_children("*", "MeshInstance3D", false, false):
					check(mesh.global_transform.is_finite(), "Nonfinite animated crab transform")
			check(preview._motion._legs.size() == 2, "Hands counted as supporting legs")
			for rig: Dictionary in preview._motion._legs:
				check(frame.to_local(rig.foot.global_position).y >= float(preview.get_meta("ground_y")) - 0.002, "Crab attachment disturbed radial feet")
		if mode != "idle": check(poses.size() > 2, "Crab arms did not move with locomotion")
	check(var_to_str(design) == before, "Arm posing rewrote saved settings")
	frame.free()


func _check_editor_hand() -> void:
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16): await process_frame
	var design: Dictionary = _arm_design("arms_grasping")
	design.parts[1].end_part_id = "hands_grasp"
	editor.set("blueprint", design)
	editor.call("_set_mode", "parts")
	editor.call("_select_part_by_index", 0)
	var original: String = var_to_str(editor.get("blueprint"))
	editor.call("_on_category_button_pressed", "hands")
	editor.call("_on_part_button_pressed", CRAB)
	check(var_to_str(editor.get("blueprint")) == original, "Editor attached crab to a leg")
	editor.call("_select_part_by_index", 1)
	var uid: String = str(editor.get("blueprint").parts[1].uid)
	editor.call("_on_category_button_pressed", "hands")
	editor.call("_on_part_button_pressed", CRAB)
	check(editor.get("blueprint").parts[1].end_part_id == CRAB, "Editor cannot select crab claw")
	editor.call("_undo_edit")
	check(editor.get("blueprint").parts[1].end_part_id == "hands_grasp", "Undo did not restore previous hand")
	editor.call("_redo_edit")
	check(editor.get("blueprint").parts[1].end_part_id == CRAB, "Redo did not restore crab claw")
	var parent_rotation: Vector3 = editor.get("blueprint").parts[1].rotation
	editor.call("_change_part_field", 31.0, "rotation", 1)
	editor.call("_change_part_field", 1.3, "scale", 0)
	editor.call("_change_part_field", 0.75, "shape", 2)
	var part: Dictionary = editor.get("blueprint").parts[1]
	check(part.rotation == parent_rotation and str(part.uid) == uid, "Crab controls changed parent arm identity or rotation")
	check(is_equal_approx(part.end_rotation.y, 31) and is_equal_approx(part.end_scale, 1.3) and is_equal_approx(part.end_shape_scale.z, 0.75), "Crab transforms not applied independently")
	editor.free()
	await process_frame


func _save_design() -> void:
	var design: Dictionary = _arm_design("arms_claws")
	check(Assembly.save_to_file(design, SAVE) == OK, "Crab design save failed")
	var file := FileAccess.open("user://crab_claws_expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"design_id": design.design_id, "parts": Assembly.BaseBlueprint._serialize_blueprint(design).parts}))
	file.close()


func _verify_restart() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://crab_claws_expected.json"))
	var loaded: Dictionary = Assembly.load_from_file(SAVE)
	check(loaded.get("design_id") == expected.design_id, "Restart changed design identity")
	check(JSON.parse_string(JSON.stringify(Assembly.BaseBlueprint._serialize_blueprint(loaded).parts)) == expected.parts, "Restart changed crab ID, limb UID or transforms")
	_check_arm_motion(loaded)
