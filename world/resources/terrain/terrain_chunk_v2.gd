extends "res://world/resources/terrain/terrain_chunk.gd"


func _get_top_surface_index(biome: int) -> int:
	if biome in [
		WorldGenerator.Biome.OCEAN,
		WorldGenerator.Biome.COAST,
		WorldGenerator.Biome.LAKE,
		WorldGenerator.Biome.DESERT,
	]:
		return SURFACE_SAND_TOP

	if biome in [
		WorldGenerator.Biome.ROCKY_HIGHLANDS,
		WorldGenerator.Biome.ALPINE,
		WorldGenerator.Biome.SNOW,
	]:
		return SURFACE_STONE_TOP

	return SURFACE_GRASS_TOP


func _get_side_surface_index(
	biome: int,
	logical_height: float,
	top_height: float,
	lower_height: float
) -> int:
	var exposed_height: float = top_height - lower_height

	if biome in [
		WorldGenerator.Biome.ROCKY_HIGHLANDS,
		WorldGenerator.Biome.ALPINE,
		WorldGenerator.Biome.SNOW,
	]:
		return SURFACE_STONE_SIDE

	if biome in [
		WorldGenerator.Biome.OCEAN,
		WorldGenerator.Biome.COAST,
		WorldGenerator.Biome.LAKE,
		WorldGenerator.Biome.DESERT,
	] and exposed_height < 1.5:
		return SURFACE_DIRT_SIDE

	if (
		logical_height > WorldGenerator.get_sea_level()
		and exposed_height >= STONE_SIDE_MIN_EXPOSURE
	):
		return SURFACE_STONE_SIDE

	return SURFACE_DIRT_SIDE


func _get_tree_spawn_probability(biome: int) -> float:
	var density_multiplier: float = WorldGenerator.get_tree_density_multiplier()
	var base_probability: float = 0.0

	match biome:
		WorldGenerator.Biome.DENSE_FOREST:
			base_probability = 0.92
		WorldGenerator.Biome.FOREST:
			base_probability = 0.78
		WorldGenerator.Biome.SWAMP:
			base_probability = 0.68
		WorldGenerator.Biome.WETLAND:
			base_probability = 0.62
		WorldGenerator.Biome.SAVANNA:
			base_probability = 0.24
		WorldGenerator.Biome.RIVER:
			base_probability = 0.28
		WorldGenerator.Biome.GRASSLAND:
			base_probability = 0.20
		WorldGenerator.Biome.COLD_GRASSLAND:
			base_probability = 0.10
		_:
			base_probability = 0.0

	return clampf(base_probability * density_multiplier, 0.0, 1.0)


func _get_bush_spawn_probability(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.DENSE_FOREST:
			return 0.82
		WorldGenerator.Biome.FOREST:
			return 0.72
		WorldGenerator.Biome.SWAMP:
			return 0.78
		WorldGenerator.Biome.WETLAND:
			return 0.70
		WorldGenerator.Biome.RIVER:
			return 0.58
		WorldGenerator.Biome.GRASSLAND:
			return 0.48
		WorldGenerator.Biome.SAVANNA:
			return 0.34
		WorldGenerator.Biome.COLD_GRASSLAND:
			return 0.24
		WorldGenerator.Biome.STEPPE:
			return 0.12
		_:
			return 0.0


func _get_grazer_spawn_probability(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.GRASSLAND:
			return 0.42
		WorldGenerator.Biome.SAVANNA:
			return 0.38
		WorldGenerator.Biome.STEPPE:
			return 0.32
		WorldGenerator.Biome.RIVER:
			return 0.24
		WorldGenerator.Biome.WETLAND:
			return 0.18
		WorldGenerator.Biome.COLD_GRASSLAND:
			return 0.14
		WorldGenerator.Biome.FOREST:
			return 0.10
		_:
			return 0.0
