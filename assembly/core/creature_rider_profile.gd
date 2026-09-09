extends RefCounted
## Optional JSON-only reference dimensions inside the existing body contract.
const Attachments = preload("res://assembly/core/creature_body_attachments.gd")
const KEY: String = "fit_profile"
const SCHEMA: int = 1
const DEFAULT: Dictionary = {"schema": 1, "rider_scale": 1.0, "leg_spacing": 0.48, "seat_height": 0.20}
const LIMITS: Dictionary = {"rider_scale": [0.5, 2.0], "leg_spacing": [0.28, 2.4], "seat_height": [0.12, 0.6]}


static func read(blueprint: Dictionary) -> Dictionary:
	var attachments: Dictionary = Attachments.read(blueprint)
	var value: Variant = attachments.get(KEY, DEFAULT)
	return value.duplicate(true) if value is Dictionary else {"schema": -1}


static func validate(profile: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not Attachments._number(profile.get("schema"), SCHEMA, SCHEMA):
		errors.append("unsupported_rider_profile")
	for field in LIMITS:
		if not Attachments._number(profile.get(field), LIMITS[field][0], LIMITS[field][1]):
			errors.append("invalid_rider_" + field)
	return errors


static func store_in(blueprint: Dictionary, profile: Dictionary) -> bool:
	var attachments: Dictionary = Attachments.read(blueprint)
	if not Attachments.validate(attachments).is_empty() or not validate(read(blueprint)).is_empty() or not validate(profile).is_empty():
		return false
	attachments[KEY] = profile.duplicate(true)
	var assembly: Dictionary = blueprint.get("assembly", {}).duplicate(true)
	assembly[Attachments.KEY] = attachments
	blueprint["assembly"] = assembly
	return true
