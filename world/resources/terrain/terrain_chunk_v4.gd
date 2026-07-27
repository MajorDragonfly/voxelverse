extends "res://world/resources/terrain/terrain_chunk_v3.gd"

# V4 keeps 64 x 64 terrain cells per chunk but each cell is 0.5 world units.
# The chunk therefore becomes physically smaller and visibly finer without
# multiplying the number of generated columns. Heights including the one-cell
# neighbour border are cached once per chunk build.

var _local_height_cache: Dictionary = {}


func generate_terrain() -> void:
	_build_local_height_cache()
	super.generate_terrain()


func _build_local_height_cache() -> void:
	_local_height_cache.clear()
	var cells_x: int = _get_cells_x()
	var cells_z: int = _get_cells_z()

	for cell_z in range(-1, cells_z + 1):
		for cell_x in range(-1, cells_x + 1):
			var world_center: Vector2 = _get_cell_center_world_position_by_index(
				cell_x,
				cell_z
			)
			_local_height_cache[Vector2i(cell_x, cell_z)] = (
				WorldGenerator.get_visual_terrain_height(
					world_center.x,
					world_center.y
				)
			)


func _get_column_height_by_index(cell_x: int, cell_z: int) -> float:
	var key := Vector2i(cell_x, cell_z)
	if _local_height_cache.has(key):
		return float(_local_height_cache[key])

	var world_center: Vector2 = _get_cell_center_world_position_by_index(
		cell_x,
		cell_z
	)
	var height: float = WorldGenerator.get_visual_terrain_height(
		world_center.x,
		world_center.y
	)
	_local_height_cache[key] = height
	return height


func _get_top_surface_index(biome: int) -> int:
	match biome:
		WorldGenerator.Biome.OCEAN, WorldGenerator.Biome.COAST, WorldGenerator.Biome.LAKE:
			return SURFACE_SAND_TOP
		WorldGenerator.Biome.ROCKY_HIGHLANDS, WorldGenerator.Biome.ALPINE, WorldGenerator.Biome.SNOW:
			return SURFACE_STONE_TOP
		_:
			# Forest, grassland, steppe, savanna and wetlands share one land
			# material. Their identity comes from continuously blended vertex
			# colors, which removes the previous hard biome-colored seam.
			return SURFACE_GRASS_TOP
