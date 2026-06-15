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

const GRASS_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/grass_01.png"
)
const SAND_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/sand_01.png"
)
const DIRT_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/dirt_01.png"
)
const STONE_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/stone_01.png"
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

# Feste Surface-Reihenfolge für Shaderless Terrain Materials V1.
# Diese Indizes dürfen später nicht stillschweigend umsortiert werden.
const SURFACE_GRASS_TOP: int = 0
const SURFACE_SAND_TOP: int = 1
const SURFACE_DIRT_SIDE: int = 2
const SURFACE_STONE_SIDE: int = 3
const TERRAIN_SURFACE_COUNT: int = 4

# Hohe freiliegende Stufen erhalten bereits außerhalb des
# ROCKY_HIGHLANDS-Bioms eine Steinseite.
const STONE_SIDE_MIN_EXPOSURE: float = 1.0


@export_category("Chunk Geometry")
@export_range(9, 257, 1)
var vertices_x: int = 65

@export_range(9, 257, 1)
var vertices_z: int = 65

@export_range(0.25, 5.0, 0.25)
var cell_size: float = 1.0


var chunk_coordinates: Vector2i = Vector2i.ZERO
var _terrain_collision_faces: PackedVector3Array = PackedVector3Array()


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
	var cell_x: int = _get_cell_x_from_local(local_x)
	var cell_z: int = _get_cell_z_from_local(local_z)

	return _get_column_height_by_index(cell_x, cell_z)


func _position_chunk() -> void:
	position = Vector3(
		float(chunk_coordinates.x) * get_chunk_width(),
		0.0,
		float(chunk_coordinates.y) * get_chunk_depth()
	)


func generate_terrain() -> void:
	terrain_mesh.mesh = null
	terrain_mesh.material_override = null
	terrain_collision.shape = null
	_terrain_collision_faces = PackedVector3Array()

	var surface_tools: Array[SurfaceTool] = _create_terrain_surface_tools()

	var cells_x: int = _get_cells_x()
	var cells_z: int = _get_cells_z()

	var half_width: float = get_chunk_width() * 0.5
	var half_depth: float = get_chunk_depth() * 0.5

	for cell_z in range(cells_z):
		for cell_x in range(cells_x):
			_add_block_column(
				surface_tools,
				cell_x,
				cell_z,
				half_width,
				half_depth
			)

	# Die Kollision wird vor dem sichtbaren Mesh gesetzt. Dadurch bleibt
	# der Boden selbst dann kollidierbar, wenn eine Material-Surface
	# unerwartet nicht erstellt werden kann.
	if not _apply_terrain_collision():
		return

	var generated_mesh := ArrayMesh.new()

	for surface_index in range(TERRAIN_SURFACE_COUNT):
		var surface_was_committed: bool = _commit_terrain_surface(
			generated_mesh,
			surface_tools[surface_index],
			surface_index
		)

		if not surface_was_committed:
			return

	if generated_mesh.get_surface_count() != TERRAIN_SURFACE_COUNT:
		push_error(
			"Terrain mesh did not create all four material surfaces."
		)
		return

	terrain_mesh.mesh = generated_mesh


func _apply_terrain_collision() -> bool:
	if (
		_terrain_collision_faces.is_empty()
		or _terrain_collision_faces.size() % 3 != 0
	):
		push_error(
			"Terrain collision faces are empty or incomplete."
		)
		return false

	# Die Kollisionsform verwendet ausschließlich echte Terraindreiecke.
	# Die unsichtbaren Surface-Platzhalter werden nicht aufgenommen.
	var generated_collision := ConcavePolygonShape3D.new()
	generated_collision.set_faces(_terrain_collision_faces)
	generated_collision.backface_collision = true

	terrain_collision.shape = generated_collision
	terrain_collision.disabled = false

	return true


func _create_terrain_surface_tools() -> Array[SurfaceTool]:
	var surface_tools: Array[SurfaceTool] = []

	for _surface_index in range(TERRAIN_SURFACE_COUNT):
		var surface_tool := SurfaceTool.new()
		surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

		# ArrayMesh akzeptiert keine Surface mit null Vertices. Deshalb
		# beginnt jede Surface mit einem flächenlosen Dreieck aus drei
		# identischen Punkten. Es ist unsichtbar und wird nicht für die
		# Kollision gespeichert.
		_add_surface_placeholder(surface_tool)
		surface_tools.append(surface_tool)

	return surface_tools


func _add_surface_placeholder(surface_tool: SurfaceTool) -> void:
	var placeholder_position := Vector3.ZERO

	for _vertex_index in range(3):
		surface_tool.set_color(Color.WHITE)
		surface_tool.set_normal(Vector3.UP)
		surface_tool.set_uv(Vector2.ZERO)
		surface_tool.add_vertex(placeholder_position)


func _commit_terrain_surface(
	generated_mesh: ArrayMesh,
	surface_tool: SurfaceTool,
	surface_index: int
) -> bool:
	var arrays: Array = surface_tool.commit_to_arrays()

	if arrays.size() != Mesh.ARRAY_MAX:
		push_error(
			"Terrain surface %d returned invalid mesh arrays."
			% surface_index
		)
		return false

	var vertex_data: Variant = arrays[Mesh.ARRAY_VERTEX]

	if not (vertex_data is PackedVector3Array):
		push_error(
			"Terrain surface %d has invalid vertex data."
			% surface_index
		)
		return false

	var vertex_array: PackedVector3Array = vertex_data

	if vertex_array.size() < 3:
		push_error(
			"Terrain surface %d contains fewer than three vertices."
			% surface_index
		)
		return false

	generated_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)

	var committed_surface_index: int = (
		generated_mesh.get_surface_count() - 1
	)

	if committed_surface_index != surface_index:
		push_error(
			"Terrain surface order is invalid. Expected %d, received %d."
			% [surface_index, committed_surface_index]
		)
		return false

	generated_mesh.surface_set_name(
		surface_index,
		_get_terrain_surface_name(surface_index)
	)
	generated_mesh.surface_set_material(
		surface_index,
		_create_terrain_surface_material(surface_index)
	)

	return true


func _get_terrain_surface_name(surface_index: int) -> String:
	match surface_index:
		SURFACE_GRASS_TOP:
			return "GrassTop"
		SURFACE_SAND_TOP:
			return "SandTop"
		SURFACE_DIRT_SIDE:
			return "DirtSide"
		SURFACE_STONE_SIDE:
			return "StoneSide"
		_:
			return "UnknownTerrainSurface"


func _create_terrain_surface_material(
	surface_index: int
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()

	material.albedo_color = Color.WHITE
	material.albedo_texture = _get_terrain_surface_texture(
		surface_index
	)
	material.vertex_color_use_as_albedo = true
	material.texture_filter = (
		BaseMaterial3D.TEXTURE_FILTER_NEAREST
	)
	material.texture_repeat = true
	material.roughness = 1.0
	material.metallic = 0.0

	# Während dieses Reparaturschritts bleibt Culling wie bisher aus.
	# Erst nach bestätigtem Test wird es separat geprüft.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	return material


func _get_terrain_surface_texture(
	surface_index: int
) -> Texture2D:
	match surface_index:
		SURFACE_GRASS_TOP:
			return GRASS_TEXTURE
		SURFACE_SAND_TOP:
			return SAND_TEXTURE
		SURFACE_DIRT_SIDE:
			return DIRT_TEXTURE
		SURFACE_STONE_SIDE:
			return STONE_TEXTURE
		_:
			return GRASS_TEXTURE


func _add_block_column(
	surface_tools: Array[SurfaceTool],
	cell_x: int,
	cell_z: int,
	half_width: float,
	half_depth: float
) -> void:
	var x0: float = float(cell_x) * cell_size - half_width
	var x1: float = x0 + cell_size
	var z0: float = float(cell_z) * cell_size - half_depth
	var z1: float = z0 + cell_size

	var top_height: float = _get_column_height_by_index(
		cell_x,
		cell_z
	)

	var world_center: Vector2 = (
		_get_cell_center_world_position_by_index(
			cell_x,
			cell_z
		)
	)

	var logical_height: float = WorldGenerator.get_terrain_height(
		world_center.x,
		world_center.y
	)

	var biome: int = WorldGenerator.get_biome(
		world_center.x,
		world_center.y,
		logical_height
	)

	var top_color: Color = WorldGenerator.get_biome_color(
		world_center.x,
		world_center.y,
		logical_height
	)

	var side_color: Color = _get_side_color(top_color)

	var top_surface_index: int = _get_top_surface_index(biome)
	var top_surface_tool: SurfaceTool = (
		surface_tools[top_surface_index]
	)

	# Oberseite.
	_add_quad(
		top_surface_tool,
		Vector3(x0, top_height, z0),
		Vector3(x0, top_height, z1),
		Vector3(x1, top_height, z1),
		Vector3(x1, top_height, z0),
		top_color,
		Vector3.UP,
		Vector2(0.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0)
	)

	var west_height: float = _get_column_height_by_index(
		cell_x - 1,
		cell_z
	)

	if top_height > west_height:
		_add_side_quad(
			surface_tools,
			biome,
			logical_height,
			top_height,
			west_height,
			Vector3(x0, west_height, z1),
			Vector3(x0, top_height, z1),
			Vector3(x0, top_height, z0),
			Vector3(x0, west_height, z0),
			side_color,
			Vector3.LEFT
		)

	var east_height: float = _get_column_height_by_index(
		cell_x + 1,
		cell_z
	)

	if top_height > east_height:
		_add_side_quad(
			surface_tools,
			biome,
			logical_height,
			top_height,
			east_height,
			Vector3(x1, east_height, z0),
			Vector3(x1, top_height, z0),
			Vector3(x1, top_height, z1),
			Vector3(x1, east_height, z1),
			side_color,
			Vector3.RIGHT
		)

	var north_height: float = _get_column_height_by_index(
		cell_x,
		cell_z - 1
	)

	if top_height > north_height:
		_add_side_quad(
			surface_tools,
			biome,
			logical_height,
			top_height,
			north_height,
			Vector3(x1, north_height, z0),
			Vector3(x1, top_height, z0),
			Vector3(x0, top_height, z0),
			Vector3(x0, north_height, z0),
			side_color,
			Vector3.FORWARD
		)

	var south_height: float = _get_column_height_by_index(
		cell_x,
		cell_z + 1
	)

	if top_height > south_height:
		_add_side_quad(
			surface_tools,
			biome,
			logical_height,
			top_height,
			south_height,
			Vector3(x0, south_height, z1),
			Vector3(x0, top_height, z1),
			Vector3(x1, top_height, z1),
			Vector3(x1, south_height, z1),
			side_color,
			Vector3.BACK
		)


func _add_side_quad(
	surface_tools: Array[SurfaceTool],
	biome: int,
	logical_height: float,
	top_height: float,
	lower_height: float,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	point_d: Vector3,
	side_color: Color,
	face_normal: Vector3
) -> void:
	var side_surface_index: int = _get_side_surface_index(
		biome,
		logical_height,
		top_height,
		lower_height
	)

	var side_surface_tool: SurfaceTool = (
		surface_tools[side_surface_index]
	)

	var vertical_repeat: float = maxf(
		(top_height - lower_height) / maxf(cell_size, 0.001),
		1.0
	)

	_add_quad(
		side_surface_tool,
		point_a,
		point_b,
		point_c,
		point_d,
		side_color,
		face_normal,
		Vector2(0.0, vertical_repeat),
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, vertical_repeat)
	)


func _get_top_surface_index(biome: int) -> int:
	match biome:
		WorldGenerator.Biome.OCEAN, WorldGenerator.Biome.COAST:
			return SURFACE_SAND_TOP
		_:
			return SURFACE_GRASS_TOP


func _get_side_surface_index(
	biome: int,
	logical_height: float,
	top_height: float,
	lower_height: float
) -> int:
	var exposed_height: float = top_height - lower_height

	if biome == WorldGenerator.Biome.ROCKY_HIGHLANDS:
		return SURFACE_STONE_SIDE

	# logical_height bleibt absichtlich Teil dieser Materialentscheidung.
	# Damit kann die Regel später ohne Änderung an der Geometrie in eine
	# planeten- oder biomabhängige Materialpalette ausgelagert werden.
	if (
		logical_height > WorldGenerator.get_sea_level()
		and exposed_height >= STONE_SIDE_MIN_EXPOSURE
	):
		return SURFACE_STONE_SIDE

	return SURFACE_DIRT_SIDE


func _get_cells_x() -> int:
	return vertices_x - 1


func _get_cells_z() -> int:
	return vertices_z - 1


func _get_cell_x_from_local(local_x: float) -> int:
	var half_width: float = get_chunk_width() * 0.5
	var grid_position: float = (
		(local_x + half_width) / cell_size
	)

	return clampi(
		int(floor(grid_position)),
		0,
		_get_cells_x() - 1
	)


func _get_cell_z_from_local(local_z: float) -> int:
	var half_depth: float = get_chunk_depth() * 0.5
	var grid_position: float = (
		(local_z + half_depth) / cell_size
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
	var half_width: float = get_chunk_width() * 0.5
	var half_depth: float = get_chunk_depth() * 0.5

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
		float(chunk_coordinates.x) * get_chunk_width()
		+ local_x
	)

	var world_z: float = (
		float(chunk_coordinates.y) * get_chunk_depth()
		+ local_z
	)

	return Vector2(world_x, world_z)


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


func _get_side_color(top_color: Color) -> Color:
	var darkened: Color = top_color.darkened(
		SIDE_COLOR_DARKEN
	)

	var rock_color: Color = Color(
		0.34,
		0.34,
		0.32,
		1.0
	)

	if WorldGenerator.has_method("get_world_rock_color"):
		rock_color = WorldGenerator.get_world_rock_color()

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
	quad_color: Color,
	face_normal: Vector3,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2,
	uv_d: Vector2
) -> void:
	var safe_normal := face_normal.normalized()

	# Godot verwendet für Vorderseiten eine Wicklung im Uhrzeigersinn.
	# Das normale Kreuzprodukt beschreibt dagegen die gegen den
	# Uhrzeigersinn gerichtete Seite.
	var triangle_cross := (
		(point_b - point_a).cross(point_c - point_a)
	)

	var reverse_winding := (
		triangle_cross.dot(safe_normal) > 0.0
	)

	if reverse_winding:
		_add_triangle(
			surface_tool,
			point_a,
			point_c,
			point_b,
			quad_color,
			safe_normal,
			uv_a,
			uv_c,
			uv_b
		)
		_add_triangle(
			surface_tool,
			point_a,
			point_d,
			point_c,
			quad_color,
			safe_normal,
			uv_a,
			uv_d,
			uv_c
		)
		return

	_add_triangle(
		surface_tool,
		point_a,
		point_b,
		point_c,
		quad_color,
		safe_normal,
		uv_a,
		uv_b,
		uv_c
	)
	_add_triangle(
		surface_tool,
		point_a,
		point_c,
		point_d,
		quad_color,
		safe_normal,
		uv_a,
		uv_c,
		uv_d
	)


func _add_triangle(
	surface_tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	triangle_color: Color,
	triangle_normal: Vector3,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2
) -> void:
	_terrain_collision_faces.append(point_a)
	_terrain_collision_faces.append(point_b)
	_terrain_collision_faces.append(point_c)

	_add_mesh_vertex(
		surface_tool,
		point_a,
		triangle_color,
		triangle_normal,
		uv_a
	)
	_add_mesh_vertex(
		surface_tool,
		point_b,
		triangle_color,
		triangle_normal,
		uv_b
	)
	_add_mesh_vertex(
		surface_tool,
		point_c,
		triangle_color,
		triangle_normal,
		uv_c
	)


func _add_mesh_vertex(
	surface_tool: SurfaceTool,
	vertex_position: Vector3,
	vertex_color: Color,
	vertex_normal: Vector3,
	texture_uv: Vector2
) -> void:
	surface_tool.set_color(vertex_color)
	surface_tool.set_normal(vertex_normal)
	surface_tool.set_uv(texture_uv)
	surface_tool.add_vertex(vertex_position)


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

		var logical_height := WorldGenerator.get_terrain_height(
			world_position.x,
			world_position.y
		)

		var biome := WorldGenerator.get_biome(
			world_position.x,
			world_position.y,
			logical_height
		)

		var spawn_probability := (
			_get_tree_spawn_probability(biome)
		)

		if random.randf() > spawn_probability:
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

		var logical_height := WorldGenerator.get_terrain_height(
			world_position.x,
			world_position.y
		)

		var biome := WorldGenerator.get_biome(
			world_position.x,
			world_position.y,
			logical_height
		)

		var spawn_probability := (
			_get_bush_spawn_probability(biome)
		)

		if random.randf() > spawn_probability:
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

		var logical_height := WorldGenerator.get_terrain_height(
			world_position.x,
			world_position.y
		)

		var biome := WorldGenerator.get_biome(
			world_position.x,
			world_position.y,
			logical_height
		)

		var spawn_probability := (
			_get_grazer_spawn_probability(biome)
		)

		if random.randf() > spawn_probability:
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
		push_error("Tree scene could not be instantiated.")
		return false

	objects.add_child(tree)
	tree.position = Vector3(
		local_x,
		terrain_height,
		local_z
	)
	tree.rotation.y = random.randf_range(0.0, TAU)

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
	bush.rotation.y = random.randf_range(0.0, TAU)

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
	grazer.rotation.y = random.randf_range(0.0, TAU)

	var scale_factor := random.randf_range(
		0.90,
		1.10
	)
	grazer.scale = Vector3.ONE * scale_factor

	return true


func _get_tree_spawn_probability(biome: int) -> float:
	var density_multiplier: float = 1.0

	if WorldGenerator.has_method(
		"get_tree_density_multiplier"
	):
		density_multiplier = (
			WorldGenerator.get_tree_density_multiplier()
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
		base_probability * density_multiplier,
		0.0,
		1.0
	)


func _get_bush_spawn_probability(biome: int) -> float:
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


func _get_grazer_spawn_probability(biome: int) -> float:
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
	return _get_tree_chunk_seed() + BUSH_SEED_OFFSET


func _get_grazer_chunk_seed() -> int:
	return _get_tree_chunk_seed() + GRAZER_SEED_OFFSET


func _clear_generated_objects() -> void:
	for child in objects.get_children():
		child.queue_free()
