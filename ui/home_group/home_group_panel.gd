extends CanvasLayer

const Text = preload("res://core/localization/ui_text.gd")
const Presentation = preload("res://ui/home_group/home_group_presentation.gd")

var controller: Node
var is_open: bool = false
var _owns_pause: bool = false
var _closing: bool = false
var _previous_mouse: int
var _previous_focus: WeakRef
var _surface: Control
var _list: VBoxContainer
var _message: Label
var _summary: Label
var _hud: Label
var _establish: Button
var _close: Button
var _last_result: Dictionary = {}
var _font_scale: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 45
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_N or event.physical_keycode == KEY_N):
		if not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and not get_tree().paused and open_panel():
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not is_open or not event is InputEventKey:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key in [KEY_ESCAPE, KEY_N]:
		if event.pressed and not event.echo:
			close_panel()
		get_viewport().set_input_as_handled()
	elif key in [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12, KEY_K, KEY_J, KEY_P]:
		get_viewport().set_input_as_handled()

func open_panel() -> bool:
	if is_open or _closing or get_tree().paused or not controller.can_use_panel():
		return false
	_previous_mouse = Input.mouse_mode
	_previous_focus = weakref(get_viewport().gui_get_focus_owner())
	is_open = true
	_owns_pause = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_surface.show()
	_last_result = {}
	_message.text = ""
	_refresh_members()
	_close.grab_focus()
	return true

func close_panel() -> void:
	if not is_open:
		return
	is_open = false
	_closing = true
	_surface.hide()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_release_pause()
	_closing = false

func _release_pause() -> void:
	if _owns_pause:
		_owns_pause = false
		get_tree().paused = false
		Input.mouse_mode = _previous_mouse
		var old: Control = _previous_focus.get_ref() if _previous_focus != null else null
		if is_instance_valid(old) and old.is_visible_in_tree():
			old.grab_focus()

func _exit_tree() -> void:
	if _owns_pause and get_tree() != null:
		_release_pause()

func _build() -> void:
	_hud = Label.new()
	_hud.text = Text.text("HOME_HUD")
	_hud.set_meta("home_font_size", 16)
	_hud.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_theme_font_size_override("font_size", 16)
	_hud.add_theme_color_override("font_color", Color(1, 0.91, 0.67))
	_hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hud.add_theme_constant_override("shadow_offset_x", 1)
	_hud.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_hud)
	_surface = Control.new()
	add_child(_surface)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.045, 0.04, 0.94)
	_surface.add_child(shade)
	var center := CenterContainer.new()
	center.name = "Centre"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(690, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.11, 0.10)
	style.border_color = Color(0.50, 0.63, 0.45)
	style.set_border_width_all(2)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	stack.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)
	var title := _label("HOME_TITLE", 28)
	title.add_theme_color_override("font_color", Color(1, 0.87, 0.53))
	content.add_child(title)
	_summary = _label("", 18)
	content.add_child(_summary)
	_summary.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_establish = _button("HOME_ESTABLISH", func() -> void: _result(controller.establish_home()))
	_establish.name = "EstablishHome"
	_establish.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	content.add_child(_establish)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	content.add_child(_list)
	_message = _label("", 17)
	_message.name = "Result"
	_message.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	content.add_child(_message)
	content.add_child(_label("HOME_REST_HINT", 16))
	_close = _button("HOME_CLOSE", close_panel)
	_close.name = "CloseHome"
	stack.add_child(_close)
	_surface.hide()

func _layout() -> void:
	# The game's 1920-wide stretch canvas otherwise reduces menu text below
	# readable sizes in smaller windows. Keep this layer in window-sized units.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size: Vector2 = Vector2(get_window().size)
	var factor: float = viewport_size.x / maxf(window_size.x, 1.0)
	transform = Transform2D(0.0, Vector2.ONE * factor, 0.0, Vector2.ZERO)
	var size: Vector2 = viewport_size / factor
	_font_scale = clampf(float(get_node("/root/DisplaySettings").ui_scale), 1.0, 1.5)
	_apply_fonts(self)
	_surface.size = size
	var panel: Control = _surface.get_node("Centre/Panel")
	panel.custom_minimum_size.x = maxf(280, minf(730 * _font_scale, size.x - 40))
	var scroll: Control = panel.get_node("Stack/Scroll")
	scroll.custom_minimum_size.y = minf(520 * _font_scale, maxf(100, size.y - 100 - 42 * _font_scale))
	_hud.position = Vector2(24, maxf(24, size.y - 82 * _font_scale))
	_hud.size.x = minf(700 * _font_scale, size.x - 48)

func _refresh_members() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var group: Dictionary = controller.group_state()
	_refresh_texts()
	if not str(controller.problem).is_empty() or group.is_empty():
		_surface.get_node("Centre/Panel/Stack/Scroll").scroll_vertical = 0
		return
	_add_order_row(Text.text("HOME_ALL"), "")
	for member: Dictionary in group["members"]:
		_add_order_row(Presentation.member_text(member), str(member["id"]))
	_layout()

func _add_order_row(title: String, identity: String) -> void:
	var label := _label(title, 18)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.set_meta("home_member_id", identity)
	_list.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_list.add_child(row)
	for order in ["follow", "wait", "home"]:
		var text: String = Presentation.ORDER_KEYS[order]
		var button := _button(text, func() -> void: _result(controller.issue_order(order, identity)))
		button.name = order.capitalize() + ("All" if identity.is_empty() else "Member")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)

func _result(result: Dictionary) -> void:
	_last_result = result.duplicate(true)
	_message.text = Presentation.result_text(_last_result)
	_message.add_theme_color_override("font_color", Color(0.70, 0.91, 0.61) if result.get("ok", false) else Color(1, 0.64, 0.48))
	_refresh_members()
	_close.grab_focus()

func refresh_status() -> void:
	_hud.visible = controller.can_use_panel() and not is_open
	if not controller.problem.is_empty():
		_hud.text = Text.text("HOME_HUD_INVALID")
		return
	var group: Dictionary = controller.group_state()
	if group.is_empty():
		_hud.text = Text.text("HOME_HUD")
		return
	var distance: float = controller.player.global_position.distance_to(controller.home_position())
	var waiting: int = 0
	for actor in controller.actors.values():
		if is_instance_valid(actor) and actor.status_code in ["blocked", "unloaded"]:
			waiting += 1
	_hud.text = Presentation.hud_text(distance, waiting, group.members.size())

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.set_meta("home_font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.set_meta("home_font_size", 18)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.21, 0.17)
	normal.border_color = Color(0.32, 0.44, 0.33)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.34, 0.24)
	hover.border_color = Color(0.65, 0.76, 0.48)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color(1, 0.85, 0.48)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(5)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	return button

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		call_deferred("_refresh_language")

func _refresh_language() -> void:
	if not is_instance_valid(controller): return
	# Keep the existing rows and actors; language changes issue no commands.
	_refresh_texts()
	refresh_status()
	_layout()

func _refresh_texts() -> void:
	var group: Dictionary = controller.group_state()
	_establish.text = Text.text("HOME_ESTABLISH" if group.is_empty() else "HOME_RELOCATE")
	_establish.disabled = not str(controller.problem).is_empty()
	_summary.text = Text.text("HOME_EMPTY" if group.is_empty() else "HOME_SUMMARY")
	if not str(controller.problem).is_empty():
		_summary.text = Presentation.result_text({"code": controller.problem_code})
	_message.text = Presentation.result_text(_last_result)
	# Invalid saved data is already explained in the summary above the actions.
	_message.visible = not _last_result.is_empty() and _last_result.get("code", "") != controller.problem_code
	if not controller.problem.is_empty(): return
	for label: Node in _list.get_children():
		if not label.has_meta("home_member_id"): continue
		var identity: String = label.get_meta("home_member_id")
		if identity.is_empty():
			label.text = Text.text("HOME_ALL")
		else:
			var member: Dictionary = controller.member_record(identity)
			if not member.is_empty(): label.text = Presentation.member_text(member)

func _apply_fonts(node: Node) -> void:
	if node.has_meta("home_font_size"):
		node.add_theme_font_size_override("font_size", roundi(float(node.get_meta("home_font_size")) * _font_scale))
		if node is Button: node.custom_minimum_size.y = 42 * _font_scale
	for child in node.get_children(): _apply_fonts(child)
