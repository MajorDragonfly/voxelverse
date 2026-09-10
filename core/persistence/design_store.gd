extends RefCounted
class_name CampaignDesignStore

const Atomic = preload("res://core/persistence/atomic_json.gd")
const Contract = preload("res://assembly/core/blueprint_contract.gd")
const FIXED_PATHS: Array[String] = ["user://creature_assembly_v7.json",
	"user://creature_editor_blueprint_v5.json", "user://creature_editor_blueprint.json", "user://creature_editor_spine_v4.json",
	"user://building_builder_autosave.json"]
const BUILDING_DIR: String = "user://building_designs"


static func is_managed(path: String) -> bool:
	return path in FIXED_PATHS or (path.get_base_dir() == BUILDING_DIR and path.get_file().ends_with(".json"))


static func service() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("SaveGameService") if tree != null else null


static func read_text(path: String) -> String:
	var owner := service()
	if is_managed(path) and owner != null and bool(owner.get("_design_snapshot_active")):
		return str(owner.get("_design_files").get(path, ""))
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


static func write(path: String, value: Dictionary) -> Error:
	var owner := service()
	if is_managed(path) and owner != null and bool(owner.get("_write_blocked")):
		return ERR_UNAVAILABLE
	if is_blueprint(path, value):
		if not Contract.inspect(value).ok: return ERR_INVALID_DATA
		# Check both the authoritative slot and the loose file before touching
		# either. A fallback preview must never overwrite a protected original.
		if not write_status(path).ok: return ERR_UNAVAILABLE
	var error: Error = Atomic.write(path, value)
	if error == OK and is_managed(path) and owner != null:
		owner.call("record_design", path, JSON.stringify(value, "\t"))
	return error


static func is_blueprint(path: String, value: Dictionary = {}) -> bool:
	return path != "user://creature_editor_spine_v4.json" and (value.has("parts") or path in FIXED_PATHS or path.get_base_dir() == BUILDING_DIR)


static func write_status(path: String) -> Dictionary:
	var texts: Array[String] = [read_text(path)]
	if FileAccess.file_exists(path): texts.append(FileAccess.get_file_as_string(path))
	for text in texts:
		if text.is_empty(): continue
		var result: Dictionary = Contract.inspect_text(text)
		if not result.ok: return result
	return {"ok": true, "code": ""}


static func has_unsupported_blueprints(files: Dictionary) -> bool:
	for path in files:
		if not is_blueprint(str(path)) or not files[path] is String: continue
		var parsed: Dictionary = Atomic.parse_dictionary(files[path])
		if parsed is Dictionary and not Contract.version_error(parsed).is_empty(): return true
	return false


static func list_buildings() -> Array[String]:
	var result: Array[String] = []
	var owner := service()
	if owner != null and bool(owner.get("_design_snapshot_active")):
		for path in owner.get("_design_files").keys():
			if str(path).get_base_dir() == BUILDING_DIR:
				result.append(str(path).get_file())
	elif DirAccess.dir_exists_absolute(BUILDING_DIR):
		for filename in DirAccess.get_files_at(BUILDING_DIR):
			if filename.ends_with(".json"):
				result.append(filename)
	result.sort()
	return result


static func capture() -> Dictionary:
	var owner := service()
	if owner != null and bool(owner.get("_design_snapshot_active")):
		return owner.get("_design_files").duplicate(true)
	var files: Dictionary = {}
	var paths: Array[String] = FIXED_PATHS.duplicate()
	for filename in list_buildings():
		paths.append(BUILDING_DIR + "/" + filename)
	for path in paths:
		if FileAccess.file_exists(path):
			files[path] = FileAccess.get_file_as_string(path)
	return files
