extends RefCounted
## Read the rendered meshes, including animated voxel batches. Never use a
## movement capsule as evidence that a visible part of an animal is in the ring.
var _nodes: Dictionary = {}
var _faces: Dictionary = {}
var _mesh_order: Array[int] = []
var _static_batches: Dictionary = {}
var _batch_layouts: Dictionary = {}
var _projection := Projection()
var _view_size := Vector2.ONE
var _accepted: Dictionary = {}
const MESH_CACHE_LIMIT := 512
const NODE_CACHE_LIMIT := 512
const BATCH_CACHE_LIMIT := 512
var _query_active := false
var _query_parts: Dictionary = {}
var _query_layouts: Dictionary = {}

func begin_query(camera: Camera3D) -> void:
	# A synchronous query has one pose. Retain geometry/transforms only until
	# end_query, never a visibility decision or a hit across camera/pose changes.
	end_query()
	_prune_caches()
	_query_active = true
	prepare_projection(camera)

func end_query() -> void:
	_query_active = false
	_query_parts.clear()
	_query_layouts.clear()
	# The scanner annotates a returned fallback contact with its actor. Drop
	# our dictionary reference without mutating the caller's returned contact.
	_accepted = {}

func _prune_caches() -> void:
	for identity: int in _nodes.keys():
		if not is_instance_valid(_nodes[identity].owner.get_ref()): _nodes.erase(identity)
	for identity: int in _static_batches.keys():
		if not is_instance_valid(_static_batches[identity].owner.get_ref()):
			_static_batches.erase(identity)
			_batch_layouts.erase(identity)
	for identity: int in _faces.keys():
		if not is_instance_valid(_faces[identity].mesh.get_ref()):
			_faces.erase(identity)
			_mesh_order.erase(identity)

func cache_sizes() -> Dictionary:
	return {"nodes": _nodes.size(), "meshes": _faces.size(), "batches": _static_batches.size(),
		"query_parts": _query_parts.size(), "query_layouts": _query_layouts.size()}

func contacts(camera: Camera3D, candidate: Node3D, circle: Dictionary, accept: Callable = Callable()) -> Array[Dictionary]:
	prepare_projection(camera)
	_accepted = {}
	var result: Array[Dictionary] = []
	var pixels: Dictionary = {}
	for reference: WeakRef in _visual_nodes(candidate):
		var node: Node3D = reference.get_ref()
		if not is_instance_valid(node) or not node.is_visible_in_tree(): continue
		if node is MeshInstance3D and node.mesh != null:
			if _mesh_contacts(camera, node.mesh, node.global_transform, circle, result, pixels, accept): return _accepted_contacts()
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			var batch: MultiMesh = node.multimesh
			var mesh: Mesh = batch.mesh
			# Runtime pose changes individual transforms. Its static custom_aabb
			# is a renderer bound, not proof that an animated foot/lid is absent.
			var count: int = batch.instance_count if batch.visible_instance_count < 0 else batch.visible_instance_count
			if count == 0: continue
			var layout: Dictionary = _batch_layout(node, count, mesh)
			if not _overlaps(camera, node.global_transform * layout.bounds, circle): continue
			if layout.tree.is_empty():
				for index in range(count):
					if _mesh_contacts(camera, mesh, node.global_transform * layout.transforms[index], circle, result, pixels, accept): return _accepted_contacts()
			else:
				if _batch_tree_contacts(camera, mesh, layout, layout.tree.size() - 1, node.global_transform, circle, result, pixels, accept): return _accepted_contacts()
	if accept.is_valid(): return []
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.depth < b.depth if is_equal_approx(a.score, b.score) else a.score < b.score)
	return result

func _accepted_contacts() -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	if not _accepted.is_empty(): selected.append(_accepted)
	return selected

func occludes(camera: Camera3D, candidate: Node3D, pixel: Vector2, point: Vector3) -> bool:
	# This is an exact pixel ray, not another projected-disc search. Reuse the
	# existing local BVHs and native segment/AABB tests; do not overwrite the
	# outer contact/marker or project every foreign triangle for each surface.
	var origin: Vector3 = camera.project_ray_origin(pixel)
	var finish: Vector3 = point - camera.project_ray_normal(pixel) * 0.0001
	var visual: Dictionary = _ray_parts(candidate)
	if visual.parts.is_empty() or visual.bounds.intersects_segment(origin, finish) == null: return false
	for part: Dictionary in visual.parts:
		var start: Vector3 = part.inverse * origin
		var end: Vector3 = part.inverse * finish
		if part.bounds.intersects_segment(start, end) == null: continue
		if not part.has("layout"):
			if _ray_local(part.mesh, start, end): return true
		elif part.layout.tree.is_empty():
			for index in range(part.layout.count):
				if _ray_local(part.mesh, part.layout.inverses[index] * start, part.layout.inverses[index] * end): return true
		elif _ray_instances(part.mesh, part.layout, part.layout.tree.size() - 1, start, end): return true
	return false

func _ray_parts(candidate: Node3D) -> Dictionary:
	var identity: int = candidate.get_instance_id()
	if _query_active and _query_parts.has(identity): return _query_parts[identity]
	var parts: Array[Dictionary] = []
	var bounds: AABB
	for reference: WeakRef in _visual_nodes(candidate):
		var node: Node3D = reference.get_ref()
		if not is_instance_valid(node) or not node.is_visible_in_tree(): continue
		var part: Dictionary
		if node is MeshInstance3D and node.mesh != null:
			part = {"mesh": node.mesh, "bounds": node.mesh.get_aabb()}
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			var batch: MultiMesh = node.multimesh
			var count: int = batch.instance_count if batch.visible_instance_count < 0 else batch.visible_instance_count
			if count == 0: continue
			var layout: Dictionary = _batch_layout(node, count, batch.mesh)
			part = {"mesh": batch.mesh, "bounds": layout.bounds, "layout": layout}
		else: continue
		var transform: Transform3D = node.global_transform
		part.inverse = transform.affine_inverse()
		var world: AABB = transform * part.bounds
		bounds = world if parts.is_empty() else bounds.merge(world)
		parts.append(part)
	var visual := {"parts": parts, "bounds": bounds}
	if _query_active: _query_parts[identity] = visual
	return visual

func _ray_instances(mesh: Mesh, layout: Dictionary, index: int, start: Vector3, end: Vector3) -> bool:
	var node: Dictionary = layout.tree[index]
	if node.bounds.intersects_segment(start, end) == null: return false
	if node.has("triangles"):
		for instance: int in node.triangles:
			if _ray_local(mesh, layout.inverses[instance] * start, layout.inverses[instance] * end): return true
		return false
	return _ray_instances(mesh, layout, node.left, start, end) or _ray_instances(mesh, layout, node.right, start, end)

func _ray_mesh(mesh: Mesh, transform: Transform3D, origin: Vector3, finish: Vector3) -> bool:
	var inverse: Transform3D = transform.affine_inverse()
	var start: Vector3 = inverse * origin
	var end: Vector3 = inverse * finish
	return _ray_local(mesh, start, end)

func _ray_local(mesh: Mesh, start: Vector3, end: Vector3) -> bool:
	return not _ray_hit(mesh, start, end).is_empty()

func _ray_hit(mesh: Mesh, start: Vector3, end: Vector3) -> Dictionary:
	if mesh.get_aabb().intersects_segment(start, end) == null: return {}
	var geometry: Dictionary = _cached_geometry(mesh)
	# Godot 4.6 exposes the native triangle BVH. Build once per cached mesh,
	# retaining exact visible triangles without GDScript traversal per pixel.
	if not geometry.has("ray_mesh"):
		geometry.ray_mesh = mesh.generate_triangle_mesh()
	var ray_mesh: TriangleMesh = geometry.ray_mesh
	return ray_mesh.intersect_segment(start, end) if ray_mesh != null else {}

func ray_contact(camera: Camera3D, candidate: Node3D, pixel: Vector2, circle: Dictionary) -> Dictionary:
	# A bounded fast path confirms real surfaces at a few points inside the
	# disc. A miss never rejects a silhouette: the full edge search still runs.
	if pixel.distance_squared_to(circle.center) > float(circle.radius) * float(circle.radius): return {}
	var visual: Dictionary = _ray_parts(candidate)
	if visual.parts.is_empty(): return {}
	var origin: Vector3 = camera.project_ray_origin(pixel)
	var finish: Vector3 = origin + camera.project_ray_normal(pixel) * (origin.distance_to(visual.bounds.get_center()) + visual.bounds.size.length())
	if visual.bounds.intersects_segment(origin, finish) == null: return {}
	for part: Dictionary in visual.parts:
		var start: Vector3 = part.inverse * origin
		var end: Vector3 = part.inverse * finish
		if part.bounds.intersects_segment(start, end) == null: continue
		var hit: Dictionary
		if not part.has("layout"):
			hit = _ray_hit(part.mesh, start, end)
		elif part.layout.tree.is_empty():
			for index in range(part.layout.count):
				hit = _ray_hit(part.mesh, part.layout.inverses[index] * start, part.layout.inverses[index] * end)
				if not hit.is_empty(): hit.position = part.layout.transforms[index] * hit.position; break
		else: hit = _ray_instances_hit(part.mesh, part.layout, part.layout.tree.size() - 1, start, end)
		if hit.is_empty(): continue
		var point: Vector3 = part.inverse.affine_inverse() * hit.position
		return {"point": point, "pixel": pixel, "depth": origin.distance_to(point), "score": pixel.distance_to(circle.center) / float(circle.radius)}
	return {}

func _ray_instances_hit(mesh: Mesh, layout: Dictionary, index: int, start: Vector3, end: Vector3) -> Dictionary:
	var node: Dictionary = layout.tree[index]
	if node.bounds.intersects_segment(start, end) == null: return {}
	if node.has("triangles"):
		for instance: int in node.triangles:
			var hit: Dictionary = _ray_hit(mesh, layout.inverses[instance] * start, layout.inverses[instance] * end)
			if not hit.is_empty():
				hit.position = layout.transforms[instance] * hit.position
				return hit
		return {}
	var left: Dictionary = _ray_instances_hit(mesh, layout, node.left, start, end)
	return left if not left.is_empty() else _ray_instances_hit(mesh, layout, node.right, start, end)

func _batch_layout(node: MultiMeshInstance3D, count: int, mesh: Mesh) -> Dictionary:
	var identity: int = node.multimesh.get_instance_id()
	if _query_active and _query_layouts.has(identity): return _query_layouts[identity]
	if node.name == "RuntimeVoxelBatch" and _batch_layouts.has(identity) and _batch_layouts[identity].count == count and _batch_layouts[identity].mesh_id == mesh.get_instance_id():
		if _query_active: _query_layouts[identity] = _batch_layouts[identity]
		return _batch_layouts[identity]
	var transforms: Array[Transform3D] = _batch_transforms(node, count)
	var inverses: Array[Transform3D] = []
	var mesh_bounds: AABB = _mesh_bounds(mesh)
	var bounds: AABB
	var boxes := PackedVector3Array()
	if count > 128: boxes.resize(count * 3)
	for index in range(count):
		inverses.append(transforms[index].affine_inverse())
		var part_bounds: AABB = transforms[index] * mesh_bounds
		bounds = part_bounds if index == 0 else bounds.merge(part_bounds)
		if count > 128:
			boxes[index * 3] = part_bounds.position
			boxes[index * 3 + 1] = part_bounds.end
			boxes[index * 3 + 2] = part_bounds.get_center()
	var layout := {"transforms": transforms, "inverses": inverses, "bounds": bounds,
		"tree": _build_tree(boxes, bounds), "count": count, "mesh_id": mesh.get_instance_id()}
	if node.name == "RuntimeVoxelBatch": _batch_layouts[identity] = layout
	if _query_active: _query_layouts[identity] = layout
	return layout

func _batch_tree_contacts(camera: Camera3D, mesh: Mesh, layout: Dictionary, index: int, transform: Transform3D,
		circle: Dictionary, result: Array[Dictionary], pixels: Dictionary, accept: Callable = Callable()) -> bool:
	var node: Dictionary = layout.tree[index]
	if not _overlaps(camera, transform * node.bounds, circle): return false
	if node.has("triangles"):
		for instance: int in node.triangles:
			if _mesh_contacts(camera, mesh, transform * layout.transforms[instance], circle, result, pixels, accept): return true
	else:
		if _batch_tree_contacts(camera, mesh, layout, node.left, transform, circle, result, pixels, accept): return true
		if _batch_tree_contacts(camera, mesh, layout, node.right, transform, circle, result, pixels, accept): return true
	return false

func prepare_projection(camera: Camera3D) -> void:
	_projection = camera.get_camera_projection() * Projection(camera.get_camera_transform().affine_inverse())
	_view_size = camera.get_viewport().get_visible_rect().size

func project(point: Vector3) -> Vector2:
	# Freeze the camera/viewport matrix once per query. Calling unproject_position
	# for every triangle repeatedly re-reads native viewport/projection state.
	var clip: Vector4 = _projection * Vector4(point.x, point.y, point.z, 1.0)
	return Vector2((clip.x / clip.w + 1.0) * _view_size.x * 0.5, (1.0 - clip.y / clip.w) * _view_size.y * 0.5)

func _batch_transforms(node: MultiMeshInstance3D, count: int) -> Array[Transform3D]:
	var batch: MultiMesh = node.multimesh
	var identity: int = batch.get_instance_id()
	# RuntimeVoxelBatch is authored once in creature_runtime_preview.rebuild;
	# locomotion moves its parent nodes. Lids have changing per-instance poses.
	if not _query_active: _prune_caches()
	if node.name == "RuntimeVoxelBatch" and _static_batches.has(identity) and _static_batches[identity].count == count: return _static_batches[identity].transforms
	# One bulk read per changing batch, rather than a RenderingServer round trip
	# for every voxel. Godot stores three matrix rows then color/custom payloads.
	var buffer := PackedFloat32Array()
	# EyeExpression already retains the exact CPU pose uploaded this frame.
	# Read that existing contract rather than forcing a GPU buffer readback.
	for eye: Dictionary in node.get_parent().get_meta("eye_expression_sockets", []):
		if eye.upper == node: buffer = eye.upper_buffer; break
		if eye.lower == node: buffer = eye.lower_buffer; break
	if buffer.is_empty(): buffer = batch.buffer
	var stride: int = 12 + (4 if batch.use_colors else 0) + (4 if batch.use_custom_data else 0)
	var result: Array[Transform3D] = []
	for index in range(count):
		var offset: int = index * stride
		result.append(Transform3D(Basis(Vector3(buffer[offset], buffer[offset + 4], buffer[offset + 8]),
			Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]), Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10])),
			Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11])))
	if node.name == "RuntimeVoxelBatch":
		if not _static_batches.has(identity) and _static_batches.size() >= BATCH_CACHE_LIMIT:
			var oldest: int = _static_batches.keys().front()
			_static_batches.erase(oldest); _batch_layouts.erase(oldest)
		_static_batches[identity] = {"owner": weakref(batch), "transforms": result, "count": count}
	return result

func _visual_nodes(candidate: Node3D) -> Array[WeakRef]:
	# Cache only weak node references; unloading a colony cannot keep it alive.
	if not _query_active: _prune_caches()
	var identity: int = candidate.get_instance_id()
	if _nodes.has(identity):
		var cached: Array[WeakRef] = _nodes[identity].nodes
		var valid: bool = not cached.is_empty()
		for reference: WeakRef in cached:
			if not is_instance_valid(reference.get_ref()): valid = false; break
		if valid: return cached
	var nodes: Array[WeakRef] = []
	_collect(candidate.get_node_or_null("SpeciesVisual") if candidate.has_node("SpeciesVisual") else candidate, nodes)
	if not _nodes.has(identity) and _nodes.size() >= NODE_CACHE_LIMIT: _nodes.erase(_nodes.keys().front())
	_nodes[identity] = {"owner": weakref(candidate), "nodes": nodes}
	return nodes

func _collect(node: Node, nodes: Array[WeakRef]) -> void:
	if node.has_meta("editor_guide"): return
	if node is MeshInstance3D or node is MultiMeshInstance3D: nodes.append(weakref(node))
	for child: Node in node.get_children(): _collect(child, nodes)

func _mesh_contacts(camera: Camera3D, mesh: Mesh, transform: Transform3D, circle: Dictionary,
		result: Array[Dictionary], pixels: Dictionary, accept: Callable = Callable()) -> bool:
	var geometry: Dictionary = _mesh_geometry(mesh)
	if not _overlaps(camera, transform * geometry.bounds, circle): return false
	var faces: PackedVector3Array = geometry.faces
	var tree: Array[Dictionary] = geometry.tree
	if tree.is_empty():
		for index in range(0, faces.size(), 3):
			if _triangle_contact(camera, faces, index, transform, circle, result, pixels, accept): return true
	else:
		return _tree_contacts(camera, faces, tree, tree.size() - 1, transform, circle, result, pixels, accept)
	return false

func _tree_contacts(camera: Camera3D, faces: PackedVector3Array, tree: Array[Dictionary], index: int,
		transform: Transform3D, circle: Dictionary, result: Array[Dictionary], pixels: Dictionary, accept: Callable = Callable()) -> bool:
	var node: Dictionary = tree[index]
	if not _overlaps(camera, transform * node.bounds, circle): return false
	if node.has("triangles"):
		for triangle: int in node.triangles:
			if _triangle_contact(camera, faces, triangle * 3, transform, circle, result, pixels, accept): return true
	else:
		if _tree_contacts(camera, faces, tree, node.left, transform, circle, result, pixels, accept): return true
		if _tree_contacts(camera, faces, tree, node.right, transform, circle, result, pixels, accept): return true
	return false

func _triangle_contact(camera: Camera3D, faces: PackedVector3Array, index: int, transform: Transform3D,
		circle: Dictionary, result: Array[Dictionary], pixels: Dictionary, accept: Callable = Callable()) -> bool:
	var a: Vector3 = transform * faces[index]
	var b: Vector3 = transform * faces[index + 1]
	var c: Vector3 = transform * faces[index + 2]
	if camera.is_position_behind(a) or camera.is_position_behind(b) or camera.is_position_behind(c): return false
	var screen_a: Vector2 = project(a)
	var screen_b: Vector2 = project(b)
	var screen_c: Vector2 = project(c)
	var pixel: Vector2 = _closest_triangle(circle.center, screen_a, screen_b, screen_c)
	var distance: float = pixel.distance_to(circle.center)
	if distance > float(circle.radius): return false
	# Move off a triangle edge while staying inside the actual disc, so the
	# physics visibility probe is robust even for less than one pixel overlap.
	var centroid: Vector2 = (screen_a + screen_b + screen_c) / 3.0
	var inset: float = minf(0.15, maxf(float(circle.radius) - distance, 0.0) * 0.25)
	if pixel.distance_to(centroid) > 0.001: pixel = pixel.move_toward(centroid, inset)
	var point: Variant = Geometry3D.ray_intersects_triangle(camera.project_ray_origin(pixel), camera.project_ray_normal(pixel), a, b, c)
	if point == null: return false
	var key := Vector2i(roundi(pixel.x * 4), roundi(pixel.y * 4))
	var depth: float = camera.global_position.distance_to(point)
	if pixels.has(key):
		var existing: Dictionary = pixels[key]
		if depth < float(existing.depth):
			existing.point = point
			existing.pixel = pixel
			existing.depth = depth
			if _accept_contact(existing, accept): return true
		return false
	var contact := {"pixel": pixel, "point": point, "depth": depth, "score": pixel.distance_to(circle.center) / float(circle.radius)}
	pixels[key] = contact
	result.append(contact)
	return _accept_contact(contact, accept)

func _accept_contact(contact: Dictionary, accept: Callable) -> bool:
	if not accept.is_valid(): return false
	# -1 aborts a proven fully occluded candidate; 0 tries another surface;
	# 1 accepts a visible point. Boolean callbacks retain the same 0/1 meaning.
	var state: int = int(accept.call(contact))
	if state > 0: _accepted = contact
	return state != 0

func world_bounds(candidate: Node3D) -> AABB:
	var bounds: AABB
	var first: bool = true
	for reference: WeakRef in _visual_nodes(candidate):
		var node: Node3D = reference.get_ref()
		if not is_instance_valid(node) or not node.is_visible_in_tree(): continue
		var local: AABB
		if node is MeshInstance3D and node.mesh != null: local = node.mesh.get_aabb()
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			var count: int = node.multimesh.instance_count if node.multimesh.visible_instance_count < 0 else node.multimesh.visible_instance_count
			if count == 0: continue
			local = _batch_layout(node, count, node.multimesh.mesh).bounds
		else: continue
		var world: AABB = node.global_transform * local
		bounds = world if first else bounds.merge(world)
		first = false
	return bounds

func _mesh_faces(mesh: Mesh) -> PackedVector3Array:
	return _mesh_geometry(mesh).faces

func _mesh_bounds(mesh: Mesh) -> AABB:
	return _mesh_geometry(mesh).bounds

func _build_tree(faces: PackedVector3Array, bounds: AABB) -> Array[Dictionary]:
	var tree: Array[Dictionary] = []
	var count: int = faces.size() / 3
	if count <= 128: return tree
	# Morton sorting is one native integer-array sort. Nearby triangles share
	# leaves; a ring edge visits only nearby leaves instead of a whole skin.
	var keys := PackedInt64Array()
	keys.resize(count)
	var extent := Vector3(maxf(bounds.size.x, 0.00001), maxf(bounds.size.y, 0.00001), maxf(bounds.size.z, 0.00001))
	for index in range(count):
		var center: Vector3 = (faces[index * 3] + faces[index * 3 + 1] + faces[index * 3 + 2]) / 3.0
		var cell: Vector3 = (center - bounds.position) / extent * 1023.0
		var morton: int = _spread(clampi(int(cell.x), 0, 1023)) | (_spread(clampi(int(cell.y), 0, 1023)) << 1) | (_spread(clampi(int(cell.z), 0, 1023)) << 2)
		keys[index] = (morton << 32) | index
	keys.sort()
	var level: Array[int] = []
	for start in range(0, count, 32):
		var indices := PackedInt32Array()
		var leaf_bounds: AABB
		for position in range(start, mini(count, start + 32)):
			var triangle: int = keys[position] & 0xffffffff
			indices.append(triangle)
			var triangle_bounds := AABB(faces[triangle * 3], Vector3.ZERO).expand(faces[triangle * 3 + 1]).expand(faces[triangle * 3 + 2])
			leaf_bounds = triangle_bounds if position == start else leaf_bounds.merge(triangle_bounds)
		level.append(tree.size())
		tree.append({"bounds": leaf_bounds, "triangles": indices})
	while level.size() > 1:
		var next: Array[int] = []
		for index in range(0, level.size(), 2):
			if index + 1 == level.size(): next.append(level[index]); continue
			var left: int = level[index]
			var right: int = level[index + 1]
			next.append(tree.size())
			tree.append({"bounds": tree[left].bounds.merge(tree[right].bounds), "left": left, "right": right})
		level = next
	return tree

static func _spread(value: int) -> int:
	value = (value | (value << 16)) & 0x030000ff
	value = (value | (value << 8)) & 0x0300f00f
	value = (value | (value << 4)) & 0x030c30c3
	return (value | (value << 2)) & 0x09249249

func _mesh_geometry(mesh: Mesh) -> Dictionary:
	var geometry: Dictionary = _cached_geometry(mesh)
	if not geometry.has("faces"):
		geometry.faces = mesh.get_faces()
		geometry.tree = _build_tree(geometry.faces, geometry.bounds)
	return geometry

func _cached_geometry(mesh: Mesh) -> Dictionary:
	var identity: int = mesh.get_instance_id()
	if not _faces.has(identity):
		# Occluders need only the native ray BVH. A projected triangle tree is
		# built lazily for actual contact searches, not for every foreign body.
		_faces[identity] = {"mesh": weakref(mesh), "bounds": mesh.get_aabb()}
		_mesh_order.append(identity)
		if _mesh_order.size() > MESH_CACHE_LIMIT: _faces.erase(_mesh_order.pop_front())
	return _faces[identity]

func _overlaps(camera: Camera3D, bounds: AABB, circle: Dictionary) -> bool:
	var rect: Rect2
	for index in range(8):
		var corner: Vector3 = bounds.get_endpoint(index)
		if camera.is_position_behind(corner): return true
		var pixel: Vector2 = project(corner)
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
