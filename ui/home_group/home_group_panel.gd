extends CanvasLayer

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
	_hud.text = "Heimat & Gruppe · N"
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
	stack.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)
	var title := _label("HEIMAT & GRUPPE", 28)
	title.add_theme_color_override("font_color", Color(1, 0.87, 0.53))
	content.add_child(title)
	_summary = _label("", 18)
	content.add_child(_summary)
	_establish = _button("Heimat hier gründen", func() -> void: _result(controller.establish_home()))
	_establish.name = "EstablishHome"
	content.add_child(_establish)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	content.add_child(_list)
	_message = _label("", 17)
	_message.name = "Result"
	content.add_child(_message)
	content.add_child(_label("Am Heimatplatz erholst du dich langsam, solange du genug gegessen und getrunken hast. Deine Gefährten gehen zu Fuß und warten vor unpassierbaren Wegen.", 16))
	_close = _button("Zurück zum Spiel · N / Esc", close_panel)
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
	_surface.size = size
	var panel: Control = _surface.get_node("Centre/Panel")
	panel.custom_minimum_size.x = maxf(280, minf(730, size.x - 40))
	var scroll: Control = panel.get_node("Stack/Scroll")
	scroll.custom_minimum_size.y = minf(520, maxf(100, size.y - 160))
	_hud.position = Vector2(24, maxf(24, size.y - 82))

func _refresh_members() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var group: Dictionary = controller.group_state()
	_establish.text = "Heimat hier gründen" if group.is_empty() else "Heimat an diesen Ort verlegen"
	_establish.disabled = not str(controller.problem).is_empty()
	_summary.text = "Gründe auf einer freien, trockenen Fläche eine Nestgruppe mit zwei Gefährten deiner Spezies." if group.is_empty() else "Zwei Gefährten deiner Spezies · Änderungen werden sofort gespeichert."
	if not str(controller.problem).is_empty():
		_summary.text = str(controller.problem)
		return
	if group.is_empty():
		return
	_add_order_row("Alle Gefährten", "")
	for member in group["members"]:
		var order: String = {"follow": "Folgen", "wait": "Warten", "home": "Heimkehren"}[member["order"]]
		_add_order_row(str(member["name"]) + " · " + order, str(member["id"]))

func _add_order_row(title: String, identity: String) -> void:
	_list.add_child(_label(title, 18))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_list.add_child(row)
	for order in ["follow", "wait", "home"]:
		var text: String = {"follow": "Folgen", "wait": "Warten", "home": "Heimkehren"}[order]
		var button := _button(text, func() -> void: _result(controller.issue_order(order, identity)))
		button.name = order.capitalize() + ("All" if identity.is_empty() else "Member")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)

func _result(result: Dictionary) -> void:
	_message.text = str(result.get("message", ""))
	_message.add_theme_color_override("font_color", Color(0.70, 0.91, 0.61) if result.get("ok", false) else Color(1, 0.64, 0.48))
	_refresh_members()
	_close.grab_focus()

func refresh_status() -> void:
	_hud.visible = controller.can_use_panel() and not is_open
	if not controller.problem.is_empty():
		_hud.text = "Heimat & Gruppe · N · gespeicherten Stand prüfen"
		return
	var group: Dictionary = controller.group_state()
	if group.is_empty():
		_hud.text = "Heimat & Gruppe · N"
		return
	var distance: float = controller.player.global_position.distance_to(controller.home_position())
	var waiting: int = 0
	for actor in controller.actors.values():
		if is_instance_valid(actor) and actor.status in ["Weg blockiert", "Außerhalb der geladenen Umgebung"]:
			waiting += 1
	_hud.text = "Heimat: %d m · Gruppe: 2 · N%s" % [roundi(distance), " · %d warten am Weg" % waiting if waiting else ""]

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
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
