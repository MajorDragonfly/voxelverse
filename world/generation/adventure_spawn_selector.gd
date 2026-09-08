extends RefCounted
class_name AdventureSpawnSelector

const DEFAULT_SEARCH_RADIUS: float = 220.0
const SAMPLE_COUNT: int = 84


static func find_spawn(
	generator: Node,
	center: Vector2 = Vector2.ZERO,
	search_radius: float = DEFAULT_SEARCH_RADIUS
) -> Vector3:
	if generator == null:
		return Vector3(center.x, 3.0, center.y)

	var world_seed: int = 1
	if generator.has_method("get_world_seed"):
		world_seed = int(generator.call("get_world_seed"))
	var random := RandomNumberGenerator.new()
	random.seed = world_seed * 1_000_003 + 9_173_117
	var sea_level: float = 0.0
	if generator.has_method("get_sea_level"):
		sea_level = float(generator.call("get_sea_level"))

	var best_point := center
	var best_height: float = sea_level + 2.0
	var best_score: float = -INF
	var radius_limit: float = maxf(search_radius, 40.0)
	var candidates: Array[Dictionary] = []

	for index in range(SAMPLE_COUNT):
		var ring_ratio: float = sqrt(float(index + 1) / float(SAMPLE_COUNT))
		var angle: float = random.randf_range(0.0, TAU)
		var radius: float = ring_ratio * radius_limit * random.randf_range(0.58, 1.0)
		var world_x: float = center.x + cos(angle) * radius
		var world_z: float = center.y + sin(angle) * radius
		var height: float = float(generator.call("get_terrain_height", world_x, world_z))
		if height < sea_level + 0.85:
			continue
		var slope: float = 0.0
		if generator.has_method("get_terrain_slope"):
			slope = float(generator.call("get_terrain_slope", world_x, world_z, 0.75))
		if slope > 0.44:
			continue

		var score: float = 0.0
		# Prefer comfortable low/mid elevation while still keeping mountains and
		# major formations nearby rather than spawning directly on a cliff.
		var elevation_target: float = sea_level + 4.8
		score += 1.0 - clampf(absf(height - elevation_target) / 10.0, 0.0, 1.0)
		score += (1.0 - clampf(slope / 0.44, 0.0, 1.0)) * 0.85

		if generator.has_method("get_ecology_density"):
			var ecology: float = float(generator.call(
				"get_ecology_density",
				world_x,
				world_z,
				height
			))
			score += (1.0 - smoothstep(0.28, 0.65, ecology)) * 1.15

		if generator.has_method("get_region_profile"):
			var region_value: Variant = generator.call("get_region_profile", world_x, world_z)
			if region_value is Dictionary:
				var region: Dictionary = region_value
				var mountain: float = float(region.get("mountain", 0.0))
				var canyon: float = float(region.get("canyon", 0.0))
				var plateau: float = float(region.get("plateau", 0.0))
				var basin: float = float(region.get("basin", 0.0))
				# Scenic intensity is intentionally rewarded without requiring the
				# spawn point itself to be steep.
				score += mountain * 1.05
				score += canyon * 0.72
				score += plateau * 0.48
				score += basin * 0.30

		if generator.has_method("get_river_strength"):
			var river: float = float(generator.call("get_river_strength", world_x, world_z))
			score += clampf(river, 0.0, 1.0) * 0.36
		if generator.has_method("get_lake_strength"):
			var lake: float = float(generator.call("get_lake_strength", world_x, world_z))
			score += clampf(lake, 0.0, 1.0) * 0.24

		candidates.append({"point": Vector2(world_x, world_z), "height": height, "score": score})

	if candidates.is_empty() and radius_limit < 3520.0:
		return find_spawn(generator, center, radius_limit * 2.0)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	for candidate: Dictionary in candidates.slice(0, mini(12, candidates.size())):
		var point: Vector2 = candidate["point"]
		var view: Dictionary = evaluate_view(generator, point, float(candidate["height"]))
		var score: float = float(candidate["score"]) + float(view["score"])
		if score > best_score:
			best_score = score
			best_point = point
			best_height = float(candidate["height"])
	var visual_height: float = best_height
	if generator.has_method("get_visual_terrain_height"):
		visual_height = float(generator.call(
			"get_visual_terrain_height",
			best_point.x,
			best_point.y
		))
	return Vector3(best_point.x, visual_height + 2.2, best_point.y)


static func evaluate_view(generator: Node, point: Vector2, surface_height: float) -> Dictionary:
	# An angular horizon on each ray rejects features hidden by nearer ground.
	# This is a bounded terrain viewshed, not a GPU occlusion query through trees.
	var eye_height: float = surface_height + 1.65
	var sea: float = float(generator.call("get_sea_level"))
	var visible_water: int = 0
	var visible_relief: float = 0.0
	var forest_edges: int = 0
	var visible_landmarks: int = 0
	for ray in range(12):
		var angle: float = float(ray) * TAU / 12.0
		var direction := Vector2(cos(angle), sin(angle))
		var horizon: float = -INF
		var previous_ecology: float = -1.0
		for distance: float in [15.0, 30.0, 60.0, 100.0, 150.0, 240.0, 360.0]:
			var probe: Vector2 = point + direction * distance
			var height: float = float(generator.call("get_terrain_height", probe.x, probe.y))
			var slope: float = (height - eye_height) / distance
			var visible: bool = slope >= horizon - 0.008
			if visible and distance >= 30.0:
				visible_relief = maxf(visible_relief, absf(height - surface_height))
				if height <= sea + 0.08:
					visible_water += 1
				if generator.has_method("get_ecology_density"):
					var ecology: float = float(generator.call("get_ecology_density", probe.x, probe.y, height))
					if previous_ecology >= 0.0 and absf(ecology - previous_ecology) > 0.18:
						forest_edges += 1
					previous_ecology = ecology
			var canopy: float = 0.0
			if distance <= 60.0 and generator.has_method("get_ecology_density"):
				canopy = smoothstep(0.35, 0.70, float(generator.call("get_ecology_density", probe.x, probe.y, height))) * 6.0
			horizon = maxf(horizon, (height + canopy - eye_height) / distance)
	if generator.has_method("get_landmarks_near"):
		for landmark: Dictionary in generator.call("get_landmarks_near", point.x, point.y):
			var target: Vector2 = landmark["center"]
			var distance: float = point.distance_to(target)
			if distance < 30.0 or distance > 360.0:
				continue
			var height: float = float(generator.call("get_terrain_height", target.x, target.y))
			var blocked: bool = false
			for step in range(1, 6):
				var fraction: float = step / 6.0
				var probe: Vector2 = point.lerp(target, fraction)
				var blocker: float = float(generator.call("get_terrain_height", probe.x, probe.y))
				if blocker > lerpf(eye_height, height + 1.0, fraction):
					blocked = true
			if not blocked:
				visible_landmarks += 1
	return {"score": minf(visible_relief / 10.0, 1.5) + minf(visible_water * 0.13, 0.7) + minf(forest_edges * 0.10, 0.35) + minf(visible_landmarks * 0.35, 0.7),
		"relief": visible_relief, "water_samples": visible_water, "forest_edges": forest_edges, "landmarks": visible_landmarks}
