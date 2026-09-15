extends "res://tests/creature_foot_provider_test.gd"
## Real editor, independent mouth/head anchors, radial runtime and cold reload.
const Models = preload("res://creatures/catalog/creature_mouth_catalog.gd")
const ModelGeometry = preload("res://creatures/editor/creature_mouth_geometry.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const Spine = preload("res://creatures/editor/creature_spine_profile.gd")
const ID: String = "head_elephant_trunk"
const SAVE: String = "user://trunk_restart.json"


func run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var restart: bool = "--verify-trunk" in OS.get_cmdline_user_args()
	if restart:
		_verify_restart()
	else:
		_check_catalog()
		_check_profile()
		_check_preview(ID)
		await _check_editor()
		if failures.is_empty():
			var output: Array = []
			var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--script", "res://tests/creature_trunk_provider_test.gd", "--", "--verify-trunk"], output, true)
			check(status == 0 and str(output).contains("TRUNK_RESTART_PASSED") and not str(output).contains("SCRIPT ERROR"), "Trunk restart failed: " + str(output))
	for problem: String in failures: push_error(problem)
	print(("TRUNK_FAILED" if not failures.is_empty() else ("TRUNK_RESTART_PASSED" if restart else "TRUNK_PROVIDER_PASSED")) + " " + JSON.stringify({"failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _check_profile() -> void:
	var profile: Dictionary = Models.get_profile(ID)
	check(profile.category == "head" and profile.stats.is_empty() and profile.capabilities.is_empty() and profile.supported_actions.is_empty(), "Trunk became a feeding mouth or granted an unsupported ability")
	check(profile.unlock_source == "mouth_filter_snout" and Library.get_parts_for_category("mouth").size() == 7, "Trunk replaced a mouth or its unlock source")
	profile.features.clear()
	check(not Models.get_profile(ID).features.is_empty(), "Caller changed shared model profile")
	check(Models.get_profile(ID, 2).is_empty() and ModelGeometry.recipe(ID, Color.WHITE, Color.WHITE, Color.WHITE, 2).is_empty(), "Future revision silently rendered old trunk")
	check(Models.get_profile("head_future").is_empty(), "Unknown head substituted a trunk")
	var recipe: Array[Dictionary] = ModelGeometry.recipe(ID, Color.WHITE, Color.WHITE, Color.WHITE)
	check(recipe.size() == 11, "Trunk exceeded its mesh budget")
	# A continuous authored nose, including the curl, instead of floating blocks.
	for index in range(1, 9):
		var a: Dictionary = recipe[index - 1]
		var b: Dictionary = recipe[index]
		check(AABB(a.position - a.size * 0.5, a.size).intersects(AABB(b.position - b.size * 0.5, b.size)), "Disconnected trunk section: " + b.name)
	for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.2, 1.4)]:
		var nodes: Array[Node3D] = []
		for side: float in [1.0, -1.0]:
			var node := Node3D.new()
			node.set_meta("creature_part_side", side)
			Snapshot.Geometry.build(node, Library.get_part(ID), {"category": "head", "shape_scale": shape}, Assembly.create_default())
			nodes.append(node)
		for child: MeshInstance3D in nodes[0].get_children():
			var mirrored: MeshInstance3D = nodes[1].get_node(NodePath(str(child.name)))
			check(child.transform.is_finite() and (child.position * Vector3(-1, 1, 1)).is_equal_approx(mirrored.position), "Trunk reflection lost authored transform")
			check(child.mesh is ArrayMesh and child.mesh.get_aabb().size.is_equal_approx(mirrored.mesh.get_aabb().size), "Trunk shape lost voxel geometry")
		for node: Node3D in nodes: node.free()


func _check_editor() -> void:
	var progress: Node = root.get_node("ProgressionService")
	root.get_node("GameState").set_world_seed(42)
	progress.reset_for_new_game()
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16): await process_frame
	var design: Dictionary = Assembly.create_default()
	Anatomy.reset_all_anchors(design)
	# Enter through the editor's real load/restore path, including its existing
	# attachment migration, before taking the unchanged-design baseline.
	editor.call("_apply_restored_blueprint", design, "Test design")
	editor.call("_set_mode", "parts")
	editor.call("_on_category_button_pressed", "head")
	editor.call("_refresh_all")
	check(editor.get("current_category") == "head", "Head category unavailable in editor")
	var original: String = var_to_str(editor.get("blueprint"))
	editor.call("_on_part_button_pressed", ID)
	check(not progress.is_part_unlocked(ID) and var_to_str(editor.get("blueprint")) == original, "Locked trunk changed a design")
	var observed: Dictionary = Assembly.create_default()
	observed.parts = []
	Assembly.BaseBlueprint.add_part(observed, "mouth_filter_snout")
	var receipt: Dictionary = progress.register_species_discovery(427, observed, 42)
	check(receipt.unlocked_part == "mouth_filter_snout" and progress.discovery_points == 3 and progress.is_part_unlocked(ID), "Discovery did not earn trunk exactly once with filtersnout")
	var state: Dictionary = progress.export_state()
	var old: Dictionary = state.duplicate(true)
	old.unlocked_parts.erase(ID)
	var old_text: String = JSON.stringify(old)
	check(progress.import_state(old) and progress.is_part_unlocked(ID), "Old earned filtersnout save did not expose trunk")
	check(JSON.stringify(old) == old_text and progress.export_state() == state, "Unlock migration mutated source or rewards")
	check(progress.import_state(state) and progress.export_state() == state, "Repeated loading duplicated unlocks")
	var rows: Array[Dictionary] = Records.part_rows(state, "", "head")
	check(rows.size() == 1 and rows[0].id == ID and rows[0].unlocked, "Journal disagrees with head unlock")
	var before_stats: Dictionary = Assembly.BaseBlueprint.calculate_stats(editor.get("blueprint"))
	before_stats.erase("complexity")
	var before_parts: Array = editor.get("blueprint").parts.duplicate(true)
	editor.call("_on_part_button_pressed", ID)
	design = editor.get("blueprint")
	var index: int = design.parts.size() - 1
	check(design.parts.size() == before_parts.size() + 1 and design.parts[index].part_id == ID, "Editor failed to add a separate head module")
	check(design.parts.slice(0, index) == before_parts, "Adding trunk changed existing attachments")
	var after_stats: Dictionary = Assembly.BaseBlueprint.calculate_stats(design)
	after_stats.erase("complexity")
	check(after_stats == before_stats, "Cosmetic trunk changed gameplay stats")
	check(not design.parts[index].mirrored and design.parts[index].position.y > design.parts[1].position.y + 0.2, "Trunk duplicated or covered the mouth socket")
	editor.call("_undo_edit")
	check(editor.get("blueprint").parts == before_parts, "Trunk undo changed original parts")
	editor.call("_redo_edit")
	editor.call("_select_part_by_index", index)
	editor.call("_change_part_field", 12.0, "rotation", 1)
	editor.call("_change_part_field", 0.9, "scale", 0)
	editor.call("_change_part_field", 1.15, "shape", 2)
	design = editor.get("blueprint").duplicate(true)
	check(is_equal_approx(design.parts[index].rotation.y, 12) and is_equal_approx(design.parts[index].scale, 0.9) and is_equal_approx(design.parts[index].shape_scale.z, 1.15), "Editor lost head transforms")
	Spine.set_segment(design, 0, {"y_offset": 0.3, "height_scale": 1.2})
	Anatomy.rebind_all_parts(design)
	_check_runtime(design)
	# Each is its own placement, with its own identity and deletion lifecycle.
	var without_head: Dictionary = design.duplicate(true)
	Assembly.BaseBlueprint.remove_part(without_head, index)
	check(without_head.parts.size() == before_parts.size() and without_head.parts[1].part_id == "mouth_grazer", "Deleting trunk removed mouth")
	var without_mouth: Dictionary = design.duplicate(true)
	Assembly.BaseBlueprint.remove_part(without_mouth, 1)
	check(without_mouth.parts.back().uid == design.parts[index].uid, "Deleting mouth removed/recreated trunk")
	check(Assembly.save_to_file(design, SAVE) == OK, "Trunk save failed")
	check(Assembly.save_to_file(without_head, "user://trunk_legacy.json") == OK, "Existing body save failed")
	var file := FileAccess.open("user://trunk_expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"design_id": design.design_id, "parts": Assembly.BaseBlueprint._serialize_blueprint(design).parts,
		"legacy": Assembly.BaseBlueprint._serialize_blueprint(without_head).parts, "progression": state, "game": root.get_node("GameState").export_state()}))
	file.close()
	editor.free()
	await process_frame


func _check_runtime(design: Dictionary) -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	parent.transform = Transform3D(Basis.from_euler(Vector3(0.9, -0.7, 0.4)), Vector3(1500, -700, 2300))
	var preview := Preview.new()
	parent.add_child(preview)
	preview.set_editor_state(design, -1, -1, false)
	var heads: Array[Node3D] = []
	var mouths: Array[Node3D] = []
	for child: Node in preview.get_children():
		if child is Node3D and child.get_meta("creature_part_category", "") == "head": heads.append(child)
		if child is Node3D and child.get_meta("creature_part_category", "") == "mouth": mouths.append(child)
	check(heads.size() == 1 and mouths.size() == 1, "Runtime lost independent head or mouth")
	var original: String = var_to_str(design)
	for mode: String in ["idle", "walk", "run"]:
		preview.set_motion(mode)
		preview.set_process(false)
		for time: float in [0, 0.19, 0.47, 0.81]:
			preview._motion.sample(mode, time)
			for node: Node3D in heads + mouths:
				var part: Dictionary = design.parts[int(node.get_meta("creature_part_index"))]
				check(node.global_transform.is_finite() and node.position.is_equal_approx(part.position), "Body motion detached a head/mouth socket")
				check(node.get_child_count() > 0, "Head or mouth lost rendered geometry")
			check(preview._motion._legs.size() == 2, "Trunk counted as a supporting limb")
	check(var_to_str(design) == original, "Posing rewrote saved head/mouth settings")
	parent.free()


func _verify_restart() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://trunk_expected.json"))
	root.get_node("GameState").import_state(expected.game, false)
	var loaded: Dictionary = Assembly.load_from_file(SAVE)
	check(loaded.get("design_id") == expected.design_id, "Restart changed design identity")
	check(JSON.parse_string(JSON.stringify(Assembly.BaseBlueprint._serialize_blueprint(loaded).parts)) == expected.parts, "Restart changed head/mouth IDs, UIDs, anchors or transforms")
	var legacy: Dictionary = Assembly.load_from_file("user://trunk_legacy.json")
	check(JSON.parse_string(JSON.stringify(Assembly.BaseBlueprint._serialize_blueprint(legacy).parts)) == expected.legacy, "Restart changed existing design without trunk")
	var progress: Node = root.get_node("ProgressionService")
	check(progress.import_state(expected.progression) and progress.is_part_unlocked(ID), "Restart lost earned trunk")
	_check_runtime(loaded)
