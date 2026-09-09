extends RefCounted
class_name ModularAssetResolver

const Catalog = preload("res://assets/catalog/asset_catalog.gd")


static func resolve_scene_path(
	definition: Dictionary,
	lod_tier: int = 0
) -> String:
	var asset_id: String = str(definition.get("asset_id", "")).strip_edges()
	if not asset_id.is_empty():
		var catalog_path: String = Catalog.get_scene_path(asset_id, lod_tier)
		if not catalog_path.is_empty():
			return catalog_path

	var lod_value: Variant = definition.get("lod_scenes", {})
	if lod_value is Dictionary:
		var lod: Dictionary = lod_value
		var direct_entry: Dictionary = {
			"asset_id": str(definition.get("id", "inline")),
			"kind": "inline",
			"lod": {
				"near": str(lod.get("near", definition.get("scene_path", ""))),
				"mid": str(lod.get("mid", "")),
				"far": str(lod.get("far", "")),
			},
		}
		var direct_path: String = Catalog.resolve_lod_path(direct_entry, lod_tier)
		if not direct_path.is_empty():
			return direct_path

	return str(definition.get("scene_path", "")).strip_edges()


static func get_asset_transform(definition: Dictionary) -> Dictionary:
	var transform_value: Variant = definition.get("asset_transform", {})
	var transform: Dictionary = {}
	if transform_value is Dictionary:
		transform = transform_value.duplicate(true)
	return {
		"position": _as_vector3(transform.get("position", Vector3.ZERO), Vector3.ZERO),
		"rotation": _as_vector3(transform.get("rotation", Vector3.ZERO), Vector3.ZERO),
		"scale": _as_vector3(transform.get("scale", Vector3.ONE), Vector3.ONE),
	}


static func validate_definition(definition: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var asset_id: String = str(definition.get("asset_id", "")).strip_edges()
	var scene_path: String = str(definition.get("scene_path", "")).strip_edges()
	var lod_value: Variant = definition.get("lod_scenes", {})
	var lod: Dictionary = {}
	if lod_value is Dictionary:
		lod = lod_value
	var has_lod_scenes: bool = not str(lod.get("near", "")).strip_edges().is_empty()
	if asset_id.is_empty() and scene_path.is_empty() and not has_lod_scenes:
		return result
	if not asset_id.is_empty() and not Catalog.has_asset(asset_id):
		result.append("Unknown authored asset_id '%s'." % asset_id)
	var resolved_path: String = resolve_scene_path(definition, 0)
	if resolved_path.is_empty():
		result.append(
			"Authored part '%s' has no resolvable Near scene."
			% str(definition.get("id", "unknown"))
		)
	elif not ResourceLoader.exists(resolved_path):
		result.append(
			"Authored part '%s' references a missing scene: %s"
			% [str(definition.get("id", "unknown")), resolved_path]
		)
	return result


static func _as_vector3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback
