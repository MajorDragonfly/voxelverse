extends Node


const WORLD_VISUAL_PROFILE_SCRIPT: Script = preload(
	"res://world/visuals/world_visual_profile.gd"
)


enum Biome {
	OCEAN,
	COAST,
	GRASSLAND,
	STEPPE,
	WETLAND,
	COLD_GRASSLAND,
	ROCKY_HIGHLANDS
}


# Grundwerte des Terrains.
#
# Das WorldVisualProfile verändert diese Werte
# reproduzierbar für jeden Welt-Seed.
const TERRAIN_FREQUENCY: float = 0.025
const TERRAIN_HEIGHT_SCALE: float = 6.0
const TERRAIN_OCTAVES: int = 5

# Fallback für den Fall, dass noch kein Profil existiert.
const TERRAIN_VISUAL_STEP_HEIGHT: float = 0.5

# Abstand für die Berechnung der Terrainsteigung.
const TERRAIN_SLOPE_SAMPLE_DISTANCE: float = 1.0

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

# Grenzwerte der logischen Biome.
const ROCKY_HEIGHT_MIN: float = 4.5
const COLD_TEMPERATURE_MAX: float = 0.32
const STEPPE_MOISTURE_MAX: float = 0.36
const WETLAND_MOISTURE_MIN: float = 0.68
const HOT_TEMPERATURE_MIN: float = 0.68
const HOT_STEPPE_MOISTURE_MAX: float = 0.50

# Fallback-Farben.
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


var _visual_profile

var _terrain_noise: FastNoiseLite
var _temperature_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite

var _initialized: bool = false


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	_initialized = false

	_create_visual_profile()
	_create_terrain_noise()
	_create_temperature_noise()
	_create_moisture_noise()

	_initialized = true

	print(
		"WorldGenerator initialized with seed: ",
		GameState.world_seed
	)

	_print_visual_profile()
	_print_spawn_biome()


func _create_visual_profile() -> void:
	_visual_profile = (
		WORLD_VISUAL_PROFILE_SCRIPT.new()
	)

	_visual_profile.generate_from_seed(
		GameState.world_seed
	)


func _create_terrain_noise() -> void:
	_terrain_noise = FastNoiseLite.new()

	_terrain_noise.seed = GameState.world_seed

	var frequency_multiplier: float = 1.0

	if _visual_profile != null:
		frequency_multiplier = (
			_visual_profile.terrain_frequency_multiplier
		)

	_terrain_noise.frequency = (
		TERRAIN_FREQUENCY
		* frequency_multiplier
	)

	_terrain_noise.fractal_octaves = TERRAIN_OCTAVES
	_terrain_noise.fractal_gain = 0.5
	_terrain_noise.fractal_lacunarity = 2.0


func _create_temperature_noise() -> void:
	_temperature_noise = FastNoiseLite.new()

	_temperature_noise.seed = (
		GameState.world_seed
		+ 10_001
	)

	_temperature_noise.frequency = TEMPERATURE_FREQUENCY
	_temperature_noise.fractal_octaves = 3
	_temperature_noise.fractal_gain = 0.5
	_temperature_noise.fractal_lacunarity = 2.0


func _create_moisture_noise() -> void:
	_moisture_noise = FastNoiseLite.new()

	_moisture_noise.seed = (
		GameState.world_seed
		+ 20_002
	)

	_moisture_noise.frequency = MOISTURE_FREQUENCY
	_moisture_noise.fractal_octaves = 4
	_moisture_noise.fractal_gain = 0.5
	_moisture_noise.fractal_lacunarity = 2.0


func get_visual_profile() -> Resource:
	_ensure_initialized()

	return _visual_profile as Resource


func get_world_archetype_name() -> String:
	_ensure_initialized()

	if _visual_profile == null:
		return "Default"

	return _visual_profile.archetype_name


func get_terrain_height_multiplier() -> float:
	_ensure_initialized()

	if _visual_profile == null:
		return 1.0

	return _visual_profile.terrain_height_multiplier


func get_cliff_strength() -> float:
	_ensure_initialized()

	if _visual_profile == null:
		return 1.0

	return _visual_profile.cliff_strength


func get_grass_density_multiplier() -> float:
	_ensure_initialized()

	if _visual_profile == null:
		return 1.0

	return _visual_profile.grass_density_multiplier


func get_rock_density_multiplier() -> float:
	_ensure_initialized()

	if _visual_profile == null:
		return 1.0

	return _visual_profile.rock_density_multiplier


func get_tree_density_multiplier() -> float:
	_ensure_initialized()

	if _visual_profile == null:
		return 1.0

	return _visual_profile.tree_density_multiplier


func get_ruin_density_multiplier() -> float:
	_ensure_initialized()

	if _visual_profile == null:
		return 1.0

	return _visual_profile.ruin_density_multiplier


func get_world_fog_color() -> Color:
	_ensure_initialized()

	if _visual_profile == null:
		return Color(
			0.65,
			0.72,
			0.76,
			1.0
		)

	return _visual_profile.fog_color


func get_world_fog_density_multiplier() -> float:
	_ensure_initialized()

	if _visual_profile == null:
		return 1.0

	return _visual_profile.fog_density_multiplier


func get_world_rock_color() -> Color:
	_ensure_initialized()

	if _visual_profile == null:
		return COLOR_ROCK

	return _visual_profile.color_rock


func get_terrain_height(
	world_x: float,
	world_z: float
) -> float:
	_ensure_initialized()

	var height_multiplier: float = 1.0

	if _visual_profile != null:
		height_multiplier = (
			_visual_profile.terrain_height_multiplier
		)

	var height := (
		_terrain_noise.get_noise_2d(
			world_x,
			world_z
		)
		* TERRAIN_HEIGHT_SCALE
		* height_multiplier
	)

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


func get_visual_terrain_height(
	world_x: float,
	world_z: float
) -> float:
	var logical_height := get_terrain_height(
		world_x,
		world_z
	)

	var step_height := maxf(
		get_visual_step_height(),
		0.05
	)

	return (
		roundf(
			logical_height
			/ step_height
		)
		* step_height
	)


func get_visual_step_height() -> float:
	_ensure_initialized()

	if _visual_profile == null:
		return TERRAIN_VISUAL_STEP_HEIGHT

	return _visual_profile.terrace_step_height


func get_terrain_slope(
	world_x: float,
	world_z: float,
	sample_distance: float = TERRAIN_SLOPE_SAMPLE_DISTANCE
) -> float:
	var safe_sample_distance := maxf(
		sample_distance,
		0.01
	)

	var height_left := get_visual_terrain_height(
		world_x - safe_sample_distance,
		world_z
	)

	var height_right := get_visual_terrain_height(
		world_x + safe_sample_distance,
		world_z
	)

	var height_back := get_visual_terrain_height(
		world_x,
		world_z - safe_sample_distance
	)

	var height_forward := get_visual_terrain_height(
		world_x,
		world_z + safe_sample_distance
	)

	var slope_x := (
		height_right
		- height_left
	) / (
		2.0
		* safe_sample_distance
	)

	var slope_z := (
		height_forward
		- height_back
	) / (
		2.0
		* safe_sample_distance
	)

	return Vector2(
		slope_x,
		slope_z
	).length()


func get_terrain_slope_degrees(
	world_x: float,
	world_z: float,
	sample_distance: float = TERRAIN_SLOPE_SAMPLE_DISTANCE
) -> float:
	var slope_factor := get_terrain_slope(
		world_x,
		world_z,
		sample_distance
	)

	return rad_to_deg(
		atan(slope_factor)
	)


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
	_ensure_initialized()

	var ocean_floor_color := COLOR_OCEAN_FLOOR
	var coast_color := COLOR_COAST
	var grassland_color := COLOR_GRASSLAND
	var dry_color := COLOR_DRY
	var wet_color := COLOR_WET
	var cold_color := COLOR_COLD
	var rock_color := COLOR_ROCK

	if _visual_profile != null:
		ocean_floor_color = (
			_visual_profile.color_ocean_floor
		)

		coast_color = (
			_visual_profile.color_coast
		)

		grassland_color = (
			_visual_profile.color_grassland
		)

		dry_color = (
			_visual_profile.color_dry
		)

		wet_color = (
			_visual_profile.color_wet
		)

		cold_color = (
			_visual_profile.color_cold
		)

		rock_color = (
			_visual_profile.color_rock
		)

	if terrain_height < SEA_LEVEL:
		var depth_factor := clampf(
			(
				SEA_LEVEL
				- terrain_height
			)
			/ DEEP_SEABED_DEPTH,
			0.0,
			1.0
		)

		return coast_color.lerp(
			ocean_floor_color,
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

	var biome_color := grassland_color

	var dry_factor := (
		1.0
		- smoothstep(
			0.30,
			0.50,
			moisture
		)
	)

	biome_color = biome_color.lerp(
		dry_color,
		dry_factor
	)

	var wet_factor := smoothstep(
		0.58,
		0.76,
		moisture
	)

	biome_color = biome_color.lerp(
		wet_color,
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
		cold_color,
		cold_factor
	)

	var rock_factor := smoothstep(
		3.0,
		5.5,
		terrain_height
	)

	biome_color = biome_color.lerp(
		rock_color,
		rock_factor
	)

	if terrain_height <= SEA_LEVEL + COAST_WIDTH:
		var coast_factor := smoothstep(
			SEA_LEVEL,
			SEA_LEVEL + COAST_WIDTH,
			terrain_height
		)

		return coast_color.lerp(
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

	temperature -= (
		maxf(
			terrain_height,
			0.0
		)
		* HEIGHT_TEMPERATURE_LOSS
	)

	return clampf(
		temperature,
		0.0,
		1.0
	)


func _print_visual_profile() -> void:
	if _visual_profile == null:
		print(
			"World visual profile: Default"
		)
		return

	print(
		"World visual profile: ",
		_visual_profile.archetype_name
	)

	print(
		"Terrain height multiplier: ",
		snappedf(
			_visual_profile.terrain_height_multiplier,
			0.01
		)
	)

	print(
		"Visual terrain step height: ",
		_visual_profile.terrace_step_height
	)

	print(
		"Scenery multipliers - grass: ",
		snappedf(
			_visual_profile.grass_density_multiplier,
			0.01
		),
		", rock: ",
		snappedf(
			_visual_profile.rock_density_multiplier,
			0.01
		),
		", tree: ",
		snappedf(
			_visual_profile.tree_density_multiplier,
			0.01
		),
		", ruin: ",
		snappedf(
			_visual_profile.ruin_density_multiplier,
			0.01
		)
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
