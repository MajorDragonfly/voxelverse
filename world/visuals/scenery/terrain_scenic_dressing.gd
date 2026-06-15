extends Node3D


const GRASS_SEED_OFFSET: int = 714_025_381
const ROCK_SEED_OFFSET: int = 932_167_447
const SPIRE_SEED_OFFSET: int = 481_597_231
const RUIN_SEED_OFFSET: int = 257_918_603


@export_category("Grass")

@export_range(0, 600, 1)
var grass_attempts_per_chunk: int = 190

@export_range(20.0, 400.0, 5.0)
var grass_visibility_distance: float = 145.0

@export_range(0.0, 2.0, 0.05)
var maximum_grass_slope: float = 0.45


@export_category("Rocks")

@export_range(0, 150, 1)
var rock_attempts_per_chunk: int = 38

@export_range(20.0, 600.0, 5.0)
var rock_visibility_distance: float = 220.0

@export_range(0, 20, 1)
var spire_attempts_per_chunk: int = 5

@export_range(20.0, 800.0, 5.0)
var spire_visibility_distance: float = 300.0


@export_category("Ruins")

@export_range(0.0, 1.0, 0.01)
var ruin_chunk_chance: float = 0.08

@export_range(20.0, 1000.0, 5.0)
var ruin_visibility_distance: float = 360.0

@export_range(0.0, 2.0, 0.05)
var maximum_ruin_slope: float = 0.24


@export_category("Placement")

@export_range(0.0, 50.0, 1.0)
var spawn_clear_radius: float = 14.0

@export_range(0.0, 10.0, 0.25)
var chunk_edge_margin: float = 1.5


func _ready() -> void:
	call_deferred(
		"_generate_scenic_dressing"
	)


func _generate_scenic_dressing() -> void:
	var chunk_node: Node3D = get_parent() as Node3D

	if chunk_node == null:
		return

	if not chunk_node.has_method(
		"get_chunk_width"
	):
		push_error(
			"Scenic dressing requires get_chunk_width()."
		)

		return

	if not chunk_node.has_method(
		"get_chunk_depth"
	):
		push_error(
			"Scenic dressing requires get_chunk_depth()."
		)

		return

	var chunk_width: float = float(
		chunk_node.call(
			"get_chunk_width"
		)
	)

	var chunk_depth: float = float(
		chunk_node.call(
			"get_chunk_depth"
		)
	)

	_generate_grass(
		chunk_node,
		chunk_width,
		chunk_depth
	)

	_generate_rocks(
		chunk_node,
		chunk_width,
		chunk_depth
	)

	_generate_spires(
		chunk_node,
		chunk_width,
		chunk_depth
	)

	_generate_ruin(
		chunk_node,
		chunk_width,
		chunk_depth
	)


func _generate_grass(
	chunk_node: Node3D,
	chunk_width: float,
	chunk_depth: float
) -> void:
	if grass_attempts_per_chunk <= 0:
		return

	var random: RandomNumberGenerator = _create_chunk_random(
		chunk_node,
		chunk_width,
		chunk_depth,
		GRASS_SEED_OFFSET
	)

	var instance_transforms: Array[Transform3D] = []
	var instance_colors: Array[Color] = []

	var half_width: float = chunk_width * 0.5
	var half_depth: float = chunk_depth * 0.5

	for _attempt_index in range(
		grass_attempts_per_chunk
	):
		var local_x: float = random.randf_range(
			-half_width + chunk_edge_margin,
			half_width - chunk_edge_margin
		)

		var local_z: float = random.randf_range(
			-half_depth + chunk_edge_margin,
			half_depth - chunk_edge_margin
		)

		var world_x: float = (
			chunk_node.global_position.x
			+ local_x
		)

		var world_z: float = (
			chunk_node.global_position.z
			+ local_z
		)

		if Vector2(
			world_x,
			world_z
		).length() < spawn_clear_radius:
			continue

		var terrain_height: float = (
			WorldGenerator.get_terrain_height(
				world_x,
				world_z
			)
		)

		if (
			terrain_height
			<= WorldGenerator.get_sea_level()
			+ 0.25
		):
			continue

		var biome: int = WorldGenerator.get_biome(
			world_x,
			world_z,
			terrain_height
		)

		if (
			random.randf()
			> _get_grass_probability(
				biome
			)
		):
			continue

		var terrain_slope: float = (
			WorldGenerator.get_terrain_slope(
				world_x,
				world_z,
				0.8
			)
		)

		if terrain_slope > maximum_grass_slope:
			continue

		var angle: float = random.randf_range(
			0.0,
			TAU
		)

		var width_scale: float = random.randf_range(
			0.70,
			1.40
		)

		var height_scale: float = random.randf_range(
			0.65,
			1.45
		)

		var instance_basis: Basis = Basis(
			Vector3.UP,
			angle
		)

		instance_basis = instance_basis.scaled(
			Vector3(
				width_scale,
				height_scale,
				width_scale
			)
		)

		instance_transforms.append(
			Transform3D(
				instance_basis,
				Vector3(
					local_x,
					terrain_height + 0.02,
					local_z
				)
			)
		)

		instance_colors.append(
			_get_grass_color(
				biome,
				random
			)
		)

	if instance_transforms.is_empty():
		return

	var grass_multi_mesh: MultiMesh = MultiMesh.new()

	grass_multi_mesh.transform_format = (
		MultiMesh.TRANSFORM_3D
	)

	grass_multi_mesh.use_colors = true
	grass_multi_mesh.mesh = _create_grass_mesh()
	grass_multi_mesh.instance_count = (
		instance_transforms.size()
	)

	for instance_index in range(
		instance_transforms.size()
	):
		grass_multi_mesh.set_instance_transform(
			instance_index,
			instance_transforms[
				instance_index
			]
		)

		grass_multi_mesh.set_instance_color(
			instance_index,
			instance_colors[
				instance_index
			]
		)

	var grass_instance: MultiMeshInstance3D = (
		MultiMeshInstance3D.new()
	)

	grass_instance.name = "GrassTufts"
	grass_instance.multimesh = grass_multi_mesh

	grass_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)

	grass_instance.visibility_range_end = maxf(
		grass_visibility_distance,
		1.0
	)

	add_child(
		grass_instance
	)


func _generate_rocks(
	chunk_node: Node3D,
	chunk_width: float,
	chunk_depth: float
) -> void:
	if rock_attempts_per_chunk <= 0:
		return

	var random: RandomNumberGenerator = _create_chunk_random(
		chunk_node,
		chunk_width,
		chunk_depth,
		ROCK_SEED_OFFSET
	)

	var instance_transforms: Array[Transform3D] = []
	var instance_colors: Array[Color] = []

	var half_width: float = chunk_width * 0.5
	var half_depth: float = chunk_depth * 0.5

	for _attempt_index in range(
		rock_attempts_per_chunk
	):
		var local_x: float = random.randf_range(
			-half_width + chunk_edge_margin,
			half_width - chunk_edge_margin
		)

		var local_z: float = random.randf_range(
			-half_depth + chunk_edge_margin,
			half_depth - chunk_edge_margin
		)

		var world_x: float = (
			chunk_node.global_position.x
			+ local_x
		)

		var world_z: float = (
			chunk_node.global_position.z
			+ local_z
		)

		if Vector2(
			world_x,
			world_z
		).length() < spawn_clear_radius:
			continue

		var terrain_height: float = (
			WorldGenerator.get_terrain_height(
				world_x,
				world_z
			)
		)

		if (
			terrain_height
			<= WorldGenerator.get_sea_level()
			+ 0.05
		):
			continue

		var biome: int = WorldGenerator.get_biome(
			world_x,
			world_z,
			terrain_height
		)

		if (
			random.randf()
			> _get_rock_probability(
				biome
			)
		):
			continue

		var horizontal_scale: float = random.randf_range(
			0.55,
			1.90
		)

		var vertical_scale: float = random.randf_range(
			0.40,
			1.25
		)

		var instance_basis: Basis = Basis(
			Vector3.UP,
			random.randf_range(
				0.0,
				TAU
			)
		)

		instance_basis = instance_basis.scaled(
			Vector3(
				horizontal_scale,
				vertical_scale,
				random.randf_range(
					0.60,
					1.55
				)
			)
		)

		instance_transforms.append(
			Transform3D(
				instance_basis,
				Vector3(
					local_x,
					terrain_height + 0.25,
					local_z
				)
			)
		)

		instance_colors.append(
			_get_rock_color(
				biome,
				random
			)
		)

	if instance_transforms.is_empty():
		return

	var rock_multi_mesh: MultiMesh = MultiMesh.new()

	rock_multi_mesh.transform_format = (
		MultiMesh.TRANSFORM_3D
	)

	rock_multi_mesh.use_colors = true
	rock_multi_mesh.mesh = _create_rock_mesh()
	rock_multi_mesh.instance_count = (
		instance_transforms.size()
	)

	for instance_index in range(
		instance_transforms.size()
	):
		rock_multi_mesh.set_instance_transform(
			instance_index,
			instance_transforms[
				instance_index
			]
		)

		rock_multi_mesh.set_instance_color(
			instance_index,
			instance_colors[
				instance_index
			]
		)

	var rock_instance: MultiMeshInstance3D = (
		MultiMeshInstance3D.new()
	)

	rock_instance.name = "ScatteredRocks"
	rock_instance.multimesh = rock_multi_mesh

	rock_instance.visibility_range_end = maxf(
		rock_visibility_distance,
		1.0
	)

	add_child(
		rock_instance
	)


func _generate_spires(
	chunk_node: Node3D,
	chunk_width: float,
	chunk_depth: float
) -> void:
	if spire_attempts_per_chunk <= 0:
		return

	var random: RandomNumberGenerator = _create_chunk_random(
		chunk_node,
		chunk_width,
		chunk_depth,
		SPIRE_SEED_OFFSET
	)

	var instance_transforms: Array[Transform3D] = []
	var instance_colors: Array[Color] = []

	var half_width: float = chunk_width * 0.5
	var half_depth: float = chunk_depth * 0.5

	for _attempt_index in range(
		spire_attempts_per_chunk
	):
		var local_x: float = random.randf_range(
			-half_width + 4.0,
			half_width - 4.0
		)

		var local_z: float = random.randf_range(
			-half_depth + 4.0,
			half_depth - 4.0
		)

		var world_x: float = (
			chunk_node.global_position.x
			+ local_x
		)

		var world_z: float = (
			chunk_node.global_position.z
			+ local_z
		)

		var terrain_height: float = (
			WorldGenerator.get_terrain_height(
				world_x,
				world_z
			)
		)

		var biome: int = WorldGenerator.get_biome(
			world_x,
			world_z,
			terrain_height
		)

		if (
			random.randf()
			> _get_spire_probability(
				biome
			)
		):
			continue

		var horizontal_scale: float = random.randf_range(
			0.75,
			1.55
		)

		var vertical_scale: float = random.randf_range(
			0.85,
			2.10
		)

		var instance_basis: Basis = Basis(
			Vector3.UP,
			random.randf_range(
				0.0,
				TAU
			)
		)

		instance_basis = instance_basis.scaled(
			Vector3(
				horizontal_scale,
				vertical_scale,
				horizontal_scale
			)
		)

		var base_mesh_height: float = 3.4

		instance_transforms.append(
			Transform3D(
				instance_basis,
				Vector3(
					local_x,
					terrain_height
						+ base_mesh_height
						* vertical_scale
						* 0.5,
					local_z
				)
			)
		)

		instance_colors.append(
			_get_rock_color(
				biome,
				random
			)
		)

	if instance_transforms.is_empty():
		return

	var spire_multi_mesh: MultiMesh = MultiMesh.new()

	spire_multi_mesh.transform_format = (
		MultiMesh.TRANSFORM_3D
	)

	spire_multi_mesh.use_colors = true
	spire_multi_mesh.mesh = _create_spire_mesh()
	spire_multi_mesh.instance_count = (
		instance_transforms.size()
	)

	for instance_index in range(
		instance_transforms.size()
	):
		spire_multi_mesh.set_instance_transform(
			instance_index,
			instance_transforms[
				instance_index
			]
		)

		spire_multi_mesh.set_instance_color(
			instance_index,
			instance_colors[
				instance_index
			]
		)

	var spire_instance: MultiMeshInstance3D = (
		MultiMeshInstance3D.new()
	)

	spire_instance.name = "RockSpires"
	spire_instance.multimesh = spire_multi_mesh

	spire_instance.visibility_range_end = maxf(
		spire_visibility_distance,
		1.0
	)

	add_child(
		spire_instance
	)


func _generate_ruin(
	chunk_node: Node3D,
	chunk_width: float,
	chunk_depth: float
) -> void:
	if ruin_chunk_chance <= 0.0:
		return

	var random: RandomNumberGenerator = _create_chunk_random(
		chunk_node,
		chunk_width,
		chunk_depth,
		RUIN_SEED_OFFSET
	)

	if random.randf() > ruin_chunk_chance:
		return

	var half_width: float = chunk_width * 0.5
	var half_depth: float = chunk_depth * 0.5

	for _attempt_index in range(12):
		var local_x: float = random.randf_range(
			-half_width + 8.0,
			half_width - 8.0
		)

		var local_z: float = random.randf_range(
			-half_depth + 8.0,
			half_depth - 8.0
		)

		var world_x: float = (
			chunk_node.global_position.x
			+ local_x
		)

		var world_z: float = (
			chunk_node.global_position.z
			+ local_z
		)

		if Vector2(
			world_x,
			world_z
		).length() < spawn_clear_radius * 1.5:
			continue

		var terrain_height: float = (
			WorldGenerator.get_terrain_height(
				world_x,
				world_z
			)
		)

		if (
			terrain_height
			<= WorldGenerator.get_sea_level()
			+ 1.0
		):
			continue

		var biome: int = WorldGenerator.get_biome(
			world_x,
			world_z,
			terrain_height
		)

		if not _biome_allows_ruins(
			biome
		):
			continue

		var terrain_slope: float = (
			WorldGenerator.get_terrain_slope(
				world_x,
				world_z,
				1.5
			)
		)

		if terrain_slope > maximum_ruin_slope:
			continue

		var ruin_mesh: ArrayMesh = _create_ruin_mesh(
			random
		)

		var ruin_instance: MeshInstance3D = (
			MeshInstance3D.new()
		)

		ruin_instance.name = "AncientRuin"
		ruin_instance.mesh = ruin_mesh

		ruin_instance.position = Vector3(
			local_x,
			terrain_height + 0.02,
			local_z
		)

		ruin_instance.rotation.y = random.randf_range(
			0.0,
			TAU
		)

		ruin_instance.visibility_range_end = maxf(
			ruin_visibility_distance,
			1.0
		)

		add_child(
			ruin_instance
		)

		return


func _create_chunk_random(
	chunk_node: Node3D,
	chunk_width: float,
	chunk_depth: float,
	seed_offset: int
) -> RandomNumberGenerator:
	var chunk_x: int = roundi(
		chunk_node.global_position.x
		/ maxf(
			chunk_width,
			0.001
		)
	)

	var chunk_z: int = roundi(
		chunk_node.global_position.z
		/ maxf(
			chunk_depth,
			0.001
		)
	)

	var random: RandomNumberGenerator = (
		RandomNumberGenerator.new()
	)

	random.seed = (
		GameState.world_seed
		+ chunk_x * 73_856_093
		+ chunk_z * 19_349_663
		+ seed_offset
	)

	return random


func _get_grass_probability(
	biome: int
) -> float:
	match biome:
		WorldGenerator.Biome.GRASSLAND:
			return 0.82

		WorldGenerator.Biome.WETLAND:
			return 0.96

		WorldGenerator.Biome.COLD_GRASSLAND:
			return 0.58

		WorldGenerator.Biome.STEPPE:
			return 0.34

		WorldGenerator.Biome.COAST:
			return 0.08

		WorldGenerator.Biome.ROCKY_HIGHLANDS:
			return 0.04

		_:
			return 0.0


func _get_rock_probability(
	biome: int
) -> float:
	match biome:
		WorldGenerator.Biome.ROCKY_HIGHLANDS:
			return 0.92

		WorldGenerator.Biome.STEPPE:
			return 0.54

		WorldGenerator.Biome.COAST:
			return 0.35

		WorldGenerator.Biome.COLD_GRASSLAND:
			return 0.42

		WorldGenerator.Biome.GRASSLAND:
			return 0.18

		WorldGenerator.Biome.WETLAND:
			return 0.08

		_:
			return 0.0


func _get_spire_probability(
	biome: int
) -> float:
	match biome:
		WorldGenerator.Biome.ROCKY_HIGHLANDS:
			return 0.38

		WorldGenerator.Biome.STEPPE:
			return 0.16

		_:
			return 0.0


func _biome_allows_ruins(
	biome: int
) -> bool:
	return (
		biome == WorldGenerator.Biome.GRASSLAND
		or biome == WorldGenerator.Biome.STEPPE
		or biome == WorldGenerator.Biome.COLD_GRASSLAND
		or biome == WorldGenerator.Biome.ROCKY_HIGHLANDS
	)


func _get_grass_color(
	biome: int,
	random: RandomNumberGenerator
) -> Color:
	var base_color: Color

	match biome:
		WorldGenerator.Biome.WETLAND:
			base_color = Color(
				0.08,
				0.36,
				0.11,
				1.0
			)

		WorldGenerator.Biome.STEPPE:
			base_color = Color(
				0.53,
				0.46,
				0.19,
				1.0
			)

		WorldGenerator.Biome.COLD_GRASSLAND:
			base_color = Color(
				0.31,
				0.45,
				0.34,
				1.0
			)

		_:
			base_color = Color(
				0.20,
				0.48,
				0.12,
				1.0
			)

	return _vary_color(
		base_color,
		random,
		0.12
	)


func _get_rock_color(
	biome: int,
	random: RandomNumberGenerator
) -> Color:
	var base_color: Color

	if biome == WorldGenerator.Biome.ROCKY_HIGHLANDS:
		base_color = Color(
			0.39,
			0.31,
			0.27,
			1.0
		)
	else:
		base_color = Color(
			0.53,
			0.34,
			0.20,
			1.0
		)

	return _vary_color(
		base_color,
		random,
		0.10
	)


func _vary_color(
	base_color: Color,
	random: RandomNumberGenerator,
	variation: float
) -> Color:
	var variation_value: float = random.randf_range(
		-variation,
		variation
	)

	if variation_value >= 0.0:
		return base_color.lerp(
			Color.WHITE,
			variation_value
		)

	return base_color.lerp(
		Color.BLACK,
		-variation_value
	)


func _create_grass_mesh() -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()

	surface_tool.begin(
		Mesh.PRIMITIVE_TRIANGLES
	)

	var blade_width: float = 0.16
	var blade_height: float = 0.75

	for blade_index in range(3):
		var blade_angle: float = (
			float(blade_index)
			* PI
			/ 3.0
		)

		var blade_right: Vector3 = Vector3(
			cos(blade_angle),
			0.0,
			sin(blade_angle)
		) * blade_width

		var blade_forward: Vector3 = Vector3(
			-sin(blade_angle),
			0.0,
			cos(blade_angle)
		) * 0.04

		var bottom_left: Vector3 = (
			-blade_right
			- blade_forward
		)

		var bottom_right: Vector3 = (
			blade_right
			- blade_forward
		)

		var top_left: Vector3 = (
			-blade_right * 0.28
			+ Vector3.UP * blade_height
			+ blade_forward
		)

		var top_right: Vector3 = (
			blade_right * 0.28
			+ Vector3.UP * blade_height
			+ blade_forward
		)

		surface_tool.add_vertex(
			bottom_left
		)

		surface_tool.add_vertex(
			bottom_right
		)

		surface_tool.add_vertex(
			top_right
		)

		surface_tool.add_vertex(
			bottom_left
		)

		surface_tool.add_vertex(
			top_right
		)

		surface_tool.add_vertex(
			top_left
		)

	surface_tool.generate_normals()

	var generated_mesh: ArrayMesh = (
		surface_tool.commit()
	)

	var grass_material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	grass_material.albedo_color = Color.WHITE
	grass_material.vertex_color_use_as_albedo = true
	grass_material.roughness = 1.0

	grass_material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)

	generated_mesh.surface_set_material(
		0,
		grass_material
	)

	return generated_mesh


func _create_rock_mesh() -> SphereMesh:
	var rock_mesh: SphereMesh = SphereMesh.new()

	rock_mesh.radius = 0.65
	rock_mesh.height = 1.30
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 4

	var rock_material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	rock_material.albedo_color = Color.WHITE
	rock_material.vertex_color_use_as_albedo = true
	rock_material.roughness = 1.0

	rock_mesh.material = rock_material

	return rock_mesh


func _create_spire_mesh() -> CylinderMesh:
	var spire_mesh: CylinderMesh = CylinderMesh.new()

	spire_mesh.top_radius = 0.32
	spire_mesh.bottom_radius = 0.92
	spire_mesh.height = 3.4
	spire_mesh.radial_segments = 6
	spire_mesh.rings = 2

	var spire_material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	spire_material.albedo_color = Color.WHITE
	spire_material.vertex_color_use_as_albedo = true
	spire_material.roughness = 1.0

	spire_mesh.material = spire_material

	return spire_mesh


func _create_ruin_mesh(
	random: RandomNumberGenerator
) -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()

	surface_tool.begin(
		Mesh.PRIMITIVE_TRIANGLES
	)

	var stone_color: Color = Color(
		0.52,
		0.47,
		0.36,
		1.0
	)

	var dark_stone_color: Color = Color(
		0.36,
		0.34,
		0.29,
		1.0
	)

	_add_box(
		surface_tool,
		Vector3(
			-2.0,
			1.0,
			0.0
		),
		Vector3(
			2.4,
			2.0,
			0.55
		),
		_vary_color(
			stone_color,
			random,
			0.08
		)
	)

	_add_box(
		surface_tool,
		Vector3(
			1.8,
			0.70,
			0.0
		),
		Vector3(
			1.6,
			1.4,
			0.55
		),
		_vary_color(
			stone_color,
			random,
			0.08
		)
	)

	_add_box(
		surface_tool,
		Vector3(
			-3.1,
			1.55,
			1.9
		),
		Vector3(
			0.70,
			3.1,
			0.70
		),
		_vary_color(
			dark_stone_color,
			random,
			0.08
		)
	)

	_add_box(
		surface_tool,
		Vector3(
			2.8,
			1.10,
			1.9
		),
		Vector3(
			0.70,
			2.2,
			0.70
		),
		_vary_color(
			dark_stone_color,
			random,
			0.08
		)
	)

	_add_box(
		surface_tool,
		Vector3(
			-0.3,
			0.25,
			2.0
		),
		Vector3(
			4.2,
			0.45,
			0.75
		),
		_vary_color(
			stone_color,
			random,
			0.08
		)
	)

	_add_box(
		surface_tool,
		Vector3(
			0.2,
			0.20,
			-2.2
		),
		Vector3(
			3.0,
			0.40,
			0.65
		),
		_vary_color(
			dark_stone_color,
			random,
			0.08
		)
	)

	surface_tool.index()
	surface_tool.generate_normals()

	var generated_mesh: ArrayMesh = (
		surface_tool.commit()
	)

	var ruin_material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	ruin_material.albedo_color = Color.WHITE
	ruin_material.vertex_color_use_as_albedo = true
	ruin_material.roughness = 1.0

	generated_mesh.surface_set_material(
		0,
		ruin_material
	)

	return generated_mesh


func _add_box(
	surface_tool: SurfaceTool,
	box_center: Vector3,
	box_size: Vector3,
	box_color: Color
) -> void:
	var half_size: Vector3 = box_size * 0.5

	var left: float = box_center.x - half_size.x
	var right: float = box_center.x + half_size.x
	var bottom: float = box_center.y - half_size.y
	var top: float = box_center.y + half_size.y
	var front: float = box_center.z - half_size.z
	var back: float = box_center.z + half_size.z

	_add_face(
		surface_tool,
		Vector3(
			right,
			bottom,
			front
		),
		Vector3(
			right,
			top,
			front
		),
		Vector3(
			right,
			top,
			back
		),
		Vector3(
			right,
			bottom,
			back
		),
		box_color
	)

	_add_face(
		surface_tool,
		Vector3(
			left,
			bottom,
			back
		),
		Vector3(
			left,
			top,
			back
		),
		Vector3(
			left,
			top,
			front
		),
		Vector3(
			left,
			bottom,
			front
		),
		box_color
	)

	_add_face(
		surface_tool,
		Vector3(
			left,
			top,
			front
		),
		Vector3(
			left,
			top,
			back
		),
		Vector3(
			right,
			top,
			back
		),
		Vector3(
			right,
			top,
			front
		),
		box_color
	)

	_add_face(
		surface_tool,
		Vector3(
			left,
			bottom,
			back
		),
		Vector3(
			left,
			bottom,
			front
		),
		Vector3(
			right,
			bottom,
			front
		),
		Vector3(
			right,
			bottom,
			back
		),
		box_color
	)

	_add_face(
		surface_tool,
		Vector3(
			left,
			bottom,
			front
		),
		Vector3(
			left,
			top,
			front
		),
		Vector3(
			right,
			top,
			front
		),
		Vector3(
			right,
			bottom,
			front
		),
		box_color
	)

	_add_face(
		surface_tool,
		Vector3(
			right,
			bottom,
			back
		),
		Vector3(
			right,
			top,
			back
		),
		Vector3(
			left,
			top,
			back
		),
		Vector3(
			left,
			bottom,
			back
		),
		box_color
	)


func _add_face(
	surface_tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	point_d: Vector3,
	face_color: Color
) -> void:
	surface_tool.set_color(
		face_color
	)

	surface_tool.add_vertex(
		point_a
	)

	surface_tool.set_color(
		face_color
	)

	surface_tool.add_vertex(
		point_b
	)

	surface_tool.set_color(
		face_color
	)

	surface_tool.add_vertex(
		point_c
	)

	surface_tool.set_color(
		face_color
	)

	surface_tool.add_vertex(
		point_a
	)

	surface_tool.set_color(
		face_color
	)

	surface_tool.add_vertex(
		point_c
	)

	surface_tool.set_color(
		face_color
	)

	surface_tool.add_vertex(
		point_d
	)
