extends SceneTree

const Terrain = preload("res://world/surface/surface_terrain.gd")
const Adapter = preload("res://world/surface/radial_surface_adapter.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const System = preload("res://world/space/celestial_system.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var terrain := Terrain.new()
	root.add_child(terrain)
	terrain.configure(System.new(false, true).bodies["m1b:terra"])
	var adapter := Adapter.new(terrain)
	var max_error: float = 0.0
	var cases: int = 0
	for face in range(6):
		# Centers include both poles; corners exercise canonical face transitions.
		for uv in [Vector2.ZERO, Vector2(1.0, 1.0), Vector2(-0.71, 0.39)]:
			var anchor: Dictionary = Cube.address("m1b:terra", face, uv.x, uv.y)
			anchor.height = adapter.sample(anchor).height + 1.1
			terrain.rebase(Cube.cartesian(anchor, terrain.surface.body.radius))
			var objects: Array[Node3D] = []
			var addresses: Array[Dictionary] = []
			for index in range(3):
				var node := Node3D.new()
				root.add_child(node)
				objects.append(node)
				var address: Dictionary = adapter.offset(anchor, adapter.frame_at(anchor).x * index * 7.3, 1.1)
				addresses.append(address)
				adapter.bind(str(index), node, address)
				_expect(node.basis.y.dot(adapter.up_at(address)) > 0.999999, "A specimen retained world-Y at face %d" % face)
			var origin: Array = terrain.origin.duplicate()
			var shift: Vector3 = adapter.frame_at(anchor).x * 64.37 + adapter.up_at(anchor) * 3.11
			terrain.rebase([origin[0] + shift.x, origin[1] + shift.y, origin[2] + shift.z])
			for index in range(3):
				var restored: Dictionary = adapter.location(objects[index])
				var error: float = Cube.local_position(Cube.cartesian(restored, 6371000.0), Cube.cartesian(addresses[index], 6371000.0)).length()
				max_error = maxf(max_error, error)
				_expect(error < 0.0001, "Rebase lost sub-millimetre placement on face %d" % face)
				adapter.unbind(str(index))
				objects[index].free()
			cases += 1
	adapter.close()
	terrain.queue_free()
	await process_frame
	await process_frame
	for message in failures:
		push_error(message)
	print("SURFACE_CONTRACT ", JSON.stringify({"radial_cases": cases, "objects_per_case": 3, "max_error_m": max_error, "passed": failures.is_empty()}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
