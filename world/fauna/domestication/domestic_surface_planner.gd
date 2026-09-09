extends RefCounted
const Contract = preload("res://world/fauna/domestication/domestic_surface_contract.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var data: Dictionary = {}
var visited: Dictionary = {}
var surface: RefCounted
var anchor: Dictionary
var frame: Basis

func begin(source: RefCounted, catalog: Dictionary) -> void:
	surface = source
	anchor = Contract.canonical(catalog.surface.anchor)
	catalog.surface.anchor = anchor
	frame = Cube.frame(Cube.vector(Cube.direction(anchor.face, anchor.u, anchor.v)))
	if not catalog.has("surface_search"):
		catalog.surface_search = {"schema": 1, "algorithm": Contract.ALGORITHM, "status": "searching",
			"nodes": [{"x": 0, "z": 0, "parent": -1, "location": anchor.duplicate(true)}], "head": 0, "direction": 0}
	data = catalog.surface_search
	visited.clear()
	for node: Dictionary in data.nodes:
		node.location = Contract.canonical(node.location)
		visited[Contract.grid_key(int(node.x), int(node.z))] = true
	if not dry(surface, anchor): _finish(catalog, false)

func step(catalog: Dictionary, edges: int = 16, budget_usec: int = 2000) -> void:
	var started: int = Time.get_ticks_usec()
	for edge in range(edges):
		if data.status != "searching": return
		if edge > 0 and budget_usec > 0 and Time.get_ticks_usec() - started >= budget_usec: return
		if int(data.head) >= data.nodes.size() or data.nodes.size() >= Contract.MAX_NODES:
			_finish(catalog, false)
			return
		var parent_index: int = int(data.head)
		var parent: Dictionary = data.nodes[parent_index]
		var direction: Vector2i = Contract.DIRECTIONS[int(data.direction)]
		data.direction = (int(data.direction) + 1) % 8
		if data.direction == 0: data.head = int(data.head) + 1
		var cell := Vector2i(int(parent.x), int(parent.z)) + direction
		var key: String = Contract.grid_key(cell.x, cell.y)
		if visited.has(key) or Vector2(cell).length() * Contract.STEP > Contract.RADIUS: continue
		var point: Dictionary = offset(surface, anchor, frame.x * cell.x * Contract.STEP + frame.z * cell.y * Contract.STEP)
		if path(surface, parent.location, point).is_empty(): continue
		visited[key] = true
		data.nodes.append({"x": cell.x, "z": cell.y, "parent": parent_index, "location": point})
		if _candidate(catalog, data.nodes.size() - 1):
			_finish(catalog, true)
			return

func _candidate(catalog: Dictionary, index: int) -> bool:
	var node: Dictionary = data.nodes[index]
	if Contract.distance(anchor, node.location, surface.body.radius) < 12.0: return false
	var represented: Array = []
	for habitat: Dictionary in catalog.habitats:
		represented.append(habitat.species_id)
		if Contract.distance(habitat.position, node.location, surface.body.radius) < 10.0: return false
	var species_id: String = ""
	for entry: Dictionary in catalog.species:
		if entry.id not in represented:
			species_id = entry.id
			break
	if species_id.is_empty(): return true
	var food: Dictionary = {}
	for direction: Vector2i in Contract.DIRECTIONS:
		var candidate: Dictionary = offset(surface, node.location, frame.x * direction.x * 4.0 + frame.z * direction.y * 4.0)
		if not path(surface, node.location, candidate).is_empty():
			food = candidate
			break
	if food.is_empty(): return false
	var route: Array = []
	var cursor: int = index
	while cursor >= 0:
		route.push_front(data.nodes[cursor].location.duplicate(true))
		cursor = int(data.nodes[cursor].parent)
		if route.size() > Contract.MAX_PATH: return false
	catalog.habitats.append({"key": "surface1:" + Contract.grid_key(int(node.x), int(node.z)), "species_id": species_id,
		"region_id": Contract.region_id(catalog.body_id, node.location), "generation": 0, "replacement_at": 0.0,
		"position": node.location.duplicate(true), "path": route, "travel_mode": "walk", "food": "plant",
		"food_position": food, "water_supply": "requires_transport", "freshwater_distance": -1.0})
	return catalog.habitats.size() >= 3

func _finish(catalog: Dictionary, ready: bool) -> void:
	data.status = "ready" if ready else "blocked"
	catalog.habitat_status = "ready" if ready else "unavailable"

static func offset(source: RefCounted, origin: Dictionary, tangent: Vector3) -> Dictionary:
	var up: Vector3 = Cube.vector(Cube.direction(origin.face, origin.u, origin.v))
	var delta: Vector3 = tangent.slide(up)
	var point: Array = Cube.cartesian(origin, source.body.radius)
	var result: Dictionary = Cube.from_cartesian(source.body.id, [point[0] + delta.x, point[1] + delta.y, point[2] + delta.z], source.body.radius)
	result.height = source.sample(result).height
	return Contract.canonical(result)

static func dry(source: RefCounted, point: Dictionary) -> bool:
	var sample: Dictionary = source.sample(point)
	var up: Vector3 = Cube.vector(Cube.direction(point.face, point.u, point.v))
	return not sample.water and not sample.get("blocked", false) and sample.height >= sample.water_level + 0.5 \
		and sample.normal.dot(up) >= 0.94

static func path(source: RefCounted, start: Dictionary, end: Dictionary) -> Array:
	var a: Array = Cube.cartesian(start, source.body.radius)
	var b: Array = Cube.cartesian(end, source.body.radius)
	var length: float = Cube.local_position(b, a).length()
	if length > 8.0 or not dry(source, start): return []
	var count: int = maxi(1, ceili(length / 2.0))
	var result: Array = [start.duplicate(true)]
	var previous: Dictionary = start
	for index in range(1, count + 1):
		var t: float = float(index) / count
		var point: Dictionary = Cube.from_cartesian(source.body.id, [lerpf(a[0], b[0], t), lerpf(a[1], b[1], t), lerpf(a[2], b[2], t)], source.body.radius)
		point.height = source.sample(point).height
		if not dry(source, point) or absf(float(point.height) - float(previous.height)) > length / count * 0.35 + 0.15: return []
		result.append(point)
		previous = point
	return result
