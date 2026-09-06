extends Node
class_name SaveGameService

signal game_saved(path: String)
signal game_loaded(path: String)
signal save_failed(message: String)

const SAVE_SCHEMA: int = 2
const DEFAULT_SAVE_PATH: String = "user://voxelverse_save.json"

@export_range(5.0, 300.0, 5.0) var autosave_interval: float = 45.0
@export var autosave_enabled: bool = true

var save_path: String = DEFAULT_SAVE_PATH
var _autosave_timer: float = 0.0
var _pending_player_state: Dictionary = {}
var _pending_region_state: Dictionary = {}
var _regions_by_world: Dictionary = {}
var _loaded_once: bool = false


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
	if not FileAccess.file_exists(save_path):
		return false
	return load_now()


func save_now(custom_path: String = "") -> bool:
	var target_path: String = save_path if custom_path.is_empty() else custom_path
	_capture_current_region_state()
	var save_data: Dictionary = {
		"schema": SAVE_SCHEMA,
		"saved_unix_time": int(Time.get_unix_time_from_system()),
		"game_state": _export_node_state("/root/GameState"),
		"progression": _export_node_state("/root/ProgressionService"),
		"player": _export_player_state(),
		"regions_by_world": _regions_by_world.duplicate(true),
	}
	var temporary_path: String = target_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		_report_failure("Could not open save file: %s" % temporary_path)
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(target_path):
		var remove_error: Error = DirAccess.remove_absolute(target_path)
		if remove_error != OK:
			_report_failure("Could not replace old save: %s" % remove_error)
			return false
	var rename_error: Error = DirAccess.rename_absolute(temporary_path, target_path)
	if rename_error != OK:
		_report_failure("Could not finalize save: %s" % rename_error)
		return false
	game_saved.emit(target_path)
	return true


func load_now(custom_path: String = "") -> bool:
	var target_path: String = save_path if custom_path.is_empty() else custom_path
	if not FileAccess.file_exists(target_path):
		return false
	var file := FileAccess.open(target_path, FileAccess.READ)
	if file == null:
		_report_failure("Could not read save file: %s" % target_path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		_report_failure("Save file is not valid JSON state.")
		return false
	var data: Dictionary = parsed
	var schema: int = int(data.get("schema", 0))
	if schema <= 0 or schema > SAVE_SCHEMA:
		_report_failure("Unsupported save schema: %d" % schema)
		return false
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("import_state"):
		game_state.call("import_state", _dict(data.get("game_state", {})), true)
	var progression := get_node_or_null("/root/ProgressionService")
	if progression != null and progression.has_method("import_state"):
		progression.call("import_state", _dict(data.get("progression", {})))
	_regions_by_world = _dict(data.get("regions_by_world", {}))
	_pending_player_state = _dict(data.get("player", {}))
	_pending_region_state = _get_saved_region_state_for_current_world()
	_apply_pending_runtime_state()
	game_loaded.emit(target_path)
	return true


func clear_save() -> bool:
	if not FileAccess.file_exists(save_path):
		return true
	return DirAccess.remove_absolute(save_path) == OK


func prepare_planet_transition() -> void:
	_capture_current_region_state()
	save_now()
	_pending_player_state.clear()
	_pending_region_state.clear()


func queue_current_world_restore() -> void:
	_pending_region_state = _get_saved_region_state_for_current_world()


func _capture_current_region_state() -> void:
	var simulation := get_tree().get_first_node_in_group(&"region_background_simulation")
	if simulation == null or not simulation.has_method("export_state"):
		return
	var world_key: String = str(_get_world_seed())
	_regions_by_world[world_key] = simulation.call("export_state")


func _get_saved_region_state_for_current_world() -> Dictionary:
	var value: Variant = _regions_by_world.get(str(_get_world_seed()), {})
	return _dict(value)


func _apply_pending_runtime_state() -> void:
	if not _pending_region_state.is_empty():
		var simulation := get_tree().get_first_node_in_group(&"region_background_simulation")
		if simulation != null and simulation.has_method("import_state"):
			simulation.call("import_state", _pending_region_state)
			_pending_region_state.clear()
	if not _pending_player_state.is_empty():
		var player := get_tree().get_first_node_in_group(&"player")
		if player != null and player.has_method("import_runtime_state"):
			player.call("import_runtime_state", _pending_player_state)
			_pending_player_state.clear()


func _export_player_state() -> Dictionary:
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null and player.has_method("export_runtime_state"):
		var value: Variant = player.call("export_runtime_state")
		return _dict(value)
	return {}


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
	push_error(message)
	save_failed.emit(message)
