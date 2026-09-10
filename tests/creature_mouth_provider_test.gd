extends "res://tests/creature_foot_provider_test.gd"
const Mouths = preload("res://creatures/catalog/creature_mouth_catalog.gd")
const MouthGeometry = preload("res://creatures/editor/creature_mouth_geometry.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const MODELS: Array[String] = ["mouth_canine_snout", "mouth_crocodile_snout", "mouth_octopus_beak"]
const SAVE: String = "user://mouth_models_restart.json"


func run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--verify-mouth-models" in OS.get_cmdline_user_args():
		_verify_restart()
	else:
		_check_catalog()
		_check_baseline()
		_check_profiles_and_geometry()
		for id: String in MODELS: _check_preview(id)
		await _check_editor_and_unlocks()
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/creature_mouth_provider_test.gd", "--", "--verify-mouth-models"], output, true)
		check(status == 0 and str(output).contains("MOUTH_MODELS_RESTART_PASSED") and not str(output).contains("SCRIPT ERROR"), "Mouth restart failed: " + str(output))
	for problem: String in failures: push_error(problem)
	print(("MOUTH_MODELS_RESTART_PASSED" if "--verify-mouth-models" in OS.get_cmdline_user_args() else "MOUTH_PROVIDER_PASSED") + " " + JSON.stringify({"failures": failures, "legacy_geometry_cases": 24, "frozen_species": 30, "models": MODELS}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _model(id: String, shape: Vector3 = Vector3.ONE, side: float = 1.0) -> Node3D:
	var node := Node3D.new()
	node.set_meta("creature_part_side", side)
	Snapshot.Geometry.build(node, Library.get_part(id), {"category": "mouth", "shape_scale": shape}, Assembly.BaseBlueprint.create_default())
	return node


func _check_baseline() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_mouths_v1.json"))
	var actual: Dictionary = {}
	for id: String in Mouths.LEGACY_IDS:
		for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9)]:
			for side: float in [-1.0, 1.0]:
				var node: Node3D = _model(id, shape, side)
				actual["%s:%s:%d" % [id, shape, int(side)]] = Snapshot.describe(node)
				node.free()
	check(expected.mouths.size() == 24 and JSON.parse_string(JSON.stringify(actual)) == expected.mouths, "Legacy mouth geometry, transforms or colors changed")
	check(expected.species.size() == 30, "Missing frozen species evidence")
	for seed_value: int in [1, 17, 42, 977, 8192]:
		for role: String in Species.ECOLOGICAL_ROLES:
			var design: Dictionary = Species.create_species(seed_value, Vector2i(13, -7), role)
			check(JSON.stringify(Assembly.BaseBlueprint._serialize_blueprint(design)).sha256_text() == expected.species["%d:%s" % [seed_value, role]], "Added mouth models regenerated a legacy species")


func _check_profiles_and_geometry() -> void:
	var signatures: Dictionary = {}
	for id: String in Mouths.LEGACY_IDS + MODELS:
		var node: Node3D = _model(id)
		var hashes: Array = []
		for entry: Dictionary in Snapshot.describe(node): hashes.append([entry.vertex_hash, entry.position, entry.basis])
		var signature: String = JSON.stringify(hashes)
		check(not signatures.has(signature), "Mouth is only a recolor or rename: " + id)
		signatures[signature] = id
		node.free()
	for id: String in MODELS:
		var profile: Dictionary = Mouths.get_profile(id)
		check(profile.attachment == "body_surface" and profile.capabilities.is_empty() and profile.supported_actions.is_empty(), "Shape granted unsupported abilities")
		profile.features.clear()
		check(not Mouths.get_profile(id).features.is_empty(), "Caller mutated mouth catalog")
		var definition: Dictionary = Library.get_part(id)
		var source: Dictionary = Library.get_part(definition.stats_source)
		check(definition.stats == source.stats and definition.complexity == source.complexity and definition.default_scale == source.default_scale, "Model invented new gameplay values")
		definition.stats.attack = 900
		check(Library.get_part(id).stats == source.stats, "Caller mutated inherited mouth stats")
		check(Mouths.get_profile(id, 2).is_empty() and MouthGeometry.recipe(id, Color.WHITE, Color.WHITE, Color.WHITE, 2).is_empty() and MouthGeometry.legacy_voxels(id, 2).is_empty(), "Future revision silently downgraded")
		for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9)]:
			var left: Node3D = _model(id, shape, 1)
			var right: Node3D = _model(id, shape, -1)
			var counts: Dictionary = {MODELS[0]: 11, MODELS[1]: 25, MODELS[2]: 17}
			check(left.get_child_count() == counts[id] and MouthGeometry.legacy_voxels(id).size() == counts[id], "Mouth model exceeded its node budget or lost legacy geometry")
			for child: MeshInstance3D in left.get_children():
				var mirrored: MeshInstance3D = right.get_node(NodePath(str(child.name)))
				check(child.transform.is_finite() and (child.position * Vector3(-1, 1, 1)).is_equal_approx(mirrored.position), "Mouth did not mirror its position")
				check(child.mesh.get_aabb().size.is_equal_approx(mirrored.mesh.get_aabb().size), "Mirroring changed mouth dimensions")
				check((child.basis.y * Vector3(-1, 1, 1)).is_equal_approx(mirrored.basis.y), "Mouth tooth/hook direction did not reflect")
			left.free()
			right.free()
	var octopus: Node3D = _model(MODELS[2])
	check(octopus.find_children("OralRing*", "MeshInstance3D", false, false).size() == 12 and octopus.has_node("UpperBeakHook") and octopus.has_node("LowerBeakHook"), "Octopus lost its ring or inner beak")
	octopus.free()
	for id: String in ["mouth_future", "feet_pads", ""]:
		check(Mouths.get_profile(id).is_empty() and MouthGeometry.recipe(id, Color.WHITE, Color.WHITE, Color.WHITE).is_empty(), "Unknown mouth rendered as another model")
	var unknown := Node3D.new()
	Snapshot.Geometry.build(unknown, {"id": "mouth_future"}, {"category": "mouth"}, Assembly.create_default())
	check(unknown.get_child_count() == 0, "Common renderer substituted unknown mouth")
	unknown.free()


func _design() -> Dictionary:
	var design: Dictionary = Assembly.create_default()
	design.parts = []
	Assembly.BaseBlueprint.add_part(design, "legs_walker")
	for id: String in MODELS: Assembly.BaseBlueprint.add_part(design, id)
	Anatomy.reset_all_anchors(design)
	for index in range(1, design.parts.size()):
		design.parts[index].rotation = Vector3(18, -23, 12)
		design.parts[index].scale = 1.15
		design.parts[index].shape_scale = Vector3(0.8, 1.1, 1.4)
	Anatomy.rebind_all_parts(design)
	return design


func _check_runtime(design: Dictionary) -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	parent.transform = Transform3D(Basis.from_euler(Vector3(0.9, -0.7, 0.4)), Vector3(1500, -700, 2300))
	var preview := Preview.new()
	parent.add_child(preview)
	preview.set_editor_state(design, -1, -1, false)
	var mouths: Array[Node3D] = []
	for child: Node in preview.get_children():
		if child is Node3D and str(child.get_meta("creature_part_category", "")) == "mouth": mouths.append(child)
	check(mouths.size() == 3, "Runtime lost a saved mouth")
	var before: String = var_to_str(design)
	for mode: String in ["idle", "walk", "run"]:
		preview.set_motion(mode)
		preview.set_process(false)
		for time: float in [0.0, 0.19, 0.47, 0.81]:
			preview._motion.sample(mode, time)
			for mouth: Node3D in mouths:
				check(mouth.global_transform.is_finite() and mouth.get_child_count() > 0, "Animated mouth detached or became invalid")
			check(preview._motion._legs.size() == 2, "Mouth counted as supporting leg")
	check(var_to_str(design) == before, "Runtime rewrote saved mouth settings")
	parent.free()


func _check_editor_and_unlocks() -> void:
	var progress: Node = root.get_node("ProgressionService")
	root.get_node("GameState").set_world_seed(42)
	progress.reset_for_new_game()
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16): await process_frame
	editor.set("blueprint", Assembly.create_default())
	editor.call("_set_mode", "parts")
	editor.call("_on_category_button_pressed", "mouth")
	var before: String = var_to_str(editor.get("blueprint"))
	for id: String in MODELS:
		check(not progress.is_part_unlocked(id), "Unearned model unlocked at start")
		editor.call("_on_part_button_pressed", id)
		check(var_to_str(editor.get("blueprint")) == before, "Locked model changed editor design")
	# The real discovery path earns the existing mouth; model alternatives follow.
	var observed: Dictionary = Assembly.create_default()
	observed.parts = []
	Assembly.BaseBlueprint.add_part(observed, "mouth_predator_jaws")
	var receipt: Dictionary = progress.register_species_discovery(421, observed, 42)
	check(receipt.unlocked_part == "mouth_predator_jaws" and progress.discovery_points == 3, "Model addition changed discovery rewards: " + JSON.stringify(receipt))
	for id: String in MODELS: check(progress.is_part_unlocked(id), "Earned mouth did not expose its models")
	if not failures.is_empty():
		editor.free()
		return
	var state: Dictionary = progress.export_state()
	for row: Dictionary in Records.part_rows(state, "", "mouth"):
		if row.id in MODELS: check(row.unlocked, "Journal disagrees with editor unlock")
	var source_state: Dictionary = state.duplicate(true)
	for id: String in MODELS: source_state.unlocked_parts.erase(id)
	var original: String = JSON.stringify(source_state)
	check(progress.import_state(source_state), "Old earned mouth state rejected")
	check(JSON.stringify(source_state) == original, "Migration rewrote input snapshot")
	for id: String in MODELS: check(progress.is_part_unlocked(id), "Old save lost model unlock")
	check(progress.export_state() == state, "Model migration changed rewards, IDs or record order")
	for id: String in MODELS:
		var design: Dictionary = Assembly.create_default()
		design.parts = []
		editor.set("blueprint", design)
		editor.call("_on_category_button_pressed", "mouth")
		editor.call("_on_part_button_pressed", id)
		check(editor.get("blueprint").parts.size() == 1 and editor.get("blueprint").parts[0].part_id == id, "Editor could not add model")
		editor.call("_undo_edit")
		check(editor.get("blueprint").parts.is_empty(), "Mouth undo failed")
		editor.call("_redo_edit")
		check(editor.get("blueprint").parts.size() == 1 and editor.get("blueprint").parts[0].part_id == id, "Mouth redo failed")
		editor.call("_select_part_by_index", 0)
		editor.call("_change_part_field", 31.0, "rotation", 1)
		editor.call("_change_part_field", 1.3, "scale", 0)
		editor.call("_change_part_field", 0.75, "shape", 2)
		var part: Dictionary = editor.get("blueprint").parts[0]
		check(is_equal_approx(part.rotation.y, 31) and is_equal_approx(part.scale, 1.3) and is_equal_approx(part.shape_scale.z, 0.75), "Mouth controls lost transform")
	editor.free()
	await process_frame
	var design: Dictionary = _design()
	_check_runtime(design)
	check(Assembly.save_to_file(design, SAVE) == OK, "Mouth save failed")
	var file := FileAccess.open("user://mouth_models_expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"design_id": design.design_id, "parts": Assembly.BaseBlueprint._serialize_blueprint(design).parts, "progression": state, "game": root.get_node("GameState").export_state()}))
	file.close()


func _verify_restart() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://mouth_models_expected.json"))
	root.get_node("GameState").import_state(expected.game, false)
	var loaded: Dictionary = Assembly.load_from_file(SAVE)
	check(loaded.get("design_id") == expected.design_id, "Restart changed design identity")
	check(JSON.parse_string(JSON.stringify(Assembly.BaseBlueprint._serialize_blueprint(loaded).parts)) == expected.parts, "Restart changed mouth IDs, UIDs or transforms")
	var progress: Node = root.get_node("ProgressionService")
	check(progress.import_state(expected.progression), "Restart rejected mouth progression")
	for id: String in MODELS: check(progress.is_part_unlocked(id), "Restart lost model unlock")
	_check_runtime(loaded)
