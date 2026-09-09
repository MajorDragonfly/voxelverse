extends CanvasLayer

const Style = preload("res://ui/progression_style.gd")
const Journal = preload("res://ui/discovery_journal.gd")
const Development = preload("res://ui/development_path_panel.gd")
const PHASES: Array[String] = ["Kreatur", "Stamm", "Antike / Mittelalter", "Weltmacht", "Weltraum", "Multiversum"]

var player: Node
var _panel: Control
var _body: BoxContainer
var _branches: BoxContainer
var _details: VBoxContainer
var _journal: VBoxContainer
var _scroll: ScrollContainer
var _phase_label: Label
var _wallet_labels: Dictionary = {}
var _cards: Dictionary = {}
var _nodes: Dictionary = {}
var _selected: String = "creature.social.approach"
var _title: Label
var _description: Label
var _requirements: Label
var _effect: Label
var _purchase: Button
var _message: Label
var _close: Button
var _tree_tab: Button
var _journal_tab: Button
var _phase_preview: Label
var _phase_choice: OptionButton
var _view_phase: int = 0
var _tree_heading: Label
var _wallet_context: Label
var _availability: Label
var _planned_earning: Dictionary = {}
var _development: VBoxContainer
var _development_tab: Button
var _previous_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _previous_focus: WeakRef
var _owns_pause: bool = false
var _closing: bool = false
var _purchase_active: bool = false


func _ready() -> void:
	name = "PlayerProgression"
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	var progression := get_node("/root/ProgressionService")
	progression.behavior_changed.connect(refresh)
	progression.discovery_points_changed.connect(func(_points: int) -> void: _refresh_journal())
	progression.species_discovered.connect(func(_key: String, _title_text: String) -> void: _refresh_journal())
	progression.region_discovered.connect(func(_key: String) -> void: _refresh_journal())
	progression.part_unlocked.connect(func(_id: String, _reason: String) -> void: _refresh_journal())
	get_node("/root/GameState").phase_changed.connect(func(_phase: int) -> void: refresh())
	get_node("/root/SaveGameService").game_loaded.connect(func(_path: String) -> void: refresh(); _refresh_journal())
	get_viewport().size_changed.connect(_layout)
	_layout()


func open_panel() -> bool:
	var tribe := get_tree().get_first_node_in_group(&"tribe_controller")
	var group_active: bool = tribe != null and tribe.is_active()
	if visible or _closing or get_tree().paused or not is_instance_valid(player) or (not player.is_physics_processing() and not group_active):
		return false
	_previous_mouse_mode = Input.mouse_mode
	_previous_focus = weakref(get_viewport().gui_get_focus_owner())
	_owns_pause = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_message.text = ""
	refresh()
	_refresh_journal()
	_development.refresh()
	_tree_tab.grab_focus()
	return true


func close_panel() -> void:
	if not visible or _closing:
		return
	visible = false
	_closing = true
	# The closing click/Space/Enter must finish before player input polling resumes.
	_release_after_input_frame()


func _release_after_input_frame() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_release_pause()
	_closing = false
	var previous: Object = _previous_focus.get_ref() if _previous_focus != null else null
	if previous is Control and previous.is_visible_in_tree():
		previous.grab_focus()


func _release_pause() -> void:
	if _owns_pause:
		_owns_pause = false
		get_tree().paused = false
		Input.mouse_mode = _previous_mouse_mode


func _exit_tree() -> void:
	_release_pause()


func _input(event: InputEvent) -> void:
	if _closing:
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	# K remains ordinary text while searching the journal.
	var typing: bool = get_viewport().gui_get_focus_owner() is LineEdit
	if event.pressed and not event.echo and ((key == KEY_K and not typing and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed) or (visible and key == KEY_ESCAPE)):
		if visible:
			close_panel()
		else:
			open_panel()
		get_viewport().set_input_as_handled()
	elif visible and key >= KEY_F1 and key <= KEY_F35:
		# DisplaySettings handles F8 in _input on the parallel planet branch.
		# Block competing menus before their handlers run, including key repeats.
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if visible or _closing:
		get_viewport().set_input_as_handled()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.042, 0.057, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	_panel = MarginContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_panel.add_theme_constant_override("margin_" + side, 32)
	add_child(_panel)
	var content := Style.column(_panel, 16)
	var header := HBoxContainer.new()
	content.add_child(header)
	var heading := Style.column(header, 2)
	heading.add_child(Style.label("VOXELVERSE  /  DEINE SPEZIES", 15, Style.SOCIAL))
	heading.add_child(Style.label("Entwicklung", 38))
	_close = Style.button("Schließen · Esc")
	_close.name = "Close"
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close_panel)
	header.add_child(_close)
	_phase_label = Style.label("", 17, Style.MUTED)
	content.add_child(_phase_label)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	content.add_child(tabs)
	_tree_tab = Style.button("Skilltree")
	_tree_tab.name = "SkilltreeTab"
	_tree_tab.pressed.connect(func() -> void: _show_tab(false))
	tabs.add_child(_tree_tab)
	_journal_tab = Style.button("Entdeckungsbuch")
	_journal_tab.name = "JournalTab"
	_journal_tab.pressed.connect(func() -> void: _show_tab(true))
	tabs.add_child(_journal_tab)
	_development_tab = Style.button("Entwicklungspfad")
	_development_tab.name = "DevelopmentTab"
	_development_tab.pressed.connect(_show_development)
	tabs.add_child(_development_tab)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	content.add_child(_scroll)
	var pages := Style.column(_scroll)
	_phase_choice = OptionButton.new()
	_phase_choice.name = "PhasePreviewChoice"
	_phase_choice.custom_minimum_size.y = 46
	_phase_choice.add_theme_font_size_override("font_size", 18)
	for index in range(PHASES.size()):
		_phase_choice.add_item(PHASES[index] + (" · spielbar" if index == 0 else " · geplant"), index)
	_phase_choice.item_selected.connect(_select_phase)
	pages.add_child(_phase_choice)
	_body = BoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 24)
	pages.add_child(_body)
	var tree_area := Style.column(_body, 16)
	tree_area.size_flags_stretch_ratio = 2.0
	_tree_heading = Style.label("Dein Weg bleibt offen", 28)
	tree_area.add_child(_tree_heading)
	_wallet_context = Style.label("", 18, Style.MUTED)
	tree_area.add_child(_wallet_context)
	_branches = BoxContainer.new()
	_branches.add_theme_constant_override("separation", 16)
	tree_area.add_child(_branches)
	for track in ["social", "aggression"]:
		_build_branch(track)
	_availability = Style.label("F halten: Befreunden · H: Verletzte versorgen · Beißen: Jagd oder feindlichen Konflikt abschließen. Eine Kreatur gibt höchstens einmal Punkte; jeder Ast hat ein Verdienstlimit von 24 Punkten. Offenheit, Zusammenhalt, Jagdinstinkt und Ausdauer wirken im Spiel.", 17, Style.MUTED)
	_availability.name = "GameplayAvailability"
	tree_area.add_child(_availability)
	_phase_preview = Style.label("", 17, Style.MUTED)
	_phase_preview.name = "PhasePreview"
	tree_area.add_child(_phase_preview)
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	detail_panel.add_theme_stylebox_override("panel", Style.box())
	_body.add_child(detail_panel)
	_details = Style.column(detail_panel, 18)
	_details.add_child(Style.label("AUSGEWÄHLTER KNOTEN", 14, Style.MUTED))
	_title = Style.label("", 29)
	_details.add_child(_title)
	_description = Style.label("")
	_details.add_child(_description)
	_requirements = Style.label("", 17, Style.MUTED)
	_details.add_child(_requirements)
	_effect = Style.label("", 17, Style.SOCIAL)
	_details.add_child(_effect)
	_purchase = Style.button("")
	_purchase.name = "Purchase"
	_purchase.pressed.connect(_buy_selected)
	_details.add_child(_purchase)
	_details.add_child(Style.label("Freischaltungen werden sofort gespeichert. Umskillen ist bisher nicht verfügbar.", 16, Style.MUTED))
	_journal = Journal.new()
	pages.add_child(_journal)
	_development = Development.new()
	pages.add_child(_development)
	_message = Style.label("", 18, Style.SOCIAL)
	_message.name = "PurchaseMessage"
	content.add_child(_message)
	_show_tab(false)


func _build_branch(track: String) -> void:
	var color: Color = Style.SOCIAL if track == "social" else Style.AGGRESSION
	var column := Style.column(_branches, 10)
	var wallet := PanelContainer.new()
	wallet.add_theme_stylebox_override("panel", Style.box(Style.PANEL, color))
	column.add_child(wallet)
	var info := Style.column(wallet, 6)
	info.add_child(Style.label("SOZIAL" if track == "social" else "AGGRESSIV", 17, color))
	var balance := Style.label("", 24)
	info.add_child(balance)
	_wallet_labels[track] = balance
	var progression := get_node("/root/ProgressionService")
	for definition: Dictionary in progression.call("get_behavior_nodes", 0):
		if definition["track"] != track:
			continue
		var id: String = definition["id"]
		var card := Style.button("", color)
		card.name = id.replace(".", "_")
		card.custom_minimum_size.y = 118
		column.add_child(card)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 14)
		card.add_child(margin)
		var labels := Style.column(margin, 5)
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.add_child(Style.label(str(definition["name"]), 23, color))
		var state_label := Style.label("", 17)
		labels.add_child(state_label)
		labels.add_child(Style.label("Vermächtnis ab Stamm" if not definition["legacy"].is_empty() else "Kreaturenphase", 15, Style.MUTED))
		card.pressed.connect(_select.bind(id))
		_cards[id] = {"button": card, "status": state_label}
	var planned := Style.label("", 18, Style.MUTED)
	planned.visible = false
	column.add_child(planned)
	_planned_earning[track] = planned


func refresh() -> void:
	if _purchase == null:
		return
	var progression := get_node("/root/ProgressionService")
	_refresh_view_label()
	var wallet: Dictionary = progression.call("get_behavior_wallet", _view_phase)
	var preview: Dictionary = progression.get_phase_progression_preview(_view_phase)
	_tree_heading.text = "Dein Weg bleibt offen" if _view_phase == 0 else PHASES[_view_phase] + " · dein zukünftiger Weg"
	_wallet_context.text = "Sozial und aggressiv lassen sich kombinieren. Angezeigt werden ausschließlich die Punkte der Phase %s." % PHASES[_view_phase]
	if _view_phase > 0:
		_wallet_context.text += " Kreaturenpunkte bleiben im Kreaturenbaum ausgebbar."
	_availability.visible = _view_phase == 0
	_details.get_parent().visible = _view_phase == 0
	for card in _cards.values():
		card["button"].visible = _view_phase == 0
	for track: String in _wallet_labels:
		_wallet_labels[track].text = "%d Punkte verfügbar\n%d verdient · %d ausgegeben" % [int(wallet["available"][track]), int(wallet["earned"][track]), int(wallet["spent"][track])]
		_planned_earning[track].visible = _view_phase > 0
		_planned_earning[track].text = "Geplante Punktequellen\n" + str(preview[track]) + "\n\nFähigkeiten und Käufe folgen mit den spielbaren Handlungen dieser Phase."
	_nodes.clear()
	for definition: Dictionary in progression.call("get_behavior_nodes", 0):
		var id: String = definition["id"]
		_nodes[id] = definition
		if not _cards.has(id):
			continue
		var status: Dictionary = definition["purchase_status"]
		_cards[id]["status"].text = "Freigeschaltet" if definition["purchased"] else "%d Punkte · %s" % [int(definition["cost"]), "Verfügbar" if status["ok"] else "Gesperrt"]
		var color: Color = Style.SOCIAL if definition["track"] == "social" else Style.AGGRESSION
		_cards[id]["button"].add_theme_stylebox_override("normal", Style.box(Color("2b4149") if id == _selected else Style.PANEL, color if id == _selected else Color("40535c"), 12))
	_update_details()
	_refresh_phase_preview()
	_development.refresh()


func _select(id: String) -> void:
	_selected = id
	_message.text = ""
	refresh()


func _update_details() -> void:
	var definition: Dictionary = _nodes.get(_selected, {})
	if definition.is_empty():
		_purchase.disabled = true
		return
	_title.text = definition["name"]
	_description.text = str(definition["description"])
	var names: PackedStringArray = []
	for id: String in definition["requires"]:
		names.append(str(_nodes.get(id, {}).get("name", id)))
	_requirements.text = "Voraussetzung: " + ("keine" if names.is_empty() else ", ".join(names))
	var phase: int = get_node("/root/GameState").current_phase
	var legacy: bool = not definition["legacy"].is_empty()
	_effect.text = "Vermächtnis · für Stamm und spätere Phasen vorbereitet" if legacy else "Kreaturenbonus · endet mit der Kreaturenphase"
	if definition["purchased"]:
		_effect.text += "\nGekauft · " + ("ab Stamm vorgesehen" if legacy and phase == 0 else "in dieser Phase vorgesehen · Gruppenmechanik noch offen" if legacy else "jetzt im Spiel aktiv" if phase == 0 else "Kreaturenphase bereits verlassen")
	var status: Dictionary = definition["purchase_status"]
	_purchase.disabled = not status["ok"] or _purchase_active or _view_phase != 0
	_purchase.text = "Freigeschaltet" if definition["purchased"] else "Freischalten · %d %s" % [int(definition["cost"]), "Sozialpunkte" if definition["track"] == "social" else "Aggressionspunkte"]
	if not status["ok"] and not definition["purchased"]:
		_requirements.text += "\n" + _reason(str(status.get("reason", "")))


func _buy_selected() -> void:
	if _purchase_active or not visible or _view_phase != 0 or not _body.visible:
		return
	_purchase_active = true
	_purchase.disabled = true
	var name_text: String = str(_nodes.get(_selected, {}).get("name", _selected))
	var result: Dictionary = get_node("/root/ProgressionService").call("purchase_behavior_node", _selected)
	_purchase_active = false
	refresh()
	_message.text = "%s freigeschaltet und gespeichert." % name_text if result.get("ok", false) else _reason(str(result.get("reason", "")))
	_message.add_theme_color_override("font_color", Style.SOCIAL if result.get("ok", false) else Style.AGGRESSION)
	# A disabled purchase button must not strand keyboard focus after success.
	if _purchase.disabled:
		_cards[_selected]["button"].grab_focus()


func _reason(reason: String) -> String:
	match reason:
		"insufficient_points": return "Noch nicht genügend Punkte in diesem Ast."
		"prerequisite_missing": return "Zuerst den vorherigen Knoten freischalten."
		"already_purchased": return "Dieser Knoten ist bereits freigeschaltet."
		"future_phase": return "Diese Freischaltung gehört zu einer späteren Phase."
		"save_failed": return "Speichern fehlgeschlagen. Punkte und Freischaltung wurden zurückgesetzt. Du kannst den Kauf erneut versuchen."
		"purchase_in_progress": return "Der vorherige Kauf wird noch gespeichert."
		_: return "Freischaltung momentan nicht möglich. Es wurden keine Punkte ausgegeben."


func _refresh_phase_preview() -> void:
	if _phase_preview == null:
		return
	var index: int = _phase_choice.selected
	var data: Dictionary = get_node("/root/ProgressionService").get_phase_progression_preview(index)
	_phase_preview.text = ("Aktueller Spielablauf" if data["implemented"] else "Planung · noch keine spielbare Phase") + " · " + str(data["scope"])
	_phase_preview.text += "\n%s\n%s\n%s" % [data["control"], " → ".join(data["loop"]), data["next"]]
	if index > 0:
		_phase_preview.text += "\nGekauftes Vermächtnis für diese Phase: Koordination +%d %% · Verteidigung +%d %%" % [roundi((float(data["legacy"]["group_cooperation"]["value"]) - 1.0) * 100.0), roundi((float(data["legacy"]["group_defense"]["value"]) - 1.0) * 100.0)]
		_phase_preview.text += "\nKoordination wirkt auf Dorfaufgaben. Verteidigung folgt mit Stammeskämpfen."
		_phase_preview.text += "\nJede Phase verdient eigene Punkte. Kreaturenpunkte bleiben ihrem Baum zugeordnet."


func _select_phase(index: int) -> void:
	if index not in range(PHASES.size()):
		return
	_view_phase = index
	_phase_choice.select(index)
	_message.text = ""
	refresh()
	_scroll.scroll_vertical = 0


func _show_tab(journal: bool) -> void:
	_body.visible = not journal
	_journal.visible = journal
	_phase_choice.visible = not journal
	_development.visible = false
	_tree_tab.modulate = Color.WHITE if not journal else Style.MUTED
	_journal_tab.modulate = Color.WHITE if journal else Style.MUTED
	_development_tab.modulate = Style.MUTED
	if _message != null:
		_message.text = ""
	_scroll.scroll_vertical = 0
	_refresh_view_label()


func _show_development() -> void:
	_body.visible = false
	_journal.visible = false
	_phase_choice.visible = false
	_development.visible = true
	_tree_tab.modulate = Style.MUTED
	_journal_tab.modulate = Style.MUTED
	_development_tab.modulate = Color.WHITE
	_message.text = ""
	_development.refresh()
	_scroll.scroll_vertical = 0
	_refresh_view_label()


func _refresh_view_label() -> void:
	var phase: int = get_node("/root/GameState").current_phase
	var page: String = "Entwicklungspfad" if _development.visible else "Entdeckungsbuch" if _journal.visible else PHASES[_view_phase]
	_phase_label.text = "Aktuelle Phase: %s · Ansicht: %s · Spiel pausiert" % [PHASES[clampi(phase, 0, PHASES.size() - 1)], page]


func _refresh_journal() -> void:
	if is_instance_valid(_journal) and visible:
		_journal.call("refresh")


func _layout() -> void:
	var width: float = get_viewport().get_visible_rect().size.x
	_body.vertical = width < 1050
	_branches.vertical = width < 620
