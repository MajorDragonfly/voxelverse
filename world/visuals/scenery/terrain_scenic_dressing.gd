extends Node3D


const VOXEL_SURFACE_MATERIAL: ShaderMaterial = preload(
	"res://world/visuals/voxel/voxel_surface_material.tres"
)

const GRASS_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/grass_01.png"
)

const STONE_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/stone_01.png"
)

const RUIN_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/ruin_stone_01.png"
)


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


@export_category("Pixel Materials")

@export_range(2, 8, 1)
var palette_steps: int = 4

@export_range(0.25, 8.0, 0.25)
var grass_texture_scale: float = 2.0

@export_range(0.25, 8.0, 0.25)
var stone_texture_scale: float = 0.85

@export_range(0.25, 8.0, 0.25)
var spire_texture_scale: float = 0.70

@export_range(0.25, 8.0, 0.25)
var ruin_texture_scale: float = 0.90

@export_range(0.20, 1.00, 0.01)
var grass_texture_darkness: float = 0.62

@export_range(0.80, 1.50, 0.01)
var grass_texture_brightness: float = 1.18

@export_range(0.20, 1.00, 0.01)
var stone_texture_darkness: float = 0.48

@export_range(0.80, 1.50, 0.01)
var stone_texture_brightness: float = 1.28

@export_range(0.20, 1.00, 0.01)
var ruin_texture_darkness: float = 0.52

@export_range(0.80, 1.50, 0.01)
var ruin_texture_brightness: float = 1.24


var _grass_material: ShaderMaterial = null
var _stone_material: ShaderMaterial = null
var _spire_material: ShaderMaterial = null
var _ruin_material: ShaderMaterial = null


func _ready() -> void:
	_initialize_pixel_materials()

	call_deferred(
		"_generate_scenic_dressing"
	)


func _initialize_pixel_materials() -> void:
	_grass_material = _create_pixel_voxel_material(
		GRASS_TEXTURE,
		grass_texture_scale,
		grass_texture_darkness,
		grass_texture_brightness
	)

	_stone_material = _create_pixel_voxel_material(
		STONE_TEXTURE,
		stone_texture_scale,
		stone_texture_darkness,
		stone_texture_brightness
	)

	_spire_material = _create_pixel_voxel_material(
		STONE_TEXTURE,
		spire_texture_scale,
		stone_texture_darkness,
		stone_texture_brightness
	)

	_ruin_material = _create_pixel_voxel_material(
		RUIN_TEXTURE,
		ruin_texture_scale,
		ruin_texture_darkness,
		ruin_texture_brightness
	)


func _create_pixel_voxel_material(
	texture: Texture2D,
	texture_scale_value: float,
	texture_darkness_value: float,
	texture_brightness_value: float
) -> ShaderMaterial:
	var material := (
		VOXEL_SURFACE_MATERIAL.duplicate()
		as ShaderMaterial
	)

	if material == null:
		push_error(
			"Scenic pixel material could not be duplicated."
		)
		return null

	material.set_shader_parameter(
		&"object_tint",
		Color.WHITE
	)

	material.set_shader_parameter(
		&"use_pixel_texture",
		texture != null
	)

	if texture != null:
		material.set_shader_parameter(
			&"pixel_texture",
			texture
		)

	material.set_shader_parameter(
		&"texture_scale",
		maxf(
			texture_scale_value,
			0.25
		)
	)

	material.set_shader_parameter(
		&"palette_steps",
		float(
			clampi(
				palette_steps,
				2,
				8
			)
		)
	)

	material.set_shader_parameter(
		&"texture_darkness",
		clampf(
			texture_darkness_value,
			0.20,
			1.00
		)
	)

	material.set_shader_parameter(
		&"texture_brightness",
		clampf(
			texture_brightness_value,
			0.80,
			1.50
		)
	)

	return material


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

	if not chunk_node.has_method(
		"get_surface_height_at_local_position"
	):
		push_error(
			"Scenic dressing requires get_surface_height_at_local_position()."
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
	var density_multiplier: float = (
		WorldGenerator.get_grass_density_multiplier()
	)

	var effective_attempts: int = maxi(
		0,
		roundi(
			float(grass_attempts_per_chunk)
			* density_multiplier
		)
	)

	if effective_attempts <= 0:
		return

	var random: RandomNumberGenerator = (
		_create_chunk_random(
			chunk_node,
			chunk_width,
			chunk_depth,
			GRASS_SEED_OFFSET
		)
	)

	var instance_transforms: Array[Transform3D] = []
	var instance_colors: Array[Color] = []

	var half_width: float = chunk_width * 0.5
	var half_depth: float = chunk_depth * 0.5

	for _attempt_index in range(
		effective_attempts
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

		var logical_height: float = (
			WorldGenerator.get_terrain_height(
				world_x,
				world_z
			)
		)

		if (
			logical_height
			<= WorldGenerator.get_sea_level()
			+ 0.25
		):
			continue

		var surface_height: float = float(
			chunk_node.call(
				"get_surface_height_at_local_position",
				local_x,
				local_z
			)
		)

		var biome: int = (
			WorldGenerator.get_biome(
				world_x,
				world_z,
				logical_height
			)
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

		if (
			terrain_slope
			> maximum_grass_slope
		):
			continue

		var angle: float = random.randf_range(
			0.0,
			TAU
		)

		var width_scale: float = (
			random.randf_range(
				0.70,
				1.40
			)
		)

		var height_scale: float = (
			random.randf_range(
				0.65,
				1.45
			)
		)

		var instance_basis: Basis = Basis(
			Vector3.UP,
			angle
		)

		instance_basis = (
			instance_basis.scaled(
				Vector3(
					width_scale,
					height_scale,
					width_scale
				)
			)
		)

		instance_transforms.append(
			Transform3D(
				instance_basis,
				Vector3(
					local_x,
					surface_height + 0.02,
					local_z
				)
			)
		)

		instance_colors.append(
			_get_grass_color(
				biome,
				world_x,
				world_z,
				logical_height,
				random
			)
		)

	if instance_transforms.is_empty():
		return

	var grass_multi_mesh := MultiMesh.new()

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

	var grass_instance := MultiMeshInstance3D.new()

	grass_instance.name = "GrassTufts"
	grass_instance.multimesh = grass_multi_mesh

	grass_instance.cast_shadow = (
		GeometryInstance3D
		.SHADOW_CASTING_SETTING_OFF
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
	var density_multiplier: float = (
		WorldGenerator.get_rock_density_multiplier()
	)

	var effective_attempts: int = maxi(
		0,
		roundi(
			float(rock_attempts_per_chunk)
			* density_multiplier
		)
	)

	if effective_attempts <= 0:
		return

	var random: RandomNumberGenerator = (
		_create_chunk_random(
			chunk_node,
			chunk_width,
			chunk_depth,
			ROCK_SEED_OFFSET
		)
	)

	var instance_transforms: Array[Transform3D] = []
	var instance_colors: Array[Color] = []

	var half_width: float = chunk_width * 0.5
	var half_depth: float = chunk_depth * 0.5

	for _attempt_index in range(
		effective_attempts
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

		var logical_height: float = (
			WorldGenerator.get_terrain_height(
				world_x,
				world_z
			)
		)

		if (
			logical_height
			<= WorldGenerator.get_sea_level()
			+ 0.05
		):
			continue

		var surface_height: float = float(
			chunk_node.call(
				"get_surface_height_at_local_position",
				local_x,
				local_z
			)
		)

		var biome: int = (
			WorldGenerator.get_biome(
				world_x,
				world_z,
				logical_height
			)
		)

		if (
			random.randf()
			> _get_rock_probability(
				biome
			)
		):
			continue

		var horizontal_scale: float = (
			random.randf_range(
				0.55,
				1.90
			)
		)

		var vertical_scale: float = (
			random.randf_range(
				0.40,
				1.25
			)
		)

		var depth_scale: float = (
			random.randf_range(
				0.60,
				1.55
			)
		)

		var instance_basis: Basis = Basis(
			Vector3.UP,
			random.randf_range(
				0.0,
				TAU
			)
		)

		instance_basis = (
			instance_basis.scaled(
				Vector3(
					horizontal_scale,
					vertical_scale,
					depth_scale
				)
			)
		)

		instance_transforms.append(
			Transform3D(
				instance_basis,
				Vector3(
					local_x,
					surface_height + 0.02,
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

	var rock_multi_mesh := MultiMesh.new()

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

	var rock_instance := MultiMeshInstance3D.new()

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
	var density_multiplier: float = (
		WorldGenerator.get_rock_density_multiplier()
	)

	var cliff_multiplier: float = clampf(
		WorldGenerator.get_cliff_strength(),
		0.50,
		1.60
	)

	var effective_attempts: int = maxi(
		0,
		roundi(
			float(spire_attempts_per_chunk)
			* density_multiplier
			* cliff_multiplier
		)
	)

	if effective_attempts <= 0:
		return

	var random: RandomNumberGenerator = (
		_create_chunk_random(
			chunk_node,
			chunk_width,
			chunk_depth,
			SPIRE_SEED_OFFSET
		)
	)

	var instance_transforms: Array[Transform3D] = []
	var instance_colors: Array[Color] = []

	var half_width: float = chunk_width * 0.5
	var half_depth: float = chunk_depth * 0.5

	for _attempt_index in range(
		effective_attempts
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

		if Vector2(
			world_x,
			world_z
		).length() < spawn_clear_radius:
			continue

		var logical_height: float = (
			WorldGenerator.get_terrain_height(
				world_x,
				world_z
			)
		)

		if (
			logical_height
			<= WorldGenerator.get_sea_level()
			+ 0.30
		):
			continue

		var surface_height: float = float(
			chunk_node.call(
				"get_surface_height_at_local_position",
				local_x,
				local_z
			)
		)

		var biome: int = (
			WorldGenerator.get_biome(
				world_x,
				world_z,
				logical_height
			)
		)

		if (
			random.randf()
			> _get_spire_probability(
				biome
			)
		):
			continue

		var horizontal_scale: float = (
			random.randf_range(
				0.75,
				1.55
			)
		)

		var vertical_scale: float = (
			random.randf_range(
				0.85,
				2.10
			)
		)

		var instance_basis: Basis = Basis(
			Vector3.UP,
			random.randf_range(
				0.0,
				TAU
			)
		)

		instance_basis = (
			instance_basis.scaled(
				Vector3(
					horizontal_scale,
					vertical_scale,
					horizontal_scale
				)
			)
		)

		instance_transforms.append(
			Transform3D(
				instance_basis,
				Vector3(
					local_x,
					surface_height + 0.02,
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

	var spire_multi_mesh := MultiMesh.new()

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

	var spire_instance := MultiMeshInstance3D.new()

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
	var density_multiplier: float = (
		WorldGenerator.get_ruin_density_multiplier()
	)

	var effective_chunk_chance: float = clampf(
		ruin_chunk_chance
		* density_multiplier,
		0.0,
		1.0
	)

	if effective_chunk_chance <= 0.0:
		return

	var random: RandomNumberGenerator = (
		_create_chunk_random(
			chunk_node,
			chunk_width,
			chunk_depth,
			RUIN_SEED_OFFSET
		)
	)

	if (
		random.randf()
		> effective_chunk_chance
	):
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

		if (
			Vector2(
				world_x,
				world_z
			).length()
			< spawn_clear_radius * 1.5
		):
			continue

		var logical_height: float = (
			WorldGenerator.get_terrain_height(
				world_x,
				world_z
			)
		)

		if (
			logical_height
			<= WorldGenerator.get_sea_level()
			+ 1.0
		):
			continue

		var surface_height: float = float(
			chunk_node.call(
				"get_surface_height_at_local_position",
				local_x,
				local_z
			)
		)

		var biome: int = (
			WorldGenerator.get_biome(
				world_x,
				world_z,
				logical_height
			)
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

		if (
			terrain_slope
			> maximum_ruin_slope
		):
			continue

		var ruin_mesh: ArrayMesh = (
			_create_ruin_mesh(
				random
			)
		)

		var ruin_instance := MeshInstance3D.new()

		ruin_instance.name = "AncientRuin"
		ruin_instance.mesh = ruin_mesh

		ruin_instance.position = Vector3(
			local_x,
			surface_height + 0.02,
			local_z
		)

		ruin_instance.rotation.y = (
			random.randf_range(
				0.0,
				TAU
			)
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

	var random := RandomNumberGenerator.new()

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
		biome
		== WorldGenerator.Biome.GRASSLAND
		or biome
		== WorldGenerator.Biome.STEPPE
		or biome
		== WorldGenerator.Biome.COLD_GRASSLAND
		or biome
		== WorldGenerator.Biome.ROCKY_HIGHLANDS
	)


func _get_grass_color(
	biome: int,
	world_x: float,
	world_z: float,
	terrain_height: float,
	random: RandomNumberGenerator
) -> Color:
	var base_color: Color = (
		WorldGenerator.get_biome_color(
			world_x,
			world_z,
			terrain_height
		)
	)

	match biome:
		WorldGenerator.Biome.WETLAND:
			base_color = base_color.lerp(
				Color(
					0.08,
					0.30,
					0.10,
					1.0
				),
				0.35
			)

		WorldGenerator.Biome.STEPPE:
			base_color = base_color.lerp(
				Color(
					0.55,
					0.44,
					0.18,
					1.0
				),
				0.30
			)

		WorldGenerator.Biome.COLD_GRASSLAND:
			base_color = base_color.lerp(
				Color(
					0.38,
					0.48,
					0.39,
					1.0
				),
				0.30
			)

	return _vary_color(
		base_color,
		random,
		0.10
	)


func _get_rock_color(
	biome: int,
	random: RandomNumberGenerator
) -> Color:
	var base_color: Color = (
		WorldGenerator.get_world_rock_color()
	)

	if (
		biome
		== WorldGenerator.Biome.ROCKY_HIGHLANDS
	):
		base_color = base_color.lerp(
			Color(
				0.28,
				0.27,
				0.26,
				1.0
			),
			0.18
		)

	elif (
		biome
		== WorldGenerator.Biome.STEPPE
	):
		base_color = base_color.lerp(
			Color(
				0.48,
				0.31,
				0.21,
				1.0
			),
			0.15
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
	var variation_value: float = (
		random.randf_range(
			-variation,
			variation
		)
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
	var surface_tool := SurfaceTool.new()

	surface_tool.begin(
		Mesh.PRIMITIVE_TRIANGLES
	)

	_add_box(
		surface_tool,
		Vector3(
			-0.20,
			0.30,
			0.00
		),
		Vector3(
			0.18,
			0.60,
			0.18
		),
		Color.WHITE
	)

	_add_box(
		surface_tool,
		Vector3(
			0.02,
			0.40,
			0.08
		),
		Vector3(
			0.20,
			0.80,
			0.20
		),
		Color.WHITE
	)

	_add_box(
		surface_tool,
		Vector3(
			0.23,
			0.27,
			-0.05
		),
		Vector3(
			0.16,
			0.54,
			0.16
		),
		Color.WHITE
	)

	surface_tool.generate_normals()

	var generated_mesh: ArrayMesh = (
		surface_tool.commit()
	)

	if generated_mesh == null:
		push_error(
			"Grass mesh could not be generated."
		)
		return null

	if _grass_material != null:
		generated_mesh.surface_set_material(
			0,
			_grass_material
		)

	return generated_mesh


func _create_rock_mesh() -> ArrayMesh:
	var surface_tool := SurfaceTool.new()

	surface_tool.begin(
		Mesh.PRIMITIVE_TRIANGLES
	)

	_add_box(
		surface_tool,
		Vector3(
			0.00,
			0.28,
			0.00
		),
		Vector3(
			1.20,
			0.56,
			0.95
		),
		Color.WHITE
	)

	_add_box(
		surface_tool,
		Vector3(
			-0.18,
			0.64,
			0.05
		),
		Vector3(
			0.75,
			0.42,
			0.68
		),
		Color.WHITE
	)

	_add_box(
		surface_tool,
		Vector3(
			0.28,
			0.46,
			-0.18
		),
		Vector3(
			0.58,
			0.46,
			0.50
		),
		Color.WHITE
	)

	surface_tool.generate_normals()

	var generated_mesh: ArrayMesh = (
		surface_tool.commit()
	)

	if generated_mesh == null:
		push_error(
			"Rock mesh could not be generated."
		)
		return null

	if _stone_material != null:
		generated_mesh.surface_set_material(
			0,
			_stone_material
		)

	return generated_mesh


func _create_spire_mesh() -> ArrayMesh:
	var surface_tool := SurfaceTool.new()

	surface_tool.begin(
		Mesh.PRIMITIVE_TRIANGLES
	)

	_add_box(
		surface_tool,
		Vector3(
			0.00,
			0.45,
			0.00
		),
		Vector3(
			1.45,
			0.90,
			1.30
		),
		Color.WHITE
	)

	_add_box(
		surface_tool,
		Vector3(
			-0.08,
			1.25,
			0.04
		),
		Vector3(
			1.10,
			0.85,
			1.00
		),
		Color.WHITE
	)

	_add_box(
		surface_tool,
		Vector3(
			0.06,
			2.02,
			-0.04
		),
		Vector3(
			0.82,
			0.78,
			0.74
		),
		Color.WHITE
	)

	_add_box(
		surface_tool,
		Vector3(
			-0.03,
			2.70,
			0.03
		),
		Vector3(
			0.54,
			0.68,
			0.50
		),
		Color.WHITE
	)

	_add_box(
		surface_tool,
		Vector3(
			0.02,
			3.18,
			-0.02
		),
		Vector3(
			0.32,
			0.34,
			0.30
		),
		Color.WHITE
	)

	surface_tool.generate_normals()

	var generated_mesh: ArrayMesh = (
		surface_tool.commit()
	)

	if generated_mesh == null:
		push_error(
			"Rock spire mesh could not be generated."
		)
		return null

	if _spire_material != null:
		generated_mesh.surface_set_material(
			0,
			_spire_material
		)

	return generated_mesh


func _create_ruin_mesh(
	random: RandomNumberGenerator
) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()

	surface_tool.begin(
		Mesh.PRIMITIVE_TRIANGLES
	)

	var profile_rock_color: Color = (
		WorldGenerator.get_world_rock_color()
	)

	var stone_color: Color = (
		profile_rock_color.lerp(
			Color(
				0.58,
				0.51,
				0.38,
				1.0
			),
			0.42
		)
	)

	var dark_stone_color: Color = (
		profile_rock_color.lerp(
			Color(
				0.25,
				0.24,
				0.21,
				1.0
			),
			0.30
		)
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

	surface_tool.generate_normals()

	var generated_mesh: ArrayMesh = (
		surface_tool.commit()
	)

	if generated_mesh == null:
		push_error(
			"Ruin mesh could not be generated."
		)
		return null

	if _ruin_material != null:
		generated_mesh.surface_set_material(
			0,
			_ruin_material
		)

	return generated_mesh


func _add_box(
	surface_tool: SurfaceTool,
	box_center: Vector3,
	box_size: Vector3,
	box_color: Color
) -> void:
	var half_size: Vector3 = (
		box_size * 0.5
	)

	var left: float = (
		box_center.x
		- half_size.x
	)

	var right: float = (
		box_center.x
		+ half_size.x
	)

	var bottom: float = (
		box_center.y
		- half_size.y
	)

	var top: float = (
		box_center.y
		+ half_size.y
	)

	var front: float = (
		box_center.z
		- half_size.z
	)

	var back: float = (
		box_center.z
		+ half_size.z
	)

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
