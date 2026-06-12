extends StaticBody3D


@export_category("Chunk Geometry")
@export_range(9, 257, 1) var vertices_x: int = 65
@export_range(9, 257, 1) var vertices_z: int = 65
@export_range(0.25, 5.0, 0.25) var cell_size: float = 1.0


var chunk_coordinates: Vector2i = Vector2i.ZERO


@onready var terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var terrain_collision: CollisionShape3D = $TerrainCollision


func _ready() -> void:
	_position_chunk()
	generate_terrain()


func get_chunk_width() -> float:
	return float(vertices_x - 1) * cell_size


func get_chunk_depth() -> float:
	return float(vertices_z - 1) * cell_size


func _position_chunk() -> void:
	position = Vector3(
		float(chunk_coordinates.x) * get_chunk_width(),
		0.0,
		float(chunk_coordinates.y) * get_chunk_depth()
	)


func generate_terrain() -> void:
	terrain_mesh.mesh = null
	terrain_collision.shape = null

	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var terrain_width := get_chunk_width()
	var terrain_depth := get_chunk_depth()

	var half_width := terrain_width * 0.5
	var half_depth := terrain_depth * 0.5

	for grid_z in range(vertices_z - 1):
		for grid_x in range(vertices_x - 1):
			var vertex_00 := _create_vertex(
				grid_x,
				grid_z,
				half_width,
				half_depth
			)

			var vertex_01 := _create_vertex(
				grid_x,
				grid_z + 1,
				half_width,
				half_depth
			)

			var vertex_10 := _create_vertex(
				grid_x + 1,
				grid_z,
				half_width,
				half_depth
			)

			var vertex_11 := _create_vertex(
				grid_x + 1,
				grid_z + 1,
				half_width,
				half_depth
			)

			var uv_00 := Vector2(
				float(grid_x) / float(vertices_x - 1),
				float(grid_z) / float(vertices_z - 1)
			)

			var uv_01 := Vector2(
				float(grid_x) / float(vertices_x - 1),
				float(grid_z + 1) / float(vertices_z - 1)
			)

			var uv_10 := Vector2(
				float(grid_x + 1) / float(vertices_x - 1),
				float(grid_z) / float(vertices_z - 1)
			)

			var uv_11 := Vector2(
				float(grid_x + 1) / float(vertices_x - 1),
				float(grid_z + 1) / float(vertices_z - 1)
			)

			var color_00 := _get_vertex_color(vertex_00)
			var color_01 := _get_vertex_color(vertex_01)
			var color_10 := _get_vertex_color(vertex_10)
			var color_11 := _get_vertex_color(vertex_11)

			# Erstes Dreieck.
			_add_vertex(
				surface_tool,
				vertex_00,
				uv_00,
				color_00
			)

			_add_vertex(
				surface_tool,
				vertex_10,
				uv_10,
				color_10
			)

			_add_vertex(
				surface_tool,
				vertex_01,
				uv_01,
				color_01
			)

			# Zweites Dreieck.
			_add_vertex(
				surface_tool,
				vertex_10,
				uv_10,
				color_10
			)

			_add_vertex(
				surface_tool,
				vertex_11,
				uv_11,
				color_11
			)

			_add_vertex(
				surface_tool,
				vertex_01,
				uv_01,
				color_01
			)

	surface_tool.index()
	surface_tool.generate_normals()

	var generated_mesh: ArrayMesh = surface_tool.commit()

	terrain_mesh.mesh = generated_mesh
	terrain_collision.shape = (
		generated_mesh.create_trimesh_shape()
	)

	_apply_terrain_material()


func _create_vertex(
	grid_x: int,
	grid_z: int,
	half_width: float,
	half_depth: float
) -> Vector3:
	var local_x := (
		float(grid_x) * cell_size
		- half_width
	)

	var local_z := (
		float(grid_z) * cell_size
		- half_depth
	)

	var world_x := (
		float(chunk_coordinates.x) * get_chunk_width()
		+ local_x
	)

	var world_z := (
		float(chunk_coordinates.y) * get_chunk_depth()
		+ local_z
	)

	var terrain_height := WorldGenerator.get_terrain_height(
		world_x,
		world_z
	)

	return Vector3(
		local_x,
		terrain_height,
		local_z
	)


func _get_vertex_color(
	local_position: Vector3
) -> Color:
	var world_x := (
		float(chunk_coordinates.x) * get_chunk_width()
		+ local_position.x
	)

	var world_z := (
		float(chunk_coordinates.y) * get_chunk_depth()
		+ local_position.z
	)

	return WorldGenerator.get_biome_color(
		world_x,
		world_z,
		local_position.y
	)


func _add_vertex(
	surface_tool: SurfaceTool,
	vertex_position: Vector3,
	uv: Vector2,
	vertex_color: Color
) -> void:
	surface_tool.set_color(vertex_color)
	surface_tool.set_uv(uv)
	surface_tool.add_vertex(vertex_position)


func _apply_terrain_material() -> void:
	var material := StandardMaterial3D.new()

	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0

	terrain_mesh.material_override = material
