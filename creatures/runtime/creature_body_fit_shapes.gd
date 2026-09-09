extends RefCounted
## Versioned reference equipment, in body-scale units. Shared by display/query.
const PROFILE: String = "workshop_reference_v2"
const Rider = preload("res://assembly/core/creature_rider_profile.gd")
const ADJUSTABLE_PROFILE: String = "workshop_rider_v1"


static func boxes(id: String, profile: Dictionary = Rider.DEFAULT) -> Array:
	if not Rider.validate(profile).is_empty():
		return []
	var size: float = profile["rider_scale"]
	var height: float = profile["seat_height"]
	var spacing: float = profile["leg_spacing"]
	if id == "saddle.primary":
		return [
			_box("Saddle", Vector3(0, 0.055, 0), Vector3(0.36, 0.11, 0.48)),
			_box("Pelvis", Vector3(0, height, 0), Vector3(0.20, 0.16, 0.18) * size),
			_box("Torso", Vector3(0, height + 0.20 * size, 0), Vector3(0.24, 0.30, 0.16) * size),
			_box("Head", Vector3(0, height + 0.45 * size, -0.025 * size), Vector3.ONE * 0.17 * size),
			_box("RiderThighLeft", Vector3(-spacing * 0.25 - 0.05 * size, height - 0.01 * size, -0.04 * size), Vector3(absf(spacing * 0.5 - 0.1 * size) + 0.06 * size, 0.08 * size, 0.10 * size)),
			_box("RiderThighRight", Vector3(spacing * 0.25 + 0.05 * size, height - 0.01 * size, -0.04 * size), Vector3(absf(spacing * 0.5 - 0.1 * size) + 0.06 * size, 0.08 * size, 0.10 * size)),
			_box("RiderLegLeft", Vector3(-spacing * 0.5, height - 0.18 * size, -0.04 * size), Vector3(0.09, 0.32, 0.12) * size),
			_box("RiderLegRight", Vector3(spacing * 0.5, height - 0.18 * size, -0.04 * size), Vector3(0.09, 0.32, 0.12) * size)]
	return [_box("HarnessPad", Vector3.ZERO, Vector3(0.075, 0.24, 0.3)),
		_box("Trace", Vector3(0, 0, 0.4), Vector3(0.035, 0.035, 0.8))]


static func _box(id: String, center: Vector3, size: Vector3) -> Dictionary:
	return {"id": id, "bounds": AABB(center - size * 0.5, size)}
