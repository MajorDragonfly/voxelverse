extends RefCounted

const Base = preload("res://world/surface/surface_lab_store.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const GENERATION: String = "living_planet_v1"
const Domestic = preload("res://world/fauna/domestication/domestic_surface_store.gd")
const PATH: String = "user://living_planet_v1.json"


static func valid(data: Dictionary) -> bool:
	if not Domestic.Contract.Values.integer(data.get("schema"), 1, 2): return false
	var legacy_header: Dictionary = data.duplicate()
	legacy_header.schema = 1
	if data.get("surface_generation") != GENERATION or data.get("fauna_codec") != "godot_native_v1" or not Base.valid(legacy_header):
		return false
	var system := Base.System.new(false, true)
	for id: String in data.bodies:
		if not Domestic.valid(data.bodies[id], system.bodies[id], int(data.schema)): return false
		var fauna: Variant = data.bodies[id].get("fauna")
		if not fauna is Dictionary or fauna.size() > 256:
			return false
		for key: Variant in fauna:
			if not key is String or not key.begins_with(id + ":land1:") or not key.ends_with(":animal"):
				return false
			var state: Variant = fauna[key]
			if not Base.pose_valid(state, id) or not state.get("returning") is bool:
				return false
			if not Cube.valid(state.get("home"), id) or not Cube.valid(state.get("goal"), id):
				return false
			if absf(state.home.height) > 20000.0 or absf(state.goal.height) > 20000.0:
				return false
			if not state.get("design") is Dictionary or state.design.get("type") != "Dictionary" or JSON.stringify(state.design).length() > 262144:
				return false
			var design: Variant = JSON.to_native(state.design, false)
			if not design is Dictionary or design.get("version") != 7 or not design.get("body") is Dictionary \
				or not design.get("parts") is Array or not design.get("design_id") is String:
				return false
	return JSON.stringify(data).length() <= 16777216


static func read(path: String = PATH) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var data: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(candidate))
		if not data.is_empty() and not valid(data):
			return {"error": ERR_UNAVAILABLE, "data": {}}
		if valid(data):
			return {"error": OK, "data": data, "recovered": candidate != path}
	return {"error": ERR_FILE_CORRUPT if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak") else OK, "data": {}}


static func write(data: Dictionary, path: String = PATH) -> Error:
	if not valid(data):
		return ERR_INVALID_DATA
	var previous: Dictionary = read(path)
	if previous.error != OK:
		return previous.error
	return Atomic.write(path, data, not previous.get("recovered", false))
