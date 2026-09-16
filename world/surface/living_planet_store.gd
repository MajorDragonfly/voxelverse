extends RefCounted

const Base = preload("res://world/surface/surface_lab_store.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const SCHEMA: int = 4
const GENERATION: String = "living_planet_v1"
const Domestic = preload("res://world/fauna/domestication/domestic_surface_store.gd")
const Atlas = preload("res://core/map/exploration_atlas.gd")
const Fauna = preload("res://world/surface/living_fauna_archive.gd")
const PATH: String = "user://living_planet_v1.json"


static func valid(data: Dictionary) -> bool:
	if not Domestic.Contract.Values.integer(data.get("schema"), 1, SCHEMA): return false
	var legacy_header: Dictionary = data.duplicate()
	legacy_header.schema = 1
	if data.get("surface_generation") != GENERATION or data.get("fauna_codec") != "godot_native_v1" or not Base.valid(legacy_header):
		return false
	var system := Base.System.new(false, true)
	if int(data.schema) >= 3 and not data.has("map_atlases"): return false
	if int(data.schema) < 3 and data.has("map_atlases"): return false
	var atlases: Variant = data.get("map_atlases", {})
	if not atlases is Dictionary or atlases.size() > 3: return false
	for id: Variant in atlases:
		if id not in Base.System.REAL_LANDABLE or not Atlas.validate(atlases[id], id).is_empty(): return false
		if atlases[id].mode != Cube.MODE or float(atlases[id].radius) != float(system.bodies[id].radius): return false
	for id: String in data.bodies:
		# Header 3 adds maps; the D1.2 payload remains the reviewed header-2 contract.
		if not Domestic.valid(data.bodies[id], system.bodies[id], mini(int(data.schema), 2)): return false
		var record: Dictionary = data.bodies[id]
		if record.has("fauna_archive"):
			if int(data.schema) < 4 or record.has("fauna") or not Fauna.manifest_valid(record.fauna_archive, id): return false
		else:
			var fauna: Variant = record.get("fauna")
			if not fauna is Dictionary or fauna.size() > 256: return false
			for key: Variant in fauna:
				if not Fauna.state_valid(key, fauna[key], id): return false
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
