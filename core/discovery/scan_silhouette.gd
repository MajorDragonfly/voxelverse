extends RefCounted
## Read the rendered meshes, including animated voxel batches. Never use a
## movement capsule as evidence that a visible part of an animal is in the ring.
var _nodes: Dictionary = {}
var _faces: Dictionary = {}
var _mesh_order: Array[int] = []
var _static_batches: Dictionary = {}
const MESH_CACHE_LIMIT := 32

func contacts(camera: Camera3D, candidate: Node3D, circle: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pixels: Dictionary = {}
	for reference: WeakRef in _visual_nodes(candidate):
		var node: Node3D = reference.get_ref()
		if not is_instance_valid(node) or not node.is_visible_in_tree(): continue
		if node is MeshInstance3D and node.mesh != null:
			_mesh_contacts(camera, node.mesh, node.global_transform, circle, result, pixels)
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			var batch: MultiMesh = node.multimesh
			# Runtime pose changes individual transforms. Its static custom_aabb
			# is a renderer bound, not proof that an animated foot/lid is absent.
			var count: int = batch.instance_count if batch.visible_instance_count < 0 else batch.visible_instance_count
			var transforms: Array[Transform3D] = _batch_transforms(node, count)
			var bounds: AABB
			for index in range(count):
				var instance: Transform3D = transforms[index]
				var part_bounds: AABB = instance * batch.mesh.get_aabb()
				bounds = part_bounds if index == 0 else bounds.merge(part_bounds)
			if count == 0 or not _overlaps(camera, node.global_transform * bounds, circle): continue
			for index in range(count):
				_mesh_contacts(camera, batch.mesh, node.global_transform * transforms[index], circle, result, pixels)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.depth < b.depth if is_equal_approx(a.score, b.score) else a.score < b.score)
	return result

func _batch_transforms(node: MultiMeshInstance3D, count: int) -> Array[Transform3D]:
	var batch: MultiMesh = node.multimesh
	var identity: int = batch.get_instance_id()
	# RuntimeVoxelBatch is authored once in creature_runtime_preview.rebuild;
	# locomotion moves its parent nodes. Lids have changing per-instance poses.
	for key: int in _static_batches.keys():
		if not is_instance_valid(_static_batches[key].owner.get_ref()): _static_batches.erase(key)
	if node.name == "RuntimeVoxelBatch" and _static_batches.has(identity): return _static_batches[identity].transforms
	# One bulk read per changing batch, rather than a RenderingServer round trip
	# for every voxel. Godot stores three matrix rows then color/custom payloads.
	var buffer: PackedFloat32Array = batch.buffer
	var stride: int = 12 + (4 if batch.use_colors else 0) + (4 if batch.use_custom_data else 0)
	var result: Array[Transform3D] = []
	for index in range(count):
		var offset: int = index * stride
		result.append(Transform3D(Basis(Vector3(buffer[offset], buffer[offset + 4], buffer[offset + 8]),
			Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]), Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10])),
			Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11])))
	if node.name == "RuntimeVoxelBatch": _static_batches[identity] = {"owner": weakref(batch), "transforms": result}
	return result

func _visual_nodes(candidate: Node3D) -> Array[WeakRef]:
	# Cache only weak node references; unloading a colony cannot keep it alive.
	for identity: int in _nodes.keys():
		if not is_instance_valid(_nodes[identity].owner.get_ref()): _nodes.erase(identity)
	var identity: int = candidate.get_instance_id()
	if _nodes.has(identity):
		var cached: Array[WeakRef] = _nodes[identity].nodes
		var valid: bool = not cached.is_empty()
		for reference: WeakRef in cached:
			if not is_instance_valid(reference.get_ref()): valid = false; break
		if valid: return cached
	var nodes: Array[WeakRef] = []
	_collect(candidate.get_node_or_null("SpeciesVisual") if candidate.has_node("SpeciesVisual") else candidate, nodes)
	_nodes[identity] = {"owner": weakref(candidate), "nodes": nodes}
	return nodes

func _collect(node: Node, nodes: Array[WeakRef]) -> void:
	if node.has_meta("editor_guide"): return
	if node is MeshInstance3D or node is MultiMeshInstance3D: nodes.append(weakref(node))
	for child: Node in node.get_children(): _collect(child, nodes)

func _mesh_contacts(camera: Camera3D, mesh: Mesh, transform: Transform3D, circle: Dictionary,
		result: Array[Dictionary], pixels: Dictionary) -> void:
	if not _overlaps(camera, transform * mesh.get_aabb(), circle): return
	var faces: PackedVector3Array = _mesh_faces(mesh)
	for index in range(0, faces.size(), 3):
		var a: Vector3 = transform * faces[index]
		var b: Vector3 = transform * faces[index + 1]
		var c: Vector3 = transform * faces[index + 2]
		if camera.is_position_behind(a) or camera.is_position_behind(b) or camera.is_position_behind(c): continue
		var screen_a: Vector2 = camera.unproject_position(a)
		var screen_b: Vector2 = camera.unproject_position(b)
		var screen_c: Vector2 = camera.unproject_position(c)
		var pixel: Vector2 = _closest_triangle(circle.center, screen_a, screen_b, screen_c)
		var distance: float = pixel.distance_to(circle.center)
		if distance > float(circle.radius): continue
		# Move off a triangle edge while staying inside the actual disc, so the
		# physics visibility probe is robust even for less than one pixel overlap.
		var centroid: Vector2 = (screen_a + screen_b + screen_c) / 3.0
		var inset: float = minf(0.15, maxf(float(circle.radius) - distance, 0.0) * 0.25)
		if pixel.distance_to(centroid) > 0.001: pixel = pixel.move_toward(centroid, inset)
		var point: Variant = Geometry3D.ray_intersects_triangle(camera.project_ray_origin(pixel), camera.project_ray_normal(pixel), a, b, c)
		if point == null: continue
		var key := Vector2i(roundi(pixel.x * 4), roundi(pixel.y * 4))
		var depth: float = camera.global_position.distance_to(point)
		if pixels.has(key):
			var existing: Dictionary = pixels[key]
			if depth < float(existing.depth): existing.point = point; existing.depth = depth
			continue
		var contact := {"pixel": pixel, "point": point, "depth": depth, "score": pixel.distance_to(circle.center) / float(circle.radius)}
		pixels[key] = contact
		result.append(contact)

func _mesh_faces(mesh: Mesh) -> PackedVector3Array:
	var identity: int = mesh.get_instance_id()
	if not _faces.has(identity):
		_faces[identity] = {"mesh": mesh, "faces": mesh.get_faces()}
		_mesh_order.append(identity)
		if _mesh_order.size() > MESH_CACHE_LIMIT: _faces.erase(_mesh_order.pop_front())
	return _faces[identity].faces

func _overlaps(camera: Camera3D, bounds: AABB, circle: Dictionary) -> bool:
	var rect: Rect2
	for index in range(8):
		var corner: Vector3 = bounds.get_endpoint(index)
		if camera.is_position_behind(corner): return true
		var pixel: Vector2 = camera.unproject_position(corner)
		rect = Rect2(pixel, Vector2.ZERO) if index == 0 else rect.expand(pixel)
	var nearest := Vector2(clampf(circle.center.x, rect.position.x, rect.end.x), clampf(circle.center.y, rect.position.y, rect.end.y))
	return nearest.distance_squared_to(circle.center) <= float(circle.radius) * float(circle.radius)

static func _closest_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var cross_a: float = (b - a).cross(point - a)
	var cross_b: float = (c - b).cross(point - b)
	var cross_c: float = (a - c).cross(point - c)
	var area: float = (b - a).cross(c - a)
	if absf(area) > 0.000001 and ((cross_a >= 0 and cross_b >= 0 and cross_c >= 0) or (cross_a <= 0 and cross_b <= 0 and cross_c <= 0)): return point
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, a, b)
	for edge: Vector2 in [Geometry2D.get_closest_point_to_segment(point, b, c), Geometry2D.get_closest_point_to_segment(point, c, a)]:
		if point.distance_squared_to(edge) < point.distance_squared_to(closest): closest = edge
	return closest
