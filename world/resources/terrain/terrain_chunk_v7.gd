extends "res://world/resources/terrain/terrain_chunk_v4.gd"

const FarMeshJob = preload(
	"res://world/streaming/terrain_far_mesh_job_v7.gd"
)
const MeshPool = preload(
	"res://world/streaming/terrain_mesh_pool_v7.gd"
)

@export_category("Far Terrain Proxy")
@export_range(2, 16, 1) var far_sample_stride: int = 4
@export var enable_far_proxy: bool = true

@onready var far_terrain_mesh: MeshInstance3D = $FarTerrainMesh

var _far_job: RefCounted
var _far_task_id: int = -1
var _far_mesh_resource: ArrayMesh
var _far_mesh_ready: bool = false
var _lod_tier: int = 0


func _ready() -> void:
	super._ready()
	far_terrain_mesh.visible = false
	far_terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if enable_far_proxy:
		call_deferred("_queue_far_proxy_build")


func _process(_delta: float) -> void:
	if _far_task_id < 0:
		return
	if not WorkerThreadPool.is_task_completed(_far_task_id):
		return
	_finalize_far_proxy()


func _exit_tree() -> void:
	if _far_task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_far_task_id)
		_far_task_id = -1
	if _far_mesh_resource != null:
		MeshPool.release_mesh(_far_mesh_resource)
		_far_mesh_resource = null


func set_lod_tier(tier: int) -> void:
	_lod_tier = clampi(tier, 0, 2)
	_apply_lod_visibility()


func get_lod_tier() -> int:
	return _lod_tier


func is_far_proxy_ready() -> bool:
	return _far_mesh_ready


func _queue_far_proxy_build() -> void:
	if _far_task_id >= 0 or far_terrain_mesh == null:
		return
	var cells_x: int = _get_cells_x()
	var cells_z: int = _get_cells_z()
	var stride: int = clampi(far_sample_stride, 2, 16)
	var columns: int = ceili(float(cells_x) / float(stride)) + 1
	var rows: int = ceili(float(cells_z) / float(stride)) + 1
	var half_width: float = get_chunk_width() * 0.5
	var half_depth: float = get_chunk_depth() * 0.5
	var local_x_values := PackedFloat32Array()
	var local_z_values := PackedFloat32Array()
	local_x_values.resize(columns)
	local_z_values.resize(rows)

	for column in range(columns):
		var cell_index: int = mini(column * stride, cells_x)
		local_x_values[column] = float(cell_index) * cell_size - half_width
	for row in range(rows):
		var cell_index: int = mini(row * stride, cells_z)
		local_z_values[row] = float(cell_index) * cell_size - half_depth

	var heights := PackedFloat32Array()
	var colors := PackedColorArray()
	heights.resize(columns * rows)
	colors.resize(columns * rows)
	for row in range(rows):
		for column in range(columns):
			var index: int = row * columns + column
			var world_x: float = global_position.x + local_x_values[column]
			var world_z: float = global_position.z + local_z_values[row]
			var logical_height: float = WorldGenerator.get_terrain_height(
				world_x,
				world_z
			)
			heights[index] = WorldGenerator.get_visual_terrain_height(
				world_x,
				world_z
			)
			colors[index] = WorldGenerator.get_biome_color(
				world_x,
				world_z,
				logical_height
			)

	_far_job = FarMeshJob.new({
		"columns": columns,
		"rows": rows,
		"local_x_values": local_x_values,
		"local_z_values": local_z_values,
		"heights": heights,
		"colors": colors,
	})
	_far_task_id = WorkerThreadPool.add_task(
		Callable(_far_job, "run"),
		false,
		"Voxelverse far terrain %s" % chunk_coordinates
	)


func _finalize_far_proxy() -> void:
	var completion_error: Error = WorkerThreadPool.wait_for_task_completion(
		_far_task_id
	)
	_far_task_id = -1
	if completion_error != OK:
		push_warning(
			"Far terrain task failed for %s: %s"
			% [chunk_coordinates, completion_error]
		)
		_far_job = null
		return
	var result: Dictionary = _far_job.call("get_result")
	_far_job = null
	var arrays_value: Variant = result.get("arrays")
	if not (arrays_value is Array):
		push_warning("Far terrain arrays are missing for %s." % chunk_coordinates)
		return
	var arrays: Array = arrays_value
	if arrays.size() != Mesh.ARRAY_MAX:
		push_warning("Far terrain arrays are incomplete for %s." % chunk_coordinates)
		return

	_far_mesh_resource = MeshPool.acquire_mesh()
	_far_mesh_resource.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)
	_far_mesh_resource.surface_set_name(0, "FarTerrainV7")
	_far_mesh_resource.surface_set_material(0, MeshPool.get_far_material())
	far_terrain_mesh.mesh = _far_mesh_resource
	far_terrain_mesh.extra_cull_margin = 4.0
	_far_mesh_ready = true
	_apply_lod_visibility()


func _apply_lod_visibility() -> void:
	if terrain_mesh == null or far_terrain_mesh == null:
		return
	if _lod_tier >= 2 and _far_mesh_ready:
		terrain_mesh.visible = false
		far_terrain_mesh.visible = true
	else:
		terrain_mesh.visible = true
		far_terrain_mesh.visible = false
