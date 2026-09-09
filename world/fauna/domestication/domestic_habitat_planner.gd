extends RefCounted
## Deterministic terrain routes. Loaded scenery clearance is checked by spawner.
const Ids = preload("res://core/campaign/campaign_ids.gd")
const CANDIDATES: int = 1024
const TARGET: int = 12
var cursor: int = 0
var origin := Vector3.ZERO
var habitats: Array = []
var finished: bool = false

func begin(generator: Node) -> void:
	origin = generator.get_scenic_spawn()
	origin.y = generator.get_visual_terrain_height(origin.x, origin.z)

func step(generator: Node, catalog: Dictionary, budget: int = 4) -> void:
	for unused in range(budget):
		if (cursor >= CANDIDATES + 256 or (cursor >= CANDIDATES and habitats.is_empty())) or habitats.size() >= TARGET:
			finished = true
			return
		var index: int = cursor
		cursor += 1
		var angle: float = float(index % 32) * TAU / 32.0 + float(posmod(int(catalog["seed"]), 31)) * 0.1
		var radius: float = 20.0 + float(index / 32) * 8.0
		var route_origin: Vector3 = origin
		var prefix: Array = []
		var inherited_mode: String = "walk"
		if index >= CANDIDATES:
			var base: Dictionary = habitats[mini(habitats.size() - 1, (index - CANDIDATES) / 64)]
			var start: Array = base["position"]
			route_origin = Vector3(start[0], start[1], start[2])
			prefix = base["path"].slice(0, base["path"].size() - 1)
			inherited_mode = base["travel_mode"]
			radius = 8.0 + float((index - CANDIDATES) / 32 % 2) * 8.0
		var point: Vector3 = route_origin + Vector3(cos(angle), 0, sin(angle)) * radius
		point.y = generator.get_visual_terrain_height(point.x, point.z)
		var crowded: bool = false
		for existing: Dictionary in habitats:
			var p: Array = existing["position"]
			if point.distance_to(Vector3(p[0], p[1], p[2])) < 7.0:
				crowded = true
		if crowded or not dry(generator, point): continue
		var biome: int = generator.get_biome(point.x, point.z, generator.get_terrain_height(point.x, point.z))
		if biome in [generator.Biome.OCEAN, generator.Biome.LAKE, generator.Biome.RIVER]: continue
		var path: Array = land_path(generator, route_origin, point)
		var travel_mode: String = inherited_mode
		if path.is_empty():
			path = surface_path(generator, route_origin, point)
			travel_mode = "swim_walk"
		if path.is_empty(): continue
		path = prefix + path
		if path.size() > 512: continue
		var species: Dictionary = catalog["species"][habitats.size() % 3]
		var coordinates := Vector2i(floori(point.x / 256.0), floori(point.z / 256.0))
		var water: Dictionary = generator.get_water_info(point.x, point.z)
		var fresh: bool = water.get("kind", "") in ["river", "lake"]
		habitats.append({"key": "%d" % index, "species_id": species["id"],
			"region_id": Ids.scoped("region", catalog["body_id"], "legacy:%d:%d" % [coordinates.x, coordinates.y]),
			"position": [point.x, point.y, point.z], "path": path,
			"travel_mode": travel_mode, "biome": biome, "food": "plant", "freshwater_distance": maxf(0.0, float(water.get("distance", 0.0))) if fresh else -1.0,
			"water_supply": "nearby_freshwater" if fresh and float(water.get("distance", 999.0)) < 16.0 else "requires_transport",
			"generation": 0, "replacement_at": 0.0})

static func dry(generator: Node, point: Vector3) -> bool:
	return generator.get_terrain_height(point.x, point.z) > generator.get_water_level(point.x, point.z) + 0.5 and generator.get_terrain_slope(point.x, point.z, 0.75) <= 0.38

static func land_path(generator: Node, from: Vector3, to: Vector3) -> Array:
	var path: Array = []
	var direction: Vector3 = (to - from).normalized()
	var side := Vector3(-direction.z, 0, direction.x) * 0.8
	var previous: Vector3 = from
	var count: int = maxi(1, ceili(Vector2(to.x - from.x, to.z - from.z).length()))
	for i in range(count + 1):
		var p: Vector3 = from.lerp(to, float(i) / count)
		p.y = generator.get_visual_terrain_height(p.x, p.z)
		if not dry(generator, p) or not dry(generator, p + side) or not dry(generator, p - side): return []
		if i > 0 and absf(p.y - previous.y) > 0.45: return []
		path.append([p.x, p.y, p.z])
		previous = p
	return path

## Players already swim. Island starts may reach a dry habitat across water;
## animals themselves always spawn and navigate on dry ground.
static func surface_path(generator: Node, from: Vector3, to: Vector3) -> Array:
	var path: Array = []
	var previous: Vector3 = from
	var water_metres: int = 0
	var count: int = maxi(1, ceili(Vector2(to.x - from.x, to.z - from.z).length()))
	for i in range(count + 1):
		var p: Vector3 = from.lerp(to, float(i) / count)
		var land: float = generator.get_visual_terrain_height(p.x, p.z)
		var water: float = generator.get_water_level(p.x, p.z)
		p.y = maxf(land, water)
		if land < water: water_metres += 1
		elif generator.get_terrain_slope(p.x, p.z, 0.75) > 0.5: return []
		if i > 0 and absf(p.y - previous.y) > 0.5: return []
		path.append([p.x, p.y, p.z])
		previous = p
	return path if water_metres <= 192 else []
