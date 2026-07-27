extends "res://world/generation/world_generator_v2.gd"

# World Runtime V3 adds stable macro-regions on top of the continental terrain.
# The region field changes landform character over kilometres instead of merely
# changing local noise details, giving each seed recognizable provinces.

var _region_noise := FastNoiseLite.new()
var _relief_noise := FastNoiseLite.new()
var _warp_noise := FastNoiseLite.new()
var _v3_seed: int = -1


func _ready() -> void:
	super._ready()
	_ensure_v3_state()


func set_seed_override(new_seed: int) -> void:
	super.set_seed_override(new_seed)
	_configure_v3(new_seed)


func set_world_seed(new_seed: int) -> void:
	super.set_world_seed(new_seed)
	_configure_v3(new_seed)


func get_terrain_height(world_x: float, world_z: float) -> float:
	_ensure_v3_state()
	var warp_x: float = _warp_noise.get_noise_2d(world_x, world_z) * 140.0
	var warp_z: float = _warp_noise.get_noise_2d(world_x + 1700.0, world_z - 900.0) * 140.0
	var sample_x: float = world_x + warp_x
	var sample_z: float = world_z + warp_z
	var base_height: float = super.get_terrain_height(sample_x, sample_z)
	var region: float = _normalized_v3(_region_noise, world_x, world_z)
	var relief: float = _relief_noise.get_noise_2d(world_x, world_z)
	var inland: float = smoothstep(0.30, 0.68, super.get_continentality(sample_x, sample_z))

	# Broad provinces: rolling lowlands, plateaus and rugged belts. The effect is
	# intentionally masked near oceans to preserve coherent coastlines.
	var regional_height: float = 0.0
	if region < 0.28:
		regional_height = relief * 0.75 - 0.55
	elif region < 0.55:
		regional_height = relief * 1.35
	elif region < 0.78:
		regional_height = 1.25 + relief * 1.85
	else:
		regional_height = 2.1 + absf(relief) * 2.8

	return clampf(base_height + regional_height * inland, MIN_TERRAIN_HEIGHT, MAX_TERRAIN_HEIGHT)


func get_region_profile(world_x: float, world_z: float) -> Dictionary:
	_ensure_v3_state()
	var value: float = _normalized_v3(_region_noise, world_x, world_z)
	var region_name := "Lowland"
	var ruggedness := 0.25
	var flora_scale := 1.0
	if value >= 0.78:
		region_name = "Rugged Belt"
		ruggedness = 0.95
		flora_scale = 0.55
	elif value >= 0.55:
		region_name = "High Plateau"
		ruggedness = 0.62
		flora_scale = 0.72
	elif value >= 0.28:
		region_name = "Rolling Province"
		ruggedness = 0.42
		flora_scale = 1.08
	return {
		"name": region_name,
		"value": value,
		"ruggedness": ruggedness,
		"flora_scale": flora_scale,
	}


func _ensure_v3_state() -> void:
	var seed_value: int = get_world_seed()
	if seed_value != _v3_seed:
		_configure_v3(seed_value)


func _configure_v3(seed_value: int) -> void:
	_v3_seed = seed_value
	_setup_noise(_region_noise, seed_value + 701, 0.00042, FastNoiseLite.FRACTAL_FBM, 3)
	_setup_noise(_relief_noise, seed_value + 1709, 0.00115, FastNoiseLite.FRACTAL_RIDGED, 4)
	_setup_noise(_warp_noise, seed_value + 2713, 0.00078, FastNoiseLite.FRACTAL_FBM, 3)


func _setup_noise(
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
	noise.domain_warp_amplitude = 34.0
	noise.domain_warp_frequency = frequency * 0.7


func _normalized_v3(noise: FastNoiseLite, x: float, z: float) -> float:
	return clampf(noise.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
