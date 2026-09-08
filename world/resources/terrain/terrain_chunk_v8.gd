extends "res://world/resources/terrain/terrain_chunk_v7.gd"

const TerrainBuildJob = preload("res://world/streaming/terrain_build_job.gd")
const EnvironmentBudget = preload("res://world/streaming/environment_generation_budget.gd")
signal terrain_ready

@export_category("Fast Terrain V8")
@export_range(1, 8, 1) var color_sample_stride: int = 4
@export var threaded_generation: bool = true

var _fast_color_cache: Dictionary = {}
var _fast_height_grid := PackedFloat32Array()
var _fast_height_width: int = 0
var _fast_height_depth: int = 0
var _terrain_job: RefCounted
var _terrain_task_id: int = -1
var generation_complete: bool = false
var upload_ms: float = 0.0
var terrain_presence: float = 0.0
var terrain_retiring: bool = false
var _terrain_lod_blend: float = 0.0
const Transition = preload("res://world/streaming/terrain_transition.gd")


func _ready() -> void:
	_position_chunk()
	far_terrain_mesh.visible = false
	far_terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	generate_terrain()


func generate_terrain() -> void:
	if _terrain_task_id >= 0:
		return
	generation_complete = false
	_terrain_job = TerrainBuildJob.new()
	_terrain_job.generator_script = WorldGenerator.get_script()
	_terrain_job.world_seed = WorldGenerator.get_world_seed()
	_terrain_job.chunk_origin = Vector2(position.x, position.z)
	_terrain_job.cell_size = cell_size
	_terrain_job.cells_x = _get_cells_x()
	_terrain_job.cells_z = _get_cells_z()
	_terrain_job.color_sample_stride = color_sample_stride
	_terrain_job.far_stride = far_sample_stride
	if threaded_generation:
		_terrain_task_id = WorkerThreadPool.add_task(_terrain_job.run, false, "Surface %s" % chunk_coordinates)
	else:
		_terrain_job.run()
		_finish_terrain()


func _process(delta: float) -> void:
	if generation_complete:
		terrain_presence = move_toward(terrain_presence, 0.0 if terrain_retiring else 1.0, delta / Transition.DURATION)
		_terrain_lod_blend = move_toward(_terrain_lod_blend, 1.0 if _lod_tier >= 2 and _far_mesh_ready else 0.0, delta / Transition.DURATION)
		_apply_lod_visibility()
	if _terrain_task_id >= 0 and WorkerThreadPool.is_task_completed(_terrain_task_id) and EnvironmentBudget.claim_mesh_upload():
		# Completed workers may arrive together. Commit at most one chunk's
		# mesh/collision payload on the main thread during a frame.
		WorkerThreadPool.wait_for_task_completion(_terrain_task_id)
		_terrain_task_id = -1
		_finish_terrain()
	super._process(delta)


func _exit_tree() -> void:
	if _terrain_task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_terrain_task_id)
		_terrain_task_id = -1
	_terrain_job = null
	super._exit_tree()


func _finish_terrain() -> void:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = _terrain_job.result
	_terrain_job = null
	_fast_height_grid = result["heights"]
	_fast_height_width = int(result["width"])
	_fast_height_depth = int(result["depth"])
	_fast_color_cache = result["colors"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result["arrays"])
	mesh.surface_set_name(0, "VoxelTerrainV8")
	terrain_mesh.mesh = mesh
	terrain_mesh.custom_aabb = result["render_bounds"]
	_apply_fast_heightmap_collision(_get_cells_x(), _get_cells_z())
	_create_water_surface()
	# Legacy decorative object generation is disabled in V3. Do not run its
	# obsolete attempts now that all environment placement is instanced.
	generation_complete = true
	if enable_far_proxy:
		_far_mesh_resource = MeshPool.acquire_mesh()
		_far_mesh_resource.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result["far_arrays"])
		_far_mesh_resource.surface_set_material(0, MeshPool.get_far_material())
		far_terrain_mesh.mesh = _far_mesh_resource
		_far_mesh_ready = true
		_apply_lod_visibility()
	upload_ms = (Time.get_ticks_usec() - started) / 1000.0
	EnvironmentBudget.record(started, "terrain")
	terrain_ready.emit()


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
	return WorldGenerator.get_visual_terrain_height(world_center.x, world_center.y)


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


func _apply_lod_visibility() -> void:
	if terrain_mesh == null or far_terrain_mesh == null:
		return
	# Keep the detailed mesh until it exactly reaches the proxy's triangles.
	# The reverse switch starts at that same shape and then restores the blocks.
	var proxy: bool = _far_mesh_ready and _terrain_lod_blend >= 1.0
	terrain_mesh.visible = not proxy
	far_terrain_mesh.visible = proxy
	var material := terrain_mesh.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter("terrain_lod_blend", _terrain_lod_blend)
