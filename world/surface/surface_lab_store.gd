extends RefCounted

## Independent M1d storage. Deliberately accepts only the three real reference
## bodies and fixture revision 1; no implicit campaign/catalog migration.
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const System = preload("res://world/space/celestial_system.gd")
const PATH: String = "user://surface_adapter_m1d.json"


static func finite(value: Variant, limit: float = 1.0e9) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= limit


static func vector_valid(value: Variant, limit: float) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not finite(component, limit):
			return false
	return true


static func pose_valid(value: Variant, id: String) -> bool:
	if not value is Dictionary or not Cube.valid(value.get("location"), id):
		return false
	return absf(value.location.height) <= 20000.0 and vector_valid(value.get("forward"), 1.01) \
		and Cube.vector(value.forward).length_squared() > 0.5 \
		and vector_valid(value.get("velocity"), 1000.0) \
		and finite(value.get("traveled")) and value.traveled >= 0.0


static func valid(data: Dictionary) -> bool:
	if data.get("schema") != 1 or data.get("fixture_revision") != 1 or data.get("surface_mode") != Cube.MODE:
		return false
	if not data.get("bodies") is Dictionary or data.bodies.size() > 3 or data.get("body_id") not in data.bodies:
		return false
	var system := System.new(false, true)
	for id: String in data.bodies:
		if id not in System.REAL_LANDABLE or not data.bodies[id] is Dictionary:
			return false
		var record: Dictionary = data.bodies[id]
		var body: Dictionary = system.bodies[id]
		if record.get("radius") != body.radius or record.get("seed") != body.seed or record.get("terrain_revision") != 3:
			return false
		if not Cube.valid(record.get("spawn"), id) or absf(record.spawn.height) > 20000.0 or not pose_valid(record.get("player"), id):
			return false
		for kind in ["tree", "creature"]:
			var object: Variant = record.get(kind)
			if not pose_valid(object, id) or object.get("object_id") != id + ":m1d:" + kind:
				return false
		if record.tree.get("asset_id") != "ancient_oak_v2" or record.creature.get("design_id") != "default_v7_fixture1":
			return false
		if not record.creature.get("returning") is bool:
			return false
		for key in ["home", "goal"]:
			if not Cube.valid(record.creature.get(key), id) or absf(record.creature[key].height) > 20000.0:
				return false
	return true


static func read(path: String = PATH) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var data: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(candidate))
		# A parseable incompatible version is protected, even with an old backup.
		if not data.is_empty() and not valid(data):
			return {"error": ERR_UNAVAILABLE, "data": {}}
		if valid(data):
			return {"error": OK, "data": data, "recovered": candidate != path}
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		return {"error": ERR_FILE_CORRUPT, "data": {}}
	return {"error": OK, "data": {}}


static func write(data: Dictionary, path: String = PATH) -> Error:
	if not valid(data):
		return ERR_INVALID_DATA
	var previous: Dictionary = read(path)
	if previous.error != OK:
		return previous.error
	# Retain a recovered backup instead of replacing it with broken primary text.
	return Atomic.write(path, data, not previous.get("recovered", false))
