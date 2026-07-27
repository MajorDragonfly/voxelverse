extends RefCounted
class_name PlanetProfileV6

# A deterministic planet descriptor separates world identity from local chunk
# generation. Future solar-system, planet-selection and save systems can persist
# this compact descriptor instead of storing generated terrain.

static func create(seed_value: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value * 97_409 + 1_107_211

	var grass_a := Color(0.20, 0.48, 0.20, 1.0).lerp(
		Color(0.42, 0.58, 0.20, 1.0),
		random.randf()
	)
	var grass_b := grass_a.lerp(
		Color(0.08, 0.31, 0.18, 1.0),
		0.48 + random.randf() * 0.28
	)
	var dry := Color(0.62, 0.47, 0.21, 1.0).lerp(
		Color(0.78, 0.56, 0.28, 1.0),
		random.randf()
	)
	var rock := Color(0.32, 0.34, 0.36, 1.0).lerp(
		Color(0.51, 0.35, 0.27, 1.0),
		random.randf()
	)
	var water := Color(0.025, 0.25, 0.40, 1.0).lerp(
		Color(0.02, 0.46, 0.48, 1.0),
		random.randf()
	)

	return {
		"schema": 1,
		"planet_seed": seed_value,
		"planet_name": "VX-%08X" % absi(seed_value),
		"terrain_style": random.randi_range(0, 3),
		"relief_scale": random.randf_range(0.86, 1.22),
		"mountain_scale": random.randf_range(0.82, 1.28),
		"erosion_scale": random.randf_range(0.82, 1.18),
		"flora_scale": random.randf_range(0.78, 1.34),
		"fauna_species_count": random.randi_range(4, 9),
		"fauna_population_scale": random.randf_range(0.82, 1.18),
		"palette": {
			"grass": grass_a,
			"forest": grass_b,
			"dry": dry,
			"rock": rock,
			"snow": Color(0.84, 0.88, 0.86, 1.0),
			"coast": dry.lerp(Color(0.78, 0.68, 0.43, 1.0), 0.66),
			"water": water,
		},
	}
