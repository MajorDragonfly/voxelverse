extends Resource
class_name WorldVisualProfile


enum TerrainArchetype {
	VERDANT_HIGHLANDS,
	AMBER_STEPPES,
	SLATE_WILDS,
	RED_MESAS,
	PALE_TUNDRA
}


const PROFILE_SEED_OFFSET: int = 903_157_411
const TERRAIN_ARCHETYPE_COUNT: int = 5


var world_seed: int = 0

var archetype: int = TerrainArchetype.VERDANT_HIGHLANDS
var archetype_name: String = "Verdant Highlands"

# Landschaftsform.
var terrain_height_multiplier: float = 1.0
var terrain_frequency_multiplier: float = 1.0
var terrace_step_height: float = 0.5
var cliff_strength: float = 1.0

# Diese Werte werden in den nächsten Schritten
# mit den jeweiligen Generatoren verbunden.
var grass_density_multiplier: float = 1.0
var rock_density_multiplier: float = 1.0
var tree_density_multiplier: float = 1.0
var ruin_density_multiplier: float = 1.0

# Atmosphärenwerte für den späteren Environment-Schritt.
var fog_density_multiplier: float = 1.0
var fog_color: Color = Color(
	0.65,
	0.72,
	0.76,
	1.0
)

# Kuratierte Weltpalette.
var color_ocean_floor: Color = Color(
	0.14,
	0.24,
	0.22,
	1.0
)

var color_coast: Color = Color(
	0.68,
	0.60,
	0.34,
	1.0
)

var color_grassland: Color = Color(
	0.18,
	0.48,
	0.12,
	1.0
)

var color_dry: Color = Color(
	0.58,
	0.46,
	0.20,
	1.0
)

var color_wet: Color = Color(
	0.07,
	0.30,
	0.10,
	1.0
)

var color_cold: Color = Color(
	0.38,
	0.52,
	0.42,
	1.0
)

var color_rock: Color = Color(
	0.34,
	0.34,
	0.32,
	1.0
)


func generate_from_seed(
	seed_value: int
) -> void:
	world_seed = seed_value

	var random := RandomNumberGenerator.new()

	random.seed = (
		seed_value
		+ PROFILE_SEED_OFFSET
	)

	archetype = random.randi_range(
		0,
		TERRAIN_ARCHETYPE_COUNT - 1
	)

	_apply_archetype_preset(
		archetype
	)

	_apply_seed_variation(
		random
	)


func _apply_archetype_preset(
	selected_archetype: int
) -> void:
	match selected_archetype:
		TerrainArchetype.VERDANT_HIGHLANDS:
			_apply_verdant_highlands()

		TerrainArchetype.AMBER_STEPPES:
			_apply_amber_steppes()

		TerrainArchetype.SLATE_WILDS:
			_apply_slate_wilds()

		TerrainArchetype.RED_MESAS:
			_apply_red_mesas()

		TerrainArchetype.PALE_TUNDRA:
			_apply_pale_tundra()

		_:
			_apply_verdant_highlands()


func _apply_verdant_highlands() -> void:
	archetype_name = "Verdant Highlands"

	terrain_height_multiplier = 1.05
	terrain_frequency_multiplier = 0.92
	terrace_step_height = 0.40
	cliff_strength = 0.85

	grass_density_multiplier = 1.30
	rock_density_multiplier = 0.75
	tree_density_multiplier = 1.25
	ruin_density_multiplier = 0.70

	fog_density_multiplier = 1.05
	fog_color = Color(
		0.61,
		0.72,
		0.68,
		1.0
	)

	color_ocean_floor = Color(
		0.10,
		0.22,
		0.20,
		1.0
	)

	color_coast = Color(
		0.66,
		0.57,
		0.32,
		1.0
	)

	color_grassland = Color(
		0.24,
		0.43,
		0.15,
		1.0
	)

	color_dry = Color(
		0.52,
		0.44,
		0.23,
		1.0
	)

	color_wet = Color(
		0.10,
		0.31,
		0.13,
		1.0
	)

	color_cold = Color(
		0.38,
		0.50,
		0.40,
		1.0
	)

	color_rock = Color(
		0.34,
		0.33,
		0.29,
		1.0
	)


func _apply_amber_steppes() -> void:
	archetype_name = "Amber Steppes"

	terrain_height_multiplier = 0.88
	terrain_frequency_multiplier = 0.82
	terrace_step_height = 0.35
	cliff_strength = 0.65

	grass_density_multiplier = 0.75
	rock_density_multiplier = 0.90
	tree_density_multiplier = 0.55
	ruin_density_multiplier = 1.15

	fog_density_multiplier = 0.82
	fog_color = Color(
		0.76,
		0.68,
		0.54,
		1.0
	)

	color_ocean_floor = Color(
		0.17,
		0.25,
		0.22,
		1.0
	)

	color_coast = Color(
		0.72,
		0.59,
		0.34,
		1.0
	)

	color_grassland = Color(
		0.46,
		0.42,
		0.20,
		1.0
	)

	color_dry = Color(
		0.63,
		0.43,
		0.19,
		1.0
	)

	color_wet = Color(
		0.24,
		0.36,
		0.18,
		1.0
	)

	color_cold = Color(
		0.48,
		0.51,
		0.39,
		1.0
	)

	color_rock = Color(
		0.43,
		0.35,
		0.28,
		1.0
	)


func _apply_slate_wilds() -> void:
	archetype_name = "Slate Wilds"

	terrain_height_multiplier = 1.22
	terrain_frequency_multiplier = 1.08
	terrace_step_height = 0.55
	cliff_strength = 1.25

	grass_density_multiplier = 0.70
	rock_density_multiplier = 1.35
	tree_density_multiplier = 0.82
	ruin_density_multiplier = 0.85

	fog_density_multiplier = 1.25
	fog_color = Color(
		0.55,
		0.63,
		0.68,
		1.0
	)

	color_ocean_floor = Color(
		0.11,
		0.20,
		0.23,
		1.0
	)

	color_coast = Color(
		0.57,
		0.55,
		0.41,
		1.0
	)

	color_grassland = Color(
		0.22,
		0.37,
		0.25,
		1.0
	)

	color_dry = Color(
		0.42,
		0.40,
		0.29,
		1.0
	)

	color_wet = Color(
		0.12,
		0.27,
		0.23,
		1.0
	)

	color_cold = Color(
		0.39,
		0.49,
		0.50,
		1.0
	)

	color_rock = Color(
		0.31,
		0.34,
		0.37,
		1.0
	)


func _apply_red_mesas() -> void:
	archetype_name = "Red Mesas"

	terrain_height_multiplier = 1.35
	terrain_frequency_multiplier = 0.88
	terrace_step_height = 0.75
	cliff_strength = 1.50

	grass_density_multiplier = 0.42
	rock_density_multiplier = 1.50
	tree_density_multiplier = 0.35
	ruin_density_multiplier = 1.30

	fog_density_multiplier = 0.72
	fog_color = Color(
		0.76,
		0.59,
		0.48,
		1.0
	)

	color_ocean_floor = Color(
		0.19,
		0.22,
		0.20,
		1.0
	)

	color_coast = Color(
		0.72,
		0.53,
		0.31,
		1.0
	)

	color_grassland = Color(
		0.41,
		0.38,
		0.18,
		1.0
	)

	color_dry = Color(
		0.62,
		0.31,
		0.17,
		1.0
	)

	color_wet = Color(
		0.26,
		0.31,
		0.16,
		1.0
	)

	color_cold = Color(
		0.50,
		0.44,
		0.36,
		1.0
	)

	color_rock = Color(
		0.46,
		0.27,
		0.20,
		1.0
	)


func _apply_pale_tundra() -> void:
	archetype_name = "Pale Tundra"

	terrain_height_multiplier = 1.08
	terrain_frequency_multiplier = 0.76
	terrace_step_height = 0.60
	cliff_strength = 1.05

	grass_density_multiplier = 0.55
	rock_density_multiplier = 1.05
	tree_density_multiplier = 0.45
	ruin_density_multiplier = 0.65

	fog_density_multiplier = 1.40
	fog_color = Color(
		0.75,
		0.79,
		0.79,
		1.0
	)

	color_ocean_floor = Color(
		0.16,
		0.23,
		0.25,
		1.0
	)

	color_coast = Color(
		0.68,
		0.65,
		0.50,
		1.0
	)

	color_grassland = Color(
		0.39,
		0.47,
		0.34,
		1.0
	)

	color_dry = Color(
		0.52,
		0.49,
		0.35,
		1.0
	)

	color_wet = Color(
		0.24,
		0.35,
		0.29,
		1.0
	)

	color_cold = Color(
		0.58,
		0.64,
		0.61,
		1.0
	)

	color_rock = Color(
		0.43,
		0.45,
		0.44,
		1.0
	)


func _apply_seed_variation(
	random: RandomNumberGenerator
) -> void:
	terrain_height_multiplier *= random.randf_range(
		0.94,
		1.06
	)

	terrain_frequency_multiplier *= random.randf_range(
		0.95,
		1.05
	)

	terrace_step_height *= random.randf_range(
		0.92,
		1.08
	)

	terrace_step_height = snappedf(
		clampf(
			terrace_step_height,
			0.30,
			0.80
		),
		0.05
	)

	cliff_strength *= random.randf_range(
		0.92,
		1.08
	)

	grass_density_multiplier *= random.randf_range(
		0.90,
		1.10
	)

	rock_density_multiplier *= random.randf_range(
		0.90,
		1.10
	)

	tree_density_multiplier *= random.randf_range(
		0.90,
		1.10
	)

	ruin_density_multiplier *= random.randf_range(
		0.88,
		1.12
	)

	fog_density_multiplier *= random.randf_range(
		0.92,
		1.08
	)

	color_ocean_floor = _vary_color(
		color_ocean_floor,
		random
	)

	color_coast = _vary_color(
		color_coast,
		random
	)

	color_grassland = _vary_color(
		color_grassland,
		random
	)

	color_dry = _vary_color(
		color_dry,
		random
	)

	color_wet = _vary_color(
		color_wet,
		random
	)

	color_cold = _vary_color(
		color_cold,
		random
	)

	color_rock = _vary_color(
		color_rock,
		random
	)

	fog_color = _vary_color(
		fog_color,
		random
	)


func _vary_color(
	base_color: Color,
	random: RandomNumberGenerator
) -> Color:
	var brightness := random.randf_range(
		0.94,
		1.06
	)

	var red_shift := random.randf_range(
		-0.012,
		0.012
	)

	var green_shift := random.randf_range(
		-0.012,
		0.012
	)

	var blue_shift := random.randf_range(
		-0.012,
		0.012
	)

	return Color(
		clampf(
			base_color.r * brightness + red_shift,
			0.0,
			1.0
		),
		clampf(
			base_color.g * brightness + green_shift,
			0.0,
			1.0
		),
		clampf(
			base_color.b * brightness + blue_shift,
			0.0,
			1.0
		),
		base_color.a
	)
