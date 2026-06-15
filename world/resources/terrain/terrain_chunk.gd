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

const SIDE_COLOR_DARKEN: float = 0.16
const SIDE_ROCK_BLEND: float = 0.32


@export_category("Chunk Geometry")

@export_range(9, 257, 1)
var vertices_x: int = 65

@export_range(9, 257, 1)
var vertices_z: int = 65

@export_range(0.25, 5.0, 0.25)
var cell_size: float = 1.0


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


func get_surface_height_at_local_position(
	local_x: float,
	local_z: float
) -> float:
	var cell_x: int = _get_cell_x_from_local(
		local_x
	)

	var cell_z: int = _get_cell_z_from_local(
		local_z
	)

	return _get_column_height_by_index(
		cell_x,
		cell_z
	)


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

	surface_tool.begin(
		Mesh.PRIMITIVE_TRIANGLES
	)

	var cells_x: int = _get_cells_x()
	var cells_z: int = _get_cells_z()

	var half_width: float = (
		get_chunk_width() * 0.5
	)

	var half_depth: float = (
		get_chunk_depth() * 0.5
	)

	for cell_z in range(cells_z):
		for cell_x in range(cells_x):
			_add_block_column(
				surface_tool,
				cell_x,
				cell_z,
				half_width,
				half_depth
			)

	surface_tool.generate_normals()

	var generated_mesh: ArrayMesh = (
		surface_tool.commit()
	)

	if generated_mesh == null:
		push_error(
			"Terrain mesh could not be generated."
		)
		return

	terrain_mesh.mesh = generated_mesh

	var generated_collision: ConcavePolygonShape3D = (
		generated_mesh.create_trimesh_shape()
	)

	if generated_collision == null:
		push_error(
			"Terrain collision could not be generated."
		)
		return

	# Concave-Trimeshes sind hohl und standardmäßig
	# nur von der Seite ihrer Flächennormalen kollidierbar.
	#
	# Blockterrain benötigt eine zuverlässige Kollision
	# von beiden Seiten, insbesondere beim Spawn und an
	# senkrechten Stufenwänden.
	generated_collision.backface_collision = true

	terrain_collision.shape = generated_collision
	terrain_collision.disabled = false

	_apply_terrain_material()


func _add_block_column(
	surface_tool: SurfaceTool,
	cell_x: int,
	cell_z: int,
	half_width: float,
	half_depth: float
) -> void:
	var x0: float = (
		float(cell_x) * cell_size
		- half_width
	)

	var x1: float = (
		x0 + cell_size
	)

	var z0: float = (
		float(cell_z) * cell_size
		- half_depth
	)

	var z1: float = (
		z0 + cell_size
	)

	var top_height: float = (
		_get_column_height_by_index(
			cell_x,
			cell_z
		)
	)

	var world_center: Vector2 = (
		_get_cell_center_world_position_by_index(
			cell_x,
			cell_z
		)
	)

	var logical_height: float = (
		WorldGenerator.get_terrain_height(
			world_center.x,
			world_center.y
		)
	)

	var top_color: Color = (
		WorldGenerator.get_biome_color(
			world_center.x,
			world_center.y,
			logical_height
		)
	)

	var side_color: Color = (
		_get_side_color(
			top_color
		)
	)

	# Horizontale Oberseite der Blocksäule.
	_add_quad(
		surface_tool,
		Vector3(
			x0,
			top_height,
			z0
		),
		Vector3(
			x0,
			top_height,
			z1
		),
		Vector3(
			x1,
			top_height,
			z1
		),
		Vector3(
			x1,
			top_height,
			z0
		),
		top_color
	)

	# Westliche Seitenwand.
	var west_height: float = (
		_get_column_height_by_index(
			cell_x - 1,
			cell_z
		)
	)

	if top_height > west_height:
		_add_quad(
			surface_tool,
			Vector3(
				x0,
				west_height,
				z1
			),
			Vector3(
				x0,
				top_height,
				z1
			),
			Vector3(
				x0,
				top_height,
				z0
			),
			Vector3(
				x0,
				west_height,
				z0
			),
			side_color
		)

	# Östliche Seitenwand.
	var east_height: float = (
		_get_column_height_by_index(
			cell_x + 1,
			cell_z
		)
	)

	if top_height > east_height:
		_add_quad(
			surface_tool,
			Vector3(
				x1,
				east_height,
				z0
			),
			Vector3(
				x1,
				top_height,
				z0
			),
			Vector3(
				x1,
				top_height,
				z1
			),
			Vector3(
				x1,
				east_height,
				z1
			),
			side_color
		)

	# Nördliche Seitenwand.
	var north_height: float = (
		_get_column_height_by_index(
			cell_x,
			cell_z - 1
		)
	)

	if top_height > north_height:
		_add_quad(
			surface_tool,
			Vector3(
				x1,
				north_height,
				z0
			),
			Vector3(
				x1,
				top_height,
				z0
			),
			Vector3(
				x0,
				top_height,
				z0
			),
			Vector3(
				x0,
				north_height,
				z0
			),
			side_color
		)

	# Südliche Seitenwand.
	var south_height: float = (
		_get_column_height_by_index(
			cell_x,
			cell_z + 1
		)
	)

	if top_height > south_height:
		_add_quad(
			surface_tool,
			Vector3(
				x0,
				south_height,
				z1
			),
			Vector3(
				x0,
				top_height,
				z1
			),
			Vector3(
				x1,
				top_height,
				z1
			),
			Vector3(
				x1,
				south_height,
				z1
			),
			side_color
		)


func _get_cells_x() -> int:
	return vertices_x - 1


func _get_cells_z() -> int:
	return vertices_z - 1


func _get_cell_x_from_local(
	local_x: float
) -> int:
	var half_width: float = (
		get_chunk_width() * 0.5
	)

	var grid_position: float = (
		(local_x + half_width)
		/ cell_size
	)

	return clampi(
		int(floor(grid_position)),
		0,
		_get_cells_x() - 1
	)


func _get_cell_z_from_local(
	local_z: float
) -> int:
	var half_depth: float = (
		get_chunk_depth() * 0.5
	)

	var grid_position: float = (
		(local_z + half_depth)
		/ cell_size
	)

	return clampi(
		int(floor(grid_position)),
		0,
		_get_cells_z() - 1
	)


func _get_cell_center_world_position_by_index(
	cell_x: int,
	cell_z: int
) -> Vector2:
	var half_width: float = (
		get_chunk_width() * 0.5
	)

	var half_depth: float = (
		get_chunk_depth() * 0.5
	)

	var local_x: float = (
		float(cell_x) * cell_size
		- half_width
		+ cell_size * 0.5
	)

	var local_z: float = (
		float(cell_z) * cell_size
		- half_depth
		+ cell_size * 0.5
	)

	var world_x: float = (
		float(chunk_coordinates.x)
		* get_chunk_width()
		+ local_x
	)

	var world_z: float = (
		float(chunk_coordinates.y)
		* get_chunk_depth()
		+ local_z
	)

	return Vector2(
		world_x,
		world_z
	)


func _get_column_height_by_index(
	cell_x: int,
	cell_z: int
) -> float:
	var world_center: Vector2 = (
		_get_cell_center_world_position_by_index(
			cell_x,
			cell_z
		)
	)

	return WorldGenerator.get_visual_terrain_height(
		world_center.x,
		world_center.y
	)


func _get_side_color(
	top_color: Color
) -> Color:
	var darkened: Color = (
		top_color.darkened(
			SIDE_COLOR_DARKEN
		)
	)

	var rock_color: Color = Color(
		0.34,
		0.34,
		0.32,
		1.0
	)

	if WorldGenerator.has_method(
		"get_world_rock_color"
	):
		rock_color = (
			WorldGenerator.get_world_rock_color()
		)

	return darkened.lerp(
		rock_color,
		SIDE_ROCK_BLEND
	)


func _add_quad(
	surface_tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	point_d: Vector3,
	quad_color: Color
) -> void:
	surface_tool.set_color(
		quad_color
	)
	surface_tool.add_vertex(
		point_a
	)

	surface_tool.set_color(
		quad_color
	)
	surface_tool.add_vertex(
		point_b
	)

	surface_tool.set_color(
		quad_color
	)
	surface_tool.add_vertex(
		point_c
	)

	surface_tool.set_color(
		quad_color
	)
	surface_tool.add_vertex(
		point_a
	)

	surface_tool.set_color(
		quad_color
	)
	surface_tool.add_vertex(
		point_c
	)

	surface_tool.set_color(
		quad_color
	)
	surface_tool.add_vertex(
		point_d
	)


func _apply_terrain_material() -> void:
	var material := StandardMaterial3D.new()

	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0

	# Blockflächen sollen auf beiden Seiten sichtbar sein.
	# Das verhindert außerdem unsichtbare Flächen während
	# der weiteren Entwicklung des Block-Meshers.
	material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)

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
		GeometryInstance3D
		.SHADOW_CASTING_SETTING_OFF
	)


func _generate_objects() -> void:
	_clear_generated_objects()

	var placed_positions: Array[Vector2] = []

	_generate_trees(
		placed_positions
	)

	_generate_berry_bushes(
		placed_positions
	)

	_generate_grazers(
		placed_positions
	)


func _generate_trees(
	placed_positions: Array[Vector2]
) -> void:
	var random := RandomNumberGenerator.new()

	random.seed = _get_tree_chunk_seed()

	var half_width := (
		get_chunk_width() * 0.5
	)

	var half_depth := (
		get_chunk_depth() * 0.5
	)

	for _attempt in range(
		TREE_ATTEMPTS_PER_CHUNK
	):
		var local_x := random.randf_range(
			-half_width + OBJECT_EDGE_MARGIN,
			half_width - OBJECT_EDGE_MARGIN
		)

		var local_z := random.randf_range(
			-half_depth + OBJECT_EDGE_MARGIN,
			half_depth - OBJECT_EDGE_MARGIN
		)

		var world_position := (
			_get_world_position_2d(
				local_x,
				local_z
			)
		)

		if (
			world_position.length()
			< SPAWN_CLEAR_RADIUS
		):
			continue

		var logical_height := (
			WorldGenerator.get_terrain_height(
				world_position.x,
				world_position.y
			)
		)

		var biome := WorldGenerator.get_biome(
			world_position.x,
			world_position.y,
			logical_height
		)

		var spawn_probability := (
			_get_tree_spawn_probability(
				biome
			)
		)

		if (
			random.randf()
			> spawn_probability
		):
			continue

		var surface_height := (
			get_surface_height_at_local_position(
				local_x,
				local_z
			)
		)

		if _create_tree(
			local_x,
			local_z,
			surface_height,
			random
		):
			placed_positions.append(
				Vector2(
					local_x,
					local_z
				)
			)


func _generate_berry_bushes(
	placed_positions: Array[Vector2]
) -> void:
	var random := RandomNumberGenerator.new()

	random.seed = _get_bush_chunk_seed()

	var half_width := (
		get_chunk_width() * 0.5
	)

	var half_depth := (
		get_chunk_depth() * 0.5
	)

	for _attempt in range(
		BUSH_ATTEMPTS_PER_CHUNK
	):
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

		var world_position := (
			_get_world_position_2d(
				local_x,
				local_z
			)
		)

		if (
			world_position.length()
			< SPAWN_CLEAR_RADIUS
		):
			continue

		var logical_height := (
			WorldGenerator.get_terrain_height(
				world_position.x,
				world_position.y
			)
		)

		var biome := WorldGenerator.get_biome(
			world_position.x,
			world_position.y,
			logical_height
		)

		var spawn_probability := (
			_get_bush_spawn_probability(
				biome
			)
		)

		if (
			random.randf()
			> spawn_probability
		):
			continue

		var surface_height := (
			get_surface_height_at_local_position(
				local_x,
				local_z
			)
		)

		if _create_berry_bush(
			local_x,
			local_z,
			surface_height,
			random
		):
			placed_positions.append(
				local_position_2d
			)


func _generate_grazers(
	placed_positions: Array[Vector2]
) -> void:
	var random := RandomNumberGenerator.new()

	random.seed = _get_grazer_chunk_seed()

	var half_width := (
		get_chunk_width() * 0.5
	)

	var half_depth := (
		get_chunk_depth() * 0.5
	)

	for _attempt in range(
		GRAZER_ATTEMPTS_PER_CHUNK
	):
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

		var world_position := (
			_get_world_position_2d(
				local_x,
				local_z
			)
		)

		if (
			world_position.length()
			< SPAWN_CLEAR_RADIUS
		):
			continue

		var logical_height := (
			WorldGenerator.get_terrain_height(
				world_position.x,
				world_position.y
			)
		)

		var biome := WorldGenerator.get_biome(
			world_position.x,
			world_position.y,
			logical_height
		)

		var spawn_probability := (
			_get_grazer_spawn_probability(
				biome
			)
		)

		if (
			random.randf()
			> spawn_probability
		):
			continue

		var surface_height := (
			get_surface_height_at_local_position(
				local_x,
				local_z
			)
		)

		if _create_grazer(
			local_x,
			local_z,
			surface_height,
			random
		):
			placed_positions.append(
				local_position_2d
			)


func _create_tree(
	local_x: float,
	local_z: float,
	terrain_height: float,
	random: RandomNumberGenerator
) -> bool:
	var tree := TREE_SCENE.instantiate() as Node3D

	if tree == null:
		push_error(
			"Tree scene could not be instantiated."
		)
		return false

	objects.add_child(
		tree
	)

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

	tree.scale = (
		Vector3.ONE * scale_factor
	)

	return true


func _create_berry_bush(
	local_x: float,
	local_z: float,
	terrain_height: float,
	random: RandomNumberGenerator
) -> bool:
	var bush := (
		BERRY_BUSH_SCENE.instantiate()
		as Node3D
	)

	if bush == null:
		push_error(
			"Berry bush scene could not be instantiated."
		)
		return false

	objects.add_child(
		bush
	)

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

	bush.scale = (
		Vector3.ONE * scale_factor
	)

	return true


func _create_grazer(
	local_x: float,
	local_z: float,
	terrain_height: float,
	random: RandomNumberGenerator
) -> bool:
	var grazer := (
		GRAZER_SCENE.instantiate()
		as Node3D
	)

	if grazer == null:
		push_error(
			"Grazer scene could not be instantiated."
		)
		return false

	objects.add_child(
		grazer
	)

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

	grazer.scale = (
		Vector3.ONE * scale_factor
	)

	return true


func _get_tree_spawn_probability(
	biome: int
) -> float:
	var density_multiplier: float = 1.0

	if WorldGenerator.has_method(
		"get_tree_density_multiplier"
	):
		density_multiplier = (
			WorldGenerator
			.get_tree_density_multiplier()
		)

	var base_probability: float = 0.0

	match biome:
		WorldGenerator.Biome.GRASSLAND:
			base_probability = 0.55

		WorldGenerator.Biome.WETLAND:
			base_probability = 0.75

		WorldGenerator.Biome.COLD_GRASSLAND:
			base_probability = 0.25

		_:
			base_probability = 0.0

	return clampf(
		base_probability
		* density_multiplier,
		0.0,
		1.0
	)


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
			candidate_position.distance_to(
				placed_position
			)
			< minimum_distance
		):
			return false

	return true


func _get_world_position_2d(
	local_x: float,
	local_z: float
) -> Vector2:
	return Vector2(
		float(chunk_coordinates.x)
		* get_chunk_width()
		+ local_x,
		float(chunk_coordinates.y)
		* get_chunk_depth()
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
