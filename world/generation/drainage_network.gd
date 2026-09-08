extends RefCounted

# Bounded, seed-local drainage features. A stream has a monotonic longitudinal
# coordinate, a terrain-guided meander, and a non-increasing surface profile.
# Every route ends in a contained lake or at the ocean. Region margins keep
# unrelated catchments disjoint; ordinary terrain chunks never own the route.
const REGION_SIZE: float = 384.0
const BANK_WIDTH: float = 10.0
const PROFILE_STEP: float = 4.0
const MARGIN: float = 44.0

static func create(generator: Node, cell: Vector2i) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = generator.get_world_seed() * 1000003 + cell.x * 73856093 + cell.y * 19349663 + 190711
	var origin: Vector2 = Vector2(cell) * REGION_SIZE
	var bounds := Rect2(origin + Vector2.ONE * MARGIN, Vector2.ONE * (REGION_SIZE - MARGIN * 2.0))
	var source := Vector2.ZERO
	var source_height: float = -INF
	for i in range(36):
		var point: Vector2 = origin + Vector2(random.randf_range(72.0, 312.0), random.randf_range(72.0, 312.0))
		var height: float = generator.get_base_terrain_height(point.x, point.y)
		if height > source_height:
			source = point
			source_height = height
	var sea: float = generator.get_sea_level()
	if source_height < sea + 3.0:
		return {}
	var sink: Vector2 = source
	var sink_height: float = source_height
	for i in range(32):
		var angle: float = TAU * i / 32.0 + random.randf_range(-0.05, 0.05)
		var point: Vector2 = source + Vector2.from_angle(angle) * random.randf_range(96.0, 190.0)
		if not bounds.has_point(point):
			continue
		var height: float = generator.get_base_terrain_height(point.x, point.y)
		if height < sink_height:
			sink = point
			sink_height = height
	if source.distance_to(sink) < 64.0 or source_height - sink_height < 1.0:
		return {}
	var direction: Vector2 = (sink - source).normalized()
	var lateral := Vector2(-direction.y, direction.x)
	var length: float = source.distance_to(sink)
	# Choose intermediate valley positions, then interpolate them smoothly.
	var bends := PackedFloat32Array([0.0])
	for i in range(1, 4):
		var center: Vector2 = source.lerp(sink, i / 4.0)
		var best_offset: float = 0.0
		var best_cost: float = INF
		for offset: float in [-18.0, -9.0, 0.0, 9.0, 18.0]:
			var point: Vector2 = center + lateral * offset
			if not bounds.has_point(point):
				continue
			var cost: float = generator.get_base_terrain_height(point.x, point.y) + absf(offset - bends[-1]) * 0.035
			if cost < best_cost:
				best_cost = cost
				best_offset = offset
		bends.append(best_offset)
	bends.append(0.0)
	var route: Dictionary = {"cell": cell, "source": source, "sink": sink, "direction": direction, "lateral": lateral,
		"length": length, "bends": bends, "width": random.randf_range(5.5, 7.5),
		"lake_radius": random.randf_range(17.0, 24.0), "levels": PackedFloat32Array(), "sea": sea}
	var count: int = ceili(length / PROFILE_STEP) + 1
	var levels := PackedFloat32Array()
	var previous: float = source_height - 0.7
	for i in range(count):
		var u: float = i / float(count - 1)
		var point: Vector2 = center_at(route, u)
		var bed: float = generator.get_base_terrain_height(point.x, point.y)
		previous = maxf(sea, minf(previous, bed - 0.7))
		levels.append(previous)
	var lakes: Array[Dictionary] = []
	var lake: bool = levels[-1] > sea + 0.8
	if lake:
		# The river and lake share one level throughout their overlap, including
		# the buried bank collar. The receiving lake has no sloping water plane.
		var flat_from: float = length - float(route["lake_radius"]) - BANK_WIDTH - PROFILE_STEP
		for i in range(count):
			if i * length / float(count - 1) >= flat_from:
				levels[i] = levels[-1]
		lakes.append({"center": sink, "radius": route["lake_radius"], "level": levels[-1]})
	# Most local lowlands reach the sea. Upland spring basins also supply lakes
	# at distinct elevations, with a flat surface through the entire outlet.
	var source_radius: float = random.randf_range(12.0, 17.0)
	var flat_to: int = mini(ceili((source_radius + BANK_WIDTH + PROFILE_STEP) / length * (count - 1)), count - 1)
	var source_level: float = levels[flat_to]
	if source_level > sea + 1.5 and random.randf() < 0.72:
		for i in range(flat_to + 1):
			levels[i] = source_level
		lakes.append({"center": source, "radius": source_radius, "level": source_level})
	route["levels"] = levels
	route["lakes"] = lakes
	route["outlet"] = "lake" if lake else "ocean"
	route["bounds"] = Rect2(source, Vector2.ZERO).expand(sink).grow(48.0).intersection(Rect2(origin, Vector2.ONE * REGION_SIZE))
	return route

static func bend_at(route: Dictionary, u: float) -> float:
	var bends: PackedFloat32Array = route["bends"]
	var scaled: float = clampf(u, 0.0, 1.0) * 4.0
	var i: int = mini(floori(scaled), 3)
	return lerpf(bends[i], bends[i + 1], smoothstep(0.0, 1.0, scaled - i))

static func center_at(route: Dictionary, u: float) -> Vector2:
	return (route["source"] as Vector2).lerp(route["sink"], u) + (route["lateral"] as Vector2) * bend_at(route, u)

static func level_at(route: Dictionary, u: float) -> float:
	var levels: PackedFloat32Array = route["levels"]
	var scaled: float = clampf(u, 0.0, 1.0) * (levels.size() - 1)
	var index: int = mini(floori(scaled), levels.size() - 2)
	return lerpf(levels[index], levels[index + 1], scaled - index)

static func sample(route: Dictionary, point: Vector2) -> Dictionary:
	if route.is_empty() or not (route["bounds"] as Rect2).has_point(point):
		return {}
	var relative: Vector2 = point - (route["source"] as Vector2)
	var length: float = route["length"]
	var along: float = relative.dot(route["direction"])
	var u: float = clampf(along / length, 0.0, 1.0)
	var across: float = relative.dot(route["lateral"]) - bend_at(route, u)
	var end_distance: float = absf(along - clampf(along, 0.0, length))
	var distance: float = Vector2(across, end_distance).length() - float(route["width"])
	var kind: String = "river"
	var level: float = level_at(route, u)
	var depth: float = 2.4 + float(route["width"]) * 0.13
	var basin_width: float = float(route["width"])
	for lake: Dictionary in route["lakes"]:
		var lake_delta: Vector2 = point - (lake["center"] as Vector2)
		var lake_distance: float = Vector2(lake_delta.dot(route["direction"]), lake_delta.dot(route["lateral"]) * 1.20).length() - float(lake["radius"])
		if lake_distance < distance:
			distance = lake_distance
			level = lake["level"]
			kind = "lake"
			depth = clampf(float(lake["radius"]) * 0.46, 5.5, 11.0)
			basin_width = float(lake["radius"]) * 0.85
	if distance >= BANK_WIDTH:
		return {}
	return {"kind": kind, "level": level, "distance": distance, "depth": depth, "basin_width": basin_width,
		"sea": route["sea"], "flow": (route["direction"] as Vector2) if kind == "river" else Vector2.ZERO}

static func surface(info: Dictionary, sea: float) -> float:
	if info.is_empty():
		return sea
	return lerpf(float(info["level"]), sea, smoothstep(2.0, BANK_WIDTH, float(info["distance"])))

static func carve(base: float, info: Dictionary) -> float:
	if info.is_empty():
		return base
	var distance: float = info["distance"]
	var level: float = info["level"]
	# A wading shelf leads into the actual bowl/channel, rather than making the
	# entire lake one shallow tray. This height also drives collision and depth.
	var shelf: float = 0.9 * smoothstep(0.0, 2.0, -distance)
	var basin: float = smoothstep(1.5, maxf(float(info["basin_width"]), 2.5), -distance)
	var channel: float = level - shelf - (float(info["depth"]) - 0.9) * basin
	# A gently raised bank contains elevated water even where the underlying
	# noise has a small depression. Both bed and water return to the old fields.
	if distance > 0.0:
		channel = level + smoothstep(0.0, 2.0, distance) * 0.65
	# Do not build a ring-shaped dam across an ocean mouth. At sea level the
	# river may lower land, but must keep existing submerged ocean connections.
	channel = lerpf(minf(base, channel), channel, smoothstep(float(info["sea"]), float(info["sea"]) + 0.8, level))
	return lerpf(channel, base, smoothstep(2.0, BANK_WIDTH, distance))
