extends RefCounted
## Bounded local steering against the actual streamed collision geometry.
## No terrain generation, global navigation mesh, or teleport is performed here.

static func ground(actor: CharacterBody3D, point: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.85, point + Vector3.DOWN * 2.0, 1)
	ray.exclude = [actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_ray(ray)

static func clear_sight(actor: CharacterBody3D, target: Node3D) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return false
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.65, target.global_position + Vector3.UP * 0.65, 1)
	ray.exclude = [actor.get_rid()]
	if target is CollisionObject3D:
		ray.exclude.append(target.get_rid())
	return actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

static func safe_direction(actor: CharacterBody3D, direction: Vector3, step_height: float, distance: float = 1.1) -> bool:
	var point: Vector3 = actor.global_position + direction * distance
	var floor_hit: Dictionary = ground(actor, point)
	if floor_hit.is_empty() or floor_hit["normal"].dot(Vector3.UP) < 0.70:
		return false
	var height: float = float(floor_hit["position"].y)
	var difference: float = height - actor.global_position.y
	if difference > step_height + 0.04 or difference < -0.78:
		return false
	var generator: Node = actor.get_node_or_null("/root/WorldGenerator")
	if generator != null and height < float(generator.get_water_level(point.x, point.z)) + 0.18:
		return false
	var motion: Vector3 = direction * distance
	if not actor.test_move(actor.global_transform, motion):
		return true
	# A step is allowed only when the whole body can rise, move forward and
	# land again. A low ceiling must not be bypassed by the raised sweep.
	var rise := Vector3.UP * step_height
	var raised: Transform3D = actor.global_transform.translated(rise)
	return not actor.test_move(actor.global_transform, rise) and not actor.test_move(raised, motion) and actor.test_move(raised.translated(motion), Vector3.DOWN * (step_height + 0.12))

static func choose(actor: CharacterBody3D, desired: Vector3, step_height: float, side: float) -> Vector3:
	if desired.length_squared() < 0.001:
		return Vector3.ZERO
	var forward: Vector3 = desired.normalized()
	# The seeded side stays stable across frames, avoiding left/right jitter
	# while following the edge of a tree or short wall.
	for angle in [0.0, side * 0.40, side * 0.80, side * 1.20, side * 1.60, -side * 0.80, -side * 1.20, -side * 1.60]:
		var direction: Vector3 = forward.rotated(Vector3.UP, angle)
		if safe_direction(actor, direction, step_height):
			return direction
	return Vector3.ZERO
