extends "res://world/visuals/scenery/procedural_ecosystem_v4.gd"

const AssetsV6 = preload(
	"res://world/visuals/scenery/voxel_asset_library_v6.gd"
)

@export_range(1.0, 2.5, 0.05)
var forest_density_multiplier: float = 1.55

@export_range(0, 48, 1)
var cliff_attempts: int = 10

@export_range(0, 96, 1)
var plant_field_attempts: int = 42

var _lod_tier: int = 0


func set_lod_tier(tier: int) -> void:
	_lod_tier = clampi(tier, 0, 2)
	_apply_lod()


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
	_apply_lod()

	await get_tree().process_frame
	if not is_inside_tree() or not _is_valid_chunk(chunk):
		return
	_generate_rocks(chunk, width, depth, random)
	_apply_lod()

	await get_tree().process_frame
	if not is_inside_tree() or not _is_valid_chunk(chunk):
		return
	_generate_ground_clusters(chunk, width, depth, random)
	_apply_lod()


func _generate_trees(
	chunk: Node3D,
	width: float,
	depth: float,
	random: RandomNumberGenerator
) -> void:
	var straight_trunks: Array[Transform3D] = []
	var straight_trunk_colors: Array[Color] = []
	var round_crowns: Array[Transform3D] = []
	var round_crown_colors: Array[Color] = []
	var gnarled_trunks: Array[Transform3D] = []
	var gnarled_colors: Array[Color] = []
	var flat_canopies: Array[Transform3D] = []
	var flat_colors: Array[Color] = []
	var conifer_trunks: Array[Transform3D] = []
	var conifer_trunk_colors: Array[Color] = []
	var conifer_crowns: Array[Transform3D] = []
	var conifer_colors: Array[Color] = []

	var attempts: int = maxi(roundi(float(tree_attempts) * forest_density_multiplier), tree_attempts)
	for _attempt in range(attempts):
		var point: Dictionary = _sample_point(chunk, width, depth, random, 0.52)
		if point.is_empty():
			continue
		var biome: int = int(point.get("biome", WorldGenerator.Biome.GRASSLAND))
		var ecology: float = float(point.get("ecology", 0.5))
		if random.randf() > _tree_chance(biome) * ecology:
			continue

		var tree_height: float = random.randf_range(2.6, 6.4)
		var trunk_width: float = random.randf_range(0.44, 0.80)
		var crown_width: float = random.randf_range(1.15, 2.40)
		var crown_height: float = random.randf_range(0.90, 1.90)
		var angle: float = random.randf_range(0.0, TAU)
		var local_x: float = float(point.get("local_x", 0.0))
		var local_z: float = float(point.get("local_z", 0.0))
		var surface_height: float = float(point.get("surface_height", 0.0))
		var world_x: float = float(point.get("world_x", 0.0))
		var world_z: float = float(point.get("world_z", 0.0))
		var terrain_height: float = float(point.get("logical_height", 0.0))
		var terrain_color: Color = WorldGenerator.get_biome_color(
			world_x,
			world_z,
			terrain_height
		)
		var trunk_color: Color = _vary(Color(0.29, 0.17, 0.085, 1.0), random, 0.18)
		var leaf_color: Color = _vary(
			terrain_color.lerp(_leaf_target_color(biome), 0.76),
			random,
			0.16
		)

		var architecture: int = 0
		if biome == WorldGenerator.Biome.SAVANNA:
			architecture = 1
		elif biome in [WorldGenerator.Biome.ALPINE, WorldGenerator.Biome.ROCKY_HIGHLANDS]:
			architecture = 2
		elif biome in [WorldGenerator.Biome.SWAMP, WorldGenerator.Biome.WETLAND]:
			architecture = 1 if random.randf() < 0.62 else 0
		else:
			architecture = random.randi_range(0, 2)

		if architecture == 1:
			tree_height *= 0.82
			crown_width *= 1.42
			crown_height *= 0.72
			gnarled_trunks.append(Transform3D(
				Basis(Vector3.UP, angle).scaled(Vector3(trunk_width, tree_height, trunk_width)),
				Vector3(local_x, surface_height + tree_height * 0.50, local_z)
			))
			gnarled_colors.append(trunk_color)
			flat_canopies.append(Transform3D(
				Basis(Vector3.UP, angle + 0.19).scaled(Vector3(crown_width, crown_height, crown_width)),
				Vector3(local_x, surface_height + tree_height + crown_height * 0.15, local_z)
			))
			flat_colors.append(leaf_color)
		elif architecture == 2:
			tree_height *= 1.12
			crown_width *= 0.78
			crown_height *= 1.36
			conifer_trunks.append(Transform3D(
				Basis(Vector3.UP, angle).scaled(Vector3(trunk_width * 0.82, tree_height, trunk_width * 0.82)),
				Vector3(local_x, surface_height + tree_height * 0.50, local_z)
			))
			conifer_trunk_colors.append(trunk_color.darkened(0.06))
			conifer_crowns.append(Transform3D(
				Basis(Vector3.UP, angle).scaled(Vector3(crown_width, crown_height, crown_width)),
				Vector3(local_x, surface_height + tree_height + crown_height * 0.06, local_z)
			))
			conifer_colors.append(leaf_color.darkened(0.08))
		else:
			straight_trunks.append(Transform3D(
				Basis(Vector3.UP, angle).scaled(Vector3(trunk_width, tree_height, trunk_width)),
				Vector3(local_x, surface_height + tree_height * 0.50, local_z)
			))
			straight_trunk_colors.append(trunk_color)
			round_crowns.append(Transform3D(
				Basis(Vector3.UP, angle + 0.23).scaled(Vector3(crown_width, crown_height, crown_width)),
				Vector3(local_x, surface_height + tree_height + crown_height * 0.20, local_z)
			))
			round_crown_colors.append(leaf_color)

	_add_group("V6StraightTrunks", AssetsV6.get_straight_trunk_mesh(), straight_trunks, straight_trunk_colors, tree_visibility_distance, true)
	_add_group("V6RoundCrowns", AssetsV6.get_round_crown_mesh(), round_crowns, round_crown_colors, tree_visibility_distance, true)
	_add_group("V6GnarledTrunks", AssetsV6.get_gnarled_trunk_mesh(), gnarled_trunks, gnarled_colors, tree_visibility_distance, true)
	_add_group("V6FlatCanopies", AssetsV6.get_flat_canopy_mesh(), flat_canopies, flat_colors, tree_visibility_distance, true)
	_add_group("V6ConiferTrunks", AssetsV6.get_straight_trunk_mesh(), conifer_trunks, conifer_trunk_colors, tree_visibility_distance, true)
	_add_group("V6ConiferCrowns", AssetsV6.get_conifer_crown_mesh(), conifer_crowns, conifer_colors, tree_visibility_distance, true)


func _generate_rocks(
	chunk: Node3D,
	width: float,
	depth: float,
	random: RandomNumberGenerator
) -> void:
	super._generate_rocks(chunk, width, depth, random)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for _attempt in range(cliff_attempts):
		var point: Dictionary = _sample_point(chunk, width, depth, random, 1.45)
		if point.is_empty():
			continue
		var world_x: float = float(point.get("world_x", 0.0))
		var world_z: float = float(point.get("world_z", 0.0))
		var slope: float = WorldGenerator.get_terrain_slope(world_x, world_z, 0.65)
		var biome: int = int(point.get("biome", WorldGenerator.Biome.GRASSLAND))
		if slope < 0.38 and biome not in [WorldGenerator.Biome.ROCKY_HIGHLANDS, WorldGenerator.Biome.ALPINE]:
			continue
		var scale_value: float = random.randf_range(0.65, 1.75)
		transforms.append(Transform3D(
			Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled(
				Vector3(scale_value * 1.2, scale_value, scale_value)
			),
			Vector3(
				float(point.get("local_x", 0.0)),
				float(point.get("surface_height", 0.0)) + scale_value * 0.18,
				float(point.get("local_z", 0.0))
			)
		))
		colors.append(_vary(WorldGenerator.get_world_rock_color(), random, 0.16))
	_add_group("V6CliffClusters", AssetsV6.get_cliff_cluster_mesh(), transforms, colors, detail_visibility_distance * 1.55, true)


func _generate_ground_clusters(
	chunk: Node3D,
	width: float,
	depth: float,
	random: RandomNumberGenerator
) -> void:
	super._generate_ground_clusters(chunk, width, depth, random)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for _attempt in range(plant_field_attempts):
		var point: Dictionary = _sample_point(chunk, width, depth, random, 0.62)
		if point.is_empty():
			continue
		var biome: int = int(point.get("biome", WorldGenerator.Biome.GRASSLAND))
		var ecology: float = float(point.get("ecology", 0.5))
		if random.randf() > _ground_chance(biome) * ecology * 0.90:
			continue
		var scale_value: float = random.randf_range(0.38, 0.90)
		transforms.append(Transform3D(
			Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_value),
			Vector3(
				float(point.get("local_x", 0.0)),
				float(point.get("surface_height", 0.0)) + scale_value * 0.08,
				float(point.get("local_z", 0.0))
			)
		))
		var terrain_color: Color = WorldGenerator.get_biome_color(
			float(point.get("world_x", 0.0)),
			float(point.get("world_z", 0.0)),
			float(point.get("logical_height", 0.0))
		)
		colors.append(_vary(terrain_color.lerp(_ground_target_color(biome), 0.72), random, 0.16))
	_add_group("V6FernFields", AssetsV6.get_fern_mesh(), transforms, colors, detail_visibility_distance, false)


func _apply_lod() -> void:
	for child in get_children():
		var instance := child as MultiMeshInstance3D
		if instance == null:
			continue
		var group_name: String = instance.name
		var is_ground_detail: bool = (
			"Ground" in group_name
			or "Fern" in group_name
		)
		var is_tree: bool = (
			"Trunk" in group_name
			or "Crown" in group_name
			or "Canop" in group_name
		)
		match _lod_tier:
			0:
				instance.visible = true
				instance.cast_shadow = (
					GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					if is_tree
					else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				)
			1:
				instance.visible = not is_ground_detail
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			2:
				instance.visible = is_tree
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
