extends Node


# Diese Werte definieren aktuell die grundlegende Weltform.
# Später werden sie durch Planetendaten und Weltprofile ersetzt.

const TERRAIN_FREQUENCY: float = 0.025
const TERRAIN_HEIGHT_SCALE: float = 6.0
const TERRAIN_OCTAVES: int = 5

const FLAT_SPAWN_RADIUS: float = 4.0
const SPAWN_BLEND_DISTANCE: float = 8.0

const TEMPERATURE_FREQUENCY: float = 0.0035
const MOISTURE_FREQUENCY: float = 0.0045


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

	# Nur um den Startpunkt der ersten Kreatur wird das Gelände
	# sanft abgeflacht.
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

	# Noise liefert ungefähr -1 bis +1.
	# Wir wandeln das in einen Wert von 0 bis 1 um.
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


func _ensure_initialized() -> void:
	if not _initialized:
		rebuild()
