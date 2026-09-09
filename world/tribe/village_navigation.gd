extends RefCounted
## Small ground-tested graph for the initial village. Never navigates unloaded
## chunks or crosses water/steep ledges. Runtime-only; orders survive rebuilding.
const Housing = preload("res://world/tribe/village_housing.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
var shelters: Array = []
const RADIUS: int = 12
var graph := AStar3D.new()
var origin := Vector3.ZERO
var home: Node

func rebuild(controller: Node, anchor: Vector3, data: Dictionary = {}) -> void:
	shelters = Housing.obstacles(data)
	home = controller
	origin = anchor
	graph.clear()
	for z in range(-RADIUS, RADIUS + 1):
		for x in range(-RADIUS, RADIUS + 1):
			if _occupied(anchor + Vector3(x, 0, z)):
				continue
			var ray := PhysicsRayQueryParameters3D.create(anchor + Vector3(x, 4, z), anchor + Vector3(x, -4, z), 1)
			ray.exclude = [home.player.get_rid()]
			var hit: Dictionary = home.player.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or hit["normal"].dot(Vector3.UP) < 0.9 or not home._dry(hit["position"]):
				continue
			var position: Vector3 = hit["position"] + Vector3.UP * 0.06
			if not home._clear_space(position + Vector3.UP * 0.72):
				continue
			graph.add_point(_id(x, z), position)
	for z in range(-RADIUS, RADIUS + 1):
		for x in range(-RADIUS, RADIUS + 1):
			var id: int = _id(x, z)
			if not graph.has_point(id):
				continue
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if x + offset.x > RADIUS or z + offset.y > RADIUS:
					continue
				var other: int = _id(x + offset.x, z + offset.y)
				if graph.has_point(other) and absf(graph.get_point_position(id).y - graph.get_point_position(other).y) <= 0.5:
					# Midpoint clearance catches tree trunks between grid samples.
					var middle: Vector3 = graph.get_point_position(id).lerp(graph.get_point_position(other), 0.5)
					var floor_hit: Dictionary = home._floor_hit(middle)
					if floor_hit.is_empty():
						continue
					# Stairs are discontinuous. The averaged endpoint height can
					# put a standing capsule inside the higher tread; use its real floor.
					var floor_position: Vector3 = floor_hit["position"]
					if absf(floor_position.y - graph.get_point_position(id).y) <= 0.56 and absf(floor_position.y - graph.get_point_position(other).y) <= 0.56 and home._clear_space(floor_position + Vector3.UP * 0.78):
						graph.connect_points(id, other)

func _id(x: int, z: int) -> int:
	return (z + RADIUS) * (RADIUS * 2 + 1) + x + RADIUS

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	if graph.get_point_count() == 0:
		return PackedVector3Array()
	if _occupied(to):
		return PackedVector3Array()
	var prefix := PackedVector3Array()
	for shelter: Dictionary in shelters:
		if Housing.contains(shelter, from):
			# Legacy decorative huts could contain a saved resident. Leave by the door.
			from = Home.vector(shelter["entrance"])
			prefix.append(from)
	var first: int = graph.get_closest_point(from)
	var last: int = graph.get_closest_point(to)
	if graph.get_point_position(first).distance_to(from) > 1.8 or graph.get_point_position(last).distance_to(to) > 1.8:
		return PackedVector3Array()
	var path: PackedVector3Array = graph.get_point_path(first, last)
	if path.is_empty():
		return path
	prefix.append_array(path)
	return prefix

func snap(position: Vector3) -> Vector3:
	return graph.get_point_position(graph.get_closest_point(position)) if graph.get_point_count() > 0 else Vector3.INF

func sites() -> Dictionary:
	var result: Dictionary = {"huts": []}
	var used: Array[Vector3] = [origin]
	var offsets: Dictionary = {"wood": Vector3(-5, 0, -4), "stone": Vector3(5, 0, -4), "food": Vector3(-5, 0, 4), "hut0": Vector3(5, 0, 4), "hut1": Vector3(8, 0, 0)}
	for kind: String in offsets:
		var best := Vector3.INF
		var distance: float = INF
		for id: int in graph.get_point_ids():
			var point: Vector3 = graph.get_point_position(id)
			if point.distance_to(origin + offsets[kind]) >= distance:
				continue
			var clear: bool = true
			if kind.begins_with("hut"):
				# A hut needs a complete level footprint, not a single safe ray.
				for corner: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
					var floor_point: Vector3 = snap(point + corner)
					if floor_point.distance_to(point + corner) > 0.45 or route(point, floor_point).is_empty():
						clear = false
			for previous: Vector3 in used:
				if point.distance_to(previous) < 3.0:
					clear = false
			if not clear or route(origin, point).is_empty():
				continue
			best = point
			distance = point.distance_to(origin + offsets[kind])
		if not best.is_finite():
			return {}
		used.append(best)
		if kind.begins_with("hut"):
			result["huts"].append([best.x, best.y, best.z])
		else:
			result[kind] = [best.x, best.y, best.z]
	return result

func free_workplace(position: Vector3, data: Dictionary, kind: String) -> bool:
	if not position.is_finite() or position.distance_to(origin) > 16.0 or position.distance_to(origin) < 3.0 or route(origin, position).is_empty():
		return false
	for corner: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		var floor_point: Vector3 = snap(position + corner)
		if floor_point.distance_to(position + corner) > 0.45 or route(position, floor_point).is_empty():
			return false
	for shelter: Dictionary in Housing.obstacles(data) + data.get("husbandry", {}).get("pens", []):
		if position.distance_to(Home.vector(shelter["position"])) < 4.0 or position.distance_to(Home.vector(shelter["entrance"])) < 2.5:
			return false
	for resource: String in data["deposits"]:
		# Upgrading an old source in place is allowed; other sources keep room.
		if resource == {"well": "water", "forester": "wood", "quarry": "stone", "fiberbed": "fiber"}.get(kind):
			continue
		var site: Array = data["deposits"][resource]["position"]
		if position.distance_to(Vector3(site[0], site[1], site[2])) < 3.0:
			return false
	return true

func _occupied(position: Vector3) -> bool:
	for shelter: Dictionary in shelters:
		if Housing.contains(shelter, position):
			return true
	return false

func free_shelter(position: Vector3, data: Dictionary, kind: String) -> bool:
	if not free_workplace(position, data, kind):
		return false
	var candidate: Dictionary = Housing.site(data, kind, Home.vector_array(position), data["housing"]["homes"].size())
	var entrance: Vector3 = Home.vector(candidate["entrance"])
	if snap(entrance).distance_to(entrance) > 0.45:
		return false
	for member: Dictionary in data["members"]:
		if Housing.contains(candidate, Home.vector(member["position"])):
			return false
	# Reserve the full footprint before charging. It must not sever any route
	# from a resident, existing source, entrance or accepted D3 pickup to storage.
	var disabled: Array[int] = []
	for id: int in graph.get_point_ids():
		if Housing.contains(candidate, graph.get_point_position(id)) and not graph.is_point_disabled(id):
			graph.set_point_disabled(id, true)
			disabled.append(id)
	shelters.append(candidate)
	var points: Array[Vector3] = [entrance]
	for member: Dictionary in data["members"]:
		points.append(Home.vector(member["position"]))
		if member["order"] == "move" or member["paused_order"] == "move":
			points.append(Home.vector(member["destination"]))
	for deposit: Dictionary in data["deposits"].values():
		points.append(Home.vector(deposit["position"]))
	for shelter: Dictionary in data["housing"]["homes"]:
		points.append(Home.vector(shelter["entrance"]))
	for p: Dictionary in data.get("husbandry", {}).get("pens", []):
		points.append(Home.vector(p["position"]))
		points.append(Home.vector(p["entrance"]))
	for record: Dictionary in data.get("husbandry", {}).get("records", {}).values():
		if int(record["pending_milk"]) > 0:
			points.append(Home.vector(record["pickup"]))
	for batch: Dictionary in data["economy"]["incoming"]:
		points.append(Home.vector(batch["position"]))
	var clear: bool = true
	for point: Vector3 in points:
		if route(origin, point).is_empty():
			clear = false
	for id: int in disabled:
		graph.set_point_disabled(id, false)
	shelters.pop_back()
	return clear
