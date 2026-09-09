extends "res://creatures/editor/creature_editor_studio.gd"
## Direct authoring tools and a bounded, reversible movement workbench.
const TransformGizmo = preload("res://creatures/editor/creature_transform_gizmo.gd")
const JointProfile = preload("res://creatures/editor/creature_joint_profile.gd")
const TestCourse = preload("res://creatures/editor/creature_test_course.gd")
var _gizmo: Control
var _tool_mode: String = "move"
var _gizmo_side: float = 1.0
var _tool_buttons: Dictionary = {}
var _joint_controls: VBoxContainer
var _joint_fields: Dictionary = {}
var _course: Node3D
var _course_choice: String = "flat"
var _course_paused: bool = false
var _course_label: Label
var _preview_speed: float = 1.0


func _build_editor_room() -> void:
	super._build_editor_room()
	_course = TestCourse.new()
	_course.name = "MovementTestCourse"
	_preview_pivot.add_child(_course)


func _build_ui() -> void:
	super._build_ui()
	_gizmo = TransformGizmo.new()
	_gizmo.name = "DirectPartHandles"
	_gizmo.set("editor", self)
	_gizmo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(_gizmo)
	_ui_root.move_child(_gizmo, 1)


func _build_part_controls() -> void:
	super._build_part_controls()
	var tools := GridContainer.new()
	tools.name = "DirectTools"
	tools.columns = 2
	_part_controls.add_child(tools)
	_part_controls.move_child(tools, 1)
	for entry in [["move", "Verschieben · W"], ["rotate", "Drehen · E"], ["scale", "Größe · R"], ["joint", "Gelenk · J"]]:
		var button := _button(tools, entry[1], _choose_tool.bind(entry[0]))
		button.name = "Tool_" + str(entry[0])
		button.toggle_mode = true
		button.custom_minimum_size.y = 32
		button.add_theme_font_size_override("font_size", 12)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tool_buttons[entry[0]] = button
	_joint_controls = VBoxContainer.new()
	_joint_controls.name = "JointSettings"
	_part_controls.add_child(_joint_controls)
	_part_controls.move_child(_joint_controls, 2)
	_label(_joint_controls, "Gelenkpunkt ziehen · Umschalt: Raster", 12)
	for field in ["upper", "lower"]:
		var row := HBoxContainer.new()
		_joint_controls.add_child(row)
		var label := _label(row, "Oberes Segment" if field == "upper" else "Unteres Segment", 12)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var spin := SpinBox.new()
		spin.name = "Joint_" + field
		spin.min_value = 40
		spin.max_value = 220
		spin.step = 5
		spin.suffix = "%"
		spin.custom_minimum_size.x = 92
		spin.get_line_edit().add_theme_font_size_override("font_size", 13)
		spin.value_changed.connect(_change_joint_field.bind(field, -1))
		spin.get_line_edit().focus_entered.connect(_begin_gesture)
		spin.get_line_edit().focus_exited.connect(_end_gesture)
		row.add_child(spin)
		_joint_fields[field] = spin
	_label(_joint_controls, "Gelenkversatz · X / Y / Z", 12)
	var row := HBoxContainer.new()
	_joint_controls.add_child(row)
	for axis in range(3):
		var spin := SpinBox.new()
		spin.name = "Joint_offset_%d" % axis
		spin.min_value = -30 if axis == 1 else -60
		spin.max_value = 30 if axis == 1 else 60
		spin.step = 2
		spin.suffix = "%"
		spin.custom_minimum_size.x = 78
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.get_line_edit().add_theme_font_size_override("font_size", 12)
		spin.value_changed.connect(_change_joint_field.bind("offset", axis))
		spin.get_line_edit().focus_entered.connect(_begin_gesture)
		spin.get_line_edit().focus_exited.connect(_end_gesture)
		row.add_child(spin)
		_joint_fields["offset_%d" % axis] = spin
	_button(_joint_controls, "Gelenk zurücksetzen", _reset_joint).add_theme_font_size_override("font_size", 12)


func _refresh_design_controls() -> void:
	super._refresh_design_controls()
	if _joint_controls == null:
		return
	var part: Dictionary = Blueprint.get_part_placement(blueprint, selected_part_index)
	var limb: bool = str(part.get("category", "")) in ["legs", "arms"]
	_joint_controls.visible = _studio_mode == "parts" and limb and not _editing_terminal and _tool_mode == "joint"
	for key: String in _tool_buttons:
		_tool_buttons[key].set_pressed_no_signal(_tool_mode == key)
		_tool_buttons[key].disabled = (key == "joint" and (not limb or _editing_terminal)) or (key == "move" and _editing_terminal)
	var joint: Dictionary = JointProfile.read(part.get("joint", {}))
	for field in ["upper", "lower"]:
		_joint_fields[field].set_value_no_signal(float(joint[field]) * 100.0)
	for axis in range(3):
		_joint_fields["offset_%d" % axis].set_value_no_signal(Vector3(joint["offset"])[axis] * 100.0)


func _choose_tool(mode: String) -> void:
	if mode == "joint" and (current_category not in ["legs", "arms"] or _editing_terminal):
		return
	if mode == "move" and _editing_terminal:
		return
	_end_gesture()
	_tool_mode = mode
	if _gizmo != null:
		_gizmo.set("mode", mode)
	_refresh_stats_panel()
	_set_builder_status({"move": "Pfeil ziehen: eine Achse verschieben · Andocken bleibt wirksam.", "rotate": "Farbring ziehen: lokal drehen · Umschalt: 15°-Schritte.", "scale": "Quadrat ziehen: Proportion ändern · Mitte: Gesamtgröße.", "joint": "Goldenen Gelenkpunkt oder Achsen ziehen · Rechts: Segmentlängen."}.get(mode, ""))


func _choose_transform_target(index: int) -> void:
	if index == 1 and _tool_mode in ["move", "joint"]:
		_choose_tool("rotate")
	super._choose_transform_target(index)


func _select_part_by_index(index: int) -> void:
	_end_gesture()
	var part: Dictionary = Blueprint.get_part_placement(blueprint, index)
	if not part.is_empty() and _tool_mode == "joint" and str(part.get("category", "")) not in ["legs", "arms"]:
		_tool_mode = "move"
		if _gizmo != null:
			_gizmo.set("mode", "move")
	super._select_part_by_index(index)


func _change_joint_field(value: float, field: String, axis: int) -> void:
	if _syncing_ui or _studio_mode != "parts" or _editing_terminal:
		return
	var part: Dictionary = Blueprint.get_part_placement(blueprint, selected_part_index)
	if str(part.get("category", "")) not in ["legs", "arms"]:
		return
	_record_before_edit("Gelenk formen")
	var joint: Dictionary = JointProfile.read(part.get("joint", {}))
	if field == "offset":
		var offset: Vector3 = joint["offset"]
		offset[axis] = value / 100.0
		joint["offset"] = offset
	else:
		joint[field] = value / 100.0
	part["joint"] = JointProfile.read(joint)
	_refresh_preview()
	_refresh_stats_panel()


func _reset_joint() -> void:
	var part: Dictionary = Blueprint.get_part_placement(blueprint, selected_part_index)
	if part.is_empty():
		return
	_record_before_edit("Gelenk zurücksetzen", true)
	part["joint"] = JointProfile.read({})
	_refresh_preview()
	_refresh_stats_panel()


func _gizmo_context(mode: String) -> Dictionary:
	if _studio_mode != "parts" or selected_part_index < 0 or not is_instance_valid(_preview):
		return {}
	var part: Dictionary = Blueprint.get_part_placement(blueprint, selected_part_index)
	if part.is_empty() or (mode == "move" and _editing_terminal):
		return {}
	var target_root: Node3D
	for child in _preview.get_children():
		if child is Node3D and int(child.get_meta("creature_part_index", -1)) == selected_part_index:
			if target_root == null or float(child.get_meta("creature_part_side", 1.0)) == _gizmo_side:
				target_root = child
	if target_root == null:
		return {}
	var target: Node3D = target_root
	var rig: Dictionary = target_root.get_meta("sculpt_limb_rig", {})
	if mode == "joint":
		if rig.is_empty() or _editing_terminal:
			return {}
		target = rig["knee"]
	elif _editing_terminal and not rig.is_empty():
		target = rig["socket"]
	var side: float = target_root.get_meta("creature_part_side", 1.0)
	var angles: Vector3 = Blueprint._as_vector3(part.get("end_rotation" if _editing_terminal else "rotation", Vector3.ZERO)) * Vector3(1, side, side)
	return {"origin": target.global_position, "basis": (_preview.global_basis if mode == "move" else (target_root.global_basis if mode == "joint" else target.global_basis)).orthonormalized(),
		"frame": target_root.global_transform, "side": side, "local_basis": Basis.from_euler(angles * PI / 180.0),
		"reference_length": target_root.get_meta("joint_reference_length", 1.0)}


func _apply_gizmo_drag(data: Dictionary, amount: float, delta: Vector2) -> void:
	var index: int = data["index"]
	if selected_part_index != index or _editing_terminal != bool(data["terminal"]):
		return
	var part: Dictionary = Blueprint.get_part_placement(blueprint, index)
	var original: Dictionary = data["blueprint"]["parts"][index]
	if str(part.get("uid", "")) != str(original.get("uid", "")):
		return
	_record_before_edit("Direkt formen")
	var mode: String = data["mode"]
	var axis: int = data["axis"]
	var context: Dictionary = data["context"]
	if mode == "move":
		var value: Vector3 = original["position"]
		value[axis] += amount * float(data["unit"]) * 82.0 / maxf(_preview.global_basis[axis].length(), 0.01)
		_change_part_field(value[axis], "position", axis)
		return
	if mode == "scale":
		if axis < 0:
			_change_part_field(float(original.get("end_scale" if _editing_terminal else "scale", 1.0)) * maxf(0.1, 1.0 + amount), "scale", 0)
		else:
			var shape: Vector3 = Blueprint.get_part_shape(original, "end_shape_scale" if _editing_terminal else "shape_scale")
			_change_part_field(shape[axis] * maxf(0.1, 1.0 + amount), "shape", axis)
		return
	if mode == "rotate":
		var local_axis := Vector3.ZERO
		local_axis[axis] = 1.0
		var rotation: Basis = Basis(context["local_basis"]) * Basis(local_axis, deg_to_rad(amount))
		part["end_rotation" if _editing_terminal else "rotation"] = rotation.get_euler() * 180.0 / PI * Vector3(1, context["side"], context["side"])
	else:
		var joint: Dictionary = JointProfile.read(original.get("joint", {}))
		var world_delta: Vector3 = (_camera.global_basis.x * delta.x - _camera.global_basis.y * delta.y) * float(data["unit"])
		if axis >= 0:
			world_delta = Basis(context["basis"])[axis] * amount * float(data["unit"]) * 82.0
		var local: Vector3 = Transform3D(context["frame"]).basis.inverse() * world_delta
		joint["offset"] = Vector3(joint["offset"]) + local * Vector3(context["side"], 1, 1) / maxf(float(context["reference_length"]) * float(joint["upper"]), 0.05)
		part["joint"] = JointProfile.read(joint)
	_refresh_preview()
	_refresh_stats_panel()


func _cancel_gizmo_drag(data: Dictionary) -> void:
	blueprint = data["blueprint"].duplicate(true)
	_history.set("_undo_stack", data["history_undo"])
	_history.set("_redo_stack", data["history_redo"])
	_refresh_preview()
	_refresh_stats_panel()
	_set_builder_status("Bearbeitung abgebrochen.")


func handle_canvas_input(event: InputEvent) -> void:
	if _gizmo != null:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _studio_mode == "parts":
			get_viewport().gui_release_focus()
			if bool(_gizmo.call("begin", event.position + _canvas.global_position - _gizmo.global_position)):
				return
		if event is InputEventMouseMotion and _studio_mode == "parts":
			_gizmo.call("motion", event.position + _canvas.global_position - _gizmo.global_position, event.shift_pressed)
	super.handle_canvas_input(event)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _drag_part:
		_gizmo_side = _drag_side


func _input(event: InputEvent) -> void:
	if _gizmo != null and not _gizmo.get("drag").is_empty():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_gizmo.call("finish", true)
			_end_gesture()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseMotion:
			_gizmo.call("motion", event.position - _gizmo.global_position, event.shift_pressed)
			get_viewport().set_input_as_handled()
			return
	super._input(event)


func _end_gesture() -> void:
	if _gizmo != null:
		_gizmo.call("finish")
	super._end_gesture()


func _handle_key(event: InputEventKey) -> void:
	if not _is_typing_text() and event.pressed and not event.echo and not event.ctrl_pressed and _studio_mode == "parts":
		var keys: Dictionary = {KEY_W: "move", KEY_E: "rotate", KEY_R: "scale", KEY_J: "joint"}
		if keys.has(event.keycode):
			_choose_tool(keys[event.keycode])
			get_viewport().set_input_as_handled()
			return
	super._handle_key(event)


func _refresh_part_palette() -> void:
	_course_label = null
	super._refresh_part_palette()
	if _studio_mode != "test":
		return
	_label(_part_grid, "TESTSTRECKE", 13)
	for entry in [["flat", "Arbeitsfläche"], ["slope", "Steigung"], ["steps", "Stufen"]]:
		var button := _button(_part_grid, entry[1], _choose_course.bind(entry[0]))
		button.name = "Course_" + str(entry[0])
		button.toggle_mode = true
		button.set_pressed_no_signal(_course_choice == entry[0])
	var actions := HBoxContainer.new()
	_part_grid.add_child(actions)
	_button(actions, "Weiter" if _course_paused else "Pause", _toggle_course_pause).name = "CoursePause"
	_button(actions, "Neu starten", _restart_course).name = "CourseRestart"
	_label(_part_grid, "Tempo der Vorschau", 12)
	var speed := HSlider.new()
	speed.name = "PreviewSpeed"
	speed.min_value = 0.5
	speed.max_value = 1.5
	speed.step = 0.1
	speed.value = _preview_speed
	speed.value_changed.connect(func(value: float) -> void:
		_preview_speed = value
		_preview.set("motion_speed_scale", value)
	)
	_part_grid.add_child(speed)
	_course_label = _label(_part_grid, "", 13)
	_course_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.text = "Teste Haltung und Schritte auf der Arbeitsfläche, an einer Steigung oder auf Stufen."


func _refresh_preview() -> void:
	if is_instance_valid(_preview):
		_preview.call("set_motion", "edit")
	super._refresh_preview()
	if _course == null or not is_instance_valid(_preview):
		return
	# The screen-sized gizmo replaces the previous fixed-size guides.
	if _studio_mode == "parts" and _gizmo != null:
		for guide in _preview.find_children("SelectionRing", "MeshInstance3D", true, false) + _preview.find_children("LocalAxis*", "MeshInstance3D", true, false):
			guide.visible = false
	var testing: bool = _studio_mode == "test" and _course_choice != "flat"
	_course.call("configure", _course_choice if testing else "flat", _preview.get_meta("ground_y", -1.0), _geometry_bounds(_preview).size)
	get_node("SculptingPlinth").visible = not testing
	get_node("PlinthRim").visible = not testing
	_preview.set("motion_speed_scale", _preview_speed)
	if testing:
		_preview.get("_motion").call("set_course", _course)
		_preview.get("_motion").call("sample", _motion_choice, 0.0)
	if _studio_mode == "test":
		_preview.set_process(not _course_paused)


func _choose_motion(mode: String) -> void:
	_course_paused = false
	super._choose_motion(mode)
	if _course != null and _course_choice != "flat":
		_preview.get("_motion").call("set_course", _course)
		_preview.get("_motion").call("sample", mode, 0.0)


func _choose_course(kind: String) -> void:
	_end_gesture()
	_course_choice = kind
	_course_paused = false
	_refresh_preview()
	_refresh_part_palette()
	_frame_creature()


func _toggle_course_pause() -> void:
	_course_paused = not _course_paused
	_preview.set_process(not _course_paused)
	_refresh_part_palette()


func _restart_course() -> void:
	_choose_motion(_motion_choice)


func _process(_delta: float) -> void:
	if not is_instance_valid(_course_label) or not is_instance_valid(_preview):
		return
	var motion: RefCounted = _preview.get("_motion")
	var profile: Dictionary = motion.get("_profile")
	_course_label.text = "%s · %d Beine\n%s" % [profile.get("name", ""), int(profile.get("count", 0)), "Ziel erreicht · Neu starten" if bool(motion.get("course_finished")) else ("Angehalten" if _course_paused else "Entwurf bleibt erhalten")]


func _frame_creature() -> void:
	super._frame_creature()
	if _studio_mode == "test" and _course_choice != "flat" and is_instance_valid(_course):
		var length: float = _course.get("course_length")
		_camera.position = Vector3(0, length * 0.52, length * 1.4)
		_camera.look_at(Vector3(0, -0.3, 0))
