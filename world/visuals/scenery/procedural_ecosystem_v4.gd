extends Node3D

const AssetLibrary = preload(
	"res://world/visuals/scenery/voxel_asset_library_v4.gd"
)

# V4 uses fewer deterministic samples and shared micro-voxel meshes. Generation
# is split over frames so terrain collision becomes available before decorative
# vegetation and rocks are added.

@export_range(0, 48, 1) var tree_attempts: int = 16
@export_range(0, 48, 1) var rock_attempts: int = 10
@export_range(0, 64, 1) var ground_attempts: int = 18
@export var tree_visibility_distance: float = 150.0
@export var detail_visibility_distance: float = 82.0

const SEED_OFFSET: int = 2_104_729_311
const CLEAR_RADIUS: float = 10.0


func _ready() -> void:
	call_deferred("_generate_staged")


func _generate_staged() -> void:
	var chunk := get_parent() as Node3D
	if not _is_valid_chunk(chunk):
		return

	var width: float = float(chunk.call("get_chunk_width"))
	var depth: float = float(chunk.call("get_chunk_depth"))
	var random := _chunk_random(chunk, width, depth)

	await get_tree().process_frame
	if not is_inside_tree() or not _is_valid_chunk(chunk):
		return
	_generate_trees(chunk, width, depth, random)

	await get_tree().process_frame
	if not is_inside_tree() or not _is_valid_chunk(chunk):
		return
	_generate_rocks(chunk, width, depth, random)

	await get_tree().process_frame
	if not is_inside_tree() or not _is_valid_chunk(chunk):
		return
	_generate_ground_clusters(chunk, width, depth, random)


func _is_valid_chunk(chunk: Node3D) -> bool:
	return (
		chunk != null
		and is_instance_valid(chunk)
		and chunk.has_method("get_chunk_width")
		and chunk.has_method("get_chunk_depth")
		and chunk.has_method("get_surface_height_at_local_position")
	)


func _generate_trees(
	chunk: Node3D,
	width: float,
	depth: float,
	random: RandomNumberGenerator
) -> void:
	var trunks: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var crowns: Array[Transform3D] = []
	var crown_colors: Array[Color] = []

	for _attempt in range(tree_attempts):
		var point: Dictionary = _sample_point(
			chunk,
			width,
			depth,
			random,
			0.48
		)
		if point.is_empty():
			continue

		var biome: int = int(point.get("biome", WorldGenerator.Biome.GRASSLAND))
		var ecology: float = float(point.get("ecology", 0.5))
		if random.randf() > _tree_chance(biome) * ecology:
			continue

		var tree_height: float = random.randf_range(2.4, 5.6)
		var trunk_width: float = random.randf_range(0.52, 0.88)
		var crown_width: float = random.randf_range(1.25, 2.35)
		var crown_height: float = random.randf_range(0.95, 1.75)

		if biome == WorldGenerator.Biome.SAVANNA:
			tree_height *= 0.76
			crown_width *= 1.34
			crown_height *= 0.72
		elif biome == WorldGenerator.Biome.SWAMP:
			tree_height *= 1.16
			trunk_width *= 0.78
		elif biome == WorldGenerator.Biome.DENSE_FOREST:
			tree_height *= 1.12
			crown_height *= 1.12

		var angle: float = random.randf_range(0.0, TAU)
		var local_x: float = float(point.get("local_x", 0.0))
		var local_z: float = float(point.get("local_z", 0.0))
		var surface_height: float = float(point.get("surface_height", 0.0))
		var world_x: float = float(point.get("world_x", 0.0))
		var world_z: float = float(point.get("world_z", 0.0))
		var terrain_height: float = float(point.get("logical_height", 0.0))

		trunks.append(Transform3D(
			Basis(Vector3.UP, angle).scaled(
				Vector3(trunk_width, tree_height, trunk_width)
			),
			Vector3(local_x, surface_height + tree_height * 0.50, local_z)
		))
		crowns.append(Transform3D(
			Basis(Vector3.UP, angle + 0.23).scaled(
				Vector3(crown_width, crown_height, crown_width)
			),
			Vector3(
				local_x,
				surface_height + tree_height + crown_height * 0.20,
				local_z
			)
		))

		var terrain_color: Color = WorldGenerator.get_biome_color(
			world_x,
			world_z,
			terrain_height
		)
		trunk_colors.append(_vary(
			Color(0.30, 0.18, 0.09, 1.0),
			random,
			0.16
		))
		crown_colors.append(_vary(
			terrain_color.lerp(_leaf_target_color(biome), 0.72),
			random,
			0.14
		))

	_add_group(
		"V4TreeTrunks",
		AssetLibrary.get_trunk_mesh(),
		trunks,
		trunk_colors,
		tree_visibility_distance,
		true
	)
	_add_group(
		"V4TreeCrowns",
		AssetLibrary.get_crown_mesh(),
		crowns,
		crown_colors,
		tree_visibility_distance,
		true
	)


func _generate_rocks(
	chunk: Node3D,
	width: float,
	depth: float,
	random: RandomNumberGenerator
) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []

	for _attempt in range(rock_attempts):
		var point: Dictionary = _sample_point(
			chunk,
			width,
			depth,
			random,
			0.88
		)
		if point.is_empty():
			continue

		var biome: int = int(point.get("biome", WorldGenerator.Biome.GRASSLAND))
		if random.randf() > _rock_chance(biome):
			continue

		var scale_value: float = random.randf_range(0.55, 1.65)
		var basis := Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled(
			Vector3(
				scale_value * random.randf_range(0.74, 1.36),
				scale_value * random.randf_range(0.60, 1.06),
				scale_value
			)
		)
		transforms.append(Transform3D(
			basis,
			Vector3(
				float(point.get("local_x", 0.0)),
				float(point.get("surface_height", 0.0)) + scale_value * 0.10,
				float(point.get("local_z", 0.0))
			)
		))
		colors.append(_vary(
			WorldGenerator.get_world_rock_color(),
			random,
			0.18
		))

	_add_group(
		"V4RockClusters",
		AssetLibrary.get_rock_mesh(),
		transforms,
		colors,
		detail_visibility_distance * 1.35,
		true
	)


func _generate_ground_clusters(
	chunk: Node3D,
	width: float,
	depth: float,
	random: RandomNumberGenerator
) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []

	for _attempt in range(ground_attempts):
		var point: Dictionary = _sample_point(
			chunk,
			width,
			depth,
			random,
			0.58
		)
		if point.is_empty():
			continue

		var biome: int = int(point.get("biome", WorldGenerator.Biome.GRASSLAND))
		var ecology: float = float(point.get("ecology", 0.5))
		if random.randf() > _ground_chance(biome) * ecology:
			continue

		var width_scale: float = random.randf_range(0.42, 0.90)
		var height_scale: float = random.randf_range(0.45, 1.05)
		transforms.append(Transform3D(
			Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled(
				Vector3(width_scale, height_scale, width_scale)
			),
			Vector3(
				float(point.get("local_x", 0.0)),
				float(point.get("surface_height", 0.0)) + height_scale * 0.20,
				float(point.get("local_z", 0.0))
			)
		))

		var terrain_color: Color = WorldGenerator.get_biome_color(
			float(point.get("world_x", 0.0)),
			float(point.get("world_z", 0.0)),
			float(point.get("logical_height", 0.0))
		)
		colors.append(_vary(
			terrain_color.lerp(_ground_target_color(biome), 0.62),
			random,
			0.18
		))

	_add_group(
		"V4GroundClusters",
		AssetLibrary.get_ground_cluster_mesh(),
		transforms,
		colors,
		detail_visibility_distance,
		false
	)


func _sample_point(
	chunk: Node3D,
	width: float,
	depth: float,
	random: RandomNumberGenerator,
	maximum_slope: float
) -> Dictionary:
	var margin: float = minf(1.5, width * 0.18)
	var local_x: float = random.randf_range(-width * 0.5 + margin, width * 0.5 - margin)
	var local_z: float = random.randf_range(-depth * 0.5 + margin, depth * 0.5 - margin)
	var world_x: float = chunk.global_position.x + local_x
	var world_z: float = chunk.global_position.z + local_z

	if Vector2(world_x, world_z).length() < CLEAR_RADIUS:
		return {}

	var logical_height: float = WorldGenerator.get_terrain_height(world_x, world_z)
	if logical_height <= WorldGenerator.get_sea_level() + 0.25:
		return {}

	var surface_height: float = float(chunk.call(
		"get_surface_height_at_local_position",
		local_x,
		local_z
	))
	var sample_offset: float = 0.75
	var east_height: float = float(chunk.call(
		"get_surface_height_at_local_position",
		local_x + sample_offset,
		local_z
	))
	var north_height: float = float(chunk.call(
		"get_surface_height_at_local_position",
		local_x,
		local_z + sample_offset
	))
	var local_slope: float = maxf(
		absf(east_height - surface_height),
		absf(north_height - surface_height)
	) / sample_offset
	if local_slope > maximum_slope:
		return {}

	return {
		"local_x": local_x,
		"local_z": local_z,
		"world_x": world_x,
		"world_z": world_z,
		"logical_height": logical_height,
		"surface_height": surface_height,
		"biome": WorldGenerator.get_biome(world_x, world_z, logical_height),
		"ecology": WorldGenerator.get_ecology_density(
			world_x,
			world_z,
			logical_height
		),
	}


func _add_group(
	group_name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	colors: Array[Color],
	visibility_distance: float,
	shadows_enabled: bool
) -> void:
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
	instance.name = group_name
	instance.multimesh = multimesh
	instance.visibility_range_end = visibility_distance
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if shadows_enabled
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	add_child(instance)


func _chunk_random(
	chunk: Node3D,
	width: float,
	depth: float
) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	var chunk_x: int = roundi(chunk.global_position.x / maxf(width, 0.01))
	var chunk_z: int = roundi(chunk.global_position.z / maxf(depth, 0.01))
	random.seed = (
		WorldGenerator.get_world_seed()
		+ chunk_x * 73_856_093
		+ chunk_z * 19_349_663
		+ SEED_OFFSET
	)
	return random


func _tree_chance(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.DENSE_FOREST: return 0.96
		WorldGenerator.Biome.FOREST: return 0.82
		WorldGenerator.Biome.SWAMP: return 0.62
		WorldGenerator.Biome.WETLAND: return 0.40
		WorldGenerator.Biome.GRASSLAND: return 0.26
		WorldGenerator.Biome.SAVANNA: return 0.20
		WorldGenerator.Biome.STEPPE: return 0.10
		_: return 0.0


func _rock_chance(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.ROCKY_HIGHLANDS, WorldGenerator.Biome.ALPINE: return 0.92
		WorldGenerator.Biome.DESERT, WorldGenerator.Biome.STEPPE: return 0.58
		WorldGenerator.Biome.SNOW: return 0.48
		_: return 0.20


func _ground_chance(biome: int) -> float:
	match biome:
		WorldGenerator.Biome.FOREST, WorldGenerator.Biome.DENSE_FOREST: return 0.88
		WorldGenerator.Biome.GRASSLAND, WorldGenerator.Biome.WETLAND: return 0.78
		WorldGenerator.Biome.SAVANNA, WorldGenerator.Biome.STEPPE: return 0.46
		WorldGenerator.Biome.SWAMP: return 0.62
		_: return 0.10


func _leaf_target_color(biome: int) -> Color:
	match biome:
		WorldGenerator.Biome.SAVANNA:
			return Color(0.52, 0.56, 0.18, 1.0)
		WorldGenerator.Biome.SWAMP, WorldGenerator.Biome.WETLAND:
			return Color(0.08, 0.34, 0.24, 1.0)
		WorldGenerator.Biome.DENSE_FOREST:
			return Color(0.06, 0.28, 0.16, 1.0)
		_:
			return Color(0.14, 0.48, 0.22, 1.0)


func _ground_target_color(biome: int) -> Color:
	match biome:
		WorldGenerator.Biome.SAVANNA, WorldGenerator.Biome.STEPPE:
			return Color(0.62, 0.52, 0.20, 1.0)
		WorldGenerator.Biome.SWAMP, WorldGenerator.Biome.WETLAND:
			return Color(0.10, 0.38, 0.27, 1.0)
		WorldGenerator.Biome.FOREST, WorldGenerator.Biome.DENSE_FOREST:
			return Color(0.08, 0.36, 0.17, 1.0)
		_:
			return Color(0.28, 0.58, 0.24, 1.0)


func _vary(
	color: Color,
	random: RandomNumberGenerator,
	amount: float
) -> Color:
	var factor: float = random.randf_range(1.0 - amount, 1.0 + amount)
	return Color(
		clampf(color.r * factor, 0.0, 1.0),
		clampf(color.g * factor, 0.0, 1.0),
		clampf(color.b * factor, 0.0, 1.0),
		color.a
	)
