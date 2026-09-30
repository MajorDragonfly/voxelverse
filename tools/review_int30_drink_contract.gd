extends SceneTree
## Focused real sampler/water/player/HUD probe. Only terrain publication is a fixture.
const Cube = preload("res://world/space/cube_sphere.gd")
const Surface = preload("res://world/surface/living_planet_surface_v2.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
var failures: Array[String] = []

class PublishedTerrain extends Node3D:
	signal origin_changed(previous: Array, current: Array)
	var surface: RefCounted
	var origin: Array = []
	var published: bool = true
	func ground_ready(_point: Array) -> bool: return published

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	await process_frame
	root.get_node("GameState").start_world_with_seed(15838)
	var body: Dictionary = preload("res://world/space/celestial_body_profile.gd").create("int30:water", "planet", 15838, 6371000.0)
	body.terrain_revision = 4
	body.surface_generation = Surface.VERSION
	var surface := Surface.new(body)
	var lake: Dictionary = {}
	var dry: Dictionary = {}
	var ocean: Dictionary = {}
	for face in range(6):
		for y in range(-3, 4):
			for x in range(-3, 4):
				var place: Dictionary = Cube.address(body.id, face, x * 0.3, y * 0.3)
				var sample: Dictionary = surface.sample(place)
				if dry.is_empty() and not sample.water: dry = place
				if ocean.is_empty() and sample.water and sample.get("water_kind", "ocean") == "ocean": ocean = place
				if lake.is_empty():
					for candidate: Dictionary in surface._lakes.values():
						if candidate.is_empty(): continue
						var water_sample: Dictionary = surface._sample(candidate.direction)
						if water_sample.water and water_sample.get("water_kind", "ocean") in ["lake", "river"] and water_sample.water_level - water_sample.height > 0.4:
							lake = candidate
							break
				if not lake.is_empty() and not dry.is_empty() and not ocean.is_empty(): break
			if not lake.is_empty() and not dry.is_empty() and not ocean.is_empty(): break
		if not lake.is_empty() and not dry.is_empty() and not ocean.is_empty(): break
	_check(not lake.is_empty() and not dry.is_empty() and not ocean.is_empty(), "Real body has no required dry/lake/ocean samples.")
	if not failures.is_empty(): await _finish(); return
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var terrain := PublishedTerrain.new()
	terrain.surface = surface
	stage.add_child(terrain)
	var adapter := preload("res://world/surface/radial_surface_adapter.gd").new(terrain)
	stage.set_meta("campaign_surface", adapter)
	var water := preload("res://world/surface/campaign_water.gd").new()
	water.name = "Water"
	stage.add_child(water)
	var address: Dictionary = Cube.from_direction(body.id, lake.direction)
	var sample: Dictionary = surface.sample(address)
	address.height = sample.water_level + 0.1
	terrain.origin = Cube.cartesian(address, body.radius)
	var player: CharacterBody3D = load("res://creatures/player/player.tscn").instantiate()
	player.get_node("CreatureRuntimeVisual").apply_blueprint_stats = false
	stage.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.global_basis = adapter.frame_at(address)
	player.up_direction = player.global_basis.y
	for i in range(5): await process_frame
	var context: Node = player.get_node("ContextActionHUD")
	_check(context.drink_prompt_at(Vector3.ZERO), "Actual freshwater source did not resolve.")
	player.current_thirst = 20
	player._try_drink_water(Vector3.ZERO)
	_check(player.current_thirst > 20, "Actual freshwater did not restore thirst.")
	terrain.published = false
	_check(not context.drink_prompt_at(Vector3.ZERO), "Unpublished ground advertised freshwater.")
	terrain.published = true
	# A physical submerged collider on a real water column, just at the reach edge.
	var bed := StaticBody3D.new()
	bed.basis = player.global_basis
	bed.position = -player.up_direction * 1.1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 0.2, 20)
	collider.shape = shape
	bed.add_child(collider)
	stage.add_child(bed)
	await physics_frame
	var ray: RayCast3D = player.interaction_ray
	ray.global_position = player.up_direction
	var target: Vector3 = player.global_basis.x * 3.1 - player.up_direction * 1.01
	ray.target_position = ray.global_basis.inverse() * (target - ray.global_position)
	ray.force_raycast_update()
	var point: Vector3 = ray.get_collision_point()
	var source: Dictionary = player.reachable_drink_source(point)
	_check(ray.is_colliding() and not source.is_empty() and player.global_position.distance_to(point) > player.interaction_range, "Physical reach-edge fixture did not reproduce the source/solid distance difference.")
	_check(context.drink_prompt_at(point), "Reachable surface hint is absent.")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	context._update_context()
	if DisplayServer.get_name() != "headless":
		_check(context._label.visible and "trinken" in context._label.text, "Reachable freshwater hint is not shown by the real HUD.")
	player.current_thirst = 20
	player._try_primary_action()
	_check(player.current_thirst > 20, "Visible reachable freshwater hint disagrees with primary click.")
	print("INT30_DRINK_BOUNDARY ", JSON.stringify({"solid_distance_m": player.global_position.distance_to(point), "surface_distance_m": player.global_position.distance_to(source.point) if not source.is_empty() else -1, "thirst": player.current_thirst}))
	player.global_position = player.global_basis.x * 10.0
	_check(not context.drink_prompt_at(point), "Far water advertises drinking.")
	player.current_thirst = 20
	player._try_drink_water(point)
	_check(player.current_thirst == 20, "Far water restored thirst.")
	player.global_position = Vector3.ZERO
	for place: Dictionary in [dry, ocean]:
		var data: Dictionary = surface.sample(place)
		place.height = data.water_level - 0.3 if data.water else data.height + 0.1
		terrain.origin = Cube.cartesian(place, body.radius)
		player.global_basis = adapter.frame_at(place)
		player.up_direction = player.global_basis.y
		_check(not context.drink_prompt_at(Vector3.ZERO), "Dry/saltwater advertised drinking.")
		bed.global_basis = player.global_basis
		bed.global_position = -player.up_direction * 1.1
		await physics_frame
		ray.global_position = player.up_direction
		ray.target_position = ray.global_basis.inverse() * (-player.up_direction * 2.1)
		ray.force_raycast_update()
		_check(ray.is_colliding(), "Dry/saltwater HUD fixture missed its physical ground.")
		context._update_context()
		if DisplayServer.get_name() != "headless":
			_check(not context._label.visible, "Dry/saltwater retained the visible drink hint.")
		player.current_thirst = 20
		player._try_drink_water(Vector3.ZERO)
		_check(player.current_thirst == 20, "Dry/saltwater restored thirst.")
	adapter.close()
	stage.free()
	current_scene = null
	await _finish()

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish() -> void:
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("INT30_DRINK_CONTRACT_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
