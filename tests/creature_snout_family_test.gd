extends "res://tests/creature_mouth_provider_test.gd"
const Joints = preload("res://creatures/runtime/creature_part_articulation.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Designs = preload("res://assembly/exchange/creature_design_library.gd")
const SNOUTS: Array[String] = ["mouth_feline_snout", "mouth_bear_snout", "mouth_pig_snout"]
const COUNTS: Dictionary = {"mouth_feline_snout": 16, "mouth_bear_snout": 20, "mouth_pig_snout": 13}
const SNOUT_SAVE: String = "user://snout_family.json"


func run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--restart-snouts" in OS.get_cmdline_user_args():
		_restart_snouts()
	else:
		_check_catalog()
		_check_baseline()
		_preserve_previous_models()
		_new_models()
		for id: String in SNOUTS: _check_preview(id)
		await _snout_editor()
		_save_and_exchange()
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/creature_snout_family_test.gd", "--", "--restart-snouts"], output, true)
		check(status == 0 and str(output).contains("SNOUTS_RESTART_PASSED") and not str(output).contains("SCRIPT ERROR"), "Snout restart failed: " + str(output))
	for problem: String in failures: push_error(problem)
	if failures.is_empty(): print("SNOUTS_RESTART_PASSED" if "--restart-snouts" in OS.get_cmdline_user_args() else "SNOUT_FAMILY_PASSED: 3 models; 42 frozen meshes; editor, joints, library and restart")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _preserve_previous_models() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_mouths_before_snouts.json"))
	check(expected.size() == 42, "Incomplete pre-snout baseline")
	for id: String in Mouths.LEGACY_IDS + MODELS:
		for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9)]:
			for side: float in [-1.0, 1.0]:
				var model: Node3D = _model(id, shape, side)
				check(JSON.stringify(Snapshot.describe(model)).sha256_text() == expected["%s:%s:%d" % [id, shape, int(side)]], "Prior mouth geometry/color changed: " + id)
				model.free()


func _new_models() -> void:
	var signatures: Dictionary = {}
	for id: String in MODELS + SNOUTS:
		var model: Node3D = _model(id)
		var meshes: Array = Snapshot.describe(model)
		for entry: Dictionary in meshes:
			entry.erase("name")
			entry.erase("color")
		var signature: String = JSON.stringify(meshes).sha256_text()
		check(not signatures.has(signature), "Snout is only a recolor or rename")
		signatures[signature] = id
		model.free()
	for id: String in SNOUTS:
		var definition: Dictionary = Library.get_part(id)
		var profile: Dictionary = Mouths.get_profile(id)
		var source: Dictionary = Library.get_part(profile.stats_source)
		check(definition.stats == source.stats and definition.complexity == source.complexity and definition.default_scale == source.default_scale, "Snout invented cost/diet/combat values")
		check(profile.unlock_source == ("mouth_predator_jaws" if id == SNOUTS[0] else "mouth_broad_beak"), "Wrong earned profile")
		check(profile.supported_actions.is_empty() and profile.capabilities.is_empty(), "Cosmetic shape granted capabilities")
		profile.features.clear()
		check(Mouths.get_profile(id).features.size() == 4, "Caller changed catalog")
		check(MouthGeometry.recipe(id, Color.WHITE, Color.WHITE, Color.WHITE, 2).is_empty() and MouthGeometry.articulation(id, 2).is_empty(), "Future model revision downgraded")
		for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9)]:
			var pair: Array[Node3D] = [_model(id, shape, 1), _model(id, shape, -1)]
			var joints: Array = [Joints.new(), Joints.new()]
			for index in range(2): joints[index].bind(pair[index])
			check(pair[0].get_child_count() == COUNTS[id] and MouthGeometry.legacy_voxels(id).size() == COUNTS[id], "Snout exceeded fixed mesh budget")
			var rest: Array = Snapshot.describe(pair[0])
			var nose: Transform3D = pair[0].get_node("NoseDisc" if id == SNOUTS[2] else "Nose").transform
			var lower: Transform3D = pair[0].get_node("LowerJaw").transform
			for amount: float in [0.0, 0.25, 0.5, 1.0, 0.0]:
				for joint: RefCounted in joints: joint.set_pose(amount, 0.0)
				check(pair[0].get_node("NoseDisc" if id == SNOUTS[2] else "Nose").transform == nose, "Nose moved with lower jaw")
				check(pair[0].get_node("LowerJaw").position.y <= lower.origin.y + 0.00001, "Jaw opened upward")
				for mesh: MeshInstance3D in pair[0].get_children():
					var mirrored: MeshInstance3D = pair[1].get_node(NodePath(str(mesh.name)))
					check(mesh.transform.is_finite() and (mesh.position * Vector3(-1, 1, 1)).is_equal_approx(mirrored.position), "Pose did not reflect: " + id + "/" + str(mesh.name))
				if amount > 0.0 and id == SNOUTS[1]:
					var tooth: Node3D = pair[0].get_node("LowerMolarLeft0")
					check(tooth.position.y < -0.172 * shape.y, "Bear lower molars did not follow jaw")
			check(Snapshot.describe(pair[0]) == rest, "Joint posing changed resting mesh data")
			for index in range(2):
				joints[index].unbind()
				pair[index].free()


func _snout_editor() -> void:
	var progress: Node = root.get_node("ProgressionService")
	root.get_node("GameState").set_world_seed(43)
	progress.reset_for_new_game()
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16): await process_frame
	editor.set("blueprint", Assembly.create_default())
	editor.call("_set_mode", "parts")
	editor.call("_on_category_button_pressed", "mouth")
	var before: String = var_to_str(editor.get("blueprint"))
	for id: String in SNOUTS:
		check(not progress.is_part_unlocked(id), "Snout unlocked without earned profile")
		editor.call("_on_part_button_pressed", id)
		check(var_to_str(editor.get("blueprint")) == before, "Locked snout changed editor")
	for source: String in ["mouth_predator_jaws", "mouth_broad_beak"]:
		var observed: Dictionary = Assembly.create_default()
		observed.parts = []
		Assembly.BaseBlueprint.add_part(observed, source)
		var receipt: Dictionary = progress.register_species_discovery(543 if source == "mouth_predator_jaws" else 544, observed, 43)
		check(receipt.unlocked_part == source, "Discovery granted the wrong base profile")
		if source == "mouth_predator_jaws":
			check(progress.is_part_unlocked(SNOUTS[0]) and not progress.is_part_unlocked(SNOUTS[1]) and not progress.is_part_unlocked(SNOUTS[2]), "Carnivore source unlocked omnivore snouts")
	for id: String in SNOUTS: check(progress.is_part_unlocked(id), "Earned profile did not unlock snout")
	var old: Dictionary = progress.export_state()
	for id: String in SNOUTS: old.unlocked_parts.erase(id)
	var untouched: String = JSON.stringify(old)
	check(progress.import_state(old) and JSON.stringify(old) == untouched, "Migration failed or mutated its input")
	var migrated: Dictionary = progress.export_state()
	check(migrated.discovery_points == old.discovery_points and migrated.discovered_species == old.discovered_species, "Migration changed rewards/discoveries")
	check(progress.import_state(migrated) and progress.export_state() == migrated, "Migration is not idempotent")
	for row: Dictionary in Records.part_rows(migrated, "", "mouth"):
		if row.id in SNOUTS: check(row.unlocked, "Journal lost earned snout")
	for id: String in SNOUTS:
		var design: Dictionary = Assembly.create_default()
		design.parts = []
		editor.set("blueprint", design)
		editor.call("_on_category_button_pressed", "mouth")
		editor.call("_on_part_button_pressed", id)
		check(editor.get("blueprint").parts.size() == 1 and editor.get("blueprint").parts[0].part_id == id, "Editor cannot add snout")
		editor.call("_undo_edit")
		check(editor.get("blueprint").parts.is_empty(), "Undo lost original design")
		editor.call("_redo_edit")
		check(editor.get("blueprint").parts.size() == 1 and editor.get("blueprint").parts[0].part_id == id, "Redo lost snout")
		editor.call("_select_part_by_index", 0)
		editor.call("_change_part_field", 27.0, "rotation", 1)
		editor.call("_change_part_field", 1.2, "scale", 0)
		editor.call("_change_part_field", 0.75, "shape", 2)
		var part: Dictionary = editor.get("blueprint").parts[0]
		check(is_equal_approx(part.rotation.y, 27) and is_equal_approx(part.scale, 1.2) and is_equal_approx(part.shape_scale.z, 0.75), "Editor lost snout transforms")
	editor.free()
	await process_frame


func _design() -> Dictionary:
	var design: Dictionary = super._design()
	for index in range(SNOUTS.size()): design.parts[index + 1].part_id = SNOUTS[index]
	return design


func _save_and_exchange() -> void:
	var design: Dictionary = _design()
	_check_runtime(design)
	check(Assembly.save_to_file(design, SNOUT_SAVE) == OK, "Snout design save failed")
	var package: Dictionary = Package.export_blueprint(design, {"title": "Schnauzenfamilie"})
	check(package.ok, "Portable snout export failed: " + str(package))
	if not package.ok: return
	check(Package.inspect(package.package).ok, "Portable snout package rejected")
	var imported: Dictionary = Designs.add(package.package, "user://snout_library.json")
	check(imported.ok, "Local snout library import failed")
	check(Designs.add(package.package, "user://snout_library.json").ok, "Repeated snout import failed")
	var expected: Dictionary = {"design": Assembly.BaseBlueprint._serialize_blueprint(design), "key": Designs.key_of(package.package),
		"progression": root.get_node("ProgressionService").export_state(), "game": root.get_node("GameState").export_state()}
	var file := FileAccess.open("user://snouts_expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(expected))
	file.close()


func _restart_snouts() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://snouts_expected.json"))
	root.get_node("GameState").import_state(expected.game, false)
	var progress: Node = root.get_node("ProgressionService")
	check(progress.import_state(expected.progression), "Restart rejected progression")
	for id: String in SNOUTS: check(progress.is_part_unlocked(id), "Restart lost earned snout")
	var loaded: Dictionary = Assembly.load_from_file(SNOUT_SAVE)
	check(JSON.parse_string(JSON.stringify(Assembly.BaseBlueprint._serialize_blueprint(loaded))) == expected.design, "Restart changed design ID/revision/parts/colors")
	_check_runtime(loaded)
	var library: Dictionary = Designs.read("user://snout_library.json")
	check(library.ok and library.packages.size() == 1, "Offline library lost or duplicated package")
	var found: Dictionary = Designs.get_package(expected.key, "user://snout_library.json")
	check(found.ok, "Offline package unavailable")
	if found.ok:
		var prepared: Dictionary = Package.prepare_import(found.package, Assembly.create_default(), 0, progress.get_unlocked_part_ids())
		check(prepared.ok, "Offline snout package could not be used")
