extends Node3D

const AuthoredAssets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const PlacementJob = preload("res://world/streaming/environment_placement_job.gd")
const Obstacles = preload("res://world/visuals/scenery/environment_obstacles.gd")
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


# Explicit staged state owns every resource. Cancelling/unloading a chunk cannot
# strand coroutine locals (RNGs and profile dictionaries) at engine shutdown.
var _phase: int = 0
var _chunk: Node3D
var _width: float
var _depth: float
var _profile: Dictionary = {}
var _placement_job: RefCounted
var _placement_task: int = -1
var _placement_usec: int = 0
var _obstacles: StaticBody3D
var _recipes: Array[Dictionary] = []
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
		if not bool(_chunk.get("generation_complete")) or not WorkBudget.claim_placement_job():
			return
		_begin_generation()
	if _phase == 1:
		if not WorkerThreadPool.is_task_completed(_placement_task):
			return
		WorkerThreadPool.wait_for_task_completion(_placement_task)
		_placement_task = -1
		WorkBudget.release_placement_job()
		_batches = _placement_job.result["batches"]
		placement_attempt_count = int(_placement_job.result["attempts"])
		instance_count = int(_placement_job.result["instances"])
		_placement_usec = _placement_job.elapsed_usec
		_placement_job = null
		_publish_keys.assign(_batches.keys())
		_phase = 2
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
			_profile.clear()
			_recipes.clear()
			set_process(false)
			_schedule_clusters()
			generation_finished.emit()


func _begin_generation() -> void:
	_width = float(_chunk.call("get_chunk_width"))
	_depth = float(_chunk.call("get_chunk_depth"))
	_profile = WorldGenerator.get_planet_profile()
	var spawn: Vector3 = WorldGenerator.get_scenic_spawn()
	_recipes = [
		PlacementJob.tree_recipe(tree_attempts, forest_density_multiplier),
		{"group": "shrub", "attempts": plant_field_attempts, "families": ["dense_bush_v2"], "chance": 0.74, "slope": 0.65},
		{"group": "rock", "attempts": rock_attempts + cliff_attempts, "families": ["layered_rock_v2"], "chance": 0.62, "slope": 1.35},
		{"group": "fern", "attempts": ground_attempts * 2, "families": ["fern_cluster_v2"], "chance": 0.85, "slope": 0.65},
		{"group": "flower", "attempts": ground_attempts * 2, "families": ["flower_cluster_v2"], "chance": 0.70, "slope": 0.65},
		{"group": "grass", "attempts": ground_attempts * 5, "families": ["grass_tuft_v2"], "chance": 1.00, "slope": 0.70},
	]
	_placement_job = PlacementJob.new()
	_placement_job.generator_script = WorldGenerator.get_script()
	_placement_job.world_seed = WorldGenerator.get_world_seed()
	_placement_job.chunk_origin = Vector2(_chunk.global_position.x, _chunk.global_position.z)
	_placement_job.width = _width
	_placement_job.depth = _depth
	_placement_job.cell_size = _chunk.cell_size
	_placement_job.heights = _chunk._fast_height_grid
	_placement_job.height_width = _chunk._fast_height_width
	_placement_job.height_depth = _chunk._fast_height_depth
	_placement_job.spawn_clear_center = Vector2(spawn.x, spawn.z)
	_placement_job.recipes = _recipes
	_phase = 1
	_placement_task = WorkerThreadPool.add_task(_placement_job.run, false, "Environment %s" % _chunk.name)


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
	var all_lod_bounds: AABB = mesh.get_aabb()
	for tier in range(3):
		var lod_mesh: Mesh = AuthoredAssets.get_mesh(batch["asset_id"], tier, int(species["geometry_variant"]))
		if lod_mesh != null:
			all_lod_bounds = all_lod_bounds.merge(lod_mesh.get_aabb())
	for i in range(transforms.size()):
		var transform: Transform3D = transforms[i]
		var instance_bounds: AABB = transform * all_lod_bounds
		bounds = instance_bounds if i == 0 else bounds.merge(instance_bounds)
	multimesh.custom_aabb = bounds.grow(0.65)
	multimesh.buffer = InstanceBuffer.pack(transforms, batch["custom"])
	var node := MultiMeshInstance3D.new()
	node.name = key
	node.multimesh = multimesh
	node.material_override = AuthoredAssets.get_material(profile, species)
	# Tree lifetime follows chunk ownership. A distance cutoff on a whole batch
	# can remove an irregular strip before the distant forest takes ownership.
	node.visibility_range_end = 0.0 if bool(batch["tree"]) else detail_visibility_distance
	add_child(node)
	batch["node"] = node
	if Obstacles.has_collision(str(batch["asset_id"])):
		if _obstacles == null:
			_obstacles = Obstacles.new()
			_obstacles.name = "EnvironmentObstacles"
			_chunk.get_node("Objects").add_child(_obstacles)
		_obstacles.add_batch(batch)
	_apply_lod()



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
		node.visibility_range_end = 0.0 if group == "trees" else detail_visibility_distance
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
		"placement_worker_usec": _placement_usec, "obstacle_shapes": _obstacles.shape_count if _obstacles != null else 0,
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



func _exit_tree() -> void:
	if _placement_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_placement_task)
		_placement_task = -1
		WorkBudget.release_placement_job()
	_placement_job = null
