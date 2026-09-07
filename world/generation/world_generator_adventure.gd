extends "res://world/generation/world_generator_v6_smooth.gd"

const AdventureProfile = preload("res://world/generation/planet_profile_v8.gd")

const ADVENTURE_MIN_HEIGHT: float = -9.0
const ADVENTURE_MAX_HEIGHT: float = 32.0
const ADVENTURE_VISUAL_STEP: float = 0.25

var _mountain_presence_noise := FastNoiseLite.new()
var _mountain_chain_noise := FastNoiseLite.new()
var _peak_noise := FastNoiseLite.new()
var _plateau_noise := FastNoiseLite.new()
var _canyon_noise := FastNoiseLite.new()
var _basin_noise := FastNoiseLite.new()
var _island_noise := FastNoiseLite.new()
var _landmark_noise := FastNoiseLite.new()


func _configure_v6(seed_value: int) -> void:
	super._configure_v6(seed_value)
	_planet_profile = AdventureProfile.create(seed_value)
	_height_cache.clear()
	_setup_adventure_noise(_mountain_presence_noise, seed_value + 8_111, 0.00026, FastNoiseLite.FRACTAL_FBM, 3, 58.0)
	_setup_adventure_noise(_mountain_chain_noise, seed_value + 9_223, 0.00058, FastNoiseLite.FRACTAL_FBM, 3, 42.0)
	_setup_adventure_noise(_peak_noise, seed_value + 10_337, 0.00145, FastNoiseLite.FRACTAL_RIDGED, 4, 24.0)
	_setup_adventure_noise(_plateau_noise, seed_value + 11_449, 0.00044, FastNoiseLite.FRACTAL_FBM, 3, 48.0)
	_setup_adventure_noise(_canyon_noise, seed_value + 12_563, 0.00082, FastNoiseLite.FRACTAL_FBM, 3, 36.0)
	_setup_adventure_noise(_basin_noise, seed_value + 13_681, 0.00031, FastNoiseLite.FRACTAL_FBM, 3, 54.0)
	_setup_adventure_noise(_island_noise, seed_value + 14_797, 0.00035, FastNoiseLite.FRACTAL_FBM, 3, 64.0)
	_setup_adventure_noise(_landmark_noise, seed_value + 15_901, 0.00185, FastNoiseLite.FRACTAL_FBM, 2, 18.0)


func get_continentality(world_x: float, world_z: float) -> float:
	_ensure_v6_state()
	var base: float = super.get_continentality(world_x, world_z)
	var style: int = int(_planet_profile.get("terrain_style", 0))
	if style == 3:
		var islands: float = _normalized_v6(_island_noise, world_x, world_z)
		base = clampf(pow(base, 1.24) + (islands - 0.5) * 0.18, 0.0, 1.0)
	return base


func get_terrain_height(world_x: float, world_z: float) -> float:
	_ensure_v6_state()
	var cache_key := Vector2i(roundi(world_x * 100.0), roundi(world_z * 100.0))
	if _height_cache.has(cache_key):
		return float(_height_cache[cache_key])
	# Evaluate the canonical centimetre represented by the cache key. Otherwise
	# nearby first queries make later height results depend on streaming order.
	world_x = float(cache_key.x) / 100.0
	world_z = float(cache_key.y) / 100.0

	var warp_strength: float = 88.0
	var warp_x: float = _warp_noise.get_noise_2d(world_x, world_z) * warp_strength
	var warp_z: float = _warp_noise.get_noise_2d(world_x + 1731.0, world_z - 947.0) * warp_strength
	var x: float = world_x + warp_x
	var z: float = world_z + warp_z
	var continentality: float = get_continentality(x, z)
	var land_mass: float = smoothstep(0.27, 0.70, continentality)
	var style: int = int(_planet_profile.get("terrain_style", 0))
	var relief_scale: float = float(_planet_profile.get("relief_scale", 1.0))
	var mountain_scale: float = float(_planet_profile.get("mountain_scale", 1.0))
	var mountain_presence_scale: float = float(_planet_profile.get("mountain_presence", 1.0))
	var plateau_scale: float = float(_planet_profile.get("plateau_scale", 1.0))
	var canyon_scale: float = float(_planet_profile.get("canyon_scale", 1.0))
	var basin_scale: float = float(_planet_profile.get("basin_scale", 1.0))

	var macro_relief: float = _relief_noise.get_noise_2d(x, z)
	var landmark: float = _landmark_noise.get_noise_2d(x, z)
	var terrain_height: float = SEA_LEVEL - 4.4
	terrain_height += land_mass * 8.0
	terrain_height += macro_relief * land_mass * 2.25 * relief_scale
	terrain_height += landmark * land_mass * 0.55

	var mountain_presence: float = smoothstep(
		0.50,
		0.75,
		_normalized_v6(_mountain_presence_noise, x, z) * mountain_presence_scale
	)
	var chain_sample: float = absf(_mountain_chain_noise.get_noise_2d(x, z))
	var chain: float = pow(clampf(1.0 - chain_sample, 0.0, 1.0), 3.3)
	var peak_detail: float = pow(
		clampf(_normalized_v6(_peak_noise, x, z), 0.0, 1.0),
		2.1
	)
	var mountain_mask: float = mountain_presence * chain * smoothstep(0.42, 0.78, land_mass)
	var mountain_height: float = mountain_mask * (7.5 + peak_detail * 17.0) * mountain_scale
	terrain_height += mountain_height
	terrain_height += mountain_presence * land_mass * macro_relief * 2.2 * mountain_scale

	var plateau_field: float = _normalized_v6(_plateau_noise, x, z)
	var plateau_mask: float = smoothstep(0.60, 0.80, plateau_field) * land_mass
	var plateau_strength: float = plateau_scale * (6.4 if style == 2 else 3.0)
	terrain_height += plateau_mask * plateau_strength
	if style == 2:
		terrain_height = lerpf(
			terrain_height,
			snappedf(terrain_height, 1.25),
			plateau_mask * 0.54
		)

	var canyon_line: float = pow(
		clampf(1.0 - absf(_canyon_noise.get_noise_2d(x, z)), 0.0, 1.0),
		5.2
	)
	var canyon_region: float = smoothstep(0.36, 0.76, land_mass) * (1.0 - mountain_mask * 0.42)
	var canyon_depth: float = canyon_line * canyon_region * canyon_scale * (5.6 if style in [2, 4] else 3.2)
	terrain_height -= canyon_depth

	var basin_field: float = smoothstep(0.68, 0.88, _normalized_v6(_basin_noise, x, z))
	var basin_depth: float = basin_field * land_mass * (1.0 - mountain_presence * 0.62) * basin_scale * 3.8
	terrain_height -= basin_depth

	if style == 3:
		var island_field: float = _normalized_v6(_island_noise, x, z)
		terrain_height += (island_field - 0.54) * 2.2 * float(_planet_profile.get("island_scale", 1.0))
	elif style == 5:
		terrain_height += mountain_mask * peak_detail * 4.0
	elif style == 0:
		terrain_height += smoothstep(0.48, 0.72, land_mass) * 0.8

	var river_strength: float = get_river_strength(world_x, world_z)
	terrain_height -= river_strength * land_mass * lerpf(1.1, 4.1, mountain_presence)
	var lake_strength: float = get_lake_strength(world_x, world_z)
	var lake_target: float = SEA_LEVEL - lerpf(0.35, 1.30, lake_strength)
	terrain_height = lerpf(terrain_height, lake_target, lake_strength * 0.88)

	var micro: float = _micro_relief_noise.get_noise_2d(world_x, world_z)
	terrain_height += get_landscape_height_offset(world_x, world_z) * smoothstep(SEA_LEVEL - 0.5, SEA_LEVEL + 2.5, terrain_height)
	terrain_height += micro * 0.10 * land_mass
	terrain_height = clampf(terrain_height, ADVENTURE_MIN_HEIGHT, ADVENTURE_MAX_HEIGHT)
	if _height_cache.size() >= HEIGHT_CACHE_LIMIT:
		_height_cache.clear()
	_height_cache[cache_key] = terrain_height
	return terrain_height


func get_landscape_height_offset(_world_x: float, _world_z: float) -> float:
	return 0.0


func get_visual_terrain_height(world_x: float, world_z: float) -> float:
	return snappedf(get_terrain_height(world_x, world_z), ADVENTURE_VISUAL_STEP)


func get_region_profile(world_x: float, world_z: float) -> Dictionary:
	_ensure_v6_state()
	var mountain_presence: float = smoothstep(
		0.50,
		0.75,
		_normalized_v6(_mountain_presence_noise, world_x, world_z)
		* float(_planet_profile.get("mountain_presence", 1.0))
	)
	var chain: float = pow(
		clampf(1.0 - absf(_mountain_chain_noise.get_noise_2d(world_x, world_z)), 0.0, 1.0),
		3.3
	)
	var plateau: float = smoothstep(0.60, 0.80, _normalized_v6(_plateau_noise, world_x, world_z))
	var canyon: float = pow(clampf(1.0 - absf(_canyon_noise.get_noise_2d(world_x, world_z)), 0.0, 1.0), 5.2)
	var basin: float = smoothstep(0.68, 0.88, _normalized_v6(_basin_noise, world_x, world_z))
	var landmark_name: String = "Open Country"
	var ruggedness: float = clampf(mountain_presence * chain * 1.4 + plateau * 0.35, 0.0, 1.0)
	if mountain_presence * chain > 0.42:
		landmark_name = "Mountain Chain"
	elif canyon > 0.58:
		landmark_name = "Canyon Country"
	elif plateau > 0.68:
		landmark_name = "High Plateau"
	elif basin > 0.72:
		landmark_name = "Great Basin"
	var ecology: float = _normalized_v6(_ecology_noise, world_x, world_z)
	return {
		"name": landmark_name,
		"terrain_archetype": str(_planet_profile.get("terrain_archetype", "Unknown")),
		"ruggedness": ruggedness,
		"flora_scale": clampf(
			ecology * 1.30 * float(_planet_profile.get("flora_scale", 1.0)),
			0.18,
			1.55
		),
		"mountain": mountain_presence * chain,
		"plateau": plateau,
		"canyon": canyon,
		"basin": basin,
	}


func get_ecology_density(world_x: float, world_z: float, terrain_height: float = -9999.0) -> float:
	_ensure_v6_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)
	var ecology: float = _normalized_v6(_ecology_noise, world_x, world_z)
	var altitude_scale: float = 1.0 - smoothstep(9.0, 25.0, terrain_height) * 0.84
	var flora_scale: float = float(_planet_profile.get("flora_scale", 1.0))
	return clampf(ecology * flora_scale * altitude_scale, 0.0, 1.0)


func get_biome(world_x: float, world_z: float, terrain_height: float = -9999.0) -> int:
	_ensure_v6_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)
	var sea_level: float = get_sea_level()
	var river: float = get_river_strength(world_x, world_z)
	var lake: float = get_lake_strength(world_x, world_z)
	var ecology: float = get_ecology_density(world_x, world_z, terrain_height)
	var palette: float = _normalized_v6(_palette_noise, world_x, world_z)
	var ruggedness: float = float(get_region_profile(world_x, world_z).get("ruggedness", 0.0))
	var snow_start: float = float(_planet_profile.get("snow_start_altitude", 20.0))
	if terrain_height < sea_level - 0.45:
		return Biome.OCEAN
	if terrain_height < sea_level + 0.55:
		return Biome.COAST
	if lake > 0.68 and terrain_height < sea_level + 1.65:
		return Biome.LAKE
	if river > 0.70 and terrain_height < 8.0:
		return Biome.RIVER
	if terrain_height >= snow_start + 3.0:
		return Biome.SNOW
	if terrain_height >= snow_start - 4.0:
		return Biome.ALPINE
	if ruggedness > 0.60 and terrain_height > 5.0:
		return Biome.ROCKY_HIGHLANDS
	if maxf(river, lake) > 0.68 and ecology > 0.58 and terrain_height < 3.4:
		return Biome.WETLAND
	if palette > 0.80 and ecology < 0.34:
		return Biome.DESERT
	if palette > 0.66 and ecology < 0.54:
		return Biome.SAVANNA
	if ecology > 0.79:
		return Biome.DENSE_FOREST
	if ecology > 0.56:
		return Biome.FOREST
	if palette > 0.58:
		return Biome.STEPPE
	return Biome.GRASSLAND


func get_biome_color(world_x: float, world_z: float, terrain_height: float = -9999.0) -> Color:
	_ensure_v6_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)
	var palette: Dictionary = _planet_profile.get("palette", {})
	var grass: Color = palette.get("grass", Color(0.30, 0.54, 0.28, 1.0))
	var forest: Color = palette.get("forest", Color(0.10, 0.34, 0.18, 1.0))
	var dry: Color = palette.get("dry", Color(0.64, 0.50, 0.24, 1.0))
	var coast: Color = palette.get("coast", Color(0.72, 0.61, 0.39, 1.0))
	var rock: Color = palette.get("rock", Color(0.37, 0.38, 0.39, 1.0))
	var snow: Color = palette.get("snow", Color(0.86, 0.90, 0.91, 1.0))
	var water: Color = palette.get("water", Color(0.04, 0.35, 0.44, 1.0))
	var sea: float = get_sea_level()
	if terrain_height < sea - 0.45:
		return water.lerp(water.darkened(0.48), clampf((sea - terrain_height) / 9.0, 0.0, 1.0))
	var ecology: float = get_ecology_density(world_x, world_z, terrain_height)
	var dry_field: float = _normalized_v6(_palette_noise, world_x, world_z)
	var ruggedness: float = float(get_region_profile(world_x, world_z).get("ruggedness", 0.0))
	var forest_weight: float = smoothstep(0.42, 0.82, ecology)
	var dry_weight: float = smoothstep(0.54, 0.84, dry_field) * (1.0 - forest_weight * 0.58)
	var rock_weight: float = smoothstep(5.0, 18.0, terrain_height) * lerpf(0.35, 1.0, ruggedness)
	var snow_start: float = float(_planet_profile.get("snow_start_altitude", 20.0))
	var snow_end: float = float(_planet_profile.get("snow_end_altitude", 24.0))
	var snow_weight: float = smoothstep(snow_start, snow_end, terrain_height)
	var coast_weight: float = 1.0 - smoothstep(sea + 0.25, sea + 1.6, terrain_height)
	var color: Color = grass.lerp(forest, forest_weight)
	color = color.lerp(dry, dry_weight)
	color = color.lerp(coast, coast_weight)
	color = color.lerp(rock, clampf(rock_weight, 0.0, 1.0))
	color = color.lerp(snow, snow_weight)
	var detail: float = _color_detail_noise.get_noise_2d(world_x, world_z) * 0.035
	return Color(
		clampf(color.r + detail, 0.0, 1.0),
		clampf(color.g + detail, 0.0, 1.0),
		clampf(color.b + detail * 0.72, 0.0, 1.0),
		1.0
	)


func sample_world(world_x: float, world_z: float) -> Dictionary:
	var result: Dictionary = super.sample_world(world_x, world_z)
	var region: Dictionary = get_region_profile(world_x, world_z)
	result["region_name"] = str(region.get("name", "Open Country"))
	result["terrain_archetype"] = str(_planet_profile.get("terrain_archetype", "Unknown"))
	return result


func _setup_adventure_noise(
	noise: FastNoiseLite,
	seed_value: int,
	frequency: float,
	fractal: int,
	octaves: int,
	warp_amplitude: float
) -> void:
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = fractal
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	noise.domain_warp_enabled = true
	noise.domain_warp_amplitude = warp_amplitude
	noise.domain_warp_frequency = frequency * 0.72
