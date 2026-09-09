extends RefCounted
## Saved breadth-first terrain search after the original radial planner fails.
const Contract = preload("res://world/fauna/domestication/domestication_contract.gd")
const Planner = preload("res://world/fauna/domestication/domestic_habitat_planner.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const SCHEMA: int = 1
const ALGORITHM: String = "domestic_habitat_recovery_v1"
const GRID: float = 4.0
const MAX_CELLS: int = 256 # 1,024 m from the deterministic landing point.
const MAX_NODES: int = 16384
const MAX_STEPS: int = 4095
const MAX_WATER: int = 192
const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]
var data: Dictionary = {}
var visited: Dictionary = {}

func begin(generator: Node, catalog: Dictionary) -> void:
	if not catalog.has("habitat_recovery"):
		var start: Vector3 = generator.get_scenic_spawn()
		start.y = maxf(generator.get_visual_terrain_height(start.x, start.z), generator.get_water_level(start.x, start.z))
		var prefix: Array = [array(start)]
		var mode: String = "walk"
		# A partial radial result is already reachable. Continue from that island
		# rather than searching the same narrow landing shore again.
		if not catalog["habitats"].is_empty():
			var anchor: Dictionary = catalog["habitats"][0]
			start = Vector3(anchor["position"][0], anchor["position"][1], anchor["position"][2])
			prefix = anchor["path"].duplicate(true)
			mode = anchor["travel_mode"]
		var water: int = water_steps(generator, prefix)
		catalog["habitat_recovery"] = {"schema": SCHEMA, "algorithm": ALGORITHM, "body_id": catalog["body_id"], "seed": int(catalog["seed"]),
			"origin": array(start), "prefix": prefix, "status": "searching" if water <= MAX_WATER else "blocked", "head": 0, "direction": 0,
			"nodes": [{"cell": [0, 0], "parent": -1, "steps": prefix.size() - 1, "water": water, "mode": mode}]}
	data = catalog["habitat_recovery"]
	visited.clear()
	for index in range(data["nodes"].size()): visited[cell_key(data["nodes"][index]["cell"])] = index

func step(generator: Node, catalog: Dictionary, budget: int = 2, max_usec: int = 0) -> void:
	if data.get("status") != "searching": return
	var started: int = Time.get_ticks_usec()
	for unused in range(budget):
		if unused > 0 and max_usec > 0 and Time.get_ticks_usec() - started >= max_usec: return
		if data["head"] >= data["nodes"].size() or data["nodes"].size() >= MAX_NODES:
			data["status"] = "blocked"
			return
		var parent_index: int = data["head"]
		var parent: Dictionary = data["nodes"][parent_index]
		var direction: Vector2i = DIRECTIONS[int(data["direction"])]
		data["direction"] = (int(data["direction"]) + 1) % DIRECTIONS.size()
		if data["direction"] == 0: data["head"] = parent_index + 1
		var cell: Array = [int(parent["cell"][0]) + direction.x, int(parent["cell"][1]) + direction.y]
		if abs(cell[0]) > MAX_CELLS or abs(cell[1]) > MAX_CELLS or visited.has(cell_key(cell)): continue
		var from: Vector3 = point(generator, parent["cell"])
		var to: Vector3 = point(generator, cell)
		var edge: Dictionary = route_edge(generator, from, to)
		if edge.is_empty(): continue
		var steps: int = int(parent["steps"]) + edge["path"].size() - 1
		var water: int = int(parent["water"]) + int(edge["water"])
		if steps > MAX_STEPS or water > MAX_WATER: continue
		var index: int = data["nodes"].size()
		data["nodes"].append({"cell": cell, "parent": parent_index, "steps": steps, "water": water,
			"mode": "swim_walk" if parent["mode"] == "swim_walk" or edge["mode"] == "swim_walk" else "walk"})
		visited[cell_key(cell)] = index
		_add_habitat(generator, catalog, index)
		if represented(catalog) == 3:
			data["status"] = "ready"
			catalog["habitat_status"] = "ready"
			return

func point(generator: Node, cell: Array) -> Vector3:
	var start: Array = data["origin"]
	var result := Vector3(float(start[0]) + int(cell[0]) * GRID, 0, float(start[2]) + int(cell[1]) * GRID)
	result.y = maxf(generator.get_visual_terrain_height(result.x, result.z), generator.get_water_level(result.x, result.z))
	return result

func _add_habitat(generator: Node, catalog: Dictionary, index: int) -> void:
	var node: Dictionary = data["nodes"][index]
	var position: Vector3 = point(generator, node["cell"])
	var start: Array = data["prefix"][0]
	if position.distance_to(Vector3(start[0], start[1], start[2])) < 20.0 or not Planner.dry(generator, position): return
	for habitat: Dictionary in catalog["habitats"]:
		var p: Array = habitat["position"]
		if position.distance_to(Vector3(p[0], p[1], p[2])) < 7.0: return
	var biome: int = generator.get_biome(position.x, position.z, generator.get_terrain_height(position.x, position.z))
	if biome in [generator.Biome.OCEAN, generator.Biome.LAKE, generator.Biome.RIVER]: return
	# A reachable food patch next to the animal, not only a single dry pixel.
	var food_patch: bool = false
	for direction: Vector2i in DIRECTIONS:
		var food: Vector3 = position + Vector3(direction.x, 0, direction.y).normalized() * 3.0
		food.y = generator.get_visual_terrain_height(food.x, food.z)
		if Planner.dry(generator, food) and not Planner.land_path(generator, position, food).is_empty():
			food_patch = true
			break
	if not food_patch: return
	var path: Array = route(generator, index)
	if path.is_empty(): return
	var counts: Dictionary = {}
	for species: Dictionary in catalog["species"]: counts[species["id"]] = 0
	for habitat: Dictionary in catalog["habitats"]: counts[habitat["species_id"]] += 1
	var chosen: String = catalog["species"][0]["id"]
	for species: Dictionary in catalog["species"]:
		if int(counts[species["id"]]) < int(counts[chosen]): chosen = species["id"]
	var region := Vector2i(floori(position.x / 256.0), floori(position.z / 256.0))
	var water: Dictionary = generator.get_water_info(position.x, position.z)
	var fresh: bool = water.get("kind", "") in ["river", "lake"]
	catalog["habitats"].append({"key": "recovery_v1:" + cell_key(node["cell"]), "species_id": chosen,
		"region_id": Ids.scoped("region", catalog["body_id"], "legacy:%d:%d" % [region.x, region.y]),
		"position": array(position), "path": path, "travel_mode": node["mode"], "biome": biome,
		"food": "plant", "freshwater_distance": maxf(0.0, float(water.get("distance", 0.0))) if fresh else -1.0,
		"water_supply": "nearby_freshwater" if fresh and float(water.get("distance", 999.0)) < 16.0 else "requires_transport",
		"generation": 0, "replacement_at": 0.0})

func route(generator: Node, index: int) -> Array:
	var chain: Array[int] = []
	while index >= 0:
		chain.push_front(index)
		index = int(data["nodes"][index]["parent"])
	var result: Array = data["prefix"].duplicate(true)
	for i in range(1, chain.size()):
		var from: Vector3 = point(generator, data["nodes"][chain[i - 1]]["cell"])
		var to: Vector3 = point(generator, data["nodes"][chain[i]]["cell"])
		var edge: Dictionary = route_edge(generator, from, to)
		if edge.is_empty(): return []
		result.append_array(edge["path"].slice(1))
	return result

static func route_edge(generator: Node, from: Vector3, to: Vector3) -> Dictionary:
	var path: Array = Planner.land_path(generator, from, to)
	if not path.is_empty(): return {"path": path, "water": 0, "mode": "walk"}
	path = Planner.surface_path(generator, from, to)
	if path.is_empty(): return {}
	return {"path": path, "water": water_steps(generator, path), "mode": "swim_walk"}

static func water_steps(generator: Node, path: Array) -> int:
	var water: int = 0
	for i in range(1, path.size()):
		var p: Array = path[i]
		if generator.get_visual_terrain_height(p[0], p[2]) < generator.get_water_level(p[0], p[2]): water += 1
	return water

static func represented(catalog: Dictionary) -> int:
	var found: Dictionary = {}
	for habitat: Dictionary in catalog["habitats"]: found[habitat["species_id"]] = true
	return found.size()

static func unsupported(value: Variant) -> bool:
	return value is Dictionary and (not Contract.integer(value.get("schema"), SCHEMA, SCHEMA) or value.get("algorithm") != ALGORITHM)

static func validate(value: Variant, catalog: Dictionary) -> String:
	if not value is Dictionary or unsupported(value): return "Unsupported habitat recovery."
	if value.get("body_id") != catalog["body_id"] or not Contract.integer(value.get("seed"), int(catalog["seed"]), int(catalog["seed"])) or not vector(value.get("origin")):
		return "Habitat recovery belongs to another body."
	if not value.get("prefix") is Array or value["prefix"].is_empty() or value["prefix"].size() > MAX_STEPS + 1: return "Invalid habitat recovery prefix."
	for p in value["prefix"]:
		if not vector(p): return "Invalid habitat recovery prefix point."
	for axis in range(3):
		if float(value["prefix"].back()[axis]) != float(value["origin"][axis]): return "Disconnected habitat recovery prefix."
	var nodes: Variant = value.get("nodes")
	if not nodes is Array or nodes.is_empty() or nodes.size() > MAX_NODES or not Contract.integer(value.get("head"), 0, nodes.size()) or not Contract.integer(value.get("direction"), 0, 7) or value.get("status") not in ["searching", "ready", "blocked"]:
		return "Invalid habitat recovery progress."
	if (value["status"] == "ready") != (catalog.get("habitat_status") == "ready"):
		return "Habitat recovery and catalog readiness disagree."
	var cells: Dictionary = {}
	for index in range(nodes.size()):
		var node: Variant = nodes[index]
		if not node is Dictionary or not node.get("cell") is Array or node["cell"].size() != 2 or not Contract.integer(node["cell"][0], -MAX_CELLS, MAX_CELLS) or not Contract.integer(node["cell"][1], -MAX_CELLS, MAX_CELLS) or not Contract.integer(node.get("parent"), -1 if index == 0 else 0, index - 1) or not Contract.integer(node.get("steps"), 0, MAX_STEPS) or not Contract.integer(node.get("water"), 0, MAX_STEPS if index == 0 and value["status"] == "blocked" else MAX_WATER) or node.get("mode") not in ["walk", "swim_walk"]:
			return "Invalid habitat recovery node."
		var key: String = cell_key(node["cell"])
		if cells.has(key): return "Duplicate habitat recovery cell."
		cells[key] = true
		if index == 0:
			if key != "0:0" or node["steps"] != value["prefix"].size() - 1 or node["water"] > node["steps"]: return "Invalid habitat recovery root."
		else:
			var parent: Dictionary = nodes[int(node["parent"])]
			var dx: int = absi(int(node["cell"][0]) - int(parent["cell"][0]))
			var dz: int = absi(int(node["cell"][1]) - int(parent["cell"][1]))
			# Recreate float32 terrain coordinates, including rounding at large origins.
			var from := Vector2(float(value["origin"][0]) + int(parent["cell"][0]) * GRID, float(value["origin"][2]) + int(parent["cell"][1]) * GRID)
			var to := Vector2(float(value["origin"][0]) + int(node["cell"][0]) * GRID, float(value["origin"][2]) + int(node["cell"][1]) * GRID)
			var steps: int = ceili(from.distance_to(to))
			if dx > 1 or dz > 1 or dx + dz == 0 or int(node["steps"]) != int(parent["steps"]) + steps or node["water"] < parent["water"] or int(node["water"]) > int(parent["water"]) + steps:
				return "Broken habitat recovery edge."
	return ""

static func array(point_value: Vector3) -> Array:
	return [point_value.x, point_value.y, point_value.z]
static func cell_key(cell: Array) -> String:
	return "%d:%d" % [int(cell[0]), int(cell[1])]
static func vector(value: Variant) -> bool:
	return value is Array and value.size() == 3 and Contract.number(value[0], -1e9, 1e9) and Contract.number(value[1], -1e6, 1e6) and Contract.number(value[2], -1e9, 1e9)
