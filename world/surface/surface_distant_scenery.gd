extends Node
## One CPU job and one staged visual set. No actors, saves or distant colliders.
const Job = preload("res://world/surface/surface_scenery_job.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const Slots = preload("res://assets/catalog/planet_material_slots.gd")
const Buffer = preload("res://core/multimesh_buffer.gd")
const SceneryShader = preload("res://world/surface/visuals/surface_scenery.gdshader")
const RECENTER_METERS: float = 32.0
var adapter: RefCounted
var player: Node3D
var nearby: Node
var generation_complete: bool = false
var max_worker_ms: float = 0.0
var max_publish_ms: float = 0.0
var last_publish_units: int = 0
var discarded_results: int = 0
var _job: RefCounted
var _task: int = -1
var _active: Dictionary = {}
var _staging: Dictionary = {}
var _center: Array = []
var _closed: bool = false


func _ready() -> void:
	# Reserve individual visual submissions before the nearby publisher runs.
	process_priority = -1
	adapter.origin_shifted.connect(_rebase)
	nearby.patches_changed.connect(_nearby_changed)


func _process(_delta: float) -> void:
	last_publish_units = 0
	if _closed: return
	_update_ownership(_active)
	var here: Dictionary = adapter.location(player)
	var absolute: Array = Cube.cartesian(here, adapter.terrain.surface.body.radius)
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task): return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		max_worker_ms = maxf(max_worker_ms, _job.elapsed_usec / 1000.0)
		var result: Dictionary = _job.result
		_job = null
		if result.has("error"):
			push_error(result.error)
			_closed = true
			return
		if Cube.local_position(absolute, result.anchor).length() > Job.RADIUS - 224.0:
			discarded_results += 1
			_center = []
		else:
			_begin(result)
	if not _staging.is_empty():
		# Teleports must not publish stale trees over the newly prepared surface.
		if Cube.local_position(absolute, _staging.anchor).length() > Job.RADIUS - 224.0:
			_discard(_staging)
			_staging = {}
			_center = []
			discarded_results += 1
		else:
			_publish_step()
			return
	if _task < 0 and (_center.is_empty() or Cube.local_position(absolute, _center).length() >= RECENTER_METERS):
		_center = absolute
		_job = Job.new()
		_job.body = adapter.terrain.surface.body.duplicate(true)
		_job.focus = here.duplicate(true)
		_job.exclusions.append({"point": Cube.cartesian(nearby.spawn, _job.body.radius), "radius": 8.0})
		for place: Dictionary in nearby._campaign_exclusions():
			_job.exclusions.append({"point": Cube.global_position(place.point, adapter.terrain.origin), "radius": place.radius})
		_job.prepare()
		_task = WorkerThreadPool.add_task(_job.run, false, "Spherical distant scenery")


func _begin(data: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "DistantScenery"
	holder.visible = false
	add_child(holder)
	holder.position = Cube.local_position(data.anchor, adapter.terrain.origin)
	data["node"] = holder
	data["next_batch"] = 0
	data["ownership"] = ImageTexture.create_from_image(Image.create(Job.MAX_CELLS, 1, false, Image.FORMAT_R8))
	data["near_ids"] = []
	_staging = data
	_update_ownership(_staging, true)


func _publish_step() -> void:
	# At most one scenery/near-flora allocation per frame, including cold art.
	nearby.reserve_scenery_frame()
	var started: int = Time.get_ticks_usec()
	if _staging.next_batch < _staging.batches.size():
		var batch: Dictionary = _staging.batches[_staging.next_batch]
		if not Assets.prepare_lods(batch.asset_id, batch.species.geometry_variant): return
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.use_custom_data = true
		mesh.mesh = Assets.get_mesh(batch.asset_id, 2, batch.species.geometry_variant)
		mesh.instance_count = batch.transforms.size()
		mesh.buffer = Buffer.pack(batch.transforms, batch.custom)
		var visual := MultiMeshInstance3D.new()
		visual.multimesh = mesh
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = SceneryShader
		material.set_shader_parameter("planet_palette", Slots.create_texture(batch.species.palette))
		material.set_shader_parameter("nearby_ownership", _staging.ownership)
		if "rock" in batch.asset_id: material.set_shader_parameter("wind_strength", 0.0)
		visual.material_override = material
		_staging.node.add_child(visual)
		_staging.next_batch += 1
	else:
		_update_ownership(_staging, true)
		_staging.node.visible = true
		_discard(_active)
		_active = _staging
		_staging = {}
		generation_complete = true
	last_publish_units = 1
	max_publish_ms = maxf(max_publish_ms, (Time.get_ticks_usec() - started) / 1000.0)


func _update_ownership(data: Dictionary, force: bool = false) -> void:
	if data.is_empty(): return
	var ids: Array = nearby.patches.keys()
	ids.sort()
	if not force and data.near_ids == ids: return
	data.near_ids = ids
	var image := Image.create(Job.MAX_CELLS, 1, false, Image.FORMAT_R8)
	for index in range(data.cell_ids.size()):
		if nearby.patches.has(data.cell_ids[index]): image.set_pixel(index, 0, Color.WHITE)
	data["ownership_image"] = image
	data.ownership.update(image)


func _nearby_changed() -> void:
	_update_ownership(_active)
	_update_ownership(_staging)


func _rebase(_shift: Vector3) -> void:
	for data: Dictionary in [_active, _staging]:
		if not data.is_empty(): data.node.position = Cube.local_position(data.anchor, adapter.terrain.origin)


func diagnostics() -> Dictionary:
	return {"ready": generation_complete, "workers": int(_task >= 0), "staged_sets": int(not _staging.is_empty()),
		"cells": _active.get("cell_ids", []).size(), "instances": _active.get("instances", 0),
		"batches": _active.get("next_batch", 0), "last_publish_units": last_publish_units,
		"max_worker_ms": max_worker_ms, "max_publish_ms": max_publish_ms, "discarded": discarded_results}


func _discard(data: Dictionary) -> void:
	if data.is_empty(): return
	data.node.visible = false
	data.node.queue_free()


func close() -> void:
	if _closed and _job == null and _active.is_empty() and _staging.is_empty(): return
	_closed = true
	if _task >= 0: WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_job = null
	_discard(_active)
	_discard(_staging)
	_active = {}
	_staging = {}
	if adapter.origin_shifted.is_connected(_rebase): adapter.origin_shifted.disconnect(_rebase)
	if nearby.patches_changed.is_connected(_nearby_changed): nearby.patches_changed.disconnect(_nearby_changed)


func _exit_tree() -> void:
	close()
