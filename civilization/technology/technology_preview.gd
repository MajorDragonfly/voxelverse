extends Control
## Standalone UI. No GameState, SaveGameService, ProgressionService or book hook.
signal close_requested
const Model = preload("res://civilization/technology/preview_model.gd")
const Catalog = preload("res://civilization/technology/technology_catalog.gd")
const Text = preload("res://civilization/technology/preview_text.gd")
const Design = preload("res://ui/design/design_system.gd")
const Symbols = preload("res://ui/design/game_symbols.gd")
var model := Model.new()
var selected_id: String = "medieval.housing"
var _text := Text.new()
var _built: bool = false
var _content: VBoxContainer
var _scenario: Button
var _language: Button
var _picker: HBoxContainer
var _picker_title: Label
var _previous: Button
var _next: Button
var _sidebar: VBoxContainer
var _detail: VBoxContainer
var _scroll: ScrollContainer
var _mark: Button
var _status: Label
var _title: Label
var _epoch: Label
var _footer: Label
var _reset: Button
var _exit: Button
var _cards: Dictionary = {}
var _margin: MarginContainer

func _enter_tree() -> void:
	_text.install()

func _exit_tree() -> void:
	_text.uninstall()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_theme()
	var background := ColorRect.new()
	background.color = Design.INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	margin.add_child(_content)
	_title = _label("", 27)
	_content.add_child(_title)
	_epoch = _label("", 15, Design.ACCENT)
	_content.add_child(_epoch)
	var options := HFlowContainer.new()
	options.add_theme_constant_override("h_separation", 10)
	_content.add_child(options)
	_scenario = Button.new()
	Symbols.apply(_scenario, "building", 20)
	_scenario.custom_minimum_size.x = 235
	_scenario.pressed.connect(func() -> void: _select_scenario((model.scenario + 1) % 3))
	options.add_child(_scenario)
	_language = Button.new()
	Symbols.apply(_language, "settings", 20)
	_language.pressed.connect(func() -> void: TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("de") else "de"))
	options.add_child(_language)
	_reset = Button.new()
	Symbols.apply(_reset, "undo", 20)
	_reset.pressed.connect(func() -> void: _select_scenario(0))
	options.add_child(_reset)
	_picker = HBoxContainer.new()
	_previous = Button.new()
	_previous.text = "‹"
	_previous.pressed.connect(func() -> void: _step_technology(-1))
	_picker.add_child(_previous)
	_picker_title = _label("", 15)
	_picker_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker.add_child(_picker_title)
	_next = Button.new()
	_next.text = "›"
	_next.pressed.connect(func() -> void: _step_technology(1))
	_picker.add_child(_next)
	_content.add_child(_picker)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	_content.add_child(body)
	_sidebar = VBoxContainer.new()
	_sidebar.custom_minimum_size.x = 215
	body.add_child(_sidebar)
	var pane := PanelContainer.new()
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(pane)
	var pane_content := VBoxContainer.new()
	pane_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.add_child(pane_content)
	_status = _label("", 17, Design.SOCIAL)
	pane_content.add_child(_status)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pane_content.add_child(_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	_scroll.add_child(_detail)
	_mark = Button.new()
	Symbols.apply(_mark, "check", 20)
	_mark.pressed.connect(func() -> void:
		model.toggle_mark(selected_id)
		_refresh())
	pane_content.add_child(_mark)
	_footer = _label("", 13, Design.MUTED)
	_content.add_child(_footer)
	_exit = Button.new()
	Symbols.apply(_exit, "back", 20)
	_exit.pressed.connect(func() -> void: close_requested.emit())
	_content.add_child(_exit)
	_built = true
	resized.connect(_responsive)
	_refresh()
	_responsive()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _built: _refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_requested.emit()
		get_viewport().set_input_as_handled()

func _build_theme() -> void:
	# This standalone preview changes font size as its window changes. Keep its
	# local Theme independent from other campaign and editor surfaces.
	theme = Design.theme().duplicate()
	theme.default_font_size = 16

func _label(value: String, font_size: int = 16, color: Color = Design.TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _heading(key: String) -> void:
	var label := _label(Text.text(key), 17, Design.ACCENT)
	label.set_meta("technology_heading", true)
	_detail.add_child(label)

func _line(value: String, color: Color = Design.TEXT) -> void:
	_detail.add_child(_label(value, 15, color))

func _responsive() -> void:
	if not _built: return
	var compact: bool = size.x < 850
	_sidebar.visible = not compact
	_picker.visible = compact
	theme.default_font_size = 13 if compact else 16
	_title.add_theme_font_size_override("font_size", 18 if compact else 27)
	_epoch.add_theme_font_size_override("font_size", 12 if compact else 15)
	_status.add_theme_font_size_override("font_size", 14 if compact else 17)
	_footer.add_theme_font_size_override("font_size", 11 if compact else 13)
	_scenario.custom_minimum_size.x = 185 if compact else 235
	_content.add_theme_constant_override("separation", 6 if compact else 10)
	for side: String in ["left", "top", "right", "bottom"]: _margin.add_theme_constant_override("margin_" + side, 10 if compact else 18)
	for label: Label in _detail.get_children():
		label.add_theme_font_size_override("font_size", (14 if compact else 17) if label.has_meta("technology_heading") else (12 if compact else 15))

func select_technology(id: String) -> void:
	if Catalog.find(model.catalog, id).is_empty(): return
	selected_id = id
	_refresh()
	_scroll.scroll_vertical = 0

func _step_technology(direction: int) -> void:
	var nodes: Array = model.catalog.get("nodes", [])
	for index: int in range(nodes.size()):
		if nodes[index]["id"] == selected_id:
			select_technology(nodes[posmod(index + direction, nodes.size())]["id"])
			return

func _select_scenario(index: int) -> void:
	model.select_scenario(index)
	_refresh()

func _refresh() -> void:
	if not _built: return
	_title.text = Text.text("MEDTECH_TITLE")
	_epoch.text = Text.text("MEDTECH_EPOCH")
	_footer.text = Text.text("MEDTECH_NOTICE") + "\n" + Text.text("MEDTECH_FOOTER")
	_reset.text = Text.text("MEDTECH_RESET")
	_exit.text = Text.text("MEDTECH_EXIT")
	var scenario_keys: Array[String] = ["MEDTECH_EMPTY", "MEDTECH_READY", "MEDTECH_PLANNED"]
	_scenario.text = Text.text(scenario_keys[model.scenario]) + "  ↻"
	_scenario.tooltip_text = Text.text("MEDTECH_SCENARIO")
	_language.text = "Deutsch / EN" if TranslationServer.get_locale().begins_with("de") else "English / DE"
	for child: Node in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	if not Catalog.validate(model.catalog).is_empty():
		_status.text = Text.text("MEDTECH_INVALID")
		_mark.disabled = true
		return
	for node: Dictionary in model.catalog["nodes"]:
		var id: String = node["id"]
		var title: String = Text.text(node["title_key"])
		var button: Button = _cards.get(id)
		if button == null:
			button = Button.new()
			Symbols.apply(button, _technology_symbol(id), 20)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.tooltip_text = id
			button.pressed.connect(select_technology.bind(id))
			_sidebar.add_child(button)
			_cards[id] = button
		button.text = ("● " if id == selected_id else "") + title + (" ✓" if id in model.marks else "")
		button.add_theme_stylebox_override("normal", Design.box(Design.PRESSED if id == selected_id else Design.PANEL, Design.ACCENT if id == selected_id else Design.CONTROL, 10))
		if id == selected_id: _picker_title.text = title
	var node: Dictionary = Catalog.find(model.catalog, selected_id)
	var status: Dictionary = model.status(selected_id)
	_status.text = Text.text(node["title_key"]) + " · " + Text.text("MEDTECH_MARKED" if status["marked"] else "MEDTECH_READY_STATUS" if status["preview_ready"] else "MEDTECH_LOCKED")
	_mark.text = Text.text("MEDTECH_UNMARK" if status["marked"] else "MEDTECH_MARK")
	_mark.disabled = not status["marked"] and not status["preview_ready"]
	_line(Text.text(node["description_key"]))
	_line(selected_id + " · v" + str(int(model.catalog["revision"])), Design.MUTED)
	_heading("MEDTECH_DEPENDENCIES")
	if node["requires"].is_empty(): _line(Text.text("MEDTECH_NO_DEPS"))
	for dependency: String in node["requires"]:
		_line(("✓ " if dependency in model.marks else "○ ") + Text.text(Catalog.find(model.catalog, dependency)["title_key"]))
	_heading("MEDTECH_CONTRACT")
	for requirement: String in node["contract_requirements"]:
		_line(("✓ " if model.facts.get(requirement) == true else "○ ") + Text.requirement(requirement))
	_heading("MEDTECH_BLOCKERS")
	for reason: Dictionary in status["reasons"]:
		if reason["code"] == "dependency_missing":
			_line("• " + Text.format_text("MEDTECH_DEP_MISSING", {"title": Text.text(Catalog.find(model.catalog, reason["id"])["title_key"])}))
		else:
			_line("• " + Text.format_text("MEDTECH_CONTRACT_MISSING", {"text": Text.requirement(reason["id"])}))
	_line("• " + Text.text("MEDTECH_PREVIEW_ONLY"), Design.ACCENT)
	_heading("MEDTECH_EFFECT")
	_line(Text.text(node["effect_key"]))
	_line(Text.text("MEDTECH_BALANCE"), Design.MUTED)
	_heading("MEDTECH_LINKS")
	var resource_labels := PackedStringArray()
	for id: String in node["resources"]: resource_labels.append(Text.resource_title(id))
	_line(Text.format_text("MEDTECH_RESOURCES", {"items": ", ".join(resource_labels)}))
	var part_labels := PackedStringArray()
	for id: String in node["building_parts"]: part_labels.append(Text.part_title(id) + " (" + id + ")")
	_line(Text.format_text("MEDTECH_PARTS", {"items": ", ".join(part_labels)}) if not part_labels.is_empty() else Text.text("MEDTECH_NO_PARTS"))
	_line(Text.text("MEDTECH_PART_NOTICE"), Design.MUTED)
	_line(Text.text("MEDTECH_ORDER_NOTICE"), Design.MUTED)
	_responsive()

func _technology_symbol(id: String) -> String:
	match id:
		"medieval.housing": return "house"
		"medieval.crafting": return "craft"
		"medieval.roads": return "build"
		"medieval.trade": return "workers"
		_: return "building"
