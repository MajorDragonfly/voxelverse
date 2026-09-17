extends "res://tests/creature_foot_provider_test.gd"
const Ornaments = preload("res://creatures/catalog/creature_ornament_catalog.gd")
const OrnamentGeometry = preload("res://creatures/editor/creature_ornament_geometry.gd")
const Revisions = preload("res://creatures/catalog/creature_part_revisions.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const Copy = preload("res://ui/discovery/journal_presentation.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Designs = preload("res://assembly/exchange/creature_design_library.gd")
const IDS: Array[String] = ["horns_stag_antlers", "horns_moose_antlers", "decor_low_crest", "decor_saw_crest", "decor_head_crest", "decor_frill"]
const ENGLISH: Array[String] = ["Stag antlers", "Palmate antlers", "Low dorsal crest", "Serrated dorsal crest", "Head crest", "Neck frill"]
const LIBRARY_FILE: String = "user://ornament_library.json"
const EXPECTED_FILE: String = "user://ornament_expected.json"
var checks: int = 0


func run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("SaveGameService")._loaded_once = true
	if "--restart-ornaments" in OS.get_cmdline_user_args():
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
			"--script", "res://tests/creature_ornament_families_test.gd", "--", "--restart-ornaments"], output, true)
		check(status == 0 and str(output).contains("ORNAMENT_RESTART_PASSED") and not str(output).contains("ERROR"), "Ornament restart failed: " + str(output))
		if status == 0: print(str(output).strip_edges())
	for problem: String in failures: push_error(problem)
	if failures.is_empty(): print(("ORNAMENT_RESTART_PASSED" if "--restart-ornaments" in OS.get_cmdline_user_args() else "ORNAMENT_FAMILY_PASSED") + ": %d checks; 6 models, 30 frozen species" % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	super.check(condition, message)


func _model(id: String, shape: Vector3 = Vector3.ONE, side: float = 1.0, revision: int = 1) -> Node3D:
	var node := Node3D.new()
	node.set_meta("creature_part_side", side)
	Snapshot.Geometry.build(node, {"id": id}, {"category": Library.get_part(id).get("category", "horns"), "shape_scale": shape, "part_revision": revision}, Assembly.BaseBlueprint.create_default())
	return node


func _baseline() -> void:
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_mouths_v1.json")).species
	check(frozen.size() == 30, "Incomplete frozen species baseline")
	for seed_value: int in [1, 17, 42, 977, 8192]:
		for role: String in Species.ECOLOGICAL_ROLES:
			var design: Dictionary = Species.create_species(seed_value, Vector2i(13, -7), role)
			check(JSON.stringify(Assembly.BaseBlueprint._serialize_blueprint(design)).sha256_text() == frozen["%d:%s" % [seed_value, role]], "Ornament variants regenerated an existing species")


func _models() -> void:
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_ornament_families_v1.json"))
	check(frozen.size() == 60, "Incomplete revision-1 ornament fixture")
	var signatures: Dictionary = {}
	for id: String in IDS:
		var node: Node3D = _model(id)
		var meshes: Array = Snapshot.describe(node)
		for entry: Dictionary in meshes:
			entry.erase("name")
			entry.erase("color")
		var signature: String = JSON.stringify(meshes).sha256_text()
		check(not signatures.has(signature), "Ornament is only a rename/recolor: " + id)
		signatures[signature] = id
		node.free()
	for index in range(IDS.size()):
		var id: String = IDS[index]
		var profile: Dictionary = Ornaments.get_profile(id)
		var definition: Dictionary = Library.get_part(id)
		var source: Dictionary = Library.get_part(profile.stats_source)
		check(definition.stats == source.stats and definition.complexity == source.complexity and definition.default_scale == source.default_scale, "Ornament invented new gameplay values: " + id)
		check(profile.unlock_source == source.id and profile.capabilities.is_empty() and profile.supported_actions.is_empty(), "Ornament granted unsupported actions/unlock")
		check(Copy.part(id, "name", "de") == profile.name and Copy.part(id, "name", "en") == ENGLISH[index], "DE/EN ornament label missing")
		check(Copy.part(id, "description", "de") == profile.description and Copy.part(id, "description", "en") != profile.description, "DE/EN ornament description missing")
		profile.capabilities.append("invented")
		definition.stats.clear()
		check(Ornaments.get_profile(id).capabilities.is_empty() and Library.get_part(id).stats == source.stats, "Caller mutated ornament profile")
		check(Revisions.resolve(id, {}) == {"geometry_id": id, "geometry_revision": 1}, "Missing revision did not resolve to shipped model")
		for revision: int in [0, 2, 99]:
			var future: Node3D = _model(id, Vector3.ONE, 1, revision)
			check(Ornaments.get_profile(id, revision).is_empty() and OrnamentGeometry.mesh(id, Color.WHITE, Color.WHITE, Color.WHITE, Vector3.ONE, 1, revision).get_surface_count() == 0 and future.get_child_count() == 0, "Unsupported ornament revision rendered a fallback")
			future.free()
		for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9), Vector3(0.4, 2.5, 0.4), Vector3(2.5, 0.4, 2.5)]:
			var left: Node3D = _model(id, shape, 1)
			var right: Node3D = _model(id, shape, -1)
			check(left.get_child_count() == 1 and right.get_child_count() == 1, "Ornament exceeded one-mesh node budget")
			for model: Node3D in [left, right]:
				var key: String = "%s:%s:%d" % [id, shape, int(model.get_meta("creature_part_side"))]
				check(_signature(model) == frozen[key], "Pinned revision-1 ornament changed: " + id)
			var cells: Dictionary = left.get_child(0).mesh.get_meta("voxel_cells")
			var reflected: Dictionary = right.get_child(0).mesh.get_meta("voxel_cells")
			check(cells.size() > 100 and cells.size() < 100000 and cells.size() == reflected.size(), "Invalid ornament volume budget: %s/%s/%d" % [id, shape, cells.size()])
			var all_mirrored: bool = true
			for cell: Vector3i in cells:
				if not reflected.has(Vector3i(-cell.x - 1, cell.y, cell.z)): all_mirrored = false
			check(all_mirrored, "Ornament occupancy did not mirror: " + id)
			check(_connected(cells), "Ornament contains detached voxel pieces: %s/%s" % [id, shape])
			left.free()
			right.free()
	for shape: Vector3 in [Vector3.ZERO, Vector3(-1, 1, 1), Vector3(NAN, 1, 1), Vector3(1, INF, 1), Vector3(0.39, 1, 1), Vector3(1, 2.51, 1)]:
		check(OrnamentGeometry.mesh(IDS[0], Color.WHITE, Color.WHITE, Color.WHITE, shape).get_surface_count() == 0, "Invalid ornament shape rendered or expanded sampling budget")
	check(OrnamentGeometry._cache.size() <= OrnamentGeometry.CACHE_LIMIT, "Unbounded ornament mesh cache")
	for id: String in ["mouth_future", "", "feet_pads"]:
		check(Ornaments.get_profile(id).is_empty() and OrnamentGeometry.mesh(id, Color.WHITE, Color.WHITE, Color.WHITE).get_surface_count() == 0, "Unknown ornament substituted")
	var unknown: Node3D = _model("mouth_future")
	check(unknown.get_child_count() == 0, "Common renderer substituted unknown ornament")
	unknown.free()


func _connected(cells: Dictionary) -> bool:
	if cells.is_empty(): return false
	var queue: Array[Vector3i] = [cells.keys()[0]]
	var seen: Dictionary = {queue[0]: true}
	var index: int = 0
	while index < queue.size():
		var cell: Vector3i = queue[index]
		index += 1
		for step: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor: Vector3i = cell + step
			if cells.has(neighbor) and not seen.has(neighbor):
				seen[neighbor] = true
				queue.append(neighbor)
	return seen.size() == cells.size()


func _editor() -> void:
	var progress: Node = root.get_node("ProgressionService")
	root.get_node("LocaleManager")._apply("de")
	root.get_node("GameState").set_world_seed(48)
	progress.reset_for_new_game()
	progress.merge_unlocked_parts(["horns_antlers"])
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16): await process_frame
	editor.set("blueprint", Assembly.create_default())
	editor.call("_set_mode", "parts")
	for id: String in IDS:
		check(progress.is_part_unlocked(id), "Existing feather profile did not expose ornament model")
		check(progress.export_state().unlocked_parts[id].source_part == Ornaments.get_profile(id).unlock_source, "Ornament changed the source unlock")
	check(progress.discovery_points == 0, "Starter ornaments granted points")
	var state: Dictionary = progress.export_state()
	for row: Dictionary in Records.part_rows(state):
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
		editor.call("_on_category_button_pressed", Library.get_part(id).category)
		editor.call("_on_part_button_pressed", id)
		check(editor.get("blueprint").parts.size() == 1 and editor.get("blueprint").parts[0].part_id == id, "Editor could not add ornament")
		check(editor.get("blueprint").parts[0].mirrored == Ornaments.get_profile(id).default_mirrored, "Ornament default pair/center mismatch")
		editor.call("_undo_edit")
		check(editor.get("blueprint").parts.is_empty(), "Ornament undo failed")
		editor.call("_redo_edit")
		check(editor.get("blueprint").parts.size() == 1 and editor.get("blueprint").parts[0].part_id == id, "Ornament redo failed")
		editor.call("_select_part_by_index", 0)
		editor.call("_change_part_field", 27.0, "rotation", 1)
		editor.call("_change_part_field", 1.2, "scale", 0)
		for axis in range(3): editor.call("_change_part_field", 0.8 + float(axis) * 0.2, "shape", axis)
		var part: Dictionary = editor.get("blueprint").parts[0]
		check(is_equal_approx(part.rotation.y, 27) and is_equal_approx(part.scale, 1.2) and part.shape_scale.is_equal_approx(Vector3(0.8, 1.0, 1.2)), "Editor lost ornament transforms")
		for mode: String in ["paired", "single", "center", "paired"]:
			editor.call("_set_placement_mode", mode)
			part = editor.get("blueprint").parts[0]
			check(part.mirrored == (mode == "paired") and part.center_locked == (mode == "center"), "Ornament placement mode not preserved")
			var roots: Array = editor.get("_preview").get_children().filter(func(node: Node) -> bool: return node.get_meta("geometry_id", "") == id)
			check(roots.size() == (2 if mode == "paired" else 1), "Editor rendered wrong ornament count")

	editor.free()
	await process_frame


func _design(id: String) -> Dictionary:
	var design: Dictionary = Assembly.create_default()
	Assembly.BaseBlueprint.add_part(design, "legs_walker")
	Assembly.BaseBlueprint.add_part(design, id)
	Anatomy.reset_all_anchors(design)
	preload("res://creatures/editor/creature_surface_sockets_v7.gd").apply_symmetry(design, design.parts.size() - 1, IDS.find(id) % 3 == 0)
	design.parts.back().center_locked = IDS.find(id) % 3 == 2
	design.parts.back().rotation = Vector3(18, -23, 12)
	design.parts.back().scale = 1.15
	design.parts.back().shape_scale = Vector3(0.8, 1.1, 1.4)
	Anatomy.rebind_all_parts(design)
	return design


func _runtime(design: Dictionary) -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	parent.transform = Transform3D(Basis.from_euler(Vector3(0.9, -0.7, 0.4)), Vector3(1500, -700, 2300))
	var preview := Preview.new()
	parent.add_child(preview)
	preview.set_editor_state(design, -1, -1, false)
	var ornaments: Array[Node3D] = []
	for child: Node in preview.get_children():
		if child is Node3D and str(child.get_meta("geometry_id", "")) == design.parts.back().part_id: ornaments.append(child)
	check(ornaments.size() == (2 if design.parts.back().mirrored else 1), "Runtime lost saved ornament: %s/%d" % [design.parts.back().part_id, ornaments.size()])
	var report: Dictionary = Body.inspect_rest(preview)
	check(report.leg_count == 4 and report.all_feet_on_plane, "Ornament affected four-legged rest contact")
	var skin: MeshInstance3D = preview.get_node("BodyV4/SculptedSkin")
	var body_cells: Dictionary = skin.mesh.get_meta("voxel_cells")
	var body_step: float = skin.mesh.get_meta("voxel_size")
	for ornament: Node3D in ornaments:
		var surface: MeshInstance3D = ornament.get_node("OrnamentSurface")
		var cells: Dictionary = surface.mesh.get_meta("voxel_cells")
		var step: float = surface.mesh.get_meta("voxel_size")
		var space: Transform3D = skin.global_transform.affine_inverse() * surface.global_transform
		var inside: int = 0
		for cell: Vector3i in cells:
			var center: Vector3 = space * ((Vector3(cell) + Vector3.ONE * 0.5) * step)
			if body_cells.has(Vector3i((center / body_step).floor())): inside += 1
		check(inside > 0 and inside < cells.size(), "Ornament floats outside or is fully buried in the body")
	var before: String = var_to_str(design)
	var poses: Array[String] = []
	var attachments: Array[Transform3D] = []
	for ornament: Node3D in ornaments: attachments.append(ornament.transform)
	for mode: String in ["idle", "walk", "run"]:
		preview.set_motion(mode)
		preview.set_process(false)
		for time: float in [0.0, 0.19, 0.47, 0.81]:
			preview._motion.sample(mode, time)
			for ornament: Node3D in ornaments:
				check(ornament.transform.is_equal_approx(attachments[ornaments.find(ornament)]), "Rigid ornament moved away from its body anchor")
				check(ornament.global_transform.is_finite() and ornament.get_child_count() > 0 and ornament.get_meta("geometry_id") == design.parts.back().part_id and ornament.get_meta("geometry_revision") == 1, "Ornament detached/lost pinned model")
				var lowest: float = INF
				for mesh: Node in ornament.get_children():
					if not mesh is MeshInstance3D: continue
					var bounds: AABB = mesh.mesh.get_aabb()
					for corner in range(8):
						lowest = minf(lowest, preview.to_local(mesh.to_global(bounds.get_endpoint(corner))).y)
				check(lowest >= float(preview.get_meta("ground_y")) - 0.002, "Authored test ornament crosses its radial ground plane")
				if ornament == ornaments[0]: poses.append(var_to_str(ornament.global_transform))
			check(preview._motion._legs.size() == 4, "Ornament counted as supporting leg")
	check(not poses.is_empty() and poses[0] != poses[-1], "Ornament did not move with body animation")
	check(var_to_str(design) == before, "Animation rewrote authoring data")
	parent.free()


func _save() -> void:
	var expected: Dictionary = {"designs": {}, "keys": {}, "meshes": {}, "progression": root.get_node("ProgressionService").export_state(), "game": root.get_node("GameState").export_state()}
	for id: String in IDS:
		var initial: Dictionary = Assembly.create_default()
		Assembly.BaseBlueprint.add_part(initial, "legs_walker")
		Assembly.BaseBlueprint.add_part(initial, id)
		Anatomy.reset_all_anchors(initial)
		_runtime(initial)
		var design: Dictionary = _design(id)
		_runtime(design)
		var path: String = "user://" + id + ".json"
		check(Assembly.save_to_file(design, path) == OK, "Ornament save failed")
		var saved: String = FileAccess.get_file_as_string(path)
		var future: Dictionary = design.duplicate(true)
		future.parts.back().part_revision = 2
		check(Assembly.save_to_file(future, path) != OK and FileAccess.get_file_as_string(path) == saved, "Future ornament overwrote existing design")
		check(not Package.export_blueprint(future).ok, "Future ornament exported as revision 1")
		var package: Dictionary = Package.export_blueprint(design, {"title": id})
		check(package.ok and Package.inspect(package.get("package", {})).ok, "Ornament package export/validation failed")
		if not package.ok: continue
		check(Designs.add(package.package, LIBRARY_FILE).ok and Designs.add(package.package, LIBRARY_FILE).ok, "Ornament library import/dedup failed")
		var unlocked: Array = root.get_node("ProgressionService").get_unlocked_part_ids()
		unlocked.erase(id)
		check(not Package.prepare_import(package.package, Assembly.create_default(), 0, unlocked).ok, "Locked ornament imported without unlock")
		expected.designs[id] = Assembly.serialize_snapshot(design)
		expected.keys[id] = Designs.key_of(package.package)
		var model: Node3D = _model(id)
		expected.meshes[id] = _signature(model)
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
	check(library.ok and library.packages.size() == 6, "Restart lost or duplicated ornament packages")
	for id: String in IDS:
		check(progress.is_part_unlocked(id), "Restart lost ornament unlock")
		var design: Dictionary = Assembly.load_from_file("user://" + id + ".json")
		check(JSON.parse_string(JSON.stringify(Assembly.serialize_snapshot(design))) == expected.designs[id], "Restart changed ornament ID/revisions/UID/shape/color")
		check(design.parts.back().part_revision == 1 and design.parts.back().catalog_revision == 1, "Saved ornament references not pinned")
		var model: Node3D = _model(id)
		check(_signature(model) == expected.meshes[id], "Restart changed rendered ornament")
		model.free()
		_runtime(design)
		var found: Dictionary = Designs.get_package(expected.keys[id], LIBRARY_FILE)
		check(found.ok, "Offline ornament package unavailable")
		if found.ok:
			var current: Dictionary = Assembly.create_default()
			var prepared: Dictionary = Package.prepare_import(found.package, current, 0, progress.get_unlocked_part_ids())
			check(prepared.ok, "Offline ornament package could not be used")
			if prepared.ok: check(prepared.blueprint.design_id == current.design_id, "Template replaced receiving species identity")


func _signature(model: Node3D) -> String:
	var arrays: Array = model.get_child(0).mesh.surface_get_arrays(0)
	return JSON.stringify({"geometry": Snapshot.describe(model), "colors": arrays[Mesh.ARRAY_COLOR].to_byte_array().hex_encode().sha256_text()}).sha256_text()
