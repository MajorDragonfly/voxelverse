extends "res://world/planet_lab/sphere_tiles.gd"
class_name AdaptiveSphereTiles

const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const PatchMesh = preload("res://world/planet_lab/planet_patch_mesh.gd")
const PatchJob = preload("res://world/planet_lab/planet_patch_job.gd")
const Support = preload("res://world/surface/surface_support.gd")
## At most two indivisible engine operations, not two complete patches.
const BUILDS_PER_FRAME: int = 2
const BUILD_BUDGET_USEC: int = 4000
const MAX_CACHED: int = 256
const MAX_RESIDENT: int = 1536
const TRANSITION_SECONDS: float = 0.18
const REFOCUS_METERS: float = 8.0
const MAX_LOOKAHEAD_METERS: float = 32.0
var layout: RefCounted
var leaves: Dictionary = {}
var _staging: Dictionary = {}
var _pending: Array[String] = []
var _collision_pending: Array[String] = []
var publication_operations: Dictionary = {}
var max_operation_usec: Dictionary = {}
var _requested_direction: Vector3 = Vector3.ZERO
var _collision_direction: Vector3 = Vector3.ZERO
var ocean_material: ShaderMaterial
var land_material: ShaderMaterial
var _fade_land: ShaderMaterial
var _fade_water: ShaderMaterial
var _old_land: ShaderMaterial
var _old_water: ShaderMaterial
var _cache: Dictionary = {}
var _retired: Array[Dictionary] = []
var _arriving: Array[Dictionary] = []
var _transition: float = 0.0
var _prepared_near: Array = []
var cache_hits: int = 0
var max_prepare_usec: int = 0
var last_worker_seconds: float = 0.75
var peak_tiles: int = 0
var peak_resident_meshes: int = 0
var max_build_usec: int = 0
var updates: int = 0
var last_build_count: int = 0
var _job: RefCounted
var max_worker_usec: int = 0
var max_publish_usec: int = 0
var max_initial_publish_usec: int = 0
var upload_samples: Array[float] = []
var lookahead_direction: Vector3 = Vector3.ZERO
var job_samples: Array[Dictionary] = []
var _last_query_direction: Vector3 = Vector3.ZERO
var publish_deferrals: int = 0
var _focus_direction: Vector3 = Vector3.ZERO
var _refresh_requested: bool = true
var _generation: int = 0
var _job_generation: int = -1
var _staging_generation: int = -1
var _published_generation: int = -1
var _job_body_id: String = ""
var discarded_jobs: int = 0
var discarded_publications: int = 0


func set_motion_hint(direction: Vector3, desired_velocity: Vector3) -> void:
	# Use intended tangent movement, including at a blocked frontier. Actual
	# velocity is zero there and still points the old way on a reversal.
	var seconds: float = clampf(last_worker_seconds + 0.25, 0.75, 2.5)
	var lead: Vector3 = (desired_velocity.slide(direction) * seconds).limit_length(MAX_LOOKAHEAD_METERS)
	lookahead_direction = (direction + lead / float(surface.body.radius)).normalized()


func configure(descriptor: Dictionary) -> void:
	surface = Surface.new(descriptor)
	layout = Layout.new(float(descriptor.radius))
	land_material = ShaderMaterial.new()
	land_material.shader = preload("res://world/planet_lab/planet_land.gdshader")
	ocean_material = ShaderMaterial.new()
	ocean_material.shader = preload("res://world/planet_lab/planet_water.gdshader")
	ocean_material.set_shader_parameter("water", true)
	_fade_land = land_material.duplicate()
	_fade_water = ocean_material.duplicate()
	_old_land = land_material.duplicate()
	_old_water = ocean_material.duplicate()
	_old_land.set_shader_parameter("lod_retiring", true)
	_old_water.set_shader_parameter("lod_retiring", true)
	_set_phase(0.0)
	# Water uses the same adaptive curved patches as land. A fixed low-poly
	# SphereMesh would sink metres below the buoyancy surface on a large body.


func stream_at(direction: Vector3, force: bool = false) -> void:
	_requested_direction = direction
	# A forced initial load clears the previous motion hint. Without a new hint,
	# subsequent requests must follow their own position, not the spawn point.
	if force: lookahead_direction = Vector3.ZERO
	var focus: Vector3 = direction if force or lookahead_direction == Vector3.ZERO else lookahead_direction
	if force or direction.distance_to(_last_query_direction) * float(surface.body.radius) >= REFOCUS_METERS \
			or focus.distance_to(_focus_direction) * float(surface.body.radius) >= REFOCUS_METERS:
		var previous_hint: Vector3 = _focus_direction - _last_query_direction
		var next_hint: Vector3 = focus - direction
		# Forward progress queues a newer focus but keeps useful work alive.
		# Cancelling it every 8 m would starve uploads at normal walking speeds.
		if previous_hint.dot(next_hint) < 0.0 or direction.distance_to(_last_query_direction) * float(surface.body.radius) > MAX_LOOKAHEAD_METERS * 2.0:
			_generation += 1
		_last_query_direction = direction
		_focus_direction = focus
		_refresh_requested = true
	if force or (_job == null and _pending.is_empty() and _retired.is_empty() and _refresh_requested):
		_request(_focus_direction)
	if force:
		_job.advance(true)
		_collect_job()
		while not _staging.is_empty():
			while not _pending.is_empty(): _build_next()
			_publish()
		_finish_transition()
	if direction.distance_to(_collision_direction) * float(surface.body.radius) >= 4.0 or force:
		_update_collisions(direction)


func _request(direction: Vector3) -> void:
	if _job != null:
		_job.join()
	_finish_transition()
	_discard_staging()
	_last_direction = direction
	_generation += 1
	_refresh_requested = false
	_staging = {}
	_pending.clear()
	_job = PatchJob.new()
	_job.body = surface.body.duplicate(true)
	_job.direction = direction
	_job_generation = _generation
	_job_body_id = str(surface.body.id)
	for id: String in leaves:
		_job.previous_masks[id] = leaves[id].mask
		_job.available[PatchJob.variant_key(leaves[id])] = true
	for key: String in _cache:
		_job.available[key] = true
	_job.start()


func _collect_job() -> void:
	if _job == null:
		return
	_staging = _job.result
	_staging_generation = _job_generation
	last_worker_seconds = _job.duration_usec / 1000000.0
	max_worker_usec = maxi(max_worker_usec, _job.duration_usec)
	if job_samples.size() < 256:
		job_samples.append({"worker_ms": _job.duration_usec / 1000.0, "selection_ms": _job.selection_usec / 1000.0, "mesh_ms": _job.mesh_usec / 1000.0, "workers": _job.worker_count, "tiles": _staging.size()})
	_job = null
	for id: String in _staging:
		var tile: Dictionary = _staging[id]
		if leaves.has(id) and leaves[id].mask == tile.mask:
			_staging[id] = leaves[id]
		else:
			var key: String = PatchJob.variant_key(tile)
			if _cache.has(key):
				tile.merge(_cache[key])
				_cache.erase(key)
				cache_hits += 1
			_pending.append(id)
	_queue_near_preparation()
	_trim_cache()
	_pending.sort_custom(func(a: String, b: String): return _staging[a].direction.distance_squared_to(_last_direction) > _staging[b].direction.distance_squared_to(_last_direction))
	if not job_samples.is_empty():
		job_samples[-1]["uploads"] = _pending.size()
	if _pending.is_empty():
		_publish()


func _process(delta: float) -> void:
	last_build_count = 0
	if not _retired.is_empty():
		_transition += delta / TRANSITION_SECONDS
		_set_phase(minf(1.0, _transition))
		if _transition >= 1.0: _finish_transition()
	var staging_current: bool = _advance_job()
	# Planning/retirement and handoff retain separate timings. Only actual
	# upload/preparation work consumes this cooperative publication budget.
	var started: int = Time.get_ticks_usec()
	while not _collision_pending.is_empty() and last_build_count < BUILDS_PER_FRAME:
		var id: String = _collision_pending[-1]
		if not leaves.has(id) or _prepare_collision(leaves[id]): _collision_pending.pop_back()
		last_build_count += 1
		if Time.get_ticks_usec() - started >= BUILD_BUDGET_USEC: break
	if last_build_count > 0 and _collision_pending.is_empty(): _update_collisions(_requested_direction)
	while staging_current and not _pending.is_empty() and last_build_count < BUILDS_PER_FRAME and Time.get_ticks_usec() - started < BUILD_BUDGET_USEC:
		_build_next()
		last_build_count += 1
	if last_build_count > 0:
		var elapsed: int = Time.get_ticks_usec() - started
		max_build_usec = maxi(max_build_usec, elapsed)
		if upload_samples.size() < 2048: upload_samples.append(elapsed / 1000.0)
	if staging_current and _pending.is_empty(): _publish()


func _advance_job() -> bool:
	if _job != null:
		if _job_generation != _generation or _job_body_id != str(surface.body.id):
			# Never join unfinished work or start obsolete mesh batches here.
			if not _job.try_join(): return false
			_job = null
			discarded_jobs += 1
			_request(_focus_direction)
			return false
		if not _job.advance(): return false
		_collect_job()
	if not _staging.is_empty() and _staging_generation != _generation:
		discarded_publications += 1
		_request(_focus_direction)
		return false
	return true


func _build_next() -> void:
	var started: int = Time.get_ticks_usec()
	var id: String = _pending[-1]
	var tile: Dictionary = _staging[id]
	var operation: String
	if not tile.has("mesh"):
		operation = "land"
		tile["mesh"] = PatchMesh.upload_surface(tile.arrays.land_arrays)
		# Empty water needs no separate upload or frame.
		if tile.arrays.water_arrays.is_empty(): tile["water"] = null
	elif not tile.has("water"):
		operation = "water"
		tile["water"] = PatchMesh.upload_surface(tile.arrays.water_arrays)
	elif not tile.has("node"):
		operation = "node"
		_build_node(tile)
	elif id in _prepared_near:
		_prepare_collision(tile)
	if not operation.is_empty(): _record_operation(operation, started)
	if tile.has("mesh") and tile.has("water"): tile.erase("arrays")
	if tile.has("node") and (id not in _prepared_near or tile.has("collider")):
		_pending.pop_back()
	max_prepare_usec = maxi(max_prepare_usec, Time.get_ticks_usec() - started)
	_trim_cache()


func _build_node(tile: Dictionary) -> void:
	var node := MeshInstance3D.new()
	node.name = "Patch_" + str(tile.id).replace("/", "_")
	node.mesh = tile.mesh
	node.material_override = land_material if leaves.is_empty() else _fade_land
	node.position = Cube.local_position(tile.anchor, origin)
	node.visible = false
	add_child(node)
	tile["node"] = node
	if tile.water != null:
		var sea := MeshInstance3D.new()
		sea.mesh = tile.water
		sea.material_override = ocean_material if leaves.is_empty() else _fade_water
		sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(sea)
		tile["sea"] = sea


func _prepare_collision(tile: Dictionary) -> bool:
	var started: int = Time.get_ticks_usec()
	if not tile.has("shape"):
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(tile.collision_faces)
		tile["shape"] = shape
		tile.erase("collision_faces")
		_record_operation("shape", started)
		return false
	if not tile.has("collider"):
		var collision := StaticBody3D.new()
		# Register with physics incrementally, without becoming a floor before
		# the complete cover is ready. No ray or moving body can hit this layer.
		collision.collision_layer = 0
		collision.collision_mask = 0
		var shape_node := CollisionShape3D.new()
		shape_node.shape = tile.shape
		collision.add_child(shape_node)
		tile.node.add_child(collision)
		tile["collider"] = collision
		_record_operation("collider", started)
	return true


func _record_operation(operation: String, started: int) -> void:
	publication_operations[operation] = int(publication_operations.get(operation, 0)) + 1
	max_operation_usec[operation] = maxi(int(max_operation_usec.get(operation, 0)), Time.get_ticks_usec() - started)


func _nearest(cover: Dictionary, direction: Vector3) -> Array:
	var sorted: Array = cover.keys()
	sorted.sort_custom(func(a: String, b: String): return cover[a].direction.distance_squared_to(direction) < cover[b].direction.distance_squared_to(direction))
	return sorted.slice(0, MAX_NEAR)


func _queue_near_preparation() -> void:
	_prepared_near = _nearest(_staging, _requested_direction)
	for id: String in _prepared_near:
		if not _staging[id].has("collider") and id not in _pending: _pending.append(id)
	# A changing observer may no longer need a previously prepared collider.
	# Bound dormant physics bodies to the 24 nearest staging owners.
	for id: String in _staging:
		if id not in _prepared_near and _staging[id].has("collider") and active.get(id) != _staging[id].collider:
			_drop_collider(_staging[id])


func _drop_collider(tile: Dictionary) -> void:
	if not tile.has("collider"): return
	var collider: StaticBody3D = tile.collider
	collider.get_parent().remove_child(collider)
	collider.queue_free()
	tile.erase("collider")


func _publish() -> void:
	if _staging.is_empty():
		return
	if _staging_generation != _generation:
		discarded_publications += 1
		_request(_focus_direction)
		return
	if not leaves.is_empty() and surface.body.get("terrain_revision", 1) >= 3:
		var here: Dictionary = Cube.from_direction(surface.body.id, [_requested_direction.x, _requested_direction.y, _requested_direction.z])
		var owner: Dictionary = layout.find_at(here.face, here.u, here.v, _staging)
		if owner.is_empty() or Support.cell_width(owner.width, surface.body.radius) > Support.MAX_GROUND_CELL_METERS:
			# Do not replace the walker's prepared floor with stale coarse data.
			# Keep the old complete cover and recompute around its current point.
			publish_deferrals += 1
			_last_query_direction = _requested_direction
			_focus_direction = _requested_direction
			_generation += 1
			_request(_requested_direction)
			return
	# Movement during uploads can change the physical owners. Prepare those
	# through the same bounded queue, never build 24 bodies during handoff.
	_queue_near_preparation()
	if not _pending.is_empty(): return
	var started: int = Time.get_ticks_usec()
	var retired: Array[Dictionary] = []
	for tile: Dictionary in leaves.values():
		if not _staging.has(tile.id) or _staging[tile.id].node != tile.node:
			retired.append(tile)
	for tile: Dictionary in _staging.values():
		if tile.node.visible:
			continue
		tile.node.visible = true
		if not retired.is_empty():
			_arriving.append(tile)
	for id: String in active.keys():
		if not _staging.has(id) or active[id].get_parent() != _staging[id].node:
			_drop_collider(leaves[id])
			active.erase(id)
	leaves = _staging
	_published_generation = _staging_generation
	_staging = {}
	tiles.assign(leaves.values())
	_collision_pending.clear()
	_update_collisions(_requested_direction)
	_retired = retired
	_transition = 0.0
	_set_phase(0.0)
	for tile: Dictionary in _retired:
		tile.node.material_override = _old_land
		if tile.has("sea"):
			tile.sea.material_override = _old_water
	peak_tiles = maxi(peak_tiles, leaves.size())
	updates += 1
	if updates == 1:
		max_initial_publish_usec = Time.get_ticks_usec() - started
	else:
		max_publish_usec = maxi(max_publish_usec, Time.get_ticks_usec() - started)


func _update_collisions(direction: Vector3) -> void:
	if leaves.is_empty(): return
	_collision_direction = direction
	var wanted: Array = _nearest(leaves, direction)
	_collision_pending.clear()
	for id: String in wanted:
		if not leaves[id].has("collider"): _collision_pending.append(id)
	# Keep the current physical cover until the next neighbourhood is ready.
	for id: String in leaves:
		if id not in wanted and not active.has(id): _drop_collider(leaves[id])
	if not _collision_pending.is_empty(): return
	for id: String in active.keys():
		if id not in wanted:
			_drop_collider(leaves[id])
			active.erase(id)
	for id: String in wanted:
		if active.has(id): continue
		var collision: StaticBody3D = leaves[id].collider
		collision.collision_layer = 1
		collision.collision_mask = 1
		active[id] = collision


func pending_count() -> int:
	return _pending.size() if _job == null else -1


func streaming_diagnostics() -> Dictionary:
	return {"generation": _generation, "published_generation": _published_generation,
		"refresh_queued": _refresh_requested,
		"discarded_jobs": discarded_jobs, "discarded_publications": discarded_publications,
		"pending_uploads": _pending.size(), "pending_collisions": _collision_pending.size(), "worker_active": _job != null,
		"operations": publication_operations.duplicate(), "max_operation_usec": max_operation_usec.duplicate(),
		"lookahead_m": lookahead_direction.distance_to(_requested_direction) * float(surface.body.radius)}


func rebase(new_origin: Array) -> void:
	super.rebase(new_origin)
	for tile: Dictionary in _staging.values() + _retired:
		if tile.has("node"):
			tile.node.position = Cube.local_position(tile.anchor, origin)


func _set_phase(value: float) -> void:
	# The whole covering set advances together: four material updates per frame,
	# independent of leaf count, supported by both Forward+ and Compatibility.
	for target: ShaderMaterial in [_fade_land, _fade_water, _old_land, _old_water]:
		if target != null:
			target.set_shader_parameter("lod_phase", value)


func _finish_transition() -> void:
	for tile: Dictionary in _arriving:
		tile.node.material_override = land_material
		if tile.has("sea"):
			tile.sea.material_override = ocean_material
	_arriving.clear()
	for tile: Dictionary in _retired:
		var data: Dictionary = {"mesh": tile.mesh, "water": tile.water, "anchor": tile.anchor}
		if tile.has("shape"):
			data["shape"] = tile.shape
		elif tile.has("collision_faces"):
			data["collision_faces"] = tile.collision_faces
		_cache[PatchJob.variant_key(tile)] = data
		remove_child(tile.node)
		tile.node.queue_free()
	_retired.clear()
	_trim_cache()


func _trim_cache() -> void:
	var resident: int = leaves.size() + _retired.size()
	for tile: Dictionary in _staging.values():
		if tile.has("mesh") and (not leaves.has(tile.id) or leaves[tile.id].get("node") != tile.get("node")):
			resident += 1
	while not _cache.is_empty() and (_cache.size() > MAX_CACHED or resident + _cache.size() > MAX_RESIDENT):
		_cache.erase(_cache.keys()[0])
	peak_resident_meshes = maxi(peak_resident_meshes, resident + _cache.size())


func _discard_staging() -> void:
	for tile: Dictionary in _staging.values():
		if tile.has("node") and (not leaves.has(tile.id) or leaves[tile.id].node != tile.node):
			remove_child(tile.node)
			tile.node.queue_free()
		elif tile.has("collider") and active.get(tile.id) != tile.collider:
			_drop_collider(tile)
	_staging.clear()
	_pending.clear()


func ground_ready(point: Array) -> bool:
	if surface == null or layout == null or point.size() != 3: return false
	var length_squared: float = 0.0
	for component in point:
		if not (component is int or component is float) or not is_finite(float(component)): return false
		length_squared += float(component) * float(component)
	if not is_finite(length_squared) or length_squared < 1.0: return false
	var address: Dictionary = Cube.from_cartesian(surface.body.id, point, surface.body.radius)
	var owner: Dictionary = layout.find_at(address.face, address.u, address.v, leaves)
	if owner.is_empty() or Support.cell_width(owner.width, surface.body.radius) > Support.MAX_GROUND_CELL_METERS: return false
	# Fine rendered geometry alone is not a physical floor. Only the currently
	# attached owner can release movement, arrival or population placement.
	var collider: StaticBody3D = active.get(owner.id)
	if not is_instance_valid(collider) or not collider.is_inside_tree() or collider.is_queued_for_deletion() or collider.get_parent() != owner.get("node") or collider.collision_layer & 1 == 0: return false
	for child in collider.get_children():
		if child is CollisionShape3D and not child.disabled and child.shape != null: return true
	return false


func _exit_tree() -> void:
	# A worker owns no scene nodes/resources. Join before releasing its inputs;
	# body switches and quitting while generating must not leave live jobs.
	if _job != null:
		_job.join()
	_job = null
	_staging.clear()
	_pending.clear()
	_collision_pending.clear()
	_cache.clear()
	_retired.clear()
	_arriving.clear()
