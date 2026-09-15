extends Control
## Standalone M9.1 authoring scene. No campaign/epoch mutation.
const Ship = preload("res://space/ships/ship_blueprint.gd")
const History = preload("res://assembly/core/modular_assembly_history.gd")
const Assembler = preload("res://assembly/runtime/modular_asset_assembler.gd")

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
var _viewport_container: SubViewportContainer
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
}

func _ready() -> void:
	_build_ui()
	new_template("expedition")
	get_viewport().size_changed.connect(_resize_columns)
	_resize_columns()
	get_tree().auto_accept_quit = false

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
	_button(toolbar, "Entwürfe öffnen", _open_library)
	_undo_button = _button(toolbar, "Rückgängig", undo)
	_redo_button = _button(toolbar, "Wiederholen", redo)
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	root.add_child(columns)
	var left: VBoxContainer = _sidebar(columns, "Modules", 220)
	_label(left, "MODULE", 18)
	_catalog = ItemList.new()
	_catalog.custom_minimum_size.y = 220
	_catalog.item_selected.connect(_catalog_selected)
	left.add_child(_catalog)
	_button(left, "Modul hinzufügen", add_selected_module)
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
	center.add_child(_name_field)
	_viewport_container = SubViewportContainer.new()
	_viewport_container.stretch = true
	_viewport_container.custom_minimum_size = Vector2(220, 220)
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.gui_input.connect(_view_input)
	center.add_child(_viewport_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_viewport)
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
	_camera = Camera3D.new()
	_camera.fov = 45
	_camera.far = 2000
	_world.add_child(_camera)
	_camera.current = true
	_add_grid()
	_label(center, "Linksklick: auswählen · Rechts ziehen: drehen · Mausrad: Zoom", 13)
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
	_library_list = ItemList.new()
	_library_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_box.add_child(_library_list)
	_library_list.item_activated.connect(_activate_library)
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
	_fill_catalog()
	_refresh()
	frame_design.call_deferred()
	_status.text = "Vorlage geöffnet. Bearbeite sie frei und speichere deinen eigenen Entwurf."

func _fill_catalog() -> void:
	_catalog.clear()
	_module_ids.clear()
	for id: String in _definitions:
		if _definitions[id].role not in ["both", blueprint.ship.role]: continue
		_module_ids.append(id)
		_catalog.add_item(_definitions[id].name)
		_catalog.set_item_tooltip(_catalog.item_count - 1, "%s · %s m" % [_definitions[id].name, _dimensions(_definitions[id].size)])
	if _catalog.item_count > 0: _catalog.select(0)

func _catalog_selected(index: int) -> void:
	var definition: Dictionary = _definitions[_module_ids[index]]
	_status.text = "%s · %s m · Masse %d t" % [definition.name, _dimensions(definition.size), definition.stats.mass]

func add_selected_module() -> void:
	if _catalog.get_selected_items().is_empty(): return
	add_module(_module_ids[_catalog.get_selected_items()[0]])

func add_module(id: String) -> void:
	if blueprint.parts.size() >= Ship.MAX_MODULES:
		_status.text = MESSAGES["ship.module_limit"]
		return
	if not _definitions.has(id): return
	var position := Vector3.ZERO
	if selected >= 0:
		var part: Dictionary = blueprint.parts[selected]
		var box: AABB = Ship.module_box(part, _definitions[part.part_id])
		position = Vector3(box.end.x + _definitions[id].size.x * 0.5, Ship.vector(part.position).y, Ship.vector(part.position).z)
	var candidate: Dictionary = blueprint.duplicate(true)
	var index: int = Ship.Assembly.add_part(candidate, id, position)
	candidate.parts[index].part_revision = Ship.Catalog.REVISION
	if _edit(candidate, "Modul hinzufügen"):
		select_part(index)

func select_part(index: int) -> void:
	selected = index if index >= 0 and index < blueprint.parts.size() else -1
	_refresh()

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
	if selected < 0 or blueprint.parts.size() >= Ship.MAX_MODULES: return
	var candidate: Dictionary = blueprint.duplicate(true)
	var index: int = Ship.Assembly.duplicate_part(candidate, selected)
	var part: Dictionary = candidate.parts[index]
	part.position.x = -part.position.x
	part.rotation.y = fposmod(-part.rotation.y, 360)
	if _edit(candidate, "Spiegelkopie"): select_part(index)

func remove_part() -> void:
	if selected < 0: return
	var candidate: Dictionary = blueprint.duplicate(true)
	Ship.Assembly.remove_part(candidate, selected)
	selected = mini(selected, candidate.parts.size() - 1)
	_edit(candidate, "Modul entfernen")

func _rename(value: String) -> void:
	if _refreshing: return
	var candidate: Dictionary = blueprint.duplicate(true)
	candidate.name = value
	# Preserve transient empty input without ever saving it as a valid design.
	history.push_state(blueprint, "Umbenennen")
	blueprint = candidate
	dirty = true
	_undo_button.disabled = not history.can_undo()

func _edit(candidate: Dictionary, label: String) -> bool:
	var check: Dictionary = Ship.inspect(candidate)
	if not check.ok:
		_status.text = MESSAGES.get(check.code, "Entwurf nicht übernommen: " + check.code)
		return false
	history.push_state(blueprint, label)
	blueprint = candidate
	dirty = true
	_refresh()
	_status.text = label + " · noch nicht gespeichert"
	return true

func undo() -> void:
	if not history.can_undo(): return
	blueprint = history.undo(blueprint)
	dirty = true
	selected = mini(selected, blueprint.parts.size() - 1)
	_refresh()

func redo() -> void:
	if not history.can_redo(): return
	blueprint = history.redo(blueprint)
	dirty = true
	selected = mini(selected, blueprint.parts.size() - 1)
	_refresh()

func save_current() -> void:
	var result: Dictionary = Ship.save_design(blueprint, current_path)
	if not result.ok:
		_status.text = MESSAGES.get(result.code, "Speichern nicht möglich: " + result.code)
		return
	current_path = result.path
	dirty = false
	_refresh()
	_status.text = "%s · Revision %d gespeichert%s" % [blueprint.name, blueprint.revision,
		" (unvollständiger Entwurf)" if not Ship.evaluate(blueprint).ok else ""]

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
	_library_entries = Ship.list_designs()
	_library_list.clear()
	for entry: Dictionary in _library_entries:
		_library_list.add_item(entry.name + (" · nicht lesbar" if not entry.ok else ""))
		_library_list.set_item_tooltip(_library_list.item_count - 1, entry.path)
	if _library_entries.is_empty():
		_status.text = "Noch keine Entwürfe gespeichert. Speichere zuerst eine Expedition und ein Beiboot."
		return
	_library.popup_centered()

func _activate_library(index: int) -> void:
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
	for connection: Dictionary in _confirmation.confirmed.get_connections(): _confirmation.confirmed.disconnect(connection.callable)
	_confirmation.confirmed.connect(action, CONNECT_ONE_SHOT)
	_confirmation.popup_centered()

func _refresh() -> void:
	_refreshing = true
	_name_field.text = blueprint.name
	_installed.clear()
	for part: Dictionary in blueprint.parts:
		_installed.add_item(_definitions[part.part_id].name)
	if selected >= 0:
		_installed.select(selected)
		var part: Dictionary = blueprint.parts[selected]
		_module_title.text = _definitions[part.part_id].name
		for axis in range(3):
			_position_fields[axis].editable = true
			_position_fields[axis].set_value_no_signal(part.position[axis])
	else:
		_module_title.text = "Keine Auswahl"
		for field: SpinBox in _position_fields: field.editable = false
	var result: Dictionary = Ship.evaluate(blueprint)
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
	_fit.text = "Hangarprüfung verwendet die tatsächlichen Abmessungen beider Entwürfe."
	_assembler.configure(blueprint, _definitions, selected)
	_undo_button.disabled = not history.can_undo()
	_redo_button.disabled = not history.can_redo()
	_refreshing = false

func _select_issue(index: int) -> void:
	var parts: Variant = _issues.get_item_metadata(index)
	if parts is Array and not parts.is_empty(): select_part(parts[0])

func frame_design() -> void:
	var result: Dictionary = Ship.evaluate(blueprint)
	if result.bounds.size.is_zero_approx(): return
	_target = result.bounds.get_center()
	var aspect: float = maxf(_viewport_container.size.x / maxf(_viewport_container.size.y, 1), 0.3)
	_distance = maxf(result.bounds.size.length() * 1.4 / minf(aspect, 1), 15)
	_update_camera()

func _view_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.006, -1.2, 1.3)
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_distance = clampf(_distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 5, 700)
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
