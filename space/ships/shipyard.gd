extends Control
## Standalone M9.1 authoring scene. No campaign/epoch mutation.
const Ship = preload("res://space/ships/ship_blueprint.gd")
const History = preload("res://assembly/core/modular_assembly_history.gd")
const Assembler = preload("res://assembly/runtime/modular_asset_assembler.gd")
const Placement = preload("res://space/ships/ship_placement.gd")
const LibraryPage = preload("res://space/ships/ship_library_page.gd")
const MeshBuilder = preload("res://assembly/runtime/modular_voxel_mesh_builder.gd")

var blueprint: Dictionary = {}
var history := History.new()
var selected: int = -1
var dirty: bool = false
var current_path: String = ""
var _refreshing: bool = false
var _definitions: Dictionary = Ship.Catalog.all()
var _module_ids: Array[String] = []
var _library_entries: Array[Dictionary] = []
var _name_field: LineEdit
var _catalog: ItemList
var _installed: ItemList
var _stats: Label
var _issues: ItemList
var _status: Label
var _fit: Label
var _position_fields: Array[SpinBox] = []
var _module_title: Label
var _undo_button: Button
var _redo_button: Button
var _viewport_container: TextureRect
var _viewport: SubViewport
var _world: Node3D
var _assembler: Node3D
var _camera: Camera3D
var _library: Window
var _library_list: ItemList
var _confirmation: ConfirmationDialog
var _target: Vector3 = Vector3.ZERO
var _distance: float = 60.0
var _yaw: float = 0.65
var _pitch: float = 0.42
var _search: LineEdit
var _category: OptionButton
var _side: OptionButton
var _placement_yaw: OptionButton
var _symmetry: CheckButton
var _preview_toggle: CheckButton
var _placement_label: Label
var _add_button: Button
var _ghost: MeshInstance3D
var _selection_outline: MeshInstance3D
var _evaluation: Dictionary = {}
var mesh_build_count: int = 0
var evaluation_count: int = 0
var _pending_action: Callable
var _rename_open: bool = false
var _library_page := LibraryPage.new()
var _library_search: LineEdit
var _library_status: Label
var _library_previous: Button
var _library_next: Button
var _library_offsets: Array[int] = [0]
var _library_page_index: int = 0
var _library_loading: bool = false
var _previous_auto_quit: bool = true

const MESSAGES: Dictionary = {
	"ship.overlap": "Module überlappen sich.", "ship.disconnected": "Modul hat keine Verbindung zum Rumpf.",
	"ship.no_hull": "Ein Rumpfmodul fehlt.", "ship.command_count": "Genau eine Brücke / ein Cockpit erforderlich.",
	"ship.power_deficit": "Die Stromerzeugung reicht nicht für alle Module.", "ship.no_energy": "Ein Energiespeicher fehlt.",
	"ship.thrust_deficit": "Der Antrieb ist für die Masse zu schwach.", "ship.no_cargo": "Ein Frachtmodul fehlt.",
	"ship.no_landing_gear": "Ein Landegestell fehlt.", "ship.no_hangar": "Ein Beiboot-Hangar fehlt.",
	"ship.size_limit": "Der Entwurf überschreitet den Baubereich.", "ship.module_role": "Modul passt nicht zu diesem Schiffstyp.",
	"ship.module_limit": "Maximal 128 Module je Entwurf.", "ship.hangar_too_small": "Das Beiboot passt nicht in den Hangar.",
	"ship.invalid_design": "Zuerst die Entwurfsfehler beheben.", "ship.write_failed": "Speichern fehlgeschlagen. Der Entwurf bleibt geöffnet.",
	"ship.protected_original": "Die Originaldatei ist beschädigt oder neuer und bleibt geschützt.",
	"ship.different_design": "Die Zieldatei gehört zu einem anderen Entwurf.",
	"ship.unsupported_version": "Die Schiffversion wird noch nicht unterstützt.",
	"ship.unsupported_module": "Die Modulversion wird noch nicht unterstützt.",
	"ship.unknown_module": "Ein benötigtes Modul ist nicht installiert.",
	"ship.file_missing": "Die Datei wurde nicht gefunden.", "future_version": "Der Bauplan benötigt eine neuere Version.",
	"ship.select_anchor": "Wähle zuerst ein Modul als Anschluss.",
	"ship.mirror_center": "Das Modul liegt bereits auf der Mittelachse.",
	"ship.placement_input": "Diese Platzierung wird nicht unterstützt.",
	"ship.identity": "Bitte einen Namen für den Entwurf eingeben.",
}

func _ready() -> void:
	_build_ui()
	new_template("expedition")
	get_viewport().size_changed.connect(_resize_columns)
	_resize_columns()
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false

func _exit_tree() -> void:
	_library_page.cancel()
	if get_tree() != null: get_tree().auto_accept_quit = _previous_auto_quit

func _process(_delta: float) -> void:
	if not _library_loading: return
	if not _library.visible:
		_library_page.cancel()
		_library_loading = false
		return
	_library_page.advance()
	_library_status.text = "Entwürfe werden gelesen … %d gefunden" % _library_page.entries.size()
	if _library_page.done: _finish_library_page()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _guard(func() -> void: get_tree().quit())

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skin := Theme.new()
	skin.default_font_size = 15
	skin.set_color("font_color", "Label", Color("d8e6ed"))
	skin.set_color("font_color", "Button", Color("e4eff3"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("253e50") if state == "normal" else Color("385c6f")
		style.set_corner_radius_all(5)
		style.content_margin_left = 11
		style.content_margin_right = 11
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		skin.set_stylebox(state, "Button", style)
	theme = skin
	var background := ColorRect.new()
	background.color = Color("101e2a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var heading := HBoxContainer.new()
	root.add_child(heading)
	var title := Label.new()
	title.text = "VOXELVERSE  /  SCHIFFSWERFT"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_button(heading, "Ansicht zentrieren", frame_design)
	var toolbar := HFlowContainer.new()
	root.add_child(toolbar)
	_button(toolbar, "Neue Expedition", func() -> void: _guard(func() -> void: new_template("expedition")))
	_button(toolbar, "Neues Beiboot", func() -> void: _guard(func() -> void: new_template("lander")))
	_button(toolbar, "Speichern", save_current)
	_button(toolbar, "Als Kopie", save_as_copy)
	_button(toolbar, "Entwürfe öffnen", _open_library)
	_button(toolbar, tr("FLEET_ENTRY"), func() -> void: _guard(func() -> void: get_tree().change_scene_to_file("res://space/fleet/fleet_trial.tscn")))
	_undo_button = _button(toolbar, "Rückgängig", undo)
	_redo_button = _button(toolbar, "Wiederholen", redo)
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	root.add_child(columns)
	var left: VBoxContainer = _sidebar(columns, "Modules", 220)
	_label(left, "MODULE", 18)
	_search = LineEdit.new()
	_search.placeholder_text = "Modul suchen …"
	_search.text_changed.connect(func(_value: String) -> void: _fill_catalog())
	left.add_child(_search)
	_category = OptionButton.new()
	for category: String in ["Alle Bereiche", "Rumpf", "Antrieb", "Energie", "Fracht", "Hangar", "Forschung", "Besatzung"]: _category.add_item(category)
	_category.item_selected.connect(func(_index: int) -> void: _fill_catalog())
	left.add_child(_category)
	_catalog = ItemList.new()
	_catalog.custom_minimum_size.y = 160
	_catalog.item_selected.connect(_catalog_selected)
	left.add_child(_catalog)
	_side = OptionButton.new()
	for side: String in ["Rechts (+X)", "Links (−X)", "Oben (+Y)", "Unten (−Y)", "Vorne (−Z)", "Hinten (+Z)"]: _side.add_item(side)
	_side.item_selected.connect(func(_index: int) -> void: _update_preview())
	left.add_child(_side)
	_placement_yaw = OptionButton.new()
	for yaw: String in ["Drehung: 0°", "Drehung: 90°", "Drehung: 180°", "Drehung: 270°"]: _placement_yaw.add_item(yaw)
	_placement_yaw.item_selected.connect(func(_index: int) -> void: _update_preview())
	left.add_child(_placement_yaw)
	_symmetry = CheckButton.new()
	_symmetry.text = "Symmetrisch anbauen"
	_symmetry.toggled.connect(func(_enabled: bool) -> void: _update_preview())
	left.add_child(_symmetry)
	_preview_toggle = CheckButton.new()
	_preview_toggle.text = "Bauvorschau"
	_preview_toggle.toggled.connect(func(_enabled: bool) -> void: _update_preview())
	left.add_child(_preview_toggle)
	_add_button = _button(left, "Modul hinzufügen", add_selected_module)
	_placement_label = _label(left, "", 13)
	_label(left, "VERBAUT", 18)
	_installed = ItemList.new()
	_installed.custom_minimum_size.y = 230
	_installed.item_selected.connect(select_part)
	left.add_child(_installed)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(center)
	_name_field = LineEdit.new()
	_name_field.placeholder_text = "Name des Entwurfs"
	_name_field.max_length = 120
	_name_field.text_changed.connect(_rename)
	_name_field.focus_exited.connect(func() -> void: _rename_open = false)
	center.add_child(_name_field)
	var views := HFlowContainer.new()
	center.add_child(views)
	for view: String in ["Perspektive", "Oben", "Vorne", "Seite"]:
		_button(views, view, func() -> void: set_view(view))
	# TextureRect displays the retained frame without taking ownership of the
	# SubViewport update policy. Redraw is requested only by actual visual edits.
	_viewport_container = TextureRect.new()
	_viewport_container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_viewport_container.stretch_mode = TextureRect.STRETCH_SCALE
	_viewport_container.custom_minimum_size = Vector2(220, 220)
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.gui_input.connect(_view_input)
	center.add_child(_viewport_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport_container.add_child(_viewport)
	_viewport_container.texture = _viewport.get_texture()
	_viewport_container.resized.connect(_request_render)
	_world = Node3D.new()
	_viewport.add_child(_world)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("152839")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("bdd7e2")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	_world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_energy = 1.4
	_world.add_child(sun)
	_assembler = Assembler.new()
	_world.add_child(_assembler)
	_ghost = MeshInstance3D.new()
	_ghost.visible = false
	_world.add_child(_ghost)
	_selection_outline = MeshInstance3D.new()
	_world.add_child(_selection_outline)
	_camera = Camera3D.new()
	_camera.fov = 45
	_camera.far = 2000
	_world.add_child(_camera)
	_camera.current = true
	_add_grid()
	_label(center, "Klick: Auswahl · Rechts: drehen · Mitte: verschieben · Rad: Zoom · R: drehen", 13)
	var right: VBoxContainer = _sidebar(columns, "Inspector", 280)
	_module_title = _label(right, "AUSWAHL", 18)
	var position_row := HBoxContainer.new()
	right.add_child(position_row)
	for axis in range(3):
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		position_row.add_child(box)
		_label(box, ["X", "Y", "Z"][axis], 13)
		var spin := SpinBox.new()
		spin.min_value = -200
		spin.max_value = 200
		spin.step = 1
		spin.custom_minimum_size.x = 68
		spin.value_changed.connect(func(value: float) -> void: _move_axis(axis, value))
		box.add_child(spin)
		_position_fields.append(spin)
	var actions := HFlowContainer.new()
	right.add_child(actions)
	_button(actions, "90° drehen", rotate_part)
	_button(actions, "Spiegelkopie", mirror_part)
	_button(actions, "Entfernen", remove_part)
	_label(right, "AUSSTATTUNG", 18)
	_stats = _label(right, "", 15)
	_label(right, "ENTWURFSPRÜFUNG", 18)
	_issues = ItemList.new()
	_issues.custom_minimum_size.y = 135
	_issues.item_selected.connect(_select_issue)
	right.add_child(_issues)
	_fit = _label(right, "", 14)
	_button(right, "Hangar mit Entwurf prüfen", _open_fit_library)
	var notice: Label = _label(right, "Entwurfswerkstatt · Module verändern die berechneten Werte. Flug, Forschung und Baukosten werden später an die Kampagne angeschlossen.", 13)
	notice.modulate = Color("8ea5b5")
	_status = _label(root, "", 14)
	_status.custom_minimum_size.y = 36
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Ungespeicherter Entwurf"
	_confirmation.dialog_text = "Änderungen verwerfen und fortfahren?"
	_confirmation.ok_button_text = "Verwerfen"
	_confirmation.cancel_button_text = "Zurück"
	_confirmation.add_button("Speichern & weiter", true, "save_continue")
	_confirmation.confirmed.connect(_discard_continue)
	_confirmation.canceled.connect(func() -> void: _pending_action = Callable())
	_confirmation.custom_action.connect(func(action: StringName) -> void:
		if action == &"save_continue":
			if save_current():
				_confirmation.hide()
				_discard_continue()
			else: _confirmation.dialog_text = _status.text + "\nDer Entwurf bleibt geöffnet.")
	add_child(_confirmation)
	_library = Window.new()
	_library.visible = false
	_library.title = "Gespeicherte Schiffsentwürfe"
	_library.size = Vector2i(580, 400)
	_library.transient = true
	_library.exclusive = true
	_library.close_requested.connect(func() -> void: _library.hide())
	add_child(_library)
	var library_box := VBoxContainer.new()
	library_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_library.add_child(library_box)
	_library_search = LineEdit.new()
	_library_search.placeholder_text = "Entwürfe nach Name filtern …"
	_library_search.text_changed.connect(func(_value: String) -> void:
		_library_offsets = [0]
		_library_page_index = 0
		_start_library_page())
	library_box.add_child(_library_search)
	_library_list = ItemList.new()
	_library_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_box.add_child(_library_list)
	_library_list.item_activated.connect(_activate_library)
	_library_status = _label(library_box, "", 14)
	var page_buttons := HBoxContainer.new()
	library_box.add_child(page_buttons)
	_library_previous = _button(page_buttons, "Vorherige Seite", func() -> void:
		_library_page_index -= 1
		_start_library_page())
	_library_next = _button(page_buttons, "Weitere Entwürfe", func() -> void:
		if _library_offsets.size() == _library_page_index + 1: _library_offsets.append(_library_page.next_offset)
		_library_page_index += 1
		_start_library_page())
	_button(library_box, "Ausgewählten Entwurf verwenden", func() -> void:
		if not _library_list.get_selected_items().is_empty(): _activate_library(_library_list.get_selected_items()[0]))
	_button(library_box, "Schließen", func() -> void: _library.hide())

func _sidebar(parent: Node, node_name: String, width: int) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.custom_minimum_size.x = width
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 9)
	scroll.add_child(box)
	return box

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func new_template(role: String) -> void:
	blueprint = Ship.template(role)
	selected = 0
	dirty = false
	current_path = ""
	history.clear()
	_rename_open = false
	_search.text = ""
	_category.select(0)
	_side.select(0)
	_placement_yaw.select(0)
	_symmetry.set_pressed_no_signal(false)
	_preview_toggle.set_pressed_no_signal(false)
	_reset_sidebars()
	_fill_catalog()
	_refresh()
	frame_design.call_deferred()
	_status.text = "Vorlage geöffnet. Bearbeite sie frei und speichere deinen eigenen Entwurf."

func _fill_catalog() -> void:
	if blueprint.is_empty(): return
	var previous: String = ""
	if not _catalog.get_selected_items().is_empty() and not _module_ids.is_empty(): previous = _module_ids[_catalog.get_selected_items()[0]]
	_catalog.clear()
	_module_ids.clear()
	for id: String in _definitions:
		if _definitions[id].role not in ["both", blueprint.ship.role]: continue
		if not _search.text.strip_edges().is_empty() and not _definitions[id].name.to_lower().contains(_search.text.strip_edges().to_lower()): continue
		if _category.selected > 0 and _definitions[id].category != _category.get_item_text(_category.selected): continue
		_module_ids.append(id)
		_catalog.add_item(_definitions[id].name)
		_catalog.set_item_tooltip(_catalog.item_count - 1, "%s · %s m" % [_definitions[id].name, _dimensions(_definitions[id].size)])
	if _catalog.item_count > 0: _catalog.select(maxi(_module_ids.find(previous), 0))
	if _ghost != null: _update_preview()

func _catalog_selected(index: int) -> void:
	var definition: Dictionary = _definitions[_module_ids[index]]
	_status.text = "%s · %s m · Masse %d t" % [definition.name, _dimensions(definition.size), definition.stats.mass]
	_preview_toggle.set_pressed_no_signal(true)
	_update_preview()

func add_selected_module() -> void:
	if _catalog.get_selected_items().is_empty(): return
	add_module(_module_ids[_catalog.get_selected_items()[0]])

func add_module(id: String) -> void:
	var result: Dictionary = Placement.add_attached(blueprint, selected, id, _side.selected, _placement_yaw.selected * 90, _symmetry.button_pressed)
	if not result.ok:
		_status.text = MESSAGES.get(result.code, result.code)
		return
	var previous: int = selected
	selected = result.added[0]
	if not _edit(result.blueprint, "Modulpaar anbauen" if result.added.size() == 2 else "Modul hinzufügen"): selected = previous

func select_part(index: int) -> void:
	selected = index if index >= 0 and index < blueprint.parts.size() else -1
	_update_selection()
	_update_preview()

func _move_axis(axis: int, value: float) -> void:
	if _refreshing or selected < 0: return
	var candidate: Dictionary = blueprint.duplicate(true)
	var position: Vector3 = candidate.parts[selected].position
	position[axis] = value
	candidate.parts[selected].position = position
	_edit(candidate, "Modul verschieben")

func rotate_part() -> void:
	if selected < 0: return
	var candidate: Dictionary = blueprint.duplicate(true)
	var rotation: Vector3 = candidate.parts[selected].rotation
	rotation.y = fposmod(rotation.y + 90, 360)
	candidate.parts[selected].rotation = rotation
	_edit(candidate, "Modul drehen")

func mirror_part() -> void:
	var result: Dictionary = Placement.mirror(blueprint, selected)
	if not result.ok:
		_status.text = MESSAGES.get(result.code, result.code)
		return
	selected = result.added[0]
	_edit(result.blueprint, "Spiegelkopie")

func remove_part() -> void:
	if selected < 0: return
	var candidate: Dictionary = blueprint.duplicate(true)
	Ship.Assembly.remove_part(candidate, selected)
	selected = mini(selected, candidate.parts.size() - 1)
	_edit(candidate, "Modul entfernen")

func _rename(value: String) -> void:
	if _refreshing: return
	if not _rename_open: history.push_state(blueprint, "Umbenennen")
	_rename_open = true
	blueprint.name = value
	dirty = true
	_undo_button.disabled = not history.can_undo()
	_redo_button.disabled = true
	_status.text = "Bitte einen Namen eingeben." if value.strip_edges().is_empty() else "Name geändert · noch nicht gespeichert"

func _edit(candidate: Dictionary, label: String) -> bool:
	var check: Dictionary = Ship.inspect(candidate)
	if not check.ok:
		_status.text = MESSAGES.get(check.code, "Entwurf nicht übernommen: " + check.code)
		return false
	history.push_state(blueprint, label)
	_rename_open = false
	blueprint = candidate
	dirty = true
	_refresh()
	_status.text = label + " · noch nicht gespeichert"
	return true

func undo() -> void:
	if not history.can_undo(): return
	blueprint = history.undo(blueprint)
	_rename_open = false
	dirty = true
	selected = mini(selected, blueprint.parts.size() - 1)
	_refresh()

func redo() -> void:
	if not history.can_redo(): return
	blueprint = history.redo(blueprint)
	_rename_open = false
	dirty = true
	selected = mini(selected, blueprint.parts.size() - 1)
	_refresh()

func save_current() -> bool:
	var result: Dictionary = Ship.save_design(blueprint, current_path)
	if not result.ok:
		_status.text = MESSAGES.get(result.code, "Speichern nicht möglich: " + result.code)
		return false
	current_path = result.path
	dirty = false
	_rename_open = false
	_refresh(false)
	_status.text = "%s · Revision %d gespeichert%s" % [blueprint.name, blueprint.revision,
		" (unvollständiger Entwurf)" if not _evaluation.ok else ""]
	return true

func save_as_copy() -> bool:
	var result: Dictionary = Ship.save_copy(blueprint)
	if not result.ok:
		_status.text = MESSAGES.get(result.code, result.code)
		return false
	blueprint = result.blueprint
	current_path = result.path
	dirty = false
	_rename_open = false
	history.clear()
	_refresh()
	_status.text = "Eigene Kopie gespeichert: " + blueprint.name
	return true

func load_path(path: String) -> bool:
	var result: Dictionary = Ship.load_design(path)
	if not result.ok:
		_status.text = MESSAGES.get(result.code, "Öffnen nicht möglich: " + result.code)
		return false
	blueprint = result.blueprint
	current_path = path
	history.clear()
	dirty = false
	selected = 0 if not blueprint.parts.is_empty() else -1
	_rename_open = false
	_reset_sidebars()
	_fill_catalog()
	_refresh()
	frame_design.call_deferred()
	_status.text = "%s · Revision %d geöffnet" % [blueprint.name, blueprint.revision]
	return true

func _open_library() -> void:
	_show_library(false)

func _open_fit_library() -> void:
	_show_library(true)

func _show_library(for_fit: bool) -> void:
	_library.set_meta("for_fit", for_fit)
	_library.title = "Hangarprüfung · Gegenstück auswählen" if for_fit else "Gespeicherte Schiffsentwürfe"
	_library_offsets = [0]
	_library_page_index = 0
	_library_search.text = ""
	_library.popup_centered()
	_start_library_page()

func _start_library_page() -> void:
	_library_entries.clear()
	_library_list.clear()
	var role: String = ""
	if _library.get_meta("for_fit", false): role = "lander" if blueprint.ship.role == "expedition" else "expedition"
	_library_page.start(Ship.DIRECTORY, _library_search.text, role, _library_offsets[_library_page_index])
	_library_loading = true
	_library_previous.disabled = true
	_library_next.disabled = true
	_library_status.text = "Entwürfe werden gelesen …"

func _finish_library_page() -> void:
	_library_loading = false
	_library_entries = _library_page.entries.duplicate(true)
	for entry: Dictionary in _library_entries:
		_library_list.add_item(entry.name + (" · Rev. %d" % entry.revision if entry.ok else " · nicht lesbar"))
		_library_list.set_item_tooltip(_library_list.item_count - 1, entry.path)
	_library_previous.disabled = _library_page_index <= 0
	_library_next.disabled = not _library_page.may_have_more
	_library_status.text = "Seite %d · %d Entwürfe" % [_library_page_index + 1, _library_entries.size()] if not _library_entries.is_empty() else "Keine weiteren passenden Entwürfe gefunden."

func _activate_library(index: int) -> void:
	if _library_loading or index < 0 or index >= _library_entries.size(): return
	var path: String = _library_entries[index].path
	_library.hide()
	if _library.get_meta("for_fit", false):
		var other: Dictionary = Ship.load_design(path)
		if not other.ok:
			_status.text = MESSAGES.get(other.code, other.code)
			return
		var host: Dictionary = blueprint if blueprint.ship.role == "expedition" else other.blueprint
		var guest: Dictionary = other.blueprint if blueprint.ship.role == "expedition" else blueprint
		var fit: Dictionary = Ship.find_hangar_fit(host, guest)
		_fit.text = "%s passt in %s (%d°). Freiraum je Seite: %s m" % [guest.name, host.name, fit.yaw, _dimensions(fit.clearance)] if fit.ok else MESSAGES.get(fit.code, fit.code)
		_reveal_fit.call_deferred()
	else:
		_guard(func() -> void: load_path(path))

func _reveal_fit() -> void:
	var scroll := _fit.get_parent().get_parent() as ScrollContainer
	if scroll != null: scroll.ensure_control_visible(_fit)

func _guard(action: Callable) -> void:
	if not dirty:
		action.call()
		return
	_pending_action = action
	_confirmation.dialog_text = "Entwurf speichern oder Änderungen verwerfen?"
	_confirmation.popup_centered()

func _discard_continue() -> void:
	var action: Callable = _pending_action
	_pending_action = Callable()
	if action.is_valid(): action.call()

func _refresh(geometry_changed: bool = true) -> void:
	_refreshing = true
	if _name_field.text != blueprint.name: _name_field.text = blueprint.name
	if geometry_changed or _evaluation.is_empty():
		var scroll: float = _installed.get_v_scroll_bar().value
		_installed.clear()
		for index in range(blueprint.parts.size()):
			var part: Dictionary = blueprint.parts[index]
			_installed.add_item("%02d  %s" % [index + 1, _definitions[part.part_id].name])
		_installed.get_v_scroll_bar().set_deferred("value", scroll)
		_evaluation = Ship.evaluate(blueprint)
		evaluation_count += 1
		_assembler.configure(blueprint, _definitions, -1)
		mesh_build_count += 1
		_fit.text = "Hangarprüfung verwendet die tatsächlichen Abmessungen beider Entwürfe."
	var result: Dictionary = _evaluation
	if not result.stats.is_empty():
		var stats: Dictionary = result.stats
		_stats.text = "%s · %d / %d Module\nGröße: %s m\nMasse: %d t · Schub: %d\nStrom: %d / %d Bedarf\nEnergiespeicher: %d\nFracht: %d · Sitze: %d\nLabore: %d · Hangars: %d\nBaukosten (Planwert): %d" % [
			"Expedition" if blueprint.ship.role == "expedition" else "Beiboot", blueprint.parts.size(), Ship.MAX_MODULES,
			_dimensions(result.bounds.size), stats.mass, stats.thrust, stats.power, stats.draw, stats.energy,
			stats.cargo, stats.seats, stats.research, result.bays.size(), stats.cost]
	_issues.clear()
	if result.ok:
		_issues.add_item("✓ Entwurf vollständig")
		_issues.set_item_custom_fg_color(0, Color("88d6aa"))
	else:
		for issue: Dictionary in result.issues:
			var text: String = MESSAGES.get(issue.code, issue.code)
			_issues.add_item(text)
			_issues.set_item_tooltip(_issues.item_count - 1, text)
			_issues.set_item_metadata(_issues.item_count - 1, issue.parts)
	_undo_button.disabled = not history.can_undo()
	_redo_button.disabled = not history.can_redo()
	_refreshing = false
	_update_selection()
	_update_preview()
	_request_render()

func _update_selection() -> void:
	if selected >= blueprint.parts.size(): selected = -1
	_selection_outline.visible = selected >= 0
	if selected >= 0:
		_installed.select(selected)
		var part: Dictionary = blueprint.parts[selected]
		_module_title.text = _definitions[part.part_id].name
		for axis in range(3):
			_position_fields[axis].editable = true
			_position_fields[axis].set_value_no_signal(part.position[axis])
		_selection_outline.mesh = _wire_box(Ship.module_box(part, _definitions[part.part_id]).grow(0.04))
	else:
		_installed.deselect_all()
		_module_title.text = "Keine Auswahl"
		for field: SpinBox in _position_fields: field.editable = false
	_request_render()

func _update_preview() -> void:
	if _ghost == null or blueprint.is_empty(): return
	_ghost.visible = false
	_add_button.disabled = true
	if _catalog.get_selected_items().is_empty():
		_placement_label.text = "Keine passenden Module."
		_request_render()
		return
	var id: String = _module_ids[_catalog.get_selected_items()[0]]
	var proposal: Dictionary = Placement.plan(blueprint, selected, id, _side.selected, _placement_yaw.selected * 90, _symmetry.button_pressed)
	_add_button.disabled = not proposal.ok
	_placement_label.text = ("Bauplatz frei · %d Modul(e)" % proposal.placements.size()) if proposal.ok else "Anbau: " + MESSAGES.get(proposal.code, proposal.code)
	_placement_label.modulate = Color("88d6aa") if proposal.ok else Color("ee9c88")
	if _preview_toggle.button_pressed and not proposal.placements.is_empty():
		_ghost.mesh = MeshBuilder.build_mesh({"parts": proposal.placements}, _definitions)
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.35, 1.0, 0.65, 0.38) if proposal.ok else Color(1.0, 0.3, 0.2, 0.45)
		_ghost.material_override = material
		_ghost.visible = true
	_request_render()

func _wire_box(box: AABB) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffd078")
	material.no_depth_test = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for index in range(8):
		var corner: Vector3 = box.position + Vector3(1 if index & 1 else 0, 1 if index & 2 else 0, 1 if index & 4 else 0) * box.size
		for bit in [1, 2, 4]:
			var other: int = index ^ bit
			if index < other:
				mesh.surface_add_vertex(corner)
				mesh.surface_add_vertex(box.position + Vector3(1 if other & 1 else 0, 1 if other & 2 else 0, 1 if other & 4 else 0) * box.size)
	mesh.surface_end()
	return mesh

func _request_render() -> void:
	if _viewport != null:
		_viewport.size = Vector2i(maxi(int(_viewport_container.size.x), 2), maxi(int(_viewport_container.size.y), 2))
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _reset_sidebars() -> void:
	for control: Control in [_catalog, _stats]:
		var scroll := control.get_parent().get_parent() as ScrollContainer
		if scroll != null: scroll.scroll_vertical = 0

func _select_issue(index: int) -> void:
	var parts: Variant = _issues.get_item_metadata(index)
	if parts is Array and not parts.is_empty(): select_part(parts[0])

func frame_design() -> void:
	var result: Dictionary = _evaluation
	if result.is_empty(): return
	if result.bounds.size.is_zero_approx(): return
	_target = result.bounds.get_center()
	var aspect: float = maxf(_viewport_container.size.x / maxf(_viewport_container.size.y, 1), 0.3)
	_distance = maxf(result.bounds.size.length() * 1.4 / minf(aspect, 1), 15)
	_camera.size = maxf(result.bounds.size.length() / minf(aspect, 1), 10)
	_update_camera()

func set_view(view: String) -> void:
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE if view == "Perspektive" else Camera3D.PROJECTION_ORTHOGONAL
	match view:
		"Oben":
			_yaw = 0
			_pitch = PI * 0.5 - 0.001
		"Vorne":
			_yaw = PI
			_pitch = 0
		"Seite":
			_yaw = PI * 0.5
			_pitch = 0
		_:
			_yaw = 0.65
			_pitch = 0.42
	frame_design()

func _view_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.006, -1.2, 1.3)
		_update_camera()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		var units: float = (_distance if _camera.projection == Camera3D.PROJECTION_PERSPECTIVE else _camera.size) / maxf(_viewport_container.size.y, 1)
		_target += (-_camera.basis.x * event.relative.x + _camera.basis.y * event.relative.y) * units
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_distance = clampf(_distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 5, 700)
			_camera.size = clampf(_camera.size * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 3, 400)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var origin: Vector3 = _camera.project_ray_origin(event.position)
			var direction: Vector3 = _camera.project_ray_normal(event.position)
			var best: float = INF
			var hit_index: int = -1
			for index in range(blueprint.parts.size()):
				var part: Dictionary = blueprint.parts[index]
				var hit: Variant = Ship.module_box(part, _definitions[part.part_id]).intersects_ray(origin, direction)
				if hit is Vector3 and origin.distance_to(hit) < best:
					best = origin.distance_to(hit)
					hit_index = index
			select_part(hit_index)

func _update_camera() -> void:
	_camera.position = _target + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.look_at(_target)
	_request_render()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if get_tree().paused or _library.visible or _confirmation.visible: return
	var text_focus: Control = get_viewport().gui_get_focus_owner()
	var editing_text: bool = text_focus is LineEdit or text_focus is TextEdit
	if event.ctrl_pressed and event.keycode == KEY_S:
		if event.shift_pressed: save_as_copy()
		else: save_current()
	elif editing_text: return
	elif event.ctrl_pressed and event.keycode == KEY_Z:
		if event.shift_pressed: redo()
		else: undo()
	elif event.ctrl_pressed and event.keycode == KEY_Y: redo()
	elif event.keycode == KEY_DELETE: remove_part()
	elif event.keycode == KEY_R: rotate_part()
	elif event.keycode == KEY_F: frame_design()
	else: return
	get_viewport().set_input_as_handled()

func _resize_columns() -> void:
	# Sidebars scroll vertically; keep the 3D view usable at smaller windows.
	var columns: Node = find_child("Columns", true, false)
	if columns == null: return
	columns.get_node("Modules").custom_minimum_size.x = 180 if size.x < 1050 else 220
	columns.get_node("Inspector").custom_minimum_size.x = 240 if size.x < 1050 else 280

func _add_grid() -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("284355")
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for step in range(-100, 101, 5):
		mesh.surface_add_vertex(Vector3(step, -8, -100))
		mesh.surface_add_vertex(Vector3(step, -8, 100))
		mesh.surface_add_vertex(Vector3(-100, -8, step))
		mesh.surface_add_vertex(Vector3(100, -8, step))
	mesh.surface_end()
	var grid := MeshInstance3D.new()
	grid.mesh = mesh
	_world.add_child(grid)

func _dimensions(value: Vector3) -> String:
	return "%.1f × %.1f × %.1f" % [value.x, value.y, value.z]
