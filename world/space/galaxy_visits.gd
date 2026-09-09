extends "res://world/space/galaxy_journal.gd"

## A separate sparse store for actual surface visits. Journal observations keep
## their original schema. The inherited atomic writes retain revision conflicts,
## bounded caches, manifest identity checks and backup recovery.
const Cube = preload("res://world/space/cube_sphere.gd")
const TERRAIN_REVISION: int = 3


func _header() -> Dictionary:
	var header: Dictionary = super._header()
	header["purpose"] = "surface_visits_v1"
	return header


func _empty_record(id: String) -> Dictionary:
	return {"schema": SCHEMA, "catalog_version": catalog.VERSION, "system_id": id, "revision": 0, "elapsed": 0.0, "bodies": {}}


func _valid(data: Dictionary, id: String) -> bool:
	if data.size() != 6 or data.get("schema") != SCHEMA or data.get("catalog_version") != catalog.VERSION or data.get("system_id") != id or not catalog.owns(id, "system"):
		return false
	for key in ["revision", "elapsed"]:
		var number: Variant = data.get(key)
		if not (number is float or number is int) or not is_finite(float(number)) or number < 0:
			return false
	if data.revision >= 1_000_000_000 or float(data.revision) != floorf(data.revision):
		return false
	if not data.get("bodies") is Dictionary or data.bodies.size() > Address.MAX_BODIES:
		return false
	var bodies: Dictionary = catalog.system(id).get("bodies", {})
	for body_id: Variant in data.bodies:
		if not body_id is String or not bodies.has(body_id) or not bodies[body_id].get("landable", false) or not valid_pose(data.bodies[body_id], body_id):
			return false
	return JSON.stringify(data).to_utf8_buffer().size() <= MAX_FILE_BYTES


static func valid_pose(pose: Variant, id: String) -> bool:
	if not pose is Dictionary or pose.size() != 3 or pose.get("terrain_revision") != TERRAIN_REVISION or not Cube.valid(pose.get("location"), id):
		return false
	if absf(float(pose.location.height)) > 20000.0 or not pose.get("forward") is Array or pose.forward.size() != 3:
		return false
	for value: Variant in pose.forward:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	var direction: Vector3 = Cube.vector(pose.forward)
	var up: Vector3 = Cube.vector(Cube.direction(pose.location.face, pose.location.u, pose.location.v))
	return direction.length_squared() > 0.5 and direction.length_squared() < 1.5 and direction.slide(up).length_squared() > 0.5


func _read_disk(id: String) -> Dictionary:
	var path: String = record_path(id)
	if path.is_empty():
		return {"error": ERR_DOES_NOT_EXIST}
	# Future terrain data must not fall back to an older, writable backup.
	for candidate in [path, path + ".bak"]:
		var data: Dictionary = _load_file(candidate)
		if data.get("bodies") is Dictionary:
			for pose: Variant in data.bodies.values():
				if pose is Dictionary and pose.has("terrain_revision") and pose.terrain_revision != TERRAIN_REVISION:
					return {"error": ERR_UNAVAILABLE}
		if _valid(data, id):
			break
	return super._read_disk(id)
