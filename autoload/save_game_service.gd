extends Node

signal game_saved(path: String)
signal game_loaded(path: String)
signal save_failed(message: String)

const SAVE_SCHEMA: int = 3
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Designs = preload("res://core/persistence/design_store.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const Campaign = preload("res://core/campaign/campaign_state.gd")
const GameEvent = preload("res://core/campaign/game_event.gd")
const DEFAULT_SAVE_PATH: String = "user://voxelverse_save.json"

@export_range(5.0, 300.0, 5.0) var autosave_interval: float = 45.0
@export var autosave_enabled: bool = true

var save_path: String = DEFAULT_SAVE_PATH
var _autosave_timer: float = 0.0
var _pending_player_state: Dictionary = {}
var _pending_region_state: Dictionary = {}
var _last_player_state: Dictionary = {}
var _regions_by_world: Dictionary = {}
var _loaded_once: bool = false
var _design_snapshot_active: bool = false
var _design_files: Dictionary = {}
var _write_blocked: bool = false
var last_migration_report: Array[String] = []
var last_error: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_autosave_timer = autosave_interval
	call_deferred("load_if_present")


func _process(delta: float) -> void:
	_apply_pending_runtime_state()
	if not autosave_enabled:
		return
	_autosave_timer -= delta
	if _autosave_timer > 0.0:
		return
	_autosave_timer = autosave_interval
	save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


func load_if_present() -> bool:
	if _loaded_once:
		return false
	_loaded_once = true
	if not FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path + ".bak"):
		return false
	return load_now()


func save_now(custom_path: String = "") -> bool:
	if _write_blocked:
		_report_failure("Saving is blocked after an unreadable or newer save. Load a compatible save first.")
		return false
	var target_path: String = save_path if custom_path.is_empty() else custom_path
	_capture_current_region_state()
	var files: Dictionary = Designs.capture()
	_upgrade_design_ids(files)
	_update_design_references(files)
	var save_data: Dictionary = {
		"schema": SAVE_SCHEMA,
		"saved_unix_time": int(Time.get_unix_time_from_system()),
		"game_state": _export_node_state("/root/GameState"),
		"progression": _export_node_state("/root/ProgressionService"),
		"player": _export_player_state(),
		"regions_by_world": _regions_by_world.duplicate(true),
		"design_files": files,
		"migration_report": last_migration_report.duplicate(),
	}
	_annotate_world_state(save_data)
	var problem: String = _validate_save(save_data)
	if not problem.is_empty():
		_report_failure(problem)
		return false
	var previous: Dictionary = _read_save(target_path)
	# The first migrated backup must also contain the editor bytes. The exact
	# original schema-1/2 files remain in the immutable migration backup.
	var keep_previous: bool = _validate_save(previous).is_empty()
	if keep_previous and int(previous.get("schema", 0)) < SAVE_SCHEMA:
		var backup_error: Error = Atomic.write(target_path + ".bak", save_data, false)
		if backup_error != OK:
			_report_failure("Could not commit complete migration recovery snapshot.")
			return false
		keep_previous = false
	var error: Error = Atomic.write(target_path, save_data, keep_previous)
	if error != OK:
		_report_failure("Could not commit save: %s (%s)" % [target_path, error_string(error)])
		return false
	_design_files = files
	_design_snapshot_active = true
	game_saved.emit(target_path)
	return true


func load_now(custom_path: String = "") -> bool:
	var target_path: String = save_path if custom_path.is_empty() else custom_path
	var source_path: String = target_path
	var data: Dictionary = _read_save(source_path)
	# Never silently downgrade a valid future schema to an old backup.
	if _has_unsupported_contract(data):
		_write_blocked = true
		_report_failure("Unsupported save, campaign or generator version.")
		return false
	if not _validate_save(data).is_empty():
		source_path = target_path + ".bak"
		data = _read_save(source_path)
	if not _validate_save(data).is_empty():
		_write_blocked = true
		_report_failure("No valid campaign snapshot or backup: " + target_path)
		return false
	last_migration_report.clear()
	var schema: int = int(data["schema"])
	if schema < SAVE_SCHEMA:
		# Preserve the exact legacy campaign and ALL editor bytes together before
		# importing anything. Migration never rewrites the old editor files.
		var files: Dictionary = _capture_disk_designs()
		var backup: Dictionary = {"legacy_save_text": FileAccess.get_file_as_string(source_path), "design_files": files}
		var backup_path: String = target_path + ".schema%d.backup.json" % schema
		if not FileAccess.file_exists(backup_path):
			if Atomic.write(backup_path, backup, false) != OK:
				_report_failure("Migration backup failed; original state was not changed.")
				_write_blocked = true
				return false
		elif _read_save(backup_path) != backup:
			# Another imported legacy file must not silently reuse an unrelated backup.
			backup_path = target_path + "." + JSON.stringify(backup).sha256_text().left(16) + ".migration-backup.json"
			if not FileAccess.file_exists(backup_path) and Atomic.write(backup_path, backup, false) != OK:
				_report_failure("Migration backup failed; original state was not changed.")
				_write_blocked = true
				return false
		var model := Campaign.new()
		model.reset(Ids.scoped("campaign", "legacy-save", str(backup["legacy_save_text"])))
		data["game_state"]["campaign"] = model.export_state()
		_upgrade_design_ids(files)
		data["design_files"] = files
		last_migration_report.append("Schema %d -> 3; legacy V9 plane retained; campaign and editor originals backed up." % schema)
	else:
		last_migration_report.assign(data.get("migration_report", []))
	if source_path != target_path:
		last_migration_report.append("Recovered the previous complete snapshot from .bak.")
	_design_files = _dict(data.get("design_files", {}))
	_design_snapshot_active = true
	_write_blocked = false
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.call("import_state", _dict(data.get("game_state", {})), true)
	var progression := get_node_or_null("/root/ProgressionService")
	if progression != null:
		progression.call("import_state", _dict(data.get("progression", {})))
	_regions_by_world = _dict(data.get("regions_by_world", {}))
	_last_player_state = _dict(data.get("player", {}))
	_pending_player_state = _last_player_state.duplicate(true)
	_pending_region_state = _get_saved_region_state_for_current_world()
	_update_design_references(_design_files)
	_apply_pending_runtime_state()
	if not resume_phase_transition(target_path):
		return false
	game_loaded.emit(target_path)
	return true


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return Atomic.parse_dictionary(FileAccess.get_file_as_string(path))


func _validate_save(data: Dictionary) -> String:
	var schema: int = int(data.get("schema", 0))
	if schema < 1 or schema > SAVE_SCHEMA:
		return "Unsupported or missing save schema."
	for field in ["game_state", "progression", "player"]:
		if not data.get(field) is Dictionary:
			return "Invalid save section: " + field
	var state: Dictionary = data["game_state"]
	if int(state.get("world_seed", 0)) <= 0 or int(state.get("phase", -1)) not in range(6):
		return "Invalid world seed or phase."
	if not data.get("regions_by_world", {}) is Dictionary:
		return "Invalid region state."
	if schema < 3:
		return ""
	var campaign: Variant = state.get("campaign")
	if not campaign is Dictionary or str(campaign.get("id", "")).is_empty() or int(campaign.get("schema", 0)) != Campaign.SCHEMA:
		return "Invalid campaign identity or version."
	for field in ["bodies", "event_cursors", "design_refs", "pending_transition", "completed_transitions"]:
		if not campaign.get(field) is Dictionary:
			return "Invalid campaign section: " + field
	for body in campaign["bodies"].values():
		if not body is Dictionary or body.get("generator_version") != Campaign.GENERATOR_VERSION or body.get("surface_mode") != Campaign.SURFACE_MODE:
			return "Unsupported body generator/surface version."
	if not campaign.get("recent_events") is Array or campaign["recent_events"].size() > 32:
		return "Invalid event history."
	for field in ["player_species_id", "player_faction_id", "player_object_id"]:
		if str(campaign.get(field, "")).is_empty():
			return "Missing society identity: " + field
	if not is_finite(float(campaign.get("elapsed_seconds", -1))) or float(campaign.get("elapsed_seconds", -1)) < 0 or float(campaign.get("time_scale", -1)) not in [0.0, 1.0, 2.0, 4.0]:
		return "Invalid campaign time."
	if not data.get("design_files") is Dictionary:
		return "Missing design snapshot."
	for path in data["design_files"].keys():
		if not Designs.is_managed(str(path)) or not data["design_files"][path] is String:
			return "Invalid design snapshot path/content."
	var pending: Dictionary = campaign["pending_transition"]
	if not pending.is_empty():
		if not bool(pending.get("debug", false)) or int(pending.get("from", -1)) != int(state["phase"]) or int(pending.get("to", -1)) != int(state["phase"]) + 1 or int(pending.get("to", 6)) > 5 or str(pending.get("id", "")).is_empty() or not pending.get("handoff") is Dictionary:
			return "Invalid prepared phase transition."
	return ""


func _capture_disk_designs() -> Dictionary:
	var active: bool = _design_snapshot_active
	_design_snapshot_active = false
	var result: Dictionary = Designs.capture()
	_design_snapshot_active = active
	return result


func record_design(path: String, text: String) -> void:
	if not _design_snapshot_active:
		_design_files = Designs.capture()
	_design_files[path] = text
	_design_snapshot_active = true
	schedule_autosave()


func _upgrade_design_ids(files: Dictionary) -> void:
	for path in files.keys():
		var parsed: Dictionary = Atomic.parse_dictionary(str(files[path]))
		if parsed.is_empty():
			var warning: String = "Unreadable design retained unchanged: " + str(path)
			if warning not in last_migration_report:
				last_migration_report.append(warning)
			continue
		if str(parsed.get("design_id", "")).is_empty():
			Ids.ensure_design(parsed, str(path))
			files[path] = JSON.stringify(parsed, "\t")


func _update_design_references(files: Dictionary) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	var references: Dictionary = {}
	for path in files.keys():
		var parsed: Dictionary = Atomic.parse_dictionary(str(files[path]))
		if not parsed.is_empty():
			var revision: int = int(parsed.get("assembly", {}).get("revision", parsed.get("revision", 0)))
			references[path] = {"design_id": str(parsed.get("design_id", "")), "revision": revision}
	state.get("campaign").data["design_refs"] = references


func _annotate_world_state(data: Dictionary) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	var campaign = state.get("campaign")
	for key in data["regions_by_world"].keys():
		var world: Dictionary = data["regions_by_world"][key]
		var body: Dictionary = campaign.body_for_seed(int(key), int(state.call("get_system_seed")))
		world["body_id"] = body["id"]
		for region in world.get("regions", {}).values():
			region["id"] = campaign.region_id(body["id"], Vector2i(int(region.get("x", 0)), int(region.get("z", 0))))
			for species in region.get("species", []):
				species["id"] = campaign.species_id(body["id"], int(species.get("species_seed", 1)))
	var player: Dictionary = data["player"]
	if not player.is_empty():
		player["object_id"] = campaign.data["player_object_id"]
		player["species_id"] = campaign.data["player_species_id"]
		player["faction_id"] = campaign.data["player_faction_id"]
		player["surface_address"] = campaign.surface_address(state.call("get_current_body")["id"], player.get("position", [0, 0, 0]), float(player.get("yaw", 0)))
		player["design_ref"] = campaign.data["design_refs"].get("user://creature_assembly_v7.json", {}).duplicate(true)
	data["game_state"] = state.call("export_state")


func request_phase_transition(new_phase: int) -> bool:
	var blockers: Array = get_node("/root/GameState").call("get_phase_transition_blockers", new_phase)
	if not blockers.is_empty():
		_report_failure(str(blockers[0]))
		return false
	return false # Real society handoff is implemented in M5, never inferred here.


func debug_prepare_phase_transition(new_phase: int, custom_path: String = "") -> bool:
	var state := get_node("/root/GameState")
	var campaign = state.get("campaign")
	var current_phase: int = int(state.get("current_phase"))
	if new_phase != current_phase + 1 or new_phase > 5 or not campaign.data["pending_transition"].is_empty():
		return false
	var transition_id: String = Ids.scoped("transition", campaign.data["id"], "%d:%d" % [current_phase, new_phase])
	if campaign.data["completed_transitions"].has(transition_id):
		return false
	_update_design_references(Designs.capture())
	var handoff: Dictionary = {"species_id": campaign.data["player_species_id"],
		"faction_id": campaign.data["player_faction_id"], "body": state.call("get_current_body"),
		"player": _export_player_state(), "design_refs": campaign.data["design_refs"].duplicate(true)}
	campaign.data["pending_transition"] = {"id": transition_id,
		"from": current_phase, "to": new_phase, "debug": true, "handoff": handoff}
	if save_now(custom_path):
		return true
	campaign.data["pending_transition"] = {}
	return false


func resume_phase_transition(custom_path: String = "") -> bool:
	var state := get_node("/root/GameState")
	var campaign = state.get("campaign")
	var pending: Dictionary = campaign.data["pending_transition"]
	if pending.is_empty():
		return true
	var before: Dictionary = campaign.export_state()
	var from_phase: int = int(state.get("current_phase"))
	var target: int = int(pending["to"])
	state.set("current_phase", target)
	var event = campaign.next_event(GameEvent.Kind.PHASE_TRANSITION, campaign.data["player_faction_id"], target, "completed")
	campaign.accept_event(event, target)
	campaign.data["completed_transitions"][pending["id"]] = pending.duplicate(true)
	campaign.data["pending_transition"] = {}
	if not save_now(custom_path):
		state.set("current_phase", from_phase)
		campaign.import_state(before)
		return false
	# Observers see completion only after the whole state has been committed.
	state.emit_signal("phase_changed", target)
	state.emit_signal("campaign_event", event.to_dict())
	return true


func reset_runtime_for_new_game() -> void:
	_last_player_state.clear()
	_regions_by_world.clear()
	_pending_player_state.clear()
	_pending_region_state.clear()
	_design_files.clear()
	_design_snapshot_active = false
	_write_blocked = false
	last_migration_report.clear()


func clear_save() -> bool:
	reset_runtime_for_new_game()
	var success: bool = true
	for path in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			success = DirAccess.remove_absolute(path) == OK and success
	return success


func prepare_planet_transition() -> bool:
	_capture_current_region_state()
	if not save_now():
		return false
	_pending_player_state.clear()
	_pending_region_state.clear()
	_last_player_state.clear()
	return true


func queue_current_world_restore() -> void:
	_pending_region_state = _get_saved_region_state_for_current_world()
	_autosave_timer = 2.0


func schedule_autosave(delay: float = 2.0) -> void:
	_autosave_timer = clampf(delay, 0.1, autosave_interval)


func _capture_current_region_state() -> void:
	var simulation := get_tree().get_first_node_in_group(&"region_background_simulation")
	if simulation == null or not simulation.has_method("export_state"):
		return
	var exported: Dictionary = simulation.call("export_state")
	if not _pending_region_state.is_empty() or int(exported.get("world_seed", -1)) != _get_world_seed():
		return
	var world_key: String = str(_get_world_seed())
	_regions_by_world[world_key] = exported


func _get_saved_region_state_for_current_world() -> Dictionary:
	var value: Variant = _regions_by_world.get(str(_get_world_seed()), {})
	return _dict(value)


func _apply_pending_runtime_state() -> void:
	if not _pending_region_state.is_empty():
		var simulation := get_tree().get_first_node_in_group(&"region_background_simulation")
		if simulation != null and simulation.has_method("import_state") and int(simulation.call("export_state").get("world_seed", -1)) == _get_world_seed():
			simulation.call("import_state", _pending_region_state)
			_pending_region_state.clear()
	if not _pending_player_state.is_empty():
		var player := get_tree().get_first_node_in_group(&"player")
		if player != null and player.has_method("import_runtime_state"):
			player.call("import_runtime_state", _pending_player_state)
			_last_player_state = _pending_player_state.duplicate(true)
			_pending_player_state.clear()


func _export_player_state() -> Dictionary:
	if not _pending_player_state.is_empty():
		return _pending_player_state.duplicate(true)
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null and player.has_method("export_runtime_state"):
		var value: Variant = player.call("export_runtime_state")
		_last_player_state = _dict(value)
	return _last_player_state.duplicate(true)


func _export_node_state(path: String) -> Dictionary:
	var node := get_node_or_null(path)
	if node != null and node.has_method("export_state"):
		var value: Variant = node.call("export_state")
		return _dict(value)
	return {}


func _get_world_seed() -> int:
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("get_world_seed"):
		return int(game_state.call("get_world_seed"))
	return 1


func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _report_failure(message: String) -> void:
	last_error = message
	push_warning(message)
	save_failed.emit(message)


func _has_unsupported_contract(data: Dictionary) -> bool:
	if int(data.get("schema", 0)) > SAVE_SCHEMA:
		return true
	var imported_state: Variant = data.get("game_state", {})
	if not imported_state is Dictionary:
		return false
	var campaign: Variant = imported_state.get("campaign", {})
	if not campaign is Dictionary:
		return false
	if int(campaign.get("schema", 0)) > Campaign.SCHEMA:
		return true
	var bodies: Variant = campaign.get("bodies", {})
	if bodies is Dictionary:
		for body in bodies.values():
			if body is Dictionary and body.has("generator_version") and body["generator_version"] != Campaign.GENERATOR_VERSION:
				return true
	return false
