extends Node3D


@export_category("Procedural Appearance")
@export_range(0.15, 0.60, 0.05) var voxel_size: float = 0.25
@export_range(0.75, 3.0, 0.05) var nest_radius: float = 1.25
@export_range(12, 48, 1) var ring_voxel_count: int = 24
@export_range(1, 4, 1) var ring_height_voxels: int = 2
@export_range(0.0, 0.50, 0.05) var bedding_gap_probability: float = 0.12

@export_category("Placement")
@export var snap_to_terrain: bool = true
@export_range(0.1, 3.0, 0.1) var respawn_height: float = 0.75


const TWIG_COLOR: Color = Color(
	0.31,
	0.17,
	0.07,
	1.0
)

const DARK_TWIG_COLOR: Color = Color(
	0.20,
	0.10,
	0.04,
	1.0
)

const BEDDING_COLOR: Color = Color(
	0.48,
	0.39,
	0.17,
	1.0
)

const DRY_GRASS_COLOR: Color = Color(
	0.58,
	0.52,
	0.25,
	1.0
)


@onready var nest_mesh: MeshInstance3D = $NestMesh
@onready var spawn_point: Marker3D = $SpawnPoint


func _ready() -> void:
	add_to_group("player_nest")

	call_deferred("_initialize_nest")


func _initialize_nest() -> void:
	if snap_to_terrain:
		_snap_to_terrain()

	spawn_point.position = Vector3(
		0.0,
		respawn_height,
		0.0
	)

	_generate_nest()


func get_respawn_position() -> Vector3:
	return spawn_point.global_position


func _generate_nest() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = _get_visual_seed()

	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_outer_ring(
		surface_tool,
		random
	)

	_add_inner_bedding(
		surface_tool,
		random
	)

	surface_tool.index()

	var generated_mesh: ArrayMesh = surface_tool.commit()

	if generated_mesh == null:
		push_error("Procedural nest mesh could not be generated.")
		return

	nest_mesh.mesh = generated_mesh

	_apply_material()


func _add_outer_ring(
	surface_tool: SurfaceTool,
	random: RandomNumberGenerator
) -> void:
	for ring_layer in range(ring_height_voxels):
		for voxel_index in range(ring_voxel_count):
			var angle := (
				TAU
				* float(voxel_index)
				/ float(ring_voxel_count)
			)

			var radius_variation := random.randf_range(
				-voxel_size * 0.35,
				voxel_size * 0.35
			)

			var layer_radius := (
				nest_radius
				- float(ring_layer)
					* voxel_size
					* 0.15
				+ radius_variation
			)

			var center := Vector3(
				cos(angle) * layer_radius,
				(
					float(ring_layer)
						+ 0.5
				) * voxel_size,
				sin(angle) * layer_radius
			)

			var twig_color := TWIG_COLOR

			if random.randf() < 0.35:
				twig_color = DARK_TWIG_COLOR

			twig_color = _vary_color(
				twig_color,
				random,
				0.12
			)

			var size_variation := random.randf_range(
				0.88,
				1.15
			)

			_add_box(
				surface_tool,
				center,
				Vector3(
					voxel_size * size_variation,
					voxel_size,
					voxel_size * size_variation
				),
				twig_color
			)


func _add_inner_bedding(
	surface_tool: SurfaceTool,
	random: RandomNumberGenerator
) -> void:
	var bedding_radius := (
		nest_radius
		- voxel_size * 1.25
	)

	var grid_radius := ceili(
		bedding_radius / voxel_size
	)

	for grid_x in range(
		-grid_radius,
		grid_radius + 1
	):
		for grid_z in range(
			-grid_radius,
			grid_radius + 1
		):
			var local_x := float(grid_x) * voxel_size
			var local_z := float(grid_z) * voxel_size

			var distance_from_center := Vector2(
				local_x,
				local_z
			).length()

			if distance_from_center > bedding_radius:
				continue

			var is_center := (
				distance_from_center
				< voxel_size * 0.75
			)

			if (
				not is_center
				and random.randf()
					< bedding_gap_probability
			):
				continue

			var bedding_color := BEDDING_COLOR

			if random.randf() < 0.45:
				bedding_color = DRY_GRASS_COLOR

			bedding_color = _vary_color(
				bedding_color,
				random,
				0.10
			)

			var height_variation := random.randf_range(
				0.0,
				voxel_size * 0.12
			)

			var center := Vector3(
				local_x,
				voxel_size * 0.18
					+ height_variation,
				local_z
			)

			_add_box(
				surface_tool,
				center,
				Vector3(
					voxel_size,
					voxel_size * 0.35,
					voxel_size
				),
				bedding_color
			)


func _add_box(
	surface_tool: SurfaceTool,
	center: Vector3,
	size: Vector3,
	color: Color
) -> void:
	var half_size := size * 0.5

	var left := center.x - half_size.x
	var right := center.x + half_size.x
	var bottom := center.y - half_size.y
	var top := center.y + half_size.y
	var front := center.z - half_size.z
	var back := center.z + half_size.z

	_add_face(
		surface_tool,
		Vector3(right, bottom, front),
		Vector3(right, top, front),
		Vector3(right, top, back),
		Vector3(right, bottom, back),
		Vector3.RIGHT,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, bottom, back),
		Vector3(left, top, back),
		Vector3(left, top, front),
		Vector3(left, bottom, front),
		Vector3.LEFT,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, top, front),
		Vector3(left, top, back),
		Vector3(right, top, back),
		Vector3(right, top, front),
		Vector3.UP,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, bottom, back),
		Vector3(left, bottom, front),
		Vector3(right, bottom, front),
		Vector3(right, bottom, back),
		Vector3.DOWN,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, bottom, front),
		Vector3(left, top, front),
		Vector3(right, top, front),
		Vector3(right, bottom, front),
		Vector3.FORWARD,
		color
	)

	_add_face(
		surface_tool,
		Vector3(right, bottom, back),
		Vector3(right, top, back),
		Vector3(left, top, back),
		Vector3(left, bottom, back),
		Vector3.BACK,
		color
	)


func _add_face(
	surface_tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	point_d: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	_add_mesh_vertex(
		surface_tool,
		point_a,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_b,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_c,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_a,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_c,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_d,
		normal,
		color
	)


func _add_mesh_vertex(
	surface_tool: SurfaceTool,
	vertex_position: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	surface_tool.set_normal(normal)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_position)


func _apply_material() -> void:
	var material := StandardMaterial3D.new()

	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0

	nest_mesh.material_override = material


func _snap_to_terrain() -> void:
	var terrain_height := WorldGenerator.get_terrain_height(
		global_position.x,
		global_position.z
	)

	global_position.y = terrain_height + 0.02


func _vary_color(
	base_color: Color,
	random: RandomNumberGenerator,
	variation: float
) -> Color:
	var value := random.randf_range(
		-variation,
		variation
	)

	if value >= 0.0:
		return base_color.lerp(
			Color.WHITE,
			value
		)

	return base_color.lerp(
		Color.BLACK,
		-value
	)


func _get_visual_seed() -> int:
	return (
		GameState.world_seed * 71
		+ int(
			round(
				global_position.x * 100.0
			)
		) * 73_856_093
		+ int(
			round(
				global_position.z * 100.0
			)
		) * 19_349_663
	)
