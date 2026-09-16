extends "res://tests/creature_foot_provider_test.gd"
const Mouths = preload("res://creatures/catalog/creature_mouth_catalog.gd")
const SurfaceV2 = preload("res://creatures/editor/creature_mouth_surface_v2.gd")
const Revisions = preload("res://creatures/catalog/creature_part_revisions.gd")
const Articulation = preload("res://creatures/runtime/creature_part_articulation.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Designs = preload("res://assembly/exchange/creature_design_library.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const EXPECTED: String = "user://mouth-refresh-expected.json"
const OFFLINE: String = "user://mouth-refresh-library.json"
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	super.check(condition, message)

func run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("SaveGameService")._loaded_once = true
	if "--mouth-refresh-restart" in OS.get_cmdline_user_args():
		_restart()
	else:
		check(not root.get_node("SaveGameService").create_slot("Mouth revision 2", 48219).is_empty(), "Campaign slot creation failed")
		_check_catalog()
		_models()
		await _editor()
		_save()
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/creature_mouth_refresh_test.gd", "--", "--mouth-refresh-restart"], output, true)
		check(status == 0 and str(output).contains("MOUTH_REFRESH_RESTART_PASSED") and not str(output).contains("ERROR"), "Mouth restart failed: " + str(output))
		if status == 0: print(str(output).strip_edges())
	for problem: String in failures: push_error(problem)
	if failures.is_empty(): print(("MOUTH_REFRESH_RESTART_PASSED" if "--mouth-refresh-restart" in OS.get_cmdline_user_args() else "MOUTH_REFRESH_PASSED") + ": %d checks; 10 revised mouths" % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _model(id: String, revision: int, shape: Vector3 = Vector3.ONE, side: float = 1) -> Node3D:
	var node := Node3D.new()
	node.set_meta("creature_part_side", side)
	Snapshot.Geometry.build(node, Library.get_part(id), {"part_id": id, "category": "mouth", "part_revision": revision, "shape_scale": shape}, Assembly.create_default())
	return node

func _signature(model: Node3D) -> String:
	var colors: Array = []
	for mesh: MeshInstance3D in model.get_children(): colors.append(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR].to_byte_array().hex_encode().sha256_text())
	return JSON.stringify({"geometry": Snapshot.describe(model), "colors": colors}).sha256_text()

func _connected(cells: Dictionary) -> bool:
	if cells.is_empty(): return false
	var queue: Array[Vector3i] = [cells.keys()[0]]
	var seen: Dictionary = {queue[0]: true}
	var index: int = 0
	while index < queue.size():
		var cell: Vector3i = queue[index]
		index += 1
		for offset: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var next: Vector3i = cell + offset
			if cells.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size() == cells.size()

func _models() -> void:
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_mouth_refresh_v2.json"))
	check(frozen.size() == 100, "Incomplete revised mouth references")
	var signatures: Dictionary = {}
	for id: String in Mouths.REFRESHED_IDS:
		check(Revisions.current_revision(id) == 2 and Revisions.resolve(id, {}).geometry_revision == 1, "Legacy reference silently upgraded")
		for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9), Vector3(0.4, 2.5, 0.4), Vector3(2.5, 0.4, 2.5)]:
			var left: Node3D = _model(id, 2, shape, 1)
			var right: Node3D = _model(id, 2, shape, -1)
			check(left.get_child_count() == 2 and right.get_child_count() == 2, "Revised mouth exceeded two mesh nodes")
			for model: Node3D in [left, right]:
				check(_signature(model) == frozen["%s:%s:%d" % [id, shape, int(model.get_meta("creature_part_side"))]], "Revision 2 changed without a revision: " + id)
			for index in range(2):
				var mesh: ArrayMesh = left.get_child(index).mesh
				var cells: Dictionary = mesh.get_meta("voxel_cells")
				var reflected: Dictionary = right.get_child(index).mesh.get_meta("voxel_cells")
				check(cells.size() > 30 and cells.size() < 100000, "Mouth volume outside budget")
				check(_connected(cells), "Detached mouth/nose/tooth cells: %s/%s/%s" % [id, shape, index])
				var mirrored: bool = cells.size() == reflected.size()
				for cell: Vector3i in cells:
					if not reflected.has(Vector3i(-cell.x - 1, cell.y, cell.z)): mirrored = false
				check(mirrored, "Mouth cells did not reflect")
				# No nostril color may create geometry above the authored roof.
				check(mesh.get_aabb().end.y <= (float(SurfaceV2.profile(id).height) + 0.02) * shape.y + float(mesh.get_meta("voxel_size")), "Nose markings created floating towers")
			_articulation(left, id)
			left.free()
			right.free()
		var model: Node3D = _model(id, 2)
		var signature: String = _signature(model)
		check(not signatures.has(signature), "Revised mouths share the same geometry")
		signatures[signature] = true
		_opening(model, id)
		model.free()
		for revision: int in [0, 3, 99]:
			var invalid: Node3D = _model(id, revision)
			check(invalid.get_child_count() == 0, "Future/invalid mouth rendered a fallback")
			invalid.free()
		_check_preview(id)
	for shape: Vector3 in [Vector3.ZERO, Vector3(-1, 1, 1), Vector3(NAN, 1, 1), Vector3(1, INF, 1)]:
		check(SurfaceV2.meshes("mouth_grazer", Color.WHITE, Color.WHITE, Color.WHITE, shape).is_empty(), "Invalid mouth shape accepted")
	check(SurfaceV2._cache.size() <= SurfaceV2.CACHE_LIMIT, "Unbounded mouth cache")
	check(Revisions.resolve("head_elephant_trunk", {"part_revision": 2}).is_empty() and Revisions.resolve("feet_pads", {"part_revision": 2}).is_empty(), "Mouth revision widened unrelated versions")
	for location: String in ["root", "body", "paint"]:
		var forged: Dictionary = Assembly.create_default()
		var section: Dictionary = forged if location == "root" else forged[location]
		section.part_id = "mouth_grazer"
		section.part_revision = 2
		check(not Revisions.version_error(forged).is_empty(), "Mouth ID bypassed body/document revision protection")

func _opening(model: Node3D, id: String) -> void:
	if id == "mouth_octopus_beak": return
	var profile: Dictionary = SurfaceV2.profile(id)
	var upper: MeshInstance3D = model.get_node("UpperJawSurface")
	var lower: MeshInstance3D = model.get_node("LowerJawSurface")
	var step: float = upper.mesh.get_meta("voxel_size")
	var cells: Dictionary = upper.mesh.get_meta("voxel_cells")
	var bottom: Dictionary = lower.mesh.get_meta("voxel_cells")
	var point := Vector3(0, -0.050, -float(profile.length) * 0.60)
	var cell := Vector3i((point / step).floor())
	check(not cells.has(cell) and not bottom.has(cell), "Mouth opening filled with solid geometry")
	var colors: PackedColorArray = lower.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var dark: bool = false
	for color: Color in colors:
		if color.r < 0.28 and color.g < 0.25 and color.b < 0.25: dark = true
	check(dark, "Open jaw lost dark inner surface")

func _articulation(model: Node3D, id: String) -> void:
	var animation := Articulation.new()
	animation.bind(model)
	var upper: MeshInstance3D = model.get_node("UpperJawSurface")
	var lower: MeshInstance3D = model.get_node("LowerJawSurface")
	var rest: Transform3D = lower.transform
	var upper_rest: Transform3D = upper.transform
	var old_mesh: Mesh = lower.mesh
	var point: Vector3 = Vector3(0, -0.10, -float(SurfaceV2.profile(id).length) * 0.75) * model.get_meta("part_shape")
	var previous_y: float = (rest * point).y
	for amount: float in [0.25, 0.5, 0.75, 1.0]:
		animation.set_pose(amount, 0)
		check((lower.transform * point).y < previous_y, "Opening jaw closed/moved upwards")
		previous_y = (lower.transform * point).y
		check(upper.transform == upper_rest and lower.mesh == old_mesh, "Jaw rebuilt geometry or moved upper face")
	animation.reset()
	check(lower.transform == rest, "Jaw did not return to its saved rest pose")
	animation.unbind()

func _design(id: String) -> Dictionary:
	var design: Dictionary = Assembly.create_default()
	design.parts = design.parts.filter(func(part: Dictionary) -> bool: return part.category != "mouth")
	Assembly.BaseBlueprint.add_part(design, "legs_walker")
	var index: int = Assembly.BaseBlueprint.add_part(design, id)
	design.parts[index].part_revision = 2
	design.parts[index].rotation = Vector3(4, -8, 3)
	design.parts[index].shape_scale = Vector3(0.8, 1.1, 1.4)
	Assembly.normalize(design)
	Anatomy.reset_all_anchors(design)
	return design

func _runtime(design: Dictionary) -> void:
	var preview := Preview.new()
	root.add_child(preview)
	preview.set_editor_state(design, -1, -1, false)
	preview.set_process(false)
	var report: Dictionary = Body.inspect_rest(preview)
	check(report.leg_count == 4 and report.all_feet_on_plane, "Mouth changed hand/foot placement")
	var mouth: Node3D
	for child: Node in preview.get_children():
		if child.get_meta("creature_part_category", "") == "mouth": mouth = child
	check(mouth != null and mouth.get_meta("geometry_revision") == 2, "Runtime lost mouth revision")
	if mouth != null:
		var skin: MeshInstance3D = preview.get_node("BodyV4/SculptedSkin")
		var cells: Dictionary = skin.mesh.get_meta("voxel_cells")
		var step: float = skin.mesh.get_meta("voxel_size")
		var surface: MeshInstance3D = mouth.get_node("UpperJawSurface")
		var own_step: float = surface.mesh.get_meta("voxel_size")
		var space: Transform3D = skin.global_transform.affine_inverse() * surface.global_transform
		var inside: int = 0
		for cell: Vector3i in surface.mesh.get_meta("voxel_cells"):
			if cells.has(Vector3i(((space * ((Vector3(cell) + Vector3.ONE * 0.5) * own_step)) / step).floor())): inside += 1
		check(inside > 0 and inside < int(surface.mesh.get_meta("voxel_count")), "Mouth floats off or is buried in head")
		_articulation(mouth, design.parts.back().part_id)
	preview.free()

func _editor() -> void:
	var progress: Node = root.get_node("ProgressionService")
	progress.reset_for_new_game()
	progress.merge_unlocked_parts(Mouths.REFRESHED_IDS)
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(12): await process_frame
	for id: String in Mouths.REFRESHED_IDS:
		var design: Dictionary = _design(id)
		design.parts.back().part_revision = 1
		var legacy: String = var_to_str(design)
		editor.set("blueprint", design.duplicate(true))
		editor.call("_select_part_by_index", design.parts.size() - 1)
		var button: Button = editor.get("_part_controls").get_node("UpdateMouth")
		check(button.visible and not button.disabled, "Legacy mouth has no update button")
		button.pressed.emit()
		check(editor.get("blueprint").parts.back().part_revision == 2 and button.disabled, "Update button did not select new mouth")
		var original: Dictionary = design.parts.back().duplicate(true)
		var updated: Dictionary = editor.get("blueprint").parts.back().duplicate(true)
		# The first explicit update also pins the implicit legacy catalog number.
		Revisions.pin_reference(original)
		original.erase("part_revision")
		updated.erase("part_revision")
		check(original == updated and var_to_str(design) == legacy, "Mouth update changed identity, values or placement")
		editor.call("_undo_edit")
		check(editor.get("blueprint").parts.back().part_revision == 1, "Mouth update cannot be undone")
		editor.call("_redo_edit")
		check(editor.get("blueprint").parts.back().part_revision == 2, "Mouth redo lost revision")
		var fresh: Dictionary = Assembly.create_default()
		fresh.parts = []
		editor.set("blueprint", fresh)
		editor.call("_on_category_button_pressed", "mouth")
		editor.call("_on_part_button_pressed", id)
		check(editor.get("blueprint").parts.size() == 1 and editor.get("blueprint").parts[0].part_revision == 2, "New editor mouth uses old model")
	editor.free()
	await process_frame

func _save() -> void:
	var expected: Dictionary = {"designs": {}, "keys": {}, "progress": root.get_node("ProgressionService").export_state()}
	for id: String in Mouths.REFRESHED_IDS:
		var design: Dictionary = _design(id)
		_runtime(design)
		var path: String = "user://" + id + "-v2.json"
		check(Assembly.save_to_file(design, path) == OK, "Revision 2 save failed")
		var before: String = FileAccess.get_file_as_string(path)
		var future: Dictionary = design.duplicate(true)
		future.parts.back().part_revision = 3
		check(Assembly.save_to_file(future, path) != OK and FileAccess.get_file_as_string(path) == before, "Future mouth overwrote existing design")
		check(not Package.export_blueprint(future).ok, "Future mouth downgraded on export")
		var package: Dictionary = Package.export_blueprint(design)
		check(package.ok, "Revision 2 package rejected")
		if not package.ok: continue
		check(Package.inspect(package.package).ok and Designs.add(package.package, OFFLINE).ok, "Offline library rejected new mouth")
		check(Designs.add(package.package, OFFLINE).code == "already_present", "New mouth package did not deduplicate")
		expected.designs[id] = Assembly.serialize_snapshot(design)
		expected.keys[id] = Designs.key_of(package.package)
	var saves: Node = root.get_node("SaveGameService")
	var campaign_design: Dictionary = _design("mouth_grazer")
	check(Assembly.save_to_file(campaign_design) == OK and saves.save_now(), "Campaign did not save revision 2")
	check(saves.load_now(), "Campaign rejected supported mouth revision")
	var future_campaign: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(saves.save_path))
	var future_design: Dictionary = Assembly.serialize_snapshot(campaign_design)
	future_design.parts.back().part_revision = 3
	future_campaign.design_files[Assembly.SAVE_PATH] = Atomic.stringify(future_design)
	check(Atomic.write(saves.save_path, future_campaign) == OK, "Future campaign fixture failed")
	expected.campaign = saves.save_path
	expected.campaign_bytes = FileAccess.get_file_as_string(saves.save_path)
	expected.backup_bytes = FileAccess.get_file_as_string(saves.save_path + ".bak")
	check(not saves.load_now() and not saves.save_now(), "Future mouth campaign downgraded to backup or overwritten")
	check(FileAccess.get_file_as_string(saves.save_path) == expected.campaign_bytes and FileAccess.get_file_as_string(saves.save_path + ".bak") == expected.backup_bytes, "Blocked campaign changed original or backup")
	check(Atomic.write(EXPECTED, expected, false) == OK, "Restart oracle not written")

func _restart() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED))
	var saves: Node = root.get_node("SaveGameService")
	saves.save_path = expected.campaign
	check(not saves.load_now() and not saves.save_now(), "Fresh process accepted future mouth campaign")
	check(FileAccess.get_file_as_string(expected.campaign) == expected.campaign_bytes and FileAccess.get_file_as_string(expected.campaign + ".bak") == expected.backup_bytes, "Fresh process rewrote protected campaign")
	var progress: Node = root.get_node("ProgressionService")
	check(progress.import_state(expected.progress), "Restart lost unlocks")
	var library: Dictionary = Designs.read(OFFLINE)
	check(library.ok and library.packages.size() == 10, "Restart lost or duplicated mouth templates")
	for id: String in Mouths.REFRESHED_IDS:
		var design: Dictionary = Assembly.load_from_file("user://" + id + "-v2.json")
		check(Atomic.parse_dictionary(Atomic.stringify(Assembly.serialize_snapshot(design))) == expected.designs[id], "Restart changed mouth ID/revision/shape")
		_runtime(design)
		var found: Dictionary = Designs.get_package(expected.keys[id], OFFLINE)
		check(found.ok, "Offline mouth not available after restart")
		if found.ok:
			var current: Dictionary = Assembly.create_default()
			var imported: Dictionary = Package.prepare_import(found.package, current, 0, progress.get_unlocked_part_ids())
			check(imported.ok and imported.blueprint.design_id == current.design_id, "Mouth template replaced receiving identity")
