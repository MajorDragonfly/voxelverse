extends CanvasLayer
## Shared discovery book, installed once by ProgressionHUD for J and the skilltree.

const Records = preload("res://core/discovery/discovery_records.gd")
const Preview = preload("res://ui/discovery/journal_preview.gd")
const Research = preload("res://core/discovery/research_goals.gd")
const PREFS_PATH := "user://discovery_journal_ui.cfg"
const PAGE_SIZE: int = 100

var is_open: bool = false
var player: Node
var _owns_pause: bool = false
var _closing: bool = false
var _previous_mouse: int = Input.MOUSE_MODE_CAPTURED
var _progression: Node
var _surface: Control
var _summary: Label
var _search: LineEdit
var _filter: OptionButton
var _status: OptionButton
var _tabs: TabBar
var _list: ItemList
var _detail: VBoxContainer
var _detail_scroll: ScrollContainer
var _preview: SubViewportContainer
var _title: Label
var _description: Label
var _parts_label: Label
var _page_label: Label
var _previous_page: Button
var _next_page: Button
var _guide: Label
var _hint: Label
var _hud: Control
var _close: Button
var _pin: Button
var _wish: Button
var _goal_progress: ProgressBar
var _action_message: Label
var _pinned_button: Button
var _pinned_row: Dictionary = {}
var _state: Dictionary = {}
var _rows: Array[Dictionary] = []
var _selected_key: String = ""
var _page: int = 0
var _hint_enabled: bool = true
var _hint_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"discovery_journal")
	layer = 30
	_progression = get_node_or_null("/root/ProgressionService")
	var prefs := ConfigFile.new()
	if prefs.load(PREFS_PATH) == OK:
		_hint_enabled = bool(prefs.get_value("journal", "show_hint", true))
	_build()
	if _progression != null:
		_progression.connect("species_discovered", _on_discovery)
		_progression.connect("discovery_points_changed", _on_points)
		_progression.connect("region_discovered", func(_key: String) -> void: _on_points(0))
		_progression.connect("part_unlocked", func(_id: String, _reason: String) -> void: _on_points(0))
		_progression.connect("research_changed", _on_research_changed)
	_update_hint()
	_update_research_hud()


func _exit_tree() -> void:
	if _owns_pause and get_tree() != null:
		get_tree().paused = false
		Input.mouse_mode = _previous_mouse


func _process(delta: float) -> void:
	_hud.visible = not is_open and not get_tree().paused and (player == null or player.is_physics_processing())
	_hint_timer -= delta
	if _hint_timer <= 0.0 and not is_open:
		_hint_timer = 1.0
		_update_hint()


func _input(event: InputEvent) -> void:
	if _closing:
		get_viewport().set_input_as_handled()
		return
	if not is_open or not event is InputEventKey:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if event.pressed and not event.echo and key == KEY_ESCAPE:
		close_journal()
		get_viewport().set_input_as_handled()
	elif key == KEY_J and not _search.has_focus():
		if event.pressed and not event.echo:
			close_journal()
		get_viewport().set_input_as_handled()
	elif key in [KEY_F2, KEY_F4, KEY_F8, KEY_F10, KEY_F11]:
		# Keep scene/editor/settings shortcuts from opening a second modal.
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if is_open or _closing:
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	if event.keycode == KEY_J or event.physical_keycode == KEY_J:
		if open_journal():
			get_viewport().set_input_as_handled()


func open_journal() -> bool:
	if is_open or _closing or get_tree().paused or _progression == null:
		return false
	if player != null and not player.is_physics_processing():
		return false
	_previous_mouse = Input.mouse_mode
	_owns_pause = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	_surface.show()
	_hud.hide()
	refresh()
	_close.grab_focus()
	return true


func close_journal() -> void:
	if not is_open:
		return
	is_open = false
	_closing = true
	_surface.hide()
	_preview.call("clear")
	_release_after_input_frame()


func _release_after_input_frame() -> void:
	# A closing Space/Enter/click must finish before gameplay polls actions again.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false
		Input.mouse_mode = _previous_mouse
	_closing = false
	_hud.show()


func refresh() -> void:
	if _progression == null:
		return
	_state = _progression.call("export_state")
	_summary.text = "%d Arten     ·     %d Regionen     ·     %d Teile verfügbar     ·     %d Entdeckungspunkte" % [
		Records.as_dictionary(_state.get("discovered_species", {})).size(),
		Records.as_dictionary(_state.get("discovered_regions", {})).size(),
		Records.as_dictionary(_state.get("unlocked_parts", {})).size(), int(_state.get("discovery_points", 0))]
	_apply_filters()


func _build() -> void:
	_surface = Control.new()
	_surface.name = "JournalSurface"
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.theme = _theme()
	add_child(_surface)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.03, 0.025, 0.90)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 28
	panel.offset_top = 24
	panel.offset_right = -28
	panel.offset_bottom = -24
	panel.add_theme_stylebox_override("panel", _box(Color("122422"), 20))
	_surface.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var heading_text := _label("ENTDECKUNGSBUCH", 28)
	heading_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(heading_text)
	_close = _button("Zurück zum Spiel  ·  Esc", close_journal)
	_close.name = "CloseJournal"
	heading.add_child(_close)
	_summary = _label("", 15)
	layout.add_child(_summary)
	_tabs = TabBar.new()
	_tabs.name = "JournalTabs"
	for tab in ["Arten", "Körperteile", "Regionen", "Nächste Schritte", "Forschungsziele"]:
		_tabs.add_tab(tab)
	_tabs.tab_changed.connect(_on_tab_changed)
	layout.add_child(_tabs)
	var tools_row := HBoxContainer.new()
	tools_row.name = "Filters"
	layout.add_child(tools_row)
	_search = LineEdit.new()
	_search.name = "JournalSearch"
	_search.placeholder_text = "Name oder Fundort suchen …"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_value: String) -> void: _page = 0; _apply_filters())
	tools_row.add_child(_search)
	_filter = OptionButton.new()
	_filter.name = "JournalFilter"
	_filter.item_selected.connect(func(_index: int) -> void: _page = 0; _apply_filters())
	tools_row.add_child(_filter)
	_status = OptionButton.new()
	_status.name = "PartStatus"
	for text in ["Alle Teile", "Freigeschaltet", "Noch gesperrt", "Merkliste"]:
		_status.add_item(text)
	_status.item_selected.connect(func(_index: int) -> void: _page = 0; _apply_filters())
	tools_row.add_child(_status)
	var content := HBoxContainer.new()
	content.name = "JournalContent"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	layout.add_child(content)
	var browser := VBoxContainer.new()
	browser.custom_minimum_size.x = 240
	browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser.size_flags_stretch_ratio = 0.38
	content.add_child(browser)
	_list = ItemList.new()
	_list.name = "JournalEntries"
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("v_separation", 14)
	_list.item_selected.connect(_select_entry)
	browser.add_child(_list)
	var paging := HBoxContainer.new()
	browser.add_child(paging)
	_previous_page = _button("‹", func() -> void: _page -= 1; _apply_filters())
	_previous_page.tooltip_text = "Vorherige Seite"
	paging.add_child(_previous_page)
	_page_label = _label("", 13)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paging.add_child(_page_label)
	_next_page = _button("›", func() -> void: _page += 1; _apply_filters())
	_next_page.tooltip_text = "Nächste Seite"
	paging.add_child(_next_page)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 14)
	_detail_scroll.add_child(_detail)
	_title = _label("", 26)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_title)
	_preview = Preview.new()
	_preview.name = "SpeciesPreview"
	_detail.add_child(_preview)
	_description = _label("", 17)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_description)
	_goal_progress = ProgressBar.new()
	_goal_progress.name = "ResearchProgress"
	_goal_progress.show_percentage = false
	_goal_progress.custom_minimum_size.y = 14
	_detail.add_child(_goal_progress)
	_pin = _button("Im Spiel verfolgen", _pin_selected)
	_pin.name = "PinResearch"
	_detail.add_child(_pin)
	_wish = _button("Auf Merkliste setzen", _toggle_wish)
	_wish.name = "WishPart"
	_detail.add_child(_wish)
	_parts_label = _label("", 16)
	_parts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_parts_label)
	_guide = _label("", 19)
	_guide.name = "JournalGuide"
	_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_guide)
	_action_message = _label("", 15)
	_action_message.name = "ResearchSaveMessage"
	_action_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_message.hide()
	layout.add_child(_action_message)
	var hints := CheckButton.new()
	hints.text = "Kurzen Spielhinweis anzeigen"
	hints.button_pressed = _hint_enabled
	hints.toggled.connect(_toggle_hint)
	layout.add_child(hints)
	_surface.hide()
	_build_hud()
	_populate_filter()


func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hud.offset_left = -480
	_hud.offset_top = -132
	_hud.offset_right = -24
	_hud.offset_bottom = -24
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = _surface.theme
	add_child(_hud)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(layout)
	_hint = _label("", 14)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	layout.add_child(_hint)
	_pinned_button = _button("", _open_pinned)
	_pinned_button.name = "PinnedResearch"
	_pinned_button.custom_minimum_size.y = 76
	_pinned_button.clip_text = true
	_pinned_button.hide()
	layout.add_child(_pinned_button)
	var open_button := _button("Entdeckungsbuch öffnen  ·  J", func() -> void: open_journal())
	open_button.name = "OpenJournal"
	open_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	layout.add_child(open_button)


func _on_tab_changed(_index: int) -> void:
	_page = 0
	_selected_key = ""
	_action_message.hide()
	_search.clear()
	_populate_filter()
	_apply_filters()


func _populate_filter() -> void:
	_filter.clear()
	_filter.add_item("Alle Rollen" if _tabs.current_tab == 0 else "Alle Kategorien")
	_filter.set_item_metadata(0, "")
	var labels: Dictionary = Records.ROLES if _tabs.current_tab == 0 else Records.CATEGORIES
	for key in labels:
		_filter.add_item(str(labels[key]))
		_filter.set_item_metadata(_filter.item_count - 1, key)
	_filter.select(0)
	_status.visible = _tabs.current_tab == 1
	_filter.visible = _tabs.current_tab < 2
	_search.placeholder_text = "Teil oder Herkunft suchen …" if _tabs.current_tab == 1 else "Name oder Fundort suchen …"
	if _tabs.current_tab == 4:
		_search.placeholder_text = "Forschungsziel suchen …"


func _apply_filters() -> void:
	if _tabs == null:
		return
	var guide_mode: bool = _tabs.current_tab == 3
	_search.get_parent().visible = not guide_mode
	_list.get_parent().visible = not guide_mode
	_guide.visible = guide_mode
	_parts_label.text = ""
	_pin.hide()
	_wish.hide()
	_goal_progress.hide()
	_preview.call("clear")
	_preview.hide()
	if guide_mode:
		_title.text = "Dein nächster Schritt"
		_description.text = _current_hint()
		_guide.text = "BEOBACHTEN\nZiele auf ein Tier in deiner Nähe und nutze Linksklick. Mit E schaltest du die Inspektionsansicht um.\n\nENTDECKEN\nEine neue Art bringt Entdeckungspunkte und kann eines ihrer noch gesperrten Körperteile freischalten. Bereits bekannte Arten geben keine zweite Belohnung.\n\nGESTALTEN\nÖffne den Kreatureneditor mit F2 im Spiel. Dort kannst du deine verfügbaren Teile anbauen.\n\nÜBERLEBEN\nNutze Linksklick zum Fressen und Trinken. Welche Nahrung deine Kreatur verträgt, hängt von ihrem Körperbau ab.\n\nDEINE SAMMLUNG\nJ öffnet dieses Buch. Es zeigt deine gespeicherten Entdeckungen und lässt sich mit Esc wieder schließen."
		return
	var filter_value: String = str(_filter.get_item_metadata(_filter.selected)) if _filter.selected >= 0 else ""
	match _tabs.current_tab:
		0: _rows = Records.species_rows(_state, _search.text, filter_value)
		1: _rows = Records.part_rows(_state, _search.text, filter_value, _status.selected)
		2: _rows = Records.region_rows(_state, _search.text)
		4: _rows = Research.rows(_state, _search.text)
	_page = clampi(_page, 0, maxi((_rows.size() - 1) / PAGE_SIZE, 0))
	_list.clear()
	var selected_index: int = 0
	for index in range(_page * PAGE_SIZE, mini((_page + 1) * PAGE_SIZE, _rows.size())):
		var row: Dictionary = _rows[index]
		var label: String = str(row.get("name", "Unbekannte Art"))
		if _tabs.current_tab == 1:
			label = ("✓  " if row.get("unlocked", false) else "○  ") + label
			if row.get("wished", false): label += " · gemerkt"
		elif _tabs.current_tab == 4:
			label = ("✓  " if row["complete"] else "○  ") + label
		_list.add_item(label)
		_list.set_item_tooltip(_list.item_count - 1, label + " · " + str(row.get("location", row.get("source", ""))))
		if str(row.get("key", row.get("id", ""))) == _selected_key:
			selected_index = _list.item_count - 1
	_page_label.text = "%d Einträge · %d / %d" % [_rows.size(), _page + 1, maxi(ceili(float(_rows.size()) / PAGE_SIZE), 1)]
	_previous_page.disabled = _page == 0
	_next_page.disabled = (_page + 1) * PAGE_SIZE >= _rows.size()
	if _rows.is_empty():
		_selected_key = ""
		_title.text = "Noch keine Arten entdeckt" if _tabs.current_tab == 0 and Records.as_dictionary(_state.get("discovered_species", {})).is_empty() else "Keine passenden Einträge"
		_description.text = "Ziele auf ein Tier in deiner Nähe und beobachte es mit Linksklick. Deine erste Entdeckung erscheint hier." if _title.text == "Noch keine Arten entdeckt" else "Ändere die Suche oder den Filter, um weitere Einträge zu sehen."
		if _tabs.current_tab == 1 and _status.selected == 3 and _search.text.is_empty():
			_title.text = "Deine Teile-Merkliste"
			_description.text = "Wähle unter »Noch gesperrt« ein Körperteil und setze es auf deine Merkliste. Du kannst ein Wunschteil als Ziel im Spiel verfolgen."
		return
	_list.select(selected_index)
	_select_entry(selected_index)


func _select_entry(index: int) -> void:
	var absolute: int = _page * PAGE_SIZE + index
	if absolute < 0 or absolute >= _rows.size():
		return
	var row: Dictionary = _rows[absolute]
	_selected_key = str(row.get("key", row.get("id", "")))
	_detail_scroll.scroll_vertical = 0
	_title.text = str(row.get("name", "Unbekannte Art"))
	_parts_label.text = ""
	_pin.hide()
	_wish.hide()
	_goal_progress.hide()
	_preview.call("clear")
	_preview.hide()
	if _tabs.current_tab == 0:
		_description.text = "%s\nEntdeckt auf %s" % [row["role_label"], row["location"]]
		var blueprint: Dictionary = Records.visual_for(row)
		if blueprint.is_empty():
			_description.text += "\n\nFür diese frühere Entdeckung fehlt eine gespeicherte Ansicht. Beobachte die Art erneut, um sie zu ergänzen."
		else:
			_preview.show()
			_preview.call("show_blueprint", blueprint)
			_description.text += "\n\nAnsicht drehen: ziehen · Zoom: Mausrad"
			var lines := PackedStringArray(["BEOBACHTETE KÖRPERTEILE"])
			for part_id in Records.part_ids(blueprint):
				var definition: Dictionary = Records.Parts.get_part(part_id)
				var available: bool = Records.as_dictionary(_state.get("unlocked_parts", {})).has(part_id)
				lines.append("%s  %s · %s" % ["✓" if available else "○", definition.get("name", part_id), "verfügbar" if available else "noch gesperrt"])
			_parts_label.text = "\n".join(lines)
		var awarded: String = str(row.get("unlocked_part", ""))
		if not awarded.is_empty():
			_description.text += "\n\nBei dieser Entdeckung freigeschaltet: %s" % Records.Parts.get_part(awarded).get("name", awarded)
	elif _tabs.current_tab == 4:
		_description.text = "%s\n\n%d / %d %s · %s\n\nBereits gespeicherte Entdeckungen zählen mit." % [row["description"], row["current"], row["target"], row["unit"], "Ziel erreicht" if row["complete"] else "In Arbeit"]
		_goal_progress.max_value = row["target"]
		_goal_progress.value = row["current"]
		_goal_progress.show()
		_show_pin(str(row["id"]))
	elif _tabs.current_tab == 2:
		_description.text = "Entdeckt auf %s\n\nGespeicherte Regionskoordinaten: %s / %s" % [row["location"], Records.saved_integer(row.get("x", "?")), Records.saved_integer(row.get("z", "?"))]
	else:
		var category: String = str(row.get("category", ""))
		_description.text = "%s · %s\n\n%s\n\n%s" % [Records.CATEGORIES.get(category, "Gespeichertes Teil"),
			"Freigeschaltet" if row["unlocked"] else "Noch gesperrt", row["source"], row.get("description", "")]
		if row["unlocked"] and category != "missing":
			_parts_label.text = "Im Kreatureneditor verfügbar · Buch schließen und F2 drücken."
		var wished: bool = row.get("wished", false)
		_wish.visible = wished or (not row["unlocked"] and category != "missing")
		_wish.text = "Von Merkliste entfernen" if wished else "Auf Merkliste setzen"
		if wished:
			_show_pin("part:" + str(row["id"]))
			if row["unlocked"]:
				_description.text += "\n\nSammelziel erreicht."
		elif not row["unlocked"] and category != "missing":
			_description.text += "\n\nWeitere neue Arten beobachten. Pro neuer Art wird höchstens ein Teil freigeschaltet; erneutes Beobachten bekannter Arten gibt kein weiteres Teil."


func _show_pin(id: String) -> void:
	_pin.show()
	_pin.text = "Nicht mehr verfolgen" if _state.get("research", {}).get("pinned", "") == id else "Im Spiel verfolgen"


func _pin_selected() -> void:
	if _selected_key.is_empty():
		return
	var id: String = "part:" + _selected_key if _tabs.current_tab == 1 else _selected_key
	if _state.get("research", {}).get("pinned", "") == id:
		id = ""
	_research_result(_progression.call("set_research_pin", id))


func _toggle_wish() -> void:
	if _selected_key.is_empty():
		return
	var wishes: Array = _state.get("research", {}).get("wished_parts", [])
	_research_result(_progression.call("set_part_wished", _selected_key, not wishes.has(_selected_key)))


func _research_result(result: Dictionary) -> void:
	_action_message.show()
	if result.get("ok", false):
		_action_message.text = "Auswahl gespeichert."
	else:
		match str(result.get("reason", "")):
			"wishlist_full": _action_message.text = "Deine Merkliste ist voll (32 Teile). Entferne zuerst ein anderes Teil."
			"part_unavailable": _action_message.text = "Dieses Teil ist bereits verfügbar oder fehlt im Teilekatalog."
			"save_in_progress": _action_message.text = "Es wird gerade gespeichert. Versuche es gleich erneut."
			_: _action_message.text = "Speichern fehlgeschlagen. Deine bisherige Auswahl bleibt erhalten; du kannst es erneut versuchen."


func _on_research_changed() -> void:
	_action_message.hide()
	if is_open:
		refresh()
	_update_research_hud()


func _update_research_hud() -> void:
	if _progression == null:
		return
	_pinned_row = _progression.call("get_pinned_research")
	_pinned_button.visible = not _pinned_row.is_empty()
	_hud.offset_top = -216 if _pinned_button.visible else -132
	if _pinned_row.is_empty():
		return
	var status: String = "Ziel erreicht" if _pinned_row["complete"] else "Dein Forschungsziel"
	if not _pinned_row["available"]:
		status = "Ziel nicht verfügbar"
	_pinned_button.text = "%s · %s\n%d / %d %s · Im Buch ansehen" % [status, _pinned_row["name"], _pinned_row["current"], _pinned_row["target"], _pinned_row["unit"]]
	_pinned_button.tooltip_text = _pinned_button.text


func _open_pinned() -> void:
	if _pinned_row.is_empty() or not open_journal():
		return
	_tabs.current_tab = 1 if _pinned_row["kind"] == "part" else 4
	_search.clear()
	_filter.select(0)
	if _tabs.current_tab == 1:
		_status.select(3)
	_selected_key = _pinned_row["key"]
	_page = 0
	_apply_filters()


func _current_hint() -> String:
	if _progression == null:
		return "Entdecke deine Welt."
	var state := {"discovered_species": _progression.get("discovered_species")}
	var active_player := player if player != null else get_tree().get_first_node_in_group(&"player")
	if active_player != null and active_player.has_method("get_health_ratio"):
		return Records.next_step(state, float(active_player.call("get_health_ratio")), float(active_player.call("get_thirst_ratio")), float(active_player.call("get_hunger_ratio")))
	return Records.next_step(state)


func _update_hint() -> void:
	_hint.visible = _hint_enabled
	if _hint_enabled:
		_hint.text = _current_hint()


func _toggle_hint(enabled: bool) -> void:
	_hint_enabled = enabled
	_update_hint()
	var prefs := ConfigFile.new()
	prefs.set_value("journal", "show_hint", enabled)
	if prefs.save(PREFS_PATH) != OK:
		_hint.tooltip_text = "Die Anzeige wurde geändert, konnte aber nicht für den nächsten Start gespeichert werden."


func _on_discovery(_key: String, _name: String) -> void:
	if is_open:
		refresh()
	_update_hint()
	_update_research_hud()


func _on_points(_points: int) -> void:
	# Import/reset emit this too. No fabricated discovery notification on loading.
	if is_open:
		call_deferred("refresh")
	_update_hint()
	_update_research_hud()


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.pressed.connect(action)
	return button


func _box(color: Color, margin: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_border_width_all(1)
	box.border_color = Color("3b5b51")
	box.set_corner_radius_all(3)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box


func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 17
	for type in ["Label", "Button", "CheckButton", "OptionButton", "LineEdit", "ItemList", "TabBar"]:
		theme.set_color("font_color", type, Color("e4eee3"))
		theme.set_color("font_selected_color", type, Color("ffffff"))
	for type in ["Button", "OptionButton", "LineEdit"]:
		theme.set_stylebox("normal", type, _box(Color("213c35")))
		theme.set_stylebox("hover", type, _box(Color("355d4c")))
		theme.set_stylebox("pressed", type, _box(Color("47765b")))
		var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0))
		focus.border_color = Color("e0c785")
		focus.set_border_width_all(2)
		theme.set_stylebox("focus", type, focus)
	theme.set_stylebox("panel", "ItemList", _box(Color("0d1c1b")))
	theme.set_stylebox("selected", "ItemList", _box(Color("365c49")))
	theme.set_stylebox("selected_focus", "ItemList", _box(Color("486d50")))
	theme.set_stylebox("tab_selected", "TabBar", _box(Color("3b5d48")))
	theme.set_stylebox("tab_unselected", "TabBar", _box(Color("1b302b")))
	return theme
