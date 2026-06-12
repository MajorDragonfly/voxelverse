extends StaticBody3D


@export_category("Chunk Size")
@export_range(9, 257, 1) var vertices_x: int = 65
@export_range(9, 257, 1) var vertices_z: int = 65
@export_range(0.25, 5.0, 0.25) var cell_size: float = 1.0

@export_category("Terrain Shape")
@export_range(0.001, 0.2, 0.001) var noise_frequency: float = 0.025
@export_range(0.0, 30.0, 0.5) var height_scale: float = 6.0
@export_range(1, 8, 1) var noise_octaves: int = 5

@export_category("Spawn Area")
@export_range(0.0, 20.0, 0.5) var flat_spawn_radius: float = 4.0
@export_range(0.5, 20.0, 0.5) var spawn_blend_distance: float = 8.0

# Position dieses Chunks im späteren Chunk-Raster.
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

	var noise := FastNoiseLite.new()

	noise.seed = GameState.world_seed
	noise.frequency = noise_frequency
	noise.fractal_octaves = noise_octaves
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0

	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var terrain_width := get_chunk_width()
	var terrain_depth := get_chunk_depth()

	var half_width := terrain_width * 0.5
	var half_depth := terrain_depth * 0.5

	for z in range(vertices_z - 1):
		for x in range(vertices_x - 1):
			var vertex_00 := _create_vertex(
				x,
				z,
				noise,
				half_width,
				half_depth
			)

			var vertex_01 := _create_vertex(
				x,
				z + 1,
				noise,
				half_width,
				half_depth
			)

			var vertex_10 := _create_vertex(
				x + 1,
				z,
				noise,
				half_width,
				half_depth
			)

			var vertex_11 := _create_vertex(
				x + 1,
				z + 1,
				noise,
				half_width,
				half_depth
			)

			var uv_00 := Vector2(
				float(x) / float(vertices_x - 1),
				float(z) / float(vertices_z - 1)
			)

			var uv_01 := Vector2(
				float(x) / float(vertices_x - 1),
				float(z + 1) / float(vertices_z - 1)
			)

			var uv_10 := Vector2(
				float(x + 1) / float(vertices_x - 1),
				float(z) / float(vertices_z - 1)
			)

			var uv_11 := Vector2(
				float(x + 1) / float(vertices_x - 1),
				float(z + 1) / float(vertices_z - 1)
			)

			# Erstes Dreieck.
			_add_vertex(surface_tool, vertex_00, uv_00)
			_add_vertex(surface_tool, vertex_10, uv_10)
			_add_vertex(surface_tool, vertex_01, uv_01)

			# Zweites Dreieck.
			_add_vertex(surface_tool, vertex_10, uv_10)
			_add_vertex(surface_tool, vertex_11, uv_11)
			_add_vertex(surface_tool, vertex_01, uv_01)

	surface_tool.index()
	surface_tool.generate_normals()

	var generated_mesh: ArrayMesh = surface_tool.commit()

	terrain_mesh.mesh = generated_mesh
	terrain_collision.shape = generated_mesh.create_trimesh_shape()

	_apply_terrain_material()


func _create_vertex(
	grid_x: int,
	grid_z: int,
	noise: FastNoiseLite,
	half_width: float,
	half_depth: float
) -> Vector3:
	# Position innerhalb dieses Chunks.
	var local_x := float(grid_x) * cell_size - half_width
	var local_z := float(grid_z) * cell_size - half_depth

	# Globale Position innerhalb der gesamten Welt.
	# Dadurch stimmen die Höhen an Chunk-Grenzen überein.
	var world_x := (
		float(chunk_coordinates.x) * get_chunk_width()
		+ local_x
	)

	var world_z := (
		float(chunk_coordinates.y) * get_chunk_depth()
		+ local_z
	)

	var height := noise.get_noise_2d(
		world_x,
		world_z
	) * height_scale

	# Nur rund um den globalen Weltmittelpunkt wird abgeflacht.
	var distance_to_spawn := Vector2(
		world_x,
		world_z
	).length()

	var flatten_factor := smoothstep(
		flat_spawn_radius,
		flat_spawn_radius + spawn_blend_distance,
		distance_to_spawn
	)

	height *= flatten_factor

	return Vector3(
		local_x,
		height,
		local_z
	)


func _add_vertex(
	surface_tool: SurfaceTool,
	vertex_position: Vector3,
	uv: Vector2
) -> void:
	surface_tool.set_uv(uv)
	surface_tool.add_vertex(vertex_position)


func _apply_terrain_material() -> void:
	var material := StandardMaterial3D.new()

	material.albedo_color = Color(
		0.16,
		0.42,
		0.12,
		1.0
	)

	material.roughness = 1.0

	terrain_mesh.material_override = material
