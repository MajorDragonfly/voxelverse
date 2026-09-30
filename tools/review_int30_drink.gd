extends "res://tests/onboarding_guidance_world_test.gd"
## Actual common spherical player, water source, HUD and physical action ray.
func _run() -> void:
	saves = root.get_node("SaveGameService")
	flow = root.get_node("SessionFlow")
	state = root.get_node("GameState")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("INT30 drink", 15838, Cube.MODE)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	flow.load_game(path)
	await _until(func() -> bool: return not flow.loading, 50000)
	if current_scene == null or not current_scene.world_initialized:
		_expect(false, "Drink sphere did not load.")
		await _finish()
		return
	var scene: Node3D = current_scene
	var player: CharacterBody3D = scene.player
	await _until(func() -> bool: return player.is_on_floor(), 10000)
	player.set_process(false)
	player.set_physics_process(false)
	var context: Node = player.get_node("ContextActionHUD")
	var dry: Dictionary = player.location().duplicate(true)
	await _water(scene)
	# _water found a real freshwater lake and proved dry/full/reachable cases.
	var lake_place: Dictionary = player.location().duplicate(true)
	var lake_sample: Dictionary = Space.sample(player, player.global_position)
	lake_place.height = lake_sample.water_level + 0.1
	player.place(lake_place)
	await _until(func() -> bool: return Space.ground_ready(player, player.global_position), 25000)
	player.is_swimming = false
	player.current_thirst = 20
	# Water has no solid surface; the physical ray sees its submerged terrain.
	var ray: RayCast3D = player.interaction_ray
	var up: Vector3 = player.up_direction
	ray.global_position = player.global_position + up * 1.0
	await physics_frame
	# Search the reach boundary: source is close, submerged solid floor is farther.
	for distance in [3.0, 3.1, 3.15, 3.18]:
		for index in range(8):
			var angle: float = index * TAU / 8.0
			var offset: Vector3 = Space.frame(player, player.global_position) * Vector3(cos(angle), 0, sin(angle)) * distance
			var target_place: Dictionary = Space.address(player, player.global_position + offset)
			var target_sample: Dictionary = scene.adapter.sample(target_place)
			target_place.height = target_sample.height - 0.2
			var target: Vector3 = scene.adapter.to_local(target_place)
			ray.target_position = ray.global_basis.inverse() * (target - ray.global_position)
			ray.force_raycast_update()
			if ray.is_colliding() and player.global_position.distance_to(ray.get_collision_point()) > player.interaction_range and context.drink_prompt_at(ray.get_collision_point()): break
		if ray.is_colliding() and player.global_position.distance_to(ray.get_collision_point()) > player.interaction_range and context.drink_prompt_at(ray.get_collision_point()): break
	var point: Vector3 = ray.get_collision_point()
	var source: Dictionary = player.reachable_drink_source(point)
	_expect(ray.is_colliding() and not source.is_empty(), "Lake-bottom ray did not resolve reachable freshwater.")
	_expect(context.drink_prompt_at(point), "Reachable lake ray did not display drink context.")
	_expect(player.global_position.distance_to(point) > player.interaction_range, "Reach-boundary case did not reproduce the deeper solid hit.")
	player._try_primary_action()
	_expect(player.current_thirst > 20, "Visible reachable freshwater hint disagrees with the actual primary action.")
	print("INT30_DRINK_RAY ", JSON.stringify({"ray_distance_m": player.global_position.distance_to(point), "surface_distance_m": player.global_position.distance_to(source.point) if not source.is_empty() else -1, "thirst": player.current_thirst}))
	# Move the actor away but retain the identical freshwater query.
	var far: Vector3 = player.global_position + Space.frame(player, player.global_position).x * 10.0
	player.global_position = far
	player.current_thirst = 20
	_expect(not context.drink_prompt_at(point), "Distant freshwater advertised drinking.")
	player._try_drink_water(point)
	_expect(player.current_thirst == 20, "Distant freshwater restored thirst.")
	# Find real ocean water from the ordinary body source, without injected kinds.
	var ocean: Dictionary = {}
	var surface: RefCounted = scene.terrain.surface
	for face in range(6):
		for u in [-0.75, -0.25, 0.25, 0.75]:
			for v in [-0.75, -0.25, 0.25, 0.75]:
				var place := {"mode": Cube.MODE, "body_id": surface.body.id, "face": face, "u": u, "v": v, "height": 0.0}
				var sample: Dictionary = scene.adapter.sample(place)
				if sample.water and sample.get("water_kind", "ocean") == "ocean":
					place.height = sample.water_level - 0.3
					ocean = place
					break
			if not ocean.is_empty(): break
		if not ocean.is_empty(): break
	_expect(not ocean.is_empty(), "No real saltwater sample found.")
	if not ocean.is_empty():
		player.place(ocean)
		await _until(func() -> bool: return Space.ground_ready(player, player.global_position), 25000)
		_expect(not context.drink_prompt_at(player.global_position), "Saltwater advertised drinking.")
		player.current_thirst = 20
		player._try_drink_water(player.global_position)
		_expect(player.current_thirst == 20, "Saltwater restored thirst.")
		player.is_swimming = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		context._update_context()
		print("INT30_SALT_HUD ", JSON.stringify({"visible": context._label.visible, "text": context._label.text, "mouse_mode": Input.mouse_mode, "inspection": player.inspection_mode_enabled, "target": str(player.get_interaction_target())}))
		_expect(context._label.visible and context._label.text.contains("auftauchen") and not context._label.text.contains("trinken"), "Saltwater swim HUD did not keep only ascent context.")
	player.place(dry)
	player.is_swimming = false
	if failures.is_empty(): print("INT30_DRINK_PASSED")
	await _finish()
