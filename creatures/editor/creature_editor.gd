extends Node3D


const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const PartLibrary = preload("res://creatures/editor/creature_part_library.gd")
const PreviewScript = preload("res://creatures/editor/creature_preview.gd")

const SAVE_PATH: String = "user://creature_editor_blueprint.json"

const TRANSLATE_STEP: float = 0.08
const SCALE_STEP: float = 0.08
const ROTATE_STEP: float = 7.5
const BODY_SHAPE_STEP: float = 0.08
const CAMERA_ROTATE_SPEED: float = 0.006
const CAMERA_ZOOM_STEP: float = 0.45
const PREVIEW_MOUSE_TURN_SPEED: float = 0.012
const PREVIEW_KEY_TURN_STEP: float = 15.0
const MOUSE_PART_MOVE_STEP: float = 0.0045
const MOUSE_PART_VERTICAL_STEP: float = 0.008
const MOUSE_PART_ROTATE_STEP: float = 0.65
const MOUSE_PART_SCALE_STEP: float = 0.06


var blueprint: Dictionary = {}
var current_category: String = PartLibrary.CATEGORY_BODY
var selected_part_index: int = -1

var _camera_pivot: Node3D
var _camera: Camera3D
var _preview_pivot: Node3D
var _preview: Node3D

var _ui_root: Control
var _left_panel: PanelContainer
var _right_panel: PanelContainer
var _bottom_panel: PanelContainer
var _category_grid: GridContainer
var _part_grid: GridContainer
var _title_label: Label
var _stats_label: Label
var _selection_label: Label
var _help_label: Label
var _complexity_bar: ProgressBar
var _creature_name_edit: LineEdit
var _mirror_button: Button
var _symmetry_button: Button

var _symmetry_enabled: bool = true
var _is_turning_creature: bool = false
var _is_dragging_part: bool = false
var _is_rotating_part_with_mouse: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	blueprint = Blueprint.create_default()

	_build_editor_room()
	_build_ui()
	_refresh_all()

	print(
		"Creature Editor V3 ready. Save path: ",
		SAVE_PATH
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
		return

	if event is InputEventKey:
		_handle_key(event)


func _build_editor_room() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.10, 0.13, 0.16, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.55, 0.62, 1.0)
	environment.ambient_light_energy = 0.55
	world_environment.environment = environment
	add_child(world_environment)

	var platform := MeshInstance3D.new()
	platform.name = "EditorPlatform"

	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 2.8
	platform_mesh.bottom_radius = 2.8
	platform_mesh.height = 0.22
	platform_mesh.radial_segments = 48
	platform.mesh = platform_mesh
	platform.position = Vector3(0.0, -0.92, 0.0)
	platform.material_override = _create_material(
		Color(0.20, 0.23, 0.27, 1.0),
		false
	)
	add_child(platform)

	var platform_ring := MeshInstance3D.new()
	platform_ring.name = "EditorPlatformRing"

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 2.70
	ring_mesh.outer_radius = 2.86
	ring_mesh.ring_segments = 64
	platform_ring.mesh = ring_mesh
	platform_ring.position = Vector3(0.0, -0.78, 0.0)
	platform_ring.material_override = _create_material(
		Color(0.10, 0.70, 0.95, 1.0),
		true
	)
	add_child(platform_ring)

	var grid_root := Node3D.new()
	grid_root.name = "PreviewGrid"
	add_child(grid_root)

	for index in range(-4, 5):
		_create_grid_line(
			grid_root,
			Vector3(float(index) * 0.5, -0.77, -2.2),
			Vector3(0.025, 0.025, 4.4)
		)
		_create_grid_line(
			grid_root,
			Vector3(-2.2, -0.77, float(index) * 0.5),
			Vector3(4.4, 0.025, 0.025)
		)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	key_light.light_energy = 2.2
	add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "FillLight"
	fill_light.position = Vector3(-3.0, 3.0, 4.0)
	fill_light.light_energy = 2.0
	fill_light.omni_range = 9.0
	add_child(fill_light)

	var rim_light := OmniLight3D.new()
	rim_light.name = "RimLight"
	rim_light.position = Vector3(3.0, 2.2, -3.5)
	rim_light.light_color = Color(0.25, 0.70, 1.0, 1.0)
	rim_light.light_energy = 1.3
	rim_light.omni_range = 8.0
	add_child(rim_light)

	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position = Vector3(0.0, 0.55, 0.0)
	add_child(_camera_pivot)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.position = Vector3(0.0, 0.8, 6.8)
	_camera.fov = 48.0
	_camera.current = true
	_camera_pivot.add_child(_camera)
	_camera.look_at(Vector3(0.0, 0.3, 0.0), Vector3.UP)

	_preview_pivot = Node3D.new()
	_preview_pivot.name = "PreviewTurntable"
	add_child(_preview_pivot)

	_preview = Node3D.new()
	_preview.name = "CreaturePreview"
	_preview.set_script(PreviewScript)
	_preview_pivot.add_child(_preview)


func _create_grid_line(
	parent: Node3D,
	position: Vector3,
	size: Vector3
) -> void:
	var line := MeshInstance3D.new()
	line.position = position

	var mesh := BoxMesh.new()
	mesh.size = size
	line.mesh = mesh
	line.material_override = _create_material(
		Color(0.13, 0.17, 0.20, 1.0),
		false
	)

	parent.add_child(line)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "EditorUI"
	add_child(canvas)

	_ui_root = Control.new()
	_ui_root.name = "Root"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_ui_root)

	_build_left_panel()
	_build_right_panel()
	_build_bottom_panel()
	_build_top_label()


func _build_left_panel() -> void:
	_left_panel = PanelContainer.new()
	_left_panel.name = "LeftPartPalette"
	_left_panel.anchor_left = 0.0
	_left_panel.anchor_top = 0.0
	_left_panel.anchor_right = 0.0
	_left_panel.anchor_bottom = 1.0
	_left_panel.offset_left = 12.0
	_left_panel.offset_top = 12.0
	_left_panel.offset_right = 306.0
	_left_panel.offset_bottom = -78.0
	_ui_root.add_child(_left_panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 8)
	_left_panel.add_child(content)

	var title := Label.new()
	title.text = "PART LIBRARY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	_category_grid = GridContainer.new()
	_category_grid.name = "CategoryGrid"
	_category_grid.columns = 3
	content.add_child(_category_grid)

	var separator := HSeparator.new()
	content.add_child(separator)

	_help_label = Label.new()
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.text = (
		"Empty LMB drag = turn creature. "
		+ "Click part = select. "
		+ "LMB drag part = move. "
		+ "RMB drag = rotate. Wheel = scale."
	)
	content.add_child(_help_label)

	var scroll := ScrollContainer.new()
	scroll.name = "PartScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	_part_grid = GridContainer.new()
	_part_grid.name = "PartGrid"
	_part_grid.columns = 1
	_part_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_part_grid)


func _build_right_panel() -> void:
	_right_panel = PanelContainer.new()
	_right_panel.name = "RightStatsPanel"
	_right_panel.anchor_left = 1.0
	_right_panel.anchor_top = 0.0
	_right_panel.anchor_right = 1.0
	_right_panel.anchor_bottom = 1.0
	_right_panel.offset_left = -318.0
	_right_panel.offset_top = 12.0
	_right_panel.offset_right = -12.0
	_right_panel.offset_bottom = -78.0
	_ui_root.add_child(_right_panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 8)
	_right_panel.add_child(content)

	var title := Label.new()
	title.text = "CREATURE STATS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	_complexity_bar = ProgressBar.new()
	_complexity_bar.min_value = 0.0
	_complexity_bar.max_value = float(Blueprint.COMPLEXITY_LIMIT)
	_complexity_bar.show_percentage = false
	_complexity_bar.custom_minimum_size = Vector2(250.0, 18.0)
	content.add_child(_complexity_bar)

	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_stats_label)

	var stats_separator := HSeparator.new()
	content.add_child(stats_separator)

	_selection_label = Label.new()
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_selection_label)

	var transform_title := Label.new()
	transform_title.text = "TRANSFORM"
	transform_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(transform_title)

	var move_grid := GridContainer.new()
	move_grid.columns = 3
	content.add_child(move_grid)

	_add_tool_button(move_grid, "X-", Callable(self, "_move_x_negative"))
	_add_tool_button(move_grid, "Y+", Callable(self, "_move_y_positive"))
	_add_tool_button(move_grid, "X+", Callable(self, "_move_x_positive"))
	_add_tool_button(move_grid, "Z-", Callable(self, "_move_z_negative"))
	_add_tool_button(move_grid, "Y-", Callable(self, "_move_y_negative"))
	_add_tool_button(move_grid, "Z+", Callable(self, "_move_z_positive"))

	var scale_rotate_grid := GridContainer.new()
	scale_rotate_grid.columns = 2
	content.add_child(scale_rotate_grid)

	_add_tool_button(scale_rotate_grid, "Scale -", Callable(self, "_scale_down"))
	_add_tool_button(scale_rotate_grid, "Scale +", Callable(self, "_scale_up"))
	_add_tool_button(scale_rotate_grid, "Rot -", Callable(self, "_rotate_negative"))
	_add_tool_button(scale_rotate_grid, "Rot +", Callable(self, "_rotate_positive"))

	var view_title := Label.new()
	view_title.text = "VIEW / SYMMETRY"
	view_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(view_title)

	var view_grid := GridContainer.new()
	view_grid.columns = 2
	content.add_child(view_grid)

	_add_tool_button(view_grid, "Turn ◀", Callable(self, "_turn_creature_left"))
	_add_tool_button(view_grid, "Turn ▶", Callable(self, "_turn_creature_right"))

	var selection_grid := GridContainer.new()
	selection_grid.columns = 2
	content.add_child(selection_grid)

	_add_tool_button(selection_grid, "Prev", Callable(self, "_select_previous_part"))
	_add_tool_button(selection_grid, "Next", Callable(self, "_select_next_part"))
	_add_tool_button(selection_grid, "Duplicate", Callable(self, "_duplicate_selected_part"))
	_add_tool_button(selection_grid, "Delete", Callable(self, "_delete_selected_part"))

	_mirror_button = Button.new()
	_mirror_button.text = "Part Mirror: -"
	_mirror_button.pressed.connect(_toggle_selected_mirror)
	content.add_child(_mirror_button)

	_symmetry_button = Button.new()
	_symmetry_button.text = "Y-Axis Symmetry (X mirror): ON"
	_symmetry_button.pressed.connect(_toggle_global_symmetry)
	content.add_child(_symmetry_button)

	var reset_button := Button.new()
	reset_button.text = "Reset Selected Transform"
	reset_button.pressed.connect(_reset_selected_transform)
	content.add_child(reset_button)

	var clear_button := Button.new()
	clear_button.text = "Clear All Parts"
	clear_button.pressed.connect(_clear_all_parts)
	content.add_child(clear_button)


func _build_bottom_panel() -> void:
	_bottom_panel = PanelContainer.new()
	_bottom_panel.name = "BottomBar"
	_bottom_panel.anchor_left = 0.0
	_bottom_panel.anchor_top = 1.0
	_bottom_panel.anchor_right = 1.0
	_bottom_panel.anchor_bottom = 1.0
	_bottom_panel.offset_left = 12.0
	_bottom_panel.offset_top = -66.0
	_bottom_panel.offset_right = -12.0
	_bottom_panel.offset_bottom = -12.0
	_ui_root.add_child(_bottom_panel)

	var content := HBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 10)
	_bottom_panel.add_child(content)

	var name_label := Label.new()
	name_label.text = "Name:"
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(name_label)

	_creature_name_edit = LineEdit.new()
	_creature_name_edit.custom_minimum_size = Vector2(260.0, 0.0)
	_creature_name_edit.text_submitted.connect(_on_name_submitted)
	_creature_name_edit.text_changed.connect(_on_name_changed)
	content.add_child(_creature_name_edit)

	_add_bottom_button(content, "Save", Callable(self, "_save_blueprint"))
	_add_bottom_button(content, "Load", Callable(self, "_load_blueprint"))
	_add_bottom_button(content, "New", Callable(self, "_reset_blueprint"))
	_add_bottom_button(content, "Randomize", Callable(self, "_randomize_blueprint"))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	_add_bottom_button(content, "Print Blueprint", Callable(self, "_print_blueprint_summary"))
	_add_bottom_button(content, "Play Test Later", Callable(self, "_play_test_placeholder"))


func _build_top_label() -> void:
	_title_label = Label.new()
	_title_label.name = "TopTitle"
	_title_label.anchor_left = 0.0
	_title_label.anchor_top = 0.0
	_title_label.anchor_right = 1.0
	_title_label.anchor_bottom = 0.0
	_title_label.offset_left = 320.0
	_title_label.offset_top = 12.0
	_title_label.offset_right = -330.0
	_title_label.offset_bottom = 52.0
	_title_label.text = "VOXELVERSE CREATURE EDITOR"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_ui_root.add_child(_title_label)


func _refresh_all() -> void:
	if _creature_name_edit != null:
		_creature_name_edit.text = str(blueprint.get("name", "New Creature"))

	_refresh_category_buttons()
	_refresh_part_palette()
	_refresh_preview()
	_refresh_stats_panel()


func _refresh_category_buttons() -> void:
	_clear_control_children(_category_grid)

	for category in PartLibrary.get_categories():
		var category_id: String = str(category.get("id", ""))
		var button := Button.new()
		button.text = "%s\n%s" % [
			str(category.get("icon", "?")),
			str(category.get("name", category_id.capitalize()))
		]
		button.custom_minimum_size = Vector2(74.0, 56.0)
		button.toggle_mode = true
		button.button_pressed = category_id == current_category
		button.pressed.connect(
			Callable(self, "_on_category_button_pressed").bind(category_id)
		)
		_category_grid.add_child(button)


func _refresh_part_palette() -> void:
	_clear_control_children(_part_grid)

	var parts: Array = PartLibrary.get_parts_for_category(current_category)

	for part in parts:
		if not (part is Dictionary):
			continue

		var button := Button.new()
		button.custom_minimum_size = Vector2(148.0, 92.0)
		button.text = _get_palette_button_text(part)
		button.tooltip_text = str(part.get("description", ""))
		button.pressed.connect(
			Callable(self, "_on_part_button_pressed").bind(
				str(part.get("id", ""))
			)
		)
		_part_grid.add_child(button)


func _refresh_preview() -> void:
	if _preview == null:
		return

	_preview.call("set_blueprint", blueprint)
	_preview.call("set_selected_part_index", selected_part_index)


func _refresh_stats_panel() -> void:
	var stats: Dictionary = Blueprint.calculate_stats(blueprint)
	var complexity: int = int(stats.get("complexity", 0))
	var part_count: int = Blueprint.get_part_count(blueprint)

	_complexity_bar.value = float(complexity)

	_stats_label.text = (
		"Complexity: %d / %d\n"
		+ "Parts: %d\n\n"
		+ "Health: %d\n"
		+ "Speed: %.2f\n"
		+ "Jump: %.2f\n"
		+ "Attack: %.2f\n"
		+ "Defense: %.2f\n"
		+ "Perception: %.2f\n"
		+ "Grip: %.2f\n"
		+ "Plant Diet: %.2f\n"
		+ "Meat Diet: %.2f\n"
		+ "Swim: %.2f\n"
		+ "Hunger Drain: %.3f\n\n"
		+ "Preview Rotation Y: %.1f°\n"
		+ "Y-Axis Symmetry (X mirror): %s"
	) % [
		complexity,
		Blueprint.COMPLEXITY_LIMIT,
		part_count,
		roundi(float(stats.get("health", 0.0))),
		float(stats.get("speed", 0.0)),
		float(stats.get("jump", 0.0)),
		float(stats.get("attack", 0.0)),
		float(stats.get("defense", 0.0)),
		float(stats.get("perception", 0.0)),
		float(stats.get("grip", 0.0)),
		float(stats.get("diet_plant", 0.0)),
		float(stats.get("diet_meat", 0.0)),
		float(stats.get("swim", 0.0)),
		float(stats.get("hunger_drain", 0.0)),
		_get_preview_y_rotation(),
		str(_symmetry_enabled),
	]

	_selection_label.text = _get_selection_text()
	_update_mirror_button()
	_update_symmetry_button()


func _get_selection_text() -> String:
	if current_category == PartLibrary.CATEGORY_BODY:
		var body_shape: Vector3 = Blueprint.get_body_shape(blueprint)
		var body_scale: float = Blueprint.get_body_scale(blueprint)
		var body_definition: Dictionary = PartLibrary.get_part(
			Blueprint.get_body_part_id(blueprint)
		)

		return (
			"Selected: Body\n"
			+ "Part: %s\n"
			+ "Shape X/Y/Z: %.2f / %.2f / %.2f\n"
			+ "Scale: %.2f"
		) % [
			str(body_definition.get("name", "Unknown")),
			body_shape.x,
			body_shape.y,
			body_shape.z,
			body_scale,
		]

	if current_category == PartLibrary.CATEGORY_PAINT:
		var paint_definition: Dictionary = PartLibrary.get_part(
			Blueprint.get_paint_part_id(blueprint)
		)

		return (
			"Selected: Paint\n"
			+ "Pattern: %s\n"
			+ "Intensity: %.2f"
		) % [
			str(paint_definition.get("name", "Unknown")),
			Blueprint.get_paint_intensity(blueprint),
		]

	var placement: Dictionary = Blueprint.get_part_placement(
		blueprint,
		selected_part_index
	)

	if placement.is_empty():
		return (
			"Selected: none\n"
			+ "Click a part in the left panel to place it."
		)

	var part_definition: Dictionary = PartLibrary.get_part(
		str(placement.get("part_id", ""))
	)
	var position: Vector3 = Blueprint._as_vector3(
		placement.get("position", Vector3.ZERO)
	)
	var rotation: Vector3 = Blueprint._as_vector3(
		placement.get("rotation", Vector3.ZERO)
	)

	return (
		"Selected: %s\n"
		+ "Category: %s\n"
		+ "Position: %.2f / %.2f / %.2f\n"
		+ "Rotation: %.1f / %.1f / %.1f\n"
		+ "Scale: %.2f\n"
		+ "Mirrored: %s"
	) % [
		str(part_definition.get("name", "Unknown")),
		PartLibrary.get_category_name(str(placement.get("category", ""))),
		position.x,
		position.y,
		position.z,
		rotation.x,
		rotation.y,
		rotation.z,
		float(placement.get("scale", 1.0)),
		str(bool(placement.get("mirrored", false))),
	]


func _update_mirror_button() -> void:
	if _mirror_button == null:
		return

	var placement: Dictionary = Blueprint.get_part_placement(
		blueprint,
		selected_part_index
	)

	if placement.is_empty():
		_mirror_button.text = "Part Mirror: -"
		_mirror_button.disabled = true
		return

	_mirror_button.disabled = false
	_mirror_button.text = "Part Mirror: %s" % str(
		bool(placement.get("mirrored", false))
	)


func _update_symmetry_button() -> void:
	if _symmetry_button == null:
		return

	_symmetry_button.text = "Y-Axis Symmetry (X mirror): %s" % (
		"ON" if _symmetry_enabled else "OFF"
	)


func _get_palette_button_text(part: Dictionary) -> String:
	var name: String = str(part.get("name", "Unnamed"))
	var complexity: int = int(part.get("complexity", 0))

	if current_category == PartLibrary.CATEGORY_BODY:
		return "⬢\n%s\nC:%d" % [name, complexity]

	if current_category == PartLibrary.CATEGORY_PAINT:
		return "▣\n%s\nC:%d" % [name, complexity]

	return "%s\nC:%d" % [name, complexity]


func _on_category_button_pressed(category_id: String) -> void:
	current_category = category_id

	if (
		category_id == PartLibrary.CATEGORY_BODY
		or category_id == PartLibrary.CATEGORY_PAINT
	):
		selected_part_index = -1

	_refresh_all()


func _on_part_button_pressed(part_id: String) -> void:
	if part_id == "":
		return

	if current_category == PartLibrary.CATEGORY_BODY:
		Blueprint.set_body_part(blueprint, part_id)
		selected_part_index = -1
		_refresh_all()
		return

	if current_category == PartLibrary.CATEGORY_PAINT:
		Blueprint.set_paint_part(blueprint, part_id)
		selected_part_index = -1
		_refresh_all()
		return

	var new_index: int = Blueprint.add_part(blueprint, part_id)

	if new_index >= 0:
		selected_part_index = new_index
		_apply_global_symmetry_to_new_part(new_index)

	_refresh_all()


func _on_name_changed(new_text: String) -> void:
	Blueprint.set_name(blueprint, new_text)


func _on_name_submitted(new_text: String) -> void:
	Blueprint.set_name(blueprint, new_text)
	_refresh_stats_panel()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_left_mouse_pressed(event.position)
		else:
			_is_dragging_part = false
			_is_turning_creature = false

		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_handle_right_mouse_pressed(event.position)
		else:
			_is_rotating_part_with_mouse = false
			_is_turning_creature = false

		return

	if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if _can_mouse_transform_part(event.position):
			_scale_selected_part_from_mouse(MOUSE_PART_SCALE_STEP)
		else:
			_zoom_camera(-CAMERA_ZOOM_STEP)

		return

	if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if _can_mouse_transform_part(event.position):
			_scale_selected_part_from_mouse(-MOUSE_PART_SCALE_STEP)
		else:
			_zoom_camera(CAMERA_ZOOM_STEP)

		return


func _handle_left_mouse_pressed(screen_position: Vector2) -> void:
	if _is_pointer_over_editor_panel(screen_position):
		return

	var picked_index: int = _pick_part_at_screen_position(screen_position)

	if picked_index >= 0:
		_select_part_by_index(picked_index)
		_is_dragging_part = true
		return

	_is_turning_creature = true


func _handle_right_mouse_pressed(screen_position: Vector2) -> void:
	if _is_pointer_over_editor_panel(screen_position):
		return

	var picked_index: int = _pick_part_at_screen_position(screen_position)

	if picked_index >= 0:
		_select_part_by_index(picked_index)
		_is_rotating_part_with_mouse = true
		return

	if selected_part_index >= 0:
		_is_rotating_part_with_mouse = true
		return

	_is_turning_creature = true


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_dragging_part:
		_drag_selected_part_from_mouse(event)
		return

	if _is_rotating_part_with_mouse:
		_rotate_selected_part_from_mouse(event)
		return

	if _is_turning_creature:
		_turn_creature_from_mouse(event)
		return


func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return

	if event.ctrl_pressed:
		match event.keycode:
			KEY_S:
				_save_blueprint()
				return
			KEY_L:
				_load_blueprint()
				return
			KEY_R:
				_reset_blueprint()
				return
			KEY_D:
				_duplicate_selected_part()
				return
			_:
				pass

	if _is_typing_text():
		return

	match event.keycode:
		KEY_TAB:
			_select_next_category()
		KEY_DELETE:
			_delete_selected_part()
		KEY_Q:
			_select_previous_library_part()
		KEY_E:
			_select_next_library_part()
		KEY_COMMA:
			_scale_down()
		KEY_PERIOD:
			_scale_up()
		KEY_LEFT:
			_move_x_negative()
		KEY_RIGHT:
			_move_x_positive()
		KEY_UP:
			_move_z_negative()
		KEY_DOWN:
			_move_z_positive()
		KEY_PAGEUP:
			_move_y_positive()
		KEY_PAGEDOWN:
			_move_y_negative()
		KEY_R:
			_rotate_positive()
		KEY_X:
			_reset_selected_transform()
		KEY_M:
			_toggle_selected_mirror()
		KEY_Y:
			_toggle_global_symmetry()
		KEY_A:
			_turn_creature_left()
		KEY_D:
			_turn_creature_right()
		_:
			pass


func _select_next_category() -> void:
	var categories: Array = PartLibrary.get_categories()
	var current_index: int = 0

	for index in range(categories.size()):
		if str(categories[index].get("id", "")) == current_category:
			current_index = index
			break

	var next_index: int = (current_index + 1) % categories.size()
	current_category = str(categories[next_index].get("id", current_category))

	if (
		current_category == PartLibrary.CATEGORY_BODY
		or current_category == PartLibrary.CATEGORY_PAINT
	):
		selected_part_index = -1

	_refresh_all()


func _select_next_library_part() -> void:
	_cycle_library_part(1)


func _select_previous_library_part() -> void:
	_cycle_library_part(-1)


func _cycle_library_part(direction: int) -> void:
	var parts: Array = PartLibrary.get_parts_for_category(current_category)

	if parts.is_empty():
		return

	if current_category == PartLibrary.CATEGORY_BODY:
		var current_id: String = Blueprint.get_body_part_id(blueprint)
		var next_id: String = _get_cycled_part_id(parts, current_id, direction)
		Blueprint.set_body_part(blueprint, next_id)
		_refresh_all()
		return

	if current_category == PartLibrary.CATEGORY_PAINT:
		var paint_id: String = Blueprint.get_paint_part_id(blueprint)
		var next_paint_id: String = _get_cycled_part_id(parts, paint_id, direction)
		Blueprint.set_paint_part(blueprint, next_paint_id)
		_refresh_all()
		return

	var placement: Dictionary = Blueprint.get_part_placement(
		blueprint,
		selected_part_index
	)

	if placement.is_empty():
		_on_part_button_pressed(str(parts[0].get("id", "")))
		return

	var current_part_id: String = str(placement.get("part_id", ""))
	var cycled_part_id: String = _get_cycled_part_id(
		parts,
		current_part_id,
		direction
	)
	placement["part_id"] = cycled_part_id
	placement["category"] = current_category

	Blueprint.set_part_placement(
		blueprint,
		selected_part_index,
		placement
	)

	_refresh_all()


func _get_cycled_part_id(
	parts: Array,
	current_part_id: String,
	direction: int
) -> String:
	var current_index: int = 0

	for index in range(parts.size()):
		if str(parts[index].get("id", "")) == current_part_id:
			current_index = index
			break

	var next_index: int = (
		current_index + direction + parts.size()
	) % parts.size()

	return str(parts[next_index].get("id", current_part_id))


func _select_next_part() -> void:
	var count: int = Blueprint.get_part_count(blueprint)

	if count <= 0:
		selected_part_index = -1
		_refresh_all()
		return

	selected_part_index = (selected_part_index + 1 + count) % count
	var placement: Dictionary = Blueprint.get_part_placement(
		blueprint,
		selected_part_index
	)
	current_category = str(placement.get("category", current_category))

	_refresh_all()


func _select_previous_part() -> void:
	var count: int = Blueprint.get_part_count(blueprint)

	if count <= 0:
		selected_part_index = -1
		_refresh_all()
		return

	if selected_part_index < 0:
		selected_part_index = 0

	selected_part_index = (selected_part_index - 1 + count) % count
	var placement: Dictionary = Blueprint.get_part_placement(
		blueprint,
		selected_part_index
	)
	current_category = str(placement.get("category", current_category))

	_refresh_all()


func _delete_selected_part() -> void:
	Blueprint.remove_part(blueprint, selected_part_index)

	var count: int = Blueprint.get_part_count(blueprint)

	if count == 0:
		selected_part_index = -1
	else:
		selected_part_index = clampi(selected_part_index, 0, count - 1)

	_refresh_all()


func _duplicate_selected_part() -> void:
	var new_index: int = Blueprint.duplicate_part(
		blueprint,
		selected_part_index
	)

	if new_index >= 0:
		selected_part_index = new_index

	_refresh_all()


func _clear_all_parts() -> void:
	Blueprint.clear_parts(blueprint)
	selected_part_index = -1
	_refresh_all()


func _reset_selected_transform() -> void:
	if current_category == PartLibrary.CATEGORY_BODY:
		var body_definition: Dictionary = PartLibrary.get_part(
			Blueprint.get_body_part_id(blueprint)
		)
		Blueprint.set_body_shape(
			blueprint,
			body_definition.get("shape", Vector3(1.3, 1.0, 2.1))
		)
		Blueprint.set_body_scale(blueprint, 1.0)
		_refresh_all()
		return

	if current_category == PartLibrary.CATEGORY_PAINT:
		Blueprint.set_paint_intensity(blueprint, 1.0)
		_refresh_all()
		return

	Blueprint.reset_part_transform(blueprint, selected_part_index)
	_refresh_all()


func _toggle_selected_mirror() -> void:
	var placement: Dictionary = Blueprint.get_part_placement(
		blueprint,
		selected_part_index
	)

	if placement.is_empty():
		return

	Blueprint.set_part_mirrored(
		blueprint,
		selected_part_index,
		not bool(placement.get("mirrored", false))
	)

	_refresh_all()


func _move_x_negative() -> void:
	_apply_transform_delta(Vector3(-TRANSLATE_STEP, 0.0, 0.0), 0.0, 0.0)


func _move_x_positive() -> void:
	_apply_transform_delta(Vector3(TRANSLATE_STEP, 0.0, 0.0), 0.0, 0.0)


func _move_y_positive() -> void:
	_apply_transform_delta(Vector3(0.0, TRANSLATE_STEP, 0.0), 0.0, 0.0)


func _move_y_negative() -> void:
	_apply_transform_delta(Vector3(0.0, -TRANSLATE_STEP, 0.0), 0.0, 0.0)


func _move_z_negative() -> void:
	_apply_transform_delta(Vector3(0.0, 0.0, -TRANSLATE_STEP), 0.0, 0.0)


func _move_z_positive() -> void:
	_apply_transform_delta(Vector3(0.0, 0.0, TRANSLATE_STEP), 0.0, 0.0)


func _scale_up() -> void:
	_apply_transform_delta(Vector3.ZERO, SCALE_STEP, 0.0)


func _scale_down() -> void:
	_apply_transform_delta(Vector3.ZERO, -SCALE_STEP, 0.0)


func _rotate_positive() -> void:
	_apply_transform_delta(Vector3.ZERO, 0.0, ROTATE_STEP)


func _rotate_negative() -> void:
	_apply_transform_delta(Vector3.ZERO, 0.0, -ROTATE_STEP)


func _apply_transform_delta(
	position_delta: Vector3,
	scale_delta: float,
	rotation_y_delta: float
) -> void:
	if current_category == PartLibrary.CATEGORY_BODY:
		_apply_body_delta(position_delta, scale_delta)
		return

	if current_category == PartLibrary.CATEGORY_PAINT:
		_apply_paint_delta(scale_delta)
		return

	if selected_part_index < 0:
		return

	if position_delta != Vector3.ZERO:
		Blueprint.nudge_part(
			blueprint,
			selected_part_index,
			position_delta
		)

	if scale_delta != 0.0:
		Blueprint.scale_part(
			blueprint,
			selected_part_index,
			scale_delta
		)

	if rotation_y_delta != 0.0:
		Blueprint.rotate_part(
			blueprint,
			selected_part_index,
			Vector3(0.0, rotation_y_delta, 0.0)
		)

	_refresh_all()


func _apply_body_delta(
	position_delta: Vector3,
	scale_delta: float
) -> void:
	var shape: Vector3 = Blueprint.get_body_shape(blueprint)
	var body_scale: float = Blueprint.get_body_scale(blueprint)

	if position_delta.x != 0.0:
		shape.x += signf(position_delta.x) * BODY_SHAPE_STEP

	if position_delta.y != 0.0:
		shape.y += signf(position_delta.y) * BODY_SHAPE_STEP

	if position_delta.z != 0.0:
		shape.z += signf(position_delta.z) * BODY_SHAPE_STEP

	if scale_delta != 0.0:
		body_scale += scale_delta

	Blueprint.set_body_shape(blueprint, shape)
	Blueprint.set_body_scale(blueprint, body_scale)

	_refresh_all()


func _apply_paint_delta(scale_delta: float) -> void:
	if scale_delta == 0.0:
		return

	Blueprint.set_paint_intensity(
		blueprint,
		Blueprint.get_paint_intensity(blueprint) + scale_delta
	)

	_refresh_all()


func _apply_global_symmetry_to_new_part(part_index: int) -> void:
	var placement: Dictionary = Blueprint.get_part_placement(
		blueprint,
		part_index
	)

	if placement.is_empty():
		return

	var category_id: String = str(placement.get("category", ""))

	if not _supports_y_axis_symmetry(category_id):
		return

	Blueprint.set_part_mirrored(
		blueprint,
		part_index,
		_symmetry_enabled
	)


func _supports_y_axis_symmetry(category_id: String) -> bool:
	return (
		category_id == PartLibrary.CATEGORY_EYES
		or category_id == PartLibrary.CATEGORY_LEGS
		or category_id == PartLibrary.CATEGORY_ARMS
		or category_id == PartLibrary.CATEGORY_HORNS
		or category_id == PartLibrary.CATEGORY_PLATES
		or category_id == PartLibrary.CATEGORY_SPIKES
		or category_id == PartLibrary.CATEGORY_DECOR
	)


func _toggle_global_symmetry() -> void:
	_symmetry_enabled = not _symmetry_enabled
	_update_symmetry_button()

	print("Creature editor Y-axis symmetry: ", _symmetry_enabled)


func _turn_creature_left() -> void:
	_rotate_preview_y(PREVIEW_KEY_TURN_STEP)


func _turn_creature_right() -> void:
	_rotate_preview_y(-PREVIEW_KEY_TURN_STEP)


func _turn_creature_from_mouse(event: InputEventMouseMotion) -> void:
	_rotate_preview_y(-event.relative.x * rad_to_deg(PREVIEW_MOUSE_TURN_SPEED))

	if Input.is_key_pressed(KEY_SHIFT):
		_rotate_preview_x(-event.relative.y * rad_to_deg(PREVIEW_MOUSE_TURN_SPEED * 0.45))


func _rotate_preview_y(rotation_degrees_delta: float) -> void:
	if _preview_pivot == null:
		return

	_preview_pivot.rotation_degrees.y = wrapf(
		_preview_pivot.rotation_degrees.y + rotation_degrees_delta,
		-180.0,
		180.0
	)

	_refresh_stats_panel()


func _rotate_preview_x(rotation_degrees_delta: float) -> void:
	if _preview_pivot == null:
		return

	_preview_pivot.rotation_degrees.x = clampf(
		_preview_pivot.rotation_degrees.x + rotation_degrees_delta,
		-35.0,
		35.0
	)

	_refresh_stats_panel()


func _get_preview_y_rotation() -> float:
	if _preview_pivot == null:
		return 0.0

	return snappedf(_preview_pivot.rotation_degrees.y, 0.1)


func _can_mouse_transform_part(screen_position: Vector2) -> bool:
	return (
		selected_part_index >= 0
		and not _is_pointer_over_editor_panel(screen_position)
	)


func _drag_selected_part_from_mouse(event: InputEventMouseMotion) -> void:
	if selected_part_index < 0:
		return

	var position_delta := Vector3.ZERO

	if Input.is_key_pressed(KEY_SHIFT):
		position_delta = Vector3(
			0.0,
			-event.relative.y * MOUSE_PART_VERTICAL_STEP,
			0.0
		)
	else:
		var camera_right := _camera.global_transform.basis.x
		var camera_forward := -_camera.global_transform.basis.z

		camera_right.y = 0.0
		camera_forward.y = 0.0

		if camera_right.length_squared() > 0.0:
			camera_right = camera_right.normalized()

		if camera_forward.length_squared() > 0.0:
			camera_forward = camera_forward.normalized()

		position_delta = (
			camera_right * event.relative.x
			+ camera_forward * -event.relative.y
		) * MOUSE_PART_MOVE_STEP

	Blueprint.nudge_part(
		blueprint,
		selected_part_index,
		position_delta
	)

	_refresh_preview()
	_refresh_stats_panel()


func _rotate_selected_part_from_mouse(event: InputEventMouseMotion) -> void:
	if selected_part_index < 0:
		return

	var rotation_delta := Vector3.ZERO

	if Input.is_key_pressed(KEY_SHIFT):
		rotation_delta.x = -event.relative.y * MOUSE_PART_ROTATE_STEP
	elif Input.is_key_pressed(KEY_CTRL):
		rotation_delta.z = event.relative.x * MOUSE_PART_ROTATE_STEP
	else:
		rotation_delta.y = event.relative.x * MOUSE_PART_ROTATE_STEP

	Blueprint.rotate_part(
		blueprint,
		selected_part_index,
		rotation_delta
	)

	_refresh_preview()
	_refresh_stats_panel()


func _scale_selected_part_from_mouse(scale_delta: float) -> void:
	if selected_part_index < 0:
		return

	Blueprint.scale_part(
		blueprint,
		selected_part_index,
		scale_delta
	)

	_refresh_preview()
	_refresh_stats_panel()


func _pick_part_at_screen_position(screen_position: Vector2) -> int:
	if _camera == null:
		return -1

	var ray_origin: Vector3 = _camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_position)
	var ray_end: Vector3 = ray_origin + ray_direction * 100.0

	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(
		query
	)

	if result.is_empty():
		return -1

	var collider: Object = result.get("collider", null) as Object

	if collider == null:
		return -1

	if not collider.has_meta("creature_part_index"):
		return -1

	return int(collider.get_meta("creature_part_index"))


func _select_part_by_index(part_index: int) -> void:
	var placement: Dictionary = Blueprint.get_part_placement(
		blueprint,
		part_index
	)

	if placement.is_empty():
		return

	selected_part_index = part_index
	current_category = str(placement.get("category", current_category))
	_refresh_all()


func _is_pointer_over_editor_panel(screen_position: Vector2) -> bool:
	for panel in [
		_left_panel,
		_right_panel,
		_bottom_panel,
	]:
		if panel == null:
			continue

		if panel.get_global_rect().has_point(screen_position):
			return true

	return false


func _save_blueprint() -> void:
	Blueprint.set_name(blueprint, _creature_name_edit.text)

	var result: Error = Blueprint.save_to_file(
		blueprint,
		SAVE_PATH
	)

	if result != OK:
		push_error("Creature save failed: %s" % result)
		return

	print("Creature saved: ", SAVE_PATH)


func _load_blueprint() -> void:
	var loaded_blueprint: Dictionary = Blueprint.load_from_file(
		SAVE_PATH
	)

	if loaded_blueprint.is_empty():
		push_warning("No creature save found at: %s" % SAVE_PATH)
		return

	blueprint = loaded_blueprint
	selected_part_index = -1
	current_category = PartLibrary.CATEGORY_BODY

	_refresh_all()

	print("Creature loaded: ", SAVE_PATH)


func _reset_blueprint() -> void:
	blueprint = Blueprint.create_default()
	selected_part_index = -1
	current_category = PartLibrary.CATEGORY_BODY
	_refresh_all()


func _randomize_blueprint() -> void:
	var random := RandomNumberGenerator.new()
	random.randomize()

	blueprint = Blueprint.create_default()
	blueprint["name"] = "Random Creature %d" % random.randi_range(100, 999)

	var body_parts: Array = PartLibrary.get_body_parts()
	var body_index: int = random.randi_range(0, body_parts.size() - 1)
	Blueprint.set_body_part(
		blueprint,
		str(body_parts[body_index].get("id", "body_balanced_core"))
	)

	var shape: Vector3 = Blueprint.get_body_shape(blueprint)
	shape.x *= random.randf_range(0.75, 1.35)
	shape.y *= random.randf_range(0.75, 1.30)
	shape.z *= random.randf_range(0.75, 1.40)
	Blueprint.set_body_shape(blueprint, shape)

	var paint_parts: Array = PartLibrary.get_paint_parts()
	var paint_index: int = random.randi_range(0, paint_parts.size() - 1)
	Blueprint.set_paint_part(
		blueprint,
		str(paint_parts[paint_index].get("id", "paint_plain"))
	)

	Blueprint.clear_parts(blueprint)

	for category in [
		PartLibrary.CATEGORY_MOUTH,
		PartLibrary.CATEGORY_EYES,
		PartLibrary.CATEGORY_LEGS,
		PartLibrary.CATEGORY_TAIL,
		PartLibrary.CATEGORY_HORNS,
	]:
		var parts: Array = PartLibrary.get_parts_for_category(category)

		if parts.is_empty():
			continue

		var part_index: int = random.randi_range(0, parts.size() - 1)
		var added_index: int = Blueprint.add_part(
			blueprint,
			str(parts[part_index].get("id", ""))
		)

		if added_index >= 0:
			Blueprint.scale_part(
				blueprint,
				added_index,
				random.randf_range(-0.20, 0.35)
			)

	selected_part_index = -1
	current_category = PartLibrary.CATEGORY_BODY

	_refresh_all()


func _print_blueprint_summary() -> void:
	print("Creature Blueprint Summary:")
	print(JSON.stringify(Blueprint._serialize_blueprint(blueprint), "\t"))


func _play_test_placeholder() -> void:
	_save_blueprint()
	print(
		"Play Test is not connected yet. "
		+ "The blueprint has been saved and will be connected "
		+ "to the player in a later sprint."
	)


func _zoom_camera(delta: float) -> void:
	if _camera == null:
		return

	_camera.position.z = clampf(
		_camera.position.z + delta,
		3.2,
		11.0
	)


func _create_material(
	color: Color,
	emissive: bool
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.75

	return material


func _add_tool_button(
	parent: Control,
	text: String,
	callback: Callable
) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(92.0, 34.0)
	button.pressed.connect(callback)
	parent.add_child(button)


func _add_bottom_button(
	parent: Control,
	text: String,
	callback: Callable
) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(118.0, 36.0)
	button.pressed.connect(callback)
	parent.add_child(button)


func _clear_control_children(control: Control) -> void:
	for child in control.get_children():
		child.queue_free()


func _is_typing_text() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()

	return focus_owner is LineEdit
