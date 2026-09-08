extends Node3D

const AuthoredAssets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const FloraFactory = preload("res://world/visuals/scenery/flora_species_factory_v9.gd")
const WorkBudget = preload("res://world/streaming/environment_generation_budget.gd")
const ClusterBuilder = preload("res://world/visuals/scenery/environment_cluster_builder.gd")
const Slots = preload("res://assets/catalog/planet_material_slots.gd")
const ClusterShader = preload("res://assets/catalog/planet_cluster.gdshader")
const InstanceBuffer = preload("res://core/multimesh_buffer.gd")

const SEED_OFFSET: int = 2_104_729_311
@export_range(0, 48, 1) var tree_attempts: int = 16
@export_range(0, 48, 1) var rock_attempts: int = 10
@export_range(0, 64, 1) var ground_attempts: int = 18
@export var tree_visibility_distance: float = 150.0
@export var detail_visibility_distance: float = 82.0
@export var enable_cluster_lod: bool = true
@export_range(0, 262144, 1024) var cluster_vertex_limit: int = 65536

# Existing scene/editor properties remain valid while placement now consumes
# the actual biome grammar and authored, shared meshes.
@export_range(1.0, 2.5, 0.05) var forest_density_multiplier: float = 1.55
@export_range(0, 48, 1) var cliff_attempts: int = 10
@export_range(0, 96, 1) var plant_field_attempts: int = 42

signal generation_finished
var generation_complete: bool = false
var placement_attempt_count: int = 0
var instance_count: int = 0
var _lod_tier: int = 0
var _batches: Dictionary = {}
var _tree_points: Array[Vector2] = []
var _spawn_clear_center := Vector2.ZERO


# Explicit staged state owns every resource. Cancelling/unloading a chunk cannot
# strand coroutine locals (RNGs and profile dictionaries) at engine shutdown.
var _phase: int = 0
var _chunk: Node3D
var _width: float
var _depth: float
var _profile: Dictionary = {}
var _random: RandomNumberGenerator
var _recipes: Array[Dictionary] = []
var _recipe_index: int = 0
var _attempt_index: int = 0
var _publish_keys: Array[String] = []
var _publish_index: int = 0
var _cluster_started: bool = false
var _cluster_builders: Dictionary = {}
var _cluster_nodes: Dictionary = {}
var _cluster_fallbacks: Dictionary = {}
var _cluster_vertices: int = 0
var _cluster_indices: int = 0
var _cluster_instances: int = 0


func _ready() -> void:
	_chunk = get_parent() as Node3D
	if not _is_valid_chunk(_chunk):
		set_process(false)


func _process(_delta: float) -> void:
	if generation_complete:
		_process_clusters()
		return
	if _phase == 0:
		if not bool(_chunk.get("generation_complete")):
			return
		_begin_generation()
	if _phase == 1:
		while not WorkBudget.exhausted():
			if _recipe_index >= _recipes.size():
				_phase = 2
				_publish_keys.assign(_batches.keys())
				break
			var recipe: Dictionary = _recipes[_recipe_index]
			if _attempt_index >= int(recipe["attempts"]):
				_recipe_index += 1
				_attempt_index = 0
				continue
			var started: int = Time.get_ticks_usec()
			_place_attempt(_chunk, _width, _depth, _random, _profile, recipe, _attempt_index)
			WorkBudget.record(started)
			_attempt_index += 1
	if _phase == 2:
		while _publish_index < _publish_keys.size() and not WorkBudget.exhausted():
			var key: String = _publish_keys[_publish_index]
			var batch: Dictionary = _batches[key]
			var started: int = Time.get_ticks_usec()
			var prepared: bool = AuthoredAssets.prepare_lods(batch["asset_id"], int(batch["species"]["geometry_variant"]))
			WorkBudget.record(started, "resource")
			if not prepared or WorkBudget.exhausted():
				return
			started = Time.get_ticks_usec()
			_publish_batch(key, batch, _profile)
			WorkBudget.record(started, "batch")
			_publish_index += 1
		if _publish_index == _publish_keys.size():
			_apply_lod()
			_phase = 3
			generation_complete = true
			_random = null
			_profile.clear()
			_recipes.clear()
			set_process(false)
			_schedule_clusters()
			generation_finished.emit()


func _begin_generation() -> void:
	_width = float(_chunk.call("get_chunk_width"))
	_depth = float(_chunk.call("get_chunk_depth"))
	_profile = WorldGenerator.get_planet_profile()
	_random = _chunk_random(_chunk, _width, _depth)
	var spawn: Vector3 = WorldGenerator.get_scenic_spawn()
	_spawn_clear_center = Vector2(spawn.x, spawn.z)
	_recipes = [
		{"group": "tree", "attempts": roundi(tree_attempts * forest_density_multiplier), "families": ["ancient_oak_v2", "tall_pine_v2"], "chance": 0.70, "slope": 0.52},
		{"group": "shrub", "attempts": plant_field_attempts, "families": ["dense_bush_v2"], "chance": 0.74, "slope": 0.65},
		{"group": "rock", "attempts": rock_attempts + cliff_attempts, "families": ["layered_rock_v2"], "chance": 0.62, "slope": 1.35},
		{"group": "fern", "attempts": ground_attempts * 2, "families": ["fern_cluster_v2"], "chance": 0.85, "slope": 0.65},
		{"group": "flower", "attempts": ground_attempts * 2, "families": ["flower_cluster_v2"], "chance": 0.70, "slope": 0.65},
		{"group": "grass", "attempts": ground_attempts * 5, "families": ["grass_tuft_v2"], "chance": 1.00, "slope": 0.70},
	]
	_phase = 1


func _place_attempt(chunk: Node3D, width: float, depth: float, random: RandomNumberGenerator, profile: Dictionary, recipe: Dictionary, attempt: int) -> void:
	placement_attempt_count += 1
	var point: Dictionary = _sample_point(chunk, width, depth, random, float(recipe["slope"]))
	if point.is_empty():
		return
	var wx: float = float(point["world_x"])
	var wz: float = float(point["world_z"])
	var tree: bool = recipe["group"] == "tree"
	if tree and Vector2(wx, wz).distance_to(_spawn_clear_center) < 3.5:
		return
	var composition: Dictionary = WorldGenerator.get_biome_composition(wx, wz, point["logical_height"])
	var families: Dictionary = composition.get("families", {})
	var options: Array = recipe["families"]
	var total: float = 0.0
	for family: String in options:
		total += float(families.get(family, 0.0))
	if random.randf() >= minf(total * float(recipe["chance"]), 0.98):
		return
	if tree:
		for existing: Vector2 in _tree_points:
			if existing.distance_squared_to(Vector2(wx, wz)) < 10.2:
				return
	var roll: float = random.randf() * total
	var selected: String = str(options[0])
	for family: String in options:
		selected = family
		roll -= float(families.get(family, 0.0))
		if roll <= 0.0:
			break
	var species_index: int = random.randi_range(0, 2)
	var key: String = "%s_%d" % [selected, species_index]
	if not _batches.has(key):
		var species: Dictionary = FloraFactory.create_species_variant(profile, "forest" if tree else "grassland", selected, species_index)
		_batches[key] = {"asset_id": selected, "species": species, "transforms": [], "custom": [], "tree": tree, "node": null}
	var batch: Dictionary = _batches[key]
	var species: Dictionary = batch["species"]
	var individual: Dictionary = FloraFactory.create_instance_variation(species, random.randi() + attempt)
	var scale_value: float = float(individual["uniform_scale"])
	var height: float = clampf(float(species["height_scale"]), 0.78, 1.42) * float(individual["height_multiplier"])
	var breadth: float = clampf(float(species["width_scale"]), 0.82, 1.28) * float(individual["width_multiplier"])
	if not tree:
		height = lerpf(1.0, height, 0.35)
		breadth = lerpf(1.0, breadth, 0.35)
		scale_value = clampf(scale_value, 0.82, 1.18)
	var basis := Basis(Vector3.UP, deg_to_rad(float(individual["rotation_y"])))
	basis = basis.rotated(basis.z.normalized(), deg_to_rad(float(individual["lean_degrees"])) * (0.55 if tree else 1.0))
	basis = basis.scaled(Vector3(breadth, height, breadth) * scale_value)
	var transform := Transform3D(basis, Vector3(point["local_x"], float(point["surface_height"]) - 0.035, point["local_z"]))
	batch["transforms"].append(transform)
	batch["custom"].append(Color(lerpf(0.95, 1.03, float(individual["health"])), random.randf(), float(individual["age"]), 1.0))
	if tree:
		_tree_points.append(Vector2(wx, wz))
	instance_count += 1


func _publish_batch(key: String, batch: Dictionary, profile: Dictionary) -> void:
	var species: Dictionary = batch["species"]
	var mesh: Mesh = AuthoredAssets.get_mesh(batch["asset_id"], _lod_tier, int(species["geometry_variant"]))
	if mesh == null:
		push_error("Environment asset has no valid runtime LOD: %s" % batch["asset_id"])
		return
	var transforms: Array = batch["transforms"]
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	var bounds: AABB
	for i in range(transforms.size()):
		var transform: Transform3D = transforms[i]
		var instance_bounds: AABB = transform * mesh.get_aabb()
		bounds = instance_bounds if i == 0 else bounds.merge(instance_bounds)
	multimesh.custom_aabb = bounds.grow(0.65)
	multimesh.buffer = InstanceBuffer.pack(transforms, batch["custom"])
	var node := MultiMeshInstance3D.new()
	node.name = key
	node.multimesh = multimesh
	node.material_override = AuthoredAssets.get_material(profile, species)
	node.visibility_range_end = tree_visibility_distance if bool(batch["tree"]) else detail_visibility_distance
	add_child(node)
	batch["node"] = node


func set_lod_tier(tier: int) -> void:
	_lod_tier = clampi(tier, 0, 2)
	_apply_lod()
	_schedule_clusters()


func set_cluster_enabled(enabled: bool) -> void:
	enable_cluster_lod = enabled
	_apply_lod()
	_schedule_clusters()


func _apply_lod() -> void:
	for batch: Dictionary in _batches.values():
		var node := batch.get("node") as MultiMeshInstance3D
		if node == null:
			continue
		var mesh: Mesh = AuthoredAssets.get_mesh(batch["asset_id"], _lod_tier, int(batch["species"]["geometry_variant"]))
		if mesh != null:
			node.multimesh.mesh = mesh
		var is_small: bool = batch["asset_id"] in ["fern_cluster_v2", "flower_cluster_v2", "grass_tuft_v2"]
		var cluster_active: bool = enable_cluster_lod and _lod_tier == 2 and _cluster_nodes.has(_cluster_group(batch))
		node.visible = (_lod_tier < 2 or not is_small) and not cluster_active
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _lod_tier == 0 and bool(batch["tree"]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node: MeshInstance3D in _cluster_nodes.values():
		node.visible = enable_cluster_lod and _lod_tier == 2


func _cluster_group(batch: Dictionary) -> String:
	return "trees" if bool(batch["tree"]) else "low"


func _schedule_clusters() -> void:
	if not generation_complete:
		return
	if not enable_cluster_lod or _lod_tier != 2:
		set_process(false)
		return
	if not _cluster_started:
		_cluster_started = true
		for batch: Dictionary in _batches.values():
			if batch["asset_id"] in ["fern_cluster_v2", "flower_cluster_v2", "grass_tuft_v2"]:
				continue
			var group: String = _cluster_group(batch)
			if not _cluster_builders.has(group):
				var builder := ClusterBuilder.new()
				builder.vertex_limit = cluster_vertex_limit
				_cluster_builders[group] = builder
			var species: Dictionary = batch["species"]
			var mesh: Mesh = AuthoredAssets.get_mesh(batch["asset_id"], 2, int(species["geometry_variant"]))
			_cluster_builders[group].sources.append({"mesh": mesh, "transforms": batch["transforms"],
				"custom": batch["custom"], "palette": species["palette"]})
	set_process(not _cluster_builders.is_empty())


func _process_clusters() -> void:
	if not enable_cluster_lod or _lod_tier != 2:
		set_process(false)
		return
	for group: String in _cluster_builders.keys():
		var builder: RefCounted = _cluster_builders[group]
		while not bool(builder.complete) and not WorkBudget.exhausted():
			var started: int = Time.get_ticks_usec()
			builder.step()
			WorkBudget.record(started, "cluster")
		if not bool(builder.complete):
			return
		if not str(builder.failure).is_empty():
			# Capacity/invalid-input fallback keeps the original Far batches visible.
			_cluster_fallbacks[group] = builder.failure
			_cluster_builders.erase(group)
			continue
		if WorkBudget.exhausted() or not WorkBudget.claim_mesh_upload():
			return
		var started: int = Time.get_ticks_usec()
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, builder.get_arrays())
		var material := ShaderMaterial.new()
		material.shader = ClusterShader
		material.set_shader_parameter("planet_palette", Slots.create_atlas(builder.palettes))
		var node := MeshInstance3D.new()
		node.name = "FarCluster_" + group
		node.mesh = mesh
		node.material_override = material
		node.custom_aabb = mesh.get_aabb().grow(0.65)
		node.visibility_range_end = tree_visibility_distance if group == "trees" else detail_visibility_distance
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_cluster_nodes[group] = node
		_cluster_vertices += builder.vertices.size()
		_cluster_indices += builder.indices.size()
		_cluster_instances += int(builder.instance_count)
		_cluster_builders.erase(group)
		_apply_lod()
		WorkBudget.record(started, "cluster_upload")
	set_process(not _cluster_builders.is_empty())


func get_generation_stats() -> Dictionary:
	var visible_batches: int = 0
	for child: Node in get_children():
		if child is GeometryInstance3D and child.visible:
			visible_batches += 1
	return {"complete": generation_complete, "attempts": placement_attempt_count, "instances": instance_count,
		"batches": _batches.size(), "nodes": get_child_count(), "visible_batches": visible_batches,
		"cluster_complete": _cluster_started and _cluster_builders.is_empty(),
		"cluster_ready": _cluster_started and _cluster_builders.is_empty() and _cluster_fallbacks.is_empty(),
		"cluster_nodes": _cluster_nodes.size(), "cluster_vertices": _cluster_vertices,
		"cluster_indices": _cluster_indices, "cluster_instances": _cluster_instances,
		"cluster_fallbacks": _cluster_fallbacks.duplicate(),
		"max_cluster_step_usec": WorkBudget.max_cluster_step_usec, "max_cluster_upload_usec": WorkBudget.max_cluster_upload_usec,
		"max_step_usec": WorkBudget.max_step_usec, "max_placement_usec": WorkBudget.max_placement_usec,
		"max_batch_usec": WorkBudget.max_batch_usec, "max_resource_usec": WorkBudget.max_resource_usec}


func _is_valid_chunk(chunk: Node3D) -> bool:
	return (
		chunk != null
		and is_instance_valid(chunk)
		and chunk.has_method("get_chunk_width")
		and chunk.has_method("get_chunk_depth")
		and chunk.has_method("get_surface_height_at_local_position")
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

	}


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
