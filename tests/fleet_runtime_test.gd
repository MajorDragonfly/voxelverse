extends SceneTree
const Fleet = preload("res://space/fleet/fleet_state.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const EXPECTED: String = "user://fleet_expected.json"
var failures: Array[String] = []
var checks: int = 0
var saves: Node
var state: Node
var host_id: String
var guest_id: String
var bay_id: String
var asset_id: String

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	root.get_node("SessionFlow").enter_frontend()
	if "--fleet-restart" in OS.get_cmdline_user_args():
		_restart()
		await _finish()
		return
	var original: String = saves.create_slot("Unchanged adventure", 23757)
	var original_bytes: String = FileAccess.get_file_as_string(original)
	_expect(not original.is_empty() and not state.campaign.data.has(Fleet.FIELD), "Old/new regular campaign has no fleet injected")
	_expect(not saves.initialize_fleet_trial(), "Ordinary adventure cannot mint trial ships")
	var path: String = saves.create_slot("Flottentest", 15838)
	_expect(not path.is_empty() and saves.initialize_fleet_trial(), "Trial initializes through actual SaveGameService: " + saves.last_error)
	if not state.campaign.data.has(Fleet.FIELD): await _finish(); return
	for ship: Dictionary in _snapshot().ships.values():
		if ship.role == "expedition": host_id = ship.id; bay_id = ship.capabilities.bays.keys()[0]
		else: guest_id = ship.id
	asset_id = _snapshot().assets.keys()[0]
	_expect(not saves.initialize_fleet_trial(), "Trial initialization cannot duplicate instances or receipts")
	var cargo: Dictionary = {"kind": "cargo", "asset_id": asset_id, "target_id": host_id}
	_reject(cargo, "Cargo cannot teleport before docking")
	var dock: Dictionary = {"kind": "dock", "ship_id": guest_id, "host_id": host_id, "bay_id": bay_id}
	var before: Dictionary = _snapshot().duplicate(true)
	_expect(saves.request_fleet_command(dock, 0), "Dock writes whole snapshot")
	_expect(_snapshot().ships[guest_id].place.host_ship_id == host_id and _snapshot().revision == 1, "Exactly one dock location is committed")
	_expect(_snapshot().assets == before.assets and _snapshot().people == before.people, "Dock preserves cargo receipts and player location")
	_reject(cargo, "Stale screen cannot overwrite newer command", 0)
	var bytes: String = FileAccess.get_file_as_string(path)
	var backup: String = FileAccess.get_file_as_string(path + ".bak")
	var live: Dictionary = state.campaign.data[Fleet.FIELD].duplicate(true)
	_expect(DirAccess.make_dir_absolute(path + ".tmp") == OK, "Inject actual atomic writer failure")
	_expect(not saves.request_fleet_command(cargo, 1), "Failed save rejects cargo transfer")
	_expect(state.campaign.data[Fleet.FIELD] == live and FileAccess.get_file_as_string(path) == bytes and FileAccess.get_file_as_string(path + ".bak") == backup, "Write failure preserves source, backup, location and receipt")
	DirAccess.remove_absolute(path + ".tmp")
	_expect(saves.request_fleet_command(cargo, 1), "Cargo transfers after writer recovers")
	_expect(_snapshot().assets[asset_id].ship_id == host_id and _snapshot().assets.size() == 2, "Cargo changes its sole owner location without duplication")
	paused = true
	_reject({"kind": "undock", "ship_id": guest_id}, "Pause forbids commands")
	paused = false
	_expect(saves.request_fleet_command({"kind": "undock", "ship_id": guest_id}, 2), "Undock persists a single system location")
	_expect(_snapshot().ships[guest_id].place.kind == "system" and _snapshot().ships[guest_id].place.position == [0.0, 0.0, 60.0], "Undock returns to nearby trial staging berth")
	_reject({"kind": "cargo", "asset_id": asset_id, "target_id": guest_id}, "Disconnected hold cannot pull cargo back")
	_pin_checks()
	_model_rejections(dock)
	_expect(saves.request_fleet_command(dock, _snapshot().revision), "Dock again before restart")
	var expected: Dictionary = {"path": path, "fleet": state.campaign.data[Fleet.FIELD].duplicate(true), "original": original, "original_hash": original_bytes.sha256_text()}
	Atomic.write(EXPECTED, expected, false)
	var child_output: Array = []
	var child: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--fleet-restart"], child_output, true)
	_expect(child == 0 and str(child_output).contains("FLEET_RESTART_PASSED") and not str(child_output).contains("SCRIPT ERROR"), "Cold restart preserves pins after deleting loose design, cargo and dock: " + str(child_output))
	_version_checks(path)
	# Copy branches campaign identity while preserving all opaque ship/module IDs.
	saves.session_active = false
	var copy_path: String = saves.duplicate_slot(path, "Fleet branch")
	_expect(not copy_path.is_empty(), "Slot copy rebases fleet campaign ownership")
	if not copy_path.is_empty():
		var copy_data: Dictionary = saves._read_save(copy_path)
		_expect(copy_data.game_state.campaign.id != state.campaign.data.id and copy_data.game_state.campaign[Fleet.FIELD].snapshot.ships == _snapshot().ships, "Copy preserves ships and changes only campaign owner")
		saves.session_active = true
		_expect(saves.load_now(copy_path), "Copy passes actual loader")
		saves.save_path = path
		_expect(saves.load_now(), "Original still loads after branch copy")
	await _ui_checks(path)
	_expect(FileAccess.get_file_as_string(original) == original_bytes, "All trial actions leave the original adventure byte-identical")
	await _finish()

func _pin_checks() -> void:
	var design: Dictionary = Fleet.Ship.template("lander")
	var saved: Dictionary = Fleet.Ship.save_design(design)
	_expect(saved.ok, "Author design saved")
	var before_ids: Array = _snapshot().ships.keys()
	var add: Dictionary = {"kind": "instantiate", "path": saved.path, "host_id": host_id}
	_expect(saves.request_fleet_command(add, _snapshot().revision), "Instantiate from exact saved blueprint")
	var new_id: String = ""
	for id: String in _snapshot().ships:
		if id not in before_ids: new_id = id
	_expect(not new_id.is_empty() and new_id != design.design_id, "Instance has its own opaque ID")
	var pin: Dictionary = _snapshot().ships[new_id].duplicate(true)
	design.name = "Later revision"
	Fleet.Ship.save_design(design, saved.path)
	_expect(_snapshot().ships[new_id] == pin, "Author changes never rewrite a live pin")
	_expect(saves.request_fleet_command(add, _snapshot().revision), "New revision creates another independent ship")
	_expect(state.campaign.data[Fleet.FIELD].designs.size() == 4, "Both revisions persist with the two built-ins")
	DirAccess.remove_absolute(saved.path)
	DirAccess.remove_absolute(saved.path + ".bak")
	_expect(saves.save_now(), "Used designs persist without loose author files")

func _model_rejections(dock: Dictionary) -> void:
	var base: Dictionary = state.campaign.data.duplicate(true)
	var rev: int = _snapshot().revision
	for position: Array in [[0, 0, 100.01], [1000000000000.125, 0, 0]]:
		var distant: Dictionary = base.duplicate(true)
		distant[Fleet.FIELD].snapshot.ships[guest_id].place.position = position
		_expect(not Fleet.apply(distant, dock, rev).ok, "Distant ship cannot dock by supplying a host ID")
	var precise: Dictionary = base.duplicate(true)
	precise[Fleet.FIELD].snapshot.ships[host_id].place.position = [1000000000000.125, 0, 0]
	precise[Fleet.FIELD].snapshot.ships[guest_id].place.position = [1000000000060.125, 0, 0]
	_expect(Fleet.apply(precise, dock, rev).ok, "Nearby large Double positions remain usable")
	precise[Fleet.FIELD].snapshot.ships[guest_id].place.position[0] += 1000
	_expect(not Fleet.apply(precise, dock, rev).ok, "Float rounding cannot fake proximity at large coordinates")
	var occupied: Dictionary = Fleet.apply(base, dock, rev).data
	var other: String = ""
	for ship: Dictionary in occupied.snapshot.ships.values():
		if ship.role == "lander" and ship.id != guest_id: other = ship.id; break
	var occupied_campaign: Dictionary = base.duplicate(true)
	occupied_campaign[Fleet.FIELD] = occupied
	var second: Dictionary = dock.duplicate()
	second.ship_id = other
	_expect(not Fleet.apply(occupied_campaign, second, rev + 1).ok, "Occupied bay cannot acquire a second ship")
	var tampered: Dictionary = base.duplicate(true)
	tampered[Fleet.FIELD].snapshot.ships[guest_id].capabilities.cargo_space += 1000
	_expect(not Fleet.validate(tampered).is_empty(), "Stored capabilities cannot inflate a pinned design")
	tampered = base.duplicate(true)
	var receipt: Dictionary = tampered[Fleet.FIELD].snapshot.assets[asset_id].duplicate(true)
	receipt.id = "duplicate"
	tampered[Fleet.FIELD].snapshot.assets["duplicate"] = receipt
	_expect(not Fleet.validate(tampered).is_empty(), "A receipt cannot be present under two transport IDs")
	# Fill host through unique test receipts, then attempt a real cargo command.
	var full: Dictionary = occupied_campaign.duplicate(true)
	full[Fleet.FIELD].snapshot.assets.clear()
	full[Fleet.FIELD].snapshot.assets[asset_id] = {"id": asset_id, "kind": "cargo", "owner_module": "shipyard_trial", "record_id": "guest_lot", "space": 2, "ship_id": guest_id}
	full[Fleet.FIELD].snapshot.assets["full"] = {"id": "full", "kind": "cargo", "owner_module": "shipyard_trial", "record_id": "host_lot", "space": full[Fleet.FIELD].snapshot.ships[host_id].capabilities.cargo_space, "ship_id": host_id}
	_expect(Fleet.validate(full).is_empty() and not Fleet.apply(full, {"kind": "cargo", "asset_id": asset_id, "target_id": host_id}, rev + 1).ok, "Transfer respects derived cargo capacity")
	for malformed in [null, 1, [], {}, true]:
		var command: Dictionary = dock.duplicate()
		command.ship_id = malformed
		_expect(not Fleet.apply(base, command, rev).ok, "Malformed command identifier fails without a script error")
	var corrupt: Dictionary = base.duplicate(true)
	corrupt.bodies[corrupt.bodies.keys()[0]] = []
	_expect(Fleet.unsupported(corrupt), "Malformed context cannot crash preflight")
	_expect(state.campaign.data == base, "Rejected pure candidates never mutate campaign")

func _version_checks(path: String) -> void:
	var source: Dictionary = saves._read_save(path)
	for variant: String in ["schema", "pin", "snapshot", "mode", "extra", "cap_version", "place", "missing_pin"]:
		var future: Dictionary = source.duplicate(true)
		var value: Dictionary = future.game_state.campaign[Fleet.FIELD]
		match variant:
			"schema": value.schema = 999
			"pin": value.designs.values()[0].ship.catalog_revision = 999
			"snapshot": value.snapshot.schema = 999
			"mode": value.mode = "future_flight"
			"extra": value["future_data"] = {"value": 12}
			"cap_version": value.snapshot.ships.values()[0].capabilities.catalog_revision = 999
			"place": value.snapshot.ships.values()[0].place.kind = "future_orbit"
			"missing_pin": value.designs.erase(value.designs.keys()[0])
		Atomic.write(path + ".bak", source, false)
		Atomic.write(path, future, false)
		var bytes: String = FileAccess.get_file_as_string(path)
		var backup: String = FileAccess.get_file_as_string(path + ".bak")
		var live: Dictionary = state.export_state()
		_expect(not saves.load_now() and not saves.save_now() and not saves.request_fleet_command({"kind": "undock", "ship_id": guest_id}, _snapshot().revision), "Future " + variant + " blocks load, fallback and writes")
		_expect(state.export_state() == live and FileAccess.get_file_as_string(path) == bytes and FileAccess.get_file_as_string(path + ".bak") == backup, "Future " + variant + " preserves live/original/backup")
		Atomic.write(path, source, false)
		_expect(saves.load_now(), "Compatible fleet can recover after protected future file")

func _ui_checks(path: String) -> void:
	change_scene_to_file("res://ui/frontend/main_menu.tscn")
	await scene_changed
	var before_open: String = FileAccess.get_file_as_string(path)
	current_scene.find_child("FleetTrial", true, false).pressed.emit()
	await scene_changed
	_expect(FileAccess.get_file_as_string(path) == before_open, "Opening public fleet entry does not alter a slot")
	var panel: Control = current_scene
	var found: bool = false
	for i in range(panel.slots.item_count):
		if panel.slots.get_item_metadata(i) == path: panel.slots.select(i); found = true; break
	_expect(found, "Trial UI lists the persisted fleet")
	panel.find_child("LoadTrial", true, false).pressed.emit()
	_expect(panel.ships.item_count == _snapshot().ships.size() and not panel.saves._write_blocked, "Actual UI resumes all owned ships")
	for i in range(panel.ships.item_count):
		if panel.ships.get_item_metadata(i) == guest_id: panel.ships.select(i); panel.ships.item_selected.emit(i); break
	var before: int = _snapshot().revision
	panel.find_child("Undock", true, false).pressed.emit()
	_expect(_snapshot().revision == before + 1 and _snapshot().ships[guest_id].place.kind == "system", "UI dispatches durable undock")
	for i in range(panel.target.item_count):
		if panel.target.get_item_metadata(i) == host_id: panel.target.select(i); panel.target.item_selected.emit(i); break
	panel.find_child("Dock", true, false).pressed.emit()
	_expect(_snapshot().ships[guest_id].place.kind == "dock", "UI dispatches durable dock")
	# The ordinary Continue/save-browser route must return to this view.
	change_scene_to_file("res://ui/frontend/main_menu.tscn")
	await scene_changed
	await root.get_node("SessionFlow").load_game(path)
	await scene_changed
	panel = current_scene
	_expect(panel.scene_file_path == "res://space/fleet/fleet_trial.tscn" and saves.session_active and panel.ships.item_count == _snapshot().ships.size(), "Continue restores the trial without starting the surface campaign")
	root.get_node("LocaleManager")._apply("en")
	await scene_changed
	panel = current_scene
	_expect(panel.find_child("Dock", true, false).text == "Dock" and saves.session_active, "Language switch refreshes the panel and retains the active trial")
	root.get_node("LocaleManager")._apply("de")
	await scene_changed
	panel = current_scene
	_expect(panel.find_child("Dock", true, false).text == "Andocken", "German trial actions are translated")
	if "--capture" in OS.get_cmdline_user_args():
		var args: PackedStringArray = OS.get_cmdline_user_args()
		root.size = Vector2i(1280, 900)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[args.find("--capture") + 1])

func _restart() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED))
	saves.session_active = true
	saves.save_path = expected.path
	_expect(saves.load_now(), "Cold load passes common save validation: " + saves.last_error)
	_expect(state.campaign.data.get(Fleet.FIELD) == expected.fleet, "Exact pins, IDs, places, cargo, energy and revision survive restart")
	_expect(FileAccess.get_file_as_string(expected.original).sha256_text() == expected.original_hash, "Cold load preserves original adventure")
	if failures.is_empty(): print("FLEET_RESTART_PASSED")

func _snapshot() -> Dictionary: return state.campaign.data[Fleet.FIELD].snapshot

func _reject(command: Dictionary, message: String, revision: int = -1) -> void:
	var before: Dictionary = state.campaign.data[Fleet.FIELD].duplicate(true)
	var bytes: String = FileAccess.get_file_as_string(saves.save_path)
	_expect(not saves.request_fleet_command(command, _snapshot().revision if revision < 0 else revision), message)
	_expect(state.campaign.data[Fleet.FIELD] == before and FileAccess.get_file_as_string(saves.save_path) == bytes, message + " preserves state")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _finish() -> void:
	print(JSON.stringify({"test": "fleet_runtime", "passed": failures.is_empty(), "checks": checks, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
