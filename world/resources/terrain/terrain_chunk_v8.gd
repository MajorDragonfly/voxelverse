extends "res://world/resources/terrain/terrain_chunk_v7.gd"

@export_category("Fast Terrain V8")
@export_range(1, 8, 1) var color_sample_stride: int = 2

var _fast_color_cache: Dictionary = {}


func generate_terrain() -> void:
	terrain_mesh.mesh = null
	terrain_mesh.material_override = null
	terrain_collision.shape = null
	_fast_color_cache.clear()
	_build_local_height_cache()

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var cells_x: int = _get_cells_x()
	var cells_z: int = _get_cells_z()
	var half_width: float = get_chunk_width() * 0.5
	var half_depth: float = get_chunk_depth() * 0.5

	for cell_z in range(cells_z):
		for cell_x in range(cells_x):
			var x0: float = float(cell_x) * cell_size - half_width
			var x1: float = x0 + cell_size
			var z0: float = float(cell_z) * cell_size - half_depth
			var z1: float = z0 + cell_size
			var height: float = _get_column_height_by_index(cell_x, cell_z)
			var top_color: Color = _get_fast_cell_color(cell_x, cell_z)
			_append_quad(
				vertices, normals, colors, uvs,
				Vector3(x0, height, z0),
				Vector3(x0, height, z1),
				Vector3(x1, height, z1),
				Vector3(x1, height, z0),
				Vector3.UP,
				top_color
			)
			var side_color: Color = top_color.darkened(0.16)
			var west: float = _get_column_height_by_index(cell_x - 1, cell_z)
			if height > west + 0.001:
				_append_quad(vertices, normals, colors, uvs,
					Vector3(x0, west, z1), Vector3(x0, height, z1),
					Vector3(x0, height, z0), Vector3(x0, west, z0),
					Vector3.LEFT, side_color)
			var east: float = _get_column_height_by_index(cell_x + 1, cell_z)
			if height > east + 0.001:
				_append_quad(vertices, normals, colors, uvs,
					Vector3(x1, east, z0), Vector3(x1, height, z0),
					Vector3(x1, height, z1), Vector3(x1, east, z1),
					Vector3.RIGHT, side_color)
			var north: float = _get_column_height_by_index(cell_x, cell_z - 1)
			if height > north + 0.001:
				_append_quad(vertices, normals, colors, uvs,
					Vector3(x1, north, z0), Vector3(x1, height, z0),
					Vector3(x0, height, z0), Vector3(x0, north, z0),
					Vector3.FORWARD, side_color)
			var south: float = _get_column_height_by_index(cell_x, cell_z + 1)
			if height > south + 0.001:
				_append_quad(vertices, normals, colors, uvs,
					Vector3(x0, south, z1), Vector3(x0, height, z1),
					Vector3(x1, height, z1), Vector3(x1, south, z1),
					Vector3.BACK, side_color)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var generated_mesh := ArrayMesh.new()
	generated_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	generated_mesh.surface_set_name(0, "VoxelTerrainV8")
	terrain_mesh.mesh = generated_mesh
	_apply_fast_heightmap_collision(cells_x, cells_z)


func _append_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	uvs: PackedVector2Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	vertices.append_array(PackedVector3Array([a, b, c, a, c, d]))
	for _index in range(6):
		normals.append(normal)
		colors.append(color)
	uvs.append_array(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0),
		Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0),
	]))


func _get_fast_cell_color(cell_x: int, cell_z: int) -> Color:
	var stride: int = maxi(color_sample_stride, 1)
	var sample_x: int = clampi((cell_x / stride) * stride, 0, _get_cells_x() - 1)
	var sample_z: int = clampi((cell_z / stride) * stride, 0, _get_cells_z() - 1)
	var key := Vector2i(sample_x, sample_z)
	if _fast_color_cache.has(key):
		return _fast_color_cache[key]
	var world_center: Vector2 = _get_cell_center_world_position_by_index(sample_x, sample_z)
	var height: float = _get_column_height_by_index(sample_x, sample_z)
	var color: Color = WorldGenerator.get_biome_color(world_center.x, world_center.y, height)
	_fast_color_cache[key] = color
	return color


func _apply_fast_heightmap_collision(cells_x: int, cells_z: int) -> void:
	var width: int = cells_x + 1
	var depth: int = cells_z + 1
	var map_data := PackedFloat32Array()
	map_data.resize(width * depth)
	for z_index in range(depth):
		for x_index in range(width):
			map_data[z_index * width + x_index] = _get_column_height_by_index(x_index, z_index)
	var height_map := HeightMapShape3D.new()
	height_map.map_width = width
	height_map.map_depth = depth
	height_map.map_data = map_data
	terrain_collision.shape = height_map
	terrain_collision.position = Vector3(cell_size * 0.5, 0.0, cell_size * 0.5)
	terrain_collision.scale = Vector3(cell_size, 1.0, cell_size)
	terrain_collision.disabled = false
