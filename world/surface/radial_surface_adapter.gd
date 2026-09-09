extends RefCounted

## M1d's bounded surface contract. Never turn absolute metre positions into
## Vector3 before subtracting the origin. Bind a root once, never both an
## ancestor and its descendants; registered roots must have unscaled parents.
const Cube = preload("res://world/space/cube_sphere.gd")
signal origin_shifted(shift: Vector3)
var terrain: Node3D
var attached: Dictionary = {}
var max_rebase_error_m: float = 0.0


func _init(value: Node3D) -> void:
	terrain = value
	terrain.origin_changed.connect(_on_origin_changed)


func sample(address: Dictionary) -> Dictionary:
	assert(Cube.valid(address, terrain.surface.body.id))
	return terrain.surface.sample(address)


func to_local(address: Dictionary) -> Vector3:
	assert(Cube.valid(address, terrain.surface.body.id))
	return Cube.local_position(Cube.cartesian(address, terrain.surface.body.radius), terrain.origin)


func location(node: Node3D) -> Dictionary:
	return Cube.from_cartesian(terrain.surface.body.id,
		Cube.global_position(node.global_position, terrain.origin), terrain.surface.body.radius)


func up_at(address: Dictionary) -> Vector3:
	return Cube.vector(Cube.direction(address.face, address.u, address.v))


func frame_at(address: Dictionary, forward: Vector3 = Vector3.FORWARD) -> Basis:
	return Cube.frame(up_at(address), forward)


func offset(address: Dictionary, tangent_metres: Vector3, clearance: float = 0.0) -> Dictionary:
	var point: Array = Cube.cartesian(address, terrain.surface.body.radius)
	var tangent: Vector3 = tangent_metres.slide(up_at(address))
	var result: Dictionary = Cube.from_cartesian(terrain.surface.body.id,
		[point[0] + tangent.x, point[1] + tangent.y, point[2] + tangent.z], terrain.surface.body.radius)
	result.height = sample(result).height + clearance
	return result


func bind(id: String, node: Node3D, address: Dictionary, forward: Vector3 = Vector3.FORWARD) -> void:
	assert(not attached.has(id))
	attached[id] = node
	node.set_meta("surface_object_id", id)
	place(node, address, forward)


func place(node: Node3D, address: Dictionary, forward: Vector3 = Vector3.FORWARD) -> void:
	node.global_position = to_local(address)
	node.global_basis = frame_at(address, forward)
	if node is CharacterBody3D:
		node.up_direction = up_at(address)


func unbind(id: String) -> void:
	attached.erase(id)


func collision_ready(address: Dictionary) -> bool:
	var owner: Dictionary = terrain.layout.find_at(address.face, address.u, address.v, terrain.leaves)
	return not owner.is_empty() and terrain.active.has(owner.id) \
		and owner.width * terrain.surface.body.radius / 16.0 <= 4.0


func attempt_step(body: CharacterBody3D, motion: Vector3) -> void:
	# Same three physical probes as RadialWalker: head clearance, forward
	# clearance, then a walkable landing. A tree/ceiling cannot be height-snapped.
	if motion.length_squared() < 0.00001 or not body.test_move(body.global_transform, motion):
		return
	var rise: Vector3 = body.up_direction * 0.62
	if body.test_move(body.global_transform, rise):
		return
	var raised: Transform3D = body.global_transform.translated(rise)
	if body.test_move(raised, motion):
		return
	var landing := KinematicCollision3D.new()
	if not body.test_move(raised.translated(motion), -body.up_direction * 0.85, landing):
		return
	if landing.get_normal().dot(body.up_direction) >= cos(body.floor_max_angle):
		body.global_transform = raised


func _on_origin_changed(previous: Array, current: Array) -> void:
	for node: Node3D in attached.values():
		var point: Array = Cube.global_position(node.global_position, previous)
		node.global_position = Cube.local_position(point, current)
		if node.has_method("surface_origin_shifted"):
			node.surface_origin_shifted(Cube.local_position(previous, current))
		var after: Array = Cube.global_position(node.global_position, current)
		max_rebase_error_m = maxf(max_rebase_error_m, Cube.local_position(after, point).length())

	origin_shifted.emit(Cube.local_position(previous, current))


func close() -> void:
	if is_instance_valid(terrain) and terrain.origin_changed.is_connected(_on_origin_changed):
		terrain.origin_changed.disconnect(_on_origin_changed)
	attached.clear()
