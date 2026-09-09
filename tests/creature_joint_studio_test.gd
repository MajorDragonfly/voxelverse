extends SceneTree
## Real input gestures, authored rest shapes and native terrain contacts.
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Blueprint = Assembly.BaseBlueprint
const JointProfile = Blueprint.JointProfile
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Gait = preload("res://creatures/runtime/creature_gait_profile.gd")
const Course = preload("res://creatures/editor/creature_test_course.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_authoring()
	await _check_course_geometry()
	await _check_direct_inputs()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("Creature joint studio passed: native rotation/scale/joint handles, one gesture per undo, cancel/redo preservation, V7 joint roundtrip, 2/4/6-leg gait, physical ramps/steps, pause/restart and intact designs.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _design(pairs: int) -> Dictionary:
	var blueprint: Dictionary = Assembly.create_default()
	blueprint["parts"] = []
	for index in range(pairs):
		Blueprint.add_part(blueprint, ["legs_walker", "legs_stubby", "legs_spider"][index])
	Anatomy.reset_all_anchors(blueprint)
	for index in range(pairs):
		var part: Dictionary = blueprint["parts"][index]
		part["anchor_t"] = 0.25 + 0.24 * index
		part["anchor_vertical"] = -0.2 - 0.12 * index
		part["joint"] = {"upper": 1.35 + 0.1 * index, "lower": 0.72 + 0.1 * index, "offset": Vector3(0.12, 0.04, 0.1)}
		part["rotation"] = Vector3(8, -15, 12)
		part["end_part_id"] = "feet_claws" if index == 0 else "feet_hooves"
	Anatomy.rebind_all_parts(blueprint)
	return blueprint


func _preview(blueprint: Dictionary) -> Preview:
	var preview := Preview.new()
	root.add_child(preview)
	preview.set_editor_state(blueprint, -1, -1, false)
	return preview


func _leg_records(preview: Node3D) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for child in preview.get_children():
		if child is Node3D and str(child.get_meta("creature_part_category", "")) == "legs" and child.has_meta("sculpt_limb_rig"):
			records.append(child.get_meta("sculpt_limb_rig"))
	return records


func _check_authoring() -> void:
	var invalid: Dictionary = JointProfile.read({"upper": NAN, "lower": -80, "offset": ["bad", INF, 200]})
	_expect(is_equal_approx(invalid["upper"], 1.0) and is_equal_approx(invalid["lower"], 0.4) and Vector3(invalid["offset"]).is_finite(), "Malformed joint data did not receive finite bounds.")
	for pairs in range(1, 4):
		var blueprint: Dictionary = _design(pairs)
		var preview := _preview(blueprint)
		var records: Array[Dictionary] = _leg_records(preview)
		var before: String = JSON.stringify(blueprint)
		for index in range(0, records.size(), 2):
			var a: Vector3 = records[index]["knee"].global_position
			var b: Vector3 = records[index + 1]["knee"].global_position
			_expect((a * Vector3(-1, 1, 1)).distance_to(b) < 0.0002, "Authored knee pair lost reflection after rotated attachment.")
		for mode: String in ["idle", "walk", "run"]:
			preview.set_motion(mode)
			preview.set_process(false)
			for sample_index in range(20):
				preview._motion.sample(mode, float(sample_index) * 0.13)
				var planted: int = 0
				for record in records:
					var foot: Node3D = record["foot"]
					var gap: float = foot.global_position.y - float(preview.get_meta("ground_y"))
					_expect(gap >= -0.0002 and foot.global_position.is_finite(), "Authored limb penetrated its standing plane: %.5f" % gap)
					if absf(gap) < 0.0002:
						planted += 1
				_expect(planted >= pairs, "Gait lost its supporting feet.")
		_expect(before == JSON.stringify(blueprint), "Movement wrote posed joints into the saved design.")
		preview.set_motion("edit")
		preview.free()
	var blueprint: Dictionary = _design(2)
	Blueprint.add_part(blueprint, "arms_grasping")
	blueprint["parts"][2]["joint"] = {"upper": 0.6, "lower": 1.7, "offset": Vector3(0.2, -0.12, -0.15)}
	Assembly.normalize(blueprint)
	var stats: Dictionary = Blueprint.calculate_stats(blueprint)
	_expect(Assembly.save_to_file(blueprint, "user://joint_studio.json") == OK, "Could not save authored limb proportions.")
	var loaded: Dictionary = Assembly.load_from_file("user://joint_studio.json")
	for index in range(3):
		var saved_joint: Dictionary = blueprint["parts"][index]["joint"]
		var loaded_joint: Dictionary = loaded["parts"][index]["joint"]
		_expect(is_equal_approx(saved_joint["upper"], loaded_joint["upper"]) and is_equal_approx(saved_joint["lower"], loaded_joint["lower"]) and Vector3(saved_joint["offset"]).is_equal_approx(loaded_joint["offset"]), "V7 roundtrip lost joint %d: %s -> %s" % [index, saved_joint, loaded_joint])
	_expect(Blueprint.calculate_stats(loaded) == stats, "Joint authoring changed progression or skill stats.")
	var short_design: Dictionary = _design(1)
	short_design["parts"][0]["scale"] = 0.6
	var short_preview := _preview(short_design)
	var short_gait: Dictionary = Gait.build(_leg_records(short_preview))
	short_design["parts"][0]["scale"] = 1.6
	var long_preview := _preview(short_design)
	var long_gait: Dictionary = Gait.build(_leg_records(long_preview))
	_expect(float(long_gait["stride"]) > float(short_gait["stride"]) and float(long_gait["cadence"]) < float(short_gait["cadence"]), "Leg reach did not affect stride and cadence.")
	short_preview.free()
	long_preview.free()


func _check_course_geometry() -> void:
	var course := Course.new()
	root.add_child(course)
	for kind: String in ["slope", "steps"]:
		course.configure(kind, 0.0, Vector3(2, 2, 3))
		for frame in range(3):
			await physics_frame
		for entry in ([[2.0, 0.0], [0.6, 0.15], [0.0, 0.3], [-2.0, 0.6]] if kind == "slope" else [[2.0, 0.0], [0.7, 0.18], [0.0, 0.36], [-0.7, 0.54], [-2.0, 0.72]]):
			var hit: Dictionary = _ray(course, Vector3(0, 1.5, entry[0]))
			_expect(not hit.is_empty() and absf(Vector3(hit.get("position", Vector3.INF)).y - float(entry[1])) < 0.001, "Native course collider does not match its visible tread/ramp: " + kind)
	course.free()


func _check_direct_inputs() -> void:
	root.size = Vector2i(1600, 900)
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16):
		await process_frame
	editor.call("_set_mode", "parts")
	editor.call("_select_part_by_index", 2)
	var original_rotation: Vector3 = editor.get("blueprint")["parts"][2]["rotation"]
	var history: RefCounted = editor.get("_history")
	var undo_count: int = history.get("_undo_stack").size()
	await _drag(editor, "rotate", 1, false)
	_expect(Blueprint._as_vector3(editor.get("blueprint")["parts"][2]["rotation"]).distance_to(original_rotation) > 5, "Native ring drag did not rotate the selected limb.")
	_expect(history.get("_undo_stack").size() == undo_count + 1, "A drag created more than one undo operation.")
	editor.call("_undo_edit")
	_expect(Blueprint._as_vector3(editor.get("blueprint")["parts"][2]["rotation"]).distance_to(original_rotation) < 0.001, "Ring undo did not restore the original orientation.")
	var before_cancel: String = JSON.stringify(editor.get("blueprint"))
	var redo_count: int = history.get("_redo_stack").size()
	await _drag(editor, "rotate", 2, true)
	_expect(JSON.stringify(editor.get("blueprint")) == before_cancel and history.get("_redo_stack").size() == redo_count, "Escape changed the design or erased the previous redo history.")
	Assembly.set_snap_to_surface(editor.get("blueprint"), false)
	var old_position: Vector3 = editor.get("blueprint")["parts"][2]["position"]
	await _drag(editor, "move", 2, false)
	var moved: Vector3 = editor.get("blueprint")["parts"][2]["position"]
	_expect(moved.z > old_position.z + 0.01 and is_equal_approx(moved.x, old_position.x) and is_equal_approx(moved.y, old_position.y), "Native translation handle did not isolate its selected axis.")
	editor.call("_undo_edit")
	Assembly.set_snap_to_surface(editor.get("blueprint"), true)
	var old_shape: Vector3 = Blueprint.get_part_shape(editor.get("blueprint")["parts"][2])
	await _drag(editor, "scale", 0, false)
	_expect(Blueprint.get_part_shape(editor.get("blueprint")["parts"][2]).x > old_shape.x, "Native size handle did not change the selected axis.")
	await _drag(editor, "joint", -1, false)
	_expect(Vector3(editor.get("blueprint")["parts"][2]["joint"]["offset"]).length() > 0.01, "Native knee handle did not author a joint offset.")
	var upper: SpinBox = editor.find_child("Joint_upper", true, false)
	upper.value = 160
	_expect(is_equal_approx(editor.get("blueprint")["parts"][2]["joint"]["upper"], 1.6), "Upper-segment control did not reach the blueprint.")
	editor.call("_choose_transform_target", 1)
	var parent_rotation: Vector3 = editor.get("blueprint")["parts"][2]["rotation"]
	await _drag(editor, "rotate", 1, false)
	_expect(editor.get("blueprint")["parts"][2]["rotation"] == parent_rotation and Blueprint._as_vector3(editor.get("blueprint")["parts"][2].get("end_rotation", Vector3.ZERO)).length() > 5, "End-piece ring changed the parent limb.")
	editor.set("blueprint", _design(2))
	editor.call("_set_mode", "test")
	var before_test: String = JSON.stringify(editor.get("blueprint"))
	for kind: String in ["slope", "steps"]:
		var button: Control = editor.find_child("Course_" + kind, true, false)
		var ancestor: Node = button.get_parent()
		while ancestor != null and not ancestor is ScrollContainer:
			ancestor = ancestor.get_parent()
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
		await process_frame
		await _click(button.get_global_rect().get_center())
		_expect(str(editor.get("_course_choice")) == kind, "Native course button did not change the route.")
		var preview: Node3D = editor.get("_preview")
		var course: Node3D = editor.get("_course")
		for mode: String in ["walk", "run"]:
			editor.call("_choose_motion", mode)
			preview.set_process(false)
			for frame in range(3):
				await physics_frame
			var motion: RefCounted = preview.get("_motion")
			var start: Vector3 = preview.position
			for sample_index in range(1, 25):
				motion.call("sample", mode, float(sample_index) * 0.23)
				var grounded: int = 0
				for record in _leg_records(preview):
					var foot: Node3D = record["foot"]
					var hit: Dictionary = _ray(course, course.to_local(foot.global_position) + Vector3.UP * 1.5)
					_expect(not hit.is_empty(), "An animated sole left the physical course.")
					if hit.is_empty():
						continue
					var gap: float = foot.global_position.y - Vector3(hit["position"]).y
					_expect(gap >= -0.002 and gap < 0.8, "Sole penetrated or floated far above %s: %.4f" % [kind, gap])
					if absf(gap) < 0.002:
						grounded += 1
				_expect(grounded > 0, "All course feet were airborne.")
			_expect(preview.position.distance_to(start) > 0.5, "The creature did not travel along the selected course.")
		editor.call("_toggle_course_pause")
		_expect(not preview.is_processing(), "Pause did not stop the preview clock.")
		editor.call("_restart_course")
		_expect(preview.is_processing() and is_zero_approx(float(preview.get("_motion_time"))), "Restart did not reset and resume the course.")
	_expect(before_test == JSON.stringify(editor.get("blueprint")), "Test-course posing modified the authored design.")
	editor.call("_set_mode", "parts")
	_expect(editor.get("_preview").position.is_equal_approx(Vector3.ZERO) and editor.get_node("SculptingPlinth").visible, "Leaving the course did not restore the authoring workbench.")
	editor.free()
	await process_frame


func _ray(course: Node3D, local_point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(course.to_global(local_point), course.to_global(local_point + Vector3.DOWN * 5), Course.COLLISION_LAYER)
	return course.get_world_3d().direct_space_state.intersect_ray(query)


func _drag(editor: Node, mode: String, axis: int, cancel: bool) -> void:
	editor.call("_choose_tool", mode)
	await process_frame
	var gizmo: Control = editor.get("_gizmo")
	var handle: Dictionary = {}
	var start := Vector2.ZERO
	var finish := Vector2.ZERO
	for candidate: Dictionary in gizmo.call("handles"):
		if int(candidate["axis"]) != axis:
			continue
		var points: PackedVector2Array = candidate["points"]
		for index in range(points.size()):
			var hit: Dictionary = gizmo.call("hit_test", points[index])
			if int(hit.get("axis", -99)) == axis:
				handle = candidate
				start = points[index]
				finish = points[(index + 7) % (points.size() - 1)] if mode == "rotate" else start + (Vector2(22, -18) if axis < 0 else (points[-1] - Vector2(candidate["center"])).normalized() * 26)
				break
	_expect(not handle.is_empty(), "No usable native handle for " + mode)
	if handle.is_empty():
		return
	await _mouse_button(start, true)
	for index in range(1, 4):
		var event := InputEventMouseMotion.new()
		event.position = start.lerp(finish, float(index) / 3.0)
		event.relative = (finish - start) / 3.0
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(event, true)
		await process_frame
	if cancel:
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.pressed = true
		root.push_input(key, true)
		await process_frame
	await _mouse_button(finish, false)


func _click(point: Vector2) -> void:
	await _mouse_button(point, true)
	await _mouse_button(point, false)


func _mouse_button(point: Vector2, pressed: bool) -> void:
	if pressed:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and failures.size() < 35:
		failures.append(message)
