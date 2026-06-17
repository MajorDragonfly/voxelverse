extends RefCounted
class_name CreatureBlueprint


const PartLibrary = preload("res://creatures/editor/creature_part_library.gd")

const SAVE_VERSION: int = 1
const COMPLEXITY_LIMIT: int = 100


static func create_default() -> Dictionary:
	var body_part: Dictionary = PartLibrary.get_part(
		PartLibrary.get_default_body_part_id()
	)

	var blueprint: Dictionary = {
		"version": SAVE_VERSION,
		"name": "New Creature",
		"body": {
			"part_id": body_part.get("id", ""),
			"shape": body_part.get("shape", Vector3(1.3, 1.0, 2.1)),
			"scale": 1.0,
		},
		"paint": {
			"part_id": PartLibrary.get_default_paint_id(),
			"intensity": 1.0,
		},
		"parts": [],
		"next_part_uid": 1,
	}

	add_part(blueprint, "eyes_beady")
	add_part(blueprint, "mouth_grazer")
	add_part(blueprint, "legs_walker")
	add_part(blueprint, "tail_balance")

	return blueprint


static func duplicate_blueprint(blueprint: Dictionary) -> Dictionary:
	return blueprint.duplicate(true)


static func set_name(
	blueprint: Dictionary,
	new_name: String
) -> void:
	blueprint["name"] = new_name.strip_edges()


static func set_body_part(
	blueprint: Dictionary,
	body_part_id: String
) -> void:
	var body_part: Dictionary = PartLibrary.get_part(body_part_id)

	if body_part.is_empty():
		push_warning("Unknown body part: %s" % body_part_id)
		return

	var body: Dictionary = blueprint.get("body", {})
	body["part_id"] = body_part_id
	body["shape"] = body_part.get("shape", Vector3(1.3, 1.0, 2.1))

	if not body.has("scale"):
		body["scale"] = 1.0

	blueprint["body"] = body


static func set_paint_part(
	blueprint: Dictionary,
	paint_part_id: String
) -> void:
	var paint_part: Dictionary = PartLibrary.get_part(paint_part_id)

	if paint_part.is_empty():
		push_warning("Unknown paint part: %s" % paint_part_id)
		return

	var paint: Dictionary = blueprint.get("paint", {})
	paint["part_id"] = paint_part_id

	if not paint.has("intensity"):
		paint["intensity"] = 1.0

	blueprint["paint"] = paint


static func set_body_shape(
	blueprint: Dictionary,
	new_shape: Vector3
) -> void:
	var safe_shape := Vector3(
		clampf(new_shape.x, 0.55, 3.00),
		clampf(new_shape.y, 0.45, 2.40),
		clampf(new_shape.z, 0.85, 4.50)
	)

	var body: Dictionary = blueprint.get("body", {})
	body["shape"] = safe_shape
	blueprint["body"] = body


static func set_body_scale(
	blueprint: Dictionary,
	new_scale: float
) -> void:
	var body: Dictionary = blueprint.get("body", {})
	body["scale"] = clampf(new_scale, 0.45, 2.25)
	blueprint["body"] = body


static func get_body_shape(blueprint: Dictionary) -> Vector3:
	var body: Dictionary = blueprint.get("body", {})
	var shape: Variant = body.get("shape", Vector3(1.3, 1.0, 2.1))

	if shape is Vector3:
		return shape

	return Vector3(1.3, 1.0, 2.1)


static func get_body_scale(blueprint: Dictionary) -> float:
	var body: Dictionary = blueprint.get("body", {})
	return float(body.get("scale", 1.0))


static func get_body_part_id(blueprint: Dictionary) -> String:
	var body: Dictionary = blueprint.get("body", {})
	return str(body.get("part_id", PartLibrary.get_default_body_part_id()))


static func get_paint_part_id(blueprint: Dictionary) -> String:
	var paint: Dictionary = blueprint.get("paint", {})
	return str(paint.get("part_id", PartLibrary.get_default_paint_id()))


static func get_paint_intensity(blueprint: Dictionary) -> float:
	var paint: Dictionary = blueprint.get("paint", {})
	return clampf(float(paint.get("intensity", 1.0)), 0.0, 1.0)


static func set_paint_intensity(
	blueprint: Dictionary,
	new_intensity: float
) -> void:
	var paint: Dictionary = blueprint.get("paint", {})
	paint["intensity"] = clampf(new_intensity, 0.0, 1.0)
	blueprint["paint"] = paint


static func add_part(
	blueprint: Dictionary,
	part_id: String
) -> int:
	var part_definition: Dictionary = PartLibrary.get_part(part_id)

	if part_definition.is_empty():
		push_warning("Unknown creature part: %s" % part_id)
		return -1

	var category_id: String = str(part_definition.get("category", ""))

	if category_id == "":
		push_warning("Creature part has no category: %s" % part_id)
		return -1

	var next_uid: int = int(blueprint.get("next_part_uid", 1))
	var body_shape: Vector3 = get_body_shape(blueprint) * get_body_scale(blueprint)
	var placement: Dictionary = {
		"uid": "part_%04d" % next_uid,
		"part_id": part_id,
		"category": category_id,
		"position": PartLibrary.get_default_position(
			category_id,
			body_shape
		),
		"rotation": Vector3.ZERO,
		"scale": float(part_definition.get("default_scale", 1.0)),
		"mirrored": PartLibrary.is_default_mirrored(category_id),
	}

	blueprint["next_part_uid"] = next_uid + 1

	var parts: Array = blueprint.get("parts", [])
	parts.append(placement)
	blueprint["parts"] = parts

	return parts.size() - 1


static func duplicate_part(
	blueprint: Dictionary,
	part_index: int
) -> int:
	var parts: Array = blueprint.get("parts", [])

	if part_index < 0 or part_index >= parts.size():
		return -1

	var original: Dictionary = parts[part_index].duplicate(true)
	var next_uid: int = int(blueprint.get("next_part_uid", 1))
	var copy: Dictionary = original.duplicate(true)
	copy["uid"] = "part_%04d" % next_uid
	copy["position"] = _as_vector3(copy.get("position", Vector3.ZERO)) + Vector3(0.15, 0.0, 0.15)

	blueprint["next_part_uid"] = next_uid + 1
	parts.append(copy)
	blueprint["parts"] = parts

	return parts.size() - 1


static func remove_part(
	blueprint: Dictionary,
	part_index: int
) -> void:
	var parts: Array = blueprint.get("parts", [])

	if part_index < 0 or part_index >= parts.size():
		return

	parts.remove_at(part_index)
	blueprint["parts"] = parts


static func clear_parts(blueprint: Dictionary) -> void:
	blueprint["parts"] = []


static func get_part_count(blueprint: Dictionary) -> int:
	var parts: Array = blueprint.get("parts", [])
	return parts.size()


static func get_part_placement(
	blueprint: Dictionary,
	part_index: int
) -> Dictionary:
	var parts: Array = blueprint.get("parts", [])

	if part_index < 0 or part_index >= parts.size():
		return {}

	return parts[part_index]


static func set_part_placement(
	blueprint: Dictionary,
	part_index: int,
	placement: Dictionary
) -> void:
	var parts: Array = blueprint.get("parts", [])

	if part_index < 0 or part_index >= parts.size():
		return

	parts[part_index] = placement
	blueprint["parts"] = parts


static func nudge_part(
	blueprint: Dictionary,
	part_index: int,
	offset: Vector3
) -> void:
	var placement: Dictionary = get_part_placement(
		blueprint,
		part_index
	)

	if placement.is_empty():
		return

	placement["position"] = _as_vector3(
		placement.get("position", Vector3.ZERO)
	) + offset

	set_part_placement(blueprint, part_index, placement)


static func rotate_part(
	blueprint: Dictionary,
	part_index: int,
	rotation_offset: Vector3
) -> void:
	var placement: Dictionary = get_part_placement(
		blueprint,
		part_index
	)

	if placement.is_empty():
		return

	var rotation: Vector3 = _as_vector3(
		placement.get("rotation", Vector3.ZERO)
	)
	rotation += rotation_offset
	placement["rotation"] = rotation

	set_part_placement(blueprint, part_index, placement)


static func scale_part(
	blueprint: Dictionary,
	part_index: int,
	scale_delta: float
) -> void:
	var placement: Dictionary = get_part_placement(
		blueprint,
		part_index
	)

	if placement.is_empty():
		return

	placement["scale"] = clampf(
		float(placement.get("scale", 1.0)) + scale_delta,
		0.25,
		3.0
	)

	set_part_placement(blueprint, part_index, placement)


static func set_part_mirrored(
	blueprint: Dictionary,
	part_index: int,
	mirrored: bool
) -> void:
	var placement: Dictionary = get_part_placement(
		blueprint,
		part_index
	)

	if placement.is_empty():
		return

	placement["mirrored"] = mirrored

	set_part_placement(blueprint, part_index, placement)


static func reset_part_transform(
	blueprint: Dictionary,
	part_index: int
) -> void:
	var placement: Dictionary = get_part_placement(
		blueprint,
		part_index
	)

	if placement.is_empty():
		return

	var part_definition: Dictionary = PartLibrary.get_part(
		str(placement.get("part_id", ""))
	)
	var category_id: String = str(placement.get("category", ""))
	var body_shape: Vector3 = get_body_shape(blueprint) * get_body_scale(blueprint)

	placement["position"] = PartLibrary.get_default_position(
		category_id,
		body_shape
	)
	placement["rotation"] = Vector3.ZERO
	placement["scale"] = float(part_definition.get("default_scale", 1.0))
	placement["mirrored"] = PartLibrary.is_default_mirrored(category_id)

	set_part_placement(blueprint, part_index, placement)


static func calculate_complexity(blueprint: Dictionary) -> int:
	var complexity: int = 0

	var body_definition: Dictionary = PartLibrary.get_part(
		get_body_part_id(blueprint)
	)
	complexity += int(body_definition.get("complexity", 0))

	var paint_definition: Dictionary = PartLibrary.get_part(
		get_paint_part_id(blueprint)
	)
	complexity += int(paint_definition.get("complexity", 0))

	var parts: Array = blueprint.get("parts", [])

	for placement in parts:
		if not (placement is Dictionary):
			continue

		var part_definition: Dictionary = PartLibrary.get_part(
			str(placement.get("part_id", ""))
		)
		complexity += int(part_definition.get("complexity", 0))

	return complexity


static func calculate_stats(blueprint: Dictionary) -> Dictionary:
	var stats: Dictionary = {
		"health": 0.0,
		"speed": 0.0,
		"jump": 0.0,
		"attack": 0.0,
		"defense": 0.0,
		"perception": 0.0,
		"grip": 0.0,
		"diet_plant": 0.0,
		"diet_meat": 0.0,
		"swim": 0.0,
		"flight": 0.0,
		"hunger_drain": 0.0,
	}

	_add_stats_from_definition(
		stats,
		PartLibrary.get_part(get_body_part_id(blueprint))
	)

	var body_shape: Vector3 = get_body_shape(blueprint)
	var body_scale: float = get_body_scale(blueprint)
	var body_mass_factor: float = body_shape.x * body_shape.y * body_shape.z * body_scale

	stats["health"] = float(stats.get("health", 0.0)) * clampf(
		body_mass_factor / 2.8,
		0.55,
		2.2
	)
	stats["speed"] = float(stats.get("speed", 0.0)) - maxf(body_mass_factor - 2.8, 0.0) * 0.22
	stats["hunger_drain"] = float(stats.get("hunger_drain", 0.0)) + maxf(body_mass_factor - 2.8, 0.0) * 0.018

	var parts: Array = blueprint.get("parts", [])

	for placement in parts:
		if not (placement is Dictionary):
			continue

		var part_definition: Dictionary = PartLibrary.get_part(
			str(placement.get("part_id", ""))
		)
		_add_stats_from_definition(stats, part_definition)

	stats["complexity"] = calculate_complexity(blueprint)
	stats["complexity_limit"] = COMPLEXITY_LIMIT

	return stats


static func save_to_file(
	blueprint: Dictionary,
	save_path: String
) -> Error:
	var file := FileAccess.open(save_path, FileAccess.WRITE)

	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(_serialize_blueprint(blueprint), "\t"))
	file.close()

	return OK


static func load_from_file(save_path: String) -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}

	var file := FileAccess.open(save_path, FileAccess.READ)

	if file == null:
		push_warning("Could not open creature save: %s" % save_path)
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)

	if not (parsed is Dictionary):
		push_warning("Creature save is not a valid dictionary.")
		return {}

	return _deserialize_blueprint(parsed)


static func _add_stats_from_definition(
	stats: Dictionary,
	part_definition: Dictionary
) -> void:
	var part_stats: Dictionary = part_definition.get("stats", {})

	for key in part_stats.keys():
		stats[key] = float(stats.get(key, 0.0)) + float(part_stats[key])


static func _serialize_blueprint(blueprint: Dictionary) -> Dictionary:
	var body: Dictionary = blueprint.get("body", {})
	var paint: Dictionary = blueprint.get("paint", {})
	var serialized_parts: Array = []

	for placement in blueprint.get("parts", []):
		if not (placement is Dictionary):
			continue

		serialized_parts.append({
			"uid": str(placement.get("uid", "")),
			"part_id": str(placement.get("part_id", "")),
			"category": str(placement.get("category", "")),
			"position": _serialize_vector3(
				_as_vector3(placement.get("position", Vector3.ZERO))
			),
			"rotation": _serialize_vector3(
				_as_vector3(placement.get("rotation", Vector3.ZERO))
			),
			"scale": float(placement.get("scale", 1.0)),
			"mirrored": bool(placement.get("mirrored", false)),
		})

	return {
		"version": SAVE_VERSION,
		"name": str(blueprint.get("name", "New Creature")),
		"body": {
			"part_id": str(body.get("part_id", PartLibrary.get_default_body_part_id())),
			"shape": _serialize_vector3(
				_as_vector3(body.get("shape", Vector3(1.3, 1.0, 2.1)))
			),
			"scale": float(body.get("scale", 1.0)),
		},
		"paint": {
			"part_id": str(paint.get("part_id", PartLibrary.get_default_paint_id())),
			"intensity": float(paint.get("intensity", 1.0)),
		},
		"parts": serialized_parts,
		"next_part_uid": int(blueprint.get("next_part_uid", serialized_parts.size() + 1)),
	}


static func _deserialize_blueprint(data: Dictionary) -> Dictionary:
	var blueprint: Dictionary = create_default()
	blueprint["name"] = str(data.get("name", "New Creature"))
	blueprint["parts"] = []

	var body_data: Dictionary = data.get("body", {})
	var body: Dictionary = {
		"part_id": str(body_data.get("part_id", PartLibrary.get_default_body_part_id())),
		"shape": _deserialize_vector3(
			body_data.get("shape", [1.3, 1.0, 2.1]),
			Vector3(1.3, 1.0, 2.1)
		),
		"scale": clampf(float(body_data.get("scale", 1.0)), 0.45, 2.25),
	}
	blueprint["body"] = body

	var paint_data: Dictionary = data.get("paint", {})
	blueprint["paint"] = {
		"part_id": str(paint_data.get("part_id", PartLibrary.get_default_paint_id())),
		"intensity": clampf(float(paint_data.get("intensity", 1.0)), 0.0, 1.0),
	}

	var loaded_parts: Array = data.get("parts", [])
	var parts: Array = []

	for item in loaded_parts:
		if not (item is Dictionary):
			continue

		var placement: Dictionary = {
			"uid": str(item.get("uid", "part_0000")),
			"part_id": str(item.get("part_id", "")),
			"category": str(item.get("category", "")),
			"position": _deserialize_vector3(
				item.get("position", [0.0, 0.0, 0.0]),
				Vector3.ZERO
			),
			"rotation": _deserialize_vector3(
				item.get("rotation", [0.0, 0.0, 0.0]),
				Vector3.ZERO
			),
			"scale": clampf(float(item.get("scale", 1.0)), 0.25, 3.0),
			"mirrored": bool(item.get("mirrored", false)),
		}

		if placement["part_id"] == "":
			continue

		if placement["category"] == "":
			var part_definition: Dictionary = PartLibrary.get_part(
				str(placement["part_id"])
			)
			placement["category"] = str(part_definition.get("category", ""))

		parts.append(placement)

	blueprint["parts"] = parts
	blueprint["next_part_uid"] = int(data.get("next_part_uid", parts.size() + 1))

	return blueprint


static func _serialize_vector3(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]


static func _deserialize_vector3(
	value: Variant,
	fallback: Vector3
) -> Vector3:
	if not (value is Array):
		return fallback

	if value.size() < 3:
		return fallback

	return Vector3(
		float(value[0]),
		float(value[1]),
		float(value[2])
	)


static func _as_vector3(
	value: Variant,
	fallback: Vector3 = Vector3.ZERO
) -> Vector3:
	if value is Vector3:
		return value

	if value is Array and value.size() >= 3:
		return Vector3(
			float(value[0]),
			float(value[1]),
			float(value[2])
		)

	return fallback
