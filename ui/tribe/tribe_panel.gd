extends CanvasLayer
const Housing = preload("res://world/tribe/village_housing.gd")
const Style = preload("res://ui/progression_style.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
const Model = preload("res://world/tribe/tribe_state.gd")
const Neighbors = preload("res://ui/tribe/neighbor_panel.gd")
var _neighbors: VBoxContainer

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
var animal_panel_open: bool = false
var _jobs: OptionButton
var _tabs: TabContainer
var _orders_page: VBoxContainer
var _work_page: VBoxContainer
var _hud_content: VBoxContainer
var _scroll: ScrollContainer
var _collapse: Button
var _collapsed: bool = false
var _husbandry_page: VBoxContainer
var _pens: OptionButton
var _animals: OptionButton
var _animal_ids: Array[String] = []
var _care_status: Label
var _bind_animal: Button
var _release_animal: Button

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
	var header := HBoxContainer.new()
	column.add_child(header)
	_stock = Style.label("", 20, Style.SOCIAL)
	_stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_stock)
	_collapse = Style.button("Einklappen")
	header.add_child(_collapse)
	_collapse.pressed.connect(func() -> void:
		if not controller.placement.is_empty():
			controller.placement = ""
			controller.status = "Platzierung abgebrochen."
			_collapsed = false
		else:
			_collapsed = not _collapsed
		refresh())
	_hud_content = VBoxContainer.new()
	_hud_content.add_theme_constant_override("separation", 7)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_scroll.add_child(_hud_content)
	_hud_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column = _hud_content
	_goal = Style.label("", 17)
	column.add_child(_goal)
	_supply = Style.label("", 16, Style.MUTED)
	column.add_child(_supply)
	_residents = HFlowContainer.new()
	column.add_child(_residents)
	_tabs = TabContainer.new()
	_tabs.use_hidden_tabs_for_min_size = false
	column.add_child(_tabs)
	_orders_page = VBoxContainer.new()
	_orders_page.name = "Aufträge"
	_tabs.add_child(_orders_page)
	_work_page = VBoxContainer.new()
	_work_page.name = "Arbeitsplätze & Berufe"
	_tabs.add_child(_work_page)
	_neighbors = Neighbors.new()
	_neighbors.controller = controller
	_neighbors.name = "Nachbarn"
	_tabs.add_child(_neighbors)
	var orders := HFlowContainer.new()
	_orders_page.add_child(orders)
	var all := Style.button("Alle auswählen")
	all.name = "SelectAll"
	orders.add_child(all)
	all.pressed.connect(controller.select_all)
	var titles: Dictionary = {"wood": "Holz sammeln", "stone": "Stein sammeln", "food": "Nahrung sammeln", "supply": "Versorgung sichern", "tool": "Werkzeug · 3 Holz / 2 Stein", "hut": "Hütte setzen · 6 Holz / 3 Stein", "tent": "Zelt setzen · 3 Holz / 2 Fasern", "garden": "Wurzelgarten · 4 Holz / 1 Stein", "feed": "Jetzt essen", "wait": "Anhalten", "resume": "Fortsetzen", "water": "Wasser holen", "provision": "Nahrung & Wasser sichern", "drink": "Jetzt trinken"}
	for order: String in titles:
		var button := Style.button(titles[order])
		button.name = "Order_" + order
		orders.add_child(button)
		button.pressed.connect(func() -> void: controller.issue_order(order))
		_buttons[order] = button
	_buttons["supply"].tooltip_text = "Dauerauftrag: Nahrung ernten und einlagern, bis vier Portionen je Bewohner vorrätig oder unterwegs sind. Danach am Dorfplatz warten und bei Bedarf weiterarbeiten."
	for kind: String in Housing.KINDS:
		_buttons[kind].tooltip_text = "Festes Stammesmodell. Rechtsklick: freien Platz wählen. Material wird aus dem Lager zum Eingang getragen. Hütte: zwei Schlafplätze; Zelt: ein Schlafplatz."
	_buttons["garden"].tooltip_text = "Benötigt ein Steinwerkzeug. Baut die Wurzelfundstelle zum Garten aus. Alle 20 Spielsekunden wächst eine Wurzel nach, bis dort acht bereitliegen."
	var workplaces := HFlowContainer.new()
	_work_page.add_child(workplaces)
	var station_titles: Dictionary = {"well": "Brunnen · 3 H / 2 S", "forester": "Forstplatz · 4 H / 1 S", "quarry": "Steinbruch · 4 H / 2 S", "fiberbed": "Faserbeet · 2 H / 1 S", "fiber": "Fasern sammeln", "milk": "Milch abholen"}
	for order: String in station_titles:
		var button := Style.button(station_titles[order])
		button.name = "Order_" + order
		button.tooltip_text = "Steinwerkzeug erforderlich. Anklicken, dann mit Rechtsklick einen freien, erreichbaren Platz wählen." if order in Economy.STATIONS else "Dauerauftrag mit Transport zum gemeinsamen Lager."
		workplaces.add_child(button)
		button.pressed.connect(func() -> void: controller.issue_order(order))
		_buttons[order] = button
	var professions := HFlowContainer.new()
	_work_page.add_child(professions)
	var profession_label := Style.label("Beruf für die Auswahl:", 16)
	profession_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	professions.add_child(profession_label)
	_jobs = OptionButton.new()
	for profession: String in Economy.JOBS:
		_jobs.add_item(Economy.JOBS[profession])
	professions.add_child(_jobs)
	var assign := Style.button("Beruf zuweisen")
	professions.add_child(assign)
	assign.pressed.connect(func() -> void: controller.assign_profession(Economy.JOBS.keys()[_jobs.selected]))
	var back := Style.button("Beruf fortsetzen")
	professions.add_child(back)
	back.pressed.connect(func() -> void: controller.issue_order("profession"))
	_work_page.add_child(Style.label("Versorger halten Nahrung und Wasser bereit. Baumeister helfen an der laufenden Baustelle. Manuelle Befehle ändern den Beruf nicht.", 15, Style.MUTED))
	_build_husbandry()
	_feedback = preload("res://ui/frontend/group_feedback.gd").new()
	_feedback.controller = controller
	_hud.get_child(0).add_child(_feedback)
	_message = _feedback.result
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
	_scroll.visible = _hud_content.visible
	_scroll.custom_minimum_size.y = minf(_hud_content.get_combined_minimum_size().y, viewport_size.y * 0.44) if _hud_content.visible else 0.0
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
	_hud_content.visible = not _collapsed and controller.placement.is_empty()
	_collapse.text = "Aufträge" if not _hud_content.visible else "Einklappen"
	if not controller._active:
		return
	var data: Dictionary = controller.village()
	if data.is_empty():
		return
	_goal.visible = _tabs.current_tab != 2
	_supply.visible = _tabs.current_tab != 2
	var stock: Dictionary = data["stock"]
	_stock.text = "STAMM · Holz %d · Stein %d · Nahrung %d · Wasser %d · Fasern %d · Milch %d   |   Bewohner %d / 6 · Schlafplätze %d" % [stock["wood"], stock["stone"], stock["food"], stock["water"], stock["fiber"], stock["milk"], data["members"].size(), Housing.beds(data)]
	_supply.text = "Lager: je 48 Einheiten. Arbeitende Bewohner essen und trinken selbstständig; ihr Auftrag bleibt erhalten."
	if int(data["garden"]) == 1:
		_supply.text = "Wurzelgarten · %d erntereif · %s · Essens- und Trinkpausen erfolgen selbstständig." % [data["deposits"]["food"]["remaining"], "Garten gefüllt" if int(data["deposits"]["food"]["remaining"]) >= Model.GARDEN_CAPACITY else "Nächste Wurzel in %d s" % ceili(Model.GROW_SECONDS - float(data["growth"]))]
	_goal.text = "Erster Schritt: Bewohner auswählen und Holz, Stein und Nahrung einlagern."
	if int(data["tools"]) > 0:
		_goal.text = "Steinwerkzeug bereit · Setze Hütten oder Zelte auf freie Plätze und sichere Nahrung und Wasser."
	elif int(stock["wood"]) >= 3 and int(stock["stone"]) >= 2:
		_goal.text = "Material bereit · Weise Bewohner an, das erste Steinwerkzeug herzustellen."
	if not data["project"].is_empty():
		var kind: String = data["project"]["kind"]
		_goal.text = "%s · %d %% · Weitere Bewohner können mitarbeiten." % [{"tool": "Werkzeugherstellung", "hut": "Hüttenbau", "tent": "Zeltbau", "pen": "Tierplatzbau", "garden": "Gartenbau", "well": "Brunnenbau", "forester": "Forstplatz", "quarry": "Steinbruch", "fiberbed": "Faserbeet"}[kind], int(float(data["project"]["progress"]) / float(Model.WORK.get(kind, 15.0)) * 100)]
	elif Housing.beds(data) >= data["members"].size():
		if int(data["garden"]) == 0:
			_goal.text = "Dein Dorf steht · Lege einen Wurzelgarten für dauerhafte Nahrung an."
		elif not data["economy"]["stations"].has("well"):
			_goal.text = "Nahrung wächst nach · Baue einen Brunnen unter Arbeitsplätze & Berufe."
		else:
			_goal.text = "Nahrung und Wasser sichern · Forstplatz, Steinbruch und Faserbeet erweitern die Rohstoffversorgung."
	if data["project"].is_empty() and int(data["tools"]) > 0:
		var reason: String = Housing.growth_blocker(data)
		_goal.text = reason if not reason.is_empty() else "Dorfwachstum · noch %d s gute Versorgung · danach 2 Nahrung und 2 Wasser für den neuen Bewohner." % ceili(Housing.GROW_SECONDS - float(data["housing"]["clock"]))
	var identities: Array = data["members"].map(func(member: Dictionary) -> String: return str(member["id"]))
	if _resident_ids != identities:
		_resident_ids = identities
		for child: Node in _residents.get_children():
			_residents.remove_child(child)
			child.queue_free()
		for member: Dictionary in data["members"]:
			var button := Style.button("")
			button.toggle_mode = true
			button.clip_text = true
			button.add_theme_font_size_override("font_size", 16)
			for state_name: String in ["normal", "hover", "pressed", "disabled"]:
				var style: StyleBoxFlat = button.get_theme_stylebox(state_name).duplicate()
				style.content_margin_top = 6
				style.content_margin_bottom = 6
				button.add_theme_stylebox_override(state_name, style)
			button.name = "Resident_" + str(member["id"])
			button.pressed.connect(func() -> void: controller.select_member(member["id"], Input.is_key_pressed(KEY_SHIFT)))
			_residents.add_child(button)
	for i in range(data["members"].size()):
		var member: Dictionary = data["members"][i]
		var button: Button = _residents.get_child(i)
		var orders: Dictionary = {"wait": "wartet", "move": "unterwegs", "wood": "sammelt Holz", "stone": "sammelt Stein", "food": "sammelt Nahrung", "tool": "stellt Werkzeug her", "hut": "baut Hütte", "tent": "baut Zelt", "pen": "baut Tierplatz", "tend": "versorgt Tiere", "garden": "legt Garten an", "supply": "sichert Nahrung", "feed": "isst", "water": "holt Wasser", "fiber": "sammelt Fasern", "milk": "holt Milch", "drink": "trinkt", "provision": "sichert Nahrung und Wasser", "build": "bereit für Bauarbeiten", "well": "baut Brunnen", "forester": "baut Forstplatz", "quarry": "baut Steinbruch", "fiberbed": "legt Faserbeet an"}
		var activity: String = orders.get(member["order"], "Auftrag: " + str(member["order"]))
		if member["order"] == "supply" and controller._food_reserve_ready():
			activity = "Vorrat bereit · bleibt zuständig"
		elif member["order"] in ["supply", "food"] and int(data["garden"]) == 1 and int(data["deposits"]["food"]["remaining"]) == 0:
			activity = "wartet auf reife Wurzeln"
		var resource: String = "food" if member["order"] == "supply" else str(member["order"])
		if resource in Economy.RESOURCES:
			if Economy.at_target(data, member, resource):
				activity = "Vorrat bereit · bleibt zuständig"
			elif resource == "milk" and data["economy"]["incoming"].is_empty():
				activity = "wartet auf Milchlieferung"
			elif resource != "milk" and int(data["deposits"][resource]["remaining"]) == 0:
				activity = "wartet auf " + Economy.TITLES[resource]
		if member["stage"] == "meal":
			activity = "Essenspause · kehrt zur Arbeit zurück"
		if member["stage"] == "drink":
			activity = "Trinkpause · kehrt zur Arbeit zurück"
		if member["blocked"]:
			activity = "Weg blockiert · prüft neuen Weg"
		if member["order"] == "wait" and member["paused_order"] != "":
			activity = "angehalten · Fortsetzen möglich"
		if member["construction_id"] != "":
			activity = "angehalten · trägt Baumaterial" if member["order"] == "wait" else "trägt Baumaterial zum Eingang"
		button.text = "%s · %s\nSatt %d %% · Wasser %d %%\n%s" % [member["name"], Economy.JOBS[member["profession"]], roundi(float(member["hunger"])), roundi(float(member["hydration"])), "trägt " + Economy.TITLES[member["cargo"]] if member["cargo"] != "" and member["construction_id"] == "" else activity]
		var logical_width: float = get_viewport().get_visible_rect().size.x / _scale_factor
		var columns: int = 2 if logical_width < 1000 else 3
		button.custom_minimum_size.x = maxf(180.0, (logical_width - 112.0) / columns)
		button.tooltip_text = button.text
		button.set_pressed_no_signal(member["id"] in controller.selected)
	for order: String in _buttons:
		_buttons[order].disabled = controller.selected.is_empty() or get_tree().paused
	_buttons["milk"].visible = not data["economy"]["receipts"].is_empty()
	_refresh_husbandry(data)
	_neighbors.refresh()
	_feedback.refresh()
	_layout()

func _process(_delta: float) -> void:
	# Other modals own their pause. Never draw/capture input above the shared book.
	_hud.visible = controller._active and (not get_tree().paused or _owns_pause)
	if get_tree().paused and not _owns_pause:
		_dragging = false
		_selection.hide()


func _input(event: InputEvent) -> void:
	if not controller.placement.is_empty() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		controller.placement = ""
		controller.status = "Platzierung abgebrochen."
		get_viewport().set_input_as_handled()
		return
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

## Feature-owned controls use the shared scrollable tabs.
func add_extension(control: Control) -> void:
	control.name = "Zähmung"
	_tabs.add_child(control)
	_tabs.tab_changed.connect(func(index: int) -> void:
		animal_panel_open = _tabs.get_tab_control(index) == control
		control.visible = animal_panel_open
		call_deferred("_layout"))

func _build_husbandry() -> void:
	_husbandry_page = VBoxContainer.new()
	_husbandry_page.name = "Tierhaltung"
	_tabs.add_child(_husbandry_page)
	var commands := HFlowContainer.new()
	_husbandry_page.add_child(commands)
	for order: String in ["pen", "tend"]:
		var button := Style.button("Tierplatz setzen · 4 Holz / 2 Fasern" if order == "pen" else "Tiere versorgen")
		button.name = "Order_" + order
		commands.add_child(button)
		button.pressed.connect(func() -> void: controller.issue_order(order))
		_buttons[order] = button
	var keeper := Style.button("Tierpfleger zuweisen")
	keeper.name = "AssignKeeper"
	commands.add_child(keeper)
	keeper.pressed.connect(func() -> void: controller.assign_profession("keeper"))
	_care_status = Style.label("", 16)
	_husbandry_page.add_child(_care_status)
	_husbandry_page.add_child(Style.label("Je ein Milchtier pro Platz. Tierpfleger füllen Tröge aus dem Lager; Milchträger holen Milch.", 15, Style.MUTED))
	var choices := HFlowContainer.new()
	_husbandry_page.add_child(choices)
	_pens = OptionButton.new()
	choices.add_child(_pens)
	_animals = OptionButton.new()
	choices.add_child(_animals)
	_bind_animal = Style.button("Tier zuordnen")
	choices.add_child(_bind_animal)
	_bind_animal.pressed.connect(func() -> void:
		if _pens.selected >= 0 and _animals.selected >= 0:
			controller.husbandry.assign(controller.village()["husbandry"]["pens"][_pens.selected]["id"], _animal_ids[_animals.selected])
		refresh())
	_release_animal = Style.button("Zuordnung lösen")
	choices.add_child(_release_animal)
	_release_animal.pressed.connect(func() -> void:
		if _pens.selected >= 0:
			controller.husbandry.release(controller.village()["husbandry"]["pens"][_pens.selected]["id"])
		refresh())

func _refresh_husbandry(data: Dictionary) -> void:
	var pens: Array = data["husbandry"]["pens"]
	if _pens.item_count != pens.size():
		_pens.clear()
		for i in range(pens.size()):
			_pens.add_item("Tierplatz %d" % (i + 1))
	var animals: Array[String] = controller.husbandry.candidates()
	if animals != _animal_ids:
		var selected_id: String = _animal_ids[_animals.selected] if _animals.selected >= 0 else ""
		_animal_ids = animals
		_animals.clear()
		for identity: String in animals:
			_animals.add_item("Milchtier · " + identity.right(12))
		if selected_id in animals:
			_animals.select(animals.find(selected_id))
	_bind_animal.disabled = get_tree().paused or _pens.selected < 0 or _animals.selected < 0
	_release_animal.disabled = get_tree().paused or _pens.selected < 0 or pens[_pens.selected]["animal_id"] == ""
	_care_status.text = "Baue einen Tierplatz auf trockenem, frei erreichbarem Boden." if pens.is_empty() else controller.husbandry.description(pens[_pens.selected])
