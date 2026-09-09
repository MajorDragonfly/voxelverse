extends RefCounted
## D1 habitat schema 2. No dependency on the catalog or campaign singleton.
const Cube = preload("res://world/space/cube_sphere.gd")
const Values = preload("res://world/fauna/domestication/domestication_contract.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const SCHEMA: int = 2
const GENERATION: String = "living_planet_v1"
const ALGORITHM: String = "domestic_surface_search_v1"
const MAX_NODES: int = 4096
const MAX_PATH: int = 512
const RADIUS: float = 128.0
const STEP: float = 4.0
const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]

static func eligible(body: Dictionary) -> bool:
	return body.get("kind") in ["planet", "moon"] and body.get("inhabited") == true \
		and body.get("surface_mode") == Cube.MODE and body.get("surface_generation") == GENERATION

static func unsupported(catalog: Dictionary) -> bool:
	var surface: Variant = catalog.get("surface")
	if not surface is Dictionary or surface.get("schema") != 1 or surface.get("mode") != Cube.MODE or surface.get("generation") != GENERATION: return true
	var search: Variant = catalog.get("surface_search")
	return search != null and (not search is Dictionary or search.get("schema") != 1 or search.get("algorithm") != ALGORITHM)

static func location(value: Variant, body_id: String) -> bool:
	return Cube.valid(value, body_id) and absf(float(value.height)) <= 20000.0

## Canonical decimal grid survives Godot JSON's decimal parsing roundoff.
## 1e-12 face units are at most 1 mm even at the supported 1e9 m radius.
static func canonical(point: Dictionary) -> Dictionary:
	var result: Dictionary = point.duplicate(true)
	result.face = int(result.face)
	result.u = round(float(result.u) * 1e12) / 1e12
	result.v = round(float(result.v) * 1e12) / 1e12
	result.height = round(float(result.height) * 1e6) / 1e6
	return result

static func grid_key(x: int, z: int) -> String:
	return "%d:%d" % [x, z]

static func region_id(body_id: String, point: Dictionary) -> String:
	return Ids.scoped("region", body_id, "sphere1:%d:%d:%d" % [int(point.face), floori(float(point.u) * 4096.0), floori(float(point.v) * 4096.0)])

static func object_id(habitat: Dictionary) -> String:
	return Ids.scoped("object", habitat.region_id, "habitat:d1:" + str(habitat.key) + ":" + str(int(habitat.generation)))

static func distance(a: Dictionary, b: Dictionary, radius: float) -> float:
	return Cube.local_position(Cube.cartesian(a, radius), Cube.cartesian(b, radius)).length()

static func validate(catalog: Dictionary, body: Dictionary, identities: Array) -> String:
	var id: String = body.id
	var surface: Dictionary = catalog.surface
	if body.get("surface_mode") != Cube.MODE or body.get("surface_generation") != GENERATION \
		or not Values.number(surface.get("radius"), 1000.0, 1e9) or surface.radius != body.get("radius") \
		or not Values.integer(surface.get("terrain_revision"), 1, 100000) or surface.terrain_revision != body.get("terrain_revision") \
		or not location(surface.get("anchor"), id): return "Invalid spherical surface identity."
	if catalog.has("habitat_recovery"): return "Legacy recovery cannot describe spherical habitats."
	var keys: Array = []
	var represented: Array = []
	for habitat in catalog.habitats:
		if not habitat is Dictionary or habitat.get("species_id") not in identities or not habitat.get("key") is String \
			or not habitat.key.begins_with("surface1:") or habitat.key in keys: return "Invalid spherical habitat identity."
		if not location(habitat.get("position"), id) or not location(habitat.get("food_position"), id) \
			or not habitat.get("path") is Array or habitat.path.size() < 2 or habitat.path.size() > MAX_PATH: return "Invalid spherical habitat route."
		if habitat.path[0] != surface.anchor or habitat.path[-1] != habitat.position: return "Spherical route endpoints disagree."
		var previous: Dictionary = habitat.path[0]
		for point in habitat.path:
			if not location(point, id) or distance(previous, point, surface.radius) > 8.0: return "Invalid spherical route edge."
			previous = point
		if distance(surface.anchor, habitat.position, surface.radius) > RADIUS + 1.0 \
			or distance(habitat.position, habitat.food_position, surface.radius) > 10.0: return "Spherical habitat exceeds search bounds."
		if habitat.has("spawn_position") and (not location(habitat.spawn_position, id) or distance(habitat.position, habitat.spawn_position, surface.radius) > 8.0): return "Invalid spherical spawn position."
		if habitat.get("region_id") != region_id(id, habitat.position) or not Values.integer(habitat.get("generation"), 0, 1000000000) \
			or not Values.number(habitat.get("replacement_at"), 0, 1e15): return "Invalid spherical habitat lifecycle."
		if habitat.get("travel_mode") != "walk" or habitat.get("food") != "plant" or habitat.get("water_supply") != "requires_transport" \
			or habitat.get("freshwater_distance") != -1: return "Unsupported spherical habitat resources."
		if habitat.has("food_state"):
			var food: Variant = habitat.food_state
			if not food is Dictionary or food.get("schema") != 1 or not Values.number(food.get("remaining"), 0, 30) or not Values.number(food.get("regrow_remaining"), 0, 180): return "Invalid spherical food state."
		keys.append(habitat.key)
		if habitat.species_id not in represented: represented.append(habitat.species_id)
	if catalog.get("habitat_status") not in ["pending", "ready", "unavailable"] or (catalog.habitat_status == "ready" and represented.size() != 3): return "Incomplete spherical habitats."
	if catalog.has("surface_search"): return validate_search(catalog.surface_search, surface, id)
	return ""

static func validate_search(search: Dictionary, surface: Dictionary, id: String) -> String:
	if search.get("status") not in ["searching", "ready", "blocked"] or not search.get("nodes") is Array \
		or search.nodes.is_empty() or search.nodes.size() > MAX_NODES \
		or not Values.integer(search.get("head"), 0, search.nodes.size()) or not Values.integer(search.get("direction"), 0, 7): return "Invalid spherical search cursor."
	var cells: Dictionary = {}
	for index in range(search.nodes.size()):
		var node: Variant = search.nodes[index]
		if not node is Dictionary or not Values.integer(node.get("x"), -32, 32) or not Values.integer(node.get("z"), -32, 32) \
			or Vector2(node.x, node.z).length() * STEP > RADIUS or not location(node.get("location"), id) \
			or not Values.integer(node.get("parent"), -1 if index == 0 else 0, index - 1): return "Invalid spherical search node."
		var key: String = grid_key(int(node.x), int(node.z))
		if cells.has(key): return "Duplicate spherical search cell."
		cells[key] = true
		if index == 0:
			if node.x != 0 or node.z != 0 or node.location != surface.anchor: return "Spherical search anchor changed."
		else:
			var parent: Dictionary = search.nodes[int(node.parent)]
			if Vector2i(int(node.x - parent.x), int(node.z - parent.z)) not in DIRECTIONS \
				or distance(node.location, parent.location, surface.radius) > 8.0: return "Invalid spherical search connection."
	return ""
