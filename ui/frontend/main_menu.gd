extends Control

const Style = preload("res://ui/frontend/menu_style.gd")
const Planet = preload("res://ui/frontend/menu_planet.gd")
var _body: VBoxContainer
var _flow: Node
var _status: Label
var _title_input: LineEdit
var _seed_input: LineEdit
var _page: String = "home"

func _enter_tree() -> void:
	get_node("/root/SessionFlow").enter_frontend()

func _ready() -> void:
	_flow = get_node("/root/SessionFlow")
	theme = Style.theme()
	_build()
	_show_home()
	_flow.menu_error.connect(_show_error)
	# Keep the native acceptance entries explicitly available after changing
	# the startup scene. Ordinary launches always stay at the title screen.
	if "--planet-lab" in OS.get_cmdline_user_args() or "--input-smoke" in OS.get_cmdline_user_args():
		if not get_tree().has_meta("frontend_diagnostic_consumed"):
			get_tree().set_meta("frontend_diagnostic_consumed", true)
			_flow.call_deferred("new_game", "Testlauf", 15838)
	if "--frontend-smoke" in OS.get_cmdline_user_args() and not get_tree().has_meta("frontend_smoke_consumed"):
		get_tree().set_meta("frontend_smoke_consumed", true)
		get_tree().root.add_child.call_deferred(load("res://core/diagnostics/frontend_probe.gd").new())

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Style.INK)
	var random := RandomNumberGenerator.new()
	random.seed = 6102026
	for i in range(100):
		var p := Vector2(random.randf_range(0.46, 0.98) * size.x, random.randf_range(0.04, 0.94) * size.y)
		draw_rect(Rect2(p, Vector2.ONE * random.randf_range(1.0, 2.5)), Color(0.6, 0.78, 0.76, random.randf_range(0.2, 0.6)))
	draw_line(Vector2(size.x * 0.075, size.y - 78), Vector2(size.x * 0.925, size.y - 78), Style.EDGE)

func _build() -> void:
	resized.connect(queue_redraw)
	var planet := Planet.new()
	planet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	planet.anchor_left = 0.49
	planet.anchor_right = 0.97
	planet.anchor_top = 0.12
	planet.anchor_bottom = 0.86
	add_child(planet)
	var tagline := Style.label(self, "DEINE SPEZIES. DEINE WELT.", 19, Style.ACCENT)
	tagline.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tagline.anchor_left = 0.58
	tagline.anchor_top = 0.84
	tagline.anchor_bottom = 0.9
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.anchor_left = 0.075
	scroll.anchor_right = 0.445
	scroll.anchor_top = 0.10
	scroll.anchor_bottom = 0.88
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	Style.label(column, "EIN KLEINER ANFANG. EIN GROSSES UNIVERSUM.", 16, Style.ACCENT)
	var title := Style.label(column, "VOXELVERSE", 72)
	title.name = "Wordmark"
	Style.paragraph(column, "Entdecke Welten. Gestalte Leben.", 23)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	column.add_child(spacer)
	_body = VBoxContainer.new()
	column.add_child(_body)
	_status = Style.paragraph(column, "", 18)
	_status.name = "MenuStatus"
	_status.add_theme_color_override("font_color", Color("f2c692"))
	var footer := Style.label(self, "ENTWICKLUNGSVERSION    /    KREATURENPHASE", 16, Style.MUTED)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.anchor_left = 0.075
	footer.offset_top = -57
	var keys := Style.label(self, "Tab  Auswahl    ·    Enter  Bestätigen    ·    F8  Einstellungen", 16, Style.MUTED)
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	keys.offset_left = -610
	keys.offset_right = -100
	keys.offset_top = -57

func _clear(page: String) -> void:
	_page = page
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_status.text = ""

func _show_home() -> void:
	_clear("home")
	var last: Dictionary = _flow.latest_slot()
	var resume := Style.button(_body, "Fortsetzen", func(): _flow.load_game(str(last.get("path", ""))), "Continue", true)
	resume.disabled = last.is_empty()
	if not last.is_empty():
		Style.paragraph(_body, str(last.name) + "  ·  " + _date(int(last.saved_time)), 17)
	var start := Style.button(_body, "Neues Spiel", _show_new, "NewGame", last.is_empty())
	Style.button(_body, "Spielstände", _show_slots, "Saves")
	Style.button(_body, "Einstellungen", func(): get_node("/root/DisplaySettings").open_menu(), "Settings")
	Style.button(_body, "Steuerung", _show_help, "Controls")
	Style.button(_body, "Beenden", func(): _flow.request_quit(), "Quit")
	if last.is_empty():
		start.grab_focus()
	else:
		resume.grab_focus()

func _show_new() -> void:
	_clear("new")
	Style.label(_body, "DEIN ABENTEUER", 27)
	Style.paragraph(_body, "Du beginnst in der Kreaturenphase. Dein Fortschritt erhält einen eigenen Spielstand.")
	Style.label(_body, "Name", 18, Style.MUTED)
	_title_input = LineEdit.new()
	_title_input.name = "AdventureName"
	_title_input.placeholder_text = "Mein Abenteuer"
	_title_input.max_length = 48
	_title_input.custom_minimum_size.y = 54
	_body.add_child(_title_input)
	Style.label(_body, "Welt-Seed · optional", 18, Style.MUTED)
	_seed_input = LineEdit.new()
	_seed_input.name = "WorldSeed"
	_seed_input.placeholder_text = "Leer lassen für eine zufällige Welt"
	_seed_input.max_length = 10
	_seed_input.custom_minimum_size.y = 54
	_seed_input.text_changed.connect(func(_text: String): _status.text = "")
	_body.add_child(_seed_input)
	Style.button(_body, "Abenteuer beginnen", _begin, "Begin", true)
	Style.button(_body, "Zurück", _show_home, "Back")
	_title_input.grab_focus()

func _begin() -> void:
	var seed_text: String = _seed_input.text.strip_edges()
	if not seed_text.is_empty() and (not seed_text.is_valid_int() or int(seed_text) < 1 or int(seed_text) > 2147483647):
		_show_error("Bitte einen Welt-Seed von 1 bis 2147483647 eingeben oder das Feld leer lassen.")
		_seed_input.grab_focus()
		return
	_flow.new_game(_title_input.text, 0 if seed_text.is_empty() else int(seed_text))

func _show_slots() -> void:
	_clear("slots")
	Style.label(_body, "DEINE SPIELSTÄNDE", 27)
	var slots: Array = get_node("/root/SaveGameService").list_slots()
	if slots.is_empty():
		Style.paragraph(_body, "Hier erscheinen deine Abenteuer, sobald du ein neues Spiel beginnst.")
	for slot: Dictionary in slots:
		var entry := Style.button(_body, str(slot.name), func(): _flow.load_game(str(slot.path)), "Slot")
		entry.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		entry.disabled = not bool(slot.valid)
		var detail: String = str(slot.problem)
		if slot.valid:
			detail = "%s · %s · %d Min.\nWelt-Seed %d%s" % [_date(int(slot.saved_time)), _phase(int(slot.phase)), int(float(slot.seconds) / 60.0), int(slot.seed), " · Sicherung verfügbar" if slot.recovered else ""]
		Style.paragraph(_body, detail, 17)
	var back := Style.button(_body, "Zurück", _show_home, "Back")
	back.grab_focus()

func _show_help() -> void:
	_clear("help")
	Style.label(_body, "STEUERUNG", 27)
	Style.paragraph(_body, _flow.controls_text(), 21)
	var back := Style.button(_body, "Zurück", _show_home, "Back")
	back.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _page != "home":
		_show_home()
		get_viewport().set_input_as_handled()

func _show_error(message: String) -> void:
	_status.text = message

static func _date(unix_time: int) -> String:
	if unix_time <= 0:
		return "Älterer Spielstand"
	var date: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%02d.%02d.%04d · %02d:%02d UTC" % [date.day, date.month, date.year, date.hour, date.minute]

static func _phase(value: int) -> String:
	return ["Kreatur", "Stamm", "Antike / Mittelalter", "Weltmacht", "Weltraum", "Multiversum"][clampi(value, 0, 5)]
