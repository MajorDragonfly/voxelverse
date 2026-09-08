extends Node3D
class_name BuildingBuilder

const Assembly = preload("res://assembly/core/modular_assembly.gd")
const History = preload("res://assembly/core/modular_assembly_history.gd")
const Parts = preload("res://civilization/buildings/building_part_library.gd")
const Blueprint = preload("res://civilization/buildings/building_blueprint.gd")
const BuildingVisual = preload("res://civilization/buildings/building_runtime_visual.gd")

const MOVE_STEP_MULTIPLIER: float = 1.0
const ROTATION_STEP: float = 15.0
const SCALE_UP: float = 1.08
const SCALE_DOWN: float = 1.0 / SCALE_UP

var blueprint: Dictionary = {}
var selected_part_index: int = -1
var current_category: String = Parts.CATEGORY_MASS
var _history: RefCounted = History.new()

var _visual: Node3D
var _camera: Camera3D
var _camera_target := Vector3(0.0, 2.0, 0.0)
var _camera_yaw: float = deg_to_rad(35.0)
var _camera_pitch: float = deg_to_rad(-18.0)
var _camera_distance: float = 15.0
var _orbit_dragging: bool = false

var _name_edit: LineEdit
var _type_option: OptionButton
var _category_box: VBoxContainer
var _part_grid: GridContainer
var _assembly_list: VBoxContainer
var _stats_label: Label
var _status_label: Label
var _snap_button: Button
var _undo_button: Button
var _redo_button: Button
var _design_option: OptionButton


func _ready() -> void:
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null:
		saves.call("load_if_present")
	blueprint = Blueprint.load_autosave()
	Blueprint.normalize(blueprint)
	_build_world()
	_build_ui()
	_refresh_all()
	_show_compatibility_warnings()


func _process(_delta: float) -> void:
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_orbit_dragging = event.pressed
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(_camera_distance - 1.0, 5.0)
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(_camera_distance + 1.0, 35.0)
			return
	if event is InputEventMouseMotion and _orbit_dragging:
		_camera_yaw -= event.relative.x * 0.008
		_camera_pitch = clampf(
			_camera_pitch - event.relative.y * 0.008,
			deg_to_rad(-65.0),
			deg_to_rad(25.0)
		)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.ctrl_pressed and event.keycode == KEY_Z:
		_undo()
		return
	if event.ctrl_pressed and event.keycode == KEY_Y:
		_redo()
		return
	match event.keycode:
		KEY_TAB:
			_cycle_selection()
		KEY_DELETE:
			_delete_selected()
		KEY_D:
			_duplicate_selected()
		KEY_G:
			_toggle_grid_snap()
		KEY_LEFT:
			_move_selected(Vector3.LEFT)
		KEY_RIGHT:
			_move_selected(Vector3.RIGHT)
		KEY_UP:
			_move_selected(Vector3.FORWARD)
		KEY_DOWN:
			_move_selected(Vector3.BACK)
		KEY_PAGEUP:
			_move_selected(Vector3.UP)
		KEY_PAGEDOWN:
			_move_selected(Vector3.DOWN)
		KEY_Q:
			_rotate_selected(Vector3(0, -ROTATION_STEP, 0))
		KEY_E:
			_rotate_selected(Vector3(0, ROTATION_STEP, 0))
		KEY_Z:
			_rotate_selected(Vector3(-ROTATION_STEP, 0, 0))
		KEY_X:
			_rotate_selected(Vector3(ROTATION_STEP, 0, 0))
		KEY_BRACKETLEFT:
			_scale_selected(SCALE_DOWN)
		KEY_BRACKETRIGHT:
			_scale_selected(SCALE_UP)


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "BuilderEnvironment"
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color(0.055, 0.075, 0.09, 1.0)
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color(0.56, 0.63, 0.68, 1.0)
	environment_resource.ambient_light_energy = 0.65
	environment_resource.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = environment_resource
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.name = "BuilderSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)

	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "BuilderFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(38.0, 38.0)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.09, 0.115, 0.125, 1.0)
	floor_material.roughness = 1.0
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)

	_visual = BuildingVisual.new()
	_visual.name = "BuildingPreview"
	_visual.set("build_collision", false)
	add_child(_visual)

	_camera = Camera3D.new()
	_camera.name = "BuilderCamera"
	_camera.fov = 55.0
	_camera.current = true
	add_child(_camera)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "BuildingBuilderUI"
	add_child(canvas)

	var title := Label.new()
	title.text = "VOXELVERSE · BUILDING BUILDER"
	title.offset_left = 24.0
	title.offset_top = 18.0
	title.offset_right = 620.0
	title.offset_bottom = 52.0
	title.add_theme_font_size_override("font_size", 24)
	canvas.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Build the architecture your civilization will reuse and evolve."
	subtitle.offset_left = 25.0
	subtitle.offset_top = 50.0
	subtitle.offset_right = 720.0
	subtitle.offset_bottom = 78.0
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.74, 0.76, 1.0))
	canvas.add_child(subtitle)

	var left_panel := PanelContainer.new()
	left_panel.anchor_left = 0.0
	left_panel.anchor_top = 0.0
	left_panel.anchor_right = 0.0
	left_panel.anchor_bottom = 1.0
	left_panel.offset_left = 20.0
	left_panel.offset_top = 90.0
	left_panel.offset_right = 350.0
	left_panel.offset_bottom = -20.0
	canvas.add_child(left_panel)
	var left_scroll := ScrollContainer.new()
	left_panel.add_child(left_scroll)
	var left_content := VBoxContainer.new()
	left_content.custom_minimum_size = Vector2(305.0, 0.0)
	left_content.add_theme_constant_override("separation", 8)
	left_scroll.add_child(left_content)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Building design name"
	_name_edit.text = str(blueprint.get("name", "New Building"))
	_name_edit.text_changed.connect(_on_name_changed)
	left_content.add_child(_name_edit)

	_type_option = OptionButton.new()
	for type_name in Blueprint.BUILDING_TYPES:
		_type_option.add_item(type_name.capitalize())
		_type_option.set_item_metadata(_type_option.item_count - 1, type_name)
	_type_option.item_selected.connect(_on_type_selected)
	left_content.add_child(_type_option)

	_add_section_label(left_content, "PART CATEGORIES")
	_category_box = VBoxContainer.new()
	left_content.add_child(_category_box)
	for category in Parts.get_categories():
		var button := Button.new()
		button.text = str(category.get("name", "Parts"))
		button.pressed.connect(
			Callable(self, "_select_category").bind(str(category.get("id", "")))
		)
		_category_box.add_child(button)

	_add_section_label(left_content, "PARTS")
	_part_grid = GridContainer.new()
	_part_grid.columns = 2
	_part_grid.add_theme_constant_override("h_separation", 6)
	_part_grid.add_theme_constant_override("v_separation", 6)
	left_content.add_child(_part_grid)

	var right_panel := PanelContainer.new()
	right_panel.anchor_left = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_bottom = 1.0
	right_panel.offset_left = -360.0
	right_panel.offset_top = 90.0
	right_panel.offset_right = -20.0
	right_panel.offset_bottom = -20.0
	canvas.add_child(right_panel)
	var right_scroll := ScrollContainer.new()
	right_panel.add_child(right_scroll)
	var right_content := VBoxContainer.new()
	right_content.custom_minimum_size = Vector2(315.0, 0.0)
	right_content.add_theme_constant_override("separation", 8)
	right_scroll.add_child(right_content)

	_add_section_label(right_content, "ASSEMBLY")
	var actions := GridContainer.new()
	actions.columns = 2
	right_content.add_child(actions)
	_undo_button = _add_action(actions, "Undo", _undo)
	_redo_button = _add_action(actions, "Redo", _redo)
	_snap_button = _add_action(actions, "Grid Snap", _toggle_grid_snap)
	_add_action(actions, "Duplicate", _duplicate_selected)
	_add_action(actions, "Delete", _delete_selected)
	_add_action(actions, "New", _new_building)
	_add_action(actions, "Save Design", _save_design)
	_add_action(actions, "Autosave", _save_autosave)

	_add_section_label(right_content, "SAVED DESIGNS")
	_design_option = OptionButton.new()
	right_content.add_child(_design_option)
	_add_action(right_content, "Load Selected", _load_selected_design)

	_add_section_label(right_content, "SELECTED PART")
	var transform_help := Label.new()
	transform_help.text = (
		"Tab select · Arrows X/Z · PgUp/PgDn Y\n"
		+ "Q/E yaw · Z/X pitch · [ / ] scale\n"
		+ "D duplicate · Delete remove · G snap\n"
		+ "MMB drag orbit · wheel zoom · Ctrl+Z/Y"
	)
	transform_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	transform_help.add_theme_color_override("font_color", Color(0.67, 0.72, 0.72, 1.0))
	right_content.add_child(transform_help)

	_assembly_list = VBoxContainer.new()
	right_content.add_child(_assembly_list)

	_add_section_label(right_content, "BUILDING STATS")
	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_content.add_child(_stats_label)

	_status_label = Label.new()
	_status_label.anchor_left = 0.5
	_status_label.anchor_top = 1.0
	_status_label.anchor_right = 0.5
	_status_label.anchor_bottom = 1.0
	_status_label.offset_left = -360.0
	_status_label.offset_top = -54.0
	_status_label.offset_right = 360.0
	_status_label.offset_bottom = -18.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.66, 0.90, 0.82, 1.0))
	canvas.add_child(_status_label)


func _refresh_all() -> void:
	Blueprint.normalize(blueprint)
	_refresh_type()
	_refresh_palette()
	_refresh_assembly_list()
	_refresh_stats()
	_refresh_toolbar()
	_refresh_designs()
	if _visual != null:
		_visual.call("set_blueprint", blueprint, selected_part_index)
	Blueprint.save_autosave(blueprint)


func _refresh_type() -> void:
	var current_type: String = Blueprint.get_building_type(blueprint)
	for index in range(_type_option.item_count):
		if str(_type_option.get_item_metadata(index)) == current_type:
			_type_option.select(index)
			break


func _refresh_palette() -> void:
	_clear_children(_part_grid)
	for definition in Parts.get_parts_for_category(current_category):
		var button := Button.new()
		button.custom_minimum_size = Vector2(142.0, 66.0)
		button.text = "%s\n%s" % [
			str(definition.get("name", "Part")),
			_stats_summary(definition.get("stats", {})),
		]
		button.tooltip_text = str(definition.get("description", ""))
		button.pressed.connect(
			Callable(self, "_add_part").bind(str(definition.get("id", "")))
		)
		_part_grid.add_child(button)


func _refresh_assembly_list() -> void:
	_clear_children(_assembly_list)
	var parts: Array = blueprint.get("parts", [])
	for index in range(parts.size()):
		if not (parts[index] is Dictionary):
			continue
		var placement: Dictionary = parts[index]
		var definition: Dictionary = Parts.get_part(str(placement.get("part_id", "")))
		var button := Button.new()
		button.text = "%s%s" % [
			"▶ " if index == selected_part_index else "",
			str(definition.get("name", placement.get("part_id", "Unknown"))),
		]
		button.pressed.connect(Callable(self, "_select_part").bind(index))
		_assembly_list.add_child(button)


func _refresh_stats() -> void:
	var stats: Dictionary = Blueprint.calculate_stats(blueprint)
	var errors: Array[String] = Blueprint.validate(blueprint)
	_stats_label.text = (
		"Type: %s\nRevision: %d\nParts: %d\n\n"
		+ "Housing: %.0f\nCommerce: %.0f\nIndustry: %.0f\n"
		+ "Defense: %.0f\nPrestige: %.0f\nEnergy: %+.0f\n"
		+ "Pollution: %.0f\nCost: %.0f"
	) % [
		Blueprint.get_building_type(blueprint).capitalize(),
		int(blueprint.get("revision", 0)),
		blueprint.get("parts", []).size(),
		float(stats.get("housing", 0.0)),
		float(stats.get("commerce", 0.0)),
		float(stats.get("industry", 0.0)),
		float(stats.get("defense", 0.0)),
		float(stats.get("prestige", 0.0)),
		float(stats.get("energy", 0.0)),
		float(stats.get("pollution", 0.0)),
		float(stats.get("cost", 0.0)),
	]
	if not errors.is_empty():
		_stats_label.text += "\n\nVALIDATION\n• " + "\n• ".join(errors)


func _refresh_toolbar() -> void:
	_undo_button.disabled = not _history.call("can_undo")
	_redo_button.disabled = not _history.call("can_redo")
	_snap_button.text = "Snap: %s" % (
		"ON" if bool(blueprint.get("grid_snap", true)) else "OFF"
	)


func _refresh_designs() -> void:
	var selected_filename: String = ""
	if _design_option.selected >= 0:
		selected_filename = str(_design_option.get_item_metadata(_design_option.selected))
	_design_option.clear()
	for filename in Blueprint.list_designs():
		_design_option.add_item(filename.trim_suffix(".json").replace("_", " ").capitalize())
		_design_option.set_item_metadata(_design_option.item_count - 1, filename)
		if filename == selected_filename:
			_design_option.select(_design_option.item_count - 1)


func _add_part(part_id: String) -> void:
	var definition: Dictionary = Parts.get_part(part_id)
	if definition.is_empty():
		return
	_record("Add %s" % str(definition.get("name", part_id)))
	var position: Vector3 = _suggest_position(str(definition.get("category", "")))
	selected_part_index = Assembly.add_part(blueprint, part_id, position)
	_set_status("Added %s." % str(definition.get("name", part_id)))
	_refresh_all()


func _suggest_position(category: String) -> Vector3:
	var aabb: AABB = _visual.call("get_combined_aabb") if _visual != null else AABB()
	match category:
		Parts.CATEGORY_ROOF:
			return Vector3(0, maxf(aabb.end.y, 3.5), 0)
		Parts.CATEGORY_OPENING:
			return Vector3(0, maxf(aabb.size.y * 0.45, 1.0), aabb.position.z - 0.15)
		Parts.CATEGORY_BALCONY:
			return Vector3(0, maxf(aabb.size.y * 0.55, 1.5), aabb.position.z - 0.2)
		Parts.CATEGORY_UTILITY:
			return Vector3(0, maxf(aabb.end.y, 3.0), 0)
		_:
			return Vector3.ZERO


func _select_category(category_id: String) -> void:
	current_category = category_id
	_refresh_palette()


func _select_part(index: int) -> void:
	selected_part_index = index
	_refresh_assembly_list()
	if _visual != null:
		_visual.call("set_selected_part", selected_part_index)


func _cycle_selection() -> void:
	var count: int = blueprint.get("parts", []).size()
	if count <= 0:
		selected_part_index = -1
	else:
		selected_part_index = posmod(selected_part_index + 1, count)
	_refresh_all()


func _move_selected(direction: Vector3) -> void:
	if selected_part_index < 0:
		return
	_record("Move part")
	var step: float = float(blueprint.get("grid_size", Assembly.DEFAULT_GRID_SIZE)) * MOVE_STEP_MULTIPLIER
	Assembly.transform_part(blueprint, selected_part_index, direction * step)
	_refresh_all()


func _rotate_selected(rotation_delta: Vector3) -> void:
	if selected_part_index < 0:
		return
	_record("Rotate part")
	Assembly.transform_part(blueprint, selected_part_index, Vector3.ZERO, rotation_delta)
	_refresh_all()


func _scale_selected(multiplier: float) -> void:
	if selected_part_index < 0:
		return
	_record("Scale part")
	Assembly.transform_part(
		blueprint,
		selected_part_index,
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ONE * multiplier
	)
	_refresh_all()


func _duplicate_selected() -> void:
	if selected_part_index < 0:
		return
	_record("Duplicate part")
	selected_part_index = Assembly.duplicate_part(blueprint, selected_part_index)
	if selected_part_index >= 0:
		Assembly.transform_part(
			blueprint,
			selected_part_index,
			Vector3(float(blueprint.get("grid_size", 0.25)), 0, 0)
		)
	_refresh_all()


func _delete_selected() -> void:
	if selected_part_index < 0:
		return
	_record("Delete part")
	Assembly.remove_part(blueprint, selected_part_index)
	selected_part_index = mini(selected_part_index, blueprint.get("parts", []).size() - 1)
	_refresh_all()


func _toggle_grid_snap() -> void:
	_record("Toggle grid snap")
	Assembly.set_grid_snap(blueprint, not bool(blueprint.get("grid_snap", true)))
	_refresh_all()


func _undo() -> void:
	if not _history.call("can_undo"):
		return
	blueprint = _history.call("undo", blueprint)
	selected_part_index = mini(selected_part_index, blueprint.get("parts", []).size() - 1)
	_set_status("Undo.")
	_refresh_all()


func _redo() -> void:
	if not _history.call("can_redo"):
		return
	blueprint = _history.call("redo", blueprint)
	selected_part_index = mini(selected_part_index, blueprint.get("parts", []).size() - 1)
	_set_status("Redo.")
	_refresh_all()


func _new_building() -> void:
	_record("New building")
	blueprint = Blueprint.create_default()
	selected_part_index = -1
	_name_edit.text = str(blueprint.get("name", "New Building"))
	_set_status("Started a new building design.")
	_refresh_all()


func _save_design() -> void:
	blueprint["name"] = _name_edit.text.strip_edges()
	var path: String = Blueprint.save_design(blueprint)
	if path.is_empty():
		_set_status("Could not save building design.")
		return
	if not _commit_campaign():
		_set_status("Design written, but the campaign snapshot could not be saved.")
		return
	_set_status("Saved design: %s" % path.get_file())
	_refresh_all()


func _save_autosave() -> void:
	var error: Error = Blueprint.save_autosave(blueprint)
	if error == OK and not _commit_campaign():
		_set_status("Design written, but the campaign snapshot could not be saved.")
		return
	_set_status("Autosave written." if error == OK else "Autosave failed: %s" % error)


func _load_selected_design() -> void:
	if _design_option.selected < 0:
		_set_status("No saved design selected.")
		return
	var filename: String = str(_design_option.get_item_metadata(_design_option.selected))
	var loaded: Dictionary = Blueprint.load_from_file(Blueprint.get_design_path(filename))
	if loaded.is_empty():
		_set_status("Could not load selected design.")
		return
	_record("Load design")
	blueprint = loaded
	selected_part_index = -1
	_name_edit.text = str(blueprint.get("name", "Building"))
	_set_status("Loaded %s." % filename)
	_refresh_all()
	_show_compatibility_warnings()


func _on_name_changed(new_text: String) -> void:
	blueprint["name"] = new_text


func _on_type_selected(index: int) -> void:
	var type_name: String = str(_type_option.get_item_metadata(index))
	_record("Change building type")
	Blueprint.set_building_type(blueprint, type_name)
	_refresh_all()


func _record(label: String) -> void:
	_history.call("push_state", blueprint, label)


func _update_camera() -> void:
	if _camera == null:
		return
	var horizontal: float = cos(_camera_pitch) * _camera_distance
	_camera.position = _camera_target + Vector3(
		sin(_camera_yaw) * horizontal,
		-sin(_camera_pitch) * _camera_distance,
		cos(_camera_yaw) * horizontal
	)
	_camera.look_at(_camera_target, Vector3.UP)


func _stats_summary(stats: Dictionary) -> String:
	var values: Array[String] = []
	for key in ["housing", "commerce", "industry", "defense", "prestige"]:
		if absf(float(stats.get(key, 0.0))) > 0.01:
			values.append("%s %+.0f" % [str(key).substr(0, 3).to_upper(), float(stats[key])])
	return " · ".join(values) if not values.is_empty() else "visual"


func _add_section_label(parent: Control, text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.70, 0.88, 0.84, 1.0))
	parent.add_child(label)
	return label


func _add_action(parent: Control, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(145.0, 34.0)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _clear_children(root: Node) -> void:
	for child in root.get_children():
		child.queue_free()


func _set_status(text_value: String) -> void:
	if _status_label != null:
		_status_label.text = text_value


func _show_compatibility_warnings() -> void:
	if not blueprint.get("compatibility_warnings", []).is_empty():
		_set_status("\n".join(blueprint["compatibility_warnings"]))


func _commit_campaign() -> bool:
	var saves := get_node_or_null("/root/SaveGameService")
	return saves == null or bool(saves.call("save_now"))
