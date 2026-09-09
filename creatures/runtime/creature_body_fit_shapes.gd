extends RefCounted
## Versioned reference equipment, in body-scale units. Shared by display/query.
const PROFILE: String = "workshop_reference_v1"


static func boxes(id: String) -> Array:
	if id == "saddle.primary":
		return [
			_box("Saddle", Vector3(0, 0.055, 0), Vector3(0.36, 0.11, 0.48)),
			_box("Pelvis", Vector3(0, 0.20, 0), Vector3(0.20, 0.16, 0.18)),
			_box("Torso", Vector3(0, 0.40, 0), Vector3(0.24, 0.30, 0.16)),
			_box("Head", Vector3(0, 0.65, -0.025), Vector3.ONE * 0.17),
			_box("RiderLegLeft", Vector3(-0.24, 0.02, -0.04), Vector3(0.09, 0.32, 0.12)),
			_box("RiderLegRight", Vector3(0.24, 0.02, -0.04), Vector3(0.09, 0.32, 0.12))]
	return [_box("HarnessPad", Vector3.ZERO, Vector3(0.075, 0.24, 0.3)),
		_box("Trace", Vector3(0, 0, 0.4), Vector3(0.035, 0.035, 0.8))]


static func _box(id: String, center: Vector3, size: Vector3) -> Dictionary:
	return {"id": id, "bounds": AABB(center - size * 0.5, size)}
