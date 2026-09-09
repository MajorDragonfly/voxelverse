extends RefCounted
## Bounded local steering against the actual streamed collision geometry.
## No terrain generation, global navigation mesh, or teleport is performed here.
const Space = preload("res://world/surface/gameplay_space.gd")

static func ground(actor: CharacterBody3D, point: Vector3) -> Dictionary:
	return Space.floor_hit(actor, point, 0.85, 2.0)

static func clear_sight(actor: CharacterBody3D, target: Node3D) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return false
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Space.up(actor, actor.global_position) * 0.65, target.global_position + Space.up(actor, target.global_position) * 0.65, 1 | 2)
	var excluded: Array[RID] = [actor.get_rid()]
	if target is CollisionObject3D:
		excluded.append(target.get_rid())
	ray.exclude = excluded
	return actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

static func safe_direction(actor: CharacterBody3D, direction: Vector3, step_height: float, distance: float = 1.1) -> bool:
	var point: Vector3 = actor.global_position + direction * distance
	var floor_hit: Dictionary = ground(actor, point)
	var up: Vector3 = Space.up(actor, point)
	if floor_hit.is_empty() or floor_hit["normal"].dot(up) < 0.70:
		return false
	var difference: float = (Vector3(floor_hit["position"]) - actor.global_position).dot(actor.up_direction)
	if difference > step_height + 0.04 or difference < -0.78:
		return false
	if not Space.dry(actor, floor_hit["position"]):
		return false
	var motion: Vector3 = direction * distance
	if not actor.test_move(actor.global_transform, motion):
		return true
	# A step is allowed only when the whole body can rise, move forward and
	# land again. A low ceiling must not be bypassed by the raised sweep.
	var rise: Vector3 = actor.up_direction * step_height
	var raised: Transform3D = actor.global_transform.translated(rise)
	return not actor.test_move(actor.global_transform, rise) and not actor.test_move(raised, motion) and actor.test_move(raised.translated(motion), -actor.up_direction * (step_height + 0.12))

static func choose(actor: CharacterBody3D, desired: Vector3, step_height: float, side: float, distance: float = 1.1) -> Vector3:
	if desired.length_squared() < 0.001:
		return Vector3.ZERO
	var forward: Vector3 = desired.slide(actor.up_direction).normalized()
	# The seeded side stays stable across frames, avoiding left/right jitter
	# while following the edge of a tree or short wall.
	for angle in [0.0, side * 0.40, side * 0.80, side * 1.20, side * 1.60, -side * 0.80, -side * 1.20, -side * 1.60]:
		var direction: Vector3 = forward.rotated(actor.up_direction, angle)
		if safe_direction(actor, direction, step_height, distance):
			return direction
	return Vector3.ZERO
