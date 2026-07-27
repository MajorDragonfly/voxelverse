extends Node3D

# The gameplay terrain remains a cheap 0.5-unit collision heightfield. This
# component adds a purely visual 2x2 micro-voxel skin to nearby chunks. One
# MultiMesh instance represents four tiny surface columns, so the detail layer
# does not create thousands of scene nodes and can be discarded at distance.

@export_range(16.0, 120.0, 1.0)
var build_distance: float = 52.0

@export_range(20.0, 160.0, 1.0)
var release_distance: float = 72.0

@export_range(64, 1024, 64)
var instances_per_frame: int = 256

@export_range(0.0, 0.25, 0.005)
var surface_lift: float = 0.012

const CHECK_INTERVAL: float = 0.35
const MICRO_PATTERN_COUNT: int = 4

static var _shared_tile_mesh: ArrayMesh
static var _shared_material: StandardMaterial3D

var _chunk: Node3D
var _player: Node3D
var _instance: MultiMeshInstance3D
var _multimesh: MultiMesh
var _build_index: int = 0
var _cells_x: int = 0
var _cells_z: int = 0
var _cell_size: float = 0.5
var _half_width: float = 0.0
var _half_depth: float = 0.0
var _building: bool = false
var _built: bool = false
var _check_timer: float = 0.0


func _ready() -> void:
	_chunk = get_parent() as Node3D
	call_deferred("_bind_player")


func _process(delta: float) -> void:
	if _chunk == null:
		return

	if _player == null or not is_instance_valid(_player):
		_bind_player()

	if _building:
		_build_next_batch()

	_check_timer -= delta
	if _check_timer > 0.0 or _player == null:
		return
	_check_timer = CHECK_INTERVAL

	var distance_to_player: float = _chunk.global_position.distance_to(
		_player.global_position
	)

	if distance_to_player <= build_distance:
		if not _built and not _building:
			_start_build()
	elif distance_to_player >= release_distance:
		_release_surface()


func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Node3D


func _start_build() -> void:
	if _chunk == null:
		return
	if not _chunk.has_method("get_chunk_width"):
		return
	if not _chunk.has_method("get_surface_height_at_local_position"):
		return

	_cells_x = maxi(int(_chunk.get("vertices_x")) - 1, 1)
	_cells_z = maxi(int(_chunk.get("vertices_z")) - 1, 1)
	_cell_size = maxf(float(_chunk.get("cell_size")), 0.05)
	_half_width = float(_chunk.call("get_chunk_width")) * 0.5
	_half_depth = float(_chunk.call("get_chunk_depth")) * 0.5

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = _get_tile_mesh()
	_multimesh.instance_count = _cells_x * _cells_z
	_multimesh.visible_instance_count = 0

	_instance = MultiMeshInstance3D.new()
	_instance.name = "MicroVoxelSurface"
	_instance.multimesh = _multimesh
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.visibility_range_end = release_distance + 16.0
	add_child(_instance)

	_build_index = 0
	_building = true
	_built = false


func _build_next_batch() -> void:
	if _multimesh == null:
		_building = false
		return

	var total_count: int = _cells_x * _cells_z
	var end_index: int = mini(
		_build_index + instances_per_frame,
		total_count
	)

	for instance_index in range(_build_index, end_index):
		_build_instance(instance_index)

	_build_index = end_index
	_multimesh.visible_instance_count = _build_index

	if _build_index >= total_count:
		_building = false
		_built = true


func _build_instance(instance_index: int) -> void:
	var cell_x: int = instance_index % _cells_x
	var cell_z: int = instance_index / _cells_x
	var local_x: float = (
		float(cell_x) * _cell_size
		- _half_width
		+ _cell_size * 0.5
	)
	var local_z: float = (
		float(cell_z) * _cell_size
		- _half_depth
		+ _cell_size * 0.5
	)
	var world_x: float = _chunk.global_position.x + local_x
	var world_z: float = _chunk.global_position.z + local_z
	var logical_height: float = WorldGenerator.get_terrain_height(
		world_x,
		world_z
	)
	var surface_height: float = float(
		_chunk.call(
			"get_surface_height_at_local_position",
			local_x,
			local_z
		)
	)

	if logical_height <= WorldGenerator.get_sea_level() + 0.08:
		_multimesh.set_instance_transform(
			instance_index,
			Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
		)
		_multimesh.set_instance_color(instance_index, Color.TRANSPARENT)
		return

	var hash_value: int = _stable_hash(cell_x, cell_z)
	var quarter_turn: float = float(hash_value % MICRO_PATTERN_COUNT) * PI * 0.5
	var basis := Basis(Vector3.UP, quarter_turn).scaled(
		Vector3(_cell_size, 1.0, _cell_size)
	)
	var transform := Transform3D(
		basis,
		Vector3(local_x, surface_height + surface_lift, local_z)
	)
	_multimesh.set_instance_transform(instance_index, transform)

	var base_color: Color = WorldGenerator.get_biome_color(
		world_x,
		world_z,
		logical_height
	)
	var variation: float = float((hash_value / 7) % 9 - 4) * 0.012
	var detail_color := Color(
		clampf(base_color.r + variation, 0.0, 1.0),
		clampf(base_color.g + variation, 0.0, 1.0),
		clampf(base_color.b + variation * 0.72, 0.0, 1.0),
		1.0
	)
	_multimesh.set_instance_color(instance_index, detail_color)


func _release_surface() -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	_multimesh = null
	_build_index = 0
	_building = false
	_built = false


func _stable_hash(cell_x: int, cell_z: int) -> int:
	var chunk_coordinates: Vector2i = _chunk.get("chunk_coordinates")
	var value: int = (
		cell_x * 73_856_093
		+ cell_z * 19_349_663
		+ chunk_coordinates.x * 83_492_791
		+ chunk_coordinates.y * 29_717_103
		+ WorldGenerator.get_world_seed()
	)
	return absi(value)


static func _get_tile_mesh() -> ArrayMesh:
	if _shared_tile_mesh != null:
		return _shared_tile_mesh

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Four quarter-cell columns. Their small height differences create a dense
	# micro-voxel silhouette while one MultiMesh transform still covers a full
	# gameplay terrain cell.
	_append_box(surface, Vector3(-0.25, 0.035, -0.25), Vector3(0.49, 0.07, 0.49))
	_append_box(surface, Vector3(0.25, 0.050, -0.25), Vector3(0.49, 0.10, 0.49))
	_append_box(surface, Vector3(-0.25, 0.060, 0.25), Vector3(0.49, 0.12, 0.49))
	_append_box(surface, Vector3(0.25, 0.042, 0.25), Vector3(0.49, 0.084, 0.49))

	_shared_tile_mesh = surface.commit()
	_shared_tile_mesh.surface_set_material(0, _get_material())
	return _shared_tile_mesh


static func _get_material() -> StandardMaterial3D:
	if _shared_material == null:
		_shared_material = StandardMaterial3D.new()
		_shared_material.albedo_color = Color.WHITE
		_shared_material.vertex_color_use_as_albedo = true
		_shared_material.roughness = 0.94
		_shared_material.metallic = 0.0
		_shared_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _shared_material


static func _append_box(
	surface: SurfaceTool,
	center: Vector3,
	size: Vector3
) -> void:
	var half: Vector3 = size * 0.5
	var x0: float = center.x - half.x
	var x1: float = center.x + half.x
	var y0: float = center.y - half.y
	var y1: float = center.y + half.y
	var z0: float = center.z - half.z
	var z1: float = center.z + half.z

	_append_quad(surface, Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.UP)
	_append_quad(surface, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3.DOWN)
	_append_quad(surface, Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y0, z0), Vector3.FORWARD)
	_append_quad(surface, Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3.BACK)
	_append_quad(surface, Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(x0, y0, z0), Vector3.LEFT)
	_append_quad(surface, Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3.RIGHT)


static func _append_quad(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3
) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.set_color(Color.WHITE)
		surface.set_normal(normal)
		surface.add_vertex(vertex)
