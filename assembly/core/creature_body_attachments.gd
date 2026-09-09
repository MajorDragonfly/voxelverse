extends RefCounted
## JSON-only authoring contract. No species roles, ownership, RNG or world axes.
const SCHEMA: int = 1
const KEY: String = "body_attachments"
const IDS: Array[String] = ["saddle.primary", "harness.left", "harness.right"]


static func defaults() -> Dictionary:
	var sockets: Dictionary = {}
	for id in IDS:
		sockets[id] = {"enabled": true, "t": 0.52 if id == "saddle.primary" else 0.32,
			"offset": [0.0, 0.0, 0.0], "rotation_degrees": [0.0, 0.0, 0.0]}
	return {"schema": SCHEMA, "sockets": sockets}


static func ensure(blueprint: Dictionary) -> void:
	var assembly: Dictionary = blueprint.get("assembly", {})
	# Only an absent field is legacy. Preserve malformed/future payloads so a
	# reader can reject them without silently replacing authored connections.
	if not assembly.has(KEY):
		assembly[KEY] = defaults()
	blueprint["assembly"] = assembly


static func read(blueprint: Dictionary) -> Dictionary:
	var assembly: Variant = blueprint.get("assembly", {})
	if not assembly is Dictionary:
		return {}
	var data: Variant = assembly.get(KEY, defaults())
	return data.duplicate(true) if data is Dictionary else {}


static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not _number(data.get("schema"), SCHEMA, SCHEMA) or not data.get("sockets") is Dictionary:
		errors.append("unsupported_body_attachments")
		return errors
	for id in IDS:
		var socket: Variant = data["sockets"].get(id)
		if not socket is Dictionary:
			errors.append("missing_socket:" + id)
			continue
		if not socket.get("enabled") is bool:
			errors.append("invalid_enabled:" + id)
		if not _number(socket.get("t"), 0.12, 0.88):
			errors.append("invalid_t:" + id)
		for field in ["offset", "rotation_degrees"]:
			var values: Variant = socket.get(field)
			var limit: float = 0.5 if field == "offset" else 180.0
			if not values is Array or values.size() != 3:
				errors.append("invalid_" + field + ":" + id)
				continue
			for value in values:
				if not _number(value, -limit, limit):
					errors.append("invalid_" + field + ":" + id)
	return errors


static func set_socket(blueprint: Dictionary, id: String, socket: Dictionary) -> bool:
	if id not in IDS:
		return false
	var data: Dictionary = read(blueprint)
	if not validate(data).is_empty():
		return false
	data["sockets"][id] = socket.duplicate(true)
	if not validate(data).is_empty():
		return false
	var assembly: Dictionary = blueprint.get("assembly", {}).duplicate(true)
	assembly[KEY] = data
	blueprint["assembly"] = assembly
	return true


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum
