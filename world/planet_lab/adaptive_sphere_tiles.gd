extends "res://world/planet_lab/sphere_tiles.gd"
class_name AdaptiveSphereTiles

const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const PatchMesh = preload("res://world/planet_lab/planet_patch_mesh.gd")
const PatchJob = preload("res://world/planet_lab/planet_patch_job.gd")
const BUILDS_PER_FRAME: int = 2
const BUILD_BUDGET_USEC: int = 4000
const MAX_CACHED: int = 256
const MAX_RESIDENT: int = 1536
const TRANSITION_SECONDS: float = 0.18
var layout: RefCounted
var leaves: Dictionary = {}
var _staging: Dictionary = {}
var _pending: Array[String] = []
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
	if force or (_job == null and _pending.is_empty() and _retired.is_empty() and direction.distance_to(_last_query_direction) * float(surface.body.radius) >= 8.0):
		_last_query_direction = direction
		_request(direction if force or lookahead_direction == Vector3.ZERO else lookahead_direction)
	if force:
		_job.advance(true)
		_collect_job()
		while not _pending.is_empty():
			_build_next()
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
	_staging = {}
	_pending.clear()
	_job = PatchJob.new()
	_job.body = surface.body.duplicate(true)
	_job.direction = direction
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
	_prepared_near = _staging.keys()
	_prepared_near.sort_custom(func(a: String, b: String): return _staging[a].direction.distance_squared_to(_requested_direction) < _staging[b].direction.distance_squared_to(_requested_direction))
	_prepared_near = _prepared_near.slice(0, MAX_NEAR)
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
		if _transition >= 1.0:
			_finish_transition()
	if _job != null:
		if not _job.advance():
			return
		_collect_job()
	var started: int = Time.get_ticks_usec()
	while not _pending.is_empty() and last_build_count < BUILDS_PER_FRAME:
		_build_next()
		last_build_count += 1
		if Time.get_ticks_usec() - started >= BUILD_BUDGET_USEC:
			break
	if last_build_count > 0:
		var elapsed: int = Time.get_ticks_usec() - started
		max_build_usec = maxi(max_build_usec, elapsed)
		if upload_samples.size() < 2048:
			upload_samples.append(elapsed / 1000.0)
		if _pending.is_empty():
			_publish()


func _build_next() -> void:
	var started: int = Time.get_ticks_usec()
	var id: String = _pending.pop_back()
	var tile: Dictionary = _staging[id]
	if not tile.has("mesh"):
		tile.merge(PatchMesh.upload(tile.arrays))
		tile.erase("arrays")
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
	if id in _prepared_near and not tile.has("shape"):
		tile["shape"] = _collision_shape(tile.mesh)
	max_prepare_usec = maxi(max_prepare_usec, Time.get_ticks_usec() - started)
	_trim_cache()


func _publish() -> void:
	if _staging.is_empty():
		return
	if not leaves.is_empty() and surface.body.get("terrain_revision", 1) >= 3:
		var here: Dictionary = Cube.from_direction(surface.body.id, [_requested_direction.x, _requested_direction.y, _requested_direction.z])
		var owner: Dictionary = layout.find_at(here.face, here.u, here.v, _staging)
		if owner.is_empty() or owner.width * surface.body.radius / PatchMesh.CELLS > 4.0:
			# Do not replace the walker's prepared floor with stale coarse data.
			# Keep the old complete cover and recompute around its current point.
			publish_deferrals += 1
			_last_query_direction = _requested_direction
			_request(_requested_direction)
			return
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
	leaves = _staging
	_staging = {}
	tiles.assign(leaves.values())
	# Rebuild changed physical owners before retiring old surfaces. There is
	# always a complete rendered covering set and collision under the walker.
	for id: String in active.keys():
		if not leaves.has(id) or active[id].get_parent() != leaves[id].node:
			active[id].get_parent().remove_child(active[id])
			active[id].queue_free()
			active.erase(id)
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
	if leaves.is_empty():
		return
	_collision_direction = direction
	var sorted: Array = leaves.keys()
	# Dot products round to 1 for thousands of distinct nearby points at Earth
	# radius. Subtract first so ordering retains their small angular distances.
	sorted.sort_custom(func(a: String, b: String): return leaves[a].direction.distance_squared_to(direction) < leaves[b].direction.distance_squared_to(direction))
	var wanted: Array = sorted.slice(0, MAX_NEAR)
	for id: String in active.keys():
		if id not in wanted:
			active[id].get_parent().remove_child(active[id])
			active[id].queue_free()
			active.erase(id)
	for id: String in wanted:
		if active.has(id):
			continue
		var collision := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		if not leaves[id].has("shape"):
			leaves[id]["shape"] = _collision_shape(leaves[id].mesh)
		shape.shape = leaves[id].shape
		collision.add_child(shape)
		leaves[id].node.add_child(collision)
		active[id] = collision


func pending_count() -> int:
	return _pending.size() if _job == null else -1


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
	_staging.clear()
	_pending.clear()


func ground_ready(point: Array) -> bool:
	var address: Dictionary = Cube.from_cartesian(surface.body.id, point, surface.body.radius)
	var owner: Dictionary = layout.find_at(address.face, address.u, address.v, leaves)
	return not owner.is_empty() and float(owner.width) * float(surface.body.radius) / PatchMesh.CELLS <= 4.0


func _collision_shape(mesh: ArrayMesh) -> ConcavePolygonShape3D:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	if vertices.size() <= 289:
		return super._collision_shape(mesh)
	# Flat voxel faces duplicate vertices. Exact rays can miss their internal
	# joins after independent float transforms as well as outer tile seams.
	# Overlap each physical triangle by at most half a millimetre in its own
	# plane; visual geometry and the radial ground height remain unchanged.
	var faces := PackedVector3Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		var center: Vector3 = (vertices[indices[i]] + vertices[indices[i + 1]] + vertices[indices[i + 2]]) / 3.0
		for corner in range(3):
			var point: Vector3 = vertices[indices[i + corner]]
			faces.append(point + (point - center).normalized() * COLLISION_EDGE_GUARD)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	return shape


func _exit_tree() -> void:
	# A worker owns no scene nodes/resources. Join before releasing its inputs;
	# body switches and quitting while generating must not leave live jobs.
	if _job != null:
		_job.join()
	_job = null
	_staging.clear()
	_pending.clear()
	_cache.clear()
	_retired.clear()
	_arriving.clear()
