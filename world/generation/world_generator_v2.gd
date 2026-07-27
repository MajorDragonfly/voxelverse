extends Node

signal world_profile_changed(seed: int)

# Existing biome names keep their original meaning so the current terrain,
# object spawning and shader code remain compatible. New regions are appended.
enum Biome {
	OCEAN,
	COAST,
	GRASSLAND,
	WETLAND,
	COLD_GRASSLAND,
	STEPPE,
	ROCKY_HIGHLANDS,
	FOREST,
	DENSE_FOREST,
	SAVANNA,
	DESERT,
	SWAMP,
	ALPINE,
	SNOW,
	LAKE,
	RIVER,
}

const SEA_LEVEL: float = 0.0
const MIN_TERRAIN_HEIGHT: float = -7.0
const MAX_TERRAIN_HEIGHT: float = 18.0
const VISUAL_HEIGHT_STEP: float = 0.50
const DEFAULT_WORLD_SEED: int = 1

var _active_seed: int = -2_147_483_000
var _seed_override_enabled: bool = false
var _seed_override: int = DEFAULT_WORLD_SEED

var _continental_noise := FastNoiseLite.new()
var _macro_noise := FastNoiseLite.new()
var _mountain_region_noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _erosion_noise := FastNoiseLite.new()
var _temperature_noise := FastNoiseLite.new()
var _moisture_noise := FastNoiseLite.new()
var _river_noise := FastNoiseLite.new()
var _lake_noise := FastNoiseLite.new()
var _regional_tint_noise := FastNoiseLite.new()


func _ready() -> void:
	_ensure_noise_state()


func set_seed_override(new_seed: int) -> void:
	_seed_override_enabled = true
	_seed_override = new_seed
	_rebuild_noise_state(new_seed)


func clear_seed_override() -> void:
	_seed_override_enabled = false
	_rebuild_noise_state(_read_game_state_seed())


func set_world_seed(new_seed: int) -> void:
	_seed_override_enabled = false
	GameState.set("world_seed", new_seed)
	_rebuild_noise_state(new_seed)


func get_world_seed() -> int:
	_ensure_noise_state()
	return _active_seed


func regenerate_with_random_seed() -> int:
	var random := RandomNumberGenerator.new()
	random.randomize()
	var new_seed: int = random.randi_range(1, 2_000_000_000)
	set_world_seed(new_seed)
	return new_seed


func get_sea_level() -> float:
	return SEA_LEVEL


func get_terrain_height(world_x: float, world_z: float) -> float:
	_ensure_noise_state()

	var continentality: float = get_continentality(world_x, world_z)
	var land_mass: float = smoothstep(0.27, 0.72, continentality)
	var macro_shape: float = _macro_noise.get_noise_2d(world_x, world_z)
	var detail_shape: float = _detail_noise.get_noise_2d(world_x, world_z)
	var erosion: float = _normalized_noise(_erosion_noise, world_x, world_z)
	var mountain_region: float = smoothstep(
		0.48,
		0.78,
		_normalized_noise(_mountain_region_noise, world_x, world_z)
	)
	var ridge_sample: float = absf(_ridge_noise.get_noise_2d(world_x, world_z))
	var ridges: float = pow(1.0 - ridge_sample, 2.35)
	var mountain_mask: float = mountain_region * smoothstep(0.45, 0.78, land_mass)

	var terrain_height: float = SEA_LEVEL - 3.4
	terrain_height += land_mass * 6.1
	terrain_height += macro_shape * lerpf(0.75, 2.75, land_mass)
	terrain_height += detail_shape * lerpf(0.25, 1.10, land_mass)
	terrain_height += mountain_mask * ridges * lerpf(7.0, 12.5, erosion)

	# Erosion suppresses some ridges and opens broad valleys between ranges.
	var erosion_valley: float = smoothstep(0.05, 0.62, erosion)
	terrain_height -= mountain_mask * (1.0 - erosion_valley) * 2.4

	var river_strength: float = get_river_strength(world_x, world_z)
	var river_carve: float = river_strength * smoothstep(0.34, 0.72, land_mass)
	terrain_height -= river_carve * lerpf(1.1, 3.1, mountain_region)

	var lake_strength: float = get_lake_strength(world_x, world_z)
	var lake_target: float = SEA_LEVEL - lerpf(0.35, 1.25, lake_strength)
	terrain_height = lerpf(terrain_height, lake_target, lake_strength * 0.88)

	return clampf(terrain_height, MIN_TERRAIN_HEIGHT, MAX_TERRAIN_HEIGHT)


func get_visual_terrain_height(world_x: float, world_z: float) -> float:
	# Half-height terraces keep the voxel identity while avoiding Minecraft-like
	# full block staircases and making larger formations read more naturally.
	return snappedf(
		get_terrain_height(world_x, world_z),
		VISUAL_HEIGHT_STEP
	)


func get_continentality(world_x: float, world_z: float) -> float:
	_ensure_noise_state()
	var base_value: float = _normalized_noise(
		_continental_noise,
		world_x,
		world_z
	)
	# This curve produces substantial oceans, coastal shelves and broad interiors.
	return clampf(pow(base_value, 1.08), 0.0, 1.0)


func get_temperature(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> float:
	_ensure_noise_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)

	var regional: float = _normalized_noise(
		_temperature_noise,
		world_x,
		world_z
	)
	var latitude_wave: float = 0.5 + 0.5 * cos(world_z * 0.00085)
	var altitude_cooling: float = maxf(terrain_height - 3.0, 0.0) * 0.035

	return clampf(
		regional * 0.64 + latitude_wave * 0.36 - altitude_cooling,
		0.0,
		1.0
	)


func get_moisture(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> float:
	_ensure_noise_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)

	var regional: float = _normalized_noise(
		_moisture_noise,
		world_x,
		world_z
	)
	var river_bonus: float = get_river_strength(world_x, world_z) * 0.34
	var lake_bonus: float = get_lake_strength(world_x, world_z) * 0.42
	var coastal_bonus: float = 0.0

	if terrain_height < SEA_LEVEL + 1.8:
		coastal_bonus = 0.15

	return clampf(regional + river_bonus + lake_bonus + coastal_bonus, 0.0, 1.0)


func get_river_strength(world_x: float, world_z: float) -> float:
	_ensure_noise_state()
	var channel_distance: float = absf(
		_river_noise.get_noise_2d(world_x, world_z)
	)
	var channel: float = 1.0 - smoothstep(0.018, 0.105, channel_distance)
	var continent_mask: float = smoothstep(
		0.35,
		0.58,
		get_continentality(world_x, world_z)
	)
	return clampf(channel * continent_mask, 0.0, 1.0)


func get_lake_strength(world_x: float, world_z: float) -> float:
	_ensure_noise_state()
	var basin_noise: float = _normalized_noise(_lake_noise, world_x, world_z)
	var continent: float = get_continentality(world_x, world_z)
	var inland_mask: float = smoothstep(0.43, 0.60, continent)
	inland_mask *= 1.0 - smoothstep(0.78, 0.93, continent)
	var basin: float = smoothstep(0.78, 0.91, basin_noise)
	return clampf(basin * inland_mask, 0.0, 1.0)


func get_terrain_slope(
	world_x: float,
	world_z: float,
	sample_distance: float = 1.0
) -> float:
	var distance: float = maxf(sample_distance, 0.1)
	var west: float = get_terrain_height(world_x - distance, world_z)
	var east: float = get_terrain_height(world_x + distance, world_z)
	var north: float = get_terrain_height(world_x, world_z - distance)
	var south: float = get_terrain_height(world_x, world_z + distance)
	var gradient_x: float = absf(east - west) / (distance * 2.0)
	var gradient_z: float = absf(south - north) / (distance * 2.0)
	return clampf(Vector2(gradient_x, gradient_z).length(), 0.0, 2.0)


func get_biome(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> int:
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)

	var temperature: float = get_temperature(world_x, world_z, terrain_height)
	var moisture: float = get_moisture(world_x, world_z, terrain_height)
	var slope: float = get_terrain_slope(world_x, world_z, 1.25)
	var river_strength: float = get_river_strength(world_x, world_z)
	var lake_strength: float = get_lake_strength(world_x, world_z)

	if terrain_height < SEA_LEVEL - 0.45:
		return Biome.OCEAN
	if terrain_height < SEA_LEVEL + 0.55:
		if lake_strength > 0.56:
			return Biome.LAKE
		return Biome.COAST
	if river_strength > 0.66 and terrain_height < 7.5:
		return Biome.RIVER
	if lake_strength > 0.70 and terrain_height < SEA_LEVEL + 1.7:
		return Biome.LAKE
	if terrain_height > 12.0 or (terrain_height > 8.0 and temperature < 0.28):
		return Biome.SNOW
	if terrain_height > 8.2:
		return Biome.ALPINE
	if slope > 0.72 or (terrain_height > 5.7 and moisture < 0.48):
		return Biome.ROCKY_HIGHLANDS
	if moisture > 0.82 and terrain_height < 2.2:
		return Biome.SWAMP
	if temperature > 0.70 and moisture < 0.25:
		return Biome.DESERT
	if temperature > 0.62 and moisture < 0.48:
		return Biome.SAVANNA
	if moisture > 0.76 and temperature > 0.30:
		return Biome.DENSE_FOREST
	if moisture > 0.58 and temperature > 0.27:
		return Biome.FOREST
	if moisture > 0.72 and terrain_height < 3.2:
		return Biome.WETLAND
	if temperature < 0.29:
		return Biome.COLD_GRASSLAND
	if moisture < 0.38:
		return Biome.STEPPE
	return Biome.GRASSLAND


func get_biome_name(biome: int) -> String:
	match biome:
		Biome.OCEAN: return "Ocean"
		Biome.COAST: return "Coast"
		Biome.GRASSLAND: return "Grassland"
		Biome.WETLAND: return "Wetland"
		Biome.COLD_GRASSLAND: return "Cold Grassland"
		Biome.STEPPE: return "Steppe"
		Biome.ROCKY_HIGHLANDS: return "Rocky Highlands"
		Biome.FOREST: return "Forest"
		Biome.DENSE_FOREST: return "Dense Forest"
		Biome.SAVANNA: return "Savanna"
		Biome.DESERT: return "Desert"
		Biome.SWAMP: return "Swamp"
		Biome.ALPINE: return "Alpine"
		Biome.SNOW: return "Snow and Ice"
		Biome.LAKE: return "Lake District"
		Biome.RIVER: return "River Valley"
		_: return "Unknown"


func get_biome_color(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> Color:
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)

	var biome: int = get_biome(world_x, world_z, terrain_height)
	var base_color: Color

	match biome:
		Biome.OCEAN:
			base_color = Color(0.055, 0.19, 0.29, 1.0)
		Biome.COAST:
			base_color = Color(0.67, 0.58, 0.36, 1.0)
		Biome.GRASSLAND:
			base_color = Color(0.31, 0.49, 0.24, 1.0)
		Biome.WETLAND:
			base_color = Color(0.20, 0.39, 0.27, 1.0)
		Biome.COLD_GRASSLAND:
			base_color = Color(0.37, 0.48, 0.38, 1.0)
		Biome.STEPPE:
			base_color = Color(0.55, 0.49, 0.27, 1.0)
		Biome.ROCKY_HIGHLANDS:
			base_color = Color(0.36, 0.35, 0.33, 1.0)
		Biome.FOREST:
			base_color = Color(0.18, 0.38, 0.20, 1.0)
		Biome.DENSE_FOREST:
			base_color = Color(0.105, 0.29, 0.17, 1.0)
		Biome.SAVANNA:
			base_color = Color(0.58, 0.50, 0.25, 1.0)
		Biome.DESERT:
			base_color = Color(0.72, 0.57, 0.31, 1.0)
		Biome.SWAMP:
			base_color = Color(0.14, 0.29, 0.22, 1.0)
		Biome.ALPINE:
			base_color = Color(0.43, 0.45, 0.42, 1.0)
		Biome.SNOW:
			base_color = Color(0.78, 0.84, 0.84, 1.0)
		Biome.LAKE:
			base_color = Color(0.28, 0.47, 0.38, 1.0)
		Biome.RIVER:
			base_color = Color(0.24, 0.44, 0.29, 1.0)
		_:
			base_color = Color(0.35, 0.45, 0.28, 1.0)

	var tint_noise: float = _normalized_noise(
		_regional_tint_noise,
		world_x,
		world_z
	)
	var tint_amount: float = (tint_noise - 0.5) * 0.18

	if tint_amount >= 0.0:
		return base_color.lightened(tint_amount)
	return base_color.darkened(absf(tint_amount) * 0.72)


func get_biome_vegetation_density(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> float:
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)
	var biome: int = get_biome(world_x, world_z, terrain_height)
	match biome:
		Biome.DENSE_FOREST: return 1.0
		Biome.FOREST: return 0.78
		Biome.SWAMP: return 0.72
		Biome.WETLAND: return 0.68
		Biome.GRASSLAND: return 0.58
		Biome.RIVER: return 0.54
		Biome.SAVANNA: return 0.40
		Biome.COLD_GRASSLAND: return 0.34
		Biome.STEPPE: return 0.20
		Biome.ALPINE: return 0.10
		_: return 0.0


func get_world_rock_color() -> Color:
	_ensure_noise_state()
	var profile: float = _seed_profile_value(11)
	return Color(0.31, 0.30, 0.29, 1.0).lerp(
		Color(0.43, 0.35, 0.28, 1.0),
		profile
	)


func get_world_grass_color() -> Color:
	return Color(0.23, 0.43, 0.20, 1.0).lerp(
		Color(0.38, 0.49, 0.22, 1.0),
		_seed_profile_value(23)
	)


func get_world_water_color() -> Color:
	return Color(0.03, 0.24, 0.36, 1.0).lerp(
		Color(0.04, 0.34, 0.42, 1.0),
		_seed_profile_value(37)
	)


# Existing scenic systems request global density multipliers. They are varied
# per seed so different worlds differ in more than only their height map.
func get_tree_density_multiplier() -> float:
	return lerpf(0.82, 1.30, _seed_profile_value(101))


func get_grass_density_multiplier() -> float:
	return lerpf(0.80, 1.24, _seed_profile_value(109))


func get_rock_density_multiplier() -> float:
	return lerpf(0.78, 1.28, _seed_profile_value(127))


func get_ruin_density_multiplier() -> float:
	return lerpf(0.70, 1.18, _seed_profile_value(149))


func get_cliff_strength() -> float:
	return lerpf(0.82, 1.34, _seed_profile_value(163))


func get_region_random(world_x: float, world_z: float, salt: int = 0) -> float:
	_ensure_noise_state()
	var sample_x: float = world_x + float(salt) * 13.37
	var sample_z: float = world_z - float(salt) * 7.91
	return _normalized_noise(_regional_tint_noise, sample_x, sample_z)


func sample_world(world_x: float, world_z: float) -> Dictionary:
	var height: float = get_terrain_height(world_x, world_z)
	var biome: int = get_biome(world_x, world_z, height)
	return {
		"seed": get_world_seed(),
		"height": height,
		"visual_height": get_visual_terrain_height(world_x, world_z),
		"continentality": get_continentality(world_x, world_z),
		"temperature": get_temperature(world_x, world_z, height),
		"moisture": get_moisture(world_x, world_z, height),
		"slope": get_terrain_slope(world_x, world_z),
		"river": get_river_strength(world_x, world_z),
		"lake": get_lake_strength(world_x, world_z),
		"biome": biome,
		"biome_name": get_biome_name(biome),
	}


func _ensure_noise_state() -> void:
	var requested_seed: int = _seed_override if _seed_override_enabled else _read_game_state_seed()
	if requested_seed != _active_seed:
		_rebuild_noise_state(requested_seed)


func _read_game_state_seed() -> int:
	var seed_value: Variant = GameState.get("world_seed")
	if seed_value == null:
		return DEFAULT_WORLD_SEED
	return int(seed_value)


func _rebuild_noise_state(new_seed: int) -> void:
	_active_seed = new_seed

	_configure_noise(_continental_noise, 11, 0.00115, 5, FastNoiseLite.FRACTAL_FBM)
	_configure_noise(_macro_noise, 29, 0.0040, 4, FastNoiseLite.FRACTAL_FBM)
	_configure_noise(_mountain_region_noise, 47, 0.00185, 3, FastNoiseLite.FRACTAL_FBM)
	_configure_noise(_ridge_noise, 71, 0.0065, 5, FastNoiseLite.FRACTAL_RIDGED)
	_configure_noise(_detail_noise, 89, 0.0180, 3, FastNoiseLite.FRACTAL_FBM)
	_configure_noise(_erosion_noise, 107, 0.0032, 4, FastNoiseLite.FRACTAL_FBM)
	_configure_noise(_temperature_noise, 131, 0.0017, 3, FastNoiseLite.FRACTAL_FBM)
	_configure_noise(_moisture_noise, 157, 0.0022, 4, FastNoiseLite.FRACTAL_FBM)
	_configure_noise(_river_noise, 181, 0.0037, 3, FastNoiseLite.FRACTAL_FBM)
	_configure_noise(_lake_noise, 211, 0.0028, 3, FastNoiseLite.FRACTAL_FBM)
	_configure_noise(_regional_tint_noise, 239, 0.015, 2, FastNoiseLite.FRACTAL_FBM)

	world_profile_changed.emit(_active_seed)


func _configure_noise(
	noise: FastNoiseLite,
	seed_offset: int,
	frequency: float,
	octaves: int,
	fractal_type: int
) -> void:
	noise.seed = _active_seed + seed_offset * 1_000_003
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = fractal_type
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = 2.05
	noise.fractal_gain = 0.50
	noise.domain_warp_enabled = true
	noise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX_REDUCED
	noise.domain_warp_amplitude = 18.0
	noise.domain_warp_frequency = frequency * 0.55


func _normalized_noise(
	noise: FastNoiseLite,
	world_x: float,
	world_z: float
) -> float:
	return clampf(noise.get_noise_2d(world_x, world_z) * 0.5 + 0.5, 0.0, 1.0)


func _seed_profile_value(salt: int) -> float:
	_ensure_noise_state()
	var random := RandomNumberGenerator.new()
	random.seed = _active_seed + salt * 97_409
	return random.randf()
