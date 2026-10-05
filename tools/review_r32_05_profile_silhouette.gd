extends "res://core/discovery/scan_silhouette.gd"
## Inclusive diagnostic timings only; never used for comparative performance.
var counters: Dictionary = {}

func _add(key: String, started: int) -> void:
	if not counters.has(key): counters[key] = {"calls": 0, "usec": 0}
	counters[key].calls += 1
	counters[key].usec += Time.get_ticks_usec() - started

func _visual_nodes(candidate: Node3D) -> Array[WeakRef]:
	var started := Time.get_ticks_usec()
	var result := super._visual_nodes(candidate)
	_add("visual_nodes", started)
	return result

func _batch_layout(node: MultiMeshInstance3D, count: int, mesh: Mesh) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := super._batch_layout(node, count, mesh)
	_add("batch_layout", started)
	return result

func _batch_transforms(node: MultiMeshInstance3D, count: int) -> Array[Transform3D]:
	var started := Time.get_ticks_usec()
	var result := super._batch_transforms(node, count)
	_add("batch_transforms", started)
	return result

func _ray_mesh(mesh: Mesh, transform: Transform3D, origin: Vector3, finish: Vector3) -> bool:
	var started := Time.get_ticks_usec()
	var result := super._ray_mesh(mesh, transform, origin, finish)
	_add("ray_mesh", started)
	return result

func occludes(camera: Camera3D, candidate: Node3D, pixel: Vector2, point: Vector3) -> bool:
	var started := Time.get_ticks_usec()
	var result := super.occludes(camera, candidate, pixel, point)
	_add("occludes", started)
	return result

func _triangle_contact(camera: Camera3D, faces: PackedVector3Array, index: int, transform: Transform3D,
		circle: Dictionary, result: Array[Dictionary], pixels: Dictionary, accept: Callable = Callable()) -> bool:
	var started := Time.get_ticks_usec()
	var accepted := super._triangle_contact(camera, faces, index, transform, circle, result, pixels, accept)
	_add("triangle_contact", started)
	return accepted
