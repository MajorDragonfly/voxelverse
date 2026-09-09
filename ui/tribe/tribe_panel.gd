extends CanvasLayer
const Style = preload("res://ui/progression_style.gd")
const Model = preload("res://world/tribe/tribe_state.gd")

var controller: Node
var confirmation_open: bool = false
var entry: Button
var confirm: Button
var cancel: Button
var _shade: ColorRect
var _center: CenterContainer
var _dialog: PanelContainer
var _detail: Label
var _message: Label
var _hud: PanelContainer
var _stock: Label
var _goal: Label
var _supply: Label
var _residents: HFlowContainer
var _buttons: Dictionary = {}
var _previous_mouse: int = Input.MOUSE_MODE_CAPTURED
var _owns_pause: bool = false
var _selection: Panel
var _drag_start := Vector2.ZERO
var _dragging: bool = false
var _scale_factor: float = 1.0
var _resident_ids: Array = []
var _feedback: VBoxContainer
var _orders_scroll: ScrollContainer

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()

func _build() -> void:
	entry = Style.button("Stammeszeitalter …")
	entry.name = "TribalAgeEntry"
	add_child(entry)
	entry.pressed.connect(open_confirmation)
	_hud = PanelContainer.new()
	_hud.resized.connect(_place_hud)
	_hud.minimum_size_changed.connect(func() -> void: call_deferred("_layout"))
	_hud.add_theme_stylebox_override("panel", Style.box())
	add_child(_hud)
	var column := Style.column(_hud, 7)
	_stock = Style.label("", 22, Style.SOCIAL)
	column.add_child(_stock)
	_feedback = preload("res://ui/frontend/group_feedback.gd").new()
	_feedback.controller = controller
	column.add_child(_feedback)
	_message = _feedback.result
	_orders_scroll = ScrollContainer.new()
	_orders_scroll.name = "GroupOrdersScroll"
	_orders_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_orders_scroll.follow_focus = true
	column.add_child(_orders_scroll)
	column = Style.column(_orders_scroll, 7)
	_goal = Style.label("", 17)
	column.add_child(_goal)
	_supply = Style.label("", 16, Style.MUTED)
	column.add_child(_supply)
	_residents = HFlowContainer.new()
	column.add_child(_residents)
	var orders := HFlowContainer.new()
	column.add_child(orders)
	var all := Style.button("Alle auswählen")
	all.name = "SelectAll"
	orders.add_child(all)
	all.pressed.connect(controller.select_all)
	var titles: Dictionary = {"wood": "Holz sammeln", "stone": "Stein sammeln", "food": "Nahrung sammeln", "supply": "Versorgung sichern", "tool": "Werkzeug · 3 Holz / 2 Stein", "hut": "Hütte · 6 Holz / 3 Stein", "garden": "Wurzelgarten · 4 Holz / 1 Stein", "feed": "Jetzt essen", "wait": "Anhalten"}
	for order: String in titles:
		var button := Style.button(titles[order])
		button.name = "Order_" + order
		orders.add_child(button)
		button.pressed.connect(func() -> void: controller.issue_order(order))
		_buttons[order] = button
	_buttons["supply"].tooltip_text = "Dauerauftrag: Nahrung ernten und einlagern, bis zwölf Portionen vorrätig oder unterwegs sind. Danach am Dorfplatz warten und bei Bedarf weiterarbeiten."
	_buttons["garden"].tooltip_text = "Benötigt ein Steinwerkzeug. Baut die Wurzelfundstelle zum Garten aus. Alle 20 Spielsekunden wächst eine Wurzel nach, bis dort acht bereitliegen."
	column.add_child(Style.label("Linksklick / Rahmen: auswählen · Umschalt: Auswahl ändern · Rechtsklick: laufen oder sammeln · WASD: Kamera · Mausrad: Zoom · Leertaste: Pause", 15, Style.MUTED))
	_shade = ColorRect.new()
	_shade.color = Color(0.015, 0.025, 0.035, 0.78)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.add_child(_center)
	_dialog = PanelContainer.new()
	_dialog.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.SOCIAL, 28))
	_center.add_child(_dialog)
	var content := Style.column(_dialog, 18)
	content.add_child(Style.label("Ein neues Zeitalter beginnt", 30, Style.SOCIAL))
	_detail = Style.label("", 19)
	content.add_child(_detail)
	confirm = Style.button("Jetzt ins Stammeszeitalter fortschreiten")
	confirm.name = "ConfirmTribalAge"
	content.add_child(confirm)
	confirm.pressed.connect(_confirm)
	cancel = Style.button("In der Kreaturenphase bleiben", Style.MUTED)
	cancel.name = "CancelTribalAge"
	content.add_child(cancel)
	cancel.pressed.connect(cancel_confirmation)
	_selection = Panel.new()
	_selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection.add_theme_stylebox_override("panel", Style.box(Color(0.3, 0.8, 0.65, 0.12), Style.SOCIAL, 0))
	add_child(_selection)
	_selection.hide()
	_shade.hide()
	_hud.hide()

func _layout() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_scale_factor = viewport_size.x / maxf(float(get_window().size.x), 1.0)
	transform = Transform2D(0.0, Vector2.ONE * _scale_factor, 0.0, Vector2.ZERO)
	viewport_size /= _scale_factor
	entry.position = Vector2(viewport_size.x - 282, 76)
	entry.size = Vector2(260, 46)
	_orders_scroll.custom_minimum_size.y = minf(260.0, viewport_size.y * 0.36)
	_hud.size = Vector2(viewport_size.x - 36, 0)
	_place_hud()
	_shade.size = viewport_size
	_dialog.custom_minimum_size.x = minf(viewport_size.x - 48, 670)

func _place_hud() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_hud.position = Vector2(18, get_viewport().get_visible_rect().size.y / _scale_factor - _hud.size.y - 18)


func open_confirmation() -> bool:
	if confirmation_open or get_tree().paused or controller._active:
		return false
	var problem: String = controller.prepare_confirmation()
	_detail.text = "Du führst künftig die Gruppe aus der Übersicht. Deine Kreatur und ihre beiden Gefährten bleiben dieselben Mitglieder. Eure Spezies, Heimat, Beziehungen und gekauften Fähigkeiten bleiben erhalten.\n\nSammelt Material, stellt ein Steinwerkzeug her, baut Hütten und versorgt eure Bewohner. Der Wechsel wird gespeichert; die direkte Einzelsteuerung endet. Stammeskämpfe und Nachbarstämme folgen in einem weiteren Ausbau."
	confirm.disabled = not problem.is_empty()
	if not problem.is_empty():
		_detail.text = problem + "\n\nDer Wechsel beginnt erst, wenn du ihn hier ausdrücklich bestätigst."
	confirmation_open = true
	_previous_mouse = Input.mouse_mode
	_owns_pause = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_shade.show()
	entry.hide()
	_layout()
	(confirm if not confirm.disabled else cancel).grab_focus()
	return true

func cancel_confirmation() -> void:
	if not confirmation_open:
		return
	confirmation_open = false
	_shade.hide()
	controller._prepared.clear()
	controller._token = ""
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if controller._active else _previous_mouse
	refresh()

func _confirm() -> void:
	if not confirmation_open or confirm.disabled:
		return
	confirm.disabled = true
	var saves: Node = get_node("/root/SaveGameService")
	if saves.request_phase_transition(1, controller._token):
		cancel_confirmation()
	else:
		_detail.text = "Der Wechsel konnte nicht gespeichert werden. Du bleibst in der Kreaturenphase.\n\n" + saves.last_error
		cancel.text = "Zur Kreatur zurück"

func refresh() -> void:
	if entry == null:
		return
	entry.visible = not confirmation_open and not get_tree().paused and int(get_node("/root/GameState").current_phase) == 0 and is_instance_valid(controller.player)
	_hud.visible = controller._active and (not get_tree().paused or _owns_pause)
	if not controller._active:
		return
	var data: Dictionary = controller.village()
	if data.is_empty():
		return
	var stock: Dictionary = data["stock"]
	_stock.text = "STAMMESZEITALTER   ·   Holz %d / 48   Stein %d / 48   Nahrung %d / 48   ·   Schlafplätze %d / 3" % [stock["wood"], stock["stone"], stock["food"], int(data["huts"]) * 2]
	_supply.text = "Arbeitende Bewohner essen ab 40 % Sättigung selbstständig und setzen ihren Auftrag fort."
	if int(data["garden"]) == 1:
		_supply.text = "Wurzelgarten · %d erntereif · %s · Essenspausen erfolgen selbstständig." % [data["deposits"]["food"]["remaining"], "Garten gefüllt" if int(data["deposits"]["food"]["remaining"]) >= Model.GARDEN_CAPACITY else "Nächste Wurzel in %d s" % ceili(Model.GROW_SECONDS - float(data["growth"]))]
	_goal.text = "Erster Schritt: Bewohner auswählen und Holz, Stein und Nahrung einlagern."
	if int(data["tools"]) > 0:
		_goal.text = "Steinwerkzeug bereit · Baue zwei Hütten für deine drei Bewohner und versorge sie mit Nahrung."
	elif int(stock["wood"]) >= 3 and int(stock["stone"]) >= 2:
		_goal.text = "Material bereit · Weise Bewohner an, das erste Steinwerkzeug herzustellen."
	if not data["project"].is_empty():
		var kind: String = data["project"]["kind"]
		_goal.text = "%s · %d %% · Weitere Bewohner können mitarbeiten." % [{"tool": "Werkzeugherstellung", "hut": "Hüttenbau", "garden": "Gartenbau"}[kind], int(float(data["project"]["progress"]) / float(Model.WORK[kind]) * 100)]
	elif int(data["huts"]) == 2 and int(data["meals"]) >= 3:
		_goal.text = "Dein Dorf steht · Lege einen Wurzelgarten an und weise Bewohner dauerhaft der Versorgung zu." if int(data["garden"]) == 0 else "Dauerhafte Nahrung bereit · Versorgung sichern hält zwölf Portionen im Vorrat und nimmt die Arbeit bei Bedarf wieder auf."
	var identities: Array = data["members"].map(func(member: Dictionary) -> String: return str(member["id"]))
	if _resident_ids != identities:
		_resident_ids = identities
		for child: Node in _residents.get_children():
			_residents.remove_child(child)
			child.queue_free()
		for member: Dictionary in data["members"]:
			var button := Style.button("")
			button.toggle_mode = true
			button.name = "Resident_" + str(member["id"])
			button.pressed.connect(func() -> void: controller.select_member(member["id"], Input.is_key_pressed(KEY_SHIFT)))
			_residents.add_child(button)
	for i in range(data["members"].size()):
		var member: Dictionary = data["members"][i]
		var button: Button = _residents.get_child(i)
		var orders: Dictionary = {"wait": "wartet", "move": "unterwegs", "wood": "sammelt Holz", "stone": "sammelt Stein", "food": "sammelt Nahrung", "tool": "stellt Werkzeug her", "hut": "baut Hütte", "garden": "legt Garten an", "supply": "sichert Nahrung", "feed": "isst"}
		var activity: String = orders.get(member["order"], "Auftrag: " + str(member["order"]))
		if member["order"] == "supply" and controller._food_reserve_ready():
			activity = "Vorrat bereit · bleibt zuständig"
		elif member["order"] in ["supply", "food"] and int(data["garden"]) == 1 and int(data["deposits"]["food"]["remaining"]) == 0:
			activity = "wartet auf reife Wurzeln"
		if member["stage"] == "meal":
			activity = "Essenspause · kehrt zur Arbeit zurück"
		button.text = "%s · Sättigung %d %%\n%s" % [member["name"], roundi(float(member["hunger"])), "trägt Material" if member["cargo"] != "" else activity]
		button.set_pressed_no_signal(member["id"] in controller.selected)
	for order: String in _buttons:
		_buttons[order].disabled = controller.selected.is_empty() or get_tree().paused
	_feedback.refresh()
	_layout()

func _process(_delta: float) -> void:
	# Other modals own their pause. Never draw/capture input above the shared book.
	_hud.visible = controller._active and (not get_tree().paused or _owns_pause)
	if get_tree().paused and not _owns_pause:
		_dragging = false
		_selection.hide()


func _input(event: InputEvent) -> void:
	if _dragging:
		if not controller.is_active():
			_dragging = false
			_selection.hide()
		elif event is InputEventMouseMotion:
			var rect := Rect2(_drag_start, event.position - _drag_start).abs()
			_selection.position = rect.position / _scale_factor
			_selection.size = rect.size / _scale_factor
			_selection.show()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_finish_selection(event)
			get_viewport().set_input_as_handled()
			return
	if confirmation_open:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			cancel_confirmation()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and event.keycode not in [KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
		return
	if controller._active and (not get_tree().paused or _owns_pause) and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_tree().paused = not get_tree().paused
		_owns_pause = get_tree().paused
		refresh()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not controller.is_active():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start = event.position
				_dragging = true
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			controller.screen_command(event.position)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			controller.zoom(-2.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2.0)
		get_viewport().set_input_as_handled()

func _finish_selection(event: InputEventMouseButton) -> void:
	var rect := Rect2(_drag_start, event.position - _drag_start).abs()
	if rect.size.length() < 8:
		rect = Rect2(event.position - Vector2(22, 32), Vector2(44, 64))
	controller.screen_select(rect, event.shift_pressed)
	_dragging = false
	_selection.hide()

func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
