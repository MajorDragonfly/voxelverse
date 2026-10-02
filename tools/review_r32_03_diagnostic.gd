extends SceneTree
## Bounded probe of an unexpected physical step rejection, no product changes.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var fixture := preload("res://tests/r32_03_step_fixture.gd").new()
	root.add_child(fixture)
	current_scene = fixture
	fixture.setup(1.0, false, 3.0)
	for tick in range(10): await physics_frame
	Input.action_press("move_forward")
	for tick in range(100): await physics_frame
	Input.action_release("move_forward")
	var actor: CharacterBody3D = fixture.player
	var motion: Vector3 = (-actor.camera_pivot.global_basis.z).slide(actor.up_direction).normalized() * actor.move_speed / 60.0
	var raised: Transform3D = actor.global_transform.translated(actor.up_direction * actor.maximum_step_height)
	var landing := KinematicCollision3D.new()
	var hit: bool = actor.test_move(raised.translated(motion), -actor.up_direction * (actor.maximum_step_height + actor.step_floor_probe), landing)
	var edge: Vector3 = landing.get_position() + motion.normalized() * minf(actor.step_floor_probe, motion.length())
	var lateral: Vector3 = (edge - actor.global_position).slide(actor.up_direction)
	var from: Vector3 = actor.global_position + lateral + actor.up_direction * (actor.maximum_step_height + actor.step_floor_probe)
	var to: Vector3 = actor.global_position + lateral - actor.up_direction * actor.step_floor_probe
	var ray := PhysicsRayQueryParameters3D.create(from, to, actor.collision_mask)
	ray.exclude = [actor.get_rid()]
	var support: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(ray)
	print("R32_03_BLOCKED_DIAGNOSTIC ", JSON.stringify({"body": str(fixture.point(actor)), "motion": str(motion), "up": str(actor.up_direction), "front": actor.test_move(actor.global_transform, motion),
		"rise": actor.test_move(actor.global_transform, actor.up_direction * actor.maximum_step_height), "raised_front": actor.test_move(raised, motion), "landing": hit,
		"normal": str(landing.get_normal()) if hit else "", "point": str(landing.get_position()) if hit else "", "ray_from": str(from), "ray_to": str(to), "support": str(support), "grounded": actor.is_on_floor(),
		"top": preload("res://world/surface/gameplay_space.gd")._walkable_step_top(actor, motion, landing.get_position(), actor.maximum_step_height, actor.step_floor_probe) if hit else false}))
	fixture.close()
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
