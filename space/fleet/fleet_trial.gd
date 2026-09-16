extends Control
## Explicit, isolated hangar test; all commands save through SaveGameService.
const Fleet = preload("res://space/fleet/fleet_state.gd")
const Style = preload("res://ui/frontend/menu_style.gd")
var saves: Node
var state: Node
var ships: ItemList
var assets: ItemList
var target: OptionButton
var bay: OptionButton
var slots: OptionButton
var detail: Label
var status: Label
var designs: OptionButton
var design_search: LineEdit
var _library := preload("res://space/ships/ship_library_page.gd").new()
var _library_pending: bool = false
var _next_designs: Button
var _first_designs: Button
var dock_button: Button
var undock_button: Button
var cargo_button: Button
var instantiate_button: Button
var _revision: int = -1
var _resume: bool = false

func _enter_tree() -> void:
	_resume = get_node("/root/SaveGameService").session_active and get_node("/root/GameState").campaign.data.has(Fleet.FIELD)
	get_node("/root/SessionFlow").enter_frontend()

func _ready() -> void:
	saves = get_node("/root/SaveGameService")
	state = get_node("/root/GameState")
	theme = Style.theme()
	var background := ColorRect.new()
	background.color = Style.INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	Style.label(column, tr("FLEET_TITLE"), 26, Style.ACCENT)
	Style.paragraph(column, tr("FLEET_INTRO"), 16)
	var setup := HFlowContainer.new()
	column.add_child(setup)
	_button(setup, tr("FLEET_NEW"), _new_trial, "NewTrial")
	slots = OptionButton.new()
	slots.custom_minimum_size.x = 240
	setup.add_child(slots)
	_button(setup, tr("FLEET_LOAD"), _load_trial, "LoadTrial")
	_button(setup, tr("FLEET_SHIPYARD"), func() -> void: get_tree().change_scene_to_file("res://space/ships/shipyard.tscn"))
	_button(setup, tr("FLEET_HOME"), func() -> void: get_tree().change_scene_to_file("res://ui/frontend/main_menu.tscn"))
	ships = ItemList.new()
	ships.custom_minimum_size.y = 155
	ships.item_selected.connect(func(_index: int) -> void: _selection())
	column.add_child(ships)
	detail = Style.paragraph(column, tr("FLEET_EMPTY"), 16)
	var actions := HFlowContainer.new()
	column.add_child(actions)
	target = OptionButton.new()
	target.custom_minimum_size.x = 225
	target.item_selected.connect(func(_index: int) -> void: _selection())
	actions.add_child(target)
	bay = OptionButton.new()
	bay.custom_minimum_size.x = 150
	actions.add_child(bay)
	dock_button = _button(actions, tr("FLEET_DOCK"), func() -> void: _command({"kind": "dock", "ship_id": _ship_id(), "host_id": _target_id(), "bay_id": _bay_id()}), "Dock")
	undock_button = _button(actions, tr("FLEET_UNDOCK"), func() -> void: _command({"kind": "undock", "ship_id": _ship_id()}), "Undock")
	Style.label(column, tr("FLEET_CARGO_TITLE"), 18, Style.ACCENT)
	assets = ItemList.new()
	assets.custom_minimum_size.y = 90
	assets.item_selected.connect(func(_index: int) -> void: _availability())
	column.add_child(assets)
	cargo_button = _button(column, tr("FLEET_TRANSFER"), _transfer, "TransferCargo")
	Style.label(column, tr("FLEET_DESIGN_TITLE"), 18, Style.ACCENT)
	var library_row := HFlowContainer.new()
	column.add_child(library_row)
	design_search = LineEdit.new()
	design_search.placeholder_text = tr("FLEET_SEARCH")
	design_search.custom_minimum_size.x = 230
	design_search.text_changed.connect(func(_query: String) -> void: _scan_designs())
	library_row.add_child(design_search)
	designs = OptionButton.new()
	designs.custom_minimum_size.x = 230
	designs.item_selected.connect(func(_index: int) -> void: _availability())
	library_row.add_child(designs)
	_first_designs = _button(library_row, tr("FLEET_FIRST"), _scan_designs)
	_next_designs = _button(library_row, tr("FLEET_MORE"), func() -> void: _scan_designs(_library.next_offset))
	instantiate_button = _button(column, tr("FLEET_INSTANTIATE"), func() -> void: _command({"kind": "instantiate", "path": _design_path(), "host_id": _target_id()}), "Instantiate")
	status = Style.paragraph(column, "", 16)
	status.name = "FleetStatus"
	get_node("/root/LocaleManager").language_changed.connect(func(_locale: String) -> void: get_tree().reload_current_scene())
	_refresh_slots()
	_scan_designs()
	if _resume:
		saves.session_active = true
		_refresh()
	_availability()

func _new_trial() -> void:
	var path: String = saves.create_slot("Flottentest", 15838)
	if path.is_empty() or not saves.initialize_fleet_trial():
		status.text = tr("FLEET_NEW_FAILED")
		_refresh()
		return
	status.text = tr("FLEET_NEW_READY")
	_refresh_slots()
	_refresh()

func _load_trial() -> void:
	if slots.selected < 0: return
	var path: String = str(slots.get_item_metadata(slots.selected))
	# A list entry is not authority. Re-read and validate immediately before load.
	var check: Dictionary = saves.inspect_slot(path)
	if not check.get("valid", false) or not saves._read_save(path).get("game_state", {}).get("campaign", {}).has(Fleet.FIELD):
		status.text = tr("FLEET_LOAD_FAILED")
		return
	if not saves.select_slot(path):
		status.text = tr("FLEET_LOAD_FAILED")
		return
	saves.session_active = true
	status.text = tr("FLEET_LOADED")
	_refresh()

func _refresh_slots() -> void:
	slots.clear()
	for entry: Dictionary in saves.list_slots():
		if not entry.get("valid", false): continue
		if not saves._read_save(entry.path).get("game_state", {}).get("campaign", {}).has(Fleet.FIELD): continue
		slots.add_item(str(entry.get("name", tr("FLEET_ENTRY"))) + " · " + str(entry.path).get_file().left(17))
		slots.set_item_metadata(slots.item_count - 1, entry.path)

func _refresh() -> void:
	var selected: String = _ship_id()
	var selected_target: String = _target_id()
	ships.clear()
	target.clear()
	var value: Dictionary = state.campaign.data.get(Fleet.FIELD, {})
	_revision = int(value.get("snapshot", {}).get("revision", -1))
	for ship: Dictionary in value.get("snapshot", {}).get("ships", {}).values():
		var label: String = _name(ship) + " · " + (tr("FLEET_HANGAR") if ship.place.kind == "dock" else tr("FLEET_SYSTEM"))
		ships.add_item(label)
		ships.set_item_metadata(ships.item_count - 1, ship.id)
		target.add_item(_name(ship))
		target.set_item_metadata(target.item_count - 1, ship.id)
		if ship.id == selected: ships.select(ships.item_count - 1)
		if ship.id == selected_target: target.select(target.item_count - 1)
	if ships.item_count > 0 and ships.get_selected_items().is_empty(): ships.select(0)
	_selection()

func _selection() -> void:
	assets.clear()
	bay.clear()
	var snapshot: Dictionary = state.campaign.data.get(Fleet.FIELD, {}).get("snapshot", {})
	var selected: Dictionary = snapshot.get("ships", {}).get(_ship_id(), {})
	if selected.is_empty():
		_availability()
		return
	var destination: Dictionary = snapshot.ships.get(_target_id(), {})
	for bay_id: String in destination.get("capabilities", {}).get("bays", {}):
		var occupant: String = tr("FLEET_FREE")
		for ship: Dictionary in snapshot.ships.values():
			if ship.place.kind == "dock" and ship.place.host_ship_id == destination.id and ship.place.bay_id == bay_id: occupant = _name(ship)
		bay.add_item(tr("FLEET_BAY") % [bay.item_count + 1, occupant])
		bay.set_item_metadata(bay.item_count - 1, bay_id)
	var used: int = 0
	for asset: Dictionary in snapshot.assets.values():
		if asset.ship_id != selected.id: continue
		used += int(asset.space)
		assets.add_item((tr("FLEET_SAMPLE") if asset.kind == "sample" else tr("FLEET_CARGO")) + tr("FLEET_SPACE") % asset.space)
		assets.set_item_metadata(assets.item_count - 1, asset.id)
	if assets.item_count > 0: assets.select(0)
	detail.text = tr("FLEET_DETAIL") % [_name(selected), selected.blueprint.revision, used, selected.capabilities.cargo_space, selected.energy, selected.capabilities.energy_capacity, selected.id, tr("FLEET_DOCKED") + _name(snapshot.ships[selected.place.host_ship_id]) if selected.place.kind == "dock" else tr("FLEET_READY")]
	_availability()

func _availability() -> void:
	var snapshot: Dictionary = state.campaign.data.get(Fleet.FIELD, {}).get("snapshot", {}) if state != null else {}
	var selected: Dictionary = snapshot.get("ships", {}).get(_ship_id(), {})
	var destination: Dictionary = snapshot.get("ships", {}).get(_target_id(), {})
	var active: bool = saves != null and saves.session_active and not saves._write_blocked and _revision >= 0
	if dock_button != null: dock_button.disabled = not active or selected.get("role") != "lander" or selected.get("place", {}).get("kind") != "system" or destination.get("role") != "expedition" or bay.item_count == 0
	if undock_button != null: undock_button.disabled = not active or selected.get("place", {}).get("kind") != "dock"
	if cargo_button != null: cargo_button.disabled = not active or assets.get_selected_items().is_empty() or not Fleet.connected(snapshot, _ship_id(), _target_id())
	if instantiate_button != null: instantiate_button.disabled = not active or destination.get("place", {}).get("kind") != "system" or _design_path().is_empty()

func _transfer() -> void:
	if assets.get_selected_items().is_empty(): return
	_command({"kind": "cargo", "asset_id": assets.get_item_metadata(assets.get_selected_items()[0]), "target_id": _target_id()})

func _command(command: Dictionary) -> void:
	var ok: bool = saves.request_fleet_command(command, _revision)
	status.text = tr("FLEET_SAVED") if ok else _error(saves.last_error)
	_refresh()

func _ship_id() -> String:
	return str(ships.get_item_metadata(ships.get_selected_items()[0])) if ships != null and not ships.get_selected_items().is_empty() else ""

func _target_id() -> String:
	return str(target.get_item_metadata(target.selected)) if target != null and target.selected >= 0 else ""

func _bay_id() -> String:
	return str(bay.get_item_metadata(bay.selected)) if bay != null and bay.selected >= 0 else ""

func _name(ship: Dictionary) -> String:
	var value: Dictionary = state.campaign.data[Fleet.FIELD]
	return str(value.designs[Fleet.design_key(ship.blueprint)].name) + " · " + str(ship.id).right(6)

func _button(parent: Node, label: String, callback: Callable, node_name: String = "") -> Button:
	var button := Button.new()
	button.text = label
	if not node_name.is_empty(): button.name = node_name
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _scan_designs(offset: int = 0) -> void:
	designs.clear()
	_library.start(Fleet.Ship.DIRECTORY, design_search.text, "", offset)
	_library_pending = true
	_next_designs.disabled = true
	_availability()

func _process(_delta: float) -> void:
	if not _library_pending: return
	_library.advance()
	if not _library.done: return
	_library_pending = false
	for entry: Dictionary in _library.entries:
		designs.add_item(str(entry.name) + " · R%d" % entry.revision)
		designs.set_item_metadata(designs.item_count - 1, entry.path)
		designs.set_item_disabled(designs.item_count - 1, not entry.ok)
	_next_designs.disabled = not _library.may_have_more
	_availability()

func _design_path() -> String:
	return str(designs.get_item_metadata(designs.selected)) if designs != null and designs.selected >= 0 and not designs.is_item_disabled(designs.selected) else ""

func _exit_tree() -> void:
	_library.cancel()

func _error(code: String) -> String:
	var keys: Dictionary = {"fleet.stale": "FLEET_ERROR_STALE", "dock.occupied": "FLEET_ERROR_OCCUPIED",
		"fleet.too_far": "FLEET_ERROR_DISTANCE", "fleet.not_connected": "FLEET_ERROR_CONNECTED",
		"cargo.capacity": "FLEET_ERROR_CAPACITY", "fleet.limit": "FLEET_ERROR_LIMIT"}
	if code.begins_with("ship."): return tr("FLEET_ERROR_DESIGN")
	return tr(str(keys.get(code, "FLEET_ERROR")))
