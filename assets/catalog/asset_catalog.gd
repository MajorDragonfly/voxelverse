extends RefCounted
class_name AssetCatalog

const PACK_ROOT: String = "res://assets/packs"
const MANIFEST_NAME: String = "manifest.json"
const CATALOG_SCHEMA: int = 1

static var _loaded: bool = false
static var _assets: Dictionary = {}
static var _packs: Dictionary = {}
static var _errors: Array[String] = []


static func reset_cache() -> void:
	_loaded = false
	_assets.clear()
	_packs.clear()
	_errors.clear()


static func get_asset(asset_id: String) -> Dictionary:
	_ensure_loaded()
	var value: Variant = _assets.get(asset_id, {})
	if value is Dictionary:
		return value.duplicate(true)
	return {}


static func has_asset(asset_id: String) -> bool:
	_ensure_loaded()
	return _assets.has(asset_id)


static func get_pack(pack_id: String) -> Dictionary:
	_ensure_loaded()
	var value: Variant = _packs.get(pack_id, {})
	if value is Dictionary:
		return value.duplicate(true)
	return {}


static func get_pack_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for key in _packs.keys():
		result.append(str(key))
	result.sort()
	return result


static func get_asset_ids_by_kind(kind: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for key in _assets.keys():
		var entry_value: Variant = _assets[key]
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("kind", "")) == kind:
			result.append(str(key))
	result.sort()
	return result


static func get_scene_path(asset_id: String, lod_tier: int = 0) -> String:
	return resolve_lod_path(get_asset(asset_id), lod_tier)


static func resolve_lod_path(entry: Dictionary, lod_tier: int = 0) -> String:
	if entry.is_empty():
		return ""
	var lod_value: Variant = entry.get("lod", {})
	var lod: Dictionary = lod_value if lod_value is Dictionary else {}
	var near_path: String = str(lod.get("near", entry.get("scene_path", "")))
	var mid_path: String = str(lod.get("mid", ""))
	var far_path: String = str(lod.get("far", ""))
	match clampi(lod_tier, 0, 2):
		0:
			return near_path
		1:
			return mid_path if not mid_path.is_empty() else near_path
		2:
			if not far_path.is_empty():
				return far_path
			if not mid_path.is_empty():
				return mid_path
			return near_path
	return near_path


static func validate_asset_entry(
	entry: Dictionary,
	check_resources: bool = false
) -> Array[String]:
	var result: Array[String] = []
	var asset_id: String = str(entry.get("asset_id", "")).strip_edges()
	if asset_id.is_empty():
		result.append("Asset entry has no asset_id.")
	var kind: String = str(entry.get("kind", "")).strip_edges()
	if kind.is_empty():
		result.append("Asset '%s' has no kind." % asset_id)
	var lod_value: Variant = entry.get("lod", {})
	if not (lod_value is Dictionary):
		result.append("Asset '%s' has invalid lod metadata." % asset_id)
		return result
	var lod: Dictionary = lod_value
	var near_path: String = str(lod.get("near", "")).strip_edges()
	if near_path.is_empty():
		result.append("Asset '%s' has no Near runtime scene." % asset_id)
	elif check_resources and not ResourceLoader.exists(near_path):
		result.append("Asset '%s' Near scene is missing: %s" % [asset_id, near_path])
	for tier_name in ["mid", "far"]:
		var path: String = str(lod.get(tier_name, "")).strip_edges()
		if check_resources and not path.is_empty() and not ResourceLoader.exists(path):
			result.append(
				"Asset '%s' %s scene is missing: %s"
				% [asset_id, tier_name.capitalize(), path]
			)
	return result


static func get_errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_assets.clear()
	_packs.clear()
	_errors.clear()
	_scan_directory(PACK_ROOT)


static func _scan_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var entry_name: String = directory.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue
		var full_path: String = path.path_join(entry_name)
		if directory.current_is_dir():
			_scan_directory(full_path)
		elif entry_name == MANIFEST_NAME:
			_load_manifest(full_path)
	directory.list_dir_end()


static func _load_manifest(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Could not open asset manifest: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		_errors.append("Asset manifest is not a JSON object: %s" % path)
		return
	var manifest: Dictionary = parsed
	if not bool(manifest.get("enabled", true)):
		return
	var schema: int = int(manifest.get("schema", 0))
	if schema != CATALOG_SCHEMA:
		_errors.append(
			"Unsupported asset manifest schema %d in %s" % [schema, path]
		)
		return
	var pack_id: String = str(manifest.get("pack_id", "")).strip_edges()
	if pack_id.is_empty():
		_errors.append("Asset manifest has no pack_id: %s" % path)
		return
	if _packs.has(pack_id):
		_errors.append("Duplicate asset pack id '%s'." % pack_id)
		return
	var pack_copy: Dictionary = manifest.duplicate(true)
	pack_copy["manifest_path"] = path
	_packs[pack_id] = pack_copy
	var assets_value: Variant = manifest.get("assets", [])
	if not (assets_value is Array):
		_errors.append("Asset pack '%s' has no valid assets array." % pack_id)
		return
	for asset_value in assets_value:
		if not (asset_value is Dictionary):
			_errors.append("Asset pack '%s' contains a non-object asset entry." % pack_id)
			continue
		var asset: Dictionary = asset_value.duplicate(true)
		var asset_id: String = str(asset.get("asset_id", "")).strip_edges()
		var validation: Array[String] = validate_asset_entry(asset, false)
		if not validation.is_empty():
			for message in validation:
				_errors.append("%s (%s)" % [message, path])
			continue
		if _assets.has(asset_id):
			_errors.append("Duplicate asset id '%s'." % asset_id)
			continue
		asset["pack_id"] = pack_id
		asset["manifest_path"] = path
		_assets[asset_id] = asset
