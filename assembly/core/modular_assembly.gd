extends RefCounted
class_name ModularAssembly

const SCHEMA_VERSION: int = 1
const DEFAULT_GRID_SIZE: float = 0.25


static func create(
	assembly_type: String,
	display_name: String = "New Assembly"
) -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"assembly_type": assembly_type,
		"name": display_name,
		"revision": 0,
		"grid_snap": true,
		"grid_size": DEFAULT_GRID_SIZE,
		"parts": [],
		"metadata": {},
	}


static func normalize(
	blueprint: Dictionary,
	assembly_type: String = "generic"
) -> Dictionary:
	if blueprint.is_empty():
		blueprint = create(assembly_type)
	blueprint["schema"] = SCHEMA_VERSION
	blueprint["assembly_type"] = str(
		blueprint.get("assembly_type", assembly_type)
	)
	blueprint["name"] = str(blueprint.get("name", "New Assembly")).strip_edges()
	if str(blueprint["name"]).is_empty():
		blueprint["name"] = "New Assembly"
	blueprint["revision"] = maxi(int(blueprint.get("revision", 0)), 0)
	blueprint["grid_snap"] = bool(blueprint.get("grid_snap", true))
	blueprint["grid_size"] = clampf(
		float(blueprint.get("grid_size", DEFAULT_GRID_SIZE)),
		0.03125,
		4.0
	)
	if not (blueprint.get("parts", []) is Array):
		blueprint["parts"] = []
	if not (blueprint.get("metadata", {}) is Dictionary):
		blueprint["metadata"] = {}
	var parts: Array = blueprint.get("parts", [])
	for index in range(parts.size()):
		if not (parts[index] is Dictionary):
			parts[index] = _default_part("")
			continue
		parts[index] = normalize_part(parts[index])
	blueprint["parts"] = parts
	return blueprint


static func normalize_part(part: Dictionary) -> Dictionary:
	part["uid"] = str(part.get("uid", _new_uid()))
	if str(part["uid"]).is_empty():
		part["uid"] = _new_uid()
	part["part_id"] = str(part.get("part_id", ""))
	part["position"] = _as_vector3(part.get("position", Vector3.ZERO))
	part["rotation"] = _as_vector3(part.get("rotation", Vector3.ZERO))
	part["scale"] = _sanitize_scale(_as_vector3(part.get("scale", Vector3.ONE)))
	part["mirror_group"] = str(part.get("mirror_group", ""))
	part["socket_id"] = str(part.get("socket_id", ""))
	part["tags"] = part.get("tags", []) if part.get("tags", []) is Array else []
	return part


static func add_part(
	blueprint: Dictionary,
	part_id: String,
	position: Vector3 = Vector3.ZERO,
	rotation: Vector3 = Vector3.ZERO,
	scale: Vector3 = Vector3.ONE,
	socket_id: String = ""
) -> int:
	normalize(blueprint, str(blueprint.get("assembly_type", "generic")))
	var parts: Array = blueprint.get("parts", [])
	var part: Dictionary = _default_part(part_id)
	part["position"] = position
	part["rotation"] = rotation
	part["scale"] = _sanitize_scale(scale)
	part["socket_id"] = socket_id
	parts.append(part)
	blueprint["parts"] = parts
	return parts.size() - 1


static func duplicate_part(blueprint: Dictionary, index: int) -> int:
	var parts: Array = blueprint.get("parts", [])
	if index < 0 or index >= parts.size() or not (parts[index] is Dictionary):
		return -1
	var copy: Dictionary = parts[index].duplicate(true)
	copy["uid"] = _new_uid()
	copy["mirror_group"] = ""
	parts.append(normalize_part(copy))
	blueprint["parts"] = parts
	return parts.size() - 1


static func remove_part(blueprint: Dictionary, index: int) -> bool:
	var parts: Array = blueprint.get("parts", [])
	if index < 0 or index >= parts.size():
		return false
	parts.remove_at(index)
	blueprint["parts"] = parts
	return true


static func get_part(blueprint: Dictionary, index: int) -> Dictionary:
	var parts: Array = blueprint.get("parts", [])
	if index < 0 or index >= parts.size() or not (parts[index] is Dictionary):
		return {}
	return parts[index]


static func set_part(blueprint: Dictionary, index: int, part: Dictionary) -> bool:
	var parts: Array = blueprint.get("parts", [])
	if index < 0 or index >= parts.size():
		return false
	parts[index] = normalize_part(part)
	blueprint["parts"] = parts
	return true


static func transform_part(
	blueprint: Dictionary,
	index: int,
	position_delta: Vector3 = Vector3.ZERO,
	rotation_delta: Vector3 = Vector3.ZERO,
	scale_multiplier: Vector3 = Vector3.ONE
) -> bool:
	var part: Dictionary = get_part(blueprint, index)
	if part.is_empty():
		return false
	part["position"] = _as_vector3(part.get("position", Vector3.ZERO)) + position_delta
	part["rotation"] = _as_vector3(part.get("rotation", Vector3.ZERO)) + rotation_delta
	part["scale"] = _sanitize_scale(
		_as_vector3(part.get("scale", Vector3.ONE)) * scale_multiplier
	)
	if bool(blueprint.get("grid_snap", true)):
		part["position"] = snap_position(
			part["position"],
			float(blueprint.get("grid_size", DEFAULT_GRID_SIZE))
		)
	return set_part(blueprint, index, part)


static func snap_position(position: Vector3, grid_size: float) -> Vector3:
	var safe_grid: float = maxf(grid_size, 0.001)
	return Vector3(
		snappedf(position.x, safe_grid),
		snappedf(position.y, safe_grid),
		snappedf(position.z, safe_grid)
	)


static func set_grid_snap(blueprint: Dictionary, enabled: bool) -> void:
	blueprint["grid_snap"] = enabled


static func set_grid_size(blueprint: Dictionary, grid_size: float) -> void:
	blueprint["grid_size"] = clampf(grid_size, 0.03125, 4.0)


static func increment_revision(blueprint: Dictionary) -> int:
	var revision: int = maxi(int(blueprint.get("revision", 0)), 0) + 1
	blueprint["revision"] = revision
	return revision


static func serialize(blueprint: Dictionary) -> Dictionary:
	var normalized: Dictionary = blueprint.duplicate(true)
	normalize(normalized, str(normalized.get("assembly_type", "generic")))
	var serialized_parts: Array = []
	for part_value in normalized.get("parts", []):
		if not (part_value is Dictionary):
			continue
		var part: Dictionary = part_value
		serialized_parts.append({
			"uid": str(part.get("uid", "")),
			"part_id": str(part.get("part_id", "")),
			"position": _serialize_vector3(_as_vector3(part.get("position", Vector3.ZERO))),
			"rotation": _serialize_vector3(_as_vector3(part.get("rotation", Vector3.ZERO))),
			"scale": _serialize_vector3(_as_vector3(part.get("scale", Vector3.ONE))),
			"mirror_group": str(part.get("mirror_group", "")),
			"socket_id": str(part.get("socket_id", "")),
			"tags": part.get("tags", []).duplicate(),
		})
	normalized["parts"] = serialized_parts
	return normalized


static func deserialize(data: Dictionary) -> Dictionary:
	var blueprint: Dictionary = data.duplicate(true)
	var source_parts: Array = data.get("parts", []) if data.get("parts", []) is Array else []
	var parts: Array = []
	for value in source_parts:
		if not (value is Dictionary):
			continue
		var part: Dictionary = value.duplicate(true)
		part["position"] = _as_vector3(part.get("position", [0.0, 0.0, 0.0]))
		part["rotation"] = _as_vector3(part.get("rotation", [0.0, 0.0, 0.0]))
		part["scale"] = _as_vector3(part.get("scale", [1.0, 1.0, 1.0]))
		parts.append(normalize_part(part))
	blueprint["parts"] = parts
	normalize(blueprint, str(blueprint.get("assembly_type", "generic")))
	return blueprint


static func calculate_stats(
	blueprint: Dictionary,
	part_definitions: Dictionary
) -> Dictionary:
	var totals: Dictionary = {}
	for part_value in blueprint.get("parts", []):
		if not (part_value is Dictionary):
			continue
		var part: Dictionary = part_value
		var definition: Dictionary = part_definitions.get(str(part.get("part_id", "")), {})
		var stats: Dictionary = definition.get("stats", {})
		for stat_name in stats.keys():
			totals[stat_name] = float(totals.get(stat_name, 0.0)) + float(stats[stat_name])
	return totals


static func validate(
	blueprint: Dictionary,
	part_definitions: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	if str(blueprint.get("assembly_type", "")).is_empty():
		errors.append("Assembly type is missing.")
	var seen_uids: Dictionary = {}
	for index in range(blueprint.get("parts", []).size()):
		var part: Dictionary = get_part(blueprint, index)
		if part.is_empty():
			errors.append("Part %d is invalid." % index)
			continue
		var part_id: String = str(part.get("part_id", ""))
		if not part_definitions.has(part_id):
			errors.append("Unknown part '%s'." % part_id)
		var uid: String = str(part.get("uid", ""))
		if seen_uids.has(uid):
			errors.append("Duplicate part UID '%s'." % uid)
		seen_uids[uid] = true
	return errors


static func _default_part(part_id: String) -> Dictionary:
	return {
		"uid": _new_uid(),
		"part_id": part_id,
		"position": Vector3.ZERO,
		"rotation": Vector3.ZERO,
		"scale": Vector3.ONE,
		"mirror_group": "",
		"socket_id": "",
		"tags": [],
	}


static func _new_uid() -> String:
	return "%d-%d" % [Time.get_ticks_usec(), randi()]


static func _sanitize_scale(scale: Vector3) -> Vector3:
	return Vector3(
		clampf(absf(scale.x), 0.05, 20.0),
		clampf(absf(scale.y), 0.05, 20.0),
		clampf(absf(scale.z), 0.05, 20.0)
	)


static func _serialize_vector3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _as_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(
			float(value.get("x", 0.0)),
			float(value.get("y", 0.0)),
			float(value.get("z", 0.0))
		)
	return Vector3.ZERO
