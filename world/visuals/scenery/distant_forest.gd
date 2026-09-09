extends Node3D

const Job = preload("res://world/streaming/distant_forest_job.gd")
const Horizon = preload("res://world/visuals/terrain/landscape_horizon.gd")
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const Slots = preload("res://assets/catalog/planet_material_slots.gd")
const Buffer = preload("res://core/multimesh_buffer.gd")
const Budget = preload("res://world/streaming/environment_generation_budget.gd")
const ForestShader = preload("res://world/visuals/scenery/distant_forest.gdshader")
var generation_complete: bool = false
var stats: Dictionary = {}
var _manager: Node3D
var _horizon: Node3D
var _center := Vector2(INF, INF)
var _job: RefCounted
var _task: int = -1
var _pending: Array[String] = []
var _staged: Array[MultiMeshInstance3D] = []
var _active: Array[MultiMeshInstance3D] = []
var _ownership: ImageTexture
var _ownership_bytes := PackedByteArray()

func _ready() -> void:
	_manager = get_parent()
	_horizon = _manager.get_node("LandscapeHorizon")
	process_priority = 1100

static func species_bit(family: String, variant: int) -> int:
	return 1 << (variant + (3 if family == "tall_pine_v2" else 0))

func _process(_delta: float) -> void:
	# Playable terrain and its nearby assets get the first CPU/resource budget.
	if not _horizon.generation_complete:
		return
	_update_ownership()
	var player: Vector3 = _manager.player.global_position
	var target: Vector2 = Horizon.recenter_target(Vector2(player.x, player.z), _center)
	if _job == null and target != _center:
		_center = target
		var reference: Node = _manager.loaded_chunks.values()[0]
		var ecology: Node = reference.get_node("ProceduralEcosystemV6")
		_job = Job.new()
		_job.generator_script = WorldGenerator.get_script()
		_job.world_seed = WorldGenerator.get_world_seed()
		_job.center = target
		_job.chunk_size = Vector2(_manager.chunk_width, _manager.chunk_depth)
		_job.cell_size = reference.cell_size
		var spawn: Vector3 = WorldGenerator.get_scenic_spawn()
		_job.spawn_center = Vector2(spawn.x, spawn.z)
		_job.recipe = Job.Placement.tree_recipe(ecology.tree_attempts, ecology.forest_density_multiplier)
		_task = WorkerThreadPool.add_task(_job.run, false, "Distant forest placement")
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_pending.assign(_job.result.batches.keys())
	if _job == null:
		return
	if not _pending.is_empty():
		var key: String = _pending[0]
		var batch: Dictionary = _job.result.batches[key]
		if Budget.exhausted() or not Assets.prepare_lods(batch.asset_id, batch.species.geometry_variant):
			return
		if not Budget.claim_mesh_upload():
			return
		var started: int = Time.get_ticks_usec()
		var node := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = Assets.get_mesh(batch.asset_id, 2, batch.species.geometry_variant)
		mm.instance_count = batch.transforms.size()
		mm.buffer = Buffer.pack(batch.transforms, batch.custom)
		var bounds := AABB()
		for index in range(batch.transforms.size()):
			var tree_bounds: AABB = batch.transforms[index] * mm.mesh.get_aabb()
			var offsets: Color = batch.custom[index]
			var low: float = minf(0.0, minf(offsets.b, offsets.a))
			var high: float = maxf(0.0, maxf(offsets.b, offsets.a))
			tree_bounds.position.y += low
			tree_bounds.size.y += high - low
			bounds = tree_bounds if index == 0 else bounds.merge(tree_bounds)
		mm.custom_aabb = bounds
		node.multimesh = mm
		var material := ShaderMaterial.new()
		material.shader = ForestShader
		material.set_shader_parameter("planet_palette", Slots.create_texture(batch.species.palette))
		material.set_shader_parameter("species_bit", species_bit(batch.asset_id, batch.species.geometry_variant))
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		add_child(node)
		_staged.append(node)
		_pending.pop_front()
		Budget.record(started, "batch")
	if _pending.is_empty():
		for node in _active:
			node.queue_free()
		_active = _staged
		_staged = []
		stats = {"trees": _job.result.trees, "tiles": _job.result.tiles, "worker_ms": _job.result.worker_ms, "batches": _active.size()}
		_job = null
		_update_ownership()
		for node in _active:
			node.visible = true
		generation_complete = true

func _update_ownership() -> void:
	var origin: Vector2i = _manager.current_player_chunk - Vector2i(8, 8)
	var image := Image.create(16, 16, false, Image.FORMAT_R8)
	image.fill(Color.BLACK)
	for key: Vector2i in _manager.loaded_chunks:
		var index: Vector2i = key - origin
		if index.x < 0 or index.y < 0 or index.x >= 16 or index.y >= 16:
			continue
		var mask: int = 0
		var ecology: Node = _manager.loaded_chunks[key].get_node("ProceduralEcosystemV6")
		for batch: Dictionary in ecology._batches.values():
			if batch.tree and is_instance_valid(batch.get("node")):
				mask |= species_bit(batch.asset_id, batch.species.geometry_variant)
		image.set_pixel(index.x, index.y, Color(mask / 255.0, 0, 0))
	var data: PackedByteArray = image.get_data()
	if _ownership == null:
		_ownership = ImageTexture.create_from_image(image)
	elif _ownership_bytes != data:
		_ownership.update(image)
	_ownership_bytes = data
	for node in _active + _staged:
		var material: ShaderMaterial = node.material_override
		material.set_shader_parameter("forest_ownership", _ownership)
		material.set_shader_parameter("terrain_coverage", _horizon._coverage)
		material.set_shader_parameter("terrain_coverage_origin", Vector2(origin))
		material.set_shader_parameter("terrain_chunk_size", Vector2(_manager.chunk_width, _manager.chunk_depth))
		material.set_shader_parameter("terrain_coverage_enabled", true)

func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_job = null
