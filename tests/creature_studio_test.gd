extends SceneTree

const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Spine = preload("res://creatures/editor/creature_spine_profile.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	_expect(preview.get_node_or_null("BodyV4/SculptedSkin") != null, "Continuous skin is absent.")
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
	var scene: PackedScene = load("res://creatures/editor/creature_editor.tscn")
	var editor: Node = scene.instantiate()
	root.add_child(editor)
	for frame in range(14):
		await process_frame
	_expect(editor.find_child("CreatureCanvas", true, false) != null, "Workshop input canvas missing.")
	_expect(editor.find_child("Card_body_balanced_core", true, false) != null, "Visual part palette missing.")
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
	var count: int = editor.get("blueprint")["parts"].size()
	editor.call("_set_mode", "parts")
	editor.call("drop_part", "eyes_beady", Vector2(2, 2))
	_expect(editor.get("blueprint")["parts"].size() == count, "Dropping outside the body created a part.")
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
		print("Creature studio test passed: knot constraints, persistence, identities, skin/anchors, motion, undo/redo and safe drops. Geometry nodes: ", geometry)
	quit(0 if _failures.is_empty() else 1)


func _geometry_count(node: Node) -> int:
	var count: int = 1 if node is GeometryInstance3D else 0
	for child in node.get_children():
		count += _geometry_count(child)
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
