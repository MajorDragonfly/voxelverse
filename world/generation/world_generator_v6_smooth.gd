extends "res://world/generation/world_generator_v6.gd"

# The first V6 pass still reused V2's high-frequency ridge kernel. It was
# mathematically continuous but could change almost two metres inside 0.25 world
# units. This active height kernel keeps the V6 planet/biome/species API while
# rebuilding elevation from lower-frequency continuous fields.


func get_terrain_height(world_x: float, world_z: float) -> float:
	_ensure_v6_state()
	var cache_key := Vector2i(roundi(world_x * 100.0), roundi(world_z * 100.0))
	if _height_cache.has(cache_key):
		return float(_height_cache[cache_key])

	var warp_x: float = _warp_noise.get_noise_2d(world_x, world_z) * 72.0
	var warp_z: float = _warp_noise.get_noise_2d(
		world_x + 1731.0,
		world_z - 947.0
	) * 72.0
	var sample_x: float = world_x + warp_x
	var sample_z: float = world_z + warp_z

	var continentality: float = get_continentality(sample_x, sample_z)
	var land_mass: float = smoothstep(0.27, 0.72, continentality)
	var region_value: float = _normalized_v6(_region_noise, world_x, world_z)
	var weights: Vector4 = _get_region_weights(region_value)
	var broad_relief: float = _relief_noise.get_noise_2d(sample_x, sample_z)
	var ridge_sample: float = _relief_noise.get_noise_2d(
		sample_x * 2.10 + 891.0,
		sample_z * 2.10 - 527.0
	)
	var valley_sample: float = _normalized_v6(
		_relief_noise,
		sample_x * 1.42 - 1613.0,
		sample_z * 1.42 + 743.0
	)
	var ridge: float = pow(
		clampf(1.0 - absf(ridge_sample), 0.0, 1.0),
		1.75
	)
	var relief_scale: float = float(_planet_profile.get("relief_scale", 1.0))
	var mountain_scale: float = float(_planet_profile.get("mountain_scale", 1.0))
	var erosion_scale: float = float(_planet_profile.get("erosion_scale", 1.0))

	var regional_relief_strength: float = (
		weights.x * 0.48
		+ weights.y * 1.05
		+ weights.z * 1.48
		+ weights.w * 1.86
	)
	var terrain_height: float = SEA_LEVEL - 3.35
	terrain_height += land_mass * 6.15
	terrain_height += (
		broad_relief
		* regional_relief_strength
		* relief_scale
		* land_mass
	)
	terrain_height += weights.z * land_mass * 0.82 * relief_scale
	terrain_height += (
		weights.w
		* land_mass
		* ridge
		* 6.6
		* mountain_scale
	)
	terrain_height -= (
		weights.w
		* land_mass
		* smoothstep(0.58, 0.90, valley_sample)
		* 1.55
		* erosion_scale
	)

	var river_strength: float = get_river_strength(world_x, world_z)
	terrain_height -= river_strength * land_mass * lerpf(0.85, 2.15, weights.w)

	var lake_strength: float = get_lake_strength(world_x, world_z)
	var lake_target: float = SEA_LEVEL - lerpf(0.30, 1.05, lake_strength)
	terrain_height = lerpf(terrain_height, lake_target, lake_strength * 0.82)

	var micro_relief: float = _micro_relief_noise.get_noise_2d(world_x, world_z)
	terrain_height += micro_relief * 0.12 * land_mass
	terrain_height = clampf(
		terrain_height,
		MIN_TERRAIN_HEIGHT,
		MAX_TERRAIN_HEIGHT
	)

	if _height_cache.size() >= HEIGHT_CACHE_LIMIT:
		_height_cache.clear()
	_height_cache[cache_key] = terrain_height
	return terrain_height
