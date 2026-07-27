extends Node3D

const ASSET_SEED_OFFSET: int = 1_487_293_711
const SPAWN_CLEAR_RADIUS: float = 13.0
const EDGE_MARGIN: float = 2.5

@export_category("Biome Assets")
@export_range(0, 120, 1)
var tree_attempts_per_chunk: int = 46

@export_range(0, 160, 1)
var shrub_attempts_per_chunk: int = 54

@export_range(0, 220, 1)
var flower_attempts_per_chunk: int = 78

@export_range(0, 100, 1)
var mushroom_attempts_per_chunk: int = 26

@export_category("Visibility")
@export_range(20.0, 500.0, 5.0)
var tree_visibility_distance: float = 210.0

@export_range(20.0, 300.0, 5.0)
var small_asset_visibility_distance: float = 115.0


func _ready() -> void:
	call_deferred("_generate_biome_assets")


func _generate_biome_assets() -> void:
	var chunk: Node3D = get_parent() as Node3D
	if chunk == null:
		return
	if not chunk.has_method("get_chunk_width"):
		return
	if not chunk.has_method("get_chunk_depth"):
		return
	if not chunk.has_method("get_surface_height_at_local_position"):
		return

	var chunk_width: float = float(chunk.call("get_chunk_width"))
	var chunk_depth: float = float(chunk.call("get_chunk_depth"))
	var random := _create_chunk_random(chunk)

	_generate_trees(chunk, chunk_width, chunk_depth, random)
	_generate_shrubs(chunk, chunk_width, chunk_depth, random)
	_generate_flowers(chunk, chunk_width, chunk_depth, random)
	_generate_mushrooms(chunk, chunk_width, chunk_depth, random)


func _generate_trees(
	chunk: Node3D,
	chunk_width: float,
	chunk_depth: float,
	random: RandomNumberGenerator
) -> void:
	var trunk_transforms: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var canopy_transforms: Array[Transform3D] = []
	var canopy_colors: Array[Color] = []

	for _attempt in range(tree_attempts_per_chunk):
		var point: Dictionary = _sample_land_point(
			chunk,
			chunk_width,
			chunk_depth,
			random,
			0.52
		)
		if point.is_empty():
			continue

		var biome: int = int(point.get("biome", WorldGenerator.Biome.GRASSLAND))
		var density: float = WorldGenerator.get_biome_vegetation_density(
			float(point.get("world_x", 0.0)),
			float(point.get("world_z", 0.0)),
			float(point.get("logical_height", 0.0))
		)
		var tree_probability: float = _get_tree_probability(biome) * density
		if random.randf() > tree_probability:
			continue

		var base_height: float = random.randf_range(2.2, 4.8)
		var trunk_width: float = random.randf_range(0.26, 0.52)
		var canopy_width: float = random.randf_range(1.25, 2.75)
		var canopy_height: float = random.randf_range(1.0, 2.4)

		if biome == WorldGenerator.Biome.SAVANNA:
			base_height *= 0.82
			canopy_width *= 1.35
			canopy_height *= 0.65
		elif biome == WorldGenerator.Biome.SWAMP:
			base_height *= 1.18
			trunk_width *= 0.72
			canopy_width *= 0.82
		elif biome == WorldGenerator.Biome.DENSE_FOREST:
			base_height *= 1.12
			canopy_height *= 1.18

		var angle: float = random.randf_range(0.0, TAU)
		var local_x: float = float(point.get("local_x", 0.0))
		var local_z: float = float(point.get("local_z", 0.0))
		var terrain_height: float = float(point.get("surface_height", 0.0))
		var trunk_basis := Basis(Vector3.UP, angle).scaled(
			Vector3(trunk_width, base_height, trunk_width)
		)
		var canopy_basis := Basis(Vector3.UP, angle + 0.27).scaled(
			Vector3(canopy_width, canopy_height, canopy_width * random.randf_range(0.78, 1.12))
		)

		trunk_transforms.append(Transform3D(
			trunk_basis,
			Vector3(local_x, terrain_height + base_height * 0.5, local_z)
		))
		canopy_transforms.append(Transform3D(
			canopy_basis,
			Vector3(
				local_x,
				terrain_height + base_height + canopy_height * 0.34,
				local_z
			)
		))

		trunk_colors.append(_vary_color(
			Color(0.34, 0.22, 0.12, 1.0),
			random,
			0.14
		))
		canopy_colors.append(_get_leaf_color(biome, random))

	_add_multimesh_group(
		"ProceduralTreeTrunks",
		_create_box_mesh(Vector3.ONE, true),
		trunk_transforms,
		trunk_colors,
		tree_visibility_distance,
		true
	)
	_add_multimesh_group(
		"ProceduralTreeCanopies",
		_create_box_mesh(Vector3.ONE, true),
		canopy_transforms,
		canopy_colors,
		tree_visibility_distance,
		true
	)


func _generate_shrubs(
	chunk: Node3D,
	chunk_width: float,
	chunk_depth: float,
	random: RandomNumberGenerator
) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []

	for _attempt in range(shrub_attempts_per_chunk):
		var point: Dictionary = _sample_land_point(
			chunk,
			chunk_width,
			chunk_depth,
			random,
			0.58
		)
		if point.is_empty():
			continue

		var biome: int = int(point.get("biome", WorldGenerator.Biome.GRASSLAND))
		var probability: float = _get_shrub_probability(biome)
		if random.randf() > probability:
			continue

		var width: float = random.randf_range(0.35, 1.10)
		var height: float = random.randf_range(0.28, 0.85)
		var depth: float = width * random.randf_range(0.72, 1.25)
		var basis := Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled(
			Vector3(width, height, depth)
		)
		var surface_height: float = float(point.get("surface_height", 0.0))

		transforms.append(Transform3D(
			basis,
			Vector3(
				float(point.get("local_x", 0.0)),
				surface_height + height * 0.42,
				float(point.get("local_z", 0.0))
			)
		))
		colors.append(_get_shrub_color(biome, random))

	_add_multimesh_group(
		"ProceduralShrubs",
		_create_box_mesh(Vector3.ONE, true),
		transforms,
		colors,
		small_asset_visibility_distance,
		false
	)


func _generate_flowers(
	chunk: Node3D,
	chunk_width: float,
	chunk_depth: float,
	random: RandomNumberGenerator
) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []

	for _attempt in range(flower_attempts_per_chunk):
		var point: Dictionary = _sample_land_point(
			chunk,
			chunk_width,
			chunk_depth,
			random,
			0.38
		)
		if point.is_empty():
			continue

		var biome: int = int(point.get("biome", WorldGenerator.Biome.GRASSLAND))
		if random.randf() > _get_flower_probability(biome):
			continue

		var width: float = random.randf_range(0.06, 0.14)
		var height: float = random.randf_range(0.18, 0.48)
		var basis := Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled(
			Vector3(width, height, width)
		)
		var surface_height: float = float(point.get("surface_height", 0.0))

		transforms.append(Transform3D(
			basis,
			Vector3(
				float(point.get("local_x", 0.0)),
				surface_height + height * 0.48,
				float(point.get("local_z", 0.0))
			)
		))
		colors.append(_get_flower_color(random))

	_add_multimesh_group(
		"ProceduralFlowers",
		_create_box_mesh(Vector3.ONE, true),
		transforms,
		colors,
		small_asset_visibility_distance,
		false
	)


func _generate_mushrooms(
	chunk: Node3D,
	chunk_width: float,
	chunk_depth: float,
	random: RandomNumberGenerator
) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []

	for _attempt in range(mushroom_attempts_per_chunk):
		var point: Dictionary = _sample_land_point(
			chunk,
			chunk_width,
			chunk_depth,
			random,
			0.42
		)
		if point.is_empty():
			continue

		var biome: int = int(point.get("biome", WorldGenerator.Biome.GRASSLAND))
		if biome not in [
			WorldGenerator.Biome.FOREST,
			WorldGenerator.Biome.DENSE_FOREST,
			WorldGenerator.Biome.SWAMP,
			WorldGenerator.Biome.WETLAND,
		]:
			continue
		if random.randf() > 0.48:
			continue

		var width: float = random.randf_range(0.09, 0.24)
		var height: float = random.randf_range(0.10, 0.30)
		var basis := Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled(
			Vector3(width, height, width)
		)
		var surface_height: float = float(point.get("surface_height", 0.0))

		transforms.append(Transform3D(
			basis,
			Vector3(
				float(point.get("local_x", 0.0)),
				surface_height + height * 0.38,
				float(point.get("local_z", 0.0))
			)
		))
		colors.append(_vary_color(
			Color(0.62, 0.22, 0.16, 1.0),
			random,
			0.24
		))

	_add_multimesh_group(
		"ProceduralMushrooms",
		_create_box_mesh(Vector3.ONE, true),
		transforms,
		colors,
		small_asset_visibility_distance,
		false
	)


func _sample_land_point(
	chunk: Node3D,
	chunk_width: float,
	chunk_depth: float,
	random: RandomNumberGenerator,
	maximum_slope: float
) -> Dictionary:
	var half_width: float = chunk_width * 0.5
	var half_depth: float = chunk_depth * 0.5
	var local_x: float = random.randf_range(
		-half_width + EDGE_MARGIN,
		half_width - EDGE_MARGIN
	)
	var local_z: float = random.randf_range(
		-half_depth + EDGE_MARGIN,
		half_depth - EDGE_MARGIN
	)
	var world_x: float = chunk.global_position.x + local_x
	var world_z: float = chunk.global_position.z + local_z

	if Vector2(world_x, world_z).length() < SPAWN_CLEAR_RADIUS:
		return {}

	var logical_height: float = WorldGenerator.get_terrain_height(world_x, world_z)
	if logical_height <= WorldGenerator.get_sea_level() + 0.35:
		return {}

	var slope: float = WorldGenerator.get_terrain_slope(world_x, world_z, 0.9)
	if slope > maximum_slope:
		return {}

	return {
		"local_x": local_x,
		"local_z": local_z,
		"world_x": world_x,
		"world_z": world_z,
		"logical_height": logical_height,
		"surface_height": float(chunk.call(
			"get_surface_height_at_local_position",
			local_x,
			local_z
		)),
		"biome": WorldGenerator.get_biome(world_x, world_z, logical_height),
	}


func _add_multimesh_group(
	group_name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	colors: Array[Color],
	visibility_distance: float,
	cast_shadows: bool
) -> void:
	if transforms.is_empty():
		return

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = transforms.size()

	for index in range(transforms.size()):
		multi_mesh.set_instance_transform(index, transforms[index])
		multi_mesh.set_instance_color(index, colors[index])

	var instance := MultiMeshInstance3D.new()
	instance.name = group_name
	instance.multimesh = multi_mesh
	instance.visibility_range_end = maxf(visibility_distance, 1.0)
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	add_child(instance)


func _create_box_mesh(size: Vector3, use_vertex_color: bool) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = use_vertex_color
	material.roughness = 0.94
	material.metallic = 0.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mesh.material = material
	return mesh


func _create_chunk_random(chunk: Node3D) -> RandomNumberGenerator:
	var coordinates: Vector2i = Vector2i.ZERO
	var coordinate_value: Variant = chunk.get("chunk_coordinates")
	if coordinate_value is Vector2i:
		coordinates = coordinate_value

	var random := RandomNumberGenerator.new()
	random.seed = (
		WorldGenerator.get_world_seed()
		+ ASSET_SEED_OFFSET
		+ coordinates.x * 73_856_093
		+ coordinates.y * 19_349_663
	)
	return random


func _get_tree_probability(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.DENSE_FOREST: return 0.92
		WorldGenerator.Biome.FOREST: return 0.72
		WorldGenerator.Biome.SWAMP: return 0.58
		WorldGenerator.Biome.WETLAND: return 0.40
		WorldGenerator.Biome.SAVANNA: return 0.26
		WorldGenerator.Biome.GRASSLAND: return 0.12
		WorldGenerator.Biome.RIVER: return 0.20
		WorldGenerator.Biome.COLD_GRASSLAND: return 0.08
		_: return 0.0


func _get_shrub_probability(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.DENSE_FOREST: return 0.78
		WorldGenerator.Biome.FOREST: return 0.68
		WorldGenerator.Biome.SWAMP: return 0.70
		WorldGenerator.Biome.WETLAND: return 0.62
		WorldGenerator.Biome.GRASSLAND: return 0.46
		WorldGenerator.Biome.RIVER: return 0.52
		WorldGenerator.Biome.SAVANNA: return 0.34
		WorldGenerator.Biome.STEPPE: return 0.18
		WorldGenerator.Biome.COLD_GRASSLAND: return 0.24
		_: return 0.02


func _get_flower_probability(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.GRASSLAND: return 0.58
		WorldGenerator.Biome.FOREST: return 0.34
		WorldGenerator.Biome.WETLAND: return 0.42
		WorldGenerator.Biome.RIVER: return 0.48
		WorldGenerator.Biome.COLD_GRASSLAND: return 0.22
		WorldGenerator.Biome.SAVANNA: return 0.14
		WorldGenerator.Biome.DENSE_FOREST: return 0.10
		_: return 0.0


func _get_leaf_color(biome: int, random: RandomNumberGenerator) -> Color:
	var base_color := Color(0.18, 0.42, 0.18, 1.0)
	match biome:
		WorldGenerator.Biome.DENSE_FOREST:
			base_color = Color(0.08, 0.29, 0.14, 1.0)
		WorldGenerator.Biome.SWAMP:
			base_color = Color(0.16, 0.34, 0.20, 1.0)
		WorldGenerator.Biome.SAVANNA:
			base_color = Color(0.43, 0.48, 0.18, 1.0)
		WorldGenerator.Biome.COLD_GRASSLAND:
			base_color = Color(0.24, 0.38, 0.28, 1.0)
	return _vary_color(base_color, random, 0.16)


func _get_shrub_color(biome: int, random: RandomNumberGenerator) -> Color:
	var base_color := Color(0.22, 0.43, 0.18, 1.0)
	if biome == WorldGenerator.Biome.SWAMP:
		base_color = Color(0.15, 0.32, 0.22, 1.0)
	elif biome == WorldGenerator.Biome.SAVANNA:
		base_color = Color(0.48, 0.46, 0.20, 1.0)
	return _vary_color(base_color, random, 0.18)


func _get_flower_color(random: RandomNumberGenerator) -> Color:
	var palette: Array[Color] = [
		Color(0.88, 0.72, 0.22, 1.0),
		Color(0.82, 0.34, 0.44, 1.0),
		Color(0.54, 0.50, 0.88, 1.0),
		Color(0.90, 0.88, 0.73, 1.0),
		Color(0.72, 0.36, 0.76, 1.0),
	]
	return _vary_color(
		palette[random.randi_range(0, palette.size() - 1)],
		random,
		0.08
	)


func _vary_color(
	base_color: Color,
	random: RandomNumberGenerator,
	amount: float
) -> Color:
	var variation: float = random.randf_range(-amount, amount)
	if variation >= 0.0:
		return base_color.lightened(variation)
	return base_color.darkened(absf(variation))
