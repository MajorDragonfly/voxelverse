extends RefCounted
class_name PlanetProfileV8

const ARCHETYPES: Array[String] = [
	"Verdant Frontier",
	"Broken Highlands",
	"Mesa World",
	"Archipelago",
	"Ancient Basin",
	"Alpine Crown",
]


static func create(seed_value: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value * 97_409 + 8_047_113
	var archetype_index: int = posmod(seed_value, ARCHETYPES.size())
	var archetype: String = ARCHETYPES[archetype_index]

	var grass_hue_shift: float = random.randf_range(-0.06, 0.10)
	var grass := Color.from_hsv(
		wrapf(0.29 + grass_hue_shift, 0.0, 1.0),
		random.randf_range(0.48, 0.78),
		random.randf_range(0.42, 0.72),
		1.0
	)
	var forest := grass.darkened(random.randf_range(0.22, 0.46))
	var dry := Color.from_hsv(
		random.randf_range(0.065, 0.12),
		random.randf_range(0.46, 0.72),
		random.randf_range(0.58, 0.82),
		1.0
	)
	var rock := Color.from_hsv(
		random.randf_range(0.035, 0.10),
		random.randf_range(0.08, 0.38),
		random.randf_range(0.34, 0.58),
		1.0
	)
	var water := Color.from_hsv(
		random.randf_range(0.48, 0.57),
		random.randf_range(0.62, 0.90),
		random.randf_range(0.38, 0.68),
		1.0
	)

	var relief_scale: float = random.randf_range(0.92, 1.22)
	var mountain_scale: float = random.randf_range(0.90, 1.28)
	var mountain_presence: float = random.randf_range(0.72, 1.18)
	var plateau_scale: float = random.randf_range(0.65, 1.22)
	var canyon_scale: float = random.randf_range(0.55, 1.15)
	var basin_scale: float = random.randf_range(0.60, 1.18)
	var island_scale: float = random.randf_range(0.72, 1.16)
	var flora_scale: float = random.randf_range(0.78, 1.38)
	var snow_line: float = random.randf_range(18.0, 25.0)

	match archetype_index:
		0:
			relief_scale *= 1.05
			mountain_presence *= 0.88
			flora_scale *= 1.22
			basin_scale *= 1.12
		1:
			mountain_scale *= 1.38
			mountain_presence *= 1.28
			canyon_scale *= 1.18
			flora_scale *= 0.88
		2:
			plateau_scale *= 1.55
			canyon_scale *= 1.42
			mountain_presence *= 0.74
			flora_scale *= 0.82
		3:
			island_scale *= 1.52
			mountain_scale *= 0.90
			flora_scale *= 1.10
		4:
			basin_scale *= 1.62
			canyon_scale *= 1.18
			mountain_presence *= 0.82
		5:
			mountain_scale *= 1.62
			mountain_presence *= 1.35
			snow_line -= 3.0
			flora_scale *= 0.78

	return {
		"schema": 2,
		"planet_seed": seed_value,
		"planet_name": "VX-%08X" % absi(seed_value),
		"terrain_style": archetype_index,
		"terrain_archetype": archetype,
		"relief_scale": relief_scale,
		"mountain_scale": mountain_scale,
		"mountain_presence": mountain_presence,
		"plateau_scale": plateau_scale,
		"canyon_scale": canyon_scale,
		"basin_scale": basin_scale,
		"island_scale": island_scale,
		"erosion_scale": random.randf_range(0.82, 1.24),
		"flora_scale": flora_scale,
		"fauna_species_count": random.randi_range(5, 11),
		"fauna_population_scale": random.randf_range(0.78, 1.24),
		"snow_start_altitude": snow_line,
		"snow_end_altitude": snow_line + random.randf_range(3.0, 5.5),
		"atmosphere_haze": random.randf_range(0.18, 0.42),
		"sun_warmth": random.randf_range(0.0, 1.0),
		"palette": {
			"grass": grass,
			"forest": forest,
			"dry": dry,
			"rock": rock,
			"snow": Color(0.86, 0.90, 0.91, 1.0).lerp(Color(0.73, 0.84, 0.92, 1.0), random.randf() * 0.35),
			"coast": dry.lerp(Color(0.82, 0.72, 0.49, 1.0), 0.68),
			"water": water,
		},
	}
