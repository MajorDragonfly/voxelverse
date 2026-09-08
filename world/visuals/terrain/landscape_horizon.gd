extends Node3D

const HorizonJob = preload("res://world/streaming/landscape_horizon_job.gd")
const Budget = preload("res://world/streaming/environment_generation_budget.gd")
const LandShader = preload("res://world/visuals/terrain/landscape_horizon.gdshader")
const WaterShader = preload("res://world/visuals/terrain/ocean_surface.gdshader")
var generation_complete: bool = false
var _task: int = -1
var _job: RefCounted
var _center := Vector2(INF, INF)
var _manager: Node3D
var _land: MeshInstance3D
var _water: MeshInstance3D
var _coverage: ImageTexture
var _coverage_bytes := PackedByteArray()
var _timer: float = 0.0

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
	var water_material := ShaderMaterial.new()
	water_material.shader = WaterShader
	water_material.set_shader_parameter("clip_loaded_chunks", true)
	var profile: Dictionary = WorldGenerator.get_planet_profile()
	var slots: Dictionary = profile["material_slots"]
	var deep: Color = slots["water_deep"]
	var shallow: Color = slots["water_shallow"]
	deep.a = 0.84
	shallow.a = 0.62
	water_material.set_shader_parameter("deep_color", deep)
	water_material.set_shader_parameter("shallow_color", shallow)
	var horizon: Color = profile["atmosphere"]["sky_horizon"]
	water_material.set_shader_parameter("reflection_tint", Vector3(horizon.r, horizon.g, horizon.b))
	water_material.render_priority = 1
	_water.material_override = water_material

func _process(delta: float) -> void:
	if not _manager.world_initialized:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.15
		_update_coverage()
	var player: Vector3 = _manager.player.global_position
	var target := Vector2(snappedf(player.x, 64.0), snappedf(player.z, 64.0))
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
		_job = null
		generation_complete = true
		Budget.record(started, "terrain")

func _update_coverage() -> void:
	var origin: Vector2i = _manager.current_player_chunk - Vector2i(8, 8)
	var image := Image.create(16, 16, false, Image.FORMAT_R8)
	image.fill(Color.BLACK)
	for key: Vector2i in _manager.loaded_chunks:
		var index: Vector2i = key - origin
		if index.x >= 0 and index.y >= 0 and index.x < 16 and index.y < 16:
			if bool(_manager.loaded_chunks[key].generation_complete):
				image.set_pixel(index.x, index.y, Color.WHITE)
	var data: PackedByteArray = image.get_data()
	if _coverage == null:
		_coverage = ImageTexture.create_from_image(image)
	elif data != _coverage_bytes:
		_coverage.update(image)
	_coverage_bytes = data
	for node: MeshInstance3D in [_land, _water]:
		node.material_override.set_shader_parameter("coverage", _coverage)
		node.material_override.set_shader_parameter("coverage_origin", Vector2(origin))
		node.material_override.set_shader_parameter("chunk_size", Vector2(_manager.chunk_width, _manager.chunk_depth))

func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_job = null
