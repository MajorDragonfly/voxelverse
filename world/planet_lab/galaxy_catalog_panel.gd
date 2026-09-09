extends CanvasLayer

const Catalog = preload("res://world/space/galaxy_catalog.gd")
const Journal = preload("res://world/space/galaxy_journal.gd")
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

func _ready() -> void:
	name = "GalaxyCatalog"
	layer = 80
	add_to_group(&"galaxy_catalog_overlay")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	journal = Journal.new(catalog, journal_directory)
	_storage_error = journal.open()
	_build()
	show_sector([0, 0, 0])
	var address: Dictionary = Catalog.Address.parse(initial_system_id)
	if address.get("kind") == "system" and catalog.owns(initial_system_id, "system"):
		show_sector(address.sector)
		for index in range(systems.size()):
			if systems[index].id == initial_system_id:
				system_list.select(index)
				select_system(index)

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.025, 0.05, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	shade.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.text = "VOXELVERSE  /  GALAXIEKATALOG"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("80d4c1"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Referenzgalaxie · 100.000 Lichtjahre Durchmesser · Systeme, Planeten und Monde"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	var row := HFlowContainer.new()
	column.add_child(row)
	_button(row, "Zentrum", func(): show_sector([0, 0, 0]))
	_button(row, "Innenarm", func(): show_sector([1000, 0, -700]))
	_button(row, "Außenrand", func(): show_sector([-2400, 0, 800]))
	_button(row, "Zurück zum Planeten", close).name = "CloseGalaxy"
	var sectors := HFlowContainer.new()
	column.add_child(sectors)
	for axis in ["X", "Y", "Z"]:
		var label := Label.new()
		label.text = "Sektor " + axis
		sectors.add_child(label)
		var input := SpinBox.new()
		input.min_value = -Catalog.Address.MAX_SECTOR
		input.max_value = Catalog.Address.MAX_SECTOR
		input.step = 1
		input.custom_minimum_size.x = 115
		sectors.add_child(input)
		coordinates.append(input)
	_button(sectors, "Anzeigen", func(): show_sector([int(coordinates[0].value), int(coordinates[1].value), int(coordinates[2].value)]))
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	column.add_child(content)
	system_list = ItemList.new()
	system_list.name = "GalaxySystems"
	system_list.custom_minimum_size.x = 220
	system_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	system_list.item_selected.connect(select_system)
	content.add_child(system_list)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(detail)
	description = RichTextLabel.new()
	description.bbcode_enabled = true
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.custom_minimum_size.y = 100
	detail.add_child(description)
	var destination := HBoxContainer.new()
	detail.add_child(destination)
	body_list = OptionButton.new()
	body_list.name = "GalaxyBodies"
	body_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_list.item_selected.connect(func(_index: int): _select_body())
	destination.add_child(body_list)
	visit_button = _button(destination, "Oberfläche besuchen", request_visit)
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
	var actions := HBoxContainer.new()
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
	message.add_theme_color_override("font_color", Color("e2bf87"))
	column.add_child(message)

func show_sector(axes: Array) -> void:
	if travel_in_progress:
		return
	if not _save_pending():
		return
	var sector: Dictionary = catalog.sector_at(axes)
	if sector.is_empty():
		message.text = "Diese Sektoradresse ist ungültig."
		return
	for axis in range(3):
		coordinates[axis].value = int(axes[axis])
	systems = sector.systems
	system_list.clear()
	selected_id = ""
	selected_index = -1
	for system: Dictionary in systems:
		system_list.add_item(system.name + (" · Doppelstern" if system.star_count == 2 else ""))
	message.text = "%d Systeme · Gesteinsplaneten und Monde besuchen; gespeicherte Orte werden beim Wiederbesuch geladen." % systems.size() if _storage_error == OK else "Katalog lesbar; gespeicherte Notizen nicht verfügbar: " + error_string(_storage_error)
	if not systems.is_empty():
		system_list.select(0)
		select_system(0)
	else:
		body_list.clear()
		visit_button.disabled = true
		record = {}
		description.text = "In diesem Sektor sind keine Sterne verzeichnet."
		_set_fields({}, false)

func select_system(index: int) -> void:
	if travel_in_progress:
		return
	if index < 0 or index >= systems.size():
		return
	if not _save_pending():
		if selected_index >= 0:
			system_list.select(selected_index)
		return
	selected_index = index
	selected_id = systems[index].id
	var system: Dictionary = catalog.system(selected_id)
	var local_position: Array = system.position.offset_ly
	var lines: PackedStringArray = ["[font_size=22]" + system.name + "[/font_size]", "", "%d Stern(e) · Körpergrößen und Bahnabstände in Kilometern" % system.star_count, "Position im Sektor: %.3f / %.3f / %.3f Lichtjahre" % local_position, ""]
	var kinds: Dictionary = {"star": "Stern", "planet": "Gesteinsplanet", "gas_giant": "Gasriese", "moon": "Mond"}
	body_list.clear()
	var first_landable: int = -1
	for body: Dictionary in system.bodies.values():
		var body_index: int = body_list.item_count
		body_list.add_item("%s · %s · Ø %.0f km" % [body.name, kinds[body.kind], body.radius * 0.002])
		body_list.set_item_metadata(body_index, body.id)
		body_list.set_item_disabled(body_index, not body.landable)
		if body.landable and first_landable < 0:
			first_landable = body_index
		lines.append("[b]%s[/b]  ·  %s  ·  Ø %.1f km" % [body.name, kinds[body.kind], body.radius * 0.002])
		if body.orbit_radius > 0:
			lines.append("Bahnabstand %.0f km" % (body.orbit_radius * 0.001))
	description.text = "\n".join(lines)
	body_list.select(first_landable)
	_select_body()
	var loaded: Dictionary = journal.read(selected_id) if _storage_error == OK else {"error": _storage_error}
	record = loaded.get("record", {})
	_set_fields(record, loaded.error == OK)
	if loaded.error != OK:
		message.text = "Notiz kann nicht geöffnet werden: " + error_string(loaded.error)
	elif loaded.get("recovered", false):
		message.text = "Notiz aus der letzten gültigen Sicherung wiederhergestellt."

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


func _select_body() -> void:
	visit_button.disabled = body_list.selected < 0 or body_list.is_item_disabled(body_list.selected)


func request_visit() -> void:
	if travel_in_progress or visit_button.disabled or not _save_pending():
		return
	visit_requested.emit(selected_id, str(body_list.get_item_metadata(body_list.selected)))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.pressed.connect(action)
	parent.add_child(button)
	return button
