extends SceneTree

const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Animator = preload("res://creatures/runtime/adaptive_locomotion_animator.gd")
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for seed_value in [15838, 23757]:
		var blueprint: Dictionary = Species.create_species(seed_value, Vector2i.ZERO, "grazer")
		var previews: Array[Node3D] = []
		var snapshots: Array[Dictionary] = []
		var counts: Array[int] = []
		for batched: bool in [false, true]:
			var preview := Preview.new()
			preview.sculpted_surface = false # Retain the legacy voxel backend regression.
			preview.batch_runtime_boxes = batched
			preview.blueprint = blueprint.duplicate(true)
			root.add_child(preview)
			previews.append(preview)
			var data: Dictionary = {}
			_collect(preview, preview, data)
			snapshots.append(data)
			counts.append(_geometry_nodes(preview))
		var before_keys: Array = snapshots[0].keys()
		var after_keys: Array = snapshots[1].keys()
		before_keys.sort()
		after_keys.sort()
		_expect(before_keys == after_keys, "Batching changed an animated slice or attachment root.")
		for path: String in snapshots[0]:
			var before: Array = snapshots[0][path]
			var after: Array = snapshots[1].get(path, [])
			_expect(before.size() == after.size(), "Batching dropped or duplicated voxels at " + path)
			for index in range(mini(before.size(), after.size())):
				_expect((before[index][0] as Transform3D).is_equal_approx(after[index][0]), "Batched voxel geometry moved at " + path)
				var a: Color = before[index][1]
				var b: Color = after[index][1]
				_expect(Vector3(a.r-b.r, a.g-b.g, a.b-b.b).length() < 0.008, "Batched voxel lost its authored color.")
		_expect(counts[1] < counts[0] / 2, "Runtime batching did not meaningfully reduce geometry nodes.")
		_test_leg_rig(previews[1])
		print("Runtime geometry batching ", JSON.stringify({"seed": seed_value, "individual_nodes": counts[0], "batched_nodes": counts[1]}))
		for preview: Node in previews:
			preview.free()
		await process_frame
	for failure: String in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("Runtime geometry batch test passed: identical voxels/colors/attachment roots, reduced nodes and moving knee rig.")
	quit(0 if _failures.is_empty() else 1)


func _collect(preview: Node3D, node: Node, data: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh is BoxMesh:
		var key: String = str(preview.get_path_to(node.get_parent()))
		if not data.has(key):
			data[key] = []
		var transform: Transform3D = node.transform * Transform3D(Basis.from_scale(node.mesh.size), Vector3.ZERO)
		data[key].append([transform, node.material_override.albedo_color])
	elif node is MultiMeshInstance3D:
		var key: String = str(preview.get_path_to(node.get_parent()))
		if not data.has(key):
			data[key] = []
		_expect(node.material_override.vertex_color_is_srgb, "Runtime authored colors lost their sRGB declaration.")
		var buffer: PackedFloat32Array = node.multimesh.buffer
		_expect(buffer.size() == node.multimesh.instance_count * 16, "Runtime instance buffer is incomplete.")
		for index in range(node.multimesh.instance_count):
			var offset: int = index * 16
			var basis := Basis(Vector3(buffer[offset], buffer[offset + 4], buffer[offset + 8]),
				Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]),
				Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10]))
			var position := Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11])
			var color := Color(buffer[offset + 12], buffer[offset + 13], buffer[offset + 14], buffer[offset + 15])
			data[key].append([node.transform * Transform3D(basis, position), color])
	for child: Node in node.get_children():
		_collect(preview, child, data)


func _geometry_nodes(node: Node) -> int:
	var count: int = 1 if node is GeometryInstance3D else 0
	for child: Node in node.get_children():
		count += _geometry_nodes(child)
	return count


func _test_leg_rig(preview: Node3D) -> void:
	for child: Node in preview.get_children():
		if str(child.get_meta("creature_part_category", "")) != "legs":
			continue
		var animator := Animator.new()
		var rig: Dictionary = animator._create_runtime_leg_rig(child)
		_expect(rig["knee"] != null and rig["foot"] != null, "Batching broke the adaptive knee/foot rig.")
		if rig["knee"] != null:
			var knee: Node3D = rig["knee"]
			var mesh: MeshInstance3D = null
			for candidate: Node in knee.get_children():
				if candidate is MeshInstance3D:
					mesh = candidate
					break
			_expect(mesh != null, "Adaptive knee contains no articulated geometry.")
			if mesh != null:
				var before: Transform3D = mesh.global_transform
				knee.rotate_x(0.3)
				_expect(not mesh.global_transform.is_equal_approx(before), "Knee rotation no longer moves the leg geometry.")
		animator.free()
		return
	_expect(false, "Creature fixture contains no leg articulation to verify.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
