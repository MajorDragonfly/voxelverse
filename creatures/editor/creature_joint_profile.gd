extends RefCounted
## Optional V7 limb authoring. Values describe the rest shape, never a pose.


static func read(value: Variant) -> Dictionary:
	var data: Dictionary = value if value is Dictionary else {}
	var offset: Variant = data.get("offset", Vector3.ZERO)
	if offset is Array and offset.size() == 3:
		offset = Vector3(_number(offset[0], 0), _number(offset[1], 0), _number(offset[2], 0))
	if not (offset is Vector3) or not offset.is_finite():
		offset = Vector3.ZERO
	return {"upper": clampf(_number(data.get("upper", 1.0), 1.0), 0.4, 2.2),
		"lower": clampf(_number(data.get("lower", 1.0), 1.0), 0.4, 2.2),
		"offset": offset.clamp(Vector3(-0.6, -0.3, -0.6), Vector3(0.6, 0.3, 0.6))}


static func encode(value: Variant) -> Dictionary:
	var data: Dictionary = read(value)
	var offset: Vector3 = data["offset"]
	data["offset"] = [offset.x, offset.y, offset.z]
	return data


static func layout(ankle: Vector3, id: String, data: Variant, side: float) -> Dictionary:
	var profile: Dictionary = read(data)
	var length: float = maxf(ankle.length(), 0.05)
	var bend := Vector3(0, 0, length * ( -0.22 if id in ["legs_sprinter", "legs_hoof"] else 0.22))
	var offset: Vector3 = profile["offset"] * Vector3(side, 1, 1) * length
	var reference: Vector3 = ankle * 0.5 + bend + offset
	var knee: Vector3 = reference * float(profile["upper"])
	var end: Vector3 = knee + (ankle - reference) * float(profile["lower"])
	return {"knee": knee, "ankle": end, "reference_length": length}


static func _number(value: Variant, fallback: float) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return float(value)
	return fallback
