extends RefCounted
class_name PlanetLabSave

const Atomic = preload("res://core/persistence/atomic_json.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const System = preload("res://world/space/celestial_system.gd")
const Catalog = preload("res://world/space/galaxy_catalog.gd")
const Visits = preload("res://world/space/galaxy_visits.gd")
const Exploration = preload("res://core/map/exploration_atlas.gd")
const PATH: String = "user://planet_lab_m1.json"


static func valid(data: Dictionary) -> bool:
	var atlases: Variant = data.get("map_atlases", {})
	if not atlases is Dictionary or atlases.size() > 256: return false
	for body_id in atlases:
		if not body_id is String or not Exploration.validate(atlases[body_id], body_id).is_empty(): return false
		if atlases[body_id].mode != Cube.MODE: return false
	if (data.get("schema") != 1 and data.get("schema") != 2 and data.get("schema") != 3 and data.get("schema") != 4) or data.get("surface_version") != Cube.MODE:
		return false
	if data.get("schema") == 4:
		return _valid_visit(data)
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


static func _valid_visit(data: Dictionary) -> bool:
	if data.get("catalog_version") != Catalog.VERSION or data.get("scale_mode") != "real" or not data.get("system_id") is String:
		return false
	var address: Dictionary = Catalog.Address.parse(data.system_id)
	if address.get("kind") != "system":
		return false
	var catalog := Catalog.new(address.universe_seed, address.galaxy_index)
	var entry: Dictionary = catalog.system(data.system_id)
	if entry.is_empty() or data.get("body_id") not in entry.bodies or not entry.bodies[data.body_id].get("landable", false) or not data.get("binary") is bool or data.binary != (entry.star_count == 2):
		return false
	var elapsed: Variant = data.get("elapsed")
	return (elapsed is float or elapsed is int) and is_finite(float(elapsed)) and elapsed >= 0.0 and Visits.valid_pose({"terrain_revision": data.get("terrain_revision"), "location": data.get("location"), "forward": data.get("forward")}, data.body_id)


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
	var atlases: Variant = data.get("map_atlases", {})
	if atlases is Dictionary:
		for atlas in atlases.values():
			if Exploration.newer(atlas): return true
	if data.is_empty():
		return false
	var schema: int = int(data.get("schema", 1))
	return schema not in [1, 2, 3, 4] or data.get("surface_version", Cube.MODE) != Cube.MODE \
		or int(data.get("terrain_revision", 1)) > (3 if schema >= 3 else System.TERRAIN_REVISION) \
		or (schema >= 3 and data.get("scale_mode", "real") != "real") \
		or (schema == 4 and data.get("catalog_version") != Catalog.VERSION)
