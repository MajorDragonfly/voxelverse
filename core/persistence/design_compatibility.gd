extends RefCounted
class_name DesignCompatibility

const CreatureParts = preload("res://creatures/editor/creature_part_library.gd")
const BuildingParts = preload("res://civilization/buildings/building_part_library.gd")


static func resolve_creature(blueprint: Dictionary) -> void:
	var warnings: Array[String] = []
	for section in ["body", "paint"]:
		var part: Dictionary = blueprint.get(section, {})
		_resolve(part, CreatureParts.get_first_part_id_for_category(section), false, warnings)
	for part in blueprint.get("parts", []):
		if part is Dictionary:
			var fallback: String = CreatureParts.get_first_part_id_for_category(str(part.get("category", "decor")))
			if fallback.is_empty():
				fallback = CreatureParts.get_first_part_id_for_category("decor")
			_resolve(part, fallback, false, warnings)
	blueprint["compatibility_warnings"] = warnings


static func resolve_building(blueprint: Dictionary) -> void:
	var warnings: Array[String] = []
	for part in blueprint.get("parts", []):
		if part is Dictionary:
			_resolve(part, BuildingParts.get_default_part_id(), true, warnings)
	blueprint["compatibility_warnings"] = warnings


static func _resolve(part: Dictionary, fallback: String, building: bool, warnings: Array[String]) -> void:
	var original: String = str(part.get("missing_part_id", ""))
	if original.is_empty():
		original = str(part.get("part_id", ""))
	var definition: Dictionary = BuildingParts.get_part(original) if building else CreatureParts.get_part(original)
	if not definition.is_empty():
		part["part_id"] = original
		part.erase("missing_part_id")
		return
	part["missing_part_id"] = original
	part["part_id"] = fallback
	warnings.append("Missing part '%s': using '%s'. Original ID and placement retained." % [original, fallback])
