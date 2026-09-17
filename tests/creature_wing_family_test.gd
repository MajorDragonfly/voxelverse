extends "res://tests/creature_foot_provider_test.gd"
const Wings = preload("res://creatures/catalog/creature_wing_catalog.gd")
const WingGeometry = preload("res://creatures/editor/creature_wing_geometry.gd")
const Revisions = preload("res://creatures/catalog/creature_part_revisions.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const Copy = preload("res://ui/discovery/journal_presentation.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Designs = preload("res://assembly/exchange/creature_design_library.gd")
const IDS: Array[String] = ["wings_broad_feather", "wings_slender_feather", "wings_bat_membrane", "wings_long_insect"]
const ENGLISH: Array[String] = ["Broad feathered wing", "Slender feathered wing", "Bat wing", "Long insect wing"]
const LIBRARY_FILE: String = "user://wing_library.json"
const EXPECTED_FILE: String = "user://wing_expected.json"
const Joints = preload("res://creatures/runtime/creature_part_articulation.gd")
const SHAPES: Array[Vector3] = [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9), Vector3(0.4, 2.5, 0.4), Vector3(2.5, 0.4, 2.5)]
var checks: int = 0


func run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--restart-wings" in OS.get_cmdline_user_args():
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
			"--script", "res://tests/creature_wing_family_test.gd", "--", "--restart-wings"], output, true)
		check(status == 0 and str(output).contains("WING_RESTART_PASSED") and not str(output).contains("SCRIPT ERROR"), "Wing restart failed: " + str(output))
	for problem: String in failures: push_error(problem)
	if failures.is_empty(): print(("WING_RESTART_PASSED" if "--restart-wings" in OS.get_cmdline_user_args() else "WING_FAMILY_PASSED") + ": %d checks; 4 models, 40 frozen meshes, 30 frozen species" % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	super.check(condition, message)


func _model(id: String, shape: Vector3 = Vector3.ONE, side: float = 1.0, revision: int = 1) -> Node3D:
	var node := Node3D.new()
	node.set_meta("creature_part_side", side)
	Snapshot.Geometry.build(node, {"id": id}, {"category": "wings", "shape_scale": shape, "part_revision": revision}, Assembly.BaseBlueprint.create_default())
	return node


func _baseline() -> void:
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_mouths_v1.json")).species
	check(frozen.size() == 30, "Incomplete frozen species baseline")
	for seed_value: int in [1, 17, 42, 977, 8192]:
		for role: String in Species.ECOLOGICAL_ROLES:
			var design: Dictionary = Species.create_species(seed_value, Vector2i(13, -7), role)
			check(JSON.stringify(Assembly.BaseBlueprint._serialize_blueprint(design)).sha256_text() == frozen["%d:%s" % [seed_value, role]], "Wing variants regenerated an existing species")


func _models() -> void:
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_wing_families_v1.json"))
	check(frozen.size() == 40, "Incomplete wing revision fixture")
	var signatures: Dictionary = {}
	for index in range(IDS.size()):
		var id: String = IDS[index]
		var profile: Dictionary = Wings.get_profile(id)
		var source: Dictionary = Library.get_part("decor_feathers")
		var definition: Dictionary = Library.get_part(id)
		check(definition.stats == source.stats and definition.complexity == source.complexity, "Wing invented gameplay values")
		check(profile.capabilities.is_empty() and profile.supported_actions.is_empty() and profile.unlock_source == source.id, "Wing granted flight or unrelated unlock")
		check(Copy.part(id, "name", "de") == profile.name and Copy.part(id, "name", "en") == ENGLISH[index], "Wing label missing")
		check(Copy.part(id, "description", "de") == profile.description and Copy.part(id, "description", "en") != profile.description, "Wing description missing")
		profile.features.clear()
		definition.stats.clear()
		check(not Wings.get_profile(id).features.is_empty() and Library.get_part(id).stats == source.stats, "Mutable catalog leaked")
		check(Revisions.resolve(id, {}) == {"geometry_id": id, "geometry_revision": 1}, "Unpinned wing resolves incorrectly")
		for revision: int in [0, 2, 99]:
			var future := _model(id, Vector3.ONE, 1, revision)
			check(future.get_child_count() == 0 and WingGeometry.meshes(id, Color.WHITE, Color.WHITE, Vector3.ONE, 1, revision).is_empty(), "Future revision rendered a fallback")
			future.free()
		for shape: Vector3 in SHAPES:
			var left := _model(id, shape, 1)
			var right := _model(id, shape, -1)
			check(left.get_child_count() == 2 and right.get_child_count() == 2, "Wing scene budget exceeded")
			for model: Node3D in [left, right]:
				var key: String = "%s:%s:%d" % [id, shape, int(model.get_meta("creature_part_side"))]
				check(fingerprint(model) == frozen[key], "Wing revision changed: " + key)
				for mesh: MeshInstance3D in model.get_children():
					var cells: Dictionary = mesh.mesh.get_meta("voxel_cells")
					check(not cells.is_empty() and cells.size() < 160000 and mesh.mesh.surface_get_array_len(0) < 450000, "Unbounded wing geometry")
					check(_connected(cells), "Disconnected wing surface: " + key + "/" + str(mesh.name))
			for child: MeshInstance3D in left.get_children():
				var opposite: Dictionary = right.get_node(NodePath(str(child.name))).mesh.get_meta("voxel_cells")
				var cells: Dictionary = child.mesh.get_meta("voxel_cells")
				check(cells.size() == opposite.size(), "Wing mirror lost cells")
				var mirrored: bool = true
				for cell: Vector3i in cells:
					if not opposite.has(Vector3i(-cell.x - 1, cell.y, cell.z)): mirrored = false
				check(mirrored, "Wing geometry did not reflect")
			if shape == Vector3.ONE:
				var signature: String = Snapshot.describe(left)[1].vertex_hash
				check(not signatures.has(signature), "Wing family only recolored another shape")
				signatures[signature] = true
			_articulate(left, right)
			left.free()
			right.free()
	for bad: Vector3 in [Vector3.ZERO, Vector3(NAN,1,1), Vector3(3,1,1)]:
		check(WingGeometry.meshes(IDS[0], Color.WHITE, Color.WHITE, bad).is_empty(), "Invalid shape accepted")
	check(Wings.get_profile("wings_future").is_empty() and WingGeometry.meshes("wings_future", Color.WHITE, Color.WHITE).is_empty(), "Unknown wing substituted")


static func fingerprint(model: Node3D) -> String:
	var data: Array = Snapshot.describe(model)
	for index in range(model.get_child_count()):
		var colors: PackedColorArray = model.get_child(index).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		data[index]["vertex_colors"] = colors.to_byte_array().hex_encode().sha256_text()
	return JSON.stringify(data).sha256_text()


func _connected(cells: Dictionary) -> bool:
	if cells.is_empty(): return false
	var queue: Array = [cells.keys()[0]]
	var seen: Dictionary = {queue[0]: true}
	var cursor: int = 0
	while cursor < queue.size():
		var cell: Vector3i = queue[cursor]
		cursor += 1
		for delta: Vector3i in WingGeometry.Voxels.NEIGHBORS:
			var next: Vector3i = cell + delta
			if cells.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size() == cells.size()


func _articulate(left: Node3D, right: Node3D) -> void:
	var a := Joints.new()
	var b := Joints.new()
	a.bind(left)
	b.bind(right)
	var socket: Transform3D = left.get_node("WingSocket").transform
	var mesh: ArrayMesh = left.get_node("WingSurface").mesh
	for pose: float in [0.0, 0.5, 1.0, 0.15]:
		a.set_wing_pose(pose)
		b.set_wing_pose(pose)
		var tip: Vector3 = left.get_node("WingSurface").transform * Vector3(1,0,0)
		var other: Vector3 = right.get_node("WingSurface").transform * Vector3(-1,0,0)
		check((tip * Vector3(-1,1,1)).is_equal_approx(other) and tip.y >= 0, "Wing joint mirror raises only one side")
		var surface: MeshInstance3D = left.get_node("WingSurface")
		var size: float = mesh.get_meta("voxel_size")
		var socket_cells: Dictionary = left.get_node("WingSocket").mesh.get_meta("voxel_cells")
		var attached: bool = false
		for cell: Vector3i in mesh.get_meta("voxel_cells"):
			var point: Vector3 = surface.transform * ((Vector3(cell) + Vector3.ONE * 0.5) * size)
			if socket_cells.has(Vector3i((point / size).floor())):
				attached = true
				break
		check(attached, "Stretched wing detached from its fixed shoulder")
		check(left.get_node("WingSocket").transform == socket and left.get_node("WingSurface").mesh == mesh, "Wing action moved socket/rebuilt geometry")
	a.reset()
	check(a.play("wing_stretch", 1.2) and not a.play("fly"), "Cosmetic stretch/flight contract wrong")
	var peak: float = 0
	for frame in range(150):
		a.advance(1.0/60.0)
		peak = maxf(peak, a.debug_state().wing)
	check(peak > 0.9 and not a.is_active() and left.get_node("WingSurface").transform == Transform3D.IDENTITY, "Stretch did not open and settle")
	a.set_wing_pose(NAN)
	check(a.debug_state().wing == 0, "Nonfinite pose propagated")
	b.unbind()


func _editor() -> void:
	var progress: Node = root.get_node("ProgressionService")
	root.get_node("GameState").set_world_seed(44)
	progress.reset_for_new_game()
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16): await process_frame
	editor.call("_set_mode", "parts")
	var state: Dictionary = progress.export_state()
	var old: Dictionary = state.duplicate(true)
	for id: String in IDS: old.unlocked_parts.erase(id)
	var untouched: String = JSON.stringify(old)
	check(progress.import_state(old) and JSON.stringify(old) == untouched, "Unlock migration mutated input")
	var migrated: Dictionary = progress.export_state()
	check(migrated.discovery_points == old.discovery_points and migrated.discovered_species == old.discovered_species, "Wing migration changed rewards/species")
	check(progress.import_state(migrated) and progress.export_state() == migrated, "Unlock migration not idempotent")
	var rows: Array = Records.part_rows(migrated, "", "wings")
	check(rows.size() == 4, "Journal wing category missing")
	for row: Dictionary in rows: check(row.unlocked, "Journal differs from editor unlock")
	for id: String in IDS:
		check(progress.is_part_unlocked(id), "Source unlock did not expose wing")
		var design: Dictionary = Assembly.create_default()
		design.parts = []
		editor.set("blueprint", design)
		editor.call("_on_category_button_pressed", "wings")
		editor.call("_on_part_button_pressed", id)
		check(editor.get("blueprint").parts.size() == 1 and editor.get("blueprint").parts[0].part_id == id, "Editor did not add wing")
		editor.call("_undo_edit")
		check(editor.get("blueprint").parts.is_empty(), "Wing undo failed")
		editor.call("_redo_edit")
		editor.call("_select_part_by_index", 0)
		for mode: String in ["single", "center", "paired"]:
			editor.call("_set_placement_mode", mode)
			var part: Dictionary = editor.get("blueprint").parts[0]
			check(part.mirrored == (mode == "paired") and part.center_locked == (mode == "center"), "Wing placement mode failed")
		editor.call("_change_part_field", 27.0, "rotation", 1)
		editor.call("_change_part_field", 1.2, "scale", 0)
		for axis in range(3): editor.call("_change_part_field", 0.8 + float(axis)*0.2, "shape", axis)
		var part: Dictionary = editor.get("blueprint").parts[0]
		check(is_equal_approx(part.rotation.y, 27) and part.shape_scale.is_equal_approx(Vector3(0.8,1,1.2)), "Editor lost wing transforms")
		var before: String = var_to_str(editor.get("blueprint"))
		var button: Button = editor.get("_part_controls").get_node("StretchWings")
		check(button.visible, "Wing stretch control hidden")
		button.pressed.emit()
		check(editor.get("_preview")._articulation.debug_state().action == "wing_stretch", "Editor stretch did not reach shared animation")
		check(var_to_str(editor.get("blueprint")) == before, "Stretch modified save data")
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
	parent.transform = Transform3D(Basis.from_euler(Vector3(0.9,-0.7,0.4)), Vector3(1500,-700,2300))
	var preview := Preview.new()
	parent.add_child(preview)
	preview.set_editor_state(design, -1, -1, false)
	preview.set_process(false)
	var wings: Array[Node3D] = []
	for child: Node in preview.get_children():
		if child is Node3D and child.get_meta("creature_part_category", "") == "wings": wings.append(child)
	check(wings.size() == 2, "Saved wing pair lost")
	var rest: Dictionary = Body.inspect_rest(preview)
	check(rest.leg_count == 2 and rest.all_feet_on_plane, "Wings changed support feet")
	var before: String = var_to_str(design)
	for mode: String in ["idle", "walk", "run"]:
		preview.set_motion(mode)
		preview.set_process(false)
		for time: float in [0.0,0.19,0.47,0.81]:
			preview._motion.sample(mode,time)
			preview._articulation.set_wing_pose(time)
			for wing: Node3D in wings:
				check(wing.global_transform.is_finite() and wing.has_node("WingSurface") and wing.has_node("WingSocket") and wing.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D).size() == 2 and wing.get_meta("geometry_revision") == 1, "Animated wing lost its attachment/reference")
			check(preview._motion._legs.size() == 2, "Wing counted as support leg")
	check(var_to_str(design) == before, "Animation rewrote blueprint")
	parent.free()


func _save() -> void:
	var expected: Dictionary = {"designs": {}, "keys": {}, "meshes": {}, "progression": root.get_node("ProgressionService").export_state(), "game": root.get_node("GameState").export_state()}
	for id: String in IDS:
		var design: Dictionary = _design(id)
		_runtime(design)
		var path: String = "user://" + id + ".json"
		check(Assembly.save_to_file(design, path) == OK, "Wing save failed")
		var saved: String = FileAccess.get_file_as_string(path)
		var future: Dictionary = design.duplicate(true)
		future.parts[1].part_revision = 2
		check(Assembly.save_to_file(future, path) != OK and FileAccess.get_file_as_string(path) == saved, "Future wing overwrote existing design")
		var package: Dictionary = Package.export_blueprint(design, {"title": id})
		check(package.ok and Package.inspect(package.get("package", {})).ok, "Wing package export/validation failed")
		if not package.ok: continue
		check(Designs.add(package.package, LIBRARY_FILE).ok and Designs.add(package.package, LIBRARY_FILE).ok, "Wing library import/dedup failed")
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
	check(library.ok and library.packages.size() == 4, "Restart lost or duplicated wing packages")
	for id: String in IDS:
		check(progress.is_part_unlocked(id), "Restart lost wing unlock")
		var design: Dictionary = Assembly.load_from_file("user://" + id + ".json")
		check(JSON.parse_string(JSON.stringify(Assembly.serialize_snapshot(design))) == expected.designs[id], "Restart changed wing ID/revisions/UID/shape/color")
		check(design.parts[1].part_revision == 1 and design.parts[1].catalog_revision == 1, "Saved wing references not pinned")
		var model: Node3D = _model(id)
		check(JSON.stringify(Snapshot.describe(model)).sha256_text() == expected.meshes[id], "Restart changed rendered wing")
		model.free()
		_runtime(design)
		var found: Dictionary = Designs.get_package(expected.keys[id], LIBRARY_FILE)
		check(found.ok, "Offline wing package unavailable")
		if found.ok:
			var prepared: Dictionary = Package.prepare_import(found.package, Assembly.create_default(), 0, progress.get_unlocked_part_ids())
			check(prepared.ok, "Offline wing package could not be used")
