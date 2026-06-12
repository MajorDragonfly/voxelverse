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


# Grundform des Geländes.
const TERRAIN_FREQUENCY: float = 0.025
const TERRAIN_HEIGHT_SCALE: float = 6.0
const TERRAIN_OCTAVES: int = 5

# Abgeflachter Startbereich.
const FLAT_SPAWN_RADIUS: float = 4.0
const SPAWN_BLEND_DISTANCE: float = 8.0

# Meer und Küsten.
const SEA_LEVEL: float = -1.5
const COAST_WIDTH: float = 1.0
const DEEP_SEABED_DEPTH: float = 2.5

# Großräumige Klimaverteilung.
const TEMPERATURE_FREQUENCY: float = 0.004
const MOISTURE_FREQUENCY: float = 0.005

# Höhenabhängige Abkühlung.
const HEIGHT_TEMPERATURE_LOSS: float = 0.035

# Grenzwerte für die logischen Biome.
const ROCKY_HEIGHT_MIN: float = 4.5
const COLD_TEMPERATURE_MAX: float = 0.32
const STEPPE_MOISTURE_MAX: float = 0.36
const WETLAND_MOISTURE_MIN: float = 0.68
const HOT_TEMPERATURE_MIN: float = 0.68
const HOT_STEPPE_MOISTURE_MAX: float = 0.50

# Vorläufige Biomfarben.
const COLOR_OCEAN_FLOOR: Color = Color(
	0.14,
	0.24,
	0.22,
	1.0
)

const COLOR_COAST: Color = Color(
	0.68,
	0.60,
	0.34,
	1.0
)

const COLOR_GRASSLAND: Color = Color(
	0.18,
	0.48,
	0.12,
	1.0
)

const COLOR_DRY: Color = Color(
	0.58,
	0.46,
	0.20,
	1.0
)

const COLOR_WET: Color = Color(
	0.07,
	0.30,
	0.10,
	1.0
)

const COLOR_COLD: Color = Color(
	0.38,
	0.52,
	0.42,
	1.0
)

const COLOR_ROCK: Color = Color(
	0.34,
	0.34,
	0.32,
	1.0
)


var _terrain_noise: FastNoiseLite
var _temperature_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite

var _initialized: bool = false


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	_create_terrain_noise()
	_create_temperature_noise()
	_create_moisture_noise()

	_initialized = true

	print(
		"WorldGenerator initialized with seed: ",
		GameState.world_seed
	)

	_print_spawn_biome()


func _create_terrain_noise() -> void:
	_terrain_noise = FastNoiseLite.new()

	_terrain_noise.seed = GameState.world_seed
	_terrain_noise.frequency = TERRAIN_FREQUENCY
	_terrain_noise.fractal_octaves = TERRAIN_OCTAVES
	_terrain_noise.fractal_gain = 0.5
	_terrain_noise.fractal_lacunarity = 2.0


func _create_temperature_noise() -> void:
	_temperature_noise = FastNoiseLite.new()

	_temperature_noise.seed = GameState.world_seed + 10_001
	_temperature_noise.frequency = TEMPERATURE_FREQUENCY
	_temperature_noise.fractal_octaves = 3
	_temperature_noise.fractal_gain = 0.5
	_temperature_noise.fractal_lacunarity = 2.0


func _create_moisture_noise() -> void:
	_moisture_noise = FastNoiseLite.new()

	_moisture_noise.seed = GameState.world_seed + 20_002
	_moisture_noise.frequency = MOISTURE_FREQUENCY
	_moisture_noise.fractal_octaves = 4
	_moisture_noise.fractal_gain = 0.5
	_moisture_noise.fractal_lacunarity = 2.0


func get_terrain_height(
	world_x: float,
	world_z: float
) -> float:
	_ensure_initialized()

	var height := _terrain_noise.get_noise_2d(
		world_x,
		world_z
	) * TERRAIN_HEIGHT_SCALE

	var distance_to_spawn := Vector2(
		world_x,
		world_z
	).length()

	var flatten_factor := smoothstep(
		FLAT_SPAWN_RADIUS,
		FLAT_SPAWN_RADIUS + SPAWN_BLEND_DISTANCE,
		distance_to_spawn
	)

	return height * flatten_factor


func get_temperature(
	world_x: float,
	world_z: float
) -> float:
	_ensure_initialized()

	var noise_value := _temperature_noise.get_noise_2d(
		world_x,
		world_z
	)

	return clampf(
		(noise_value + 1.0) * 0.5,
		0.0,
		1.0
	)


func get_moisture(
	world_x: float,
	world_z: float
) -> float:
	_ensure_initialized()

	var noise_value := _moisture_noise.get_noise_2d(
		world_x,
		world_z
	)

	return clampf(
		(noise_value + 1.0) * 0.5,
		0.0,
		1.0
	)


func get_sea_level() -> float:
	return SEA_LEVEL


func is_below_sea_level(
	world_x: float,
	world_z: float
) -> bool:
	return get_terrain_height(
		world_x,
		world_z
	) < SEA_LEVEL


func get_biome(
	world_x: float,
	world_z: float,
	terrain_height: float
) -> int:
	# Meer und Küste haben Vorrang vor den Landbiomen.
	if terrain_height < SEA_LEVEL:
		return Biome.OCEAN

	if terrain_height <= SEA_LEVEL + COAST_WIDTH:
		return Biome.COAST

	var temperature := _get_adjusted_temperature(
		world_x,
		world_z,
		terrain_height
	)

	var moisture := get_moisture(
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
	# Gelände unterhalb der Meereshöhe wird zum Meeresboden.
	if terrain_height < SEA_LEVEL:
		var depth_factor := clampf(
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

	var temperature := _get_adjusted_temperature(
		world_x,
		world_z,
		terrain_height
	)

	var moisture := get_moisture(
		world_x,
		world_z
	)

	var biome_color := COLOR_GRASSLAND

	var dry_factor := (
		1.0
		- smoothstep(
			0.30,
			0.50,
			moisture
		)
	)

	biome_color = biome_color.lerp(
		COLOR_DRY,
		dry_factor
	)

	var wet_factor := smoothstep(
		0.58,
		0.76,
		moisture
	)

	biome_color = biome_color.lerp(
		COLOR_WET,
		wet_factor
	)

	var cold_factor := (
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

	var rock_factor := smoothstep(
		3.0,
		5.5,
		terrain_height
	)

	biome_color = biome_color.lerp(
		COLOR_ROCK,
		rock_factor
	)

	# Übergang von Sand zu normalem Land.
	if terrain_height <= SEA_LEVEL + COAST_WIDTH:
		var coast_factor := smoothstep(
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
	var temperature := get_temperature(
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


func _print_spawn_biome() -> void:
	var spawn_height := get_terrain_height(
		0.0,
		0.0
	)

	var spawn_biome := get_biome(
		0.0,
		0.0,
		spawn_height
	)

	print(
		"Spawn biome: ",
		get_biome_name(spawn_biome)
	)

	print(
		"Sea level: ",
		SEA_LEVEL
	)


func _ensure_initialized() -> void:
	if not _initialized:
		rebuild()
