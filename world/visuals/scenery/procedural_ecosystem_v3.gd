extends Node3D

# A chunk creates only a handful of MultiMesh draw groups. Objects are sampled in
# deterministic ecological clusters instead of uniform grass/berry scatter.

@export_range(0, 80, 1) var canopy_attempts: int = 34
@export_range(0, 100, 1) var rock_attempts: int = 28
@export_range(0, 160, 1) var ground_cluster_attempts: int = 46
@export var tree_visibility_distance: float = 240.0
@export var detail_visibility_distance: float = 125.0

const SEED_OFFSET: int = 1_934_221_771
const CLEAR_RADIUS: float = 15.0


func _ready() -> void:
	call_deferred("_generate")


func _generate() -> void:
	var chunk := get_parent() as Node3D
	if chunk == null:
		return
	if not chunk.has_method("get_chunk_width") or not chunk.has_method("get_surface_height_at_local_position"):
		return

	var width: float = float(chunk.call("get_chunk_width"))
	var depth: float = float(chunk.call("get_chunk_depth"))
	var random := _chunk_random(chunk, width, depth)
	_generate_canopies(chunk, width, depth, random)
	_generate_rocks(chunk, width, depth, random)
	_generate_ground_clusters(chunk, width, depth, random)


func _generate_canopies(chunk: Node3D, width: float, depth: float, random: RandomNumberGenerator) -> void:
	var trunks: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var crowns: Array[Transform3D] = []
	var crown_colors: Array[Color] = []

	for _index in range(canopy_attempts):
		var point: Dictionary = _sample_point(chunk, width, depth, random, 0.38)
		if point.is_empty():
			continue
		var biome: int = int(point.get("biome", 0))
		var chance: float = _tree_chance(biome)
		if random.randf() > chance:
			continue

		var region_scale: float = 1.0
		if WorldGenerator.has_method("get_region_profile"):
			var profile: Dictionary = WorldGenerator.get_region_profile(
				float(point.world_x), float(point.world_z)
			)
			region_scale = float(profile.get("flora_scale", 1.0))

		var height: float = random.randf_range(2.8, 6.2) * region_scale
		var trunk_radius: float = random.randf_range(0.18, 0.42)
		var crown_width: float = random.randf_range(1.2, 2.8) * region_scale
		var crown_height: float = random.randf_range(1.0, 2.5)
		if biome == WorldGenerator.Biome.SAVANNA:
			height *= 0.78
			crown_width *= 1.45
			crown_height *= 0.58
		elif biome == WorldGenerator.Biome.SWAMP:
			height *= 1.2
			trunk_radius *= 0.72
		elif biome == WorldGenerator.Biome.SNOW:
			crown_width *= 0.72
			crown_height *= 1.35

		var angle: float = random.randf_range(0.0, TAU)
		var surface: float = float(point.surface_height)
		var local_x: float = float(point.local_x)
		var local_z: float = float(point.local_z)
		trunks.append(Transform3D(
			Basis(Vector3.UP, angle).scaled(Vector3(trunk_radius, height, trunk_radius)),
			Vector3(local_x, surface + height * 0.5, local_z)
		))
		crowns.append(Transform3D(
			Basis(Vector3.UP, angle + 0.31).scaled(Vector3(crown_width, crown_height, crown_width * random.randf_range(0.78, 1.18))),
			Vector3(local_x, surface + height + crown_height * 0.25, local_z)
		))
		trunk_colors.append(_vary(Color(0.24, 0.15, 0.08, 1.0), random, 0.12))
		crown_colors.append(_leaf_color(biome, random))

	_add_group("EcosystemTrunks", _cylinder_mesh(), trunks, trunk_colors, tree_visibility_distance, true)
	_add_group("EcosystemCrowns", _crown_mesh(), crowns, crown_colors, tree_visibility_distance, true)


func _generate_rocks(chunk: Node3D, width: float, depth: float, random: RandomNumberGenerator) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for _index in range(rock_attempts):
		var point: Dictionary = _sample_point(chunk, width, depth, random, 0.72)
		if point.is_empty():
			continue
		var biome: int = int(point.biome)
		if random.randf() > _rock_chance(biome):
			continue
		var size: float = random.randf_range(0.28, 1.35)
		var basis := Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled(
			Vector3(size * random.randf_range(0.75, 1.45), size * random.randf_range(0.45, 1.05), size)
		)
		transforms.append(Transform3D(
			basis,
			Vector3(float(point.local_x), float(point.surface_height) + size * 0.18, float(point.local_z))
		))
		colors.append(_vary(WorldGenerator.get_world_rock_color(), random, 0.16))
	_add_group("EcosystemRocks", _rock_mesh(), transforms, colors, detail_visibility_distance * 1.45, true)


func _generate_ground_clusters(chunk: Node3D, width: float, depth: float, random: RandomNumberGenerator) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for _index in range(ground_cluster_attempts):
		var point: Dictionary = _sample_point(chunk, width, depth, random, 0.42)
		if point.is_empty():
			continue
		var biome: int = int(point.biome)
		if random.randf() > _ground_chance(biome):
			continue
		var width_scale: float = random.randf_range(0.18, 0.62)
		var height_scale: float = random.randf_range(0.22, 0.88)
		var basis := Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled(
			Vector3(width_scale, height_scale, width_scale * random.randf_range(0.7, 1.3))
		)
		transforms.append(Transform3D(
			basis,
			Vector3(float(point.local_x), float(point.surface_height) + height_scale * 0.25, float(point.local_z))
		))
		colors.append(_ground_color(biome, random))
	_add_group("EcosystemGroundClusters", _cluster_mesh(), transforms, colors, detail_visibility_distance, false)


func _sample_point(chunk: Node3D, width: float, depth: float, random: RandomNumberGenerator, max_slope: float) -> Dictionary:
	var local_x: float = random.randf_range(-width * 0.5 + 2.0, width * 0.5 - 2.0)
	var local_z: float = random.randf_range(-depth * 0.5 + 2.0, depth * 0.5 - 2.0)
	var world_x: float = chunk.global_position.x + local_x
	var world_z: float = chunk.global_position.z + local_z
	if Vector2(world_x, world_z).length() < CLEAR_RADIUS:
		return {}
	var height: float = WorldGenerator.get_terrain_height(world_x, world_z)
	if height <= WorldGenerator.get_sea_level() + 0.2:
		return {}
	if WorldGenerator.get_terrain_slope(world_x, world_z, 1.0) > max_slope:
		return {}
	return {
		"local_x": local_x,
		"local_z": local_z,
		"world_x": world_x,
		"world_z": world_z,
		"logical_height": height,
		"surface_height": float(chunk.call("get_surface_height_at_local_position", local_x, local_z)),
		"biome": WorldGenerator.get_biome(world_x, world_z, height),
	}


func _add_group(name_value: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], visibility: float, shadows: bool) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_color(index, colors[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = name_value
	instance.multimesh = multimesh
	instance.visibility_range_end = visibility
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _chunk_random(chunk: Node3D, width: float, depth: float) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	var chunk_x: int = roundi(chunk.global_position.x / maxf(width, 0.01))
	var chunk_z: int = roundi(chunk.global_position.z / maxf(depth, 0.01))
	random.seed = WorldGenerator.get_world_seed() + chunk_x * 73_856_093 + chunk_z * 19_349_663 + SEED_OFFSET
	return random


func _cylinder_mesh() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.72
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 6
	return mesh


func _crown_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


func _rock_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	return mesh


func _cluster_mesh() -> Mesh:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	mesh.left_to_right = 0.35
	return mesh


func _tree_chance(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.DENSE_FOREST: return 0.92
		WorldGenerator.Biome.FOREST: return 0.78
		WorldGenerator.Biome.SWAMP: return 0.62
		WorldGenerator.Biome.GRASSLAND: return 0.24
		WorldGenerator.Biome.SAVANNA: return 0.18
		WorldGenerator.Biome.COLD_GRASSLAND: return 0.12
		_: return 0.0


func _rock_chance(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.ROCKY_HIGHLANDS, WorldGenerator.Biome.ALPINE: return 0.9
		WorldGenerator.Biome.DESERT, WorldGenerator.Biome.STEPPE: return 0.55
		WorldGenerator.Biome.SNOW: return 0.46
		_: return 0.16


func _ground_chance(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.FOREST, WorldGenerator.Biome.DENSE_FOREST: return 0.82
		WorldGenerator.Biome.GRASSLAND, WorldGenerator.Biome.WETLAND: return 0.72
		WorldGenerator.Biome.SAVANNA, WorldGenerator.Biome.STEPPE: return 0.40
		_: return 0.12


func _leaf_color(biome: int, random: RandomNumberGenerator) -> Color:
	var color := Color(0.14, 0.42, 0.18, 1.0)
	if biome == WorldGenerator.Biome.SAVANNA:
		color = Color(0.43, 0.48, 0.16, 1.0)
	elif biome == WorldGenerator.Biome.SWAMP:
		color = Color(0.08, 0.26, 0.16, 1.0)
	elif biome == WorldGenerator.Biome.COLD_GRASSLAND or biome == WorldGenerator.Biome.SNOW:
		color = Color(0.20, 0.34, 0.30, 1.0)
	return _vary(color, random, 0.12)


func _ground_color(biome: int, random: RandomNumberGenerator) -> Color:
	var color := WorldGenerator.get_biome_color(0.0, 0.0, 2.0)
	if biome == WorldGenerator.Biome.FOREST or biome == WorldGenerator.Biome.DENSE_FOREST:
		color = Color(0.10, 0.31, 0.13, 1.0)
	elif biome == WorldGenerator.Biome.SAVANNA or biome == WorldGenerator.Biome.STEPPE:
		color = Color(0.55, 0.46, 0.20, 1.0)
	return _vary(color, random, 0.16)


func _vary(color: Color, random: RandomNumberGenerator, amount: float) -> Color:
	var factor: float = random.randf_range(1.0 - amount, 1.0 + amount)
	return Color(clampf(color.r * factor, 0.0, 1.0), clampf(color.g * factor, 0.0, 1.0), clampf(color.b * factor, 0.0, 1.0), color.a)
