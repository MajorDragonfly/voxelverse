extends RefCounted
## ARCH-27: bounded, directed connections between certified local gateways.
## Does not certify terrain, discover routes, own stocks or load regions.
const Home = preload("res://world/home_group/home_group_state.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
const SCHEMA: int = 1
const MAX_NODES: int = 128
const MAX_EDGES: int = 256
const MAX_LEGS: int = 64
const MAX_DURATION: float = 86400.0

static func fields(value: Variant, names: Array) -> bool:
	if not value is Dictionary or value.size() != names.size(): return false
	for name: String in names:
		if not value.has(name): return false
	return true

static func identity(value: Variant, empty: bool = false) -> bool:
	return value is String and value.length() <= 160 and (empty or not value.is_empty()) and value.strip_edges() == value and not "\n" in value

static func node_valid(value: Variant, body_id: String) -> bool:
	if not fields(value, ["id", "region_id", "settlement_id", "faction_id", "place"]): return false
	for field: String in ["id", "region_id", "settlement_id", "faction_id"]:
		if not identity(value[field], field == "settlement_id"): return false
	if not fields(value.place, ["mode", "body_id", "face", "u", "v", "height", "radius"]): return false
	if not value.place.mode is String or not value.place.body_id is String or not Economy.integer(value.place.face, 0, 5): return false
	return Home.place_valid(value.place, Home.Cube.MODE, body_id)

static func edge_valid(value: Variant) -> bool:
	if not fields(value, ["id", "from", "to", "mode", "seconds", "capacity", "revision", "blocked"]): return false
	for field: String in ["id", "from", "to"]:
		if not identity(value[field]): return false
	return value.from != value.to and value.mode is String and value.mode == "foot" and Economy.number(value.seconds, 0.01, MAX_DURATION) and Economy.integer(value.capacity, 1, 48) and Economy.integer(value.revision, 1, 1000000000) and value.blocked is bool

static func validate(value: Variant) -> String:
	if not fields(value, ["schema", "id", "body_id", "nodes", "edges"]): return "routes.fields"
	if not Economy.integer(value.schema, SCHEMA, SCHEMA): return "routes.schema"
	if not identity(value.id) or not identity(value.body_id): return "routes.identity"
	if not value.nodes is Dictionary or not value.edges is Dictionary or value.nodes.size() > MAX_NODES or value.edges.size() > MAX_EDGES: return "routes.budget"
	for id: Variant in value.nodes:
		if not identity(id) or not node_valid(value.nodes[id], value.body_id) or value.nodes[id].id != id: return "routes.node"
	for id: Variant in value.edges:
		var edge: Variant = value.edges[id]
		if not identity(id) or not edge_valid(edge) or edge.id != id: return "routes.edge"
		if not value.nodes.has(edge.from) or not value.nodes.has(edge.to): return "routes.endpoint"
		if value.nodes[edge.from].place.radius != value.nodes[edge.to].place.radius: return "routes.radius"
	return ""

static func plan(graph: Dictionary, source: String, target: String, amount: int = 1) -> Dictionary:
	var problem: String = validate(graph)
	if not problem.is_empty(): return {"ok": false, "code": problem}
	if not graph.nodes.has(source) or not graph.nodes.has(target) or amount < 1 or amount > 48: return {"ok": false, "code": "routes.request"}
	if source == target:
		return {"ok": true, "code": "", "route": {"schema": SCHEMA, "graph_id": graph.id, "body_id": graph.body_id, "nodes": [graph.nodes[source].duplicate(true)], "legs": []}}
	# Deterministic Dijkstra; strict network bounds limit both memory and work.
	var todo: Array = graph.nodes.keys()
	todo.sort()
	var edge_ids: Array = graph.edges.keys()
	edge_ids.sort()
	var distance: Dictionary = {source: 0.0}
	var previous: Dictionary = {}
	while not todo.is_empty():
		var current: String = ""
		var best: float = INF
		for id: String in todo:
			if float(distance.get(id, INF)) < best:
				current = id
				best = distance[id]
		if current.is_empty(): break
		todo.erase(current)
		if current == target: break
		for id: String in edge_ids:
			var edge: Dictionary = graph.edges[id]
			if edge.from != current or edge.blocked or edge.capacity < amount or not edge.to in todo: continue
			var candidate: float = best + float(edge.seconds)
			if candidate < float(distance.get(edge.to, INF)):
				distance[edge.to] = candidate
				previous[edge.to] = id
	if not previous.has(target): return {"ok": false, "code": "routes.unreachable"}
	var cursor: String = target
	var legs: Array = []
	var nodes: Array = [graph.nodes[target].duplicate(true)]
	while cursor != source:
		if legs.size() >= MAX_LEGS: return {"ok": false, "code": "routes.leg_budget"}
		var edge: Dictionary = graph.edges[previous[cursor]]
		legs.push_front(edge.duplicate(true))
		cursor = edge.from
		nodes.push_front(graph.nodes[cursor].duplicate(true))
	return {"ok": true, "code": "", "route": {"schema": SCHEMA, "graph_id": graph.id, "body_id": graph.body_id, "nodes": nodes, "legs": legs}}

static func validate_route(value: Variant, amount: int = 1) -> String:
	if not fields(value, ["schema", "graph_id", "body_id", "nodes", "legs"]): return "route.fields"
	if not Economy.integer(value.schema, SCHEMA, SCHEMA): return "route.schema"
	if not identity(value.graph_id) or not identity(value.body_id): return "route.identity"
	if not value.nodes is Array or not value.legs is Array or value.legs.size() > MAX_LEGS or value.nodes.size() != value.legs.size() + 1: return "route.budget"
	var seen: Dictionary = {}
	for node: Variant in value.nodes:
		if not node_valid(node, value.body_id) or seen.has(node.id): return "route.node"
		seen[node.id] = true
	for i: int in value.legs.size():
		var edge: Variant = value.legs[i]
		if not edge_valid(edge) or edge.blocked or edge.capacity < amount: return "route.edge"
		if edge.from != value.nodes[i].id or edge.to != value.nodes[i + 1].id or value.nodes[i].place.radius != value.nodes[i + 1].place.radius: return "route.disconnected"
	return ""

static func availability(route: Dictionary, index: int, graph: Dictionary) -> String:
	# A missing/evicted network suspends work. The saved route is not permission
	# to assume a region is still traversable after an obstacle change.
	var problem: String = validate(graph)
	if not problem.is_empty(): return "route.network_unavailable"
	if graph.id != route.graph_id or graph.body_id != route.body_id: return "route.network_mismatch"
	var saved: Dictionary = route.legs[index]
	var edge: Dictionary = graph.edges.get(saved.id, {})
	if edge.is_empty(): return "route.connection_missing"
	if edge.blocked: return "route.blocked"
	if edge != saved: return "route.recertification_required"
	for i: int in [index, index + 1]:
		var node: Dictionary = route.nodes[i]
		if graph.nodes.get(node.id, {}) != node: return "route.endpoint_changed"
	return ""
