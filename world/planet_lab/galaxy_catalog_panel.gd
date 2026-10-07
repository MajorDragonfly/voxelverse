extends CanvasLayer

const Catalog = preload("res://world/space/galaxy_catalog.gd")
const Journal = preload("res://world/space/galaxy_journal.gd")
const Presentation = preload("res://world/planet_lab/galaxy_browser_presentation.gd")
const Design = preload("res://ui/design/design_system.gd")
const Symbols = preload("res://ui/design/game_symbols.gd")
signal closed
signal visit_requested(system_id: String, body_id: String)
var initial_system_id: String = ""
var travel_in_progress: bool = false
var body_list: OptionButton
var visit_button: Button
var catalog: RefCounted = Catalog.new()
var journal: RefCounted
var journal_directory: String = "user://galaxy_m1c"
var systems: Array = []
var selected_id: String = ""
var selected_index: int = -1
var record: Dictionary = {}
var _dirty: bool = false
var _loading: bool = false
var _storage_error: Error = OK
var coordinates: Array[SpinBox] = []
var system_list: ItemList
var description: RichTextLabel
var custom_name: LineEdit
var note: TextEdit
var discovered: CheckBox
var message: Label
var save_button: Button
var discard_button: Button
# Optional existing store's read method, supplied by its owner. Never open/write visits here.
var visit_reader: Callable
var _visit: Dictionary = {}
var _system: Dictionary = {}
var _origin: Dictionary = {}
var _visible_indices: Array[int] = []
var _page: int = 0
var search: LineEdit
var sector_label: Label
var page_label: Label
var previous_page: Button
var next_page: Button
var body_description: RichTextLabel
var inspection_list: OptionButton
var _content: BoxContainer
var _column: VBoxContainer
var _shade: ColorRect

func _ready() -> void:
	name = "GalaxyCatalog"
	layer = 80
	add_to_group(&"galaxy_catalog_overlay")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	journal = Journal.new(catalog, journal_directory)
	_storage_error = journal.open()
	var initial: Dictionary = catalog.system(initial_system_id)
	_origin = initial.get("position", {})
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	var address: Dictionary = Catalog.Address.parse(initial_system_id)
	show_sector(address.sector if not initial.is_empty() else [0, 0, 0])
	if address.get("kind") == "system" and not initial.is_empty():
		for index in range(systems.size()):
			if systems[index].id == initial_system_id:
				_page = index / Presentation.PAGE_SIZE
				_render_page()
				select_system(index)

func _build() -> void:
	_shade = ColorRect.new()
	_shade.theme = Design.theme()
	_shade.color = Color(Design.INK, 0.97)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(_shade)
	var scroll := ScrollContainer.new()
	scroll.name = "GalaxyScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shade.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	scroll.add_child(margin)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 10)
	margin.add_child(_column)
	var title := Label.new()
	title.text = Presentation.text("GALAXY_TITLE", "VOXELVERSE  /  GALAXIEKATALOG")
	title.add_theme_font_size_override("font_size", 24)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Design.ACCENT)
	_column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = Presentation.text("GALAXY_SUBTITLE", "Referenzgalaxie · 100.000 Lichtjahre Durchmesser · Sektorkante 16 Lichtjahre")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Design.MUTED)
	_column.add_child(subtitle)
	var row := HFlowContainer.new()
	_column.add_child(row)
	_button(row, "Zentrum", func(): show_sector([0, 0, 0]))
	_button(row, "Innenarm", func(): show_sector([1000, 0, -700]))
	_button(row, "Außenrand", func(): show_sector([-2400, 0, 800]))
	_button(row, "Zurück zum Planeten", close).name = "CloseGalaxy"
	var sectors := HFlowContainer.new()
	_column.add_child(sectors)
	for axis in ["X", "Y", "Z"]:
		var axis_row := HBoxContainer.new()
		sectors.add_child(axis_row)
		var label := Label.new()
		label.text = "Sektor " + axis
		axis_row.add_child(label)
		var input := SpinBox.new()
		input.min_value = -Catalog.Address.MAX_SECTOR
		input.max_value = Catalog.Address.MAX_SECTOR
		input.step = 1
		input.custom_minimum_size.x = 155
		input.name = "Sector" + axis
		axis_row.add_child(input)
		coordinates.append(input)
	_button(sectors, "Anzeigen", func(): show_sector([int(coordinates[0].value), int(coordinates[1].value), int(coordinates[2].value)])).name = "ShowGalaxySector"
	sector_label = Label.new()
	sector_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_column.add_child(sector_label)
	var query_row := HBoxContainer.new()
	_column.add_child(query_row)
	search = LineEdit.new()
	search.name = "GalaxySearch"
	search.placeholder_text = Presentation.text("GALAXY_SEARCH", "Name im Sektor oder vollständige Sektor-/System-/Körperkennung")
	search.tooltip_text = Presentation.text("GALAXY_SEARCH_HELP", "Namen filtern nur diesen Sektor. Vollständige vx1-Kennungen öffnen vorhandene Katalogeinträge.")
	search.max_length = Presentation.SEARCH_LIMIT
	search.keep_editing_on_text_submit = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_submitted.connect(func(_value: String): search_catalog())
	query_row.add_child(search)
	_button(query_row, "Suchen", search_catalog).name = "SearchGalaxy"
	_button(query_row, "Leeren", func(): search.text = ""; search_catalog()).name = "ClearGalaxySearch"
	_content = BoxContainer.new()
	_content.add_theme_constant_override("separation", 20)
	_column.add_child(_content)
	var systems_column := VBoxContainer.new()
	systems_column.custom_minimum_size.x = 285
	systems_column.size_flags_horizontal = Control.SIZE_FILL
	_content.add_child(systems_column)
	system_list = ItemList.new()
	system_list.name = "GalaxySystems"
	system_list.custom_minimum_size.y = 150
	system_list.item_selected.connect(func(row_index: int): select_system(int(system_list.get_item_metadata(row_index))))
	systems_column.add_child(system_list)
	var pages := HFlowContainer.new()
	systems_column.add_child(pages)
	previous_page = _button(pages, "‹", func(): change_page(-1))
	previous_page.name = "PreviousGalaxyPage"
	page_label = Label.new()
	pages.add_child(page_label)
	next_page = _button(pages, "›", func(): change_page(1))
	next_page.name = "NextGalaxyPage"
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(detail)
	description = RichTextLabel.new()
	description.name = "GalaxySystemDetails"
	description.fit_content = true
	description.scroll_active = false
	description.selection_enabled = true
	detail.add_child(description)
	inspection_list = OptionButton.new()
	inspection_list.name = "InspectGalaxyBody"
	inspection_list.fit_to_longest_item = false
	inspection_list.item_selected.connect(func(_index: int): _inspect_body())
	detail.add_child(inspection_list)
	body_list = OptionButton.new()
	body_list.name = "GalaxyBodies"
	body_list.fit_to_longest_item = false
	body_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_list.item_selected.connect(func(_index: int): _select_body())
	detail.add_child(body_list)
	body_description = RichTextLabel.new()
	body_description.name = "GalaxyBodyDetails"
	body_description.fit_content = true
	body_description.scroll_active = false
	body_description.selection_enabled = true
	detail.add_child(body_description)
	var unit_help := Label.new()
	unit_help.text = Presentation.text("GALAXY_UNITS", "km = Kilometer · AU = astronomische Einheit · 1 AU ≈ 149,6 Mio. km")
	unit_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_help.add_theme_color_override("font_color", Design.MUTED)
	detail.add_child(unit_help)
	var destination_label := Label.new()
	destination_label.text = Presentation.text("GALAXY_DESTINATION", "Begehbares Reiseziel")
	detail.add_child(destination_label)
	detail.move_child(body_list, detail.get_child_count() - 1)
	visit_button = _button(detail, "Oberfläche besuchen", request_visit)
	visit_button.name = "VisitGalaxyBody"
	custom_name = LineEdit.new()
	custom_name.placeholder_text = "Eigener Systemname (optional)"
	custom_name.max_length = 80
	custom_name.text_changed.connect(func(_text: String): _changed())
	detail.add_child(custom_name)
	note = TextEdit.new()
	note.placeholder_text = "Notiz zum Sternsystem"
	note.custom_minimum_size.y = 68
	note.text_changed.connect(_changed)
	detail.add_child(note)
	var actions := HFlowContainer.new()
	detail.add_child(actions)
	discovered = CheckBox.new()
	discovered.text = "Als entdeckt markieren"
	discovered.toggled.connect(func(_value: bool): _changed())
	actions.add_child(discovered)
	save_button = _button(actions, "Notiz speichern", save_changes)
	save_button.name = "SaveGalaxyNote"
	discard_button = _button(actions, "Ohne Änderung zurück", func(): closed.emit(); queue_free())
	discard_button.hide()
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", Design.ACCENT)
	_column.add_child(message)
	_column.move_child(message, query_row.get_index() + 1)

func _layout() -> void:
	var logical: Vector2 = get_viewport().get_visible_rect().size
	var display: Node = get_node_or_null("/root/DisplaySettings")
	var ui_scale: float = clampf(float(display.ui_scale), 1.0, 1.5) if display != null else 1.0
	var factor: float = logical.x / maxf(float(get_window().size.x), 1.0) * ui_scale
	transform = Transform2D(0.0, Vector2.ONE * factor, 0.0, Vector2.ZERO)
	var viewport_size: Vector2 = logical / factor
	_shade.size = viewport_size
	_content.vertical = viewport_size.x < 950
	_column.custom_minimum_size.y = maxf(0, viewport_size.y - 40)

func show_sector(axes: Array) -> void:
	if travel_in_progress or not _save_pending():
		return
	var sector: Dictionary = catalog.sector_at(axes)
	if sector.is_empty():
		message.text = "Diese Sektoradresse ist ungültig."
		return
	for axis in range(3):
		coordinates[axis].value = int(axes[axis])
	systems = sector.systems
	search.text = ""
	_page = 0
	_visible_indices = Presentation.matching_indices(systems, "")
	sector_label.text = Presentation.text("GALAXY_SECTOR", "Sektor: {id} · {count} Systeme", {"id": sector.id, "count": systems.size()})
	selected_id = ""
	selected_index = -1
	_render_page()
	message.text = Presentation.text("GALAXY_BROWSE_HELP", "Kennungen lassen sich kopieren. Besuchsdaten werden nur gelesen; eine Suche startet keine Reise.") if _storage_error == OK else "Katalog lesbar; gespeicherte Notizen nicht verfügbar: " + error_string(_storage_error)
	if not systems.is_empty():
		select_system(0)
	else:
		_clear_details(Presentation.text("GALAXY_EMPTY_SECTOR", "In diesem Sektor sind keine Sterne verzeichnet."))

func _render_page() -> void:
	var pages: int = maxi(1, ceili(float(_visible_indices.size()) / Presentation.PAGE_SIZE))
	_page = clampi(_page, 0, pages - 1)
	system_list.clear()
	for offset in range(_page * Presentation.PAGE_SIZE, mini((_page + 1) * Presentation.PAGE_SIZE, _visible_indices.size())):
		var index: int = _visible_indices[offset]
		var system: Dictionary = systems[index]
		var row: int = system_list.item_count
		var type: String = Presentation.text("GALAXY_BINARY", "Doppelstern") if system.star_count == 2 else Presentation.text("GALAXY_SINGLE", "Einzelstern")
		system_list.add_item(system.name + " · " + type)
		system_list.set_item_metadata(row, index)
		system_list.set_item_tooltip(row, system.id)
		if index == selected_index:
			system_list.select(row)
	page_label.text = Presentation.text("GALAXY_PAGE", "Seite {page}/{pages} · {count} Treffer", {"page": _page + 1, "pages": pages, "count": _visible_indices.size()})
	previous_page.disabled = _page == 0
	next_page.disabled = _page + 1 >= pages

func change_page(direction: int) -> void:
	if travel_in_progress or not _save_pending():
		return
	var target: int = _page + direction
	if target < 0 or target * Presentation.PAGE_SIZE >= _visible_indices.size():
		return
	_page = target
	_render_page()
	select_system(_visible_indices[_page * Presentation.PAGE_SIZE])

func search_catalog() -> void:
	if travel_in_progress or not _save_pending():
		return
	var query: String = search.text.strip_edges()
	if query.begins_with("vx") or "/" in query:
		var address: Dictionary = Presentation.resolve(catalog, query)
		if address.is_empty():
			message.text = Presentation.text("GALAXY_SEARCH_INVALID", "Diese Kennung ist ungültig, gehört zu einer anderen Galaxie oder ist nicht im Katalog vorhanden.")
			return
		show_sector(address.sector)
		if address.kind != "sector":
			for index in range(systems.size()):
				if systems[index].id == address.system_id:
					_page = index / Presentation.PAGE_SIZE
					_render_page()
					select_system(index)
					break
		if address.kind == "body":
			for index in range(body_list.item_count):
				if body_list.get_item_metadata(index) == address.body_id:
					inspection_list.select(index)
					_inspect_body()
		search.text = query
		return
	_visible_indices = Presentation.matching_indices(systems, query)
	message.text = Presentation.text("GALAXY_BROWSE_HELP", "Kennungen lassen sich kopieren. Besuchsdaten werden nur gelesen; eine Suche startet keine Reise.")
	_page = 0
	_render_page()
	if _visible_indices.is_empty():
		selected_index = -1
		selected_id = ""
		message.text = Presentation.text("GALAXY_NO_RESULTS", "Keine Treffer in diesem Sektor. Eine vollständige Kennung öffnet einen anderen Sektor.")
		_clear_details(message.text)
	else:
		select_system(_visible_indices[0])

func _clear_details(label: String) -> void:
	body_list.clear()
	inspection_list.clear()
	body_description.text = ""
	visit_button.disabled = true
	record = {}
	_system = {}
	_visit = {}
	description.text = label
	_set_fields({}, false)

func select_system(index: int) -> void:
	if travel_in_progress or index < 0 or index >= systems.size():
		return
	if not _save_pending():
		_render_page()
		return
	selected_index = index
	selected_id = systems[index].id
	for row in range(system_list.item_count):
		if system_list.get_item_metadata(row) == index:
			system_list.select(row)
	_system = catalog.system(selected_id)
	var position: Array = _system.position.offset_ly
	var type: String = Presentation.text("GALAXY_BINARY", "Doppelstern") if _system.star_count == 2 else Presentation.text("GALAXY_SINGLE", "Einzelstern")
	var lines: PackedStringArray = [_system.name + " · " + type, selected_id,
		Presentation.text("GALAXY_POSITION", "Position innerhalb des Sektors: {x} / {y} / {z} Lichtjahre", {"x": _number(position[0]), "y": _number(position[1]), "z": _number(position[2])})]
	if not _origin.is_empty():
		lines.append(Presentation.text("GALAXY_DISTANCE", "Entfernung zum Ausgangssystem: {value}", {"value": Presentation.distance_ly(_system.position, _origin)}))
	description.text = "\n".join(lines)
	body_list.clear()
	inspection_list.clear()
	var first_landable: int = -1
	for body: Dictionary in Presentation.ordered_bodies(_system):
		var body_index: int = body_list.item_count
		body_list.add_item(body.name + " · " + Presentation.kind_label(body.kind))
		body_list.set_item_metadata(body_index, body.id)
		body_list.set_item_tooltip(body_index, body.id)
		body_list.set_item_disabled(body_index, not body.landable)
		inspection_list.add_item(body.name + " · " + Presentation.kind_label(body.kind))
		inspection_list.set_item_metadata(body_index, body.id)
		inspection_list.set_item_tooltip(body_index, body.id)
		if body.landable and first_landable < 0:
			first_landable = body_index
	_visit = visit_reader.call(selected_id) if visit_reader.is_valid() else {}
	body_list.select(first_landable)
	_select_body()
	var loaded: Dictionary = journal.read(selected_id) if _storage_error == OK else {"error": _storage_error}
	record = loaded.get("record", {})
	_set_fields(record, loaded.error == OK)
	if loaded.error != OK:
		message.text = "Notiz kann nicht geöffnet werden: " + error_string(loaded.error)
	elif loaded.get("recovered", false):
		message.text = "Notiz aus der letzten gültigen Sicherung wiederhergestellt."

func _number(value: float) -> String:
	return Presentation.Ui.number(value, 3)

func _set_fields(value: Dictionary, editable: bool) -> void:
	_loading = true
	custom_name.text = value.get("name", "")
	note.text = value.get("note", "")
	discovered.button_pressed = value.get("discovered", false)
	custom_name.editable = editable
	note.editable = editable
	discovered.disabled = not editable
	save_button.disabled = not editable
	_loading = false
	_dirty = false

func _changed() -> void:
	if not _loading:
		_dirty = true
		message.text = "Änderung noch nicht gespeichert."

func save_changes() -> bool:
	if record.is_empty():
		return false
	if note.text.length() > 1024:
		message.text = "Die Notiz darf höchstens 1.024 Zeichen enthalten."
		return false
	var edited: Dictionary = record.duplicate(true)
	edited.name = custom_name.text
	edited.note = note.text
	edited.discovered = discovered.button_pressed
	var error: Error = journal.write(edited)
	if error != OK:
		message.text = "Speichern fehlgeschlagen: " + error_string(error) + ". Die Eingabe bleibt hier erhalten."
		discard_button.show()
		return false
	record = journal.read(selected_id).record
	_dirty = false
	discard_button.hide()
	message.text = "Systemname, Markierung und Notiz gespeichert."
	return true

func _save_pending() -> bool:
	return not _dirty or save_changes()

func close() -> void:
	if travel_in_progress:
		return
	if _save_pending():
		closed.emit()
		queue_free()


func _inspect_body() -> void:
	var index: int = inspection_list.selected
	if index < 0:
		return
	body_list.select(-1 if body_list.is_item_disabled(index) else index)
	visit_button.disabled = travel_in_progress or body_list.selected < 0
	body_description.text = Presentation.body_details(_system, _system.get("bodies", {}).get(str(inspection_list.get_item_metadata(index)), {}), _visit)

func _select_body() -> void:
	if body_list.selected >= 0:
		inspection_list.select(body_list.selected)
		_inspect_body()
	else:
		visit_button.disabled = true


func request_visit() -> void:
	if travel_in_progress or visit_button.disabled or not _save_pending():
		return
	var id: String = str(body_list.get_item_metadata(body_list.selected))
	if not _system.get("bodies", {}).get(id, {}).get("landable", false):
		return
	visit_requested.emit(selected_id, id)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	match text:
		"Zentrum", "Innenarm", "Außenrand", "Anzeigen": Symbols.apply(button, "map", 20)
		"Zurück zum Planeten", "Ohne Änderung zurück": Symbols.apply(button, "back", 20)
		"Suchen": Symbols.apply(button, "search", 20)
		"Leeren": Symbols.apply(button, "close", 20)
		"Oberfläche besuchen": Symbols.apply(button, "globe", 20)
		"Notiz speichern": Symbols.apply(button, "save", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
