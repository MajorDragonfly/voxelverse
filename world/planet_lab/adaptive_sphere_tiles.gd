extends "res://world/planet_lab/sphere_tiles.gd"
class_name AdaptiveSphereTiles

const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const PatchMesh = preload("res://world/planet_lab/planet_patch_mesh.gd")
const PatchJob = preload("res://world/planet_lab/planet_patch_job.gd")
const BUILDS_PER_FRAME: int = 2
const BUILD_BUDGET_USEC: int = 4000
var layout: RefCounted
var leaves: Dictionary = {}
var _staging: Dictionary = {}
var _pending: Array[String] = []
var _requested_direction: Vector3 = Vector3.ZERO
var _collision_direction: Vector3 = Vector3.ZERO
var ocean_material: StandardMaterial3D
var peak_tiles: int = 0
var peak_resident_meshes: int = 0
var max_build_usec: int = 0
var updates: int = 0
var last_build_count: int = 0
var _task: int = -1
var _job: RefCounted
var max_worker_usec: int = 0
var max_publish_usec: int = 0
var max_initial_publish_usec: int = 0
var upload_samples: Array[float] = []
var lookahead_direction: Vector3 = Vector3.ZERO
var job_samples: Array[Dictionary] = []


func configure(descriptor: Dictionary) -> void:
	surface = Surface.new(descriptor)
	layout = Layout.new(float(descriptor.radius))
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	ocean_material = StandardMaterial3D.new()
	ocean_material.albedo_color = Color("247c9d")
	ocean_material.roughness = 0.9
	ocean_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Water uses the same adaptive curved patches as land. A fixed low-poly
	# SphereMesh would sink metres below the buoyancy surface on a large body.


func stream_at(direction: Vector3, force: bool = false) -> void:
	_requested_direction = direction
	if force or (_task < 0 and _pending.is_empty() and direction.distance_to(_last_direction) * float(surface.body.radius) >= 8.0):
		_request(direction if force or lookahead_direction == Vector3.ZERO else lookahead_direction)
	if force:
		_collect_job()
		while not _pending.is_empty():
			_build_next()
		_publish()
	if direction.distance_to(_collision_direction) * float(surface.body.radius) >= 4.0 or force:
		_update_collisions(direction)


func _request(direction: Vector3) -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_last_direction = direction
	_staging = {}
	_pending.clear()
	_job = PatchJob.new()
	_job.body = surface.body.duplicate(true)
	_job.direction = direction
	for id: String in leaves:
		_job.previous_masks[id] = leaves[id].mask
	_task = WorkerThreadPool.add_task(_job.run, false, "Adaptive planet patches")


func _collect_job() -> void:
	if _task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_staging = _job.result
	max_worker_usec = maxi(max_worker_usec, _job.duration_usec)
	if job_samples.size() < 256:
		job_samples.append({"worker_ms": _job.duration_usec / 1000.0, "tiles": _staging.size()})
	_job = null
	for id: String in _staging:
		var tile: Dictionary = _staging[id]
		if leaves.has(id) and leaves[id].mask == tile.mask:
			_staging[id] = leaves[id]
		else:
			_pending.append(id)
	_pending.sort_custom(func(a: String, b: String): return _staging[a].direction.distance_squared_to(_last_direction) > _staging[b].direction.distance_squared_to(_last_direction))
	if not job_samples.is_empty():
		job_samples[-1]["uploads"] = _pending.size()
	if _pending.is_empty():
		_publish()


func _process(_delta: float) -> void:
	last_build_count = 0
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
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
	var id: String = _pending.pop_back()
	var tile: Dictionary = _staging[id]
	var built: Dictionary = PatchMesh.upload(tile.arrays)
	tile.erase("arrays")
	tile.merge(built)
	# Count terrain meshes; water adds at most one mesh per terrain patch.
	var resident: int = leaves.size()
	for staged: Dictionary in _staging.values():
		if staged.has("mesh") and not staged.has("node"):
			resident += 1
	peak_resident_meshes = maxi(peak_resident_meshes, resident)


func _publish() -> void:
	if _staging.is_empty():
		return
	var started: int = Time.get_ticks_usec()
	var retired: Array[Node] = []
	for tile: Dictionary in leaves.values():
		if not _staging.has(tile.id) or not _staging[tile.id].has("node"):
			retired.append(tile.node)
	for tile: Dictionary in _staging.values():
		if tile.has("node"):
			continue
		var node := MeshInstance3D.new()
		node.name = "Patch_" + str(tile.id).replace("/", "_")
		node.mesh = tile.mesh
		node.material_override = material
		node.position = Cube.local_position(tile.anchor, origin)
		add_child(node)
		tile["node"] = node
		if tile.water != null:
			var sea := MeshInstance3D.new()
			sea.mesh = tile.water
			sea.material_override = ocean_material
			sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(sea)
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
	for node: Node in retired:
		remove_child(node)
		node.queue_free()
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
		shape.shape = _collision_shape(leaves[id].mesh)
		collision.add_child(shape)
		leaves[id].node.add_child(collision)
		active[id] = collision


func pending_count() -> int:
	return _pending.size() if _task < 0 else -1


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
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_job = null
	_staging.clear()
	_pending.clear()
