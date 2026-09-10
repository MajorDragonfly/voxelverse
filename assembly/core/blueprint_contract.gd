extends RefCounted
## Read-only boundary checks. Normalization is only for supported local data.
## These are persistence limits, not extra player form points or build capacity.
const MAX_PARTS: int = 2048
const MAX_BYTES: int = 2 * 1024 * 1024
const MAX_DEPTH: int = 24
const MAX_VALUES: int = 100000


static func kind_of(data: Dictionary) -> String:
	if data.has("building") or data.get("assembly_type") == "building":
		return "building"
	if data.has("body") or data.has("assembly") or data.has("version"):
		return "creature"
	return "modular"


static func version_error(data: Dictionary, kind: String = "") -> String:
	if kind.is_empty():
		kind = kind_of(data)
	var code: String = ""
	if kind == "creature":
		code = _version(data, "version", 7)
		if not code.is_empty(): return code
		code = _section(data, "assembly", 7)
		if not code.is_empty(): return code
		var assembly: Dictionary = data.get("assembly", {})
		code = _section(assembly, "body_attachments", 1)
		if not code.is_empty(): return code
		return _section(assembly.get("body_attachments", {}), "fit_profile", 1)
	code = _version(data, "schema", 1)
	if not code.is_empty(): return code
	return _section(data, "building", 1) if kind == "building" else ""


static func inspect(data: Dictionary, kind: String = "") -> Dictionary:
	var code: String = version_error(data, kind)
	if not code.is_empty(): return _result(code)
	if data.is_empty(): return _result("empty_blueprint")
	if kind.is_empty(): kind = kind_of(data)
	var budget: Array[int] = [MAX_VALUES]
	if not _bounded_value(data, 0, budget): return _result("invalid_or_excessive_data")
	if JSON.stringify(data).to_utf8_buffer().size() > MAX_BYTES: return _result("blueprint_too_large")
	if not data.get("parts", []) is Array: return _result("invalid_parts")
	var parts: Array = data.get("parts", [])
	if parts.size() > MAX_PARTS: return _result("too_many_parts")
	for section in ["metadata", "extensions", "body", "paint", "appearance", "progression"]:
		if data.has(section) and not data[section] is Dictionary: return _result("invalid_" + section)
	if not _extensions(data): return _result("invalid_extensions")
	for section in ["body", "paint"]:
		if not _extensions(data.get(section, {})): return _result("invalid_extensions")
	if data.has("grid_size") and not _number(data.grid_size): return _result("invalid_grid_size")
	var body: Dictionary = data.get("body", {})
	if body.has("shape") and not _vector(body.shape): return _result("invalid_body_shape")
	for field in ["scale", "spine_length_scale"]:
		if body.has(field) and not _number(body[field]): return _result("invalid_body_" + field)
	if body.has("spine") and not body.spine is Array: return _result("invalid_spine")
	var paint: Dictionary = data.get("paint", {})
	if paint.has("intensity") and not _number(paint.intensity): return _result("invalid_paint_intensity")
	if not _revision(data.get("revision", 0)): return _result("invalid_revision")
	if kind == "creature" and not _revision(data.get("assembly", {}).get("revision", 0)):
		return _result("invalid_revision")
	var uids: Dictionary = {}
	for part in parts:
		if not part is Dictionary: return _result("invalid_part")
		if not part.get("part_id", "") is String: return _result("invalid_part_id")
		var uid: String = str(part.get("uid", ""))
		# Missing legacy UIDs are supplied by the existing migration.
		if not uid.is_empty():
			if uids.has(uid): return _result("duplicate_part_uid")
			uids[uid] = true
		for field in ["position", "rotation", "shape_scale", "end_shape_scale", "end_rotation", "manual_offset", "anchor_surface_offset"]:
			if part.has(field) and not _vector(part[field]): return _result("invalid_" + field)
		if part.has("scale") and not (_number(part.scale) if kind == "creature" else _vector(part.scale)):
			return _result("invalid_scale")
		for field in ["end_scale", "anchor_t", "anchor_side", "anchor_vertical"]:
			if part.has(field) and not _number(part[field]): return _result("invalid_" + field)
		if part.has("tags") and not part.tags is Array: return _result("invalid_tags")
		if part.has("extensions") and not part.extensions is Dictionary: return _result("invalid_extensions")
		if not _extensions(part): return _result("invalid_extensions")
	return _result("")


## Only missing legacy IDs are added; existing IDs and the input stay intact.
static func migrate_part_ids(data: Dictionary, legacy_key: String = "") -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	var owner: String = str(data.get("design_id", legacy_key))
	if owner.is_empty(): owner = JSON.stringify(data).sha256_text()
	var parts: Array = result.get("parts", [])
	for index in range(parts.size()):
		if str(parts[index].get("uid", "")).is_empty():
			parts[index]["uid"] = "legacy_" + JSON.stringify([owner, index]).sha256_text().left(32)
	return result


static func inspect_text(text: String, kind: String = "") -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES: return _result("blueprint_too_large")
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary: return _result("invalid_json")
	var parsed: Dictionary = parser.data
	return inspect(parsed, kind)


static func _version(data: Dictionary, key: String, maximum: int) -> String:
	if not data.has(key): return "" # Explicitly supported unversioned legacy data.
	var value: Variant = data[key]
	if not _number(value) or float(value) < 1 or floorf(float(value)) != float(value):
		return "invalid_version"
	return "future_version" if float(value) > maximum else ""


static func _section(data: Dictionary, key: String, maximum: int) -> String:
	if not data.has(key): return ""
	if not data[key] is Dictionary: return "invalid_" + key
	return _version(data[key], "schema", maximum)


static func _result(code: String) -> Dictionary:
	return {"ok": code.is_empty(), "code": code}


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _revision(value: Variant) -> bool:
	return _number(value) and float(value) >= 0 and float(value) <= 9007199254740990.0 and floorf(float(value)) == float(value)


static func _vector(value: Variant) -> bool:
	if value is Vector3: return value.is_finite()
	if value is Array:
		return value.size() == 3 and _number(value[0]) and _number(value[1]) and _number(value[2])
	if value is Dictionary:
		return _number(value.get("x")) and _number(value.get("y")) and _number(value.get("z"))
	return false


static func _extensions(data: Dictionary) -> bool:
	for field in ["part_revision", "catalog_revision"]:
		if data.has(field) and not _revision(data[field]): return false
	if not data.has("extensions"): return true
	var budget: Array[int] = [MAX_VALUES]
	return data.extensions is Dictionary and _bounded_value(data.extensions, 0, budget, false)


static func _bounded_value(value: Variant, depth: int, budget: Array[int], allow_vectors: bool = true) -> bool:
	budget[0] -= 1
	if budget[0] < 0 or depth > MAX_DEPTH: return false
	if value is Dictionary:
		if value.size() > budget[0]: return false
		for key in value:
			if not (key is String or key is StringName) or not _bounded_value(value[key], depth + 1, budget, allow_vectors): return false
		return true
	if value is Array:
		if value.size() > budget[0]: return false
		for entry in value:
			if not _bounded_value(entry, depth + 1, budget, allow_vectors): return false
		return true
	if value is Vector3: return allow_vectors and value.is_finite()
	if value is float: return is_finite(value)
	return value == null or value is bool or value is int or value is String or value is StringName
