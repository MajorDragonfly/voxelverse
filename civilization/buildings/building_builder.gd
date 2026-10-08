extends Node3D
class_name BuildingBuilder

const Text = preload("res://civilization/buildings/building_editor_text.gd")
const TransformField = preload("res://civilization/buildings/building_transform_field.gd")
const UiText = preload("res://core/localization/ui_text.gd")
const Design = preload("res://ui/design/design_system.gd")
const Symbols = preload("res://ui/design/game_symbols.gd")

const Assembly = preload("res://assembly/core/modular_assembly.gd")
const History = preload("res://assembly/core/modular_assembly_history.gd")
const Parts = preload("res://civilization/buildings/building_part_library.gd")
const Blueprint = preload("res://civilization/buildings/building_blueprint.gd")
const BuildingVisual = preload("res://civilization/buildings/building_runtime_visual.gd")
const Exchange = preload("res://assembly/exchange/building_design_exchange.gd")
const ExchangePackage = preload("res://assembly/exchange/building_blueprint_package.gd")

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
var _selection_label: Label
var _identity_label: Label
var _transform_fields: Dictionary = {}
var _part_buttons: Dictionary = {}
var _selection_actions: Array[Button] = []
var _left_panel: PanelContainer
var _right_panel: PanelContainer
var _left_content: VBoxContainer
var _right_content: VBoxContainer
var _title: Label
var _subtitle: Label
var _ui_canvas: CanvasLayer
var _exchange_dialog: FileDialog
var _exchange_confirmation: ConfirmationDialog
var _pending_exchange_package: Dictionary = {}


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
	get_node("/root/LocaleManager").language_changed.connect(_on_language_changed)
	get_viewport().size_changed.connect(_layout_ui)
	call_deferred("_layout_ui")
	call_deferred("_translate_navigation")


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
	# Name and numeric drafts own their keys, including editor shortcuts.
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
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
	_ui_canvas = CanvasLayer.new()
	_ui_canvas.name = "BuildingBuilderUI"
	add_child(_ui_canvas)
	_title = Label.new()
	_title.theme = Design.theme()
	_title.add_theme_font_size_override("font_size", 24)
	Text.bind(_title, "text", "BEDITOR_TITLE")
	_ui_canvas.add_child(_title)
	_subtitle = Label.new()
	_subtitle.theme = Design.theme()
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_color_override("font_color", Design.MUTED)
	Text.bind(_subtitle, "text", "BEDITOR_SUBTITLE")
	_ui_canvas.add_child(_subtitle)

	_left_panel = PanelContainer.new()
	_left_panel.name = "PalettePanel"
	_style_panel(_left_panel)
	_left_panel.anchor_bottom = 1.0
	_ui_canvas.add_child(_left_panel)
	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left_panel.add_child(left_scroll)
	_left_content = VBoxContainer.new()
	_left_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_content.add_theme_constant_override("separation", 8)
	left_scroll.add_child(_left_content)

	_name_edit = LineEdit.new()
	_name_edit.name = "DesignName"
	Text.bind(_name_edit, "placeholder_text", "BEDITOR_NAME")
	_name_edit.text = str(blueprint.get("name", ""))
	_name_edit.text_changed.connect(_on_name_changed)
	_left_content.add_child(_name_edit)
	_type_option = OptionButton.new()
	_type_option.name = "BuildingType"
	_type_option.fit_to_longest_item = false
	for type_name in Blueprint.BUILDING_TYPES:
		var key: String = "BEDITOR_TYPE_" + type_name.to_upper()
		_type_option.add_item(Text.render(key))
		_type_option.set_meta("building_option_%d" % (_type_option.item_count - 1), key)
		_type_option.set_item_metadata(_type_option.item_count - 1, type_name)
	_type_option.item_selected.connect(_on_type_selected)
	_left_content.add_child(_type_option)

	_add_section_label(_left_content, "BEDITOR_CATEGORIES")
	_category_box = VBoxContainer.new()
	_left_content.add_child(_category_box)
	for category in Parts.get_categories():
		var button := Button.new()
		var id: String = str(category.id)
		button.name = "Category_" + id
		Text.bind(button, "text", "BEDITOR_CATEGORY_" + id.to_upper())
		button.pressed.connect(Callable(self, "_select_category").bind(id))
		_category_box.add_child(button)
	_add_section_label(_left_content, "BEDITOR_PARTS")
	_part_grid = GridContainer.new()
	_part_grid.columns = 1
	_part_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_part_grid.add_theme_constant_override("v_separation", 6)
	_left_content.add_child(_part_grid)

	_right_panel = PanelContainer.new()
	_right_panel.name = "InspectorPanel"
	_style_panel(_right_panel)
	_right_panel.anchor_left = 1.0
	_right_panel.anchor_right = 1.0
	_right_panel.anchor_bottom = 1.0
	_ui_canvas.add_child(_right_panel)
	var right_scroll := ScrollContainer.new()
	right_scroll.name = "InspectorScroll"
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_panel.add_child(right_scroll)
	_right_content = VBoxContainer.new()
	_right_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_content.add_theme_constant_override("separation", 8)
	right_scroll.add_child(_right_content)

	_add_section_label(_right_content, "BEDITOR_SELECTED")
	_selection_label = Label.new()
	_selection_label.name = "SelectedPart"
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_label.add_theme_font_size_override("font_size", 18)
	_right_content.add_child(_selection_label)
	_identity_label = Label.new()
	_identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_identity_label.add_theme_font_size_override("font_size", 12)
	_identity_label.add_theme_color_override("font_color", Design.MUTED)
	_right_content.add_child(_identity_label)
	for field: String in ["position", "rotation", "scale"]:
		_add_transform_row(field)
	_snap_button = _add_action(_right_content, "BEDITOR_SNAP", _toggle_grid_snap)
	_snap_button.name = "GridSnap"
	var selection_actions := GridContainer.new()
	selection_actions.columns = 2
	_right_content.add_child(selection_actions)
	_selection_actions.append(_add_action(selection_actions, "BEDITOR_DUPLICATE", _duplicate_selected))
	_selection_actions.append(_add_action(selection_actions, "BEDITOR_DELETE", _delete_selected))

	_add_section_label(_right_content, "BEDITOR_ASSEMBLY")
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "AssemblyScroll"
	list_scroll.custom_minimum_size.y = 116.0
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_content.add_child(list_scroll)
	_assembly_list = VBoxContainer.new()
	_assembly_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_assembly_list)
	var history_actions := GridContainer.new()
	history_actions.columns = 2
	_right_content.add_child(history_actions)
	_undo_button = _add_action(history_actions, "BEDITOR_UNDO", _undo)
	_redo_button = _add_action(history_actions, "BEDITOR_REDO", _redo)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 12)
	Text.bind(help, "text", "BEDITOR_SHORTCUTS")
	_right_content.add_child(help)

	_add_section_label(_right_content, "BEDITOR_DESIGNS")
	_design_option = OptionButton.new()
	_design_option.name = "SavedDesigns"
	_design_option.fit_to_longest_item = false
	_right_content.add_child(_design_option)
	var file_actions := GridContainer.new()
	# The long import/export labels would give a two-column grid a wider minimum
	# than the inspector itself, pushing the panel beyond the viewport.
	file_actions.columns = 1
	_right_content.add_child(file_actions)
	_add_action(file_actions, "BEDITOR_LOAD", _load_selected_design)
	_add_action(file_actions, "BEDITOR_SAVE", _save_design)
	_add_action(file_actions, "BEDITOR_NEW", _new_building)
	_add_action(file_actions, "BEDITOR_AUTOSAVE", _save_autosave)
	_add_action(file_actions, "BEDITOR_EXCHANGE_IMPORT", func(): _show_exchange_dialog(false))
	_add_action(file_actions, "BEDITOR_EXCHANGE_EXPORT", func(): _show_exchange_dialog(true))
	var templates := preload("res://civilization/buildings/templates/building_template_picker.gd").new()
	templates.name = "TemplatePicker"
	templates.template_chosen.connect(func(copy: Dictionary):
		preload("res://civilization/buildings/templates/building_template_selection.gd").apply_to_editor(self, copy)
	)
	_right_content.add_child(templates)
	_add_section_label(_right_content, "BEDITOR_STATS")
	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right_content.add_child(_stats_label)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.theme = Design.theme()
	_status_label.anchor_top = 1.0
	_status_label.anchor_right = 1.0
	_status_label.anchor_bottom = 1.0
	_status_label.offset_left = 20.0
	_status_label.offset_top = -66.0
	_status_label.offset_right = -20.0
	_status_label.offset_bottom = -12.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Design.SOCIAL)
	_ui_canvas.add_child(_status_label)
	_exchange_dialog = FileDialog.new()
	_exchange_dialog.name = "BuildingExchangeDialog"
	_exchange_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_exchange_dialog.filters = PackedStringArray(["*.json ; JSON"])
	_exchange_dialog.file_selected.connect(_exchange_file_selected)
	_ui_canvas.add_child(_exchange_dialog)
	_exchange_confirmation = ConfirmationDialog.new()
	_exchange_confirmation.name = "BuildingExchangeCopyConfirmation"
	_exchange_confirmation.confirmed.connect(_adopt_exchange_copy)
	_exchange_confirmation.canceled.connect(func(): _pending_exchange_package.clear())
	_ui_canvas.add_child(_exchange_confirmation)


func _add_transform_row(field: String) -> void:
	_add_section_label(_right_content, "BEDITOR_" + field.to_upper())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_right_content.add_child(row)
	for axis in range(3):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		var label := Label.new()
		label.text = ["X", "Y", "Z"][axis]
		column.add_child(label)
		var spin := TransformField.new()
		spin.name = field.capitalize() + ["X", "Y", "Z"][axis]
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.custom_minimum_size.x = 84.0
		spin.limit_value = field == "scale"
		spin.invalid_value.connect(Callable(self, "_set_status").bind("BEDITOR_TRANSFORM_INVALID"))
		spin.value_changed.connect(Callable(self, "_on_transform_value").bind(field, axis))
		column.add_child(spin)
		_transform_fields[field + "_%d" % axis] = spin


func _style_panel(panel: PanelContainer) -> void:
	var editor_theme: Theme = Design.theme().duplicate() as Theme
	editor_theme.default_font_size = 16
	panel.theme = editor_theme
	panel.add_theme_stylebox_override("panel", Design.box(Design.PANEL, Design.EDGE, 12))


func _layout_ui() -> void:
	if _left_panel == null:
		return
	var width: float = get_viewport().get_visible_rect().size.x
	var left_width: float = clampf(width * 0.24, 200.0, 305.0)
	var right_width: float = clampf(width * 0.29, 316.0, 360.0)
	_left_panel.offset_left = 16.0
	_left_panel.offset_right = 16.0 + left_width
	_left_panel.offset_top = 102.0
	_left_panel.offset_bottom = -80.0
	_right_panel.offset_left = -16.0 - right_width
	_right_panel.offset_right = -16.0
	_right_panel.offset_top = 102.0
	_right_panel.offset_bottom = -80.0
	_left_content.custom_minimum_size.x = left_width - 32.0
	_right_content.custom_minimum_size.x = right_width - 32.0
	_title.position = Vector2(20.0, 16.0)
	_title.size = Vector2(maxf(width - 225.0, 100.0), 32.0)
	_title.add_theme_font_size_override("font_size", 18 if width < 1000.0 else 24)
	_subtitle.position = Vector2(20.0, 52.0)
	_subtitle.size = Vector2(width - 40.0, 46.0)


func _translate_navigation() -> void:
	var button := get_node_or_null("BuildingBuilderUI/BackToWorld") as Button
	if button != null:
		Text.bind(button, "text", "BEDITOR_BACK")


func _on_language_changed(_locale: String) -> void:
	# Re-label in place. Numeric drafts, focus, selection and history survive.
	Text.refresh(_ui_canvas)
	for id: String in _part_buttons:
		Text.bind(_part_buttons[id], "text", Text.message("BEDITOR_PALETTE_PART", {
			"name": Text.part(id), "stats": _stats_summary(Parts.get_part(id).get("stats", {})),
		}))
	_refresh_stats()
	_refresh_toolbar()
	if _exchange_dialog.visible:
		_exchange_dialog.title = Text.render("BEDITOR_EXCHANGE_EXPORT" if _exchange_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE else "BEDITOR_EXCHANGE_IMPORT")
	if _exchange_confirmation.visible: _refresh_exchange_confirmation()


func _refresh_inspector() -> void:
	var placement: Dictionary = Assembly.get_part(blueprint, selected_part_index)
	var enabled: bool = not placement.is_empty()
	if enabled:
		Text.bind(_selection_label, "text", Text.message("BEDITOR_SELECTION", {
			"name": Text.part(str(placement.part_id)),
			"index": selected_part_index + 1, "count": blueprint.parts.size(),
		}))
		Text.bind(_identity_label, "text", Text.message("BEDITOR_IDENTITY", {
			"id": placement.part_id, "uid": placement.uid,
		}))
	else:
		Text.bind(_selection_label, "text", "BEDITOR_NO_SELECTION")
		Text.bind(_identity_label, "text", "BEDITOR_SELECT_HINT")
	for field: String in ["position", "rotation", "scale"]:
		var value: Vector3 = placement.get(field, Vector3.ONE if field == "scale" else Vector3.ZERO)
		for axis in range(3):
			var spin: TransformField = _transform_fields[field + "_%d" % axis]
			spin.nudge_step = float(blueprint.get("grid_size", Assembly.DEFAULT_GRID_SIZE)) if field == "position" and blueprint.get("grid_snap", true) else (0.01 if field == "position" else 15.0 if field == "rotation" else 0.05)
			spin.editable = enabled
			spin.get_line_edit().focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
			spin.set_value_no_signal(value[axis])
	for button: Button in _selection_actions:
		button.disabled = not enabled


func _on_transform_value(value: float, field: String, axis: int) -> void:
	var placement: Dictionary = Assembly.get_part(blueprint, selected_part_index)
	if placement.is_empty() or not is_finite(value):
		return
	var current: Vector3 = placement[field]
	var requested: Vector3 = current
	requested[axis] = value
	var candidate: Dictionary = blueprint.duplicate(true)
	match field:
		"position": Assembly.transform_part(candidate, selected_part_index, requested - current)
		"rotation": Assembly.transform_part(candidate, selected_part_index, Vector3.ZERO, requested - current)
		"scale": Assembly.transform_part(candidate, selected_part_index, Vector3.ZERO, Vector3.ZERO, requested / current)
	var edited: Dictionary = Assembly.get_part(candidate, selected_part_index)
	var position: Vector3 = placement.position
	if field == "position":
		position[axis] = edited.position[axis]
	edited.position = position
	Assembly.set_part(candidate, selected_part_index, edited)
	if not Blueprint.Contract.inspect(candidate, "building").ok:
		_set_status(Text.message("BEDITOR_TRANSFORM_INVALID"))
		_refresh_inspector()
		return
	if candidate == blueprint:
		_refresh_inspector()
		return
	_record("BEDITOR_" + field.to_upper())
	blueprint = candidate
	_set_status(Text.message("BEDITOR_TRANSFORM_APPLIED"))
	_refresh_all()


func _refresh_all() -> void:
	Blueprint.normalize(blueprint)
	if _name_edit.text != str(blueprint.get("name", "")):
		_name_edit.text = str(blueprint.get("name", ""))
	_refresh_type()
	_refresh_palette()
	_refresh_assembly_list()
	_refresh_inspector()
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
	_part_buttons.clear()
	for definition in Parts.get_parts_for_category(current_category):
		var button := Button.new()
		var id: String = str(definition.id)
		button.name = "Part_" + id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 64.0
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Symbols.apply(button, "building", 24)
		button.clip_text = true
		Text.bind(button, "text", Text.message("BEDITOR_PALETTE_PART", {
			"name": Text.part(id), "stats": _stats_summary(definition.get("stats", {})),
		}))
		Text.bind(button, "tooltip_text", Text.part(id, "description"))
		button.pressed.connect(Callable(self, "_add_part").bind(id))
		_part_grid.add_child(button)
		_part_buttons[id] = button


func _refresh_assembly_list() -> void:
	_clear_children(_assembly_list)
	var parts: Array = blueprint.get("parts", [])
	for index in range(parts.size()):
		if not (parts[index] is Dictionary):
			continue
		var placement: Dictionary = parts[index]
		var button := Button.new()
		button.name = "Placement_%d" % index
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = index == selected_part_index
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		Text.bind(button, "text", Text.message("BEDITOR_LIST_PART", {
			"index": index + 1, "name": Text.part(str(placement.part_id)),
		}))
		Text.bind(button, "tooltip_text", Text.message("BEDITOR_IDENTITY", {
			"id": placement.part_id, "uid": placement.uid,
		}))
		button.pressed.connect(Callable(self, "_select_part").bind(index))
		_assembly_list.add_child(button)


func _refresh_stats() -> void:
	var stats: Dictionary = Blueprint.calculate_stats(blueprint)
	var text_value: String = Text.render(Text.message("BEDITOR_STATS_HEADER", {
		"type": Text.message("BEDITOR_TYPE_" + Blueprint.get_building_type(blueprint).to_upper()),
		"revision": blueprint.get("revision", 0), "count": blueprint.get("parts", []).size(),
	}))
	for key: String in ["housing", "commerce", "industry", "defense", "prestige", "energy", "pollution", "cost"]:
		text_value += "\n" + Text.render("BEDITOR_STAT_" + key.to_upper()) + ": " + UiText.number(float(stats.get(key, 0.0)), 0)
	var errors: Array[String] = Blueprint.validate(blueprint)
	if not errors.is_empty():
		text_value += "\n\n" + Text.render("BEDITOR_VALIDATION") + "\n• " + Text.validation(errors)
	_stats_label.text = text_value


func _refresh_toolbar() -> void:
	_undo_button.disabled = not _history.call("can_undo")
	_redo_button.disabled = not _history.call("can_redo")
	Text.bind(_snap_button, "text", Text.message("BEDITOR_SNAP_STATE", {
		"state": Text.message("BEDITOR_ON" if bool(blueprint.get("grid_snap", true)) else "BEDITOR_OFF"),
		"step": UiText.number(float(blueprint.get("grid_size", Assembly.DEFAULT_GRID_SIZE))),
	}))


func _refresh_designs() -> void:
	var selected_filename: String = ""
	if _design_option.selected >= 0:
		selected_filename = str(_design_option.get_item_metadata(_design_option.selected))
	_design_option.clear()
	for filename in Blueprint.list_designs():
		_design_option.add_item(filename.trim_suffix(".json"))
		_design_option.set_item_metadata(_design_option.item_count - 1, filename)
		if filename == selected_filename:
			_design_option.select(_design_option.item_count - 1)


func _add_part(part_id: String) -> void:
	var definition: Dictionary = Parts.get_part(part_id)
	if definition.is_empty():
		return
	var candidate: Dictionary = blueprint.duplicate(true)
	var position: Vector3 = _suggest_position(str(definition.get("category", "")))
	var added: int = Assembly.add_part(candidate, part_id, position)
	if added < 0:
		_set_status("BEDITOR_PART_LIMIT")
		return
	_record("BEDITOR_PARTS")
	blueprint = candidate
	selected_part_index = added
	_set_status(Text.message("BEDITOR_ADDED", {"name": Text.part(part_id)}))
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
	_refresh_inspector()
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
	_record("BEDITOR_POSITION")
	var step: float = float(blueprint.get("grid_size", Assembly.DEFAULT_GRID_SIZE)) * MOVE_STEP_MULTIPLIER
	Assembly.transform_part(blueprint, selected_part_index, direction * step)
	_refresh_all()


func _rotate_selected(rotation_delta: Vector3) -> void:
	if selected_part_index < 0:
		return
	_record("BEDITOR_ROTATION")
	var original_position: Vector3 = Assembly.get_part(blueprint, selected_part_index).position
	Assembly.transform_part(blueprint, selected_part_index, Vector3.ZERO, rotation_delta)
	Assembly.get_part(blueprint, selected_part_index).position = original_position
	_refresh_all()


func _scale_selected(multiplier: float) -> void:
	if selected_part_index < 0:
		return
	_record("BEDITOR_SCALE")
	var original_position: Vector3 = Assembly.get_part(blueprint, selected_part_index).position
	Assembly.transform_part(
		blueprint,
		selected_part_index,
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ONE * multiplier
	)
	Assembly.get_part(blueprint, selected_part_index).position = original_position
	_refresh_all()


func _duplicate_selected() -> void:
	if selected_part_index < 0:
		return
	var candidate: Dictionary = blueprint.duplicate(true)
	var duplicated: int = Assembly.duplicate_part(candidate, selected_part_index)
	if duplicated < 0:
		_set_status("BEDITOR_PART_LIMIT")
		return
	_record("BEDITOR_DUPLICATE")
	blueprint = candidate
	selected_part_index = duplicated
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
	_record("BEDITOR_DELETE")
	Assembly.remove_part(blueprint, selected_part_index)
	selected_part_index = mini(selected_part_index, blueprint.get("parts", []).size() - 1)
	_refresh_all()


func _toggle_grid_snap() -> void:
	_record("BEDITOR_SNAP")
	Assembly.set_grid_snap(blueprint, not bool(blueprint.get("grid_snap", true)))
	_refresh_all()


func _undo() -> void:
	if not _history.call("can_undo"):
		return
	blueprint = _history.call("undo", blueprint)
	selected_part_index = mini(selected_part_index, blueprint.get("parts", []).size() - 1)
	_set_status("BEDITOR_UNDO_APPLIED")
	_refresh_all()


func _redo() -> void:
	if not _history.call("can_redo"):
		return
	blueprint = _history.call("redo", blueprint)
	selected_part_index = mini(selected_part_index, blueprint.get("parts", []).size() - 1)
	_set_status("BEDITOR_REDO_APPLIED")
	_refresh_all()


func _new_building() -> void:
	_record("BEDITOR_NEW")
	blueprint = Blueprint.create_default()
	selected_part_index = -1
	_name_edit.text = str(blueprint.get("name", "New Building"))
	_set_status("BEDITOR_NEW_STARTED")
	_refresh_all()


func _save_design() -> void:
	blueprint["name"] = _name_edit.text.strip_edges()
	if not _copy_save_target_available():
		_set_status("BEDITOR_EXCHANGE_COPY_COLLISION")
		return
	var path: String = Blueprint.save_design(blueprint)
	if path.is_empty():
		_set_status("BEDITOR_SAVE_FAILED")
		return
	if not _commit_campaign():
		_set_status("BEDITOR_CAMPAIGN_SAVE_FAILED")
		return
	_set_status(Text.message("BEDITOR_SAVED", {"file": path.get_file()}))
	_refresh_all()


func _save_autosave() -> void:
	var error: Error = Blueprint.save_autosave(blueprint)
	if error == OK and not _commit_campaign():
		_set_status("BEDITOR_CAMPAIGN_SAVE_FAILED")
		return
	_set_status("BEDITOR_AUTOSAVED" if error == OK else Text.message("BEDITOR_AUTOSAVE_FAILED", {"error": error}))


func _load_selected_design() -> void:
	if _design_option.selected < 0:
		_set_status("BEDITOR_LOAD_NONE")
		return
	var filename: String = str(_design_option.get_item_metadata(_design_option.selected))
	var loaded: Dictionary = Blueprint.load_from_file(Blueprint.get_design_path(filename))
	if loaded.is_empty():
		_set_status("BEDITOR_LOAD_FAILED")
		return
	_record("BEDITOR_LOAD")
	blueprint = loaded
	selected_part_index = -1
	_name_edit.text = str(blueprint.get("name", "Building"))
	_set_status(Text.message("BEDITOR_LOADED", {"file": filename}))
	_refresh_all()
	_show_compatibility_warnings()


func _on_name_changed(new_text: String) -> void:
	blueprint["name"] = new_text


func _on_type_selected(index: int) -> void:
	var type_name: String = str(_type_option.get_item_metadata(index))
	_record("BEDITOR_TYPE_CHANGE")
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
	for key: String in ["housing", "commerce", "industry", "defense", "prestige"]:
		if absf(float(stats.get(key, 0.0))) > 0.01:
			values.append(Text.render("BEDITOR_STAT_" + key.to_upper()) + " " + UiText.number(float(stats[key]), 0))
	return " · ".join(values) if not values.is_empty() else Text.render("BEDITOR_VISUAL")


func _add_section_label(parent: Control, text_value: String) -> Label:
	var label := Label.new()
	Text.bind(label, "text", text_value)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Design.ACCENT)
	parent.add_child(label)
	return label


func _add_action(parent: Control, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = text_value.trim_prefix("BEDITOR_").capitalize().replace(" ", "")
	Text.bind(button, "text", text_value)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(125.0, 40.0)
	var symbol: String = {"BEDITOR_DUPLICATE": "copy", "BEDITOR_DELETE": "delete", "BEDITOR_UNDO": "undo", "BEDITOR_REDO": "redo", "BEDITOR_LOAD": "import", "BEDITOR_SAVE": "save", "BEDITOR_AUTOSAVE": "save", "BEDITOR_EXCHANGE_IMPORT": "import", "BEDITOR_EXCHANGE_EXPORT": "export"}.get(text_value, "")
	if not symbol.is_empty(): Symbols.apply(button, symbol, 20)
	# Paired workshop actions share a narrow inspector; reserve the symbol
	# without the broad menu padding used by the title screen.
	button.add_theme_constant_override("h_separation", 8)
	button.add_theme_stylebox_override("normal", Design.box(Design.PANEL, Design.CONTROL, 4))
	button.add_theme_stylebox_override("hover", Design.box(Design.HOVER, Design.ACCENT, 4))
	button.add_theme_stylebox_override("pressed", Design.box(Design.PRESSED, Design.ACCENT, 4))
	button.add_theme_stylebox_override("disabled", Design.box(Design.DISABLED, Design.EDGE, 4))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _clear_children(root: Node) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()


func _set_status(copy: Variant) -> void:
	if _status_label != null:
		Text.bind(_status_label, "text", copy)


func _show_compatibility_warnings() -> void:
	if not blueprint.get("compatibility_warnings", []).is_empty():
		_set_status(Text.message("BEDITOR_COMPATIBILITY", {"codes": ", ".join(blueprint["compatibility_warnings"])}))


func _commit_campaign() -> bool:
	var saves := get_node_or_null("/root/SaveGameService")
	return saves == null or bool(saves.call("save_now"))


func export_exchange_file(destination: String, metadata: Dictionary = {}) -> Dictionary:
	return Exchange.export_file(blueprint, destination, metadata)


func import_exchange_file(source: String) -> Dictionary:
	return Exchange.import_file(source)


## The inbox remains immutable; adoption is explicit and gets a new identity.
func prepare_exchange_editor_copy(package: Dictionary) -> Dictionary:
	var state := get_node_or_null("/root/GameState")
	var saves := get_node_or_null("/root/SaveGameService")
	if state == null or saves == null or not saves.session_active:
		return {"ok": false, "code": "no_campaign"}
	if saves.is_phase_transition_active(): return {"ok": false, "code": "transition_active"}
	if int(state.current_phase) < state.Phase.ANCIENT_MEDIEVAL:
		return {"ok": false, "code": "phase_not_editable"}
	if blueprint.has("_protected_design_source") or not Blueprint.Contract.inspect(blueprint, "building").ok:
		return {"ok": false, "code": "protected_target"}
	return ExchangePackage.prepare_working_copy(package)


func _show_exchange_dialog(exporting: bool) -> void:
	_exchange_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if exporting else FileDialog.FILE_MODE_OPEN_FILE
	_exchange_dialog.title = Text.render("BEDITOR_EXCHANGE_EXPORT" if exporting else "BEDITOR_EXCHANGE_IMPORT")
	if exporting: _exchange_dialog.current_file = "building-design.json"
	_exchange_dialog.popup_centered(Vector2i(640, 420))


func _exchange_file_selected(path: String) -> void:
	var exporting: bool = _exchange_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE
	# FileDialog emits before its own close completes. Release exclusivity before
	# the import confirmation becomes the editor's next modal child window.
	_exchange_dialog.hide()
	var result: Dictionary = export_exchange_file(path) if exporting else import_exchange_file(path)
	if not result.ok:
		_set_status(Text.message("BEDITOR_EXCHANGE_FAILED", {"code": result.code}))
		return
	if exporting:
		_set_status("BEDITOR_EXCHANGE_EXPORTED")
		return
	_pending_exchange_package = result.package.duplicate(true)
	_refresh_exchange_confirmation()
	_exchange_confirmation.popup_centered(Vector2i(480, 240))


func _refresh_exchange_confirmation() -> void:
	_exchange_confirmation.title = Text.render("BEDITOR_EXCHANGE_IMPORT")
	_exchange_confirmation.dialog_text = Text.render(Text.message("BEDITOR_EXCHANGE_COPY_CONFIRM", {
		"name": _pending_exchange_package.get("title", ""),
		"revision": _pending_exchange_package.get("revision", 0),
		"parts": _pending_exchange_package.get("required_parts", []).size(),
	}))


func _adopt_exchange_copy() -> void:
	var result: Dictionary = prepare_exchange_editor_copy(_pending_exchange_package)
	_pending_exchange_package.clear()
	if not result.ok:
		_set_status(Text.message("BEDITOR_EXCHANGE_FAILED", {"code": result.code}))
		return
	_record("BEDITOR_EXCHANGE_IMPORT")
	blueprint = result.blueprint
	selected_part_index = -1
	_refresh_all()
	_set_status("BEDITOR_EXCHANGE_ADOPTED")


func _copy_save_target_available() -> bool:
	var received: bool = blueprint.get("extensions", {}).has(ExchangePackage.ORIGIN_KEY)
	var template: bool = blueprint.get("metadata", {}).has("source_template")
	if not received and not template: return true
	var path: String = Blueprint.get_design_path(Blueprint._slugify(str(blueprint.get("name", ""))) + ".json")
	var texts: Array[String] = [Blueprint.Store.read_text(path)]
	if FileAccess.file_exists(path): texts.append(FileAccess.get_file_as_string(path))
	for text: String in texts:
		if text.is_empty(): continue
		if not Blueprint.Contract.inspect_text(text, "building").ok: return false
		var previous: Dictionary = JSON.parse_string(text)
		if str(previous.get("design_id", "")) != str(blueprint.get("design_id", "")): return false
	return true
