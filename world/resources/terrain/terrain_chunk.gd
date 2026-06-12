extends StaticBody3D


const TREE_SCENE: PackedScene = preload(
	"res://world/resources/trees/tree.tscn"
)

const BERRY_BUSH_SCENE: PackedScene = preload(
	"res://world/resources/plants/berry_bush.tscn"
)

const GRAZER_SCENE: PackedScene = preload(
	"res://creatures/animals/grazer/grazer.tscn"
)


const TREE_ATTEMPTS_PER_CHUNK: int = 8
const BUSH_ATTEMPTS_PER_CHUNK: int = 14
const GRAZER_ATTEMPTS_PER_CHUNK: int = 4

const OBJECT_EDGE_MARGIN: float = 3.0
const SPAWN_CLEAR_RADIUS: float = 8.0

const MINIMUM_OBJECT_DISTANCE: float = 2.0
const MINIMUM_GRAZER_DISTANCE: float = 4.0

const BUSH_SEED_OFFSET: int = 83_492_791
const GRAZER_SEED_OFFSET: int = 147_298_431


@export_category("Chunk Geometry")
@export_range(9, 257, 1) var vertices_x: int = 65
@export_range(9, 257, 1) var vertices_z: int = 65
@export_range(0.25, 5.0, 0.25) var cell_size: float = 1.0


var chunk_coordinates: Vector2i = Vector2i.ZERO


@onready var terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var terrain_collision: CollisionShape3D = $TerrainCollision
@onready var water_mesh: MeshInstance3D = $WaterMesh
@onready var objects: Node3D = $Objects


func _ready() -> void:
	_position_chunk()
	generate_terrain()
	_create_water_surface()
	_generate_objects()


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

	if generated_mesh == null:
		push_error("Terrain mesh could not be generated.")
		return

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


func _create_water_surface() -> void:
	var plane_mesh := PlaneMesh.new()

	plane_mesh.size = Vector2(
		get_chunk_width(),
		get_chunk_depth()
	)

	var water_material := StandardMaterial3D.new()

	water_material.albedo_color = Color(
		0.05,
		0.30,
		0.52,
		0.62
	)

	water_material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)

	water_material.roughness = 0.18
	water_material.metallic = 0.0

	water_mesh.mesh = plane_mesh
	water_mesh.material_override = water_material

	water_mesh.position = Vector3(
		0.0,
		WorldGenerator.get_sea_level() + 0.02,
		0.0
	)

	water_mesh.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)


func _generate_objects() -> void:
	_clear_generated_objects()

	var placed_positions: Array[Vector2] = []

	_generate_trees(placed_positions)
	_generate_berry_bushes(placed_positions)
	_generate_grazers(placed_positions)


func _generate_trees(
	placed_positions: Array[Vector2]
) -> void:
	var random := RandomNumberGenerator.new()

	# Der bisherige Baum-Seed bleibt unverändert.
	random.seed = _get_tree_chunk_seed()

	var half_width := get_chunk_width() * 0.5
	var half_depth := get_chunk_depth() * 0.5

	for _attempt in range(TREE_ATTEMPTS_PER_CHUNK):
		var local_x := random.randf_range(
			-half_width + OBJECT_EDGE_MARGIN,
			half_width - OBJECT_EDGE_MARGIN
		)

		var local_z := random.randf_range(
			-half_depth + OBJECT_EDGE_MARGIN,
			half_depth - OBJECT_EDGE_MARGIN
		)

		var world_position := _get_world_position_2d(
			local_x,
			local_z
		)

		if world_position.length() < SPAWN_CLEAR_RADIUS:
			continue

		var terrain_height := WorldGenerator.get_terrain_height(
			world_position.x,
			world_position.y
		)

		var biome := WorldGenerator.get_biome(
			world_position.x,
			world_position.y,
			terrain_height
		)

		var spawn_probability := (
			_get_tree_spawn_probability(biome)
		)

		if random.randf() > spawn_probability:
			continue

		if _create_tree(
			local_x,
			local_z,
			terrain_height,
			random
		):
			placed_positions.append(
				Vector2(local_x, local_z)
			)


func _generate_berry_bushes(
	placed_positions: Array[Vector2]
) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = _get_bush_chunk_seed()

	var half_width := get_chunk_width() * 0.5
	var half_depth := get_chunk_depth() * 0.5

	for _attempt in range(BUSH_ATTEMPTS_PER_CHUNK):
		var local_x := random.randf_range(
			-half_width + OBJECT_EDGE_MARGIN,
			half_width - OBJECT_EDGE_MARGIN
		)

		var local_z := random.randf_range(
			-half_depth + OBJECT_EDGE_MARGIN,
			half_depth - OBJECT_EDGE_MARGIN
		)

		var local_position_2d := Vector2(
			local_x,
			local_z
		)

		if not _is_position_clear(
			local_position_2d,
			placed_positions,
			MINIMUM_OBJECT_DISTANCE
		):
			continue

		var world_position := _get_world_position_2d(
			local_x,
			local_z
		)

		if world_position.length() < SPAWN_CLEAR_RADIUS:
			continue

		var terrain_height := WorldGenerator.get_terrain_height(
			world_position.x,
			world_position.y
		)

		var biome := WorldGenerator.get_biome(
			world_position.x,
			world_position.y,
			terrain_height
		)

		var spawn_probability := (
			_get_bush_spawn_probability(biome)
		)

		if random.randf() > spawn_probability:
			continue

		if _create_berry_bush(
			local_x,
			local_z,
			terrain_height,
			random
		):
			placed_positions.append(local_position_2d)


func _generate_grazers(
	placed_positions: Array[Vector2]
) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = _get_grazer_chunk_seed()

	var half_width := get_chunk_width() * 0.5
	var half_depth := get_chunk_depth() * 0.5

	for _attempt in range(GRAZER_ATTEMPTS_PER_CHUNK):
		var local_x := random.randf_range(
			-half_width + OBJECT_EDGE_MARGIN,
			half_width - OBJECT_EDGE_MARGIN
		)

		var local_z := random.randf_range(
			-half_depth + OBJECT_EDGE_MARGIN,
			half_depth - OBJECT_EDGE_MARGIN
		)

		var local_position_2d := Vector2(
			local_x,
			local_z
		)

		if not _is_position_clear(
			local_position_2d,
			placed_positions,
			MINIMUM_GRAZER_DISTANCE
		):
			continue

		var world_position := _get_world_position_2d(
			local_x,
			local_z
		)

		if world_position.length() < SPAWN_CLEAR_RADIUS:
			continue

		var terrain_height := WorldGenerator.get_terrain_height(
			world_position.x,
			world_position.y
		)

		var biome := WorldGenerator.get_biome(
			world_position.x,
			world_position.y,
			terrain_height
		)

		var spawn_probability := (
			_get_grazer_spawn_probability(biome)
		)

		if random.randf() > spawn_probability:
			continue

		if _create_grazer(
			local_x,
			local_z,
			terrain_height,
			random
		):
			placed_positions.append(local_position_2d)


func _create_tree(
	local_x: float,
	local_z: float,
	terrain_height: float,
	random: RandomNumberGenerator
) -> bool:
	var tree := TREE_SCENE.instantiate() as Node3D

	if tree == null:
		push_error("Tree scene could not be instantiated.")
		return false

	objects.add_child(tree)

	tree.position = Vector3(
		local_x,
		terrain_height,
		local_z
	)

	tree.rotation.y = random.randf_range(
		0.0,
		TAU
	)

	var scale_factor := random.randf_range(
		0.85,
		1.15
	)

	tree.scale = Vector3.ONE * scale_factor

	return true


func _create_berry_bush(
	local_x: float,
	local_z: float,
	terrain_height: float,
	random: RandomNumberGenerator
) -> bool:
	var bush := BERRY_BUSH_SCENE.instantiate() as Node3D

	if bush == null:
		push_error(
			"Berry bush scene could not be instantiated."
		)
		return false

	objects.add_child(bush)

	bush.position = Vector3(
		local_x,
		terrain_height,
		local_z
	)

	bush.rotation.y = random.randf_range(
		0.0,
		TAU
	)

	var scale_factor := random.randf_range(
		0.85,
		1.15
	)

	bush.scale = Vector3.ONE * scale_factor

	return true


func _create_grazer(
	local_x: float,
	local_z: float,
	terrain_height: float,
	random: RandomNumberGenerator
) -> bool:
	var grazer := GRAZER_SCENE.instantiate() as Node3D

	if grazer == null:
		push_error(
			"Grazer scene could not be instantiated."
		)
		return false

	objects.add_child(grazer)

	grazer.position = Vector3(
		local_x,
		terrain_height + 0.05,
		local_z
	)

	grazer.rotation.y = random.randf_range(
		0.0,
		TAU
	)

	var scale_factor := random.randf_range(
		0.90,
		1.10
	)

	grazer.scale = Vector3.ONE * scale_factor

	return true


func _get_tree_spawn_probability(
	biome: int
) -> float:
	match biome:
		WorldGenerator.Biome.GRASSLAND:
			return 0.55

		WorldGenerator.Biome.WETLAND:
			return 0.75

		WorldGenerator.Biome.COLD_GRASSLAND:
			return 0.25

		_:
			return 0.0


func _get_bush_spawn_probability(
	biome: int
) -> float:
	match biome:
		WorldGenerator.Biome.GRASSLAND:
			return 0.55

		WorldGenerator.Biome.WETLAND:
			return 0.80

		WorldGenerator.Biome.COLD_GRASSLAND:
			return 0.20

		WorldGenerator.Biome.STEPPE:
			return 0.08

		_:
			return 0.0


func _get_grazer_spawn_probability(
	biome: int
) -> float:
	match biome:
		WorldGenerator.Biome.GRASSLAND:
			return 0.40

		WorldGenerator.Biome.STEPPE:
			return 0.30

		WorldGenerator.Biome.WETLAND:
			return 0.18

		WorldGenerator.Biome.COLD_GRASSLAND:
			return 0.12

		_:
			return 0.0


func _is_position_clear(
	candidate_position: Vector2,
	placed_positions: Array[Vector2],
	minimum_distance: float
) -> bool:
	for placed_position in placed_positions:
		if (
			candidate_position.distance_to(placed_position)
			< minimum_distance
		):
			return false

	return true


func _get_world_position_2d(
	local_x: float,
	local_z: float
) -> Vector2:
	return Vector2(
		float(chunk_coordinates.x) * get_chunk_width()
			+ local_x,
		float(chunk_coordinates.y) * get_chunk_depth()
			+ local_z
	)


func _get_tree_chunk_seed() -> int:
	return (
		GameState.world_seed
		+ chunk_coordinates.x * 73_856_093
		+ chunk_coordinates.y * 19_349_663
	)


func _get_bush_chunk_seed() -> int:
	return (
		_get_tree_chunk_seed()
		+ BUSH_SEED_OFFSET
	)


func _get_grazer_chunk_seed() -> int:
	return (
		_get_tree_chunk_seed()
		+ GRAZER_SEED_OFFSET
	)


func _clear_generated_objects() -> void:
	for child in objects.get_children():
		child.queue_free()
