extends "res://tests/creature_foot_provider_test.gd"
var Profiles: GDScript
var Shapes: GDScript
var family: String
var channel: String
var action: String
var prefix: String
var button_name: String
var entry_script: String
var stats_source: String
const Revisions = preload("res://creatures/catalog/creature_part_revisions.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const Copy = preload("res://ui/discovery/journal_presentation.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Designs = preload("res://assembly/exchange/creature_design_library.gd")
var IDS: Array[String] = []
var ENGLISH: Array[String] = []
var LIBRARY_FILE: String
var EXPECTED_FILE: String
const Joints = preload("res://creatures/runtime/creature_part_articulation.gd")
const SHAPES: Array[Vector3] = [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9), Vector3(0.4, 2.5, 0.4), Vector3(2.5, 0.4, 2.5)]
var checks: int = 0


func run() -> void:
	LIBRARY_FILE = "user://" + family + "_library.json"
	EXPECTED_FILE = "user://" + family + "_expected.json"
	root.get_node("SaveGameService").autosave_enabled = false
	if "--restart-appendages" in OS.get_cmdline_user_args():
		_restart()
	else:
		_check_catalog()
		_baseline()
		_models()
		for id: String in IDS: _check_preview(id)
		await _editor()
		_mixed_actions()
		_save()
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", entry_script, "--", "--restart-appendages"], output, true)
		check(status == 0 and str(output).contains("APPENDAGE_RESTART_PASSED") and not str(output).contains("SCRIPT ERROR"), "Appendage restart failed: " + str(output))
	for problem: String in failures: push_error(problem)
	if failures.is_empty(): print(("APPENDAGE_RESTART_PASSED" if "--restart-appendages" in OS.get_cmdline_user_args() else family.to_upper() + "_FAMILY_PASSED") + ": %d checks; 6 models, 60 frozen meshes, 30 frozen species" % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	super.check(condition, message)


func _model(id: String, shape: Vector3 = Vector3.ONE, side: float = 1.0, revision: int = 1) -> Node3D:
	var node := Node3D.new()
	node.set_meta("creature_part_side", side)
	Snapshot.Geometry.build(node, {"id": id}, {"category": family, "shape_scale": shape, "part_revision": revision}, Assembly.BaseBlueprint.create_default())
	return node


func _baseline() -> void:
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_mouths_v1.json")).species
	check(frozen.size() == 30, "Incomplete frozen species baseline")
	for seed_value: int in [1, 17, 42, 977, 8192]:
		for role: String in Species.ECOLOGICAL_ROLES:
			var design: Dictionary = Species.create_species(seed_value, Vector2i(13, -7), role)
			check(JSON.stringify(Assembly.BaseBlueprint._serialize_blueprint(design)).sha256_text() == frozen["%d:%s" % [seed_value, role]], "Appendage variants regenerated an existing species")


func _models() -> void:
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_" + family + "_families_v1.json"))
	check(frozen.size() == 60, "Incomplete appendage revision fixture")
	var signatures: Dictionary = {}
	for index in range(IDS.size()):
		var id: String = IDS[index]
		var profile: Dictionary = Profiles.get_profile(id)
		var source: Dictionary = Library.get_part(stats_source)
		var definition: Dictionary = Library.get_part(id)
		check(definition.stats == source.stats and definition.complexity == source.complexity, "Appendage invented gameplay values")
		check(profile.capabilities.is_empty() and profile.supported_actions.is_empty() and profile.unlock_source == source.id, "Appendage granted flight or unrelated unlock")
		check(Copy.part(id, "name", "de") == profile.name and Copy.part(id, "name", "en") == ENGLISH[index], "Appendage label missing")
		check(Copy.part(id, "description", "de") == profile.description and Copy.part(id, "description", "en") != profile.description, "Appendage description missing")
		profile.features.clear()
		definition.stats.clear()
		check(not Profiles.get_profile(id).features.is_empty() and Library.get_part(id).stats == source.stats, "Mutable catalog leaked")
		check(Revisions.resolve(id, {}) == {"geometry_id": id, "geometry_revision": 1}, "Unpinned appendage resolves incorrectly")
		for revision: int in [0, 2, 99]:
			var future := _model(id, Vector3.ONE, 1, revision)
			check(future.get_child_count() == 0 and Shapes.meshes(id, Color.WHITE, Color.WHITE, Vector3.ONE, 1, revision).is_empty(), "Future revision rendered a fallback")
			future.free()
		for shape: Vector3 in SHAPES:
			var left := _model(id, shape, 1)
			var right := _model(id, shape, -1)
			check(left.get_child_count() == 2 and right.get_child_count() == 2, "Appendage scene budget exceeded")
			for model: Node3D in [left, right]:
				var key: String = "%s:%s:%d" % [id, shape, int(model.get_meta("creature_part_side"))]
				check(fingerprint(model) == frozen[key], "Appendage revision changed: " + key)
				for mesh: MeshInstance3D in model.get_children():
					var cells: Dictionary = mesh.mesh.get_meta("voxel_cells")
					check(not cells.is_empty() and cells.size() < 160000 and mesh.mesh.surface_get_array_len(0) < 450000, "Unbounded appendage geometry")
					check(_connected(cells), "Disconnected appendage surface: " + key + "/" + str(mesh.name))
			for child: MeshInstance3D in left.get_children():
				var opposite: Dictionary = right.get_node(NodePath(str(child.name))).mesh.get_meta("voxel_cells")
				var cells: Dictionary = child.mesh.get_meta("voxel_cells")
				check(cells.size() == opposite.size(), "Appendage mirror lost cells")
				var mirrored: bool = true
				for cell: Vector3i in cells:
					if not opposite.has(Vector3i(-cell.x - 1, cell.y, cell.z)): mirrored = false
				check(mirrored, "Appendage geometry did not reflect")
			if shape == Vector3.ONE:
				var signature: String = Snapshot.describe(left)[1].vertex_hash
				check(not signatures.has(signature), "Appendage family only recolored another shape")
				signatures[signature] = true
			_articulate(left, right)
			left.free()
			right.free()
	for bad: Vector3 in [Vector3.ZERO, Vector3(NAN,1,1), Vector3(3,1,1)]:
		check(Shapes.meshes(IDS[0], Color.WHITE, Color.WHITE, bad).is_empty(), "Invalid shape accepted")
	check(Profiles.get_profile(family + "_future").is_empty() and Shapes.meshes(family + "_future", Color.WHITE, Color.WHITE).is_empty(), "Unknown appendage substituted")


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
		for delta: Vector3i in Shapes.Voxels.NEIGHBORS:
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
	var socket: Transform3D = left.get_node(prefix + "Socket").transform
	var mesh: ArrayMesh = left.get_node(prefix + "Surface").mesh
	for pose: float in [0.0, 0.5, 1.0, 0.15]:
		a.call("set_" + channel + "_pose", pose)
		b.call("set_" + channel + "_pose", pose)
		var tip: Vector3 = left.get_node(prefix + "Surface").transform * Vector3(1,0,0)
		var other: Vector3 = right.get_node(prefix + "Surface").transform * Vector3(-1,0,0)
		check((tip * Vector3(-1,1,1)).is_equal_approx(other) , "Joint mirror differs")
		var surface: MeshInstance3D = left.get_node(prefix + "Surface")
		var size: float = mesh.get_meta("voxel_size")
		var socket_cells: Dictionary = left.get_node(prefix + "Socket").mesh.get_meta("voxel_cells")
		var attached: bool = false
		for cell: Vector3i in mesh.get_meta("voxel_cells"):
			var point: Vector3 = surface.transform * ((Vector3(cell) + Vector3.ONE * 0.5) * size)
			if socket_cells.has(Vector3i((point / size).floor())):
				attached = true
				break
		check(attached, "Stretched appendage detached from its fixed shoulder")
		check(left.get_node(prefix + "Socket").transform == socket and left.get_node(prefix + "Surface").mesh == mesh, "Appendage action moved socket/rebuilt geometry")
	a.reset()
	check(a.play(action, 1.2) and not a.play("fly"), "Cosmetic stretch/flight contract wrong")
	var peak: float = 0
	for frame in range(150):
		a.advance(1.0/60.0)
		peak = maxf(peak, a.debug_state()[channel])
	check(peak > 0.9 and not a.is_active() and left.get_node(prefix + "Surface").transform == Transform3D.IDENTITY, "Stretch did not open and settle")
	a.call("set_" + channel + "_pose", NAN)
	check(a.debug_state()[channel] == 0, "Nonfinite pose propagated")
	b.unbind()


func _editor() -> void:
	var progress: Node = root.get_node("ProgressionService")
	root.get_node("GameState").set_world_seed(44)
	progress.reset_for_new_game()
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16): await process_frame
	editor.call("_set_mode", "parts")
	if family == "fins":
		var before: String = var_to_str(editor.get("blueprint"))
		for id: String in IDS:
			check(not progress.is_part_unlocked(id), "Fin unlocked before discovery")
			editor.call("_on_part_button_pressed", id)
			check(var_to_str(editor.get("blueprint")) == before, "Locked fin changed editor")
		var observed: Dictionary = Assembly.create_default()
		observed.parts = []
		Assembly.BaseBlueprint.add_part(observed, "tail_fin")
		var receipt: Dictionary = progress.register_species_discovery(545, observed, 44)
		check(receipt.unlocked_part == "tail_fin" and progress.discovery_points == 3, "Fin models changed discovery reward")
	var state: Dictionary = progress.export_state()
	var old: Dictionary = state.duplicate(true)
	for id: String in IDS: old.unlocked_parts.erase(id)
	var untouched: String = JSON.stringify(old)
	check(progress.import_state(old) and JSON.stringify(old) == untouched, "Unlock migration mutated input")
	var migrated: Dictionary = progress.export_state()
	check(migrated.discovery_points == old.discovery_points and migrated.discovered_species == old.discovered_species, "Appendage migration changed rewards/species")
	check(progress.import_state(migrated) and progress.export_state() == migrated, "Unlock migration not idempotent")
	var rows: Array = Records.part_rows(migrated, "", family)
	check(rows.size() == 6, "Journal appendage category missing")
	for row: Dictionary in rows: check(row.unlocked, "Journal differs from editor unlock")
	for id: String in IDS:
		check(progress.is_part_unlocked(id), "Source unlock did not expose appendage")
		var design: Dictionary = Assembly.create_default()
		design.parts = []
		editor.set("blueprint", design)
		editor.call("_on_category_button_pressed", family)
		editor.call("_on_part_button_pressed", id)
		check(editor.get("blueprint").parts.size() == 1 and editor.get("blueprint").parts[0].part_id == id, "Editor did not add appendage")
		var added: Dictionary = editor.get("blueprint").parts[0]
		var paired: bool = Profiles.get_profile(id).default_mirrored
		check(added.mirrored == paired and bool(added.get("center_locked", false)) == not paired, "Natural placement default lost: " + id)
		editor.call("_undo_edit")
		check(editor.get("blueprint").parts.is_empty(), "Appendage undo failed")
		editor.call("_redo_edit")
		editor.call("_select_part_by_index", 0)
		for mode: String in ["single", "center", "paired"]:
			editor.call("_set_placement_mode", mode)
			var part: Dictionary = editor.get("blueprint").parts[0]
			check(part.mirrored == (mode == "paired") and part.center_locked == (mode == "center"), "Appendage placement mode failed")
		editor.call("_change_part_field", 27.0, "rotation", 1)
		editor.call("_change_part_field", 1.2, "scale", 0)
		for axis in range(3): editor.call("_change_part_field", 0.8 + float(axis)*0.2, "shape", axis)
		var part: Dictionary = editor.get("blueprint").parts[0]
		check(is_equal_approx(part.rotation.y, 27) and part.shape_scale.is_equal_approx(Vector3(0.8,1,1.2)), "Editor lost appendage transforms")
		var before: String = var_to_str(editor.get("blueprint"))
		var button: Button = editor.get("_part_controls").get_node(NodePath(button_name))
		check(button.visible, "Appendage stretch control hidden")
		button.pressed.emit()
		check(editor.get("_preview")._articulation.debug_state().action == action, "Editor stretch did not reach shared animation")
		check(var_to_str(editor.get("blueprint")) == before, "Stretch modified save data")
	editor.free()
	await process_frame


func _design(id: String) -> Dictionary:
	var design: Dictionary = Assembly.create_default()
	design.parts = []
	Assembly.BaseBlueprint.add_part(design, "legs_walker")
	Assembly.BaseBlueprint.add_part(design, id)
	Anatomy.reset_all_anchors(design)
	design.parts[1].rotation = Vector3(8, -16, 5)
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
	var appendages: Array[Node3D] = []
	for child: Node in preview.get_children():
		if child is Node3D and child.get_meta("creature_part_category", "") == family: appendages.append(child)
	check(appendages.size() == (2 if design.parts[1].mirrored else 1), "Saved appendage pair lost")
	var skin: MeshInstance3D = preview.get_node("BodyV4/SculptedSkin")
	var skin_cells: Dictionary = skin.mesh.get_meta("voxel_cells")
	var skin_step: float = skin.mesh.get_meta("voxel_size")
	for appendage: Node3D in appendages:
		var socket: MeshInstance3D = appendage.get_node(NodePath(prefix + "Socket"))
		var attached: bool = false
		for cell: Vector3i in socket.mesh.get_meta("voxel_cells"):
			var p: Vector3 = (Vector3(cell) + Vector3.ONE * 0.5) * float(socket.mesh.get_meta("voxel_size"))
			var local: Vector3 = skin.to_local(socket.to_global(p))
			if skin_cells.has(Vector3i((local / skin_step).floor())):
				attached = true
				break
		check(attached, "Rendered socket detached from body: " + str(design.parts[1].part_id))
	var rest: Dictionary = Body.inspect_rest(preview)
	check(rest.leg_count == 2 and rest.all_feet_on_plane, "Appendages changed support feet")
	var before: String = var_to_str(design)
	for mode: String in ["idle", "walk", "run"]:
		preview.set_motion(mode)
		preview.set_process(false)
		for time: float in [0.0,0.19,0.47,0.81]:
			preview._motion.sample(mode,time)
			preview._articulation.call("set_" + channel + "_pose", time)
			for appendage: Node3D in appendages:
				check(appendage.global_transform.is_finite() and appendage.has_node(prefix + "Surface") and appendage.has_node(prefix + "Socket") and appendage.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D).size() == 2 and appendage.get_meta("geometry_revision") == 1, "Animated appendage lost its attachment/reference")
			check(preview._motion._legs.size() == 2, "Appendage counted as support leg")
	check(var_to_str(design) == before, "Animation rewrote blueprint")
	parent.free()


func _save() -> void:
	var expected: Dictionary = {"designs": {}, "keys": {}, "meshes": {}, "progression": root.get_node("ProgressionService").export_state(), "game": root.get_node("GameState").export_state()}
	for id: String in IDS:
		var design: Dictionary = _design(id)
		_runtime(design)
		var path: String = "user://" + id + ".json"
		check(Assembly.save_to_file(design, path) == OK, "Appendage save failed")
		var saved: String = FileAccess.get_file_as_string(path)
		var future: Dictionary = design.duplicate(true)
		future.parts[1].part_revision = 2
		check(Assembly.save_to_file(future, path) != OK and FileAccess.get_file_as_string(path) == saved, "Future appendage overwrote existing design")
		var package: Dictionary = Package.export_blueprint(design, {"title": id})
		check(package.ok and Package.inspect(package.get("package", {})).ok, "Appendage package export/validation failed")
		if not package.ok: continue
		check(Designs.add(package.package, LIBRARY_FILE).ok and Designs.add(package.package, LIBRARY_FILE).ok, "Appendage library import/dedup failed")
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
	check(library.ok and library.packages.size() == 6, "Restart lost or duplicated appendage packages")
	for id: String in IDS:
		check(progress.is_part_unlocked(id), "Restart lost appendage unlock")
		var design: Dictionary = Assembly.load_from_file("user://" + id + ".json")
		check(JSON.parse_string(JSON.stringify(Assembly.serialize_snapshot(design))) == expected.designs[id], "Restart changed appendage ID/revisions/UID/shape/color")
		check(design.parts[1].part_revision == 1 and design.parts[1].catalog_revision == 1, "Saved appendage references not pinned")
		var model: Node3D = _model(id)
		check(JSON.stringify(Snapshot.describe(model)).sha256_text() == expected.meshes[id], "Restart changed rendered appendage")
		model.free()
		_runtime(design)
		var found: Dictionary = Designs.get_package(expected.keys[id], LIBRARY_FILE)
		check(found.ok, "Offline appendage package unavailable")
		if found.ok:
			var prepared: Dictionary = Package.prepare_import(found.package, Assembly.create_default(), 0, progress.get_unlocked_part_ids())
			check(prepared.ok, "Offline appendage package could not be used")


func _mixed_actions() -> void:
	var holder := Node3D.new()
	var fixtures: Array[Dictionary] = [
		{"id": "wings_broad_feather", "category": "wings", "prefix": "Wing", "action": "wing_stretch", "channel": "wing"},
		{"id": "fins_broad_paddle", "category": "fins", "prefix": "Fin", "action": "fin_flex", "channel": "fin"},
		{"id": "ears_cat_pointed", "category": "ears", "prefix": "Ear", "action": "ear_perk", "channel": "ear"}]
	var nodes: Array[Node3D] = []
	for fixture: Dictionary in fixtures:
		var node := Node3D.new()
		Snapshot.Geometry.build(node, {"id": fixture.id}, {"category": fixture.category}, Assembly.create_default())
		holder.add_child(node)
		nodes.append(node)
	var joints := Joints.new()
	joints.bind(holder)
	for index in range(fixtures.size()):
		joints.reset()
		check(joints.play(fixtures[index].action, 1.2), "Mixed action unavailable")
		for frame in range(36): joints.advance(1.0/60.0)
		for other in range(fixtures.size()):
			var transform: Transform3D = nodes[other].get_node(NodePath(fixtures[other].prefix + "Surface")).transform
			check((transform != Transform3D.IDENTITY) == (other == index), "Action leaked into another family")
	joints.unbind()
	check(not joints.play(action), "Missing appendage accepted its action")
	holder.free()
