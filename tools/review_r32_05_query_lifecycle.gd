extends RefCounted
## Consecutive queries must observe changed poses/visibility and release actors.
const Silhouette = preload("res://core/discovery/scan_silhouette.gd")
const Packing = preload("res://core/multimesh_buffer.gd")
var failures: Array[String] = []

func run(tree: SceneTree) -> Array[String]:
	var root: Window = tree.root
	var camera := Camera3D.new(); root.add_child(camera); camera.make_current()
	var candidate := Node3D.new(); root.add_child(candidate)
	var batch := MultiMeshInstance3D.new(); candidate.add_child(batch)
	batch.multimesh = MultiMesh.new(); batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_colors = true; batch.multimesh.mesh = BoxMesh.new(); batch.multimesh.instance_count = 1
	_pose(batch, Vector3(0, 0, -4))
	var geometry := Silhouette.new()
	var circle := {"center": root.get_visible_rect().get_center(), "radius": 26.0}
	geometry.begin_query(camera)
	var contact: Dictionary = geometry.ray_contact(camera, candidate, circle.center, circle)
	_check(not contact.is_empty(), "Native fast path lost a real batch surface")
	_check(contact.is_empty() or camera.unproject_position(contact.point).distance_to(contact.pixel) < 0.002, "Fast path returned a mismatched reticle pixel")
	_check(geometry.occludes(camera, candidate, circle.center, Vector3(0, 0, -8)), "Batch failed to occlude a point behind its surface")
	_check(not geometry.occludes(camera, candidate, circle.center, Vector3(0, 0, -2)), "Batch occluded a nearer point")
	# The scanner adds its target to the returned fallback contact dictionary.
	# Its internal accepted contact must not retain that actor after the query.
	var fallback: Array[Dictionary] = geometry.contacts(camera, candidate, circle,
		func(_point: Dictionary) -> int: return 1)
	_check(not fallback.is_empty(), "Lifecycle fixture failed to reach a silhouette contact")
	if not fallback.is_empty(): fallback.front().target = candidate
	geometry.end_query()
	_check(geometry.get("_accepted").is_empty(), "A completed query retained its accepted silhouette contact")
	_check(fallback.is_empty() or fallback.front().has("point"), "Query teardown invalidated a returned surface")
	_check(geometry.cache_sizes().query_parts == 0 and geometry.cache_sizes().query_layouts == 0, "A completed query retained a pose snapshot")
	# Same count/identity, changing instance pose in the same engine frame.
	_pose(batch, Vector3(4, 0, -4))
	geometry.begin_query(camera)
	_check(geometry.ray_contact(camera, candidate, circle.center, circle).is_empty(), "Next query retained the previous animated pose")
	_check(not geometry.occludes(camera, candidate, circle.center, Vector3(0, 0, -8)), "Next query retained stale occlusion")
	geometry.end_query()
	# CPU eye-pose contract changes without a RenderingServer readback.
	var poses: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(0, 0, -4))]
	var eye := {"upper": batch, "upper_buffer": Packing.pack(poses, [Color.WHITE]), "lower": null, "lower_buffer": PackedFloat32Array()}
	candidate.set_meta("eye_expression_sockets", [eye])
	geometry.begin_query(camera)
	_check(geometry.occludes(camera, candidate, circle.center, Vector3(0, 0, -8)), "Scanner ignored the current CPU eye pose")
	geometry.end_query()
	poses[0].origin.x = 4
	eye.upper_buffer = Packing.pack(poses, [Color.WHITE])
	geometry.begin_query(camera)
	_check(not geometry.occludes(camera, candidate, circle.center, Vector3(0, 0, -8)), "Changed CPU eye pose retained old occlusion")
	geometry.end_query()
	candidate.remove_meta("eye_expression_sockets")
	# Immutable voxel geometry may move with its parent and replace its mesh.
	batch.name = "RuntimeVoxelBatch"
	batch.multimesh = MultiMesh.new(); batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_colors = true; batch.multimesh.mesh = BoxMesh.new(); batch.multimesh.instance_count = 1
	_pose(batch, Vector3(0, 0, -4))
	geometry.begin_query(camera)
	_check(geometry.occludes(camera, candidate, circle.center, Vector3(0, 0, -8)), "Static voxel batch failed to occlude")
	geometry.end_query()
	candidate.position.x = 5
	geometry.begin_query(camera)
	_check(not geometry.occludes(camera, candidate, circle.center, Vector3(0, 0, -8)), "Parent motion retained static batch world bounds")
	geometry.end_query()
	candidate.position.x = 0
	var small := BoxMesh.new(); small.size = Vector3.ONE * 0.1; batch.multimesh.mesh = small
	geometry.begin_query(camera)
	var narrow: Dictionary = geometry.ray_contact(camera, candidate, circle.center, circle)
	_check(not narrow.is_empty() and absf(narrow.point.z + 3.95) < 0.001, "Mesh replacement retained old native surface/layout")
	geometry.end_query()
	batch.hide()
	geometry.begin_query(camera)
	_check(geometry.ray_contact(camera, candidate, circle.center, circle).is_empty(), "Hidden geometry remained a fast-path contact")
	_check(not geometry.occludes(camera, candidate, circle.center, Vector3(0, 0, -8)), "Hidden geometry retained occlusion")
	geometry.end_query()
	batch.show()
	geometry.begin_query(camera)
	_check(not geometry.ray_contact(camera, candidate, circle.center, circle).is_empty(), "Restored visible geometry remained absent")
	geometry.end_query()
	var released: WeakRef = weakref(candidate)
	candidate.queue_free(); await tree.process_frame
	geometry.begin_query(camera); geometry.end_query()
	_check(released.get_ref() == null and geometry.cache_sizes().nodes == 0 and geometry.cache_sizes().batches == 0, "Scanner caches retained an unloaded actor or batch")
	_check(geometry.cache_sizes().meshes <= geometry.MESH_CACHE_LIMIT, "Native geometry cache exceeded its bound")
	camera.queue_free(); await tree.process_frame
	if failures.is_empty(): print("R32_05_QUERY_LIFECYCLE_PASSED")
	return failures

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _pose(batch: MultiMeshInstance3D, position: Vector3) -> void:
	# Production RuntimeVoxelBatch and eye animation upload the same bulk data;
	# individual server setters do not provide a buffer in the headless driver.
	batch.multimesh.buffer = Packing.pack([Transform3D(Basis.IDENTITY, position)], [Color.WHITE])
