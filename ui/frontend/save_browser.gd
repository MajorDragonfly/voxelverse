extends Control

const Query = preload("res://ui/frontend/slot_browser_query.gd")
const Text = preload("res://core/localization/ui_text.gd")
signal back_requested
const Style = preload("res://ui/frontend/menu_style.gd")
const Dates = preload("res://ui/frontend/main_menu.gd")
var _saves: Node
var _list: VBoxContainer
var _details: VBoxContainer
var _status: Label
var _name_input: LineEdit
var _history: OptionButton
var _history_preview: VBoxContainer
var _restore_button: Button
var selected_path: String = ""
var _slots: Array = []
var _entries: Array = []
var _filtered: Array[Dictionary] = []
var _page: int = 0
var _search: LineEdit
var _phase_filter: OptionButton
var _state_filter: OptionButton
var _sort: OptionButton
var _reset: Button
var _page_label: Label
var _previous: Button
var _next: Button
var _margin: MarginContainer
var _toolbar: HBoxContainer
var _brand: Label
var _heading: Label
var _tools: VBoxContainer
var _left: VBoxContainer
var _slot_scroll: ScrollContainer
var _right: ScrollContainer
var _details_toggle: Button
var _overview: BoxContainer
var _detail_picture: Control
var _detail_summary: VBoxContainer
var _compact: bool = false
var _show_details: bool = false
var _query_pending: bool = false
var _query_delay: float = 0.0
var _selection_memory: Dictionary = {}
var _scan: RefCounted
var _history_scan: RefCounted
var _preferred_path: String = ""
var _scan_label: Label
var _history_label: Label
var _history_loaded: bool = false
var _left_view: bool = false
const STATUS_KEYS := ["SAVE_FILTER_ALL", "SAVE_FILTER_READY", "SAVE_FILTER_ATTENTION"]
const STATUS_IDS := ["all", "ready", "attention"]
const SORT_KEYS := ["SAVE_SORT_RECENT", "SAVE_SORT_NAME", "SAVE_SORT_PLAYTIME"]
const SORT_IDS := ["recent", "name", "playtime"]

func _ready() -> void:
	name = "SaveBrowser"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.theme()
	_saves = get_node("/root/SaveGameService")
	get_node("/root/LocaleManager").language_changed.connect(_language_changed)
	var background := ColorRect.new()
	background.color = Style.INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_margin.add_child(column)
	_toolbar = HBoxContainer.new()
	column.add_child(_toolbar)
	_brand = Style.label(_toolbar, "VOXELVERSE", 26, Style.ACCENT)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toolbar.add_child(spacer)
	_details_toggle = _button(_toolbar, "SAVE_VIEW_DETAILS", func() -> void: _show_details = not _show_details; _layout(), "SaveDetailsToggle")
	_button(_toolbar, "SAVE_BROWSER_BACK", _leave, "BackFromSaves")
	_heading = Style.label(column, "DEINE ABENTEUER", 27)
	_tools = VBoxContainer.new()
	column.add_child(_tools)
	var search_row := HBoxContainer.new()
	_tools.add_child(search_row)
	_search = LineEdit.new()
	_search.name = "SearchSaves"
	_search.placeholder_text = "SAVE_SEARCH_PLACEHOLDER"
	_search.tooltip_text = "SAVE_SEARCH_HINT"
	_search.clear_button_enabled = true
	_search.max_length = 128
	_search.custom_minimum_size.y = 48
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_value: String) -> void: _query_pending = true; _query_delay = 0.18)
	search_row.add_child(_search)
	_reset = _button(search_row, "SAVE_FILTER_RESET", _reset_filters, "ResetSaveFilters")
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 8)
	filters.add_theme_constant_override("v_separation", 8)
	_tools.add_child(filters)
	_phase_filter = _choice(filters, "SavePhase", "SAVE_PHASE_HINT")
	_state_filter = _choice(filters, "SaveState", "SAVE_STATE_HINT")
	_sort = _choice(filters, "SaveSort", "SAVE_SORT_HINT")
	_translate_filters()
	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", 20)
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panes)
	_left = VBoxContainer.new()
	panes.add_child(_left)
	_slot_scroll = ScrollContainer.new()
	_slot_scroll.name = "SlotScroll"
	_slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_slot_scroll.follow_focus = true
	_slot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_child(_slot_scroll)
	_list = VBoxContainer.new()
	_list.name = "SlotList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_scroll.add_child(_list)
	var pager := HBoxContainer.new()
	pager.name = "SavePages"
	_left.add_child(pager)
	_previous = _button(pager, "←", func() -> void: _turn_page(-1), "PreviousSavePage")
	_page_label = Style.label(pager, "", 17)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_page_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next = _button(pager, "→", func() -> void: _turn_page(1), "NextSavePage")
	_right = ScrollContainer.new()
	_right.name = "DetailsScroll"
	_right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right.follow_focus = true
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panes.add_child(_right)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 12)
	_right.add_child(_details)
	_status = Style.paragraph(column, "", 19)
	_status.name = "SlotStatus"
	_status.add_theme_color_override("font_color", Style.ACCENT)
	get_viewport().size_changed.connect(_layout)
	resized.connect(_layout)
	_right.resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	refresh()

func refresh(preferred_path: String = "") -> void:
	_remember_selection()
	_preferred_path = preferred_path if not preferred_path.is_empty() else (selected_path if not selected_path.is_empty() else _preferred_path)
	_cancel_scans()
	_left_view = false
	_slots = []
	_filtered = []
	selected_path = ""
	_entries = []
	_name_input = null
	_history = null
	_clear_children(_list)
	_clear_children(_details)
	_scan_label = Style.paragraph(_list, "SAVE_SCAN_DISCOVER")
	_previous.disabled = true
	_next.disabled = true
	_page_label.text = ""
	_show_details = false
	_scan = _saves.begin_slot_scan()
	_layout()

func is_loading() -> bool:
	return _scan != null or _history_scan != null

func _cancel_scans() -> void:
	if _scan != null: _scan.cancel()
	if _history_scan != null: _history_scan.cancel()
	_scan = null
	_history_scan = null

func _exit_tree() -> void:
	_cancel_scans()

func _leave() -> void:
	_cancel_scans()
	_left_view = true
	back_requested.emit()

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		_remember_selection()
		_cancel_scans()
	elif is_node_ready():
		refresh(_preferred_path if selected_path.is_empty() else selected_path)

func _scan_progress() -> void:
	if _scan == null: return
	_scan_label.text = Text.text("SAVE_SCAN_DISCOVER") if _scan.discovering else Text.format_text("SAVE_SCAN_PROGRESS", {"done": _scan.inspected, "total": _scan.paths.size()})

func _advance_scan() -> void:
	if _scan != null:
		if not _scan.advance():
			_scan_progress()
			return
		_slots = _scan.result
		_scan = null
		var paths: Array = _slots.map(func(slot: Dictionary) -> String: return str(slot.path))
		for path: String in _selection_memory.keys():
			if path not in paths: _selection_memory.erase(path)
		_apply_query(_preferred_path, true)
		_preferred_path = ""
	elif _history_scan != null and _history_scan.advance():
		_entries = _history_scan.result
		_history_scan = null
		_finish_history()

func _choice(parent: Node, id: String, hint: String) -> OptionButton:
	var choice := OptionButton.new()
	choice.name = id
	choice.tooltip_text = hint
	choice.custom_minimum_size = Vector2(205, 44)
	choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	choice.fit_to_longest_item = false
	choice.item_selected.connect(func(_index: int) -> void: _apply_query())
	parent.add_child(choice)
	return choice

func _translate_filters() -> void:
	var indices := [_phase_filter.selected, _state_filter.selected, _sort.selected]
	_phase_filter.clear()
	_phase_filter.add_item(Text.text("SAVE_PHASE_ALL"), -1)
	for phase in range(6): _phase_filter.add_item(Dates._phase(phase), phase)
	_state_filter.clear()
	for key: String in STATUS_KEYS: _state_filter.add_item(Text.text(key))
	_sort.clear()
	for key: String in SORT_KEYS: _sort.add_item(Text.text(key))
	_phase_filter.select(maxi(indices[0], 0))
	_state_filter.select(maxi(indices[1], 0))
	_sort.select(maxi(indices[2], 0))

func _process(delta: float) -> void:
	_status.visible = not _status.text.is_empty()
	if not is_visible_in_tree() or _left_view: return
	_advance_scan()
	if not _query_pending: return
	_query_delay -= delta
	if _query_delay <= 0.0: _apply_query()

func _clear_filters() -> void:
	_search.clear()
	_phase_filter.select(0)
	_state_filter.select(0)

func _reset_filters() -> void:
	_clear_filters()
	_apply_query()

func _apply_query(preferred_path: String = "", force_details: bool = false) -> void:
	_query_pending = false
	if _scan != null: return
	_filtered = Query.select(_slots, _search.text, _phase_filter.selected - 1, STATUS_IDS[_state_filter.selected], SORT_IDS[_sort.selected])
	if not preferred_path.is_empty() and Query.page_for(_filtered, preferred_path) < 0 and Query.page_for(_slots, preferred_path) >= 0:
		# After copy/restore/rename the acted-on slot must remain visible.
		_clear_filters()
		_filtered = Query.select(_slots, "", -1, "all", SORT_IDS[_sort.selected])
	var desired := preferred_path if not preferred_path.is_empty() else selected_path
	var found := Query.page_for(_filtered, desired)
	_page = found if found >= 0 else 0
	_query_pending = false
	_render_page(desired, force_details)

func _turn_page(direction: int) -> void:
	if _query_pending:
		_apply_query()
		return
	_page = clampi(_page + direction, 0, maxi(ceili(float(_filtered.size()) / Query.PAGE_SIZE) - 1, 0))
	_render_page()
	_slot_scroll.scroll_vertical = 0

func _render_page(preferred_path: String = "", force_details: bool = false) -> void:
	_clear_children(_list)
	var visible_slots := Query.page(_filtered, _page)
	for slot: Dictionary in visible_slots:
		var button := Button.new()
		button.name = "Slot_" + str(slot.path).get_file().trim_suffix(".json")
		button.toggle_mode = true
		button.set_meta("slot_path", slot.path)
		button.custom_minimum_size = Vector2(0, 120)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): select_slot(str(slot.path)))
		_list.add_child(button)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.offset_left = 12
		margin.offset_top = 12
		margin.offset_right = -12
		margin.offset_bottom = -12
		button.add_child(margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		margin.add_child(row)
		var picture: Control = _preview(slot.preview, 98, false)
		picture.custom_minimum_size.x = 120
		row.add_child(picture)
		var text_column := VBoxContainer.new()
		text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_column)
		var label := Style.label(text_column, str(slot.name), 21)
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size.x = 0
		var phase_label := Style.label(text_column, Dates._phase(int(slot.phase)) + Text.text(" · %d Min.") % int(float(slot.seconds) / 60.0), 17, Style.MUTED)
		phase_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var summary := Style.label(text_column, Text.format_text("SAVE_LIST_SEED", {"seed": slot.seed}) if slot.valid and not slot.recovered else Text.text("SAVE_LIST_BACKUP" if slot.recovered else "Wiederherstellung prüfen"), 17, Style.ACCENT)
		summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_ignore_mouse(margin)
	_previous.disabled = _page <= 0
	_next.disabled = (_page + 1) * Query.PAGE_SIZE >= _filtered.size()
	_page_label.text = Text.format_text("SAVE_PAGE", {"page": _page + 1, "pages": maxi(ceili(float(_filtered.size()) / Query.PAGE_SIZE), 1), "count": _filtered.size(), "total": _slots.size()})
	_previous.tooltip_text = "SAVE_PAGE_PREVIOUS"
	_next.tooltip_text = "SAVE_PAGE_NEXT"
	if visible_slots.is_empty():
		_remember_selection()
		if _history_scan != null: _history_scan.cancel()
		_history_scan = null
		selected_path = ""
		_clear_children(_details)
		_name_input = null
		_history = null
		_entries = []
		Style.paragraph(_list, "Dein erstes Abenteuer beginnt mit „Neues Spiel“." if _slots.is_empty() else "SAVE_NO_RESULTS")
		Style.paragraph(_details, "SAVE_SELECT_RESULT")
		_show_details = false
	else:
		var chosen := preferred_path if not preferred_path.is_empty() else selected_path
		if Query.page_for(visible_slots, chosen) < 0: chosen = str(visible_slots[0].path)
		if force_details or chosen != selected_path: _show_slot(chosen)
		_mark_selection()
	_layout()

func select_slot(path: String) -> void:
	if Query.page_for(_slots, path) < 0: return
	if Query.page_for(_filtered, path) != _page:
		_apply_query(path)
	else:
		_show_slot(path)
	_show_details = true
	_layout()

func _mark_selection() -> void:
	for child in _list.get_children():
		if child is Button: child.set_pressed_no_signal(str(child.get_meta("slot_path")) == selected_path)

func _remember_selection() -> void:
	if selected_path.is_empty() or not is_instance_valid(_name_input) or not _name_input.is_inside_tree(): return
	var source: String = str(_selection_memory.get(selected_path, {}).get("history", ""))
	if _history_loaded and is_instance_valid(_history) and _history.is_inside_tree() and _history.selected >= 0 and _history.selected < _entries.size():
		source = str(_entries[_history.selected].source)
	_selection_memory[selected_path] = {"name": _name_input.text, "history": source}

func _show_slot(path: String) -> void:
	_remember_selection()
	selected_path = path
	_clear_children(_details)
	_name_input = null
	_history = null
	if _history_scan != null: _history_scan.cancel()
	_history_scan = null
	_history_loaded = false
	_entries = []
	var slot: Dictionary = {}
	for candidate: Dictionary in _slots:
		if candidate.path == path: slot = candidate; break
	if slot.is_empty(): return
	_mark_selection()
	var overview := BoxContainer.new()
	_overview = overview
	overview.add_theme_constant_override("separation", 18)
	_details.add_child(overview)
	var picture: Control = _preview(slot.preview, 190)
	_detail_picture = picture
	picture.custom_minimum_size.x = 300
	overview.add_child(picture)
	var summary := VBoxContainer.new()
	_detail_summary = summary
	summary.custom_minimum_size.x = 0
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.add_child(summary)
	var heading := Style.label(summary, str(slot.name), 27)
	heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var text: String = Text.format_text("SAVE_OVERVIEW", {
		"planet": int(slot.planet_index) + 1, "seed": int(slot.seed), "phase": Dates._phase(int(slot.phase)),
		"minutes": int(float(slot.seconds) / 60.0), "time": _date(int(slot.saved_time))})
	if not slot.valid:
		text = str(slot.problem)
	elif slot.recovered:
		text += Text.text("\nDie letzte Sicherung ist verfügbar.")
	Style.paragraph(summary, text, 19)
	var load_button := _button(_details, "Auf Kugelwelt fortsetzen" if slot.surface_mode == "legacy_plane_v9" else "Abenteuer laden", func(): get_node("/root/SessionFlow").load_game(selected_path), "LoadAdventure", true)
	load_button.disabled = not slot.valid
	var rename_row := HBoxContainer.new()
	_details.add_child(rename_row)
	_name_input = LineEdit.new()
	_name_input.name = "SlotName"
	_name_input.text = str(_selection_memory.get(path, {}).get("name", slot.name))
	_name_input.max_length = 48
	_name_input.placeholder_text = "Name des Abenteuers"
	_name_input.custom_minimum_size.y = 50
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.editable = slot.valid
	rename_row.add_child(_name_input)
	var rename := _button(rename_row, "Umbenennen", _rename, "RenameSlot")
	rename.disabled = not slot.valid
	var copy := _button(_details, "Spielstand kopieren", _copy, "CopySlot")
	copy.disabled = not slot.valid or int(slot.schema) < 3
	Style.paragraph(_details, "Kugelwelt" if slot.surface_mode == "cube_sphere_m1_v1" else "Älterer Spielstand · beim Fortsetzen wird eine Kugelkopie angelegt. Das Original bleibt erhalten.", 17)
	if slot.valid and slot.surface_mode == "legacy_plane_v9":
		_button(_details, "Kugelumzug prüfen", _preview_migration, "PreviewSphereMigration")
	if slot.valid and slot.has_migration_archive:
		_button(_details, "Originalarchiv als Kopie sichern", func() -> void:
			var restored: String = _saves.restore_spherical_source(selected_path)
			if restored.is_empty(): _status.text = _saves.last_error
			else:
				refresh(restored)
				_status.text = "Originaldaten und ursprüngliche Karten als eigene Archivkopie gesichert.", "RestoreMigrationSource")
	if slot.valid and int(slot.schema) < 3:
		Style.paragraph(_details, "Prüfe den Kugelumzug dieses älteren Spielstands. Seine Originaldaten bleiben erhalten.", 17)
	_details.add_child(HSeparator.new())
	_history_label = Style.label(_details, "SAVE_HISTORY_LOADING", 21, Style.ACCENT)
	Style.paragraph(_details, "Bis zu acht frühere Speicherstände. Eine Wiederherstellung legt ein neues Abenteuer an.", 17)
	_history = OptionButton.new()
	_history.name = "HistoryChoice"
	_history.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_history.custom_minimum_size.y = 48
	_details.add_child(_history)
	_history.disabled = true
	_history.visible = false
	_restore_button = _button(_details, "Sicherung als Kopie wiederherstellen", _restore, "RestoreSlot")
	_restore_button.disabled = true
	_restore_button.visible = false
	_history_preview = VBoxContainer.new()
	_details.add_child(_history_preview)
	_history.item_selected.connect(_select_history)
	_history_scan = _saves.begin_history_scan(path)
	_layout()

func _finish_history() -> void:
	_history_loaded = true
	_history_label.text = Text.plural("SAVE_BACKUPS", "SAVE_BACKUPS_PLURAL", _entries.size())
	_history.clear()
	for entry: Dictionary in _entries:
		var label: String = Text.format_text("SAVE_HISTORY_ENTRY", {"time": _date(int(entry.saved_time)), "minutes": int(float(entry.seconds) / 60.0), "reason": _reason(str(entry.reason))})
		if not entry.can_copy: label += Text.text(" · nicht ladbar")
		_history.add_item(label)
	_history.disabled = _entries.is_empty()
	_history.visible = not _entries.is_empty()
	_restore_button.visible = not _entries.is_empty()
	var remembered: String = str(_selection_memory.get(selected_path, {}).get("history", ""))
	var history_index := 0
	for index in _entries.size():
		if str(_entries[index].source) == remembered: history_index = index; break
	if not _entries.is_empty(): _history.select(history_index)
	_select_history(history_index)
	_layout()

func _select_history(index: int) -> void:
	if not _history_loaded: return
	_clear_children(_history_preview)
	_restore_button.disabled = _entries.is_empty() or index < 0 or index >= _entries.size() or not bool(_entries[index].can_copy)
	if _entries.is_empty():
		Style.paragraph(_history_preview, "Nach dem nächsten Speichern erscheint hier dein vorheriger Stand.", 17)
		return
	var entry: Dictionary = _entries[index]
	_history_preview.add_child(_preview(entry.preview, 135))
	if not entry.valid:
		Style.paragraph(_history_preview, str(entry.problem), 17)

func _preview_migration() -> void:
	_remember_selection()
	if _history_scan != null: _history_scan.cancel()
	_history_scan = null
	var source: String = selected_path
	var preview: Dictionary = _saves.preview_spherical_migration(source)
	if not preview.ok:
		_clear_children(_details)
		Style.label(_details, "UMZUG NOCH NICHT MÖGLICH", 25)
		for problem in preview.blockers:
			Style.paragraph(_details, str(problem), 18)
		_button(_details, "Zurück zum Spielstand", func() -> void: select_slot(source), "BackFromMigrationBlockers")
		_status.text = "Das Original bleibt vollständig erhalten. Für diesen Spielstand muss der Kugelumzug noch ergänzt werden."
		return
	_clear_children(_details)
	Style.label(_details, "KUGELKOPIE PRÜFEN", 25)
	Style.paragraph(_details, "Die geprüfte Kopie übernimmt Entwürfe, Fortschritt, Heimat, Bewohner, Tierbesitz, Vorräte und laufende Lieferungen. Bekannte Orte erhalten neue Plätze auf der Kugel. Die ursprüngliche Landschaft und ihre Karten bleiben im Quellarchiv erhalten.")
	Style.paragraph(_details, "Du setzt das Abenteuer auf einem Kugelplaneten fort. Dein bisheriger Spielstand bleibt als Original erhalten.")
	var manifest: Dictionary = preview.manifest
	Style.paragraph(_details, "Körper: %d · Entwurfsdateien: %d\nQuell-Hash: %s\nManifest: %s\nOriginal und vollständiges Quellarchiv bleiben erhalten." % [
		manifest.inventory.body_count, preview.data.design_files.size(), str(manifest.source_sha256).left(16), str(manifest.id).left(16)], 17)
	_button(_details, "Geprüfte Kugelkopie anlegen", func() -> void:
		var target: String = _saves.migrate_slot_to_sphere(source, manifest.source_sha256)
		if target.is_empty(): _status.text = _saves.last_error
		else:
			refresh(target)
			_status.text = "Kugelkopie geschrieben, zurückgelesen und geprüft. Das Original ist weiterhin verfügbar.", "CommitSphereMigration", true)
	_button(_details, "Zurück zum Spielstand", func() -> void: select_slot(source), "CancelSphereMigration")

func _rename() -> void:
	if selected_path.is_empty() or _scan != null: return
	var renamed: bool = _saves.rename_slot(selected_path, _name_input.text)
	if renamed:
		refresh(selected_path)
	_status.text = "Abenteuer umbenannt." if renamed else _saves.last_error

func _copy() -> void:
	if selected_path.is_empty() or _scan != null: return
	var copied: String = _saves.duplicate_slot(selected_path)
	if not copied.is_empty():
		refresh(copied)
	_status.text = "Kopie angelegt. Wähle „Abenteuer laden“, um sie weiterzuspielen." if not copied.is_empty() else _saves.last_error

func _restore() -> void:
	if not _history_loaded or _history_scan != null or not is_instance_valid(_history): return
	var index: int = _history.selected
	if index < 0 or index >= _entries.size():
		return
	var copied: String = _saves.restore_slot_copy(selected_path, str(_entries[index].source))
	if not copied.is_empty():
		refresh(copied)
	_status.text = "Sicherung als neues Abenteuer wiederhergestellt. Der bisherige Stand bleibt erhalten." if not copied.is_empty() else _saves.last_error

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _left_view: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()

static func _preview(value: Dictionary, height: int, explain: bool = true) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = height
	panel.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.EDGE, 0))
	var texture := TextureRect.new()
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(texture)
	var encoded: String = str(value.get("png", ""))
	if encoded.length() > 0 and encoded.length() <= 700000:
		var bytes: PackedByteArray = Marshalls.base64_to_raw(encoded)
		var picture := Image.new()
		if bytes.size() >= 24 and bytes.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
			if picture.load_png_from_buffer(bytes) == OK and not picture.is_empty():
				texture.texture = ImageTexture.create_from_image(picture)
	if texture.texture == null:
		var fallback := Style.paragraph(panel, "Das Vorschaubild entsteht beim Spielen." if explain else "VOXEL\nVERSE", 18)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return panel

static func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

static func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Control in control.get_children():
		_ignore_mouse(child)

static func _date(unix_time: int) -> String:
	return Text.date_time(unix_time, true)

static func _reason(reason: String) -> String:
	return Text.text({"automatic": "Auto", "manual": "Speichern", "rename": "Vor Umbenennen", "backup": "Letzte Sicherung"}.get(reason, "Sicherung"))

func _language_changed(_locale: String) -> void:
	if _scan != null:
		_translate_filters()
		_scan_progress()
		return
	var focus := get_viewport().gui_get_focus_owner()
	var editing_name: bool = focus == _name_input and is_instance_valid(_name_input)
	var caret: int = _name_input.caret_column if editing_name else 0
	var list_scroll := _slot_scroll.scroll_vertical
	var detail_scroll := _right.scroll_vertical
	_translate_filters()
	_render_page(selected_path, true)
	if editing_name and is_instance_valid(_name_input):
		_name_input.grab_focus()
		_name_input.caret_column = caret
	_slot_scroll.scroll_vertical = list_scroll
	_right.scroll_vertical = detail_scroll

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if (event.ctrl_pressed or event.meta_pressed) and event.keycode == KEY_F:
		_show_details = false
		_layout()
		_search.grab_focus()
		_search.select_all()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and _search.has_focus():
		_search.release_focus()
		get_viewport().set_input_as_handled()

func _layout() -> void:
	if not is_instance_valid(_right): return
	var extent := get_viewport_rect().size
	_compact = extent.x < 1200
	var short_window: bool = extent.y < 500
	var inset: int = 20 if _compact else 48
	var column := _margin.get_child(0) as VBoxContainer
	column.add_theme_constant_override("separation", 8 if short_window else 12)
	for child in _toolbar.get_children():
		if child is Button: child.custom_minimum_size.y = 44 if short_window else 56
	for button: Button in [_reset, _previous, _next]:
		button.custom_minimum_size.y = 44 if short_window else 56
	for choice: OptionButton in [_phase_filter, _state_filter, _sort]:
		choice.custom_minimum_size.x = minf(205, floorf((extent.x - inset * 2 - 16) / 3.0))
	_margin.offset_left = inset
	_margin.offset_right = -inset
	_margin.offset_top = 8 if short_window else 16
	_margin.offset_bottom = -8 if short_window else -16
	_brand.visible = extent.x >= 650
	_heading.visible = extent.y >= 650 and not _compact
	_details_toggle.visible = _compact
	_details_toggle.disabled = selected_path.is_empty()
	_details_toggle.text = "SAVE_VIEW_RESULTS" if _show_details else "SAVE_VIEW_DETAILS"
	_tools.visible = not (_compact and _show_details)
	_left.visible = not (_compact and _show_details)
	_right.visible = not _compact or _show_details
	_left.custom_minimum_size.x = 0 if _compact else 440
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_FILL
	if is_instance_valid(_overview) and _overview.is_inside_tree():
		_overview.vertical = _compact or _right.size.x < 780
		_detail_picture.custom_minimum_size = Vector2(0 if _overview.vertical else 300, 135 if _overview.vertical else 190)
		_detail_summary.custom_minimum_size.x = 0

static func _button(parent: Node, text: String, action: Callable, id: String = "", primary: bool = false) -> Button:
	var button := Style.button(parent, text, action, id, primary)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button
