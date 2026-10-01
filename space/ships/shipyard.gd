extends Control
## Standalone M9.1 authoring scene. No campaign/epoch mutation.
const Ship = preload("res://space/ships/ship_blueprint.gd")
const History = preload("res://assembly/core/modular_assembly_history.gd")
const Assembler = preload("res://assembly/runtime/modular_asset_assembler.gd")
const Placement = preload("res://space/ships/ship_placement.gd")
const LibraryPage = preload("res://space/ships/ship_library_page.gd")
const Present = preload("res://space/ships/shipyard_presentation.gd")
const Text = preload("res://core/localization/ui_text.gd")
const MeshBuilder = preload("res://assembly/runtime/modular_voxel_mesh_builder.gd")
const DesignExchange = preload("res://assembly/exchange/ship_design_exchange.gd")

var blueprint: Dictionary = {}
var history := History.new()
var selected: int = -1
var dirty: bool = false
var current_path: String = ""
var _refreshing: bool = false
var _definitions: Dictionary = Ship.Catalog.all()
var _module_ids: Array[String] = []
var _library_entries: Array[Dictionary] = []
var _name_field: LineEdit
var _catalog: ItemList
var _installed: ItemList
var _stats: Label
var _issues: ItemList
var _status: Label
var _fit: Label
var _position_fields: Array[SpinBox] = []
var _selection_actions: Array[Button] = []
var _catalog_details: Label
var _module_details: Label
var _issue_details: Label
var _issue_count: Label
var _fit_pair: Array[Dictionary] = []
var _status_key: String = ""
var _status_values: Dictionary = {}
var _status_code: String = ""
var _module_title: Label
var _undo_button: Button
var _redo_button: Button
var _viewport_container: TextureRect
var _viewport: SubViewport
var _world: Node3D
var _assembler: Node3D
var _camera: Camera3D
var _library: Window
var _library_list: ItemList
var _confirmation: ConfirmationDialog
var _target: Vector3 = Vector3.ZERO
var _distance: float = 60.0
var _yaw: float = 0.65
var _pitch: float = 0.42
var _search: LineEdit
var _category: OptionButton
var _side: OptionButton
var _placement_yaw: OptionButton
var _symmetry: CheckButton
var _preview_toggle: CheckButton
var _placement_label: Label
var _add_button: Button
var _ghost: MeshInstance3D
var _selection_outline: MeshInstance3D
var _evaluation: Dictionary = {}
var mesh_build_count: int = 0
var evaluation_count: int = 0
var _pending_action: Callable
var _rename_open: bool = false
var _library_page := LibraryPage.new()
var _library_search: LineEdit
var _library_status: Label
var _library_previous: Button
var _library_next: Button
var _library_offsets: Array[int] = [0]
var _library_page_index: int = 0
var _library_loading: bool = false
var _previous_auto_quit: bool = true
var _exchange_dialog: FileDialog


func _ready() -> void:
	_build_ui()
	new_template("expedition")
	resized.connect(_resize_columns)
	_resize_columns()
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false

func _exit_tree() -> void:
	_library_page.cancel()
	if get_tree() != null: get_tree().auto_accept_quit = _previous_auto_quit

func _process(_delta: float) -> void:
	if not _library_loading: return
	if not _library.visible:
		_library_page.cancel()
		_library_loading = false
		return
	_library_page.advance()
	_library_status.text = Text.format_text("SY_LIBRARY_PROGRESS", {"count": _library_page.entries.size()})
	if _library_page.done: _finish_library_page()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _guard(func() -> void: preload("res://core/runtime_shutdown.gd").finish(get_tree()))
	if what == NOTIFICATION_TRANSLATION_CHANGED and _status != null: _retranslate()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skin := Theme.new()
	skin.default_font_size = 15
	skin.set_color("font_color", "Label", Color("d8e6ed"))
	skin.set_color("font_color", "Button", Color("e4eff3"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("253e50") if state == "normal" else Color("385c6f")
		style.set_corner_radius_all(5)
		style.content_margin_left = 11
		style.content_margin_right = 11
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		skin.set_stylebox(state, "Button", style)
	theme = skin
	var background := ColorRect.new()
	background.color = Color("101e2a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var heading := HBoxContainer.new()
	root.add_child(heading)
	var title := Label.new()
	_bind_text(title, "text", "SY_TITLE")
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_button(heading, "SY_CENTER", frame_design)
	var toolbar := HFlowContainer.new()
	root.add_child(toolbar)
	_button(toolbar, "SY_NEW_EXPEDITION", func() -> void: _guard(func() -> void: new_template("expedition")))
	_button(toolbar, "SY_NEW_LANDER", func() -> void: _guard(func() -> void: new_template("lander")))
	_button(toolbar, "SY_SAVE", save_current)
	_button(toolbar, "SY_COPY", save_as_copy)
	_button(toolbar, "SY_OPEN", _open_library)
	_button(toolbar, "SHIP_EXCHANGE_IMPORT", func(): _show_exchange_dialog(false))
	_button(toolbar, "SHIP_EXCHANGE_EXPORT", func(): _show_exchange_dialog(true))
	_button(toolbar, "FLEET_ENTRY", func() -> void: _guard(func() -> void: get_tree().change_scene_to_file("res://space/fleet/fleet_trial.tscn")))
	_undo_button = _button(toolbar, "SY_UNDO", undo)
	_redo_button = _button(toolbar, "SY_REDO", redo)
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	root.add_child(columns)
	var left: VBoxContainer = _sidebar(columns, "Modules", 220)
	_label(left, "SY_MODULES", 18)
	_search = LineEdit.new()
	_bind_text(_search, "placeholder_text", "SY_SEARCH")
	_search.text_changed.connect(func(_value: String) -> void: _fill_catalog())
	left.add_child(_search)
	_category = OptionButton.new()
	for key: String in Present.CATEGORY_KEYS: _category.add_item(Text.text(key))
	_category.item_selected.connect(func(_index: int) -> void: _fill_catalog())
	left.add_child(_category)
	_catalog = ItemList.new()
	_catalog.custom_minimum_size.y = 160
	_catalog.item_selected.connect(_catalog_selected)
	left.add_child(_catalog)
	_catalog_details = _label(left, "", 13)
	_side = OptionButton.new()
	for index in range(6): _side.add_item(Text.text("SY_SIDE_%d" % index))
	_side.item_selected.connect(func(_index: int) -> void: _update_preview())
	left.add_child(_side)
	_placement_yaw = OptionButton.new()
	for yaw in [0, 90, 180, 270]: _placement_yaw.add_item(Text.format_text("SY_YAW", {"yaw": yaw}))
	_placement_yaw.item_selected.connect(func(_index: int) -> void: _update_preview())
	left.add_child(_placement_yaw)
	_symmetry = CheckButton.new()
	_bind_text(_symmetry, "text", "SY_SYMMETRY")
	_symmetry.toggled.connect(func(_enabled: bool) -> void: _update_preview())
	left.add_child(_symmetry)
	_preview_toggle = CheckButton.new()
	_bind_text(_preview_toggle, "text", "SY_PREVIEW")
	_preview_toggle.toggled.connect(func(_enabled: bool) -> void: _update_preview())
	left.add_child(_preview_toggle)
	_add_button = _button(left, "SY_ADD", add_selected_module)
	_placement_label = _label(left, "", 13)
	_label(left, "SY_INSTALLED", 18)
	_installed = ItemList.new()
	_installed.custom_minimum_size.y = 230
	_installed.item_selected.connect(select_part)
	left.add_child(_installed)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(center)
	_name_field = LineEdit.new()
	_bind_text(_name_field, "placeholder_text", "SY_NAME")
	_name_field.max_length = 120
	_name_field.text_changed.connect(_rename)
	_name_field.focus_exited.connect(func() -> void: _rename_open = false)
	center.add_child(_name_field)
	var views := HFlowContainer.new()
	center.add_child(views)
	for view: String in ["perspective", "top", "front", "side"]:
		_button(views, "SY_VIEW_" + view.to_upper(), func() -> void: set_view(view))
	# TextureRect displays the retained frame without taking ownership of the
	# SubViewport update policy. Redraw is requested only by actual visual edits.
	_viewport_container = TextureRect.new()
	_viewport_container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_viewport_container.stretch_mode = TextureRect.STRETCH_SCALE
	_viewport_container.custom_minimum_size = Vector2(220, 220)
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.gui_input.connect(_view_input)
	center.add_child(_viewport_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport_container.add_child(_viewport)
	_viewport_container.texture = _viewport.get_texture()
	_viewport_container.resized.connect(_request_render)
	_world = Node3D.new()
	_viewport.add_child(_world)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("152839")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("bdd7e2")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	_world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_energy = 1.4
	_world.add_child(sun)
	_assembler = Assembler.new()
	_world.add_child(_assembler)
	_ghost = MeshInstance3D.new()
	_ghost.visible = false
	_world.add_child(_ghost)
	_selection_outline = MeshInstance3D.new()
	_world.add_child(_selection_outline)
	_camera = Camera3D.new()
	_camera.fov = 45
	_camera.far = 2000
	_world.add_child(_camera)
	_camera.current = true
	_add_grid()
	_label(center, "SY_CONTROLS", 13)
	var right: VBoxContainer = _sidebar(columns, "Inspector", 280)
	_module_title = _label(right, "", 18)
	_module_details = _label(right, "", 13)
	var position_row := HBoxContainer.new()
	right.add_child(position_row)
	for axis in range(3):
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		position_row.add_child(box)
		_label(box, ["X", "Y", "Z"][axis], 13)
		var spin := SpinBox.new()
		spin.min_value = -200
		spin.max_value = 200
		spin.step = 1
		spin.custom_minimum_size.x = 68
		spin.value_changed.connect(func(value: float) -> void: _move_axis(axis, value))
		box.add_child(spin)
		_position_fields.append(spin)
	var actions := HFlowContainer.new()
	right.add_child(actions)
	_selection_actions.append(_button(actions, "SY_ROTATE", rotate_part))
	_selection_actions.append(_button(actions, "SY_MIRROR", mirror_part))
	_selection_actions.append(_button(actions, "SY_REMOVE", remove_part))
	_label(right, "SY_EQUIPMENT", 18)
	_stats = _label(right, "", 15)
	_label(right, "SY_VALIDATION", 18)
	_issue_count = _label(right, "", 14)
	_issues = ItemList.new()
	_issues.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_issues.custom_minimum_size.y = 135
	_issues.item_selected.connect(_select_issue)
	right.add_child(_issues)
	_issue_details = _label(right, "", 13)
	_fit = _label(right, "", 14)
	_button(right, "SY_CHECK_FIT", _open_fit_library)
	var notice: Label = _label(right, "SY_NOTICE", 13)
	notice.modulate = Color("8ea5b5")
	_status = _label(root, "", 14)
	_status.custom_minimum_size.y = 36
	_confirmation = ConfirmationDialog.new()
	_bind_text(_confirmation, "title", "SY_UNSAVED")
	_confirmation.dialog_text = Text.text("SY_DISCARD_QUESTION")
	_bind_text(_confirmation.get_ok_button(), "text", "SY_DISCARD")
	_bind_text(_confirmation.get_cancel_button(), "text", "SY_BACK")
	_bind_text(_confirmation.add_button(Text.text("SY_SAVE_CONTINUE"), true, "save_continue"), "text", "SY_SAVE_CONTINUE")
	_confirmation.confirmed.connect(_discard_continue)
	_confirmation.canceled.connect(func() -> void: _pending_action = Callable())
	_confirmation.custom_action.connect(func(action: StringName) -> void:
		if action == &"save_continue":
			if save_current():
				_confirmation.hide()
				_discard_continue()
			else: _confirmation.dialog_text = _status.text + "\n" + Text.text("SY_KEEP_OPEN"))
	add_child(_confirmation)
	_library = Window.new()
	_library.visible = false
	_library.title = Text.text("SY_LIBRARY")
	_library.size = Vector2i(580, 400)
	_library.transient = true
	_library.exclusive = true
	_library.close_requested.connect(func() -> void: _library.hide())
	add_child(_library)
	var library_box := VBoxContainer.new()
	library_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_library.add_child(library_box)
	_library_search = LineEdit.new()
	_bind_text(_library_search, "placeholder_text", "SY_LIBRARY_SEARCH")
	_library_search.text_changed.connect(func(_value: String) -> void:
		_library_offsets = [0]
		_library_page_index = 0
		_start_library_page())
	library_box.add_child(_library_search)
	_library_list = ItemList.new()
	_library_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_box.add_child(_library_list)
	_library_list.item_activated.connect(_activate_library)
	_library_status = _label(library_box, "", 14)
	var page_buttons := HBoxContainer.new()
	library_box.add_child(page_buttons)
	_library_previous = _button(page_buttons, "SY_PREVIOUS", func() -> void:
		_library_page_index -= 1
		_start_library_page())
	_library_next = _button(page_buttons, "SY_NEXT", func() -> void:
		if _library_offsets.size() == _library_page_index + 1: _library_offsets.append(_library_page.next_offset)
		_library_page_index += 1
		_start_library_page())
	_button(library_box, "SY_USE", func() -> void:
		if not _library_list.get_selected_items().is_empty(): _activate_library(_library_list.get_selected_items()[0]))
	_button(library_box, "SY_CLOSE", func() -> void: _library.hide())

func _sidebar(parent: Node, node_name: String, width: int) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.custom_minimum_size.x = width
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 9)
	scroll.add_child(box)
	return box

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	if not text.is_empty(): _bind_text(label, "text", text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	_bind_text(button, "text", text)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func new_template(role: String) -> void:
	blueprint = Ship.template(role)
	selected = 0
	dirty = false
	current_path = ""
	history.clear()
	_rename_open = false
	_search.text = ""
	_category.select(0)
	_side.select(0)
	_placement_yaw.select(0)
	_symmetry.set_pressed_no_signal(false)
	_preview_toggle.set_pressed_no_signal(false)
	_reset_sidebars()
	_fill_catalog()
	_refresh()
	frame_design.call_deferred()
	_set_status("SY_TEMPLATE_OPEN")

func _fill_catalog() -> void:
	if blueprint.is_empty(): return
	var previous: String = ""
	if not _catalog.get_selected_items().is_empty() and not _module_ids.is_empty(): previous = _module_ids[_catalog.get_selected_items()[0]]
	_catalog.clear()
	_module_ids.clear()
	for id: String in _definitions:
		if _definitions[id].role not in ["both", blueprint.ship.role]: continue
		if not _search.text.strip_edges().is_empty() and not (Present.module_name(id) + " " + _definitions[id].name).to_lower().contains(_search.text.strip_edges().to_lower()): continue
		if _category.selected > 0 and _definitions[id].category != Present.CATEGORIES[_category.selected]: continue
		_module_ids.append(id)
		_catalog.add_item(Present.module_name(id))
		_catalog.set_item_tooltip(_catalog.item_count - 1, Present.module_details(_definitions[id]))
	if _catalog.item_count > 0: _catalog.select(maxi(_module_ids.find(previous), 0))
	if _ghost != null: _update_preview()

func _catalog_selected(index: int) -> void:
	_set_status("SY_CATALOG_SELECTED", {"module_id": _module_ids[index]})
	_preview_toggle.set_pressed_no_signal(true)
	_update_preview()

func add_selected_module() -> void:
	if _catalog.get_selected_items().is_empty(): return
	add_module(_module_ids[_catalog.get_selected_items()[0]])

func add_module(id: String) -> void:
	var result: Dictionary = Placement.add_attached(blueprint, selected, id, _side.selected, _placement_yaw.selected * 90, _symmetry.button_pressed)
	if not result.ok:
		_error_status(result.code)
		return
	var previous: int = selected
	selected = result.added[0]
	if not _edit(result.blueprint, "SY_EDIT_PAIR" if result.added.size() == 2 else "SY_ADD"): selected = previous

func select_part(index: int) -> void:
	selected = index if index >= 0 and index < blueprint.parts.size() else -1
	_update_selection()
	_update_preview()

func _move_axis(axis: int, value: float) -> void:
	if _refreshing or selected < 0: return
	var candidate: Dictionary = blueprint.duplicate(true)
	var position: Vector3 = candidate.parts[selected].position
	position[axis] = value
	candidate.parts[selected].position = position
	_edit(candidate, "SY_EDIT_MOVE")

func rotate_part() -> void:
	if selected < 0: return
	var candidate: Dictionary = blueprint.duplicate(true)
	var rotation: Vector3 = candidate.parts[selected].rotation
	rotation.y = fposmod(rotation.y + 90, 360)
	candidate.parts[selected].rotation = rotation
	_edit(candidate, "SY_EDIT_ROTATE")

func mirror_part() -> void:
	var result: Dictionary = Placement.mirror(blueprint, selected)
	if not result.ok:
		_error_status(result.code)
		return
	selected = result.added[0]
	_edit(result.blueprint, "SY_MIRROR")

func remove_part() -> void:
	if selected < 0: return
	var candidate: Dictionary = blueprint.duplicate(true)
	Ship.Assembly.remove_part(candidate, selected)
	selected = mini(selected, candidate.parts.size() - 1)
	_edit(candidate, "SY_EDIT_REMOVE")

func _rename(value: String) -> void:
	if _refreshing: return
	if not _rename_open: history.push_state(blueprint, "SY_EDIT_RENAME")
	_rename_open = true
	blueprint.name = value
	dirty = true
	_undo_button.disabled = not history.can_undo()
	_redo_button.disabled = true
	_fit_pair.clear()
	_show_fit_report()
	_set_status("SY_NAME_REQUIRED" if value.strip_edges().is_empty() else "SY_NAME_PENDING")

func _edit(candidate: Dictionary, label: String) -> bool:
	var check: Dictionary = Ship.inspect(candidate)
	if not check.ok:
		_error_status(check.code)
		return false
	history.push_state(blueprint, label)
	_rename_open = false
	blueprint = candidate
	dirty = true
	_refresh()
	_set_status("SY_ACTION_PENDING", {"action_key": label})
	return true

func undo() -> void:
	if not history.can_undo(): return
	blueprint = history.undo(blueprint)
	_rename_open = false
	dirty = true
	selected = mini(selected, blueprint.parts.size() - 1)
	_refresh()

func redo() -> void:
	if not history.can_redo(): return
	blueprint = history.redo(blueprint)
	_rename_open = false
	dirty = true
	selected = mini(selected, blueprint.parts.size() - 1)
	_refresh()

func save_current() -> bool:
	if _is_imported_source():
		_set_status("SHIP_EXCHANGE_COPY_REQUIRED")
		return false
	var result: Dictionary = Ship.save_design(blueprint, current_path)
	if not result.ok:
		_error_status(result.code)
		return false
	current_path = result.path
	dirty = false
	_rename_open = false
	_refresh(false)
	_set_status("SY_SAVED" if _evaluation.ok else "SY_SAVED_DRAFT", {"name": blueprint.name, "revision": blueprint.revision})
	return true

func save_as_copy() -> bool:
	var result: Dictionary = Ship.save_copy(blueprint)
	if not result.ok:
		_error_status(result.code)
		return false
	blueprint = result.blueprint
	current_path = result.path
	dirty = false
	_rename_open = false
	history.clear()
	_refresh()
	_set_status("SY_COPY_SAVED", {"name": blueprint.name})
	return true

func load_path(path: String) -> bool:
	var result: Dictionary = Ship.load_design(path)
	if not result.ok:
		_error_status(result.code)
		return false
	blueprint = result.blueprint
	current_path = path
	history.clear()
	dirty = false
	selected = 0 if not blueprint.parts.is_empty() else -1
	_rename_open = false
	_reset_sidebars()
	_fill_catalog()
	_refresh()
	frame_design.call_deferred()
	_set_status("SY_OPENED", {"name": blueprint.name, "revision": blueprint.revision})
	return true

func _open_library() -> void:
	_show_library(false)

func _open_fit_library() -> void:
	_show_library(true)

func _show_library(for_fit: bool) -> void:
	_library.set_meta("for_fit", for_fit)
	_library.title = Text.text("SY_FIT_PICKER" if for_fit else "SY_LIBRARY")
	_library_offsets = [0]
	_library_page_index = 0
	_library_search.text = ""
	_library.popup_centered()
	_start_library_page()

func _start_library_page() -> void:
	_library_entries.clear()
	_library_list.clear()
	var role: String = ""
	if _library.get_meta("for_fit", false): role = "lander" if blueprint.ship.role == "expedition" else "expedition"
	_library_page.start(Ship.DIRECTORY, _library_search.text, role, _library_offsets[_library_page_index])
	_library_loading = true
	_library_previous.disabled = true
	_library_next.disabled = true
	_library_status.text = Text.text("SY_LIBRARY_LOADING")

func _finish_library_page() -> void:
	_library_loading = false
	_library_entries = _library_page.entries.duplicate(true)
	for entry: Dictionary in _library_entries:
		_library_list.add_item(Text.format_text("SY_LIBRARY_ENTRY", {"name": entry.name, "revision": entry.revision}) if entry.ok else Text.format_text("SY_LIBRARY_UNREADABLE", {"name": entry.name}))
		_library_list.set_item_tooltip(_library_list.item_count - 1, (entry.path if entry.ok else Present.error(entry.code) + "\n" + entry.path))
	_library_previous.disabled = _library_page_index <= 0
	_library_next.disabled = not _library_page.may_have_more
	_library_status.text = Text.format_text("SY_LIBRARY_PAGE", {"page": _library_page_index + 1, "count": _library_entries.size()}) if not _library_entries.is_empty() else Text.text("SY_LIBRARY_EMPTY")

func _activate_library(index: int) -> void:
	if _library_loading or index < 0 or index >= _library_entries.size(): return
	var path: String = _library_entries[index].path
	_library.hide()
	if _library.get_meta("for_fit", false):
		var other: Dictionary = Ship.load_design(path)
		if not other.ok:
			_error_status(other.code)
			return
		var host: Dictionary = blueprint if blueprint.ship.role == "expedition" else other.blueprint
		var guest: Dictionary = other.blueprint if blueprint.ship.role == "expedition" else blueprint
		_fit_pair.assign([host.duplicate(true), guest.duplicate(true)])
		_show_fit_report()
		_reveal_fit.call_deferred()
	else:
		_guard(func() -> void: load_path(path))

func _reveal_fit() -> void:
	# Container layout follows text changes; scroll the completed report.
	await get_tree().process_frame
	if _fit_pair.is_empty(): return
	var scroll := _fit.get_parent().get_parent() as ScrollContainer
	if scroll != null: scroll.ensure_control_visible(_fit)

func _guard(action: Callable) -> void:
	if not dirty:
		action.call()
		return
	_pending_action = action
	_confirmation.dialog_text = Text.text("SY_SAVE_QUESTION")
	_confirmation.popup_centered()

func _discard_continue() -> void:
	var action: Callable = _pending_action
	_pending_action = Callable()
	if action.is_valid(): action.call()

func _refresh(geometry_changed: bool = true) -> void:
	_refreshing = true
	if _name_field.text != blueprint.name: _name_field.text = blueprint.name
	if geometry_changed or _evaluation.is_empty():
		_evaluation = Ship.evaluate(blueprint)
		evaluation_count += 1
		_assembler.configure(blueprint, _definitions, -1)
		mesh_build_count += 1
		_fit_pair.clear()
		_show_fit_report()
	_refresh_installed()
	var result: Dictionary = _evaluation
	if not result.stats.is_empty():
		var stats: Dictionary = result.stats
		_stats.text = Text.format_text("SY_STATS", {
			"role": Present.role_name(blueprint.ship.role), "modules": blueprint.parts.size(), "limit": Ship.MAX_MODULES,
			"size": Present.dimensions(result.bounds.size), "mass": stats.mass, "thrust": stats.thrust,
			"power": stats.power, "draw": stats.draw, "energy": stats.energy, "cargo": stats.cargo,
			"seats": stats.seats, "research": stats.research, "bays": result.bays.size(), "cost": stats.cost})
	_issues.clear()
	_issue_details.text = Text.text("SY_ISSUE_HINT") if not result.ok else ""
	_issue_count.text = Text.format_text("SY_ISSUE_COUNT", {"count": result.issues.size()}) if not result.ok else ""
	if result.ok:
		_issues.add_item(Text.text("SY_VALID"))
		_issues.set_item_custom_fg_color(0, Color("88d6aa"))
	else:
		for issue: Dictionary in result.issues:
			var text: String = Present.issue_summary(issue, blueprint)
			_issues.add_item(text)
			_issues.set_item_tooltip(_issues.item_count - 1, Present.issue_details(issue, blueprint))
			_issues.set_item_metadata(_issues.item_count - 1, issue)
			_issues.set_item_custom_fg_color(_issues.item_count - 1, Color("ee9c88"))
	_undo_button.disabled = not history.can_undo()
	_redo_button.disabled = not history.can_redo()
	_refreshing = false
	_update_selection()
	_update_preview()
	_request_render()

func _update_selection() -> void:
	if selected >= blueprint.parts.size(): selected = -1
	for button: Button in _selection_actions: button.disabled = selected < 0
	_selection_outline.visible = selected >= 0
	if selected >= 0:
		_installed.select(selected)
		var part: Dictionary = blueprint.parts[selected]
		_module_title.text = "#%02d %s" % [selected + 1, Present.module_name(part.part_id)]
		_module_details.text = Present.module_details(_definitions[part.part_id], part)
		for axis in range(3):
			_position_fields[axis].editable = true
			_position_fields[axis].set_value_no_signal(part.position[axis])
		_selection_outline.mesh = _wire_box(Ship.module_box(part, _definitions[part.part_id]).grow(0.04))
	else:
		_installed.deselect_all()
		_module_title.text = Text.text("SY_NONE")
		_module_details.text = ""
		for field: SpinBox in _position_fields: field.editable = false
	_request_render()

func _update_preview() -> void:
	if _ghost == null or blueprint.is_empty(): return
	_ghost.visible = false
	_add_button.disabled = true
	if _catalog.get_selected_items().is_empty():
		_catalog_details.text = Text.text("SY_NO_MODULES")
		_placement_label.text = Text.text("SY_NO_MODULES")
		_request_render()
		return
	var id: String = _module_ids[_catalog.get_selected_items()[0]]
	_catalog_details.text = Present.module_name(id) + "\n" + Present.module_details(_definitions[id])
	var proposal: Dictionary = Placement.plan(blueprint, selected, id, _side.selected, _placement_yaw.selected * 90, _symmetry.button_pressed)
	_add_button.disabled = not proposal.ok
	_placement_label.text = Text.format_text("SY_PLACEMENT_FREE", {"count": proposal.placements.size()}) if proposal.ok else Text.format_text("SY_PLACEMENT_BLOCKED", {"error": Present.error(proposal.code)})
	_placement_label.modulate = Color("88d6aa") if proposal.ok else Color("ee9c88")
	if _preview_toggle.button_pressed and not proposal.placements.is_empty():
		_ghost.mesh = MeshBuilder.build_mesh({"parts": proposal.placements}, _definitions)
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.35, 1.0, 0.65, 0.38) if proposal.ok else Color(1.0, 0.3, 0.2, 0.45)
		_ghost.material_override = material
		_ghost.visible = true
	_request_render()

func _wire_box(box: AABB) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffd078")
	material.no_depth_test = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for index in range(8):
		var corner: Vector3 = box.position + Vector3(1 if index & 1 else 0, 1 if index & 2 else 0, 1 if index & 4 else 0) * box.size
		for bit in [1, 2, 4]:
			var other: int = index ^ bit
			if index < other:
				mesh.surface_add_vertex(corner)
				mesh.surface_add_vertex(box.position + Vector3(1 if other & 1 else 0, 1 if other & 2 else 0, 1 if other & 4 else 0) * box.size)
	mesh.surface_end()
	return mesh

func _request_render() -> void:
	if _viewport != null:
		_viewport.size = Vector2i(maxi(int(_viewport_container.size.x), 2), maxi(int(_viewport_container.size.y), 2))
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _reset_sidebars() -> void:
	for control: Control in [_catalog, _stats]:
		var scroll := control.get_parent().get_parent() as ScrollContainer
		if scroll != null: scroll.scroll_vertical = 0

func _select_issue(index: int) -> void:
	var issue: Variant = _issues.get_item_metadata(index)
	if not issue is Dictionary: return
	_issue_details.text = Present.issue_details(issue, blueprint)
	if not issue.parts.is_empty(): select_part(issue.parts[0])
	var scroll := _issue_details.get_parent().get_parent() as ScrollContainer
	if scroll != null: scroll.ensure_control_visible(_issue_details)

func frame_design() -> void:
	var result: Dictionary = _evaluation
	if result.is_empty(): return
	if result.bounds.size.is_zero_approx(): return
	_target = result.bounds.get_center()
	var aspect: float = maxf(_viewport_container.size.x / maxf(_viewport_container.size.y, 1), 0.3)
	_distance = maxf(result.bounds.size.length() * 1.4 / minf(aspect, 1), 15)
	_camera.size = maxf(result.bounds.size.length() / minf(aspect, 1), 10)
	_update_camera()

func set_view(view: String) -> void:
	# Accept historical callers while buttons use language-independent IDs.
	view = {"Perspektive": "perspective", "Oben": "top", "Vorne": "front", "Seite": "side"}.get(view, view)
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE if view == "perspective" else Camera3D.PROJECTION_ORTHOGONAL
	match view:
		"top":
			_yaw = 0
			_pitch = PI * 0.5 - 0.001
		"front":
			_yaw = PI
			_pitch = 0
		"side":
			_yaw = PI * 0.5
			_pitch = 0
		_:
			_yaw = 0.65
			_pitch = 0.42
	frame_design()

func _view_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.006, -1.2, 1.3)
		_update_camera()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		var units: float = (_distance if _camera.projection == Camera3D.PROJECTION_PERSPECTIVE else _camera.size) / maxf(_viewport_container.size.y, 1)
		_target += (-_camera.basis.x * event.relative.x + _camera.basis.y * event.relative.y) * units
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_distance = clampf(_distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 5, 700)
			_camera.size = clampf(_camera.size * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 3, 400)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var origin: Vector3 = _camera.project_ray_origin(event.position)
			var direction: Vector3 = _camera.project_ray_normal(event.position)
			var best: float = INF
			var hit_index: int = -1
			for index in range(blueprint.parts.size()):
				var part: Dictionary = blueprint.parts[index]
				var hit: Variant = Ship.module_box(part, _definitions[part.part_id]).intersects_ray(origin, direction)
				if hit is Vector3 and origin.distance_to(hit) < best:
					best = origin.distance_to(hit)
					hit_index = index
			select_part(hit_index)

func _update_camera() -> void:
	_camera.position = _target + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.look_at(_target)
	_request_render()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if get_tree().paused or _library.visible or _confirmation.visible or (_exchange_dialog != null and _exchange_dialog.visible): return
	var text_focus: Control = get_viewport().gui_get_focus_owner()
	var editing_text: bool = text_focus is LineEdit or text_focus is TextEdit
	if event.ctrl_pressed and event.keycode == KEY_S:
		if event.shift_pressed: save_as_copy()
		else: save_current()
	elif editing_text: return
	elif event.ctrl_pressed and event.keycode == KEY_Z:
		if event.shift_pressed: redo()
		else: undo()
	elif event.ctrl_pressed and event.keycode == KEY_Y: redo()
	elif event.keycode == KEY_DELETE: remove_part()
	elif event.keycode == KEY_R: rotate_part()
	elif event.keycode == KEY_F: frame_design()
	else: return
	get_viewport().set_input_as_handled()

func _resize_columns() -> void:
	# Sidebars scroll vertically; keep the 3D view usable at smaller windows.
	var columns: Node = find_child("Columns", true, false)
	if columns == null: return
	columns.get_node("Modules").custom_minimum_size.x = 180 if size.x < 1050 else 220
	columns.get_node("Inspector").custom_minimum_size.x = 240 if size.x < 1050 else 280

func _add_grid() -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("284355")
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for step in range(-100, 101, 5):
		mesh.surface_add_vertex(Vector3(step, -8, -100))
		mesh.surface_add_vertex(Vector3(step, -8, 100))
		mesh.surface_add_vertex(Vector3(-100, -8, step))
		mesh.surface_add_vertex(Vector3(100, -8, step))
	mesh.surface_end()
	var grid := MeshInstance3D.new()
	grid.mesh = mesh
	_world.add_child(grid)

func _dimensions(value: Vector3) -> String:
	return Present.dimensions(value)

func _bind_text(control: Node, property: String, key: String) -> void:
	control.set_meta("shipyard_text_property", property)
	control.set_meta("shipyard_text_key", key)
	control.set(property, Text.text(key))

func _translate_bound(node: Node) -> void:
	if node.has_meta("shipyard_text_key"):
		node.set(node.get_meta("shipyard_text_property"), Text.text(node.get_meta("shipyard_text_key")))
	for child: Node in node.get_children(): _translate_bound(child)

func _set_status(key: String, values: Dictionary = {}) -> void:
	_status_key = key
	_status_values = values.duplicate(true)
	_status_code = ""
	_show_status()

func _error_status(code: String) -> void:
	_status_code = code
	_status_key = ""
	_show_status()

func _show_status() -> void:
	if not _status_code.is_empty():
		_status.text = Present.error(_status_code)
		return
	var values: Dictionary = _status_values.duplicate(true)
	if values.has("action_key"): values["action"] = Text.text(values.action_key)
	if values.has("module_id"): values["module"] = Present.module_name(values.module_id)
	_status.text = Text.format_text(_status_key, values) if not _status_key.is_empty() else ""

func _refresh_installed() -> void:
	var scroll: float = _installed.get_v_scroll_bar().value
	_installed.clear()
	for index in range(blueprint.parts.size()):
		_installed.add_item("%02d  %s" % [index + 1, Present.module_name(blueprint.parts[index].part_id)])
	_installed.get_v_scroll_bar().set_deferred("value", scroll)

func _show_fit_report() -> void:
	if _fit_pair.is_empty():
		_fit.text = Text.text("SY_FIT_HINT")
		_fit.modulate = Color.WHITE
		return
	var report: Dictionary = Present.hangar_report(_fit_pair[0], _fit_pair[1])
	_fit.text = report.text
	_fit.modulate = Color("88d6aa") if report.ok else Color("ee9c88")

func _retranslate() -> void:
	_translate_bound(self)
	if blueprint.is_empty(): return
	for index in range(Present.CATEGORY_KEYS.size()): _category.set_item_text(index, Text.text(Present.CATEGORY_KEYS[index]))
	for index in range(6): _side.set_item_text(index, Text.text("SY_SIDE_%d" % index))
	for index in range(4): _placement_yaw.set_item_text(index, Text.format_text("SY_YAW", {"yaw": index * 90}))
	var issue_selection := _issues.get_selected_items()
	_fill_catalog()
	_refresh(false)
	if not issue_selection.is_empty() and issue_selection[0] < _issues.item_count:
		_issues.select(issue_selection[0])
		_select_issue(issue_selection[0])
	_show_fit_report()
	if not _fit_pair.is_empty(): _reveal_fit.call_deferred()
	_show_status()
	_library.title = Text.text("SY_FIT_PICKER" if _library.get_meta("for_fit", false) else "SY_LIBRARY")
	if not _library_loading:
		var selection := _library_list.get_selected_items()
		_library_list.clear()
		_finish_library_page()
		if not selection.is_empty() and selection[0] < _library_list.item_count: _library_list.select(selection[0])
	_confirmation.dialog_text = Text.text("SY_SAVE_QUESTION")
	if _exchange_dialog != null:
		_exchange_dialog.title = Text.text("SHIP_EXCHANGE_EXPORT" if _exchange_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE else "SHIP_EXCHANGE_IMPORT")


## Export the committed revision; the player's working edits remain distinct.
func export_portable_design(destination: String, metadata: Dictionary = {}) -> Dictionary:
	if dirty or current_path.is_empty():
		return {"ok": false, "code": "ship_exchange.unsaved_design"}
	return DesignExchange.export_file(current_path, destination, metadata)


## Installing a received revision leaves the open draft and fleet untouched.
func import_portable_design(source: String) -> Dictionary:
	return DesignExchange.import_file(source)


func _is_imported_source() -> bool:
	return current_path.get_file().begins_with("import_")


func _show_exchange_dialog(exporting: bool) -> void:
	if exporting and (dirty or current_path.is_empty()):
		_set_status("SHIP_EXCHANGE_UNSAVED_DESIGN")
		return
	if _exchange_dialog == null:
		_exchange_dialog = FileDialog.new()
		_exchange_dialog.name = "ShipExchangeDialog"
		_exchange_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_exchange_dialog.filters = PackedStringArray(["*.json ; JSON"])
		_exchange_dialog.file_selected.connect(_exchange_file_selected)
		add_child(_exchange_dialog)
	_exchange_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if exporting else FileDialog.FILE_MODE_OPEN_FILE
	_exchange_dialog.title = Text.text("SHIP_EXCHANGE_EXPORT" if exporting else "SHIP_EXCHANGE_IMPORT")
	if exporting: _exchange_dialog.current_file = "ship-design.json"
	_exchange_dialog.popup_centered(Vector2i(640, 420))


func _exchange_file_selected(path: String) -> void:
	var exporting: bool = _exchange_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE
	var result: Dictionary = export_portable_design(path) if exporting else import_portable_design(path)
	if not result.ok:
		_set_status("SHIP_EXCHANGE_FAILED", {"code": result.code})
		return
	_set_status("SHIP_EXCHANGE_EXPORTED" if exporting else ("SHIP_EXCHANGE_ALREADY_PRESENT" if result.code == "already_present" else "SHIP_EXCHANGE_IMPORTED"))
