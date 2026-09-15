extends "res://tests/creature_foot_provider_test.gd"
const Tails = preload("res://creatures/catalog/creature_tail_catalog.gd")
const TailGeometry = preload("res://creatures/editor/creature_tail_geometry.gd")
const Revisions = preload("res://creatures/catalog/creature_part_revisions.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const Copy = preload("res://ui/discovery/journal_presentation.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Designs = preload("res://assembly/exchange/creature_design_library.gd")
const IDS: Array[String] = ["tail_stump", "tail_reptile", "tail_beaver_paddle", "tail_horizontal_fluke"]
const COUNTS: Array[int] = [2, 9, 11, 8]
const ENGLISH: Array[String] = ["Stump tail", "Reptile tail", "Beaver paddle", "Horizontal tail fluke"]
const LIBRARY_FILE: String = "user://tail_library.json"
const EXPECTED_FILE: String = "user://tail_expected.json"
var checks: int = 0


func run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--restart-tails" in OS.get_cmdline_user_args():
		_restart()
	else:
		_check_catalog()
		_baseline()
		_models()
		for id: String in IDS: _check_preview(id)
		await _editor()
		_save()
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/creature_tail_family_test.gd", "--", "--restart-tails"], output, true)
		check(status == 0 and str(output).contains("TAIL_RESTART_PASSED") and not str(output).contains("SCRIPT ERROR"), "Tail restart failed: " + str(output))
	for problem: String in failures: push_error(problem)
	if failures.is_empty(): print(("TAIL_RESTART_PASSED" if "--restart-tails" in OS.get_cmdline_user_args() else "TAIL_FAMILY_PASSED") + ": %d checks; 4 models, 24 frozen meshes, 30 frozen species" % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	super.check(condition, message)


func _model(id: String, shape: Vector3 = Vector3.ONE, side: float = 1.0, revision: int = 1) -> Node3D:
	var node := Node3D.new()
	node.set_meta("creature_part_side", side)
	Snapshot.Geometry.build(node, {"id": id}, {"category": "tail", "shape_scale": shape, "part_revision": revision}, Assembly.BaseBlueprint.create_default())
	return node


func _baseline() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_tails_v1.json"))
	check(expected.size() == 24, "Incomplete pre-provider tail baseline")
	for id: String in Tails.LEGACY_IDS:
		for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9)]:
			for side: float in [-1.0, 1.0]:
				var model: Node3D = _model(id, shape, side)
				check(JSON.stringify(Snapshot.describe(model)).sha256_text() == expected["%s:%s:%d" % [id, shape, int(side)]], "Legacy tail mesh/color/transform changed: " + id)
				model.free()
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_mouths_v1.json")).species
	check(frozen.size() == 30, "Incomplete frozen species baseline")
	for seed_value: int in [1, 17, 42, 977, 8192]:
		for role: String in Species.ECOLOGICAL_ROLES:
			var design: Dictionary = Species.create_species(seed_value, Vector2i(13, -7), role)
			check(JSON.stringify(Assembly.BaseBlueprint._serialize_blueprint(design)).sha256_text() == frozen["%d:%s" % [seed_value, role]], "Tail variants regenerated an existing species")


func _models() -> void:
	# Newly shipped revision-1 recipes are frozen too, after visual acceptance.
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_tail_families_v1.json"))
	check(frozen.size() == 24, "Incomplete revision-1 family fixture")
	var signatures: Dictionary = {}
	for id: String in Tails.LEGACY_IDS + IDS:
		var node: Node3D = _model(id)
		var meshes: Array = Snapshot.describe(node)
		for entry: Dictionary in meshes:
			entry.erase("name")
			entry.erase("color")
		var signature: String = JSON.stringify(meshes).sha256_text()
		check(not signatures.has(signature), "Tail is only a rename/recolor: " + id)
		signatures[signature] = id
		node.free()
	for index in range(IDS.size()):
		var id: String = IDS[index]
		var profile: Dictionary = Tails.get_profile(id)
		var definition: Dictionary = Library.get_part(id)
		var source: Dictionary = Library.get_part("tail_balance" if index < 2 else "tail_fin")
		check(definition.stats == source.stats and definition.complexity == source.complexity and definition.default_scale == source.default_scale, "Tail invented new gameplay values: " + id)
		check(profile.unlock_source == source.id and profile.capabilities.is_empty() and profile.supported_actions.is_empty(), "Tail granted unsupported actions/unlock")
		check(profile.attachment == "body_surface" and profile.forward == "+Z", "Wrong attachment direction")
		check(Copy.part(id, "name", "de") == profile.name and Copy.part(id, "name", "en") == ENGLISH[index], "DE/EN tail label missing")
		check(Copy.part(id, "description", "de") == profile.description and Copy.part(id, "description", "en") != profile.description, "DE/EN tail description missing")
		profile.features.clear()
		definition.stats.clear()
		check(not Tails.get_profile(id).features.is_empty() and Library.get_part(id).stats == source.stats, "Caller mutated tail profile")
		check(Revisions.resolve(id, {}) == {"geometry_id": id, "geometry_revision": 1}, "Missing revision did not resolve to shipped model")
		for revision: int in [0, 2, 99]:
			var future: Node3D = _model(id, Vector3.ONE, 1, revision)
			check(Tails.get_profile(id, revision).is_empty() and TailGeometry.recipe(id, Color.WHITE, Color.WHITE, Color.WHITE, revision).is_empty() and future.get_child_count() == 0, "Unsupported tail revision rendered a fallback")
			future.free()
		for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9)]:
			var left: Node3D = _model(id, shape, 1)
			var right: Node3D = _model(id, shape, -1)
			check(left.get_child_count() == COUNTS[index] and TailGeometry.legacy_voxels(id).size() == COUNTS[index], "Tail exceeded fixed mesh budget")
			for model: Node3D in [left, right]:
				var key: String = "%s:%s:%d" % [id, shape, int(model.get_meta("creature_part_side"))]
				check(JSON.stringify(Snapshot.describe(model)).sha256_text() == frozen[key], "Pinned revision-1 tail changed: " + id)
			for child: MeshInstance3D in left.get_children():
				var mirrored: MeshInstance3D = right.get_node(NodePath(str(child.name)))
				check(child.transform.is_finite() and (child.position * Vector3(-1, 1, 1)).is_equal_approx(mirrored.position), "Tail did not reflect its position")
				check(child.mesh.get_aabb().size.is_equal_approx(mirrored.mesh.get_aabb().size) and (child.basis.y * Vector3(-1, 1, 1)).is_equal_approx(mirrored.basis.y), "Tail mirror changed size/direction")
			left.free()
			right.free()
	for id: String in ["tail_future", "", "feet_pads"]:
		check(Tails.get_profile(id).is_empty() and TailGeometry.recipe(id, Color.WHITE, Color.WHITE, Color.WHITE).is_empty(), "Unknown tail substituted")
	var unknown: Node3D = _model("tail_future")
	check(unknown.get_child_count() == 0, "Common renderer substituted unknown tail")
	unknown.free()


func _editor() -> void:
	var progress: Node = root.get_node("ProgressionService")
	root.get_node("GameState").set_world_seed(44)
	progress.reset_for_new_game()
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16): await process_frame
	editor.set("blueprint", Assembly.create_default())
	editor.call("_set_mode", "parts")
	editor.call("_on_category_button_pressed", "tail")
	var before: String = var_to_str(editor.get("blueprint"))
	for id: String in IDS.slice(2):
		check(not progress.is_part_unlocked(id), "Fin variant unlocked before discovery")
		editor.call("_on_part_button_pressed", id)
		check(var_to_str(editor.get("blueprint")) == before, "Locked tail changed editor")
	for id: String in IDS.slice(0, 2): check(progress.is_part_unlocked(id), "Starter balance variant unavailable")
	var observed: Dictionary = Assembly.create_default()
	observed.parts = []
	Assembly.BaseBlueprint.add_part(observed, "tail_fin")
	var receipt: Dictionary = progress.register_species_discovery(545, observed, 44)
	check(receipt.unlocked_part == "tail_fin" and progress.discovery_points == 3, "Tail variant changed discovery reward")
	for id: String in IDS: check(progress.is_part_unlocked(id), "Earned source did not expose tail variant")
	var state: Dictionary = progress.export_state()
	for row: Dictionary in Records.part_rows(state, "", "tail"):
		if row.id in IDS: check(row.unlocked, "Journal disagrees with editor unlock")
	var old: Dictionary = state.duplicate(true)
	for id: String in IDS: old.unlocked_parts.erase(id)
	var untouched: String = JSON.stringify(old)
	check(progress.import_state(old) and JSON.stringify(old) == untouched, "Old unlock migration mutated its input")
	var migrated: Dictionary = progress.export_state()
	check(migrated.discovery_points == old.discovery_points and migrated.discovered_species == old.discovered_species, "Migration changed rewards/discoveries")
	check(progress.import_state(migrated) and progress.export_state() == migrated, "Unlock migration not idempotent")
	for id: String in IDS:
		var design: Dictionary = Assembly.create_default()
		design.parts = []
		editor.set("blueprint", design)
		editor.call("_on_category_button_pressed", "tail")
		editor.call("_on_part_button_pressed", id)
		check(editor.get("blueprint").parts.size() == 1 and editor.get("blueprint").parts[0].part_id == id, "Editor could not add tail")
		editor.call("_undo_edit")
		check(editor.get("blueprint").parts.is_empty(), "Tail undo failed")
		editor.call("_redo_edit")
		check(editor.get("blueprint").parts.size() == 1 and editor.get("blueprint").parts[0].part_id == id, "Tail redo failed")
		editor.call("_select_part_by_index", 0)
		editor.call("_change_part_field", 27.0, "rotation", 1)
		editor.call("_change_part_field", 1.2, "scale", 0)
		for axis in range(3): editor.call("_change_part_field", 0.8 + float(axis) * 0.2, "shape", axis)
		var part: Dictionary = editor.get("blueprint").parts[0]
		check(is_equal_approx(part.rotation.y, 27) and is_equal_approx(part.scale, 1.2) and part.shape_scale.is_equal_approx(Vector3(0.8, 1.0, 1.2)), "Editor lost tail transforms")
	editor.free()
	await process_frame


func _design(id: String) -> Dictionary:
	var design: Dictionary = Assembly.create_default()
	design.parts = []
	Assembly.BaseBlueprint.add_part(design, "legs_walker")
	Assembly.BaseBlueprint.add_part(design, id)
	Anatomy.reset_all_anchors(design)
	design.parts[1].rotation = Vector3(18, -23, 12)
	design.parts[1].scale = 1.15
	design.parts[1].shape_scale = Vector3(0.8, 1.1, 1.4)
	Anatomy.rebind_all_parts(design)
	return design


func _runtime(design: Dictionary) -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	parent.transform = Transform3D(Basis.from_euler(Vector3(0.9, -0.7, 0.4)), Vector3(1500, -700, 2300))
	var preview := Preview.new()
	parent.add_child(preview)
	preview.set_editor_state(design, -1, -1, false)
	var tails: Array[Node3D] = []
	for child: Node in preview.get_children():
		if child is Node3D and str(child.get_meta("creature_part_category", "")) == "tail": tails.append(child)
	check(tails.size() == 1, "Runtime lost saved tail")
	var before: String = var_to_str(design)
	var poses: Array[String] = []
	for mode: String in ["idle", "walk", "run"]:
		preview.set_motion(mode)
		preview.set_process(false)
		for time: float in [0.0, 0.19, 0.47, 0.81]:
			preview._motion.sample(mode, time)
			for tail: Node3D in tails:
				check(tail.global_transform.is_finite() and tail.get_child_count() > 0 and tail.get_meta("geometry_id") == design.parts[1].part_id and tail.get_meta("geometry_revision") == 1, "Tail detached/lost pinned model")
				var lowest: float = INF
				for mesh: Node in tail.get_children():
					if not mesh is MeshInstance3D: continue
					var bounds: AABB = mesh.mesh.get_aabb()
					for corner in range(8):
						lowest = minf(lowest, preview.to_local(mesh.to_global(bounds.get_endpoint(corner))).y)
				check(lowest >= float(preview.get_meta("ground_y")) - 0.002, "Authored test tail crosses its radial ground plane")
				poses.append(var_to_str(tail.rotation))
			check(preview._motion._legs.size() == 2, "Tail counted as supporting leg")
	check(not poses.is_empty() and poses[0] != poses[-1], "Tail did not move with body animation")
	check(var_to_str(design) == before, "Animation rewrote authoring data")
	parent.free()


func _save() -> void:
	var expected: Dictionary = {"designs": {}, "keys": {}, "meshes": {}, "progression": root.get_node("ProgressionService").export_state(), "game": root.get_node("GameState").export_state()}
	for id: String in IDS:
		var design: Dictionary = _design(id)
		_runtime(design)
		var path: String = "user://" + id + ".json"
		check(Assembly.save_to_file(design, path) == OK, "Tail save failed")
		var saved: String = FileAccess.get_file_as_string(path)
		var future: Dictionary = design.duplicate(true)
		future.parts[1].part_revision = 2
		check(Assembly.save_to_file(future, path) != OK and FileAccess.get_file_as_string(path) == saved, "Future tail overwrote existing design")
		var package: Dictionary = Package.export_blueprint(design, {"title": id})
		check(package.ok and Package.inspect(package.get("package", {})).ok, "Tail package export/validation failed")
		if not package.ok: continue
		check(Designs.add(package.package, LIBRARY_FILE).ok and Designs.add(package.package, LIBRARY_FILE).ok, "Tail library import/dedup failed")
		expected.designs[id] = Assembly.serialize_snapshot(design)
		expected.keys[id] = Designs.key_of(package.package)
		var model: Node3D = _model(id)
		expected.meshes[id] = JSON.stringify(Snapshot.describe(model)).sha256_text()
		model.free()
	var file := FileAccess.open(EXPECTED_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(expected))
	file.close()


func _restart() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED_FILE))
	root.get_node("GameState").import_state(expected.game, false)
	var progress: Node = root.get_node("ProgressionService")
	check(progress.import_state(expected.progression), "Restart rejected progression")
	var library: Dictionary = Designs.read(LIBRARY_FILE)
	check(library.ok and library.packages.size() == 4, "Restart lost or duplicated tail packages")
	for id: String in IDS:
		check(progress.is_part_unlocked(id), "Restart lost tail unlock")
		var design: Dictionary = Assembly.load_from_file("user://" + id + ".json")
		check(JSON.parse_string(JSON.stringify(Assembly.serialize_snapshot(design))) == expected.designs[id], "Restart changed tail ID/revisions/UID/shape/color")
		check(design.parts[1].part_revision == 1 and design.parts[1].catalog_revision == 1, "Saved tail references not pinned")
		var model: Node3D = _model(id)
		check(JSON.stringify(Snapshot.describe(model)).sha256_text() == expected.meshes[id], "Restart changed rendered tail")
		model.free()
		_runtime(design)
		var found: Dictionary = Designs.get_package(expected.keys[id], LIBRARY_FILE)
		check(found.ok, "Offline tail package unavailable")
		if found.ok:
			var prepared: Dictionary = Package.prepare_import(found.package, Assembly.create_default(), 0, progress.get_unlocked_part_ids())
			check(prepared.ok, "Offline tail package could not be used")
