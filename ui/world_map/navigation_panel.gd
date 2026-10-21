extends VBoxContainer
const State = preload("res://core/map/navigation_state.gd")
const Style = preload("res://ui/frontend/menu_style.gd")
const Symbols = preload("res://ui/design/game_symbols.gd")
const Text = preload("res://core/localization/ui_text.gd")
signal add_here
signal add_center
signal selected(id: String)
signal rename_requested(id: String, title: String)
signal removed(id: String)
signal tracked(id: String)
signal stopped
var selected_id: String = ""
var _list: VBoxContainer
var _title: Label
var _name: LineEdit
var _target: Label
var _message: Label
var _empty: Label
var _stop: Button
var _here: Button
var _center: Button
var _rename: Button
var _remove: Button
var _track: Button
var _row_signature: Array = []
var _can_edit: bool = false
var _saved_name: String = ""
var _editing_id: String = ""

func select_waypoint(id: String) -> void:
	selected_id = id
	_editing_id = ""

func _ready() -> void:
	name = "AtlasNavigationPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	_title = Style.label(self, "NAV_WAYPOINTS", 22)
	_target = Style.paragraph(self, "", 16)
	_target.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_target.max_lines_visible = 2
	_message = Style.paragraph(self, "", 16)
	_message.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_message.hide()
	_stop = _button(self, "NAV_STOP", func() -> void: stopped.emit(), "NavigationStop")
	var actions := HFlowContainer.new()
	add_child(actions)
	_here = _button(actions, "NAV_HERE", func() -> void: add_here.emit(), "NavigationHere")
	_center = _button(actions, "NAV_MAP_CENTER", func() -> void: add_center.emit(), "NavigationCenter")
	_center.tooltip_text = "NAV_CENTER_HELP"
	var scroll := ScrollContainer.new()
	scroll.name = "NavigationScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 60
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_empty = Style.paragraph(self, "NAV_EMPTY", 16)
	_name = LineEdit.new()
	_name.name = "WaypointName"
	_name.max_length = State.NAME_LIMIT
	_name.placeholder_text = "NAV_NAME"
	_name.text_submitted.connect(func(value: String) -> void:
		if not _rename.disabled: rename_requested.emit(selected_id, value))
	_name.text_changed.connect(func(_value: String) -> void: _update_name_action())
	add_child(_name)
	var editing := HFlowContainer.new()
	add_child(editing)
	_track = _button(editing, "NAV_TRACK", func() -> void: tracked.emit(selected_id), "NavigationTrack")
	_rename = _button(editing, "NAV_RENAME", func() -> void: rename_requested.emit(selected_id, _name.text), "NavigationRename")
	_remove = _button(editing, "NAV_DELETE", func() -> void: removed.emit(selected_id), "NavigationDelete")

func _button(parent: Node, key: String, action: Callable, id: String) -> Button:
	var button := Button.new()
	button.name = id
	button.text = key
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func refresh(body: Dictionary, target_name: String, editable: bool, message: String = "") -> void:
	var record: Dictionary = State.view(body)
	var points: Dictionary = record.get("waypoints", {})
	_can_edit = editable
	if not points.has(selected_id): selected_id = ""
	_title.text = Text.format_text("NAV_COUNT", {"count": points.size(), "limit": State.CAPACITY})
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_target.text = Text.text("NAV_NO_TARGET") if target_name.is_empty() else Text.format_text("NAV_CURRENT_TARGET", {"name": target_name})
	_message.text = message
	_message.visible = not message.is_empty()
	_stop.disabled = not editable or record.get("target", {}).is_empty()
	_here.disabled = not editable or points.size() >= State.CAPACITY
	_center.disabled = _here.disabled
	_empty.visible = points.is_empty()
	var signature: Array = []
	for id: String in points:
		signature.append([id, points[id].name, id == selected_id])
	if signature != _row_signature:
		_row_signature = signature
		for child: Node in _list.get_children(): _list.remove_child(child); child.queue_free()
		for id: String in points:
			var point: Dictionary = points[id]
			var button := _button(_list, point.name, func() -> void: selected.emit(id), "Waypoint_" + str(_list.get_child_count()))
			button.set_meta("waypoint_id", id)
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.toggle_mode = true
			button.button_pressed = id == selected_id
			Symbols.apply(button, "pin", 18)
	_name.editable = editable and not selected_id.is_empty()
	var saved_name: String = str(points.get(selected_id, {}).get("name", ""))
	# A live map refresh must not discard a draft when focus moves from its
	# LineEdit to the Rename button. Explicit pin selection resets the draft.
	if selected_id != _editing_id or (not _name.has_focus() and _name.text == _saved_name): _name.text = saved_name
	_editing_id = selected_id
	_saved_name = saved_name
	for button in [_track, _rename, _remove]: button.disabled = not editable or selected_id.is_empty()
	_track.disabled = _track.disabled or record.get("target", {}) == {"kind": "waypoint", "id": selected_id}
	_update_name_action()

func _update_name_action() -> void:
	if _rename == null: return
	var name: String = State.clean_name(_name.text)
	_rename.disabled = not _can_edit or selected_id.is_empty() or name.is_empty() or name == _saved_name

func editing_name() -> bool:
	return _name.has_focus()
