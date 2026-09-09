extends SceneTree

const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Spine = preload("res://creatures/editor/creature_spine_profile.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Voxels = preload("res://creatures/editor/creature_voxel_mesh.gd")
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_voxel_contract()
	var blueprint: Dictionary = Assembly.create_default()
	Anatomy.reset_all_anchors(blueprint)
	var ids: Array = blueprint["parts"].map(func(p: Dictionary) -> String: return str(p["uid"]))
	Spine.move_knot(blueprint, 2, 0.05, 0.7)
	Spine.move_knot(blueprint, 3, -100.0, 0.0)
	var segments: Array = Spine.get_segments(blueprint)
	for index in range(1, 7):
		_expect(float(segments[index]["t"]) - float(segments[index - 1]["t"]) >= Spine.MIN_KNOT_GAP - 0.0001, "Spine knots crossed.")
	blueprint["appearance"] = {"base_color": "78bd9f", "accent_color": "31586e"}
	_expect(Assembly.save_to_file(blueprint, "user://studio_roundtrip.json") == OK, "Saving shaped design failed.")
	var loaded: Dictionary = Assembly.load_from_file("user://studio_roundtrip.json")
	_expect(is_equal_approx(float(Spine.get_segment(loaded, 2)["t"]), float(segments[2]["t"])), "Longitudinal shaping lost during reload.")
	_expect(loaded.get("appearance", {}) == blueprint["appearance"], "Custom colors lost during reload.")
	_expect(loaded["parts"].map(func(p: Dictionary) -> String: return str(p["uid"])) == ids, "Editing changed part identities.")
	var preview := Preview.new()
	root.add_child(preview)
	preview.set_editor_state(loaded, -1, -1, false)
	var skin: MeshInstance3D = preview.get_node_or_null("BodyV4/SculptedSkin")
	_expect(skin != null, "Editable voxel skin is absent.")
	if skin != null:
		_check_cubic_faces(skin.mesh)
		var cells: Dictionary = skin.mesh.get_meta("voxel_cells", {})
		_expect(not cells.is_empty(), "Voxel body cannot be picked for part placement.")
		for cell: Vector3i in cells:
			_expect(cells.has(Vector3i(-cell.x - 1, cell.y, cell.z)), "Voxelization broke body symmetry.")
	for piece: MeshInstance3D in preview.find_children("*", "MeshInstance3D", true, false):
		_expect(piece.mesh is ArrayMesh, "Smooth primitive remains in the active creature.")
	var geometry: int = _geometry_count(preview)
	_expect(geometry < 100, "Default sculpted creature exceeded 100 geometry nodes.")
	for child in preview.get_children():
		if child is Node3D and child.has_meta("creature_part_index"):
			var part: Dictionary = loaded["parts"][int(child.get_meta("creature_part_index"))]
			var anchor: Vector3 = Anatomy.get_anchor_position(loaded, part)
			_expect(is_equal_approx(child.position.y, anchor.y) and is_equal_approx(child.position.z, anchor.z), "Attachment was deformed twice.")
	var before: String = JSON.stringify(loaded)
	preview.set_motion("walk")
	preview._motion.sample("walk", 0.42)
	var has_knee: bool = not preview.find_children("RuntimeKneePivot", "Node3D", true, false).is_empty()
	_expect(has_knee, "Walking preview has no articulated knee.")
	preview.set_motion("edit")
	_expect(JSON.stringify(loaded) == before, "Motion preview mutated the design.")
	preview.free()
	for pair_count: int in [2, 3]:
		var many: Dictionary = Assembly.create_default()
		for index in range(pair_count - 1):
			Assembly.BaseBlueprint.add_part(many, "legs_walker")
		Anatomy.reset_all_anchors(many)
		var walker := Preview.new()
		root.add_child(walker)
		walker.set_editor_state(many, -1, -1, false)
		walker.set_motion("walk")
		_expect(walker._motion._legs.size() == pair_count * 2, "Multi-legged gait lost a mirrored limb.")
		walker._motion.sample("walk", 0.15)
		var foot: Node3D = walker._motion._legs[0]["foot"]
		var first: Vector3 = foot.global_position
		walker._motion.sample("walk", 0.60)
		_expect(foot.global_position.is_finite() and not foot.global_position.is_equal_approx(first), "Four/six-legged gait did not move its foot.")
		walker.free()
	var scene: PackedScene = load("res://creatures/editor/creature_editor.tscn")
	var editor: Node = scene.instantiate()
	root.add_child(editor)
	for frame in range(14):
		await process_frame
	_expect(editor.find_child("CreatureCanvas", true, false) != null, "Workshop input canvas missing.")
	_expect(editor.find_child("Card_body_balanced_core", true, false) != null, "Visual part palette missing.")
	# Route actual GUI events through the viewport, including a control over
	# the 3D canvas. Calling a handler directly would miss mouse-filter bugs.
	var part_tab: Control = editor.get("_mode_buttons")["parts"]
	await _click(part_tab.get_global_rect().get_center())
	_expect(str(editor.get("_studio_mode")) == "parts", "The Parts tab is not clickable through the GUI.")
	await _click(editor.get("_mode_buttons")["body"].get_global_rect().get_center())
	_expect(str(editor.get("_studio_mode")) == "body", "The Body tab is not clickable through the GUI.")
	editor.call("_apply_body_preset", "grazer")
	var shaped: Dictionary = editor.get("blueprint").duplicate(true)
	_expect(float(shaped["body"]["spine_length_scale"]) > 1.3, "Long-neck preset did not shape the body.")
	editor.set("selected_body_segment", 2)
	editor.call("_begin_gesture")
	for value in [0.8, 1.0, 1.2, 1.4]:
		editor.call("_change_shape", value, "width_scale")
	editor.call("_end_gesture")
	editor.call("_undo_edit")
	_expect(is_equal_approx(float(Spine.get_segment(editor.get("blueprint"), 2)["width_scale"]), float(Spine.get_segment(shaped, 2)["width_scale"])), "A drag required more than one undo.")
	editor.call("_redo_edit")
	_expect(is_equal_approx(float(Spine.get_segment(editor.get("blueprint"), 2)["width_scale"]), 1.4), "Redo did not restore the entire drag.")
	editor.call("_save_blueprint")
	_expect(bool(editor.get("_last_save_ok")), "Editor save failed.")
	_expect(bool(editor.get("_history").call("can_undo")), "Saving cleared undo history.")
	var saved_revision: int = Assembly.get_revision(editor.get("blueprint"))
	editor.call("_undo_edit")
	editor.call("_save_blueprint")
	_expect(Assembly.get_revision(editor.get("blueprint")) == saved_revision + 1, "Saving after undo reused an existing design revision.")
	var count: int = editor.get("blueprint")["parts"].size()
	editor.call("_set_mode", "parts")
	editor.call("drop_part", "eyes_beady", Vector2(2, 2))
	_expect(editor.get("blueprint")["parts"].size() == count, "Dropping outside the body created a part.")
	var camera: Camera3D = editor.get("_camera")
	var visual: Node3D = editor.get("_preview")
	var section: Dictionary = Surface.section(editor.get("blueprint"), 0.5)
	var body_point: Vector2 = camera.unproject_position(visual.to_global(section["center"]))
	_expect(bool(editor.call("can_drop_part", "eyes_beady", body_point)), "A visible body cannot receive parts.")
	editor.call("drop_part", "eyes_beady", body_point)
	_expect(editor.get("blueprint")["parts"].size() == count + 1, "Dropping a discovered part on the body failed.")
	if editor.get("blueprint")["parts"].size() == count + 1:
		_expect(bool(editor.get("blueprint")["parts"][-1]["mirrored"]), "A new paired part ignored symmetry.")
		editor.call("_toggle_surface_snap")
		var moving_part: Dictionary = editor.get("blueprint")["parts"][-1]
		var previous: Vector3 = moving_part["position"]
		editor.call("_move_part_to_cursor", body_point + Vector2(25, -90))
		_expect(not moving_part["position"].is_equal_approx(previous), "Turning off snapping did not allow manual movement.")
		var manual: Vector3 = moving_part["manual_offset"]
		Assembly.save_to_file(editor.get("blueprint"), "user://studio_free_part.json")
		var restored: Dictionary = Assembly.load_from_file("user://studio_free_part.json")
		editor.AttachmentNormalizerV7.normalize(restored)
		_expect(Assembly.BaseBlueprint._as_vector3(restored["parts"][-1]["manual_offset"]).is_equal_approx(manual), "Free part placement did not survive normalization and reload.")
	var design_before_preview: String = JSON.stringify(editor.get("blueprint"))
	editor.call("_set_mode", "test")
	editor.call("_choose_motion", "run")
	for frame in range(4):
		await process_frame
	_expect(JSON.stringify(editor.get("blueprint")) == design_before_preview, "Testing a creature changed its blueprint.")
	editor.free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("Creature studio test passed: cubic exposed faces, voxel picking, knot constraints, persistence, identities, skin/anchors, motion, undo/redo and safe drops. Geometry nodes: ", geometry)
	quit(0 if _failures.is_empty() else 1)


func _check_voxel_contract() -> void:
	var adjacent: Dictionary = {Vector3i.ZERO: Color.WHITE, Vector3i.RIGHT: Color.RED}
	var mesh: ArrayMesh = Voxels.from_cells(adjacent, 1.0, true)
	var arrays: Array = mesh.surface_get_arrays(0)
	_expect(arrays[Mesh.ARRAY_INDEX].size() == 60, "Two adjacent voxels must expose ten faces; internal faces leaked.")
	_check_cubic_faces(mesh)
	var hit: Dictionary = Voxels.raycast(mesh, Vector3(5, 0.5, 0.5), Vector3.LEFT)
	_expect(not hit.is_empty(), "A visible voxel face cannot receive a part.")
	if not hit.is_empty():
		_expect(hit["position"].is_equal_approx(Vector3(2, 0.5, 0.5)) and hit["normal"] == Vector3.RIGHT, "Voxel picking missed the first visible face.")
	var reverse: Dictionary = Voxels.raycast(mesh, Vector3(-5, 0.5, 0.5), Vector3.RIGHT)
	_expect(not reverse.is_empty() and reverse.get("normal") == Vector3.LEFT, "Picking from the opposite side failed.")
	_expect(Voxels.raycast(mesh, Vector3(5, 1.1, 0.5), Vector3.LEFT).is_empty(), "Empty space next to a voxel accepted a part.")
	var gap: ArrayMesh = Voxels.from_cells({Vector3i.ZERO: Color.WHITE, Vector3i(2, 0, 0): Color.RED}, 1.0, true)
	_expect(Voxels.raycast(gap, Vector3(1.5, 5, 0.5), Vector3.DOWN).is_empty(), "An empty cell inside the body bounds accepted a part.")
	for kind: String in ["ellipsoid", "capsule", "cone"]:
		_check_cubic_faces(Voxels.primitive(Vector3(0.25, 0.8, 0.25), kind))


func _check_cubic_faces(mesh: ArrayMesh) -> void:
	_expect(mesh.get_surface_count() == 1, "Voxel piece must be a single visible mesh surface.")
	if mesh.get_surface_count() != 1:
		return
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var step: float = float(mesh.get_meta("voxel_size"))
	var aligned: bool = true
	var flat: bool = true
	var winding: bool = true
	for index in range(vertices.size()):
		var grid: Vector3 = vertices[index] / step
		aligned = aligned and grid.distance_to(grid.round()) < 0.0001
		var normal: Vector3 = normals[index]
		# Godot packs normals into octahedral 16-bit values. Reading the mesh
		# back introduces tiny off-axis errors even for exact unit-axis input.
		flat = flat and normal.round().length_squared() == 1.0 and normal.distance_to(normal.round()) < 0.0001
		flat = flat and colors[index].is_equal_approx(colors[index - index % 4])
	for index in range(0, indices.size(), 3):
		var a: int = indices[index]
		var actual: Vector3 = (vertices[indices[index + 2]] - vertices[a]).cross(vertices[indices[index + 1]] - vertices[a]).normalized()
		winding = winding and actual.dot(normals[a]) > 0.99
	_expect(aligned, "Creature faces are off the equal-sized cubic lattice.")
	_expect(flat, "Voxel faces have interpolated normals or color gradients.")
	_expect(winding, "Voxel faces are inside-out or degenerate.")


func _geometry_count(node: Node) -> int:
	var count: int = 1 if node is GeometryInstance3D else 0
	for child in node.get_children():
		count += _geometry_count(child)
	return count


func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		# Coordinates come from the logical viewport, which can be scaled by
		# DisplaySettings. Mark them local instead of applying scaling twice.
		root.push_input(event, true)
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
