extends "res://world/generation/world_generator_v3.gd"

# Runtime V4 keeps the deterministic regional terrain from V3, but removes
# temperature/moisture from the hot generation path. Terrain height samples are
# cached because a voxel column, its neighbours, biome and color frequently ask
# for the same world coordinate during one chunk build.

const HEIGHT_CACHE_LIMIT: int = 140_000
const VISUAL_HEIGHT_STEP_V4: float = 0.25

var _palette_noise := FastNoiseLite.new()
var _ecology_noise := FastNoiseLite.new()
var _micro_relief_noise := FastNoiseLite.new()
var _color_detail_noise := FastNoiseLite.new()
var _height_cache: Dictionary = {}
var _v4_seed: int = -1


func _ready() -> void:
	super._ready()
	_ensure_v4_state()


func set_seed_override(new_seed: int) -> void:
	super.set_seed_override(new_seed)
	_configure_v4(new_seed)


func clear_seed_override() -> void:
	super.clear_seed_override()
	_configure_v4(get_world_seed())


func set_world_seed(new_seed: int) -> void:
	super.set_world_seed(new_seed)
	_configure_v4(new_seed)


func get_terrain_height(world_x: float, world_z: float) -> float:
	_ensure_v4_state()
	var cache_key := Vector2i(roundi(world_x * 100.0), roundi(world_z * 100.0))
	if _height_cache.has(cache_key):
		return float(_height_cache[cache_key])

	var terrain_height: float = super.get_terrain_height(world_x, world_z)
	var micro_relief: float = _micro_relief_noise.get_noise_2d(world_x, world_z)
	var inland: float = smoothstep(0.34, 0.68, get_continentality(world_x, world_z))
	terrain_height = clampf(
		terrain_height + micro_relief * 0.28 * inland,
		MIN_TERRAIN_HEIGHT,
		MAX_TERRAIN_HEIGHT
	)

	if _height_cache.size() >= HEIGHT_CACHE_LIMIT:
		_height_cache.clear()
	_height_cache[cache_key] = terrain_height
	return terrain_height


func get_visual_terrain_height(world_x: float, world_z: float) -> float:
	return snappedf(
		get_terrain_height(world_x, world_z),
		VISUAL_HEIGHT_STEP_V4
	)


# Kept as constant compatibility values for older APIs and smoke tests. No noise
# layers or repeated terrain calls are performed for either field anymore.
func get_temperature(
	_world_x: float,
	_world_z: float,
	_terrain_height: float = -9999.0
) -> float:
	return 0.5


func get_moisture(
	_world_x: float,
	_world_z: float,
	_terrain_height: float = -9999.0
) -> float:
	return 0.5


func get_ecology_density(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> float:
	_ensure_v4_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)
	var ecology: float = _normalized_v4(_ecology_noise, world_x, world_z)
	var region_profile: Dictionary = get_region_profile(world_x, world_z)
	var region_scale: float = float(region_profile.get("flora_scale", 1.0))
	var altitude_scale: float = 1.0 - smoothstep(5.5, 12.5, terrain_height) * 0.82
	return clampf(ecology * region_scale * altitude_scale, 0.0, 1.0)


func get_biome_vegetation_density(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> float:
	return get_ecology_density(world_x, world_z, terrain_height)


func get_biome(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> int:
	_ensure_v4_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)

	var sea_level: float = get_sea_level()
	var river: float = get_river_strength(world_x, world_z)
	var lake: float = get_lake_strength(world_x, world_z)
	var palette: float = _normalized_v4(_palette_noise, world_x, world_z)
	var ecology: float = get_ecology_density(world_x, world_z, terrain_height)
	var region_profile: Dictionary = get_region_profile(world_x, world_z)
	var ruggedness: float = float(region_profile.get("ruggedness", 0.25))
	var water_influence: float = maxf(river, lake)

	if terrain_height < sea_level - 0.45:
		return Biome.OCEAN
	if terrain_height < sea_level + 0.55:
		return Biome.COAST
	if lake > 0.68 and terrain_height < sea_level + 1.65:
		return Biome.LAKE
	if river > 0.70 and terrain_height < 7.0:
		return Biome.RIVER
	if terrain_height > 12.0:
		return Biome.SNOW
	if terrain_height > 8.4:
		return Biome.ALPINE
	if ruggedness > 0.72 and terrain_height > 4.8:
		return Biome.ROCKY_HIGHLANDS
	if water_influence > 0.72 and ecology > 0.62 and terrain_height < 3.0:
		return Biome.SWAMP
	if water_influence > 0.48 and ecology > 0.52 and terrain_height < 3.8:
		return Biome.WETLAND
	if palette > 0.78 and ecology < 0.38:
		return Biome.DESERT
	if palette > 0.62 and ecology < 0.58:
		return Biome.SAVANNA
	if ecology > 0.78:
		return Biome.DENSE_FOREST
	if ecology > 0.57:
		return Biome.FOREST
	if palette > 0.56:
		return Biome.STEPPE
	return Biome.GRASSLAND


func get_biome_color(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> Color:
	_ensure_v4_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)

	var sea_level: float = get_sea_level()
	if terrain_height < sea_level - 0.45:
		var ocean_depth: float = clampf((sea_level - terrain_height) / 7.0, 0.0, 1.0)
		return Color(0.12, 0.30, 0.42, 1.0).lerp(
			Color(0.055, 0.14, 0.25, 1.0),
			ocean_depth
		)

	var palette: float = _normalized_v4(_palette_noise, world_x, world_z)
	var ecology: float = get_ecology_density(world_x, world_z, terrain_height)
	var river: float = get_river_strength(world_x, world_z)
	var lake: float = get_lake_strength(world_x, world_z)
	var region_profile: Dictionary = get_region_profile(world_x, world_z)
	var ruggedness: float = float(region_profile.get("ruggedness", 0.25))

	var grass_color := Color(0.31, 0.56, 0.31, 1.0)
	var forest_color := Color(0.10, 0.34, 0.20, 1.0)
	var dry_color := Color(0.62, 0.52, 0.24, 1.0)
	var wet_color := Color(0.16, 0.43, 0.33, 1.0)
	var coast_color := Color(0.70, 0.59, 0.36, 1.0)
	var rock_color := Color(0.36, 0.38, 0.39, 1.0)
	var snow_color := Color(0.78, 0.84, 0.83, 1.0)

	var forest_weight: float = smoothstep(0.42, 0.80, ecology)
	var dry_weight: float = smoothstep(0.50, 0.82, palette) * (1.0 - forest_weight * 0.58)
	var wet_weight: float = smoothstep(0.42, 0.82, maxf(river, lake)) * 0.72
	var rock_weight: float = clampf(
		smoothstep(4.8, 10.4, terrain_height) * lerpf(0.48, 1.0, ruggedness),
		0.0,
		1.0
	)
	var snow_weight: float = smoothstep(10.2, 14.2, terrain_height)
	var coast_weight: float = 1.0 - smoothstep(sea_level + 0.35, sea_level + 1.55, terrain_height)

	var color: Color = grass_color.lerp(forest_color, forest_weight)
	color = color.lerp(dry_color, dry_weight)
	color = color.lerp(wet_color, wet_weight)
	color = color.lerp(coast_color, clampf(coast_weight, 0.0, 1.0))
	color = color.lerp(rock_color, rock_weight)
	color = color.lerp(snow_color, snow_weight)

	var detail: float = _color_detail_noise.get_noise_2d(world_x, world_z) * 0.055
	return Color(
		clampf(color.r + detail, 0.0, 1.0),
		clampf(color.g + detail, 0.0, 1.0),
		clampf(color.b + detail * 0.72, 0.0, 1.0),
		1.0
	)


func sample_world(world_x: float, world_z: float) -> Dictionary:
	var height: float = get_terrain_height(world_x, world_z)
	var biome: int = get_biome(world_x, world_z, height)
	var region_profile: Dictionary = get_region_profile(world_x, world_z)
	return {
		"seed": get_world_seed(),
		"height": height,
		"visual_height": get_visual_terrain_height(world_x, world_z),
		"continentality": get_continentality(world_x, world_z),
		"temperature": 0.5,
		"moisture": 0.5,
		"slope": get_terrain_slope(world_x, world_z),
		"river": get_river_strength(world_x, world_z),
		"lake": get_lake_strength(world_x, world_z),
		"ecology": get_ecology_density(world_x, world_z, height),
		"region_name": str(region_profile.get("name", "Unknown Region")),
		"biome": biome,
		"biome_name": get_biome_name(biome),
	}


func _ensure_v4_state() -> void:
	var seed_value: int = get_world_seed()
	if seed_value != _v4_seed:
		_configure_v4(seed_value)


func _configure_v4(seed_value: int) -> void:
	_v4_seed = seed_value
	_height_cache.clear()
	_setup_v4_noise(_palette_noise, seed_value + 4_013, 0.00072, 3)
	_setup_v4_noise(_ecology_noise, seed_value + 6_019, 0.00105, 3)
	_setup_v4_noise(_micro_relief_noise, seed_value + 8_021, 0.018, 2)
	_setup_v4_noise(_color_detail_noise, seed_value + 10_027, 0.034, 2)


func _setup_v4_noise(
	noise: FastNoiseLite,
	seed_value: int,
	frequency: float,
	octaves: int
) -> void:
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	noise.domain_warp_enabled = true
	noise.domain_warp_amplitude = 22.0
	noise.domain_warp_frequency = frequency * 0.65


func _normalized_v4(noise: FastNoiseLite, x: float, z: float) -> float:
	return clampf(noise.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
