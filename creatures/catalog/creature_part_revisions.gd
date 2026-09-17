extends RefCounted
## Persisted part references. Missing fields mean the frozen shipped revision 1,
## never the latest model. Assembly/design revisions are a separate contract.
const Fins = preload("res://creatures/catalog/creature_fin_catalog.gd")
const Ears = preload("res://creatures/catalog/creature_ear_catalog.gd")
const Wings = preload("res://creatures/catalog/creature_wing_catalog.gd")
const Mouths = preload("res://creatures/catalog/creature_mouth_catalog.gd")
const Hands = preload("res://creatures/catalog/creature_hand_catalog.gd")
const Tails = preload("res://creatures/catalog/creature_tail_catalog.gd")
const Feet = preload("res://creatures/catalog/creature_foot_catalog.gd")
const LEGACY_REVISION: int = 1
const LEGACY_CATALOG_REVISION: int = 1
const FIELDS: Array[String] = ["part_revision", "catalog_revision", "end_part_revision", "end_catalog_revision"]


static func version_error(data: Dictionary) -> String:
	var sections: Array = [data]
	for key in ["body", "paint"]:
		if not data.get(key, {}) is Dictionary: return "invalid_" + key
		sections.append(data.get(key, {}))
	var parts: Variant = data.get("parts", [])
	if not parts is Array: return "invalid_parts"
	if parts.size() > 2048: return "too_many_parts"
	sections.append_array(parts)
	for section in sections:
		if not section is Dictionary: return "invalid_part"
		var error: String = reference_error(section)
		if not error.is_empty(): return error
	return ""


static func reference_error(reference: Dictionary) -> String:
	for field in FIELDS:
		if not reference.has(field): continue
		var value: Variant = reference[field]
		if not (value is int or value is float) or not is_finite(float(value)):
			return "invalid_part_revision"
		if float(value) < 1 or floorf(float(value)) != float(value): return "invalid_part_revision"
		# Revision 1 is the only shipped geometry. Add an explicit historical
		# resolver before accepting another revision; never clamp/downgrade it.
		if float(value) > 1: return "unsupported_part_revision"
	return ""


static func pin_legacy(blueprint: Dictionary) -> void:
	if not version_error(blueprint).is_empty(): return
	for key in ["body", "paint"]:
		pin_reference(blueprint.get(key, {}))
	for part: Dictionary in blueprint.get("parts", []):
		pin_reference(part)
		if str(part.get("category", "")) in ["legs", "arms"]:
			pin_reference(part, "end_")


static func pin_reference(reference: Dictionary, prefix: String = "") -> void:
	if not reference.has(prefix + "part_revision"):
		reference[prefix + "part_revision"] = LEGACY_REVISION
	if not reference.has(prefix + "catalog_revision"):
		reference[prefix + "catalog_revision"] = LEGACY_CATALOG_REVISION


static func copy_fields(source: Dictionary, target: Dictionary) -> void:
	for field in FIELDS:
		if source.has(field): target[field] = int(source[field])


static func resolve(id: String, reference: Dictionary, prefix: String = "") -> Dictionary:
	if not reference_error(reference).is_empty(): return {}
	var revision: int = int(reference.get(prefix + "part_revision", LEGACY_REVISION))
	var profile: Dictionary = {}
	if id.begins_with("fins_"):
		profile = Fins.get_profile(id, revision)
		if profile.is_empty(): return {}
	elif id.begins_with("ears_"):
		profile = Ears.get_profile(id, revision)
		if profile.is_empty(): return {}
	elif id.begins_with("wings_"):
		profile = Wings.get_profile(id, revision)
		if profile.is_empty(): return {}
	elif id.begins_with("feet_"):
		profile = Feet.get_profile(id, revision)
		if profile.is_empty(): return {}
	elif id.begins_with("hands_"):
		profile = Hands.get_profile(id, revision)
		if profile.is_empty(): return {}
	elif id.begins_with("tail_"):
		profile = Tails.get_profile(id, revision)
		if profile.is_empty(): return {}
	elif id.begins_with("mouth_") or id.begins_with("head_"):
		profile = Mouths.get_profile(id, revision)
		if profile.is_empty() and id not in Mouths.LEGACY_IDS: return {}
	if profile.is_empty():
		return {"geometry_id": id, "geometry_revision": revision}
	return {"geometry_id": profile.geometry_id, "geometry_revision": profile.geometry_revision}


static func default_terminal(id: String, category: String) -> String:
	if category == "legs":
		return "feet_hooves" if id == "legs_hoof" else ("feet_claws" if id in ["legs_spider", "legs_sprinter"] else "feet_pads")
	return "hands_claws" if id == "arms_claws" else "hands_grasp"
