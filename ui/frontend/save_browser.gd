extends Control

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
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 80
	margin.offset_top = 36
	margin.offset_right = -80
	margin.offset_bottom = -30
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	Style.label(toolbar, "VOXELVERSE", 30, Style.ACCENT)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	Style.button(toolbar, "Zurück zum Startmenü", func(): back_requested.emit(), "BackFromSaves")
	Style.label(column, "DEINE ABENTEUER", 27)
	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", 24)
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panes)
	var left := ScrollContainer.new()
	left.name = "SlotScroll"
	left.custom_minimum_size.x = 470
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.follow_focus = true
	panes.add_child(left)
	_list = VBoxContainer.new()
	_list.name = "SlotList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_list)
	var right := ScrollContainer.new()
	right.name = "DetailsScroll"
	right.custom_minimum_size.x = 540
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.follow_focus = true
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panes.add_child(right)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 12)
	right.add_child(_details)
	_status = Style.paragraph(column, "", 19)
	_status.name = "SlotStatus"
	_status.custom_minimum_size.y = 52
	_status.add_theme_color_override("font_color", Style.ACCENT)
	refresh()

func refresh(preferred_path: String = "") -> void:
	_slots = _saves.list_slots()
	_clear_children(_list)
	for slot: Dictionary in _slots:
		var button := Button.new()
		button.name = "Slot_" + str(slot.path).get_file().trim_suffix(".json")
		button.toggle_mode = true
		button.set_meta("slot_path", slot.path)
		button.custom_minimum_size = Vector2(450, 128)
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
		picture.custom_minimum_size.x = 150
		row.add_child(picture)
		var text_column := VBoxContainer.new()
		text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_column)
		var label := Style.label(text_column, str(slot.name), 21)
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size.x = 220
		Style.label(text_column, Dates._phase(int(slot.phase)) + Text.text(" · %d Min.") % int(float(slot.seconds) / 60.0), 17, Style.MUTED)
		Style.label(text_column, Text.text("Planet %d") % (int(slot.planet_index) + 1) if slot.valid else "Wiederherstellung prüfen", 17, Style.ACCENT)
		_ignore_mouse(margin)
	if _slots.is_empty():
		Style.paragraph(_list, "Dein erstes Abenteuer beginnt mit „Neues Spiel“.")
		_clear_children(_details)
		return
	var chosen: String = preferred_path if not preferred_path.is_empty() else selected_path
	if not _slots.any(func(slot: Dictionary): return str(slot.path) == chosen):
		chosen = str(_slots[0].path)
	select_slot(chosen)

func select_slot(path: String) -> void:
	selected_path = path
	_clear_children(_details)
	var slot: Dictionary = _saves.inspect_slot(path)
	for child: Button in _list.get_children():
		child.set_pressed_no_signal(str(child.get_meta("slot_path")) == path)
	var overview := HBoxContainer.new()
	overview.add_theme_constant_override("separation", 18)
	_details.add_child(overview)
	var picture: Control = _preview(slot.preview, 190)
	picture.custom_minimum_size.x = 340
	overview.add_child(picture)
	var summary := VBoxContainer.new()
	summary.custom_minimum_size.x = 180
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
	var load_button := Style.button(_details, "Abenteuer laden", func(): get_node("/root/SessionFlow").load_game(selected_path), "LoadAdventure", true)
	load_button.disabled = not slot.valid
	var rename_row := HBoxContainer.new()
	_details.add_child(rename_row)
	_name_input = LineEdit.new()
	_name_input.name = "SlotName"
	_name_input.text = str(slot.name)
	_name_input.max_length = 48
	_name_input.placeholder_text = "Name des Abenteuers"
	_name_input.custom_minimum_size.y = 50
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.editable = slot.valid
	rename_row.add_child(_name_input)
	var rename := Style.button(rename_row, "Umbenennen", _rename, "RenameSlot")
	rename.disabled = not slot.valid
	var copy := Style.button(_details, "Spielstand kopieren", _copy, "CopySlot")
	copy.disabled = not slot.valid or int(slot.schema) < 3
	Style.paragraph(_details, "Kugelwelt" if slot.surface_mode == "cube_sphere_m1_v1" else "Bisherige Flachwelt", 17)
	if slot.valid and slot.surface_mode == "legacy_plane_v9":
		Style.button(_details, "Kugelumzug prüfen", _preview_migration, "PreviewSphereMigration")
	if slot.valid and slot.has_migration_archive:
		Style.button(_details, "Flachwelt aus Umzugsarchiv kopieren", func() -> void:
			var restored: String = _saves.restore_spherical_source(selected_path)
			if restored.is_empty(): _status.text = _saves.last_error
			else:
				refresh(restored)
				_status.text = "Flachwelt mit den ursprünglichen Karten als eigene Kopie wiederhergestellt.", "RestoreMigrationSource")
	if slot.valid and int(slot.schema) < 3:
		Style.paragraph(_details, "Diesen älteren Stand einmal laden und speichern, um auch seine Entwürfe kopieren zu können.", 17)
	_details.add_child(HSeparator.new())
	_entries = _saves.list_slot_history(selected_path)
	Style.label(_details, Text.plural("SAVE_BACKUPS", "SAVE_BACKUPS_PLURAL", _entries.size()), 21, Style.ACCENT)
	Style.paragraph(_details, "Bis zu acht frühere Speicherstände. Eine Wiederherstellung legt ein neues Abenteuer an.", 17)
	_history = OptionButton.new()
	_history.name = "HistoryChoice"
	_history.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_history.custom_minimum_size.y = 48
	_details.add_child(_history)
	for entry: Dictionary in _entries:
		var label: String = Text.format_text("SAVE_HISTORY_ENTRY", {"time": _date(int(entry.saved_time)), "minutes": int(float(entry.seconds) / 60.0), "reason": _reason(str(entry.reason))})
		if not entry.can_copy:
			label += Text.text(" · nicht ladbar")
		_history.add_item(label)
	_history.disabled = _entries.is_empty()
	_history.visible = not _entries.is_empty()
	_restore_button = Style.button(_details, "Sicherung als Kopie wiederherstellen", _restore, "RestoreSlot")
	_restore_button.visible = not _entries.is_empty()
	_history_preview = VBoxContainer.new()
	_details.add_child(_history_preview)
	_history.item_selected.connect(_select_history)
	_select_history(0)

func _select_history(index: int) -> void:
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
	var source: String = selected_path
	var preview: Dictionary = _saves.preview_spherical_migration(source)
	if not preview.ok:
		_clear_children(_details)
		Style.label(_details, "UMZUG NOCH NICHT MÖGLICH", 25)
		for problem in preview.blockers:
			Style.paragraph(_details, str(problem), 18)
		Style.button(_details, "Zurück zum Spielstand", func() -> void: select_slot(source), "BackFromMigrationBlockers")
		_status.text = "Die Quelle bleibt vollständig erhalten und kann weiter als Flachwelt geladen werden."
		return
	_clear_children(_details)
	Style.label(_details, "KUGELKOPIE PRÜFEN", 25)
	Style.paragraph(_details, "Diese Kopie übernimmt Identitäten, Entwürfe und Fortschritt. Der Spieler erhält einen geprüften Startplatz. Alte Karten bleiben im Quellarchiv; die neue Kugelkarte beginnt unerforscht.")
	Style.paragraph(_details, "Auf der Kugel funktionieren derzeit Bewegung, Karte und Speichern. Nahrung, Begegnungen und Siedlungen folgen.")
	var manifest: Dictionary = preview.manifest
	Style.paragraph(_details, "Körper: %d · Entwurfsdateien: %d\nQuell-Hash: %s\nManifest: %s\nOriginal und vollständiges Quellarchiv bleiben erhalten." % [
		manifest.inventory.body_count, preview.data.design_files.size(), str(manifest.source_sha256).left(16), str(manifest.id).left(16)], 17)
	Style.button(_details, "Geprüfte Kugelkopie anlegen", func() -> void:
		var target: String = _saves.migrate_slot_to_sphere(source, manifest.source_sha256)
		if target.is_empty(): _status.text = _saves.last_error
		else:
			refresh(target)
			_status.text = "Kugelkopie geschrieben, zurückgelesen und geprüft. Das Original ist weiterhin verfügbar.", "CommitSphereMigration", true)
	Style.button(_details, "Zurück zum Spielstand", func() -> void: select_slot(source), "CancelSphereMigration")

func _rename() -> void:
	var renamed: bool = _saves.rename_slot(selected_path, _name_input.text)
	if renamed:
		refresh(selected_path)
	_status.text = "Abenteuer umbenannt." if renamed else _saves.last_error

func _copy() -> void:
	var copied: String = _saves.duplicate_slot(selected_path)
	if not copied.is_empty():
		refresh(copied)
	_status.text = "Kopie angelegt. Wähle „Abenteuer laden“, um sie weiterzuspielen." if not copied.is_empty() else _saves.last_error

func _restore() -> void:
	var index: int = _history.selected
	if index < 0 or index >= _entries.size():
		return
	var copied: String = _saves.restore_slot_copy(selected_path, str(_entries[index].source))
	if not copied.is_empty():
		refresh(copied)
	_status.text = "Sicherung als neues Abenteuer wiederhergestellt. Der bisherige Stand bleibt erhalten." if not copied.is_empty() else _saves.last_error

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()

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
	# Preserve an unsaved rename and the selected backup while rebuilding dates.
	var draft: String = _name_input.text if is_instance_valid(_name_input) else ""
	var history_index: int = _history.selected if is_instance_valid(_history) else -1
	refresh(selected_path)
	if is_instance_valid(_name_input):
		_name_input.text = draft
	if is_instance_valid(_history) and history_index >= 0 and history_index < _history.item_count:
		_history.select(history_index)
		_select_history(history_index)
