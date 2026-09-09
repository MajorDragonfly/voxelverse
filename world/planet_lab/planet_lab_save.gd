extends RefCounted
class_name PlanetLabSave

const Atomic = preload("res://core/persistence/atomic_json.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const System = preload("res://world/space/celestial_system.gd")
const PATH: String = "user://planet_lab_m1.json"


static func valid(data: Dictionary) -> bool:
	if (data.get("schema") != 1 and data.get("schema") != 2 and data.get("schema") != 3) or data.get("surface_version") != Cube.MODE:
		return false
	if data.get("schema") == 2 and data.get("terrain_revision") != System.TERRAIN_REVISION:
		return false
	if data.get("schema") == 3 and (data.get("terrain_revision") != 3 or data.get("scale_mode") != "real"):
		return false
	var ids: Array[String] = System.REAL_LANDABLE if data.get("schema") == 3 else System.LANDABLE
	if not data.get("binary") is bool or data.get("body_id") not in ids:
		return false
	if not Cube.valid(data.get("location"), data.body_id):
		return false
	if absf(float(data.location.height)) > (20000.0 if data.get("schema") == 3 else 1000.0):
		return false
	if not (data.get("elapsed") is float or data.get("elapsed") is int) or not is_finite(float(data.elapsed)) or data.elapsed < 0.0:
		return false
	if not data.get("forward") is Array or data.forward.size() != 3:
		return false
	for value in data.forward:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	return Cube.vector(data.forward).length_squared() > 0.5


static func write(data: Dictionary, path: String = PATH) -> Error:
	if not valid(data):
		return ERR_INVALID_DATA
	if FileAccess.file_exists(path) and _incompatible(Atomic.parse_dictionary(FileAccess.get_file_as_string(path))):
		return ERR_UNAVAILABLE
	return Atomic.write(path, data)


static func read(path: String = PATH) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var data: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(candidate))
		if _incompatible(data):
			return {}
		if valid(data):
			return data
	return {}


static func _incompatible(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var schema: int = int(data.get("schema", 1))
	return schema not in [1, 2, 3] or data.get("surface_version", Cube.MODE) != Cube.MODE \
		or int(data.get("terrain_revision", 1)) > (3 if schema == 3 else System.TERRAIN_REVISION) \
		or (schema == 3 and data.get("scale_mode", "real") != "real")
