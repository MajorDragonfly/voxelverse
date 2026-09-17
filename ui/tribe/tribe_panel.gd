extends CanvasLayer
const Layout = preload("res://ui/hud_layout.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Presentation = preload("res://ui/tribe/tribe_presentation.gd")
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
var _dialog_scroll: ScrollContainer
var _dialog_content: VBoxContainer
var _confirmation_problem: String = ""
var _confirmation_error: String = ""
var _message: Label
var _hud: PanelContainer
var _hud_content: VBoxContainer
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
var _build_page: VBoxContainer
var _work_page: VBoxContainer
var _workplaces: VBoxContainer
var _construction: VBoxContainer
var _hud_scroll: ScrollContainer:
	get: return _scroll
var _orders_scroll: ScrollContainer:
	get: return _scroll
var _scroll: ScrollContainer
var _camera_menu: MenuButton
var _collapse: Button
var _collapsed: bool = false
var _husbandry_page: VBoxContainer
var _pens: OptionButton
var _animals: OptionButton
var _animal_ids: Array[String] = []
var _care_status: Label
var _bind_animal: Button
var _release_animal: Button
var _change_site: Button
var _font_scale: float = -1.0

func _ready() -> void:
	layer = 40
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_refresh_language()
	get_node("/root/DisplaySettings").input_preferences.bindings_changed.connect(_refresh_camera_menu)
	# Tab-dependent headings affect the scroll layout. Update them with the tab,
	# before callers scroll to an action, instead of waiting for the next village tick.
	_tabs.tab_changed.connect(func(_index: int) -> void: refresh())
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()

func _build() -> void:
	entry = _local_button("TRIBE_AGE_ENTRY")
	entry.name = "TribalAgeEntry"
	add_child(entry)
	entry.pressed.connect(open_confirmation)
	_hud = PanelContainer.new()
	_hud.resized.connect(_place_hud)
	_hud.minimum_size_changed.connect(func() -> void: call_deferred("_layout"))
	_hud.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Color("354750"), 10))
	add_child(_hud)
	var column := Style.column(_hud, 7)
	var header := HBoxContainer.new()
	column.add_child(header)
	_stock = Style.label("", 17, Style.SOCIAL)
	_stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stock.mouse_filter = Control.MOUSE_FILTER_STOP
	header.add_child(_stock)
	_camera_menu = MenuButton.new()
	_camera_menu.name = "TribeCameraMenu"
	_camera_menu.text = Text.text("TRIBE_CAMERA_VIEW")
	_camera_menu.about_to_popup.connect(_refresh_camera_menu)
	_camera_menu.get_popup().id_pressed.connect(_camera_action)
	header.add_child(_camera_menu)
	_collapse = _local_button("TRIBE_COLLAPSE")
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
	_residents = HFlowContainer.new()
	column.add_child(_residents)
	_tabs = TabContainer.new()
	_tabs.use_hidden_tabs_for_min_size = false
	column.add_child(_tabs)
	_orders_page = VBoxContainer.new()
	_orders_page.name = "Aufträge"
	_tabs.add_child(_orders_page)
	_construction = preload("res://ui/tribe/construction_panel.gd").new()
	_construction.controller = controller
	_build_page = VBoxContainer.new()
	_build_page.name = "Bauen"
	_build_page.add_child(_construction)
	_work_page = VBoxContainer.new()
	_work_page.name = "Arbeitsplätze & Berufe"
	_tabs.add_child(_work_page)
	_work_page.add_child(_supply)
	_neighbors = Neighbors.new()
	_neighbors.controller = controller
	_neighbors.name = "Nachbarn"
	var orders := HFlowContainer.new()
	_orders_page.add_child(orders)
	var builds := HFlowContainer.new()
	_build_page.add_child(builds)
	var care := HFlowContainer.new()
	_work_page.add_child(care)
	var all := _local_button("TRIBE_SELECT_ALL")
	all.name = "SelectAll"
	orders.add_child(all)
	all.pressed.connect(controller.select_all)
	var titles: Array = ["wood", "stone", "food", "supply", "tool", "hut", "tent", "garden", "feed", "wait", "resume", "water", "provision", "drink"]
	for order: String in titles:
		var button := Style.button(Presentation.order_title(order))
		button.name = "Order_" + order
		if order in ["tool", "hut", "tent", "garden"]:
			builds.add_child(button)
		elif order in ["supply", "feed", "drink"]:
			care.add_child(button)
		else:
			orders.add_child(button)
		button.pressed.connect(func() -> void: controller.issue_order(order))
		_buttons[order] = button
	_buttons["supply"].tooltip_text = Text.text("TRIBE_SUPPLY_HINT")
	for kind: String in Housing.KINDS:
		_buttons[kind].tooltip_text = Text.text("TRIBE_HOUSING_HINT")
	_buttons["garden"].tooltip_text = Text.text("TRIBE_GARDEN_HINT")
	var workplaces := HFlowContainer.new()
	_work_page.add_child(workplaces)
	var station_titles: Array = ["well", "forester", "quarry", "fiberbed", "fiber", "milk"]
	for order: String in station_titles:
		var button := Style.button(Presentation.order_title(order))
		button.name = "Order_" + order
		button.tooltip_text = Text.text("TRIBE_STATION_HINT") if order in Economy.STATIONS else Text.text("TRIBE_TRANSPORT_HINT")
		workplaces.add_child(button)
		button.pressed.connect(func() -> void: controller.issue_order(order))
		_buttons[order] = button
	var professions := HFlowContainer.new()
	_work_page.add_child(professions)
	var profession_label := _local_label("TRIBE_PROFESSION_LABEL", 16)
	profession_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profession_label.custom_minimum_size.x = 200
	professions.add_child(profession_label)
	_jobs = OptionButton.new()
	for profession: String in Economy.JOBS:
		_jobs.add_item(Presentation.job_title(profession))
	professions.add_child(_jobs)
	var assign := _local_button("TRIBE_ASSIGN_PROFESSION")
	professions.add_child(assign)
	assign.pressed.connect(func() -> void: controller.assign_profession(Economy.JOBS.keys()[_jobs.selected]))
	var back := _local_button("TRIBE_RESUME_PROFESSION")
	professions.add_child(back)
	back.pressed.connect(func() -> void: controller.issue_order("profession"))
	_work_page.add_child(_local_label("TRIBE_PROFESSION_HINT", 15, Style.MUTED))
	_workplaces = preload("res://ui/tribe/workplace_panel.gd").new()
	_workplaces.controller = controller
	# A completed station creates a new row even when the display scale did not change.
	_workplaces.child_entered_tree.connect(func(_row: Node) -> void: _font_scale = -1.0)
	_work_page.add_child(_workplaces)
	_build_husbandry()
	_tabs.add_child(_neighbors)
	_tabs.add_child(_build_page)
	_feedback = preload("res://ui/frontend/group_feedback.gd").new()
	_feedback.controller = controller
	_hud.get_child(0).add_child(_feedback)
	_message = _feedback.result
	_residents.tooltip_text = Text.text("TRIBE_CONTROLS")
	_compact_controls(_hud)
	_shade = ColorRect.new()
	_shade.color = Color(0.015, 0.025, 0.035, 0.78)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.add_child(_center)
	_dialog = PanelContainer.new()
	_dialog.minimum_size_changed.connect(func() -> void: call_deferred("_layout"))
	_dialog.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.SOCIAL, 28))
	_center.add_child(_dialog)
	var content := Style.column(_dialog, 12)
	content.add_child(_local_label("TRIBE_AGE_TITLE", 30, Style.SOCIAL))
	_dialog_scroll = ScrollContainer.new()
	_dialog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_dialog_scroll)
	_dialog_content = Style.column(_dialog_scroll, 0)
	_detail = Style.label("", 19)
	_dialog_content.add_child(_detail)
	confirm = _local_button("TRIBE_AGE_CONFIRM")
	confirm.name = "ConfirmTribalAge"
	content.add_child(confirm)
	confirm.pressed.connect(_confirm)
	cancel = _local_button("TRIBE_AGE_CANCEL")
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
	var font_scale: float = clampf(float(get_node("/root/DisplaySettings").ui_scale), 1.0, 1.5)
	if font_scale != _font_scale:
		_font_scale = font_scale
		_apply_hud_fonts(_hud, font_scale)
		_apply_hud_fonts(_dialog, font_scale)
		_apply_hud_fonts(entry, font_scale)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_scale_factor = viewport_size.x / maxf(float(get_window().size.x), 1.0)
	transform = Transform2D(0.0, Vector2.ONE * _scale_factor, 0.0, Vector2.ZERO)
	viewport_size /= _scale_factor
	# Large text in a short window needs the selection/result to scroll with the
	# orders. Keep the same Controls; placement feedback stays outside the scroll.
	var compact_feedback: bool = _hud_content.visible and float(get_node("/root/DisplaySettings").ui_scale) > 1.0 and (viewport_size.x < 1100 or viewport_size.y < 750)
	var feedback_parent: Node = _hud_content if compact_feedback else _hud.get_child(0)
	if _feedback.get_parent() != feedback_parent:
		_feedback.reparent(feedback_parent)
	entry.position = Vector2(viewport_size.x - 282, 76)
	entry.size = Vector2(260, 46)
	_scroll.visible = _hud_content.visible
	var fixed_height: float = _hud.get_combined_minimum_size().y - _scroll.get_combined_minimum_size().y
	var available_height: float = maxf(0.0, viewport_size.y - 36.0 - fixed_height)
	var height_fraction: float = 0.25 if _tabs.get_current_tab_control() == _orders_page and font_scale <= 1.0 and viewport_size.y >= 900 else 0.36
	# Scroll offsets are integer pixels. A fractional viewport height can leave
	# the last button clipped at enlarged canvas scales after ensure_control_visible.
	_scroll.custom_minimum_size.y = ceilf(minf(_hud_content.get_combined_minimum_size().y, minf(viewport_size.y * height_fraction, available_height))) if _hud_content.visible else 0.0
	var minimap := get_tree().get_first_node_in_group(&"minimap_hud")
	var reserve: float = minimap.reserved_width() if minimap != null else 0.0
	_hud.size = Vector2(maxf(viewport_size.x - 36 - reserve, 280.0), 0)
	_place_hud()
	_shade.size = viewport_size
	_dialog.custom_minimum_size.x = minf(viewport_size.x - 48, 670)
	var dialog_fixed: float = _dialog.get_combined_minimum_size().y - _dialog_scroll.get_combined_minimum_size().y
	_dialog_scroll.custom_minimum_size.y = minf(_dialog_content.get_combined_minimum_size().y, maxf(0.0, viewport_size.y - 48.0 - dialog_fixed))
	_dialog.size = Vector2(_dialog.custom_minimum_size.x, 0)

func _place_hud() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_hud.position = Vector2(18, get_viewport().get_visible_rect().size.y / _scale_factor - _hud.size.y - 18)


func open_confirmation() -> bool:
	if confirmation_open or get_tree().paused or controller._active:
		return false
	_confirmation_problem = controller.prepare_confirmation()
	_confirmation_error = ""
	confirm.disabled = not _confirmation_problem.is_empty()
	_refresh_confirmation_text()
	_dialog_scroll.scroll_vertical = 0
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
		_confirmation_error = saves.last_error
		_refresh_confirmation_text()
		_layout()
		cancel.grab_focus()

func _refresh_confirmation_text() -> void:
	# Re-render the captured outcome, never prepare/retry a transition on locale change.
	cancel.text = Text.text("TRIBE_AGE_CANCEL" if _confirmation_error.is_empty() else "TRIBE_AGE_RETURN")
	_detail.text = Text.text("TRIBE_AGE_DETAIL")
	if not _confirmation_problem.is_empty():
		_detail.text = Text.format_text("TRIBE_AGE_BLOCKED", {"reason": Presentation.legacy_status(_confirmation_problem)})
	if not _confirmation_error.is_empty():
		_detail.text = Text.format_text("TRIBE_AGE_SAVE_FAILED", {"reason": Presentation.legacy_status(_confirmation_error)})

func refresh() -> void:
	if entry == null:
		return
	_update_hud_visibility()
	_hud_content.visible = not _collapsed and controller.placement.is_empty()
	_feedback.visible = not _collapsed
	_collapse.text = Text.text("TRIBE_ORDERS_TAB" if not _hud_content.visible else "TRIBE_COLLAPSE")
	if not controller._active:
		return
	var data: Dictionary = controller.village()
	if data.is_empty():
		return
	_construction.refresh(data)
	_goal.visible = _tabs.get_current_tab_control() == _orders_page
	_supply.visible = true
	var stock: Dictionary = data["stock"]
	_stock.text = Text.format_text("TRIBE_STOCK", stock.merged({"eggs": stock.get("eggs", 0), "residents": data["members"].size(), "capacity": Housing.MAX_RESIDENTS, "beds": Housing.beds(data)}, true))
	_stock.tooltip_text = preload("res://world/tribe/village_inventory_view.gd").tooltip(data)
	_supply.text = Text.text("TRIBE_STORE_HINT")
	if int(data["garden"]) == 1:
		_supply.text = Text.format_text("TRIBE_GARDEN_STATUS", {"ready": data["deposits"]["food"]["remaining"], "growth": Text.text("TRIBE_GARDEN_FULL") if int(data["deposits"]["food"]["remaining"]) >= Model.GARDEN_CAPACITY else Text.format_text("TRIBE_GARDEN_NEXT", {"seconds": ceili(Model.GROW_SECONDS - float(data["growth"]))})})
	_goal.text = Text.text("TRIBE_GOAL_START")
	if int(data["tools"]) > 0:
		_goal.text = Text.text("TRIBE_GOAL_TOOL")
	elif int(stock["wood"]) >= 3 and int(stock["stone"]) >= 2:
		_goal.text = Text.text("TRIBE_GOAL_MATERIAL")
	if not data["project"].is_empty():
		var kind: String = data["project"]["kind"]
		_goal.text = Text.format_text("TRIBE_GOAL_PROJECT", {"project": Text.text(Presentation.PROJECTS.get(kind, "TRIBE_COMMAND")), "percent": int(float(data["project"]["progress"]) / float(Model.WORK.get(kind, 15.0)) * 100)})
	elif Housing.beds(data) >= data["members"].size():
		if int(data["garden"]) == 0:
			_goal.text = Text.text("TRIBE_GOAL_GARDEN")
		elif not data["economy"]["stations"].has("well"):
			_goal.text = Text.text("TRIBE_GOAL_WELL")
		else:
			_goal.text = Text.text("TRIBE_GOAL_SUPPLY")
	if data["project"].is_empty() and int(data["tools"]) > 0:
		var reason: String = Housing.growth_blocker(data)
		_goal.text = Presentation.legacy_status(reason) if not reason.is_empty() else Text.format_text("TRIBE_GROWTH_READY", {"seconds": ceili(Housing.GROW_SECONDS - float(data["housing"]["clock"]))})
	var identities: Array = data["members"].map(func(member: Dictionary) -> String: return str(member["id"]))
	if _resident_ids != identities:
		_resident_ids = identities
		for child: Node in _residents.get_children():
			_residents.remove_child(child)
			child.queue_free()
		for member: Dictionary in data["members"]:
			var button := Style.button("")
			button.toggle_mode = true
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_size_override("font_size", 16)
			for state_name: String in ["normal", "hover", "pressed", "disabled"]:
				var style: StyleBoxFlat = button.get_theme_stylebox(state_name).duplicate()
				style.content_margin_top = 6
				style.content_margin_bottom = 6
				button.add_theme_stylebox_override(state_name, style)
			button.name = "Resident_" + str(member["id"])
			button.pressed.connect(func() -> void: controller.select_member(member["id"], Input.is_key_pressed(KEY_SHIFT)))
			_residents.add_child(button)
			_apply_hud_fonts(button, maxf(1.0, _font_scale))
	for i in range(data["members"].size()):
		var member: Dictionary = data["members"][i]
		var button: Button = _residents.get_child(i)
		var activity: String = Presentation.activity_title(member["order"])
		if member["order"] == "supply" and controller._food_reserve_ready():
			activity = Text.text("TRIBE_RESERVE_READY")
		elif member["order"] in ["supply", "food"] and int(data["garden"]) == 1 and int(data["deposits"]["food"]["remaining"]) == 0:
			activity = Text.text("TRIBE_WAIT_ROOTS")
		var resource: String = "food" if member["order"] == "supply" else str(member["order"])
		if resource in Economy.RESOURCES:
			if Economy.at_target(data, member, resource):
				activity = Text.text("TRIBE_RESERVE_READY")
			elif Economy.Resources.uses_batches(resource) and Economy.pickup(data, resource).is_empty():
				activity = Text.format_text("TRIBE_WAIT_RESOURCE", {"resource": Presentation.resource_title(resource)})
			elif not Economy.Resources.uses_batches(resource) and int(Economy.source(data, member, resource)["remaining"]) == 0:
				activity = Text.format_text("TRIBE_WAIT_RESOURCE", {"resource": Presentation.resource_title(resource)})
		if member["stage"] == "meal":
			activity = Text.text("TRIBE_MEAL")
		if member["stage"] == "drink":
			activity = Text.text("TRIBE_DRINK")
		if member["blocked"]:
			activity = Text.text("TRIBE_BLOCKED")
		if member["order"] == "wait" and member["paused_order"] != "":
			activity = Text.text("TRIBE_STOPPED")
		if member["construction_id"] != "":
			activity = Text.text("TRIBE_STOPPED_CARGO") if member["order"] == "wait" else Text.text("TRIBE_BUILD_CARGO")
		var description := {"name": member["name"], "profession": Presentation.job_title(member["profession"]), "food": roundi(float(member["hunger"])), "water": roundi(float(member["hydration"])), "activity": Text.format_text("TRIBE_CARRYING", {"resource": Presentation.resource_title(member["cargo"])}) if member["cargo"] != "" and member["construction_id"] == "" else activity}
		button.text = Text.format_text("TRIBE_RESIDENT_COMPACT", description)
		button.tooltip_text = Text.format_text("TRIBE_RESIDENT", description)
		var workplace: String = Economy.station_key(data, str(member.get("workplace_id", "")))
		if not workplace.is_empty():
			button.tooltip_text += "\n" + Text.format_text("WORKPLACE_ASSIGNED", {"name": Text.text(Presentation.PROJECTS[Economy.station_kind(workplace)]), "number": 1 if workplace in Economy.STATIONS else 2})
		var logical_width: float = get_viewport().get_visible_rect().size.x / _scale_factor
		var columns: int = 2 if logical_width < 1000 else 3
		button.custom_minimum_size.x = maxf(180.0, (_hud.size.x - 56.0) / columns)
		button.set_pressed_no_signal(member["id"] in controller.selected)
	for order: String in _buttons:
		_buttons[order].disabled = controller.selected.is_empty() or get_tree().paused
		if order in Economy.STATIONS and Economy.next_station(data, order).is_empty(): _buttons[order].disabled = true
	_workplaces.refresh(data)
	_buttons["milk"].visible = not data["economy"]["receipts"].is_empty()
	# Hidden detail pages do not need to scan/validate the animal registry five
	# times per second. Tab changes refresh them before the player interacts.
	if _tabs.get_current_tab_control() == _husbandry_page:
		_refresh_husbandry(data)
	if _tabs.get_current_tab_control() == _neighbors:
		_neighbors.refresh()
	_feedback.refresh()
	_layout()

func _update_hud_visibility() -> void:
	entry.visible = not confirmation_open and int(get_node("/root/GameState").current_phase) == 0 and Layout.gameplay_entries_visible(self, controller.player)
	_hud.visible = controller._active and (not get_tree().paused or _owns_pause)

func _process(_delta: float) -> void:
	if controller.camera_rig != null and not controller.is_active():
		controller.camera_rig.cancel_input()
		_camera_menu.get_popup().hide()
	# Other modals own their pause. Never draw/capture input above the shared book.
	_update_hud_visibility()
	if get_tree().paused and not _owns_pause:
		_dragging = false
		_selection.hide()


func _input(event: InputEvent) -> void:
	if not controller.placement.is_empty() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		controller.placement = ""
		controller.status = "Platzierung abgebrochen."
		controller.building_preview.clear_preview()
		refresh()
		get_viewport().set_input_as_handled()
		return
	if controller.camera_rig != null and controller.camera_rig.handle_input(event):
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
	# Wheel events can propagate through buttons even when ordinary clicks stop.
	if event is InputEventMouseButton and get_viewport().gui_get_hovered_control() != null:
		return
	if event is InputEventMouseButton and event.pressed:
		get_viewport().gui_release_focus()
	if not _dragging and controller.camera_rig.handle_unhandled(event):
		get_viewport().set_input_as_handled()
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
	_font_scale = -1.0
	_tabs.set_tab_title(_tabs.get_tab_idx_from_control(control), Text.text("TRIBE_TAMING_TAB"))
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
	for order: String in ["pen", "laying_site", "tend", "eggs"]:
		var button := _local_button({"pen": "HUSBANDRY_BUILD_PEN", "laying_site": "HUSBANDRY_BUILD_LAYING"}.get(order, Presentation.ORDERS[order]))
		button.name = "Order_" + order
		commands.add_child(button)
		button.pressed.connect(func() -> void: controller.issue_order(order))
		_buttons[order] = button
	var keeper := _local_button("HUSBANDRY_ASSIGN_KEEPER")
	keeper.name = "AssignKeeper"
	commands.add_child(keeper)
	keeper.pressed.connect(func() -> void: controller.assign_profession("keeper"))
	_care_status = Style.label("", 16)
	_husbandry_page.add_child(_care_status)
	_husbandry_page.add_child(_local_label("HUSBANDRY_HINT", 15, Style.MUTED))
	var choices := HFlowContainer.new()
	_husbandry_page.add_child(choices)
	_pens = OptionButton.new()
	_pens.fit_to_longest_item = false
	_pens.custom_minimum_size.x = 230
	_pens.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	choices.add_child(_pens)
	_pens.item_selected.connect(func(_index: int) -> void: refresh())
	_animals = OptionButton.new()
	_animals.fit_to_longest_item = false
	_animals.custom_minimum_size.x = 230
	_animals.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	choices.add_child(_animals)
	_bind_animal = _local_button("HUSBANDRY_ASSIGN")
	choices.add_child(_bind_animal)
	_bind_animal.pressed.connect(func() -> void:
		if _pens.selected >= 0 and _animals.selected >= 0:
			controller.husbandry.assign(controller.village()["husbandry"]["pens"][_pens.selected]["id"], _animal_ids[_animals.selected])
		refresh())
	_release_animal = _local_button("HUSBANDRY_RELEASE")
	choices.add_child(_release_animal)
	var change_site := _local_button("HUSBANDRY_CHANGE_SITE")
	_change_site = change_site
	choices.add_child(change_site)
	change_site.pressed.connect(func() -> void:
		if _pens.selected >= 0:
			controller.husbandry.change_site(controller.village().husbandry.pens[_pens.selected].id)
		refresh())
	_release_animal.pressed.connect(func() -> void:
		if _pens.selected >= 0:
			controller.husbandry.release(controller.village()["husbandry"]["pens"][_pens.selected]["id"])
		refresh())

func _refresh_husbandry(data: Dictionary) -> void:
	var pens: Array = data["husbandry"]["pens"]
	if _pens.item_count != pens.size():
		var selected_id: String = str(_pens.get_item_metadata(_pens.selected)) if _pens.selected >= 0 else ""
		_pens.clear()
		for i in range(pens.size()):
			_pens.add_item("")
			_pens.set_item_metadata(i, pens[i].id)
			if pens[i].id == selected_id:
				_pens.select(i)
	for i in range(pens.size()):
		_pens.set_item_text(i, Text.format_text("HUSBANDRY_LAYING_SITE" if pens[i].get("kind", "pen") == "laying_site" else "HUSBANDRY_PEN", {"number": i + 1}))
	var animals: Array[String] = controller.husbandry.candidates(pens[_pens.selected] if _pens.selected >= 0 else {})
	if animals != _animal_ids:
		var selected_id: String = _animal_ids[_animals.selected] if _animals.selected >= 0 else ""
		_animal_ids = animals
		_animals.clear()
		for identity: String in animals:
			_animals.add_item("")
		if selected_id in animals:
			_animals.select(animals.find(selected_id))
	for i in range(animals.size()):
		_animals.set_item_text(i, Text.format_text("HUSBANDRY_EGG_ANIMAL" if _pens.selected >= 0 and pens[_pens.selected].get("kind") == "laying_site" else "HUSBANDRY_MILK_ANIMAL", {"number": i + 1}))
	for choice: OptionButton in [_pens, _animals]:
		choice.tooltip_text = choice.get_item_text(choice.selected) if choice.selected >= 0 else ""
	_bind_animal.disabled = get_tree().paused or _pens.selected < 0 or _animals.selected < 0
	_release_animal.disabled = get_tree().paused or _pens.selected < 0 or pens[_pens.selected]["animal_id"] == ""
	_change_site.disabled = get_tree().paused or _pens.selected < 0
	_care_status.text = Text.text("HUSBANDRY_BUILD_HINT") if pens.is_empty() else Presentation.husbandry_detail(controller.husbandry.describe(pens[_pens.selected]))

func _local_button(key: String) -> Button:
	var button := Style.button(Text.text(key))
	button.set_meta("tribe_text_key", key)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF if key == "TRIBE_COLLAPSE" else TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.x = 0 if key == "TRIBE_COLLAPSE" else 200
	return button

func _local_label(key: String, font_size: int, color: Color = Style.TEXT) -> Label:
	var label := Style.label(Text.text(key), font_size, color)
	label.set_meta("tribe_text_key", key)
	return label

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and controller != null and controller.camera_rig != null:
		controller.camera_rig.cancel_input()
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _scroll != null:
		# Keep the session, resident nodes, profession selection, focus and tab.
		var old_scroll: int = _scroll.scroll_vertical
		var old_dialog_scroll: int = _dialog_scroll.scroll_vertical
		_refresh_language()
		refresh()
		_layout()
		call_deferred("_restore_language_scroll", old_scroll, old_dialog_scroll)

func _restore_language_scroll(value: int, dialog_value: int) -> void:
	if is_inside_tree():
		_scroll.scroll_vertical = value
		_dialog_scroll.scroll_vertical = dialog_value

func _refresh_language() -> void:
	_refresh_camera_menu()
	for control: Node in find_children("*", "Control", true, false):
		if control.has_meta("tribe_text_key"):
			control.text = Text.text(control.get_meta("tribe_text_key"))
	_tabs.set_tab_title(_tabs.get_tab_idx_from_control(_orders_page), Text.text("TRIBE_ORDERS_TAB"))
	_tabs.set_tab_title(_tabs.get_tab_idx_from_control(_work_page), Text.text("TRIBE_WORK_TAB"))
	_tabs.set_tab_title(_tabs.get_tab_idx_from_control(_husbandry_page), Text.text("TRIBE_HUSBANDRY_TAB"))
	_tabs.set_tab_title(_tabs.get_tab_idx_from_control(_build_page), Text.text("TRIBE_BUILD_TAB"))
	_residents.tooltip_text = Text.text("TRIBE_CONTROLS")
	for i in range(_tabs.get_tab_count()):
		if _tabs.get_tab_control(i).name == "Zähmung":
			_tabs.set_tab_title(i, Text.text("TRIBE_TAMING_TAB"))
	for order: String in _buttons:
		if _buttons[order].get_parent().get_parent() in [_orders_page, _work_page, _build_page]:
			_buttons[order].text = Presentation.order_title(order)
			_buttons[order].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_buttons[order].custom_minimum_size.x = 150
	for i in range(_jobs.item_count):
		_jobs.set_item_text(i, Presentation.job_title(Economy.JOBS.keys()[i]))
	_buttons["supply"].tooltip_text = Text.text("TRIBE_SUPPLY_HINT")
	_buttons["garden"].tooltip_text = Text.text("TRIBE_GARDEN_HINT")
	for kind: String in Housing.KINDS:
		_buttons[kind].tooltip_text = Text.text("TRIBE_HOUSING_HINT")
	for order: String in ["well", "forester", "quarry", "fiberbed", "fiber", "milk"]:
		_buttons[order].tooltip_text = Text.text("TRIBE_STATION_HINT" if order in Economy.STATIONS else "TRIBE_TRANSPORT_HINT")
	_change_site.tooltip_text = Text.text("HUSBANDRY_CHANGE_HINT")
	_refresh_confirmation_text()

func _apply_hud_fonts(node: Node, font_scale: float) -> void:
	if node is Label or node is Button or node is TabBar or node is PopupMenu:
		if not node.has_meta("tribe_base_font_size"):
			node.set_meta("tribe_base_font_size", node.get_theme_font_size("font_size"))
		var target: int = roundi(float(node.get_meta("tribe_base_font_size")) * font_scale)
		if node.get_theme_font_size("font_size") != target:
			node.add_theme_font_size_override("font_size", target)
	for child: Node in node.get_children(true):
		_apply_hud_fonts(child, font_scale)

func _compact_controls(node: Node) -> void:
	if node is Button:
		node.custom_minimum_size.y = 34
		node.set_meta("tribe_base_font_size", 16)
		node.add_theme_font_size_override("font_size", 16)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBox = node.get_theme_stylebox(state).duplicate()
			style.content_margin_top = 6
			style.content_margin_bottom = 6
			style.content_margin_left = 9
			style.content_margin_right = 9
			node.add_theme_stylebox_override(state, style)
	for child: Node in node.get_children():
		_compact_controls(child)

func add_settlements(runtime: Node) -> void:
	var page := preload("res://ui/tribe/settlement_panel.gd").new()
	page.runtime = runtime
	_tabs.add_child(page)
	_font_scale = -1.0

func _refresh_camera_menu() -> void:
	var keys = preload("res://core/input_preferences.gd")
	_camera_menu.text = Text.text("TRIBE_CAMERA_VIEW")
	var values: Dictionary = {}
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "tribe_turn_left", "tribe_turn_right", "tribe_tilt_up", "tribe_tilt_down", "tribe_focus_home", "tribe_focus_selection", "tribe_orbit"]:
		values[action] = keys.binding_label(action)
	_camera_menu.tooltip_text = Text.format_text("TRIBE_CAMERA_HINT", values)
	var menu: PopupMenu = _camera_menu.get_popup()
	menu.clear()
	menu.add_item(Text.text("TRIBE_CAMERA_HOME") + " · " + values.tribe_focus_home, 0)
	menu.add_item(Text.text("TRIBE_CAMERA_SELECTION") + " · " + values.tribe_focus_selection, 1)
	menu.add_item(Text.text("TRIBE_CAMERA_RESET"), 2)
	menu.add_separator()
	menu.add_item(Text.text("TRIBE_CAMERA_OPEN_SETTINGS"), 3)
	menu.set_item_disabled(1, controller.selected.is_empty())
	if controller.camera_rig != null: controller.camera_rig.cancel_input()

func _camera_action(id: int) -> void:
	if not controller.is_active(): return
	match id:
		0: controller.camera_rig.focus_home()
		1: controller.camera_rig.focus_selection()
		2: controller.camera_rig.reset_view()
		3:
			var settings: Node = get_node("/root/DisplaySettings")
			settings.open_menu()
			settings._tabs.current_tab = settings._control_settings.get_parent().get_index()
