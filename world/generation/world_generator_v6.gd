extends "res://world/generation/world_generator_v2.gd"

const PlanetProfile = preload("res://world/generation/planet_profile_v6.gd")

# V6 deliberately skips the V3/V4 inheritance chain. Those versions switched
# between regional height formulas at hard thresholds, which created kilometre-
# long cliffs. V6 builds one continuous planet field and exposes a compact
# planet descriptor for future galaxy/system/planet selection.

const HEIGHT_CACHE_LIMIT: int = 160_000
const VISUAL_HEIGHT_STEP_V6: float = 0.25

var _region_noise := FastNoiseLite.new()
var _relief_noise := FastNoiseLite.new()
var _warp_noise := FastNoiseLite.new()
var _ecology_noise := FastNoiseLite.new()
var _palette_noise := FastNoiseLite.new()
var _micro_relief_noise := FastNoiseLite.new()
var _color_detail_noise := FastNoiseLite.new()

var _height_cache: Dictionary = {}
var _planet_profile: Dictionary = {}
var _v6_seed: int = -2_147_483_000


func _ready() -> void:
	super._ready()
	_ensure_v6_state()


func _rebuild_noise_state(new_seed: int) -> void:
	super._rebuild_noise_state(new_seed)
	_configure_v6(new_seed)


func get_planet_profile() -> Dictionary:
	_ensure_v6_state()
	return _planet_profile.duplicate(true)


func get_terrain_height(world_x: float, world_z: float) -> float:
	_ensure_v6_state()
	var cache_key := Vector2i(roundi(world_x * 100.0), roundi(world_z * 100.0))
	if _height_cache.has(cache_key):
		return float(_height_cache[cache_key])

	var warp_x: float = _warp_noise.get_noise_2d(world_x, world_z) * 92.0
	var warp_z: float = _warp_noise.get_noise_2d(world_x + 1731.0, world_z - 947.0) * 92.0
	var sample_x: float = world_x + warp_x
	var sample_z: float = world_z + warp_z
	var base_height: float = super.get_terrain_height(sample_x, sample_z)
	var region_value: float = _normalized_v6(_region_noise, world_x, world_z)
	var weights: Vector4 = _get_region_weights(region_value)
	var relief: float = _relief_noise.get_noise_2d(world_x, world_z)
	var micro_relief: float = _micro_relief_noise.get_noise_2d(world_x, world_z)
	var inland: float = smoothstep(0.30, 0.70, super.get_continentality(sample_x, sample_z))
	var relief_scale: float = float(_planet_profile.get("relief_scale", 1.0))
	var mountain_scale: float = float(_planet_profile.get("mountain_scale", 1.0))

	var lowland_height: float = relief * 0.42 - 0.28
	var rolling_height: float = relief * 1.05
	var plateau_height: float = 0.92 + relief * 1.38
	var rugged_height: float = 1.35 + absf(relief) * 2.35 * mountain_scale
	var regional_height: float = (
		weights.x * lowland_height
		+ weights.y * rolling_height
		+ weights.z * plateau_height
		+ weights.w * rugged_height
	)

	var terrain_height: float = base_height
	terrain_height += regional_height * inland * relief_scale
	terrain_height += micro_relief * 0.20 * inland
	terrain_height = clampf(terrain_height, MIN_TERRAIN_HEIGHT, MAX_TERRAIN_HEIGHT)

	if _height_cache.size() >= HEIGHT_CACHE_LIMIT:
		_height_cache.clear()
	_height_cache[cache_key] = terrain_height
	return terrain_height


func get_visual_terrain_height(world_x: float, world_z: float) -> float:
	return snappedf(get_terrain_height(world_x, world_z), VISUAL_HEIGHT_STEP_V6)


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


func get_region_profile(world_x: float, world_z: float) -> Dictionary:
	_ensure_v6_state()
	var value: float = _normalized_v6(_region_noise, world_x, world_z)
	var weights: Vector4 = _get_region_weights(value)
	var ruggedness: float = (
		weights.x * 0.18
		+ weights.y * 0.38
		+ weights.z * 0.62
		+ weights.w * 0.94
	)
	var flora_scale: float = (
		weights.x * 1.05
		+ weights.y * 1.18
		+ weights.z * 0.82
		+ weights.w * 0.50
	)
	flora_scale *= float(_planet_profile.get("flora_scale", 1.0))

	var dominant_name := "Lowland"
	var dominant_weight: float = weights.x
	if weights.y > dominant_weight:
		dominant_name = "Rolling Province"
		dominant_weight = weights.y
	if weights.z > dominant_weight:
		dominant_name = "High Plateau"
		dominant_weight = weights.z
	if weights.w > dominant_weight:
		dominant_name = "Rugged Belt"

	return {
		"name": dominant_name,
		"value": value,
		"weights": weights,
		"ruggedness": ruggedness,
		"flora_scale": flora_scale,
	}


func get_ecology_density(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> float:
	_ensure_v6_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)
	var ecology: float = _normalized_v6(_ecology_noise, world_x, world_z)
	var region_profile: Dictionary = get_region_profile(world_x, world_z)
	var region_scale: float = float(region_profile.get("flora_scale", 1.0))
	var altitude_scale: float = 1.0 - smoothstep(6.0, 12.5, terrain_height) * 0.84
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
	_ensure_v6_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)

	var sea_level: float = get_sea_level()
	var river: float = get_river_strength(world_x, world_z)
	var lake: float = get_lake_strength(world_x, world_z)
	var palette: float = _normalized_v6(_palette_noise, world_x, world_z)
	var ecology: float = get_ecology_density(world_x, world_z, terrain_height)
	var ruggedness: float = float(get_region_profile(world_x, world_z).get("ruggedness", 0.25))
	var water_influence: float = maxf(river, lake)

	if terrain_height < sea_level - 0.45:
		return Biome.OCEAN
	if terrain_height < sea_level + 0.55:
		return Biome.COAST
	if lake > 0.68 and terrain_height < sea_level + 1.65:
		return Biome.LAKE
	if river > 0.70 and terrain_height < 7.0:
		return Biome.RIVER
	if terrain_height > 12.4:
		return Biome.SNOW
	if terrain_height > 8.8:
		return Biome.ALPINE
	if ruggedness > 0.70 and terrain_height > 4.8:
		return Biome.ROCKY_HIGHLANDS
	if water_influence > 0.72 and ecology > 0.62 and terrain_height < 3.0:
		return Biome.SWAMP
	if water_influence > 0.48 and ecology > 0.52 and terrain_height < 3.8:
		return Biome.WETLAND
	if palette > 0.79 and ecology < 0.36:
		return Biome.DESERT
	if palette > 0.64 and ecology < 0.56:
		return Biome.SAVANNA
	if ecology > 0.80:
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
	_ensure_v6_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)
	var palette_data: Dictionary = _planet_profile.get("palette", {})
	var grass_color: Color = palette_data.get("grass", Color(0.30, 0.54, 0.28, 1.0))
	var forest_color: Color = palette_data.get("forest", Color(0.10, 0.34, 0.18, 1.0))
	var dry_color: Color = palette_data.get("dry", Color(0.64, 0.50, 0.24, 1.0))
	var coast_color: Color = palette_data.get("coast", Color(0.72, 0.61, 0.39, 1.0))
	var rock_color: Color = palette_data.get("rock", Color(0.37, 0.38, 0.39, 1.0))
	var snow_color: Color = palette_data.get("snow", Color(0.84, 0.88, 0.86, 1.0))
	var water_color: Color = palette_data.get("water", Color(0.04, 0.35, 0.44, 1.0))
	var sea_level: float = get_sea_level()

	if terrain_height < sea_level - 0.45:
		var ocean_depth: float = clampf((sea_level - terrain_height) / 7.0, 0.0, 1.0)
		return water_color.lerp(water_color.darkened(0.48), ocean_depth)

	var ecology: float = get_ecology_density(world_x, world_z, terrain_height)
	var dry_field: float = _normalized_v6(_palette_noise, world_x, world_z)
	var river: float = get_river_strength(world_x, world_z)
	var lake: float = get_lake_strength(world_x, world_z)
	var ruggedness: float = float(get_region_profile(world_x, world_z).get("ruggedness", 0.25))
	var forest_weight: float = smoothstep(0.40, 0.82, ecology)
	var dry_weight: float = smoothstep(0.52, 0.84, dry_field) * (1.0 - forest_weight * 0.60)
	var wet_weight: float = smoothstep(0.42, 0.82, maxf(river, lake)) * 0.62
	var rock_weight: float = clampf(
		smoothstep(4.8, 10.6, terrain_height) * lerpf(0.45, 1.0, ruggedness),
		0.0,
		1.0
	)
	var snow_weight: float = smoothstep(10.8, 14.3, terrain_height)
	var coast_weight: float = 1.0 - smoothstep(sea_level + 0.30, sea_level + 1.65, terrain_height)

	var color: Color = grass_color.lerp(forest_color, forest_weight)
	color = color.lerp(dry_color, dry_weight)
	color = color.lerp(grass_color.lerp(water_color, 0.26), wet_weight)
	color = color.lerp(coast_color, clampf(coast_weight, 0.0, 1.0))
	color = color.lerp(rock_color, rock_weight)
	color = color.lerp(snow_color, snow_weight)
	var detail: float = _color_detail_noise.get_noise_2d(world_x, world_z) * 0.045
	return Color(
		clampf(color.r + detail, 0.0, 1.0),
		clampf(color.g + detail, 0.0, 1.0),
		clampf(color.b + detail * 0.72, 0.0, 1.0),
		1.0
	)


func get_world_rock_color() -> Color:
	_ensure_v6_state()
	return _planet_profile.get("palette", {}).get("rock", Color(0.37, 0.38, 0.39, 1.0))


func get_world_grass_color() -> Color:
	_ensure_v6_state()
	return _planet_profile.get("palette", {}).get("grass", Color(0.30, 0.54, 0.28, 1.0))


func get_world_water_color() -> Color:
	_ensure_v6_state()
	return _planet_profile.get("palette", {}).get("water", Color(0.04, 0.35, 0.44, 1.0))


func get_tree_density_multiplier() -> float:
	_ensure_v6_state()
	return float(_planet_profile.get("flora_scale", 1.0))


func get_grass_density_multiplier() -> float:
	return get_tree_density_multiplier()


func get_rock_density_multiplier() -> float:
	_ensure_v6_state()
	return lerpf(0.82, 1.28, _seed_profile_value(127))


func get_species_seed(region_x: int, region_z: int, species_slot: int) -> int:
	_ensure_v6_state()
	return absi(
		get_world_seed()
		+ region_x * 73_856_093
		+ region_z * 19_349_663
		+ species_slot * 83_492_791
		+ 1_475_921_941
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
		"planet": str(_planet_profile.get("planet_name", "Unknown Planet")),
	}


func _get_region_weights(value: float) -> Vector4:
	var lowland: float = 1.0 - smoothstep(0.20, 0.42, value)
	var rolling: float = smoothstep(0.16, 0.38, value) * (1.0 - smoothstep(0.48, 0.68, value))
	var plateau: float = smoothstep(0.46, 0.66, value) * (1.0 - smoothstep(0.70, 0.88, value))
	var rugged: float = smoothstep(0.68, 0.88, value)
	var total: float = maxf(lowland + rolling + plateau + rugged, 0.0001)
	return Vector4(lowland, rolling, plateau, rugged) / total


func _ensure_v6_state() -> void:
	var seed_value: int = get_world_seed()
	if seed_value != _v6_seed:
		_configure_v6(seed_value)


func _configure_v6(seed_value: int) -> void:
	_v6_seed = seed_value
	_planet_profile = PlanetProfile.create(seed_value)
	_height_cache.clear()
	_setup_v6_noise(_region_noise, seed_value + 701, 0.00042, FastNoiseLite.FRACTAL_FBM, 3)
	_setup_v6_noise(_relief_noise, seed_value + 1709, 0.00115, FastNoiseLite.FRACTAL_RIDGED, 4)
	_setup_v6_noise(_warp_noise, seed_value + 2713, 0.00078, FastNoiseLite.FRACTAL_FBM, 3)
	_setup_v6_noise(_ecology_noise, seed_value + 3907, 0.00155, FastNoiseLite.FRACTAL_FBM, 4)
	_setup_v6_noise(_palette_noise, seed_value + 4513, 0.00120, FastNoiseLite.FRACTAL_FBM, 3)
	_setup_v6_noise(_micro_relief_noise, seed_value + 5231, 0.0240, FastNoiseLite.FRACTAL_FBM, 2)
	_setup_v6_noise(_color_detail_noise, seed_value + 6521, 0.0350, FastNoiseLite.FRACTAL_FBM, 2)


func _setup_v6_noise(
	noise: FastNoiseLite,
	seed_value: int,
	frequency: float,
	fractal: int,
	octaves: int
) -> void:
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = fractal
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	noise.domain_warp_enabled = true
	noise.domain_warp_amplitude = 28.0
	noise.domain_warp_frequency = frequency * 0.7


func _normalized_v6(noise: FastNoiseLite, x: float, z: float) -> float:
	return clampf(noise.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
