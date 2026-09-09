extends RefCounted
## Small ground-tested graph for the initial village. Never navigates unloaded
## chunks or crosses water/steep ledges. Runtime-only; orders survive rebuilding.
const RADIUS: int = 12
var graph := AStar3D.new()
var origin := Vector3.ZERO
var home: Node

func rebuild(controller: Node, anchor: Vector3) -> void:
	home = controller
	origin = anchor
	graph.clear()
	for z in range(-RADIUS, RADIUS + 1):
		for x in range(-RADIUS, RADIUS + 1):
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
	var first: int = graph.get_closest_point(from)
	var last: int = graph.get_closest_point(to)
	if graph.get_point_position(first).distance_to(from) > 1.8 or graph.get_point_position(last).distance_to(to) > 1.8:
		return PackedVector3Array()
	return graph.get_point_path(first, last)

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
