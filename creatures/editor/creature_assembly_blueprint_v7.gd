extends RefCounted
class_name CreatureAssemblyBlueprintV7

const BaseBlueprint = preload(
	"res://creatures/editor/creature_blueprint.gd"
)
const BlueprintV5 = preload(
	"res://creatures/editor/creature_blueprint_v5.gd"
)
const SpineProfile = preload(
	"res://creatures/editor/creature_spine_profile.gd"
)

const Compatibility = preload("res://core/persistence/design_compatibility.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const Store = preload("res://core/persistence/design_store.gd")
const SkinStyle = preload("res://creatures/editor/creature_skin_style.gd")

const SAVE_VERSION: int = 7
const SAVE_PATH: String = "user://creature_assembly_v7.json"
const LEGACY_V5_PATH: String = "user://creature_editor_blueprint_v5.json"
const LEGACY_BASE_PATH: String = "user://creature_editor_blueprint.json"

const REMOVED_GENETIC_FIELDS: Array[String] = [
	"generation",
	"genes",
	"genome",
	"genetics",
	"mutation",
	"mutations",
	"lineage",
	"parent_seed",
	"seed",
]


static func create_default() -> Dictionary:
	var blueprint: Dictionary = BaseBlueprint.create_default()
	normalize(blueprint)
	return blueprint


static func normalize(blueprint: Dictionary) -> Dictionary:
	if blueprint.is_empty():
		blueprint = BaseBlueprint.create_default()
	for field_name in REMOVED_GENETIC_FIELDS:
		blueprint.erase(field_name)
	Ids.ensure_design(blueprint)
	SpineProfile.ensure_profile(blueprint)
	Compatibility.resolve_creature(blueprint)
	SkinStyle.normalize(blueprint)
	for part: Dictionary in blueprint.get("parts", []):
		part["shape_scale"] = BaseBlueprint.get_part_shape(part)
		part["end_shape_scale"] = BaseBlueprint.get_part_shape(part, "end_shape_scale")
		part["end_scale"] = clampf(float(part.get("end_scale", 1.0)), 0.4, 2.0)
		var end_id: String = str(part.get("end_part_id", ""))
		var end: Dictionary = BaseBlueprint.PartLibrary.get_part(end_id)
		var expected: String = "feet" if str(part.get("category", "")) == "legs" else ("hands" if str(part.get("category", "")) == "arms" else "")
		if not end_id.is_empty() and (expected.is_empty() or end.is_empty() or str(end.get("category", "")) != expected):
			part["end_part_id"] = ""
		if bool(part.get("center_locked", false)):
			part["mirrored"] = false

	var assembly: Dictionary = blueprint.get("assembly", {})
	assembly["schema"] = SAVE_VERSION
	assembly["revision"] = maxi(int(assembly.get("revision", 0)), 0)
	assembly["symmetry_enabled"] = bool(
		assembly.get("symmetry_enabled", true)
	)
	assembly["snap_to_surface"] = bool(
		assembly.get("snap_to_surface", true)
	)
	assembly["edit_mode"] = str(assembly.get("edit_mode", "body"))
	assembly["last_selected_category"] = str(
		assembly.get("last_selected_category", "body")
	)
	blueprint["assembly"] = assembly

	var progression: Dictionary = blueprint.get("progression", {})
	progression.erase("phase") # Campaign phase belongs exclusively to GameState.
	progression["unlocked_parts"] = progression.get(
		"unlocked_parts",
		[]
	)
	progression["discoveries"] = progression.get("discoveries", [])
	blueprint["progression"] = progression
	blueprint["version"] = SAVE_VERSION
	return blueprint


static func increment_revision(blueprint: Dictionary) -> int:
	normalize(blueprint)
	var assembly: Dictionary = blueprint.get("assembly", {})
	var revision: int = int(assembly.get("revision", 0)) + 1
	assembly["revision"] = revision
	blueprint["assembly"] = assembly
	return revision


static func get_revision(blueprint: Dictionary) -> int:
	var assembly: Dictionary = blueprint.get("assembly", {})
	return maxi(int(assembly.get("revision", 0)), 0)


static func set_symmetry_enabled(
	blueprint: Dictionary,
	enabled: bool
) -> void:
	normalize(blueprint)
	var assembly: Dictionary = blueprint.get("assembly", {})
	assembly["symmetry_enabled"] = enabled
	blueprint["assembly"] = assembly


static func is_symmetry_enabled(blueprint: Dictionary) -> bool:
	var assembly: Dictionary = blueprint.get("assembly", {})
	return bool(assembly.get("symmetry_enabled", true))


static func set_snap_to_surface(
	blueprint: Dictionary,
	enabled: bool
) -> void:
	normalize(blueprint)
	var assembly: Dictionary = blueprint.get("assembly", {})
	assembly["snap_to_surface"] = enabled
	blueprint["assembly"] = assembly


static func is_snap_to_surface(blueprint: Dictionary) -> bool:
	var assembly: Dictionary = blueprint.get("assembly", {})
	return bool(assembly.get("snap_to_surface", true))


static func save_to_file(
	blueprint: Dictionary,
	save_path: String = SAVE_PATH
) -> Error:
	normalize(blueprint)
	var serialized: Dictionary = BaseBlueprint._serialize_blueprint(blueprint)
	serialized["version"] = SAVE_VERSION
	serialized["design_id"] = blueprint["design_id"]
	serialized["assembly"] = blueprint.get("assembly", {}).duplicate(true)
	serialized["progression"] = blueprint.get(
		"progression",
		{}
	).duplicate(true)

	var body: Dictionary = serialized.get("body", {})
	body["spine"] = _serialize_spine(SpineProfile.get_segments(blueprint))
	body["spine_length_scale"] = SpineProfile.get_body_length_scale(
		blueprint
	)
	serialized["body"] = body
	serialized["appearance"] = blueprint.get("appearance", {}).duplicate(true)

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
				source_part.get("anchor_surface_offset", Vector3.ZERO)
			)
		)
		serialized_part["manual_offset"] = _serialize_vector3(
			BaseBlueprint._as_vector3(
				source_part.get("manual_offset", Vector3.ZERO)
			)
		)
		serialized_part["anchor_locked"] = bool(
			source_part.get("anchor_locked", true)
		)
		serialized_part["socket_type"] = str(
			source_part.get("socket_type", "surface")
		)
		serialized_part["paired_uid"] = str(
			source_part.get("paired_uid", "")
		)
		serialized_parts[index] = serialized_part
	serialized["parts"] = serialized_parts

	for field_name in REMOVED_GENETIC_FIELDS:
		serialized.erase(field_name)
	return Store.write(save_path, serialized)


static func load_from_file(
	save_path: String = SAVE_PATH
) -> Dictionary:
	var text: String = Store.read_text(save_path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("Creature assembly save is not a dictionary: %s" % save_path)
		return {}

	var blueprint: Dictionary = BaseBlueprint._deserialize_blueprint(parsed)
	blueprint["design_id"] = str(parsed.get("design_id", ""))
	Ids.ensure_design(blueprint, save_path)
	var body_data: Dictionary = parsed.get("body", {})
	var body: Dictionary = blueprint.get("body", {})
	body["spine"] = _deserialize_spine(body_data.get("spine", []))
	body["spine_length_scale"] = clampf(
		float(body_data.get("spine_length_scale", 1.0)),
		SpineProfile.MIN_BODY_LENGTH_SCALE,
		SpineProfile.MAX_BODY_LENGTH_SCALE
	)
	blueprint["body"] = body
	blueprint["appearance"] = parsed.get("appearance", {}).duplicate(true) if parsed.get("appearance", {}) is Dictionary else {}
	blueprint["assembly"] = parsed.get("assembly", {}).duplicate(true)
	blueprint["progression"] = parsed.get(
		"progression",
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
		placement["socket_type"] = str(
			serialized_part.get("socket_type", "surface")
		)
		placement["paired_uid"] = str(
			serialized_part.get("paired_uid", "")
		)
		loaded_parts[index] = placement
	blueprint["parts"] = loaded_parts
	normalize(blueprint)
	return blueprint


static func load_best_available() -> Dictionary:
	var blueprint: Dictionary = load_from_file(SAVE_PATH)
	if not blueprint.is_empty():
		return blueprint
	blueprint = BlueprintV5.load_from_file(LEGACY_V5_PATH)
	if blueprint.is_empty():
		blueprint = BaseBlueprint.load_from_file(LEGACY_BASE_PATH)
		if not blueprint.is_empty():
			SpineProfile.load_profile(blueprint)
	if blueprint.is_empty():
		return create_default()
	Ids.ensure_design(blueprint, LEGACY_V5_PATH if not Store.read_text(LEGACY_V5_PATH).is_empty() else LEGACY_BASE_PATH)
	normalize(blueprint)
	return blueprint


static func _serialize_spine(segments: Array) -> Array:
	var serialized: Array = []
	for segment_value in segments:
		var segment: Dictionary = {}
		if segment_value is Dictionary:
			segment = segment_value
		serialized.append({
			"t": float(segment.get("t", float(serialized.size()) / 6.0)),
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
			"t": float(source.get("t", float(index) / 6.0)),
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
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO
