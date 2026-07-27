extends RefCounted
class_name CreatureBlueprintV5

const BaseBlueprint = preload(
	"res://creatures/editor/creature_blueprint.gd"
)
const SpineProfile = preload(
	"res://creatures/editor/creature_spine_profile.gd"
)

const SAVE_VERSION: int = 5
const SAVE_PATH: String = "user://creature_editor_blueprint_v5.json"
const LEGACY_SAVE_PATH: String = "user://creature_editor_blueprint.json"


static func normalize(blueprint: Dictionary) -> Dictionary:
	if blueprint.is_empty():
		blueprint = BaseBlueprint.create_default()

	SpineProfile.ensure_profile(blueprint)

	var generation: Dictionary = blueprint.get("generation", {})
	generation["seed"] = int(generation.get("seed", 0))
	generation["generation"] = maxi(
		int(generation.get("generation", 0)),
		0
	)
	generation["parent_seed"] = int(
		generation.get("parent_seed", 0)
	)
	generation["archetype"] = str(
		generation.get("archetype", "custom")
	)
	generation["mutation_strength"] = clampf(
		float(generation.get("mutation_strength", 0.0)),
		0.0,
		1.0
	)
	blueprint["generation"] = generation

	return blueprint


static func save_to_file(
	blueprint: Dictionary,
	save_path: String = SAVE_PATH
) -> Error:
	normalize(blueprint)

	var serialized: Dictionary = BaseBlueprint._serialize_blueprint(
		blueprint
	)
	serialized["version"] = SAVE_VERSION
	serialized["generation"] = blueprint.get(
		"generation",
		{}
	).duplicate(true)

	var body: Dictionary = serialized.get("body", {})
	body["spine"] = _serialize_spine(
		SpineProfile.get_segments(blueprint)
	)
	body["spine_length_scale"] = (
		SpineProfile.get_body_length_scale(blueprint)
	)
	serialized["body"] = body

	var serialized_parts: Array = serialized.get("parts", [])
	var source_parts: Array = blueprint.get("parts", [])

	for index in range(mini(serialized_parts.size(), source_parts.size())):
		if not (
			serialized_parts[index] is Dictionary
			and source_parts[index] is Dictionary
		):
			continue

		var serialized_part: Dictionary = serialized_parts[index]
		var source_part: Dictionary = source_parts[index]

		serialized_part["anchor_t"] = clampf(
			float(source_part.get("anchor_t", 0.5)),
			0.0,
			1.0
		)
		serialized_part["anchor_side"] = clampf(
			float(source_part.get("anchor_side", 0.0)),
			-1.0,
			1.0
		)
		serialized_part["anchor_vertical"] = clampf(
			float(source_part.get("anchor_vertical", 0.0)),
			-1.0,
			1.0
		)
		serialized_part["anchor_surface_offset"] = _serialize_vector3(
			BaseBlueprint._as_vector3(
				source_part.get(
					"anchor_surface_offset",
					Vector3.ZERO
				)
			)
		)
		serialized_part["manual_offset"] = _serialize_vector3(
			BaseBlueprint._as_vector3(
				source_part.get(
					"manual_offset",
					Vector3.ZERO
				)
			)
		)
		serialized_part["anchor_locked"] = bool(
			source_part.get("anchor_locked", true)
		)
		serialized_parts[index] = serialized_part

	serialized["parts"] = serialized_parts

	var file := FileAccess.open(save_path, FileAccess.WRITE)

	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(serialized, "\t"))
	file.close()
	return OK


static func load_from_file(
	save_path: String = SAVE_PATH
) -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}

	var file := FileAccess.open(save_path, FileAccess.READ)

	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not (parsed is Dictionary):
		push_warning("Creature V5 save is not a dictionary: %s" % save_path)
		return {}

	var blueprint: Dictionary = BaseBlueprint._deserialize_blueprint(parsed)
	var body_data: Dictionary = parsed.get("body", {})
	var body: Dictionary = blueprint.get("body", {})

	body["spine"] = _deserialize_spine(
		body_data.get("spine", [])
	)
	body["spine_length_scale"] = clampf(
		float(body_data.get("spine_length_scale", 1.0)),
		SpineProfile.MIN_BODY_LENGTH_SCALE,
		SpineProfile.MAX_BODY_LENGTH_SCALE
	)
	blueprint["body"] = body
	blueprint["generation"] = parsed.get(
		"generation",
		{}
	).duplicate(true)

	var loaded_parts: Array = blueprint.get("parts", [])
	var serialized_parts: Array = parsed.get("parts", [])

	for index in range(mini(loaded_parts.size(), serialized_parts.size())):
		if not (
			loaded_parts[index] is Dictionary
			and serialized_parts[index] is Dictionary
		):
			continue

		var placement: Dictionary = loaded_parts[index]
		var serialized_part: Dictionary = serialized_parts[index]
		placement["anchor_t"] = clampf(
			float(serialized_part.get("anchor_t", 0.5)),
			0.0,
			1.0
		)
		placement["anchor_side"] = clampf(
			float(serialized_part.get("anchor_side", 0.0)),
			-1.0,
			1.0
		)
		placement["anchor_vertical"] = clampf(
			float(serialized_part.get("anchor_vertical", 0.0)),
			-1.0,
			1.0
		)
		placement["anchor_surface_offset"] = _deserialize_vector3(
			serialized_part.get("anchor_surface_offset", [0.0, 0.0, 0.0])
		)
		placement["manual_offset"] = _deserialize_vector3(
			serialized_part.get("manual_offset", [0.0, 0.0, 0.0])
		)
		placement["anchor_locked"] = bool(
			serialized_part.get("anchor_locked", true)
		)
		loaded_parts[index] = placement

	blueprint["parts"] = loaded_parts
	normalize(blueprint)
	return blueprint


static func load_best_available() -> Dictionary:
	var blueprint: Dictionary = load_from_file(SAVE_PATH)

	if not blueprint.is_empty():
		return blueprint

	blueprint = BaseBlueprint.load_from_file(LEGACY_SAVE_PATH)

	if blueprint.is_empty():
		return {}

	SpineProfile.load_profile(blueprint)
	normalize(blueprint)
	return blueprint


static func _serialize_spine(segments: Array) -> Array:
	var serialized: Array = []

	for segment_value in segments:
		var segment: Dictionary = {}

		if segment_value is Dictionary:
			segment = segment_value

		serialized.append({
			"width_scale": float(segment.get("width_scale", 1.0)),
			"height_scale": float(segment.get("height_scale", 1.0)),
			"y_offset": float(segment.get("y_offset", 0.0)),
		})

	return serialized


static func _deserialize_spine(value: Variant) -> Array:
	if not (value is Array):
		return SpineProfile.create_default()

	var segments: Array = []

	for index in range(SpineProfile.SEGMENT_COUNT):
		var source: Dictionary = {}

		if index < value.size() and value[index] is Dictionary:
			source = value[index]

		segments.append({
			"width_scale": clampf(
				float(source.get("width_scale", 1.0)),
				SpineProfile.MIN_WIDTH_SCALE,
				SpineProfile.MAX_WIDTH_SCALE
			),
			"height_scale": clampf(
				float(source.get("height_scale", 1.0)),
				SpineProfile.MIN_HEIGHT_SCALE,
				SpineProfile.MAX_HEIGHT_SCALE
			),
			"y_offset": clampf(
				float(source.get("y_offset", 0.0)),
				SpineProfile.MIN_Y_OFFSET,
				SpineProfile.MAX_Y_OFFSET
			),
		})

	return segments


static func _serialize_vector3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _deserialize_vector3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(
			float(value[0]),
			float(value[1]),
			float(value[2])
		)

	return Vector3.ZERO
