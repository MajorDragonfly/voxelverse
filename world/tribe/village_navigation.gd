extends RefCounted
## Small ground-tested graph for the initial village. Never navigates unloaded
## chunks or crosses water/steep ledges. Runtime-only; orders survive rebuilding.
const Housing = preload("res://world/tribe/village_housing.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
var shelters: Array = []
const RADIUS: int = 12
var _radius: int = RADIUS
var _samples: int = RADIUS
var _spacing: float = 1.0
var graph := AStar3D.new()
var origin := Vector3.ZERO
var home: Node

const MAX_CELLS_PER_SLICE: int = 128
const SLICE_USECS: int = 2000
var pending: bool = false
var generation: int = 0
var completed_generation: int = -1
var last_slice_cells: int = 0
var _cursor: int = 0
var _phase: int = 0
var _body_id: String = ""

func begin(controller: Node, anchor: Vector3, data: Dictionary = {}, extent: int = RADIUS) -> int:
	cancel()
	shelters = Housing.obstacles(data)
	home = controller
	origin = anchor
	_radius = clampi(extent, RADIUS, 20)
	_spacing = 0.5 if _radius > RADIUS else 1.0
	_samples = roundi(float(_radius) / _spacing)
	var state: Node = home.get_node_or_null("/root/GameState")
	_body_id = state.active_body_id if state != null else ""
	pending = true
	return generation

func cancel() -> void:
	generation += 1
	pending = false
	_cursor = 0
	_phase = 0
	graph.clear()

func advance(max_cells: int = MAX_CELLS_PER_SLICE, usecs: int = SLICE_USECS) -> bool:
	last_slice_cells = 0
	if not pending: return completed_generation == generation
	if not is_instance_valid(home) or not is_instance_valid(home.player):
		cancel()
		return false
	var state: Node = home.get_node_or_null("/root/GameState")
	if state != null and state.active_body_id != _body_id:
		cancel()
		return false
	var started: int = Time.get_ticks_usec()
	var width: int = _samples * 2 + 1
	while pending and last_slice_cells < clampi(max_cells, 1, MAX_CELLS_PER_SLICE):
		var x: int = _cursor % width - _samples
		var z: int = _cursor / width - _samples
		if _phase == 0: _sample_point(x, z)
		else: _connect_point(x, z)
		_cursor += 1
		last_slice_cells += 1
		if _cursor == width * width:
			_cursor = 0
			_phase += 1
			if _phase == 2:
				pending = false
				completed_generation = generation
		if Time.get_ticks_usec() - started >= maxi(1, usecs): break
	return not pending

## Explicit synchronous adapter for preflight/contract tools. Scene ticks call
## begin/advance and cannot consume a partially built or stale graph.
func rebuild(controller: Node, anchor: Vector3, data: Dictionary = {}, extent: int = RADIUS) -> void:
	begin(controller, anchor, data, extent)
	while pending: advance()

func _sample_point(x: int, z: int) -> void:
	if _occupied(Space.offset(home, origin, Vector3(x * _spacing, 0, z * _spacing))):
		return
	var ray := PhysicsRayQueryParameters3D.create(Space.offset(home, origin, Vector3(x * _spacing, 4, z * _spacing)), Space.offset(home, origin, Vector3(x * _spacing, -4, z * _spacing)), 1)
	ray.exclude = [home.player.get_rid()]
	var hit: Dictionary = home.player.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit["normal"].dot(Space.up(home, hit["position"])) < 0.9 or not home._dry(hit["position"]):
		return
	var position: Vector3 = hit["position"] + Space.up(home, hit["position"]) * 0.06
	# Leave clearance inside the neighbor resident's saved 22 m boundary.
	if _radius > RADIUS and position.distance_to(origin) > 21.0:
		return
	if not home._clear_space(position + Space.up(home, position) * 0.72):
		return
	graph.add_point(_id(x, z), position)

func _connect_point(x: int, z: int) -> void:
	var id: int = _id(x, z)
	if not graph.has_point(id):
		return
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	if _spacing < 1.0:
		# Keep the original one-metre stair edges as well. A capsule
		# cannot stand halfway beside a riser, but can step across it.
		offsets.append_array([Vector2i(2, 0), Vector2i(0, 2)])
	for offset: Vector2i in offsets:
		if x + offset.x > _samples or z + offset.y > _samples:
			continue
		var other: int = _id(x + offset.x, z + offset.y)
		# Loaded voxel treads can differ by 0.50000... m after collision
		# interpolation. Preserve half-metre links within the 0.55 m step budget.
		if graph.has_point(other) and absf((graph.get_point_position(id) - graph.get_point_position(other)).dot(Space.up(home, origin))) <= 0.52:
			# Midpoint clearance catches tree trunks between grid samples.
			var middle: Vector3 = graph.get_point_position(id).lerp(graph.get_point_position(other), 0.5)
			var floor_hit: Dictionary = home._floor_hit(middle)
			if floor_hit.is_empty():
				continue
			# Stairs are discontinuous. The averaged endpoint height can
			# put a standing capsule inside the higher tread; use its real floor.
			var floor_position: Vector3 = floor_hit["position"]
			if absf((floor_position - graph.get_point_position(id)).dot(Space.up(home, floor_position))) <= 0.56 and absf((floor_position - graph.get_point_position(other)).dot(Space.up(home, floor_position))) <= 0.56 and home._clear_space(floor_position + Space.up(home, floor_position) * 0.78):
				graph.connect_points(id, other)


func _id(x: int, z: int) -> int:
	return (z + _samples) * (_samples * 2 + 1) + x + _samples

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	if pending or graph.get_point_count() == 0:
		return PackedVector3Array()
	if _occupied(to):
		return PackedVector3Array()
	var prefix := PackedVector3Array()
	for shelter: Dictionary in shelters:
		if Housing.contains(shelter, Space.encode(home, from)):
			# Legacy decorative huts could contain a saved resident. Leave by the door.
			from = Space.resolve(home, shelter["entrance"])
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
	return graph.get_point_position(graph.get_closest_point(position)) if not pending and graph.get_point_count() > 0 else Vector3.INF

func sites() -> Dictionary:
	var result: Dictionary = {"huts": []}
	var used: Array[Vector3] = [origin]
	var offsets: Dictionary = {"wood": Vector3(-5, 0, -4), "stone": Vector3(5, 0, -4), "food": Vector3(-5, 0, 4), "hut0": Vector3(5, 0, 4), "hut1": Vector3(8, 0, 0)}
	for kind: String in offsets:
		var best := Vector3.INF
		var distance: float = INF
		for id: int in graph.get_point_ids():
			var point: Vector3 = graph.get_point_position(id)
			if point.distance_to(Space.offset(home, origin, offsets[kind])) >= distance:
				continue
			var clear: bool = true
			if kind.begins_with("hut"):
				# A hut needs a complete level footprint, not a single safe ray.
				for corner: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
					var floor_point: Vector3 = snap(Space.offset(home, point, corner))
					if floor_point.distance_to(Space.offset(home, point, corner)) > 0.45 or route(point, floor_point).is_empty():
						clear = false
			for previous: Vector3 in used:
				if point.distance_to(previous) < 3.0:
					clear = false
			if not clear or route(origin, point).is_empty():
				continue
			best = point
			distance = point.distance_to(Space.offset(home, origin, offsets[kind]))
		if not best.is_finite():
			return {}
		used.append(best)
		if kind.begins_with("hut"):
			result["huts"].append(Space.encode(home, best))
		else:
			result[kind] = Space.encode(home, best)
	return result

func free_workplace(position: Vector3, data: Dictionary, kind: String, maximum_distance: float = 16.0, floor_tolerance: float = 0.45) -> bool:
	if not position.is_finite() or position.distance_to(origin) > maximum_distance or position.distance_to(origin) < 3.0 or route(origin, position).is_empty():
		return false
	for corner: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		var floor_point: Vector3 = snap(Space.offset(home, position, corner))
		if floor_point.distance_to(Space.offset(home, position, corner)) > minf(floor_tolerance, 0.75) or route(position, floor_point).is_empty():
			return false
	for shelter: Dictionary in Housing.obstacles(data) + data.get("husbandry", {}).get("pens", []):
		if position.distance_to(Space.resolve(home, shelter["position"])) < 4.0 or position.distance_to(Space.resolve(home, shelter["entrance"])) < 2.5:
			return false
	for resource: String in data["deposits"]:
		# Upgrading an old source in place is allowed; other sources keep room.
		if resource == {"well": "water", "forester": "wood", "quarry": "stone", "fiberbed": "fiber"}.get(kind):
			continue
		var site: Variant = data["deposits"][resource]["position"]
		if position.distance_to(Space.resolve(home, site)) < 3.0:
			return false
	return true

func _occupied(position: Vector3) -> bool:
	for shelter: Dictionary in shelters:
		if Housing.contains(shelter, Space.encode(home, position)):
			return true
	return false

func free_shelter(position: Vector3, data: Dictionary, kind: String) -> bool:
	if not free_workplace(position, data, kind):
		return false
	var candidate: Dictionary = Housing.site(data, kind, Space.encode(home, position), data["housing"]["homes"].size())
	var entrance: Vector3 = Space.resolve(home, candidate["entrance"])
	if snap(entrance).distance_to(entrance) > 0.45:
		return false
	for member: Dictionary in data["members"]:
		if Housing.contains(candidate, member["position"]):
			return false
	# Reserve the full footprint before charging. It must not sever any route
	# from a resident, existing source, entrance or accepted D3 pickup to storage.
	var disabled: Array[int] = []
	for id: int in graph.get_point_ids():
		if Housing.contains(candidate, Space.encode(home, graph.get_point_position(id))) and not graph.is_point_disabled(id):
			graph.set_point_disabled(id, true)
			disabled.append(id)
	shelters.append(candidate)
	var points: Array[Vector3] = [entrance]
	for member: Dictionary in data["members"]:
		points.append(Space.resolve(home, member["position"]))
		if member["order"] == "move" or member["paused_order"] == "move":
			points.append(Space.resolve(home, member["destination"]))
	for deposit: Dictionary in data["deposits"].values():
		points.append(Space.resolve(home, deposit["position"]))
	for shelter: Dictionary in data["housing"]["homes"]:
		points.append(Space.resolve(home, shelter["entrance"]))
	for p: Dictionary in data.get("husbandry", {}).get("pens", []):
		points.append(Space.resolve(home, p["position"]))
		points.append(Space.resolve(home, p["entrance"]))
	for record: Dictionary in data.get("husbandry", {}).get("records", {}).values():
		if int(record["pending_milk"]) > 0:
			points.append(Space.resolve(home, record["pickup"]))
	for batch: Dictionary in data["economy"]["incoming"]:
		points.append(Space.resolve(home, batch["position"]))
	var clear: bool = true
	for point: Vector3 in points:
		if route(origin, point).is_empty():
			clear = false
	for id: int in disabled:
		graph.set_point_disabled(id, false)
	shelters.pop_back()
	return clear

func surface_origin_shifted(shift: Vector3) -> void:
	origin += shift
	for id: int in graph.get_point_ids(): graph.set_point_position(id, graph.get_point_position(id) + shift)
