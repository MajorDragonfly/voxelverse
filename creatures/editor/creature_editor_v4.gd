extends "res://creatures/editor/creature_editor.gd"

const BasePartLibrary = preload(
	"res://creatures/editor/creature_part_library.gd"
)

const SpineProfile = preload(
	"res://creatures/editor/creature_spine_profile.gd"
)

const PreviewV4 = preload(
	"res://creatures/editor/creature_preview_v4.gd"
)

const BASE_SAVE_PATH: String = (
	"user://creature_editor_blueprint.json"
)

const MOUSE_WIDTH_SPEED: float = 0.004
const MOUSE_HEIGHT_SPEED: float = 0.004
const MOUSE_CURVE_SPEED: float = 0.006

const KEY_WIDTH_STEP: float = 0.05
const KEY_HEIGHT_STEP: float = 0.05
const KEY_CURVE_STEP: float = 0.05

const HANDLE_CLICK_RADIUS: float = 42.0

var selected_body_segment: int = -1
var _is_dragging_spine_segment: bool = false


func _ready() -> void:
	super._ready()

	SpineProfile.ensure_profile(blueprint)

	_replace_preview_with_v4()

	if _title_label != null:
		_title_label.text = (
			"VOXELVERSE CREATURE EDITOR V4"
		)

	if _help_label != null:
		_help_label.text = (
			"BODY MODE:\n"
			+ "Click cyan handle = select segment.\n"
			+ "Drag left/right = width.\n"
			+ "Drag up/down = body curve.\n"
			+ "Shift + drag up/down = height.\n"
			+ "Mouse wheel = width.\n"
			+ "Shift + wheel = height.\n"
			+ "Arrow keys = width / curve.\n"
			+ "PageUp/PageDown = height.\n"
			+ "X = reset selected segment.\n\n"
			+ "PART MODE:\n"
			+ "Click part = select.\n"
			+ "LMB drag = move.\n"
			+ "RMB drag = rotate.\n"
			+ "Mouse wheel = scale."
		)

	_refresh_all()

	print(
		"Creature Editor V4 ready. "
		+ "Editable spine segments enabled."
	)


func _input(event: InputEvent) -> void:
	if _try_handle_spine_input(event):
		get_viewport().set_input_as_handled()


func _replace_preview_with_v4() -> void:
	if _preview_pivot == null:
		return

	if is_instance_valid(_preview):
		_preview.queue_free()

	_preview = PreviewV4.new()
	_preview.name = "CreaturePreviewV4"

	_preview_pivot.add_child(_preview)


func _refresh_preview() -> void:
	if _preview == null:
		return

	SpineProfile.ensure_profile(blueprint)

	if _preview.has_method("set_editor_state"):
		_preview.call(
			"set_editor_state",
			blueprint,
			selected_part_index,
			selected_body_segment,
			current_category
				== BasePartLibrary.CATEGORY_BODY
				or selected_body_segment >= 0
		)

		return

	_preview.call(
		"set_blueprint",
		blueprint
	)

	_preview.call(
		"set_selected_part_index",
		selected_part_index
	)


func _refresh_stats_panel() -> void:
	super._refresh_stats_panel()

	if (
		selected_body_segment < 0
		or _selection_label == null
	):
		return

	var segment: Dictionary = (
		SpineProfile.get_segment(
			blueprint,
			selected_body_segment
		)
	)

	_selection_label.text = (
		"Selected: Body Segment %d / %d\n"
		+ "Width: %d%%\n"
		+ "Height: %d%%\n"
		+ "Curve offset: %.2f\n\n"
		+ "Drag the yellow handle.\n"
		+ "Press X to reset this segment."
	) % [
		selected_body_segment + 1,
		SpineProfile.SEGMENT_COUNT,
		roundi(
			float(
				segment.get(
					"width_scale",
					1.0
				)
			)
			* 100.0
		),
		roundi(
			float(
				segment.get(
					"height_scale",
					1.0
				)
			)
			* 100.0
		),
		float(
			segment.get(
				"y_offset",
				0.0
			)
		),
	]


func _try_handle_spine_input(
	event: InputEvent
) -> bool:
	if event is InputEventMouseButton:
		return _handle_spine_mouse_button(event)

	if event is InputEventMouseMotion:
		return _handle_spine_mouse_motion(event)

	if event is InputEventKey:
		return _handle_spine_key(event)

	return false


func _handle_spine_mouse_button(
	event: InputEventMouseButton
) -> bool:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			if _is_dragging_spine_segment:
				_is_dragging_spine_segment = false
				return true

			return false

		if _is_pointer_over_v4_ui(event.position):
			return false

		var picked_segment: int = (
			_pick_spine_segment(
				event.position
			)
		)

		if picked_segment >= 0:
			_select_spine_segment(
				picked_segment
			)

			_is_dragging_spine_segment = true
			return true

		if selected_body_segment >= 0:
			_clear_spine_selection(true)

		return false

	if (
		not event.pressed
		or selected_body_segment < 0
		or _is_pointer_over_v4_ui(
			event.position
		)
	):
		return false

	if (
		event.button_index
		== MOUSE_BUTTON_WHEEL_UP
	):
		if event.shift_pressed:
			_apply_spine_delta(
				0.0,
				KEY_HEIGHT_STEP,
				0.0
			)
		else:
			_apply_spine_delta(
				KEY_WIDTH_STEP,
				0.0,
				0.0
			)

		return true

	if (
		event.button_index
		== MOUSE_BUTTON_WHEEL_DOWN
	):
		if event.shift_pressed:
			_apply_spine_delta(
				0.0,
				-KEY_HEIGHT_STEP,
				0.0
			)
		else:
			_apply_spine_delta(
				-KEY_WIDTH_STEP,
				0.0,
				0.0
			)

		return true

	return false


func _handle_spine_mouse_motion(
	event: InputEventMouseMotion
) -> bool:
	if (
		not _is_dragging_spine_segment
		or selected_body_segment < 0
	):
		return false

	var width_delta: float = (
		event.relative.x
		* MOUSE_WIDTH_SPEED
	)

	var height_delta: float = 0.0
	var curve_delta: float = 0.0

	if event.shift_pressed:
		height_delta = (
			-event.relative.y
			* MOUSE_HEIGHT_SPEED
		)
	else:
		curve_delta = (
			-event.relative.y
			* MOUSE_CURVE_SPEED
		)

	_apply_spine_delta(
		width_delta,
		height_delta,
		curve_delta
	)

	return true


func _handle_spine_key(
	event: InputEventKey
) -> bool:
	if not event.pressed or event.echo:
		return false

	if event.ctrl_pressed:
		return false

	if _is_typing_v4_text():
		return false

	if selected_body_segment < 0:
		return false

	match event.keycode:
		KEY_LEFT:
			_apply_spine_delta(
				-KEY_WIDTH_STEP,
				0.0,
				0.0
			)
			return true

		KEY_RIGHT:
			_apply_spine_delta(
				KEY_WIDTH_STEP,
				0.0,
				0.0
			)
			return true

		KEY_UP:
			_apply_spine_delta(
				0.0,
				0.0,
				KEY_CURVE_STEP
			)
			return true

		KEY_DOWN:
			_apply_spine_delta(
				0.0,
				0.0,
				-KEY_CURVE_STEP
			)
			return true

		KEY_PAGEUP:
			_apply_spine_delta(
				0.0,
				KEY_HEIGHT_STEP,
				0.0
			)
			return true

		KEY_PAGEDOWN:
			_apply_spine_delta(
				0.0,
				-KEY_HEIGHT_STEP,
				0.0
			)
			return true

		KEY_X:
			SpineProfile.reset_segment(
				blueprint,
				selected_body_segment
			)

			_refresh_preview()
			_refresh_stats_panel()
			return true

		KEY_ESCAPE:
			_clear_spine_selection(true)
			return true

	return false


func _select_spine_segment(
	segment_index: int
) -> void:
	selected_body_segment = clampi(
		segment_index,
		0,
		SpineProfile.SEGMENT_COUNT - 1
	)

	selected_part_index = -1

	current_category = (
		BasePartLibrary.CATEGORY_BODY
	)

	_is_dragging_part = false
	_is_rotating_part_with_mouse = false
	_is_turning_creature = false

	_refresh_all()


func _clear_spine_selection(
	refresh_editor: bool
) -> void:
	selected_body_segment = -1
	_is_dragging_spine_segment = false

	if refresh_editor:
		_refresh_preview()
		_refresh_stats_panel()


func _apply_spine_delta(
	width_delta: float,
	height_delta: float,
	curve_delta: float
) -> void:
	if selected_body_segment < 0:
		return

	SpineProfile.adjust_segment(
		blueprint,
		selected_body_segment,
		width_delta,
		height_delta,
		curve_delta
	)

	_refresh_preview()
	_refresh_stats_panel()


func _pick_spine_segment(
	screen_position: Vector2
) -> int:
	if (
		_camera == null
		or _preview == null
		or not is_instance_valid(_preview)
	):
		return -1

	var handle_nodes: Array[Node] = (
		_preview.find_children(
			"SpineHandleV4_*",
			"StaticBody3D",
			true,
			false
		)
	)

	var closest_segment: int = -1
	var closest_distance: float = (
		HANDLE_CLICK_RADIUS
	)

	for handle_node in handle_nodes:
		if not (handle_node is Node3D):
			continue

		var handle: Node3D = handle_node

		if not handle.has_meta(
			"creature_spine_index"
		):
			continue

		if _camera.is_position_behind(
			handle.global_position
		):
			continue

		var handle_screen_position: Vector2 = (
			_camera.unproject_position(
				handle.global_position
			)
		)

		var distance: float = (
			screen_position.distance_to(
				handle_screen_position
			)
		)

		if distance >= closest_distance:
			continue

		closest_distance = distance

		closest_segment = int(
			handle.get_meta(
				"creature_spine_index"
			)
		)

	return closest_segment


func _is_pointer_over_v4_ui(
	screen_position: Vector2
) -> bool:
	var panels: Array = [
		_left_panel,
		_right_panel,
		_bottom_panel,
	]

	for panel_value in panels:
		if panel_value == null:
			continue

		if not (panel_value is Control):
			continue

		var panel: Control = panel_value

		if not panel.visible:
			continue

		if panel.get_global_rect().has_point(
			screen_position
		):
			return true

	return false


func _is_typing_v4_text() -> bool:
	var focus_owner: Control = (
		get_viewport().gui_get_focus_owner()
	)

	return (
		focus_owner is LineEdit
		or focus_owner is TextEdit
		or focus_owner is CodeEdit
	)


func _on_category_button_pressed(
	category_id: String
) -> void:
	if (
		category_id
		!= BasePartLibrary.CATEGORY_BODY
	):
		_clear_spine_selection(false)

	super._on_category_button_pressed(
		category_id
	)


func _on_part_button_pressed(
	part_id: String
) -> void:
	if (
		current_category
		!= BasePartLibrary.CATEGORY_BODY
	):
		_clear_spine_selection(false)

	super._on_part_button_pressed(
		part_id
	)


func _select_next_category() -> void:
	super._select_next_category()

	if (
		current_category
		!= BasePartLibrary.CATEGORY_BODY
		and selected_body_segment >= 0
	):
		_clear_spine_selection(true)


func _select_part_by_index(
	part_index: int
) -> void:
	_clear_spine_selection(false)

	super._select_part_by_index(
		part_index
	)


func _select_next_part() -> void:
	_clear_spine_selection(false)
	super._select_next_part()


func _select_previous_part() -> void:
	_clear_spine_selection(false)
	super._select_previous_part()


func _reset_selected_transform() -> void:
	if selected_body_segment >= 0:
		SpineProfile.reset_segment(
			blueprint,
			selected_body_segment
		)

		_refresh_preview()
		_refresh_stats_panel()
		return

	super._reset_selected_transform()


func _save_blueprint() -> void:
	SpineProfile.ensure_profile(blueprint)

	super._save_blueprint()

	var save_error: Error = (
		SpineProfile.save_profile(
			blueprint
		)
	)

	if save_error != OK:
		push_error(
			"Spine profile save failed: %s"
			% save_error
		)
		return

	print(
		"Creature spine saved: ",
		SpineProfile.SAVE_PATH
	)


func _load_blueprint() -> void:
	super._load_blueprint()

	selected_body_segment = -1
	_is_dragging_spine_segment = false

	if FileAccess.file_exists(
		BASE_SAVE_PATH
	):
		SpineProfile.load_profile(
			blueprint
		)
	else:
		SpineProfile.ensure_profile(
			blueprint
		)

	_refresh_all()


func _reset_blueprint() -> void:
	super._reset_blueprint()

	selected_body_segment = -1
	_is_dragging_spine_segment = false

	SpineProfile.reset_all(blueprint)

	_refresh_all()
