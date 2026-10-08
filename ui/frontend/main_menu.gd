extends Control

const Style = preload("res://ui/frontend/menu_style.gd")
const Planet = preload("res://ui/frontend/menu_planet.gd")
const Symbols = preload("res://ui/design/game_symbols.gd")
const Text = preload("res://core/localization/ui_text.gd")
const BlueprintLibraryPanel = preload("res://ui/blueprints/creature_library_panel.gd")
const TribalPlaytest = preload("res://ui/frontend/tribal_playtest.gd")
var _creature_template: Dictionary = {}
var _creature_template_builtin: bool = false
var _template_summary: Label
var _library_panel: Control
var _body: VBoxContainer
var _flow: Node
var _status: Label
var _title_input: LineEdit
var _seed_input: LineEdit
var _page: String = "home"
var _save_browser: Control
var _help_text: Label
var _latest_summary: Label
var _latest: Dictionary = {}
var _latest_phase: Label
var _menu_scroll: ScrollContainer
var _planet_art: Control
var _wordmark: Label
var _footer: Label
var _keys: Label

func _enter_tree() -> void:
	get_node("/root/SessionFlow").enter_frontend()

func _ready() -> void:
	_flow = get_node("/root/SessionFlow")
	theme = Style.theme()
	_build()
	_show_home()
	_flow.menu_error.connect(_show_error)
	get_node("/root/LocaleManager").language_changed.connect(_language_changed)
	if "--pause-menu-smoke" in OS.get_cmdline_user_args() and not get_tree().has_meta("pause_menu_consumed"):
		get_tree().set_meta("pause_menu_consumed", true)
		get_tree().root.add_child.call_deferred(load("res://core/diagnostics/pause_menu_probe.gd").new())
	if "--body-travel-smoke" in OS.get_cmdline_user_args() and not get_tree().has_meta("body_travel_consumed"):
		get_tree().set_meta("body_travel_consumed", true)
		get_tree().root.add_child.call_deferred(load("res://core/diagnostics/body_travel_probe.gd").new())
	if "--sphere-gameplay-smoke" in OS.get_cmdline_user_args() and not get_tree().has_meta("sphere_gameplay_consumed"):
		get_tree().set_meta("sphere_gameplay_consumed", true)
		get_tree().root.add_child.call_deferred(load("res://core/diagnostics/spherical_gameplay_probe.gd").new())
	if "--sphere-creature-smoke" in OS.get_cmdline_user_args() and not get_tree().has_meta("sphere_creature_consumed"):
		get_tree().set_meta("sphere_creature_consumed", true)
		get_tree().root.add_child.call_deferred(load("res://core/diagnostics/spherical_creature_probe.gd").new())
	if "--sphere-smoke" in OS.get_cmdline_user_args() and not get_tree().has_meta("sphere_smoke_consumed"):
		get_tree().set_meta("sphere_smoke_consumed", true)
		get_tree().root.add_child.call_deferred(load("res://core/diagnostics/spherical_campaign_probe.gd").new())
	# Keep the native acceptance entries explicitly available after changing
	# the startup scene. Ordinary launches always stay at the title screen.
	if "--planet-lab" in OS.get_cmdline_user_args() or "--input-smoke" in OS.get_cmdline_user_args():
		if not get_tree().has_meta("frontend_diagnostic_consumed"):
			get_tree().set_meta("frontend_diagnostic_consumed", true)
			if "--input-smoke" in OS.get_cmdline_user_args():
				get_tree().set_meta("menu_smoke_consumed", true)
				get_tree().root.add_child.call_deferred(load("res://core/diagnostics/menu_input_probe.gd").new())
			else:
				get_tree().change_scene_to_file.call_deferred("res://world/planet_lab/planet_lab.tscn")
	if "--frontend-smoke" in OS.get_cmdline_user_args() and not get_tree().has_meta("frontend_smoke_consumed"):
		get_tree().set_meta("frontend_smoke_consumed", true)
		get_tree().root.add_child.call_deferred(load("res://core/diagnostics/frontend_probe.gd").new())

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Style.INK)
	# A quiet orbital frame belongs to the planet; the action area stays clear.
	var center := Vector2(size.x * 0.75, size.y * 0.49)
	var radius: float = minf(size.x * 0.245, size.y * 0.40)
	draw_arc(center, radius, -0.25, 4.50, 100, Color(Style.EDGE, 0.65), 1.0, true)
	draw_arc(center, radius + 18, 0.8, 3.45, 70, Color(Style.EDGE, 0.25), 1.0, true)
	for angle: float in [-0.25, 1.2, 4.50]:
		var marker := center + Vector2.from_angle(angle) * radius
		draw_circle(marker, 2.5, Style.ACCENT)
	draw_line(Vector2(size.x * 0.055, size.y - 62), Vector2(size.x * 0.945, size.y - 62), Style.EDGE)

func _build() -> void:
	resized.connect(_layout)
	_planet_art = Planet.new()
	_planet_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_planet_art.anchor_left = 0.47
	_planet_art.anchor_right = 0.995
	_planet_art.anchor_top = 0.13
	_planet_art.anchor_bottom = 0.90
	add_child(_planet_art)
	_wordmark = Style.label(self, "VOXELVERSE", 64)
	_wordmark.name = "Wordmark"
	_wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_scroll = ScrollContainer.new()
	_menu_scroll.follow_focus = true
	_menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_menu_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	_menu_scroll.add_child(column)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	column.add_child(_body)
	_status = Style.paragraph(column, "", 17)
	_status.name = "MenuStatus"
	_status.add_theme_color_override("font_color", Style.ACCENT)
	_footer = Style.label(self, "ENTWICKLUNGSVERSION    /    KREATURENPHASE", 13, Style.MUTED)
	_keys = Style.label(self, "Tab  Auswahl    ·    Enter  Bestätigen", 13, Style.MUTED)
	_layout()

func _layout() -> void:
	if not is_instance_valid(_menu_scroll): return
	var inset: float = maxf(32.0, size.x * 0.055)
	var compact: bool = size.x < 1000.0
	var width: float = minf(520.0, size.x - inset * 2.0) if compact else minf(540.0, size.x * 0.425)
	_wordmark.position = Vector2(inset - 3.0, maxf(28.0, size.y * 0.075))
	_wordmark.add_theme_font_size_override("font_size", 48 if compact else 64)
	_menu_scroll.position = Vector2(inset, maxf(115.0, size.y * 0.21))
	_menu_scroll.size = Vector2(width, maxf(120.0, size.y - _menu_scroll.position.y - 82.0))
	_planet_art.visible = not compact
	_footer.position = Vector2(inset, size.y - 41.0)
	_keys.position = Vector2(maxf(inset, size.x - inset - 340.0), size.y - 41.0)
	_keys.visible = size.x > 1000.0
	queue_redraw()

func _action(parent: Node, text: String, action: Callable, id: String, symbol: String, primary: bool = false, small: bool = false) -> Button:
	var button := Style.button(parent, text, action, id, primary)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 42 if small else 52
	button.add_theme_font_size_override("font_size", 16 if small else 21)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Symbols.apply(button, symbol, 20 if small else 24)
	if primary: button.icon = Symbols.texture(symbol, Style.INK)
	return button

func _clear(page: String) -> void:
	_page = page
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_status.text = ""
	_status.hide()
	_body.add_theme_constant_override("separation", 12)
	_menu_scroll.scroll_vertical = 0

func _show_home() -> void:
	if is_instance_valid(_save_browser):
		remove_child(_save_browser)
		_save_browser.queue_free()
		_save_browser = null
	_clear("home")
	_latest_summary = null
	_latest_phase = null
	var last: Dictionary = _flow.latest_slot()
	_latest = last
	var resume_parent: Node = _body
	if not last.is_empty():
		var card := PanelContainer.new()
		card.name = "LatestAdventure"
		card.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.EDGE, 18))
		_body.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 14)
		card.add_child(content)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		content.add_child(row)
		row.add_child(Symbols.view("globe", 40, Style.ACCENT))
		var summary := VBoxContainer.new()
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary.add_theme_constant_override("separation", 4)
		row.add_child(summary)
		_latest_summary = Style.label(summary, str(last.name), 24)
		_latest_summary.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_latest_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_latest_phase = Style.paragraph(summary, _latest_information(), 15)
		resume_parent = content
	var resume := _action(resume_parent, "Fortsetzen", func(): _flow.load_game(str(last.get("path", ""))), "Continue", "play", not last.is_empty())
	resume.disabled = last.is_empty()
	var play_row := HBoxContainer.new()
	play_row.add_theme_constant_override("separation", 10)
	_body.add_child(play_row)
	var start := _action(play_row, "Neues Spiel", _show_new, "NewGame", "new_game", last.is_empty())
	_action(play_row, "Spielstände", _show_slots, "Saves", "save")
	var utility_row := HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 8)
	_body.add_child(utility_row)
	_action(utility_row, "Einstellungen", func(): get_node("/root/DisplaySettings").open_menu(), "Settings", "settings", false, true)
	_action(utility_row, "Steuerung", _show_help, "Controls", "controls", false, true)
	_action(utility_row, "Beenden", func(): _flow.request_quit(), "Quit", "quit", false, true)
	_body.add_child(HSeparator.new())
	var development_row := HBoxContainer.new()
	development_row.add_theme_constant_override("separation", 8)
	_body.add_child(development_row)
	_action(development_row, "TRIBAL_TEST_ENTRY", _show_tribal_test, "TribalPlaytest", "tribe", false, true)
	_action(development_row, "FLEET_ENTRY", func(): get_tree().change_scene_to_file("res://space/fleet/fleet_trial.tscn"), "FleetTrial", "fleet", false, true)
	if last.is_empty(): start.grab_focus()
	else: resume.grab_focus()

func _latest_information() -> String:
	if _latest.is_empty(): return ""
	return _phase(int(_latest.get("phase", 0))) + Text.text(" · %d Min.") % int(float(_latest.get("seconds", 0.0)) / 60.0) + "\n" + _date(int(_latest.get("saved_time", 0)))

func _show_new() -> void:
	_clear("new")
	_body.add_theme_constant_override("separation", 8)
	Style.label(_body, "DEIN ABENTEUER", 27)
	Style.paragraph(_body, "Du beginnst in der Kreaturenphase. Dein Fortschritt erhält einen eigenen Spielstand.", 17)
	Style.label(_body, "Name", 18, Style.MUTED)
	_title_input = LineEdit.new()
	_title_input.name = "AdventureName"
	_title_input.placeholder_text = "Mein Abenteuer"
	_title_input.max_length = 48
	_title_input.custom_minimum_size.y = 48
	_body.add_child(_title_input)
	Style.label(_body, "Welt-Seed · optional", 18, Style.MUTED)
	_seed_input = LineEdit.new()
	_seed_input.name = "WorldSeed"
	_seed_input.placeholder_text = "Leer lassen für eine zufällige Welt"
	_seed_input.max_length = 10
	_seed_input.custom_minimum_size.y = 48
	_seed_input.text_changed.connect(func(_text: String): _status.text = ""; _status.hide())
	_body.add_child(_seed_input)
	_template_summary = Style.paragraph(_body, _template_text(), 16)
	_template_summary.name = "StartingCreatureSummary"
	_action(_body, "BP_CHOOSE_START", _choose_start_template, "ChooseStartingCreature", "creature", false, true)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_body.add_child(actions)
	_action(actions, "Abenteuer beginnen", _begin, "Begin", "play", true)
	_action(actions, "Zurück", _show_home, "Back", "back", false, true)
	_title_input.grab_focus()

func _show_tribal_test() -> void:
	_clear("tribal_test")
	Style.paragraph(_body, "TRIBAL_TEST_ENTRY", 27)
	Style.paragraph(_body, "TRIBAL_TEST_DESCRIPTION")
	Style.paragraph(_body, "TRIBAL_TEST_CONTROLS", 17)
	_action(_body, "TRIBAL_TEST_PREPARE", func(): TribalPlaytest.start(_flow), "BeginTribalPlaytest", "play", true)
	_action(_body, "Zurück", _show_home, "Back", "back", false, true).grab_focus()

func _begin() -> void:
	var seed_text: String = _seed_input.text.strip_edges()
	if not seed_text.is_empty() and (not seed_text.is_valid_int() or int(seed_text) < 1 or int(seed_text) > 2147483647):
		_show_error("Bitte einen Welt-Seed von 1 bis 2147483647 eingeben oder das Feld leer lassen.")
		_seed_input.grab_focus()
		return
	_flow.new_game(_title_input.text, 0 if seed_text.is_empty() else int(seed_text), "cube_sphere_m1_v1", _creature_template)


func _choose_start_template() -> void:
	if is_instance_valid(_library_panel): return
	_library_panel = BlueprintLibraryPanel.new()
	_library_panel.start_mode = true
	var comparison_start: Dictionary = BlueprintLibraryPanel.Package.Creature.create_default()
	if not _creature_template.is_empty():
		var prior: Dictionary = BlueprintLibraryPanel.Starter.prepare(_creature_template, comparison_start)
		if prior.ok: comparison_start = prior.blueprint
	_library_panel.compare_current = func() -> Dictionary: return comparison_start.duplicate(true)
	_library_panel.prepare_template = func(package: Dictionary) -> Dictionary:
		return BlueprintLibraryPanel.Starter.prepare(package, BlueprintLibraryPanel.Package.Creature.create_default())
	_library_panel.template_chosen.connect(func(package: Dictionary):
		_creature_template = package.duplicate(true)
		_creature_template_builtin = _library_panel._entry().builtin
		_template_summary.text = _template_text()
		_library_panel._close())
	_library_panel.closed.connect(func(): _library_panel = null)
	add_child(_library_panel)


func _template_text() -> String:
	if _creature_template.is_empty(): return Text.text("BP_DEFAULT_START")
	var title: String = str(_creature_template.title)
	if _creature_template_builtin:
		title = Text.text("BP_START_" + str(_creature_template.design_id).trim_prefix("starter_").to_upper())
	return Text.format_text("BP_SELECTED_START", {"name": title})

func _show_slots() -> void:
	_clear("slots")
	_save_browser = load("res://ui/frontend/save_browser.gd").new()
	_save_browser.back_requested.connect(_show_home)
	add_child(_save_browser)

func _show_help() -> void:
	_clear("help")
	Style.label(_body, "STEUERUNG", 27)
	_help_text = Style.paragraph(_body, _flow.controls_text(), 21)
	var back := _action(_body, "Zurück", _show_home, "Back", "back", false, true)
	back.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(_library_panel): return
	if event.is_action_pressed("ui_cancel") and _page != "home":
		_show_home()
		get_viewport().set_input_as_handled()

func _show_error(message: String) -> void:
	_status.text = message
	_status.show()
	_menu_scroll.ensure_control_visible.call_deferred(_status)

static func _date(unix_time: int) -> String:
	if unix_time <= 0:
		return Text.text("Älterer Spielstand")
	return Text.date_time(unix_time)

static func _phase(value: int) -> String:
	return Text.text(["Kreatur", "Stamm", "Antike / Mittelalter", "Weltmacht", "Weltraum", "Multiversum"][clampi(value, 0, 5)])

func _language_changed(_locale: String) -> void:
	if _page == "new" and is_instance_valid(_template_summary): _template_summary.text = _template_text()
	if _page == "help" and is_instance_valid(_help_text):
		_help_text.text = _flow.controls_text()
	if _page == "home" and is_instance_valid(_latest_summary) and not _latest.is_empty():
		_latest_summary.text = str(_latest.name)
		if is_instance_valid(_latest_phase): _latest_phase.text = _latest_information()
