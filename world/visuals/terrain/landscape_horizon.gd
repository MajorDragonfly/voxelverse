extends Node3D

const HorizonJob = preload("res://world/streaming/landscape_horizon_job.gd")
const Budget = preload("res://world/streaming/environment_generation_budget.gd")
const LandShader = preload("res://world/visuals/terrain/landscape_horizon.gdshader")
const WaterBuilder = preload("res://world/visuals/terrain/water_mesh_builder_v7.gd")
var generation_complete: bool = false
var _task: int = -1
var _job: RefCounted
var _center := Vector2(INF, INF)
var published_center := Vector2(INF, INF)
var _manager: Node3D
var _land: MeshInstance3D
var _water: MeshInstance3D
var _coverage: ImageTexture
var _coverage_bytes := PackedByteArray()

func _ready() -> void:
	_manager = get_parent()
	process_priority = 1000
	_land = MeshInstance3D.new()
	_water = MeshInstance3D.new()
	_land.name = "DistantLand"
	_water.name = "DistantWater"
	for node: MeshInstance3D in [_land, _water]:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	var land_material := ShaderMaterial.new()
	land_material.shader = LandShader
	_land.material_override = land_material
	var reference: Node = _manager.loaded_chunks.values()[0]
	var settings: Dictionary = reference.get_node("Visuals").get_water_settings()
	var profile: Dictionary = WorldGenerator.get_planet_profile()
	_water.material_override = WaterBuilder.make_material(profile, settings)
	_water.extra_cull_margin = WaterBuilder.displacement_margin(settings)

func _process(_delta: float) -> void:
	if not _manager.world_initialized:
		return
	_update_coverage()
	var player: Vector3 = _manager.player.global_position
	var target: Vector2 = recenter_target(Vector2(player.x, player.z), _center)
	if _task < 0 and target != _center:
		_center = target
		_job = HorizonJob.new()
		_job.generator_script = WorldGenerator.get_script()
		_job.world_seed = WorldGenerator.get_world_seed()
		_job.center = target
		_task = WorkerThreadPool.add_task(_job.run, false, "Landscape horizon")
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task) and not Budget.exhausted() and Budget.claim_mesh_upload():
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		var started: int = Time.get_ticks_usec()
		var land := ArrayMesh.new()
		land.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _job.result["terrain"])
		var water := ArrayMesh.new()
		water.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _job.result["water"])
		_land.mesh = land
		_water.mesh = water
		published_center = _job.center
		# Publish meshes and transfer ownership before the next rendered frame.
		# Keep old water while the worker runs; chunks outside its bounds retain
		# their fallback, including during long teleports and partial overlap.
		_manager.set_shared_water_bounds(Rect2(published_center - Vector2.ONE * HorizonJob.RADIUS, Vector2.ONE * HorizonJob.RADIUS * 2.0))
		_job = null
		generation_complete = true
		_update_coverage()
		Budget.record(started, "terrain")

func _update_coverage() -> void:
	var origin: Vector2i = _manager.current_player_chunk - Vector2i(8, 8)
	var image := Image.create(16, 16, false, Image.FORMAT_RGB8)
	image.fill(Color.BLACK)
	for key: Vector2i in _manager.loaded_chunks:
		var index: Vector2i = key - origin
		if index.x >= 0 and index.y >= 0 and index.x < 16 and index.y < 16:
			if bool(_manager.loaded_chunks[key].generation_complete):
				var chunk: Node3D = _manager.loaded_chunks[key]
				image.set_pixel(index.x, index.y, Color(float(chunk.terrain_presence), 1.0, float(chunk._terrain_lod_blend)))
	var data: PackedByteArray = image.get_data()
	if _coverage == null:
		_coverage = ImageTexture.create_from_image(image)
	elif data != _coverage_bytes:
		_coverage.update(image)
	_coverage_bytes = data
	_land.material_override.set_shader_parameter("coverage", _coverage)
	_land.material_override.set_shader_parameter("coverage_origin", Vector2(origin))
	_land.material_override.set_shader_parameter("chunk_size", Vector2(_manager.chunk_width, _manager.chunk_depth))
	for chunk: Node3D in _manager.loaded_chunks.values():
		for name: String in ["TerrainMesh", "FarTerrainMesh"]:
			var material := chunk.get_node(name).material_override as ShaderMaterial
			if material == null:
				continue
			if material.get_meta("coverage_origin", Vector2i(999999, 999999)) != origin or material.get_meta("coverage_active", false) != generation_complete:
				material.set_shader_parameter("terrain_coverage", _coverage)
				material.set_shader_parameter("terrain_coverage_origin", Vector2(origin))
				material.set_shader_parameter("terrain_chunk_size", Vector2(_manager.chunk_width, _manager.chunk_depth))
				material.set_shader_parameter("terrain_coverage_enabled", generation_complete)
				material.set_meta("coverage_origin", origin)
				material.set_meta("coverage_active", generation_complete)

static func recenter_target(player_xz: Vector2, center: Vector2) -> Vector2:
	# A player pacing across a 64 m rounding boundary used to rebuild on every
	# crossing. Retain 32 m of fine water beyond this 96 m movement threshold.
	if center.is_finite():
		var movement: Vector2 = (player_xz - center).abs()
		if maxf(movement.x, movement.y) <= 96.0:
			return center
	return Vector2(snappedf(player_xz.x, 64.0), snappedf(player_xz.y, 64.0))

func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_job = null
	if is_instance_valid(_manager) and _manager.is_inside_tree() and not _manager.is_queued_for_deletion():
		_manager.set_shared_water_bounds(Rect2())
		for chunk: Node3D in _manager.loaded_chunks.values():
			for name: String in ["TerrainMesh", "FarTerrainMesh"]:
				var material := chunk.get_node(name).material_override as ShaderMaterial
				if material != null:
					material.set_shader_parameter("terrain_coverage_enabled", false)
					material.remove_meta("coverage_origin")
