extends Node


enum Biome {
	OCEAN,
	COAST,
	GRASSLAND,
	STEPPE,
	WETLAND,
	COLD_GRASSLAND,
	ROCKY_HIGHLANDS
}


# Meer und Küsten.
const SEA_LEVEL: float = -1.5
const COAST_WIDTH: float = 1.2
const DEEP_SEABED_DEPTH: float = 4.0

# Sicherer Startbereich.
const FLAT_SPAWN_RADIUS: float = 6.0
const SPAWN_BLEND_DISTANCE: float = 16.0

# Großräumige Kontinente.
const CONTINENT_FREQUENCY: float = 0.0018
const CONTINENT_OCEAN_THRESHOLD: float = 0.38
const CONTINENT_LAND_THRESHOLD: float = 0.62
const DEEP_OCEAN_HEIGHT: float = -5.5
const CONTINENT_LAND_HEIGHT: float = 2.2

# Regionale Hügel und Täler.
const REGIONAL_FREQUENCY: float = 0.006
const REGIONAL_HEIGHT_SCALE: float = 4.0

# Bergketten.
const RIDGE_FREQUENCY: float = 0.0034
const RIDGE_HEIGHT_SCALE: float = 11.0
const RIDGE_START: float = 0.48
const RIDGE_END: float = 0.82

# Trockene Plateaus und Mesas.
const MESA_FREQUENCY: float = 0.0026
const MESA_HEIGHT_SCALE: float = 8.0
const MESA_START: float = 0.58
const MESA_END: float = 0.82
const MESA_TERRACE_COUNT: float = 6.0

# Schluchten und Flusstäler.
const VALLEY_FREQUENCY: float = 0.0045
const VALLEY_WIDTH: float = 0.16
const VALLEY_DEPTH: float = 5.5

# Kleine Oberflächendetails.
const DETAIL_FREQUENCY: float = 0.028
const DETAIL_HEIGHT_SCALE: float = 1.15

# Unregelmäßigkeit großer Formen.
const EROSION_FREQUENCY: float = 0.011

# Temperatur und Feuchtigkeit.
const TEMPERATURE_FREQUENCY: float = 0.004
const MOISTURE_FREQUENCY: float = 0.005
const HEIGHT_TEMPERATURE_LOSS: float = 0.025

# Biomgrenzen.
const ROCKY_HEIGHT_MIN: float = 7.0
const COLD_TEMPERATURE_MAX: float = 0.32
const STEPPE_MOISTURE_MAX: float = 0.36
const WETLAND_MOISTURE_MIN: float = 0.68
const HOT_TEMPERATURE_MIN: float = 0.68
const HOT_STEPPE_MOISTURE_MAX: float = 0.50

# Warme, stilisierte Grundfarben.
const COLOR_OCEAN_FLOOR: Color = Color(
	0.10,
	0.20,
	0.20,
	1.0
)

const COLOR_COAST: Color = Color(
	0.72,
	0.59,
	0.35,
	1.0
)

const COLOR_GRASSLAND: Color = Color(
	0.24,
	0.46,
	0.16,
	1.0
)

const COLOR_DRY: Color = Color(
	0.64,
	0.46,
	0.23,
	1.0
)

const COLOR_WET: Color = Color(
	0.07,
	0.28,
	0.11,
	1.0
)

const COLOR_COLD: Color = Color(
	0.38,
	0.50,
	0.43,
	1.0
)

const COLOR_ROCK: Color = Color(
	0.43,
	0.29,
	0.21,
	1.0
)

const COLOR_HIGH_ROCK: Color = Color(
	0.36,
	0.34,
	0.32,
	1.0
)


var _continent_noise: FastNoiseLite
var _regional_noise: FastNoiseLite
var _ridge_noise: FastNoiseLite
var _mesa_noise: FastNoiseLite
var _valley_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _erosion_noise: FastNoiseLite

var _temperature_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite

var _initialized: bool = false


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	_continent_noise = _create_noise(
		1_001,
		CONTINENT_FREQUENCY,
		4,
		FastNoiseLite.FRACTAL_FBM
	)

	_regional_noise = _create_noise(
		2_002,
		REGIONAL_FREQUENCY,
		4,
		FastNoiseLite.FRACTAL_FBM
	)

	_ridge_noise = _create_noise(
		3_003,
		RIDGE_FREQUENCY,
		5,
		FastNoiseLite.FRACTAL_RIDGED
	)

	_mesa_noise = _create_noise(
		4_004,
		MESA_FREQUENCY,
		4,
		FastNoiseLite.FRACTAL_FBM
	)

	_valley_noise = _create_noise(
		5_005,
		VALLEY_FREQUENCY,
		3,
		FastNoiseLite.FRACTAL_FBM
	)

	_detail_noise = _create_noise(
		6_006,
		DETAIL_FREQUENCY,
		4,
		FastNoiseLite.FRACTAL_FBM
	)

	_erosion_noise = _create_noise(
		7_007,
		EROSION_FREQUENCY,
		3,
		FastNoiseLite.FRACTAL_FBM
	)

	_temperature_noise = _create_noise(
		10_001,
		TEMPERATURE_FREQUENCY,
		4,
		FastNoiseLite.FRACTAL_FBM
	)

	_moisture_noise = _create_noise(
		20_002,
		MOISTURE_FREQUENCY,
		4,
		FastNoiseLite.FRACTAL_FBM
	)

	_initialized = true

	print(
		"WorldGenerator initialized with layered planetary terrain. Seed: ",
		GameState.world_seed
	)

	_print_spawn_biome()


func _create_noise(
	seed_offset: int,
	frequency: float,
	octaves: int,
	fractal_type: FastNoiseLite.FractalType
) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()

	noise.seed = GameState.world_seed + seed_offset
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency

	noise.fractal_type = fractal_type
	noise.fractal_octaves = octaves
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0

	return noise


func get_terrain_height(
	world_x: float,
	world_z: float
) -> float:
	_ensure_initialized()

	var continent_value: float = _to_unit(
		_continent_noise.get_noise_2d(
			world_x,
			world_z
		)
	)

	var land_factor: float = smoothstep(
		CONTINENT_OCEAN_THRESHOLD,
		CONTINENT_LAND_THRESHOLD,
		continent_value
	)

	var base_height: float = lerpf(
		DEEP_OCEAN_HEIGHT,
		CONTINENT_LAND_HEIGHT,
		land_factor
	)

	var regional_value: float = (
		_regional_noise.get_noise_2d(
			world_x,
			world_z
		)
	)

	var regional_height: float = (
		regional_value
		* REGIONAL_HEIGHT_SCALE
		* land_factor
	)

	var erosion_value: float = _to_unit(
		_erosion_noise.get_noise_2d(
			world_x,
			world_z
		)
	)

	var erosion_strength: float = lerpf(
		0.55,
		1.0,
		erosion_value
	)

	var ridge_value: float = _to_unit(
		_ridge_noise.get_noise_2d(
			world_x,
			world_z
		)
	)

	var ridge_mask: float = smoothstep(
		RIDGE_START,
		RIDGE_END,
		ridge_value
	)

	var ridge_height: float = (
		pow(
			ridge_mask,
			1.45
		)
		* RIDGE_HEIGHT_SCALE
		* land_factor
		* erosion_strength
	)

	var moisture_value: float = _to_unit(
		_moisture_noise.get_noise_2d(
			world_x,
			world_z
		)
	)

	var dryness: float = (
		1.0
		- smoothstep(
			0.42,
			0.68,
			moisture_value
		)
	)

	var mesa_value: float = _to_unit(
		_mesa_noise.get_noise_2d(
			world_x,
			world_z
		)
	)

	var mesa_mask: float = (
		smoothstep(
			MESA_START,
			MESA_END,
			mesa_value
		)
		* dryness
		* land_factor
	)

	var mesa_steps: float = (
		floorf(
			mesa_value
			* MESA_TERRACE_COUNT
		)
		/ MESA_TERRACE_COUNT
	)

	var mesa_height: float = (
		mesa_mask
		* (
			2.0
			+ mesa_steps
			* MESA_HEIGHT_SCALE
		)
		* erosion_strength
	)

	var valley_value: float = absf(
		_valley_noise.get_noise_2d(
			world_x,
			world_z
		)
	)

	var valley_mask: float = (
		1.0
		- smoothstep(
			0.015,
			VALLEY_WIDTH,
			valley_value
		)
	)

	var valley_dryness_multiplier: float = lerpf(
		0.70,
		1.0,
		dryness
	)

	var valley_depth: float = (
		valley_mask
		* VALLEY_DEPTH
		* land_factor
		* valley_dryness_multiplier
	)

	var detail_height: float = (
		_detail_noise.get_noise_2d(
			world_x,
			world_z
		)
		* DETAIL_HEIGHT_SCALE
		* lerpf(
			0.35,
			1.0,
			land_factor
		)
	)

	var terrain_height: float = (
		base_height
		+ regional_height
		+ ridge_height
		+ mesa_height
		- valley_depth
		+ detail_height
	)

	terrain_height = clampf(
		terrain_height,
		-8.0,
		22.0
	)

	var distance_to_spawn: float = Vector2(
		world_x,
		world_z
	).length()

	var spawn_blend: float = smoothstep(
		FLAT_SPAWN_RADIUS,
		FLAT_SPAWN_RADIUS
			+ SPAWN_BLEND_DISTANCE,
		distance_to_spawn
	)

	return lerpf(
		0.0,
		terrain_height,
		spawn_blend
	)


func get_terrain_slope(
	world_x: float,
	world_z: float,
	sample_distance: float = 1.0
) -> float:
	var safe_distance: float = maxf(
		sample_distance,
		0.1
	)

	var height_left: float = get_terrain_height(
		world_x - safe_distance,
		world_z
	)

	var height_right: float = get_terrain_height(
		world_x + safe_distance,
		world_z
	)

	var height_back: float = get_terrain_height(
		world_x,
		world_z - safe_distance
	)

	var height_forward: float = get_terrain_height(
		world_x,
		world_z + safe_distance
	)

	var gradient_x: float = (
		height_right - height_left
	) / (
		safe_distance * 2.0
	)

	var gradient_z: float = (
		height_forward - height_back
	) / (
		safe_distance * 2.0
	)

	return Vector2(
		gradient_x,
		gradient_z
	).length()


func get_temperature(
	world_x: float,
	world_z: float
) -> float:
	_ensure_initialized()

	return _to_unit(
		_temperature_noise.get_noise_2d(
			world_x,
			world_z
		)
	)


func get_moisture(
	world_x: float,
	world_z: float
) -> float:
	_ensure_initialized()

	return _to_unit(
		_moisture_noise.get_noise_2d(
			world_x,
			world_z
		)
	)


func get_sea_level() -> float:
	return SEA_LEVEL


func is_below_sea_level(
	world_x: float,
	world_z: float
) -> bool:
	return (
		get_terrain_height(
			world_x,
			world_z
		)
		< SEA_LEVEL
	)


func get_biome(
	world_x: float,
	world_z: float,
	terrain_height: float
) -> int:
	if terrain_height < SEA_LEVEL:
		return Biome.OCEAN

	if terrain_height <= SEA_LEVEL + COAST_WIDTH:
		return Biome.COAST

	var temperature: float = _get_adjusted_temperature(
		world_x,
		world_z,
		terrain_height
	)

	var moisture: float = get_moisture(
		world_x,
		world_z
	)

	if terrain_height >= ROCKY_HEIGHT_MIN:
		return Biome.ROCKY_HIGHLANDS

	if temperature <= COLD_TEMPERATURE_MAX:
		return Biome.COLD_GRASSLAND

	if moisture >= WETLAND_MOISTURE_MIN:
		return Biome.WETLAND

	if (
		moisture <= STEPPE_MOISTURE_MAX
		or (
			temperature >= HOT_TEMPERATURE_MIN
			and moisture <= HOT_STEPPE_MOISTURE_MAX
		)
	):
		return Biome.STEPPE

	return Biome.GRASSLAND


func get_biome_name(
	biome: int
) -> String:
	match biome:
		Biome.OCEAN:
			return "Ocean"

		Biome.COAST:
			return "Coast"

		Biome.GRASSLAND:
			return "Grassland"

		Biome.STEPPE:
			return "Steppe"

		Biome.WETLAND:
			return "Wetland"

		Biome.COLD_GRASSLAND:
			return "Cold Grassland"

		Biome.ROCKY_HIGHLANDS:
			return "Rocky Highlands"

		_:
			return "Unknown"


func get_biome_color(
	world_x: float,
	world_z: float,
	terrain_height: float
) -> Color:
	if terrain_height < SEA_LEVEL:
		var depth_factor: float = clampf(
			(
				SEA_LEVEL
				- terrain_height
			) / DEEP_SEABED_DEPTH,
			0.0,
			1.0
		)

		return COLOR_COAST.lerp(
			COLOR_OCEAN_FLOOR,
			depth_factor
		)

	var temperature: float = _get_adjusted_temperature(
		world_x,
		world_z,
		terrain_height
	)

	var moisture: float = get_moisture(
		world_x,
		world_z
	)

	var biome_color: Color = COLOR_GRASSLAND

	var dry_factor: float = (
		1.0
		- smoothstep(
			0.30,
			0.52,
			moisture
		)
	)

	biome_color = biome_color.lerp(
		COLOR_DRY,
		dry_factor
	)

	var wet_factor: float = smoothstep(
		0.58,
		0.78,
		moisture
	)

	biome_color = biome_color.lerp(
		COLOR_WET,
		wet_factor
	)

	var cold_factor: float = (
		1.0
		- smoothstep(
			0.28,
			0.46,
			temperature
		)
	)

	biome_color = biome_color.lerp(
		COLOR_COLD,
		cold_factor
	)

	var rock_factor: float = smoothstep(
		5.0,
		11.5,
		terrain_height
	)

	var high_rock_factor: float = smoothstep(
		13.0,
		19.0,
		terrain_height
	)

	var warm_rock_color: Color = COLOR_ROCK.lerp(
		COLOR_HIGH_ROCK,
		high_rock_factor
	)

	biome_color = biome_color.lerp(
		warm_rock_color,
		rock_factor
	)

	if terrain_height <= SEA_LEVEL + COAST_WIDTH:
		var coast_factor: float = smoothstep(
			SEA_LEVEL,
			SEA_LEVEL + COAST_WIDTH,
			terrain_height
		)

		return COLOR_COAST.lerp(
			biome_color,
			coast_factor
		)

	return biome_color


func _get_adjusted_temperature(
	world_x: float,
	world_z: float,
	terrain_height: float
) -> float:
	var temperature: float = get_temperature(
		world_x,
		world_z
	)

	temperature -= maxf(
		terrain_height,
		0.0
	) * HEIGHT_TEMPERATURE_LOSS

	return clampf(
		temperature,
		0.0,
		1.0
	)


func _to_unit(
	noise_value: float
) -> float:
	return clampf(
		(
			noise_value + 1.0
		) * 0.5,
		0.0,
		1.0
	)


func _print_spawn_biome() -> void:
	var spawn_height: float = get_terrain_height(
		0.0,
		0.0
	)

	var spawn_biome: int = get_biome(
		0.0,
		0.0,
		spawn_height
	)

	print(
		"Spawn biome: ",
		get_biome_name(
			spawn_biome
		)
	)

	print(
		"Sea level: ",
		SEA_LEVEL
	)


func _ensure_initialized() -> void:
	if not _initialized:
		rebuild()
