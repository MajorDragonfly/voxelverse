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
			score += ecology * 0.55

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

		if score > best_score:
			best_score = score
			best_point = Vector2(world_x, world_z)
			best_height = height

	var visual_height: float = best_height
	if generator.has_method("get_visual_terrain_height"):
		visual_height = float(generator.call(
			"get_visual_terrain_height",
			best_point.x,
			best_point.y
		))
	return Vector3(best_point.x, visual_height + 2.2, best_point.y)
