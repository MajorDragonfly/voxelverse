extends "res://world/visuals/scenery/terrain_scenic_dressing.gd"


func _get_grass_probability(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.DENSE_FOREST:
			return 0.74
		WorldGenerator.Biome.FOREST:
			return 0.88
		WorldGenerator.Biome.SWAMP:
			return 0.82
		WorldGenerator.Biome.WETLAND:
			return 0.96
		WorldGenerator.Biome.RIVER:
			return 0.90
		WorldGenerator.Biome.GRASSLAND:
			return 0.84
		WorldGenerator.Biome.SAVANNA:
			return 0.48
		WorldGenerator.Biome.COLD_GRASSLAND:
			return 0.58
		WorldGenerator.Biome.STEPPE:
			return 0.34
		WorldGenerator.Biome.ALPINE:
			return 0.10
		WorldGenerator.Biome.COAST:
			return 0.08
		WorldGenerator.Biome.ROCKY_HIGHLANDS:
			return 0.04
		_:
			return 0.0


func _get_rock_probability(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.ROCKY_HIGHLANDS:
			return 0.92
		WorldGenerator.Biome.ALPINE:
			return 0.84
		WorldGenerator.Biome.SNOW:
			return 0.58
		WorldGenerator.Biome.DESERT:
			return 0.62
		WorldGenerator.Biome.STEPPE:
			return 0.54
		WorldGenerator.Biome.COAST:
			return 0.35
		WorldGenerator.Biome.COLD_GRASSLAND:
			return 0.42
		WorldGenerator.Biome.SAVANNA:
			return 0.28
		WorldGenerator.Biome.GRASSLAND:
			return 0.18
		WorldGenerator.Biome.WETLAND:
			return 0.08
		WorldGenerator.Biome.SWAMP:
			return 0.08
		_:
			return 0.0


func _get_spire_probability(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.ROCKY_HIGHLANDS:
			return 0.40
		WorldGenerator.Biome.ALPINE:
			return 0.32
		WorldGenerator.Biome.DESERT:
			return 0.20
		WorldGenerator.Biome.STEPPE:
			return 0.16
		_:
			return 0.0


func _biome_allows_ruins(biome: int) -> bool:
	return biome in [
		WorldGenerator.Biome.GRASSLAND,
		WorldGenerator.Biome.STEPPE,
		WorldGenerator.Biome.COLD_GRASSLAND,
		WorldGenerator.Biome.ROCKY_HIGHLANDS,
		WorldGenerator.Biome.SAVANNA,
		WorldGenerator.Biome.DESERT,
		WorldGenerator.Biome.FOREST,
	]


func _get_grass_color(
	biome: int,
	world_x: float,
	world_z: float,
	terrain_height: float,
	random: RandomNumberGenerator
) -> Color:
	var base_color: Color = WorldGenerator.get_biome_color(
		world_x,
		world_z,
		terrain_height
	)

	match biome:
		WorldGenerator.Biome.DENSE_FOREST:
			base_color = base_color.lerp(Color(0.06, 0.24, 0.12, 1.0), 0.34)
		WorldGenerator.Biome.FOREST:
			base_color = base_color.lerp(Color(0.11, 0.34, 0.15, 1.0), 0.24)
		WorldGenerator.Biome.SWAMP:
			base_color = base_color.lerp(Color(0.10, 0.26, 0.16, 1.0), 0.40)
		WorldGenerator.Biome.WETLAND:
			base_color = base_color.lerp(Color(0.08, 0.30, 0.10, 1.0), 0.32)
		WorldGenerator.Biome.RIVER:
			base_color = base_color.lerp(Color(0.08, 0.30, 0.10, 1.0), 0.32)
		WorldGenerator.Biome.SAVANNA:
			base_color = base_color.lerp(Color(0.58, 0.49, 0.18, 1.0), 0.30)
		WorldGenerator.Biome.STEPPE:
			base_color = base_color.lerp(Color(0.55, 0.44, 0.18, 1.0), 0.30)
		WorldGenerator.Biome.COLD_GRASSLAND:
			base_color = base_color.lerp(Color(0.38, 0.48, 0.39, 1.0), 0.30)

	return _vary_color(base_color, random, 0.10)


func _get_rock_color(
	biome: int,
	random: RandomNumberGenerator
) -> Color:
	var base_color: Color = WorldGenerator.get_world_rock_color()

	if biome in [
		WorldGenerator.Biome.ROCKY_HIGHLANDS,
		WorldGenerator.Biome.ALPINE,
		WorldGenerator.Biome.SNOW,
	]:
		base_color = base_color.lerp(Color(0.28, 0.29, 0.30, 1.0), 0.22)
	elif biome == WorldGenerator.Biome.DESERT:
		base_color = base_color.lerp(Color(0.52, 0.37, 0.23, 1.0), 0.28)
	elif biome in [
		WorldGenerator.Biome.STEPPE,
		WorldGenerator.Biome.SAVANNA,
	]:
		base_color = base_color.lerp(Color(0.48, 0.31, 0.21, 1.0), 0.15)

	return _vary_color(base_color, random, 0.10)
