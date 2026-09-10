extends RefCounted
## A closed, declarative subset of V7. No downloaded resource paths or code.
## Optional fields use a '?' suffix in these rules, never in the wire format.
const MAX_BYTES: int = 2 * 1024 * 1024
const MAX_PARTS: int = 256
const VECTOR_EPSILON: float = 0.000001 # Native Vector3 components have float32 precision.
const REVISION: Array = ["int", 0, 9007199254740990.0]
const SOCKET: Dictionary = {
	"enabled": "bool", "t": ["num", 0.12, 0.88],
	"offset": ["vec", -0.5, 0.5], "rotation_degrees": ["vec", -180, 180],
}
const ATTACHMENTS: Dictionary = {
	"schema": ["int", 1, 1],
	"sockets": {"saddle.primary": SOCKET, "harness.left": SOCKET, "harness.right": SOCKET},
	"fit_profile?": {"schema": ["int", 1, 1], "rider_scale": ["num", 0.5, 2],
		"leg_spacing": ["num", 0.28, 2.4], "seat_height": ["num", 0.12, 0.6]},
}
const BODY: Dictionary = {
	"part_id": "id", "shape": ["vec", 0.45, 4.5], "scale": ["num", 0.45, 2.25],
	"spine_length_scale": ["num", 0.45, 3],
	"spine": ["list", {"t": ["num", 0, 1], "width_scale": ["num", 0.22, 2.6],
		"height_scale": ["num", 0.22, 2.6], "y_offset": ["num", -1.8, 1.8]}, 7],
}
const PAINT: Dictionary = {"part_id": "id", "intensity": ["num", 0, 1]}
const APPEARANCE: Dictionary = {
	"skin_type": ["enum", "smooth", "scales", "fur", "leather", "chitin"],
	"skin_strength": ["num", 0, 1], "skin_scale": ["num", 0.4, 2.5],
	"base_color?": "color", "accent_color?": "color", "belly_color?": "color",
	"eye_color?": "color", "horn_color?": "color",
}
const PART: Dictionary = {
	"uid": "id", "part_id": "id", "category": ["enum", "mouth", "eyes", "legs",
		"arms", "tail", "horns", "plates", "spikes", "decor"],
	"position": ["vec", -32, 32], "rotation": ["vec", -36000, 36000],
	"scale": ["num", 0.25, 3], "mirrored": "bool", "center_locked": "bool",
	"shape_scale": ["vec", 0.4, 2.5], "end_part_id": "optional_id",
	"end_scale": ["num", 0.4, 2], "end_shape_scale": ["vec", 0.4, 2.5],
	"end_rotation": ["vec", -36000, 36000],
	"joint": {"upper": ["num", 0.4, 2.2], "lower": ["num", 0.4, 2.2], "offset": ["vec", -0.6, 0.6]},
	"anchor_t": ["num", 0, 1], "anchor_side": ["num", -1, 1],
	"anchor_vertical": ["num", -1, 1], "anchor_surface_offset": ["vec", -32, 32],
	"manual_offset": ["vec", -32, 32], "anchor_locked": "bool",
	"socket_type": ["enum", "surface", "front", "rear", "lower_side", "side", "upper_front", "upper_spine"],
	"paired_uid": "optional_id",
}
const BLUEPRINT: Dictionary = {
	"version": ["int", 7, 7], "name": ["text", 120], "body": BODY, "paint": PAINT,
	"parts": ["list", PART, MAX_PARTS], "appearance": APPEARANCE,
	"assembly": {"schema": ["int", 7, 7], "body_attachments": ATTACHMENTS},
}
const ORIGIN: Dictionary = {"design_id": "id", "revision": REVISION, "author": ["text", 120]}
const PACKAGE: Dictionary = {
	"schema": ["int", 1, 1], "kind": ["enum", "creature"],
	"catalog_revision": ["int", 1, 1], "design_id": "id", "revision": REVISION,
	"title": ["text", 120], "description": ["text", 2000], "author": ["text", 120],
	"tags": ["list", ["text", 40], 12], "provenance": ["list", ORIGIN, 8],
	"required_parts": ["list", "id", MAX_PARTS * 2 + 2], "blueprint": BLUEPRINT,
}


## Returns the first invalid field, without converting or walking unknown data.
static func problem(value: Variant, rule: Variant = PACKAGE, path: String = "package") -> String:
	if rule is Dictionary:
		if not value is Dictionary: return path
		if value.size() > rule.size(): return path
		for key in value:
			if not (key is String or key is StringName) or not (rule.has(key) or rule.has(str(key) + "?")): return path + ".unknown_field"
		for key: String in rule:
			var field: String = key.trim_suffix("?")
			if key.ends_with("?") and not value.has(field): continue
			var error: String = problem(value.get(field), rule[key], path + "." + field)
			if not error.is_empty(): return error
		return ""
	if rule is Array:
		match rule[0]:
			"num", "int":
				if not (value is int or value is float) or not is_finite(float(value)): return path
				if float(value) < float(rule[1]) or float(value) > float(rule[2]): return path
				if rule[0] == "int" and floorf(float(value)) != float(value): return path
			"vec":
				if not value is Array or value.size() != 3: return path
				for element in value:
					if not problem(element, ["num", float(rule[1]) - VECTOR_EPSILON, float(rule[2]) + VECTOR_EPSILON], path).is_empty(): return path
			"list":
				if not value is Array or value.size() > int(rule[2]): return path
				for index in range(value.size()):
					var error: String = problem(value[index], rule[1], path + "[%d]" % index)
					if not error.is_empty(): return error
			"enum":
				if not value is String or not value in rule.slice(1): return path
			"text":
				if not value is String or value.to_utf8_buffer().size() > int(rule[1]) or value.to_utf8_buffer().has(0): return path
		return ""
	if rule == "bool": return "" if value is bool else path
	if not value is String: return path
	if rule == "color":
		if value.length() not in [6, 8]: return path
		for character in value.to_lower():
			if not character in "0123456789abcdef": return path
		return ""
	if value.is_empty(): return "" if rule == "optional_id" else path
	if value.length() > 96: return path
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.:-": return path
	return ""


## Select authoring fields only. Never copy opaque extensions to a public file.
static func project(value: Dictionary, rule: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in rule:
		var field: String = key.trim_suffix("?")
		if not value.has(field): continue
		var child_rule: Variant = rule[key]
		if child_rule is Dictionary and value[field] is Dictionary:
			result[field] = project(value[field], child_rule)
		elif child_rule is Array and child_rule[0] == "list" and child_rule[1] is Dictionary and value[field] is Array:
			result[field] = []
			for element in value[field]:
				result[field].append(project(element, child_rule[1]) if element is Dictionary else null)
		else:
			result[field] = value[field]
	return result.duplicate(true)
