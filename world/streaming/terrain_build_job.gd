extends RefCounted

const Surface = preload("res://world/streaming/voxel_surface_builder.gd")
const Transition = preload("res://world/streaming/terrain_transition.gd")
var far_stride: int = 4
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
var _horizon_heights: Dictionary = {}
var _proxy_heights: Dictionary = {}
var _render_min: float = INF
var _render_max: float = -INF

func run() -> void:
	_generator = generator_script.new()
	_generator.set_seed_override(world_seed)
	_build_local_height_cache()
	var arrays: Array = _column_arrays(cell_size, true)
	result = {"arrays": arrays, "heights": _fast_height_grid, "width": _fast_height_width, "depth": _fast_height_depth, "colors": _fast_color_cache}
	result["far_arrays"] = _column_arrays(Transition.PROXY_STEP, false)
	result["render_bounds"] = AABB(Vector3(-get_chunk_width() * 0.5, _render_min, -get_chunk_depth() * 0.5), Vector3(get_chunk_width(), _render_max - _render_min, get_chunk_depth()))
	_generator.free()
	_generator = null

func _column_arrays(step: float, detailed: bool) -> Array:
	var size := Vector2(get_chunk_width(), get_chunk_depth())
	var columns: int = roundi(size.x / step)
	var rows: int = roundi(size.y / step)
	var heights := PackedVector3Array()
	var colors := PackedColorArray()
	for z in range(-1, rows + 1):
		for x in range(-1, columns + 1):
			var point: Vector2 = chunk_origin + Vector2(x + 0.5, z + 0.5) * step - size * 0.5
			var proxy: float = Transition.height_at(_generator, point, Transition.PROXY_STEP, _proxy_heights)
			var height: float = _get_column_height_by_index(x, z) if detailed else proxy
			var horizon: float = Transition.height_at(_generator, point, Transition.HORIZON_STEP, _horizon_heights)
			heights.append(Vector3(height, horizon, proxy))
			var color := Color.WHITE
			if x >= 0 and z >= 0 and x < columns and z < rows:
				color = _get_fast_cell_color(x, z) if detailed else _generator.get_biome_color(point.x, point.y, height)
			colors.append(color)
			_render_min = minf(_render_min, minf(height, minf(horizon, proxy)))
			_render_max = maxf(_render_max, maxf(height, maxf(horizon, proxy)))
	return Surface.new().build(size, step, heights, colors)

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
