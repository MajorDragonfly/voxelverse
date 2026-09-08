extends RefCounted

const FarMeshJob = preload("res://world/streaming/terrain_far_mesh_job_v7.gd")
var far_stride: int = 5

var generator_script: Script
var world_seed: int
var chunk_origin: Vector2
var cell_size: float
var cells_x: int
var cells_z: int
var color_sample_stride: int
var result: Dictionary = {}
var _generator: Node

var _fast_color_cache: Dictionary = {}
var _fast_height_grid := PackedFloat32Array()
var _fast_height_width: int = 0
var _fast_height_depth: int = 0
var _build_vertices := PackedVector3Array()
var _build_normals := PackedVector3Array()
var _build_colors := PackedColorArray()
var _build_uvs := PackedVector2Array()


func run() -> void:
	_generator = generator_script.new()
	_generator.set_seed_override(world_seed)
	_fast_color_cache.clear()
	_build_vertices.clear()
	_build_normals.clear()
	_build_colors.clear()
	_build_uvs.clear()
	_build_local_height_cache()

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
			_append_build_quad(
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
				_append_build_quad(
					Vector3(x0, west, z1), Vector3(x0, height, z1),
					Vector3(x0, height, z0), Vector3(x0, west, z0),
					Vector3.LEFT, side_color)
			var east: float = _get_column_height_by_index(cell_x + 1, cell_z)
			if height > east + 0.001:
				_append_build_quad(
					Vector3(x1, east, z0), Vector3(x1, height, z0),
					Vector3(x1, height, z1), Vector3(x1, east, z1),
					Vector3.RIGHT, side_color)
			var north: float = _get_column_height_by_index(cell_x, cell_z - 1)
			if height > north + 0.001:
				_append_build_quad(
					Vector3(x1, north, z0), Vector3(x1, height, z0),
					Vector3(x0, height, z0), Vector3(x0, north, z0),
					Vector3.FORWARD, side_color)
			var south: float = _get_column_height_by_index(cell_x, cell_z + 1)
			if height > south + 0.001:
				_append_build_quad(
					Vector3(x0, south, z1), Vector3(x0, height, z1),
					Vector3(x1, height, z1), Vector3(x1, south, z1),
					Vector3.BACK, side_color)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _build_vertices
	arrays[Mesh.ARRAY_NORMAL] = _build_normals
	arrays[Mesh.ARRAY_COLOR] = _build_colors
	arrays[Mesh.ARRAY_TEX_UV] = _build_uvs
	result = {"arrays": arrays, "heights": _fast_height_grid, "width": _fast_height_width, "depth": _fast_height_depth, "colors": _fast_color_cache}
	result["far_arrays"] = _build_far_arrays()
	_generator.free()
	_generator = null


func _build_local_height_cache() -> void:
	_fast_height_width = cells_x + 2
	_fast_height_depth = cells_z + 2
	_fast_height_grid.resize(_fast_height_width * _fast_height_depth)
	for cell_z in range(-1, cells_z + 1):
		for cell_x in range(-1, cells_x + 1):
			var world_center: Vector2 = _get_cell_center_world_position_by_index(cell_x, cell_z)
			var grid_index: int = (cell_z + 1) * _fast_height_width + (cell_x + 1)
			_fast_height_grid[grid_index] = _generator.get_visual_terrain_height(
				world_center.x,
				world_center.y
			)


func _get_column_height_by_index(cell_x: int, cell_z: int) -> float:
	var grid_x: int = cell_x + 1
	var grid_z: int = cell_z + 1
	if (
		grid_x >= 0 and grid_x < _fast_height_width
		and grid_z >= 0 and grid_z < _fast_height_depth
		and not _fast_height_grid.is_empty()
	):
		return _fast_height_grid[grid_z * _fast_height_width + grid_x]
	var world_center: Vector2 = _get_cell_center_world_position_by_index(cell_x, cell_z)
	return _generator.get_visual_terrain_height(world_center.x, world_center.y)


func _append_build_quad(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	# Match the original terrain builder: callers have different winding on
	# different axes, while Godot requires clockwise outward front faces.
	var reverse: bool = (b - a).cross(c - a).dot(normal) > 0.0
	_build_vertices.append_array(PackedVector3Array([a, c, b, a, d, c] if reverse else [a, b, c, a, c, d]))
	for _index in range(6):
		_build_normals.append(normal)
		_build_colors.append(color)
	_build_uvs.append_array(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0),
	] if reverse else [
		Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0),
		Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0),
	]))


func _get_fast_cell_color(cell_x: int, cell_z: int) -> Color:
	var stride: int = maxi(color_sample_stride, 1)
	var sample_x: int = clampi(
		floori(float(cell_x) / float(stride)) * stride,
		0,
		cells_x - 1
	)
	var sample_z: int = clampi(
		floori(float(cell_z) / float(stride)) * stride,
		0,
		cells_z - 1
	)
	var key := Vector2i(sample_x, sample_z)
	if _fast_color_cache.has(key):
		return _fast_color_cache[key]
	var world_center: Vector2 = _get_cell_center_world_position_by_index(sample_x, sample_z)
	var height: float = _get_column_height_by_index(sample_x, sample_z)
	var color: Color = _generator.get_biome_color(world_center.x, world_center.y, height)
	_fast_color_cache[key] = color
	return color



func get_chunk_width() -> float:
	return cells_x * cell_size

func get_chunk_depth() -> float:
	return cells_z * cell_size

func _get_cell_center_world_position_by_index(x: int, z: int) -> Vector2:
	return chunk_origin + Vector2((x + 0.5) * cell_size - get_chunk_width() * 0.5, (z + 0.5) * cell_size - get_chunk_depth() * 0.5)


func _build_far_arrays() -> Array:
	var columns: int = ceili(float(cells_x) / far_stride) + 1
	var rows: int = ceili(float(cells_z) / far_stride) + 1
	var xs := PackedFloat32Array()
	var zs := PackedFloat32Array()
	var heights := PackedFloat32Array()
	var colors := PackedColorArray()
	for x in range(columns):
		xs.append(mini(x * far_stride, cells_x) * cell_size - get_chunk_width() * 0.5)
	for z in range(rows):
		zs.append(mini(z * far_stride, cells_z) * cell_size - get_chunk_depth() * 0.5)
	for z in range(rows):
		for x in range(columns):
			var cx: int = mini(x * far_stride, cells_x)
			var cz: int = mini(z * far_stride, cells_z)
			heights.append(_get_column_height_by_index(cx, cz))
			colors.append(_get_fast_cell_color(cx, cz))
	var job := FarMeshJob.new({"columns": columns, "rows": rows, "local_x_values": xs, "local_z_values": zs, "heights": heights, "colors": colors})
	job.run()
	return job.get_result()["arrays"]
