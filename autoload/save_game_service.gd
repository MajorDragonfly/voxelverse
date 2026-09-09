extends Node
const Neighbor = preload("res://world/tribe/neighbors/neighbor_state.gd")

signal game_saved(path: String)
signal game_loaded(path: String)
signal save_failed(message: String)
signal save_started(path: String)
signal slots_changed

const SAVE_SCHEMA: int = 8
const Surface = preload("res://core/campaign/surface_context.gd")
const Migration = preload("res://core/campaign/spherical_migration.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const GameModel = preload("res://autoload/game_state.gd")
const Animals = preload("res://world/domestication/campaign_animal_state.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Designs = preload("res://core/persistence/design_store.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const Campaign = preload("res://core/campaign/campaign_state.gd")
const GameEvent = preload("res://core/campaign/game_event.gd")
const Progression = preload("res://autoload/progression_service.gd")
const FaunaCatalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Exploration = preload("res://core/map/exploration_atlas.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const DEFAULT_SAVE_PATH: String = "user://voxelverse_save.json"
const SLOT_DIRECTORY: String = "user://saves"
const History = preload("res://core/persistence/slot_history.gd")

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
var _saving: bool = false
var _transition_busy: bool = false
var session_managed: bool = false
var session_active: bool = false
var slot_name: String = ""
var _slot_preview: Dictionary = {}
var _slot_origin: Dictionary = {}
var _save_reason: String = "manual"
var last_saved_unix_time: int = 0
var guidance := preload("res://core/onboarding_progress.gd").new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_autosave_timer = autosave_interval
	call_deferred("load_if_present")


func _process(delta: float) -> void:
	if session_managed and not session_active:
		return
	_apply_pending_runtime_state()
	if not autosave_enabled or (session_managed and get_tree().paused):
		return
	_autosave_timer -= delta
	if _autosave_timer > 0.0:
		return
	_autosave_timer = autosave_interval
	_save_reason = "automatic"
	save_now()
	_save_reason = "manual"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not session_managed:
		save_now()


func load_if_present() -> bool:
	if session_managed:
		return false
	if _loaded_once:
		return false
	_loaded_once = true
	if not FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path + ".bak"):
		return false
	return load_now()


func save_now(custom_path: String = "") -> bool:
	if _saving:
		return false
	_saving = true
	var result: bool = _save_snapshot(custom_path)
	_saving = false
	return result


func _save_snapshot(custom_path: String = "") -> bool:
	if session_managed and not session_active:
		return false
	if _write_blocked:
		_report_failure("Saving is blocked after an unreadable or newer save. Load a compatible save first.")
		return false
	var target_path: String = save_path if custom_path.is_empty() else custom_path
	save_started.emit(target_path)
	_capture_current_region_state()
	var files: Dictionary = Designs.capture()
	_upgrade_design_ids(files)
	_update_design_references(files)
	var save_data: Dictionary = {
		"slot_name": slot_name,
		"schema": SAVE_SCHEMA,
		"saved_unix_time": int(Time.get_unix_time_from_system()),
		"game_state": _export_node_state("/root/GameState"),
		"progression": _export_node_state("/root/ProgressionService"),
		"player": _export_player_state(),
		"regions_by_world": _regions_by_world.duplicate(true),
		"design_files": files,
		"migration_report": last_migration_report.duplicate(),
		"slot_preview": _slot_preview.duplicate(true) if int(_slot_preview.get("world_seed", 0)) == _get_world_seed() else {},
		"slot_origin": _slot_origin.duplicate(true),
		"onboarding": guidance.export_state(),
	}
	_annotate_world_state(save_data)
	var problem: String = _validate_save(save_data)
	if not problem.is_empty():
		_report_failure(problem)
		return false
	var previous: Dictionary = _read_save(target_path)
	if _has_unsupported_contract(previous):
		_write_blocked = true
		_report_failure("Der vorhandene Spielstand benötigt eine neuere Version und bleibt unverändert.")
		return false
	# The first migrated backup must also contain the editor bytes. The exact
	# original schema-1/2 files remain in the immutable migration backup.
	var keep_previous: bool = _validate_save(previous).is_empty()
	if keep_previous and is_slot_path(target_path):
		var history_error: Error = History.capture(target_path, previous, _save_reason)
		if history_error != OK:
			_report_failure("Sicherungshistorie konnte nicht geschrieben werden. Der bisherige Spielstand bleibt erhalten.")
			return false
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
	last_error = ""
	last_saved_unix_time = int(save_data["saved_unix_time"])
	if is_slot_path(target_path):
		History.trim(target_path)
	game_saved.emit(target_path)
	return true


func load_now(custom_path: String = "") -> bool:
	if _transition_busy or _saving:
		return false
	var target_path: String = save_path if custom_path.is_empty() else custom_path
	var source_path: String = target_path
	var data: Dictionary = _read_save(source_path)
	# Never silently downgrade a valid future schema to an old backup.
	if _has_unsupported_contract(data):
		_write_blocked = true
		_report_failure("Unsupported save, campaign, progression or generator version.")
		return false
	if not _validate_save(data).is_empty():
		source_path = target_path + ".bak"
		data = _read_save(source_path)
		if _has_unsupported_contract(data):
			_write_blocked = true
			_report_failure("Unsupported backup contract; saving remains blocked.")
			return false
	if not _validate_save(data).is_empty():
		_write_blocked = true
		_report_failure("No valid campaign snapshot or backup: " + target_path)
		return false
	last_migration_report.clear()
	var schema: int = int(data["schema"])
	if schema < SAVE_SCHEMA:
		# Schema 3 already owns campaign identity and the authoritative editor bytes.
		var files: Dictionary = _capture_disk_designs() if schema < 3 else _dict(data["design_files"])
		if not _backup_migration(target_path, source_path, schema, files):
			return false
		if schema < 3:
			var model := Campaign.new()
			model.reset(Ids.scoped("campaign", "legacy-save", FileAccess.get_file_as_string(source_path)))
			data["game_state"]["campaign"] = model.export_state()
			_upgrade_design_ids(files)
			data["design_files"] = files
		else:
			last_migration_report.assign(data.get("migration_report", []))
		last_migration_report.append("Schema %d -> %d; campaign, location, designs, behavior and encounters retained; surface mode unchanged." % [schema, SAVE_SCHEMA])
	else:
		last_migration_report.assign(data.get("migration_report", []))
	if source_path != target_path:
		last_migration_report.append("Recovered the previous complete snapshot from .bak.")
	for saved_body: Dictionary in data["game_state"]["campaign"].get("bodies", {}).values():
		if saved_body.has("tribe") and Tribe.upgrade(saved_body["tribe"]):
			last_migration_report.append("Tribe -> %d; residents, orders, cargo, stock and economy retained. Existing huts and paid construction keep their sites; new shelters, residents and husbandry develop in play." % Tribe.SCHEMA)
	_design_files = _dict(data.get("design_files", {}))
	slot_name = str(data.get("slot_name", "Bisheriges Abenteuer"))
	_slot_preview = _dict(data.get("slot_preview", {}))
	_slot_origin = _dict(data.get("slot_origin", {}))
	guidance.import_state(data.get("onboarding"))
	last_saved_unix_time = int(data.get("saved_unix_time", 0))
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
	last_error = ""
	return true


## Listing is read-only: validation and backup inspection never import a world.
func list_slots() -> Array[Dictionary]:
	var paths: Array[String] = []
	if FileAccess.file_exists(DEFAULT_SAVE_PATH) or FileAccess.file_exists(DEFAULT_SAVE_PATH + ".bak"):
		paths.append(DEFAULT_SAVE_PATH)
	if DirAccess.dir_exists_absolute(SLOT_DIRECTORY):
		for filename in DirAccess.get_files_at(SLOT_DIRECTORY):
			var candidate: String = filename.trim_suffix(".bak")
			if candidate.begins_with("slot_") and candidate.ends_with(".json"):
				var path: String = SLOT_DIRECTORY + "/" + candidate
				if path not in paths:
					paths.append(path)
		for directory in DirAccess.get_directories_at(SLOT_DIRECTORY):
			var path: String = SLOT_DIRECTORY.path_join(directory.trim_suffix(".history"))
			if directory.ends_with(".history") and is_slot_path(path) and path not in paths:
				paths.append(path)
	if DirAccess.dir_exists_absolute(History.directory(DEFAULT_SAVE_PATH)) and DEFAULT_SAVE_PATH not in paths:
		paths.append(DEFAULT_SAVE_PATH)
	var result: Array[Dictionary] = []
	for path in paths:
		result.append(inspect_slot(path))
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.saved_time) == int(b.saved_time):
			return str(a.path) > str(b.path)
		return int(a.saved_time) > int(b.saved_time))
	return result


func inspect_slot(path: String) -> Dictionary:
	var data: Dictionary = _read_save(path)
	var recovered: bool = false
	var newer: bool = _has_unsupported_contract(data)
	if not newer and not _validate_save(data).is_empty():
		var backup: Dictionary = _read_save(path + ".bak")
		newer = _has_unsupported_contract(backup)
		if not newer and _validate_save(backup).is_empty():
			data = backup
			recovered = true
	var valid: bool = not newer and _validate_save(data).is_empty()
	return _slot_summary(path, data, valid, recovered, newer)


func _slot_summary(path: String, data: Dictionary, valid: bool, recovered: bool = false, newer: bool = false) -> Dictionary:
	var state: Dictionary = _dict(data.get("game_state", {}))
	var campaign: Dictionary = _dict(state.get("campaign", {}))
	var title: String = str(data.get("slot_name", "")).strip_edges()
	if title.is_empty():
		title = "Bisheriges Abenteuer" if path == DEFAULT_SAVE_PATH else path.get_file().trim_suffix(".json")
	return {"path": path, "name": title, "valid": valid, "recovered": recovered,
		"saved_time": int(data.get("saved_unix_time", 0)), "seed": int(state.get("world_seed", 0)),
		"phase": int(state.get("phase", 0)), "seconds": float(campaign.get("elapsed_seconds", 0.0)),
		"planet_index": int(state.get("planet_index", 0)), "preview": _dict(data.get("slot_preview", {})),
		"history_count": History.paths(path).size(), "schema": int(data.get("schema", 0)),
		"surface_mode": _dict(_dict(campaign.get("bodies", {})).get(str(int(state.get("world_seed", 0))), {})).get("surface_mode", Surface.LEGACY),
		"has_migration_archive": not _dict(campaign.get("surface_migration", {})).is_empty(),
		"problem": "Benötigt eine neuere Spielversion." if newer else ("Spielstand und Sicherung nicht lesbar." if not valid else "")}


static func is_slot_path(path: String) -> bool:
	return path == DEFAULT_SAVE_PATH or (path.get_base_dir() == SLOT_DIRECTORY and path.get_file().begins_with("slot_") and path.get_file().ends_with(".json") and path == SLOT_DIRECTORY.path_join(path.get_file()))


func _read_compatible_slot(path: String) -> Dictionary:
	if not is_slot_path(path):
		return {}
	var current := _read_save(path)
	if _has_unsupported_contract(current):
		return {}
	if _validate_save(current).is_empty():
		return current
	var backup := _read_save(path + ".bak")
	return backup if not _has_unsupported_contract(backup) and _validate_save(backup).is_empty() else {}


func _can_manage_slots() -> bool:
	if session_active:
		_report_failure("Bitte zuerst zum Hauptmenü zurückkehren.")
		return false
	return true


func rename_slot(path: String, title: String) -> bool:
	if not _can_manage_slots():
		return false
	title = title.strip_edges().left(48)
	var data := _read_compatible_slot(path)
	if data.is_empty() or title.is_empty():
		_report_failure("Bitte einen lesbaren Spielstand und einen Namen auswählen.")
		return false
	if str(data.get("slot_name", "")) == title:
		return true
	var error: Error = History.capture(path, data, "rename")
	if error == OK:
		data["slot_name"] = title
		error = Atomic.write(path, data, _validate_save(_read_save(path)).is_empty())
	if error != OK:
		_report_failure("Der Spielstand konnte nicht umbenannt werden.")
		return false
	History.trim(path)
	last_error = ""
	slots_changed.emit()
	return true


func duplicate_slot(path: String, title: String = "") -> String:
	if not _can_manage_slots():
		return ""
	var data := _read_compatible_slot(path)
	return _write_slot_copy(data, title, "copy")


## Preflight is read-only and reports every known unconnected consumer. It
## deliberately does not recover a backup: the hash refers to selected bytes.
func preview_spherical_migration(path: String) -> Dictionary:
	if not is_slot_path(path): return {"ok": false, "blockers": ["Ungültiger Quellpfad."]}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok": false, "blockers": ["Die ausgewählte Primärdatei ist nicht lesbar. Eine Sicherung kann zuerst ausdrücklich als eigener Slot wiederhergestellt werden."]}
	if file.get_length() > Migration.MAX_SOURCE_BYTES: return {"ok": false, "blockers": ["Quelle überschreitet das 16-MiB-Budget dieser Kopiermigration."]}
	var source_text: String = file.get_as_text()
	file.close()
	var source: Dictionary = Atomic.parse_dictionary(source_text)
	if _has_unsupported_contract(source): return {"ok": false, "blockers": ["Neuere Quelldaten bleiben geschützt; kein Rückgriff auf eine ältere Sicherung."]}
	var problem: String = _validate_save(source)
	if not problem.is_empty(): return {"ok": false, "blockers": ["Quelle ist nicht vollständig lesbar: " + problem]}
	return Migration.plan(source, source_text, path)


func migrate_slot_to_sphere(path: String, expected_source_sha256: String) -> String:
	if not _can_manage_slots(): return ""
	var plan: Dictionary = preview_spherical_migration(path)
	if not plan.ok:
		_report_failure("Kugelumzug noch nicht möglich:\n" + "\n".join(plan.blockers))
		return ""
	if expected_source_sha256 != plan.manifest.source_sha256:
		_report_failure("Quelle wurde seit der Prüfung geändert. Bitte erneut prüfen.")
		return ""
	var target: String = SLOT_DIRECTORY.path_join("slot_sphere_" + str(plan.manifest.id) + ".json")
	if FileAccess.file_exists(target) or FileAccess.file_exists(target + ".bak"):
		var existing: Dictionary = _read_save(target)
		if not _has_unsupported_contract(existing) and _validate_save(existing).is_empty() and existing.game_state.campaign.get("surface_migration", {}).get("id") == plan.manifest.id:
			last_error = ""
			return target # Idempotent: never reset a copy that has been played.
		_report_failure("Die zugehörige Zielkopie existiert bereits und bleibt geschützt.")
		return ""
	var data: Dictionary = plan.data
	var campaign: Dictionary = data.game_state.campaign
	for field in ["object_id", "species_id", "faction_id"]:
		data.player[field] = campaign["player_" + field]
	if not _validate_save(data).is_empty() or Migration.inventory(data) != plan.manifest.inventory:
		_report_failure("Zielvertrag oder Inventarprüfung fehlgeschlagen.")
		return ""
	if DirAccess.make_dir_recursive_absolute(SLOT_DIRECTORY) != OK:
		_report_failure("Zielordner konnte nicht angelegt werden.")
		return ""
	var stage: String = target + ".migration-stage"
	var error: Error = Atomic.write(stage, data, false)
	var reread: Dictionary = _read_save(stage) if error == OK else {}
	var readback_problem: String = _validate_save(reread) if error == OK else ""
	if error == OK and (not readback_problem.is_empty() or Migration.fingerprint(reread) != Migration.fingerprint(data)):
		error = ERR_FILE_CORRUPT
	# The source must still match at commit time; a changed or newer file wins.
	if error == OK and FileAccess.get_file_as_string(path).sha256_text() != expected_source_sha256:
		error = ERR_BUSY
	if error == OK and not FileAccess.file_exists(target):
		error = DirAccess.rename_absolute(stage, target)
	elif error == OK:
		error = ERR_ALREADY_EXISTS
	if error != OK:
		_report_failure("Kugelkopie wurde nicht veröffentlicht: " + error_string(error) + (" · " + readback_problem if not readback_problem.is_empty() else ""))
		return ""
	if not _validate_save(_read_save(target)).is_empty():
		_report_failure("Die veröffentlichte Kopie konnte nicht bestätigt werden. Quelle bleibt erhalten.")
		return ""
	last_error = ""
	slots_changed.emit()
	return target


func restore_spherical_source(path: String) -> String:
	if not _can_manage_slots(): return ""
	var data: Dictionary = _read_compatible_slot(path)
	var manifest: Dictionary = _dict(_dict(_dict(data.get("game_state", {})).get("campaign", {})).get("surface_migration", {}))
	if not Migration.validate(manifest).is_empty():
		_report_failure("Kein geprüftes Flachweltarchiv in diesem Spielstand.")
		return ""
	return _write_slot_copy(Atomic.parse_dictionary(manifest.source_text), "", "recovery")


func list_slot_history(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_slot_path(path):
		return result
	var sources := History.paths(path)
	if FileAccess.file_exists(path + ".bak"):
		sources.append(path + ".bak")
	var seen := {}
	for source: String in sources:
		var data := _read_save(source)
		var meta: Dictionary = _dict(data.get("slot_history", {}))
		data.erase("slot_history")
		var identity: String = JSON.stringify(data).sha256_text()
		if seen.has(identity):
			continue
		seen[identity] = true
		var newer: bool = _has_unsupported_contract(data)
		var valid: bool = not newer and _validate_save(data).is_empty()
		var entry: Dictionary = _slot_summary(path, data, valid, false, newer)
		entry["source"] = source
		entry["reason"] = str(meta.get("reason", "backup"))
		entry["can_copy"] = valid and int(data.get("schema", 0)) >= 3
		result.append(entry)
	return result


func restore_slot_copy(path: String, source_path: String, title: String = "") -> String:
	if not _can_manage_slots():
		return ""
	if not is_slot_path(path) or not History.is_source(path, source_path):
		_report_failure("Diese Sicherung gehört nicht zum ausgewählten Abenteuer.")
		return ""
	var data := _read_save(source_path)
	return _write_slot_copy(data, title, "recovery")


func _write_slot_copy(source: Dictionary, title: String, kind: String) -> String:
	if _has_unsupported_contract(source) or not _validate_save(source).is_empty():
		_report_failure("Dieser Spielstand kann nicht kopiert werden.")
		return ""
	if int(source.get("schema", 0)) < 3:
		_report_failure("Bitte diesen älteren Spielstand zuerst laden und speichern, damit auch seine Kreaturenentwürfe gesichert sind.")
		return ""
	if DirAccess.make_dir_recursive_absolute(SLOT_DIRECTORY) != OK:
		_report_failure("Der Ordner für Spielstände konnte nicht angelegt werden.")
		return ""
	var data: Dictionary = source.duplicate(true)
	var campaign: Dictionary = data["game_state"]["campaign"]
	var old_identity: String = campaign["id"]
	campaign["id"] = Ids.create("campaign")
	# Preserve opaque object/design/body IDs and paid-target ledgers: the copy
	# branches an existing history, rather than recreating its discovered world.
	for event: Dictionary in campaign["recent_events"]:
		if str(event.get("campaign_id", "")) == old_identity:
			event["campaign_id"] = campaign["id"]
	for body: Dictionary in campaign["bodies"].values():
		if body.has(Animals.FIELD):
			body[Animals.FIELD]["registry"]["campaign_id"] = campaign["id"]
	if data["progression"].get("tribal", {}).get("campaign_id", "") == old_identity:
		data["progression"]["tribal"]["campaign_id"] = campaign["id"]
	data.erase("slot_history")
	data["slot_origin"] = {"kind": kind, "campaign_id": old_identity,
		"saved_unix_time": int(source.get("saved_unix_time", 0))}
	data["saved_unix_time"] = int(Time.get_unix_time_from_system())
	title = title.strip_edges().left(48)
	if title.is_empty():
		var old_title: String = str(source.get("slot_name", "Mein Abenteuer"))
		title = old_title.left(32) + (" – Sicherung" if kind == "recovery" else " – Kopie")
	data["slot_name"] = title
	var path: String = SLOT_DIRECTORY + "/slot_" + Crypto.new().generate_random_bytes(12).hex_encode() + ".json"
	if not _validate_save(data).is_empty() or Atomic.write(path, data, false) != OK:
		_report_failure("Die Spielstandkopie konnte nicht gespeichert werden.")
		return ""
	last_error = ""
	slots_changed.emit()
	return path


func cache_slot_preview(png: PackedByteArray, world_seed: int) -> void:
	if session_active and not png.is_empty() and png.size() <= 524288 and world_seed == _get_world_seed():
		_slot_preview = {"world_seed": world_seed, "png": Marshalls.raw_to_base64(png)}


func create_slot(title: String, seed_value: int = 0, surface_mode: String = Surface.LEGACY) -> String:
	if surface_mode not in [Surface.LEGACY, Surface.Cube.MODE]:
		_report_failure("Unbekannter Oberflächentyp.")
		return ""
	if DirAccess.make_dir_recursive_absolute(SLOT_DIRECTORY) != OK:
		_report_failure("Der Ordner für Spielstände konnte nicht angelegt werden.")
		return ""
	var path: String = SLOT_DIRECTORY + "/slot_" + Crypto.new().generate_random_bytes(12).hex_encode() + ".json"
	# Campaign reset leaves legacy design files on disk. An explicit empty
	# snapshot prevents a new campaign inheriting another campaign's creature.
	var state := get_node("/root/GameState")
	if seed_value > 0:
		state.call("start_world_with_seed", seed_value)
	else:
		state.call("start_new_random_world")
	if surface_mode == Surface.Cube.MODE:
		state.campaign.data.surface_policy = surface_mode
		var old: Dictionary = state.get_current_body()
		# A new reset has no body yet; body_for_seed uses the selected policy.
		if old.is_empty():
			_report_failure("Kein geeigneter Startbereich auf diesem Planeten gefunden. Bitte einen anderen Seed wählen.")
			return ""
		var spawn: Dictionary = old.surface_context.spawn
		var heading: Vector3 = -Surface.Cube.frame(Surface.Cube.vector(Surface.Cube.direction(spawn.face, spawn.u, spawn.v))).z
		_last_player_state = {"surface_address": spawn.duplicate(true), "surface_forward": [heading.x, heading.y, heading.z],
			"surface_velocity": [0.0, 0.0, 0.0], "surface_pitch": -0.18}
		_pending_player_state = _last_player_state.duplicate(true)
	_design_snapshot_active = true
	_design_files.clear()
	slot_name = title.strip_edges().left(48)
	guidance.reset(true)
	if slot_name.is_empty():
		slot_name = "Mein Abenteuer"
	save_path = path
	_loaded_once = true
	session_active = true
	if not save_now():
		session_active = false
		return ""
	return path


func select_slot(path: String) -> bool:
	var known: bool = false
	for slot in list_slots():
		if slot.path == path and slot.valid:
			known = true
			break
	if not known:
		last_error = "Dieser Spielstand kann nicht geladen werden."
		return false
	var previous_path: String = save_path
	save_path = path
	_loaded_once = true
	session_active = true
	if not load_now():
		save_path = previous_path
		session_active = false
		return false
	return true


func _backup_migration(target_path: String, source_path: String, schema: int, files: Dictionary) -> bool:
	var backup: Dictionary = {"legacy_save_text": FileAccess.get_file_as_string(source_path), "design_files": files}
	var backup_path: String = target_path + ".schema%d.backup.json" % schema
	if FileAccess.file_exists(backup_path) and _read_save(backup_path) != backup:
		backup_path = target_path + "." + JSON.stringify(backup).sha256_text().left(16) + ".migration-backup.json"
	if not FileAccess.file_exists(backup_path) and Atomic.write(backup_path, backup, false) != OK:
		_report_failure("Migration backup failed; original state was not changed.")
		_write_blocked = true
		return false
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
	var progression_problem: String = Progression.validate_state(data["progression"])
	if not progression_problem.is_empty():
		return progression_problem
	if schema >= 4 and int(data["progression"].get("schema", 0)) < 3:
		return "Schema 4 requires complete behavior progression."
	if schema >= 5 and int(data["progression"].get("schema", 0)) < 4:
		return "Schema 5 requires persistent creature encounters."
	var runtime: Variant = data["player"].get("behavior_runtime", {})
	if not runtime is Dictionary:
		return "Invalid player behavior state."
	for key in runtime:
		var value: Variant = runtime[key]
		if key not in ["stamina", "recovery_delay"] or not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > (100.0 if key == "stamina" else 0.8):
			return "Invalid player stamina state."
	var state: Dictionary = data["game_state"]
	if int(state.get("world_seed", 0)) <= 0 or int(state.get("phase", -1)) not in range(6):
		return "Invalid world seed or phase."
	if not data.get("regions_by_world", {}) is Dictionary:
		return "Invalid region state."
	if schema < 3:
		return ""
	var campaign: Variant = state.get("campaign")
	if not campaign is Dictionary or str(campaign.get("id", "")).is_empty() or (campaign.get("schema") != 1 and campaign.get("schema") != Campaign.SCHEMA):
		return "Invalid campaign identity or version."
	if campaign.has("surface_migration") and not campaign.surface_migration is Dictionary: return "Invalid migration section."
	if campaign.get("schema") == Campaign.SCHEMA:
		if campaign.get("surface_policy") not in [Surface.LEGACY, Surface.Cube.MODE] or not campaign.get("surface_migration") is Dictionary:
			return "Invalid campaign surface policy or migration record."
		if not campaign.surface_migration.is_empty():
			var manifest_problem: String = Migration.validate(campaign.surface_migration)
			if not manifest_problem.is_empty(): return manifest_problem
			var archived: Dictionary = Atomic.parse_dictionary(campaign.surface_migration.source_text)
			if _has_unsupported_contract(archived): return "Unknown contract in migration source archive."
			var archived_problem: String = _validate_save(archived)
			if not archived_problem.is_empty(): return "Invalid migration source archive: " + archived_problem
	var tribal: Dictionary = data["progression"].get("tribal", {})
	if not str(tribal.get("campaign_id", "")).is_empty():
		if tribal["campaign_id"] != campaign.get("id") or tribal["species_id"] != campaign.get("player_species_id") or tribal["faction_id"] != campaign.get("player_faction_id"):
			return "Stammesfortschritt gehört zu einer anderen Kampagne, Spezies oder Fraktion."
	for field in ["bodies", "event_cursors", "design_refs", "pending_transition", "completed_transitions"]:
		if not campaign.get(field) is Dictionary:
			return "Invalid campaign section: " + field
	for body in campaign["bodies"].values():
		if not body is Dictionary or body.get("generator_version") != Campaign.GENERATOR_VERSION:
			return "Unsupported body generator/surface version."
		var surface_problem: String = Surface.validate(body)
		if not surface_problem.is_empty(): return surface_problem
		if body.surface_mode == Surface.Cube.MODE and (schema < 8 or campaign.schema < 2): return "Sphere requires save 8 and campaign 2."
		if body.surface_mode == Surface.Cube.MODE:
			var regions: Variant = data.get("regions_by_world", {}).get(str(int(body.seed)), {})
			if not regions is Dictionary or not regions.is_empty(): return "Planar regional state requires an explicit regional migration adapter."
		if body.has("home_group"):
			var home_problem: String = Home.validate(body.home_group, str(body.id), str(campaign.player_species_id))
			if not home_problem.is_empty(): return home_problem
		if body.has("fauna_catalog"):
			var fauna_problem: String = FaunaCatalog.validate(body["fauna_catalog"], body)
			if not fauna_problem.is_empty():
				return fauna_problem
		var animal_problem: String = Animals.validate_body(body, campaign)
		if not animal_problem.is_empty():
			return animal_problem
		if body.has("exploration_atlas"):
			var map_problem: String = Exploration.validate(body["exploration_atlas"], str(body.get("id", "")))
			if not map_problem.is_empty(): return map_problem
			if body["exploration_atlas"]["mode"] != body["surface_mode"]: return "Map and body surface modes differ."
		if body.has("tribe"):
			var tribe_problem: String = Tribe.validate(body["tribe"], body, campaign)
			if not tribe_problem.is_empty():
				return tribe_problem
		if body.has("tribal_neighbor"):
			if int(tribal.get("schema", 0)) < 3:
				return "Nachbarlager benötigt Stammesfortschrittformat 3."
			var neighbor_problem: String = Neighbor.validate(body["tribal_neighbor"], body.get("tribe", {}), campaign)
			if not neighbor_problem.is_empty():
				return neighbor_problem
	var active: Dictionary = campaign.bodies.get(str(int(state.world_seed)), {})
	for mapping: Dictionary in campaign.get("surface_migration", {}).get("mapping", []):
		var matched: bool = false
		for body: Dictionary in campaign.bodies.values():
			if body.id == mapping.body_id:
				matched = Migration.fingerprint(body.get("surface_context", {})) == mapping.target_context_sha256
		if not matched: return "Migrated body differs from its verified surface mapping."
	if active.get("surface_mode") == Surface.Cube.MODE:
		if int(state.phase) != 0 or not campaign.pending_transition.is_empty(): return "Radial phase handoff is not available yet."
		var player_problem: String = Surface.player_problem(data.player, active)
		if not player_problem.is_empty(): return player_problem
		for field in ["object_id", "species_id", "faction_id"]:
			if data.player.get(field) != campaign.get("player_" + field): return "Player identity differs from campaign."
	var aid_award: Dictionary = tribal.get("awards", {}).get("neighbor_help", {})
	if not aid_award.is_empty():
		var found: bool = false
		for body: Dictionary in campaign["bodies"].values():
			var neighbor: Dictionary = body.get("tribal_neighbor", {})
			if neighbor.get("id") == aid_award["neighbor_id"] and neighbor.get("village_id") == aid_award["village_id"] and neighbor.get("aid", {}).get("id") == aid_award["agreement_id"] and Neighbor.progress(neighbor)["met"]:
				found = true
		if not found:
			return "Stammesverdienst ohne erfüllte Nachbarhilfe."
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
		if state.call("get_current_body")["surface_mode"] == Surface.LEGACY:
			player["surface_address"] = campaign.surface_address(state.call("get_current_body")["id"], player.get("position", [0, 0, 0]), float(player.get("yaw", 0)))
		player["design_ref"] = campaign.data["design_refs"].get("user://creature_assembly_v7.json", {}).duplicate(true)
	data["game_state"] = state.call("export_state")


func is_phase_transition_active() -> bool:
	return _transition_busy


func request_phase_transition(new_phase: int, confirmation_token: String = "") -> bool:
	if _transition_busy or _saving:
		return false
	var state: Node = get_node("/root/GameState")
	var blockers: Array = state.get_phase_transition_blockers(new_phase)
	if not blockers.is_empty():
		_report_failure(str(blockers[0]))
		return false
	var runtime: Node = get_tree().get_first_node_in_group(&"tribe_controller")
	var handoff: Dictionary = runtime.confirmed_handoff(confirmation_token) if runtime != null else {}
	if new_phase != 1 or handoff.is_empty():
		_report_failure("Bestätige den Wechsel im Fenster für das Stammeszeitalter erneut.")
		return false
	var campaign = state.campaign
	var transition_id: String = Ids.scoped("transition", campaign.data["id"], "0:1")
	if campaign.data["completed_transitions"].has(transition_id):
		return false
	var before: Dictionary = campaign.export_state()
	_transition_busy = true
	var body_key: String = str(state.get_world_seed())
	campaign.data["bodies"][body_key]["tribe"] = handoff
	state.current_phase = 1
	var event = campaign.next_event(GameEvent.Kind.PHASE_TRANSITION, campaign.data["player_faction_id"], 1, "completed")
	campaign.accept_event(event, 1)
	campaign.data["completed_transitions"][transition_id] = {"id": transition_id, "from": 0, "to": 1,
		"confirmed": true, "tribe_id": handoff["id"], "body_id": handoff["body_id"]}
	# One atomic replacement owns both the phase and the full village. A crash
	# can load only the old creature snapshot or this complete tribal snapshot.
	var saved: bool = save_now()
	if not saved:
		state.current_phase = 0
		campaign.import_state(before)
	_transition_busy = false
	if not saved:
		return false
	state.phase_changed.emit(1)
	state.campaign_event.emit(event.to_dict())
	return true


func debug_prepare_phase_transition(new_phase: int, custom_path: String = "") -> bool:
	if _transition_busy or _saving:
		return false
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
	_slot_preview.clear()
	_slot_origin.clear()
	last_saved_unix_time = 0
	guidance.reset()


func clear_save() -> bool:
	if _transition_busy or _saving:
		return false
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
	if Progression.has_unsupported_contract(data.get("progression", {})):
		return true
	var imported_state: Variant = data.get("game_state", {})
	if not imported_state is Dictionary:
		return false
	if float(imported_state.get("schema", 0)) > GameModel.STATE_SCHEMA: return true
	var campaign: Variant = imported_state.get("campaign", {})
	if not campaign is Dictionary:
		return false
	if int(campaign.get("schema", 0)) > Campaign.SCHEMA:
		return true
	if campaign.has("surface_policy") and campaign.surface_policy not in [Surface.LEGACY, Surface.Cube.MODE]: return true
	if campaign.get("surface_migration") is Dictionary and not campaign.surface_migration.is_empty() and campaign.surface_migration.get("schema") != Migration.SCHEMA: return true
	if campaign.get("surface_migration") is Dictionary and not campaign.surface_migration.is_empty():
		if campaign.surface_migration.get("algorithm") != "early_campaign_copy_v1": return true
		var archive: Variant = campaign.surface_migration.get("source_text")
		if archive is String and archive.to_utf8_buffer().size() <= Migration.MAX_SOURCE_BYTES:
			var source: Dictionary = Atomic.parse_dictionary(archive)
			var nested: Variant = _dict(_dict(source.get("game_state", {})).get("campaign", {})).get("surface_migration")
			if nested is Dictionary and not nested.is_empty(): return true
			if _has_unsupported_contract(source): return true
	var bodies: Variant = campaign.get("bodies", {})
	if bodies is Dictionary:
		for body in bodies.values():
			if body is Dictionary and Surface.unsupported(body): return true
			if body is Dictionary and body.get("home_group") is Dictionary and body.home_group.get("schema") != Home.SCHEMA: return true
			if body is Dictionary and Exploration.newer(body.get("legacy_exploration_atlas")): return true
			if body is Dictionary and Animals.unsupported(body):
				return true
			if body is Dictionary and Neighbor.has_unsupported_contract(body.get("tribal_neighbor")):
				return true
			if body is Dictionary and body.has("fauna_catalog") and FaunaCatalog.has_unsupported(body["fauna_catalog"]):
				return true
			if body is Dictionary and Exploration.newer(body.get("exploration_atlas")): return true
			if body is Dictionary and body.get("tribe") is Dictionary and int(body["tribe"].get("schema", 0)) > Tribe.SCHEMA:
				return true
			if body is Dictionary and body.has("generator_version") and body["generator_version"] != Campaign.GENERATOR_VERSION:
				return true
	return false
