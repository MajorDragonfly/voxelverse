extends SceneTree
const World = preload("res://world/planet_lab/living_planet.gd")
const Save = preload("res://world/surface/living_planet_store.gd")
const Contract = preload("res://world/fauna/domestication/domestic_surface_contract.gd")
const Evidence = preload("res://world/fauna/domestication/domestic_body_evidence.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var failures: Array[String] = []
var metrics: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("SaveGameService").autosave_enabled = false
	var campaign_before: String = JSON.stringify(root.get_node("GameState").campaign.export_state())
	var world := World.new()
	world.store_path = "user://d12-runtime.json"
	root.add_child(world)
	current_scene = world
	world.walker.enabled = false
	await populate(world)
	var catalog: Dictionary = world.ecosystem.domestic.catalog
	metrics.search_status = catalog.habitat_status
	metrics.search_nodes = catalog.surface_search.nodes.size()
	metrics.blocked_placements = world.ecosystem.domestic.blocked_placements
	metrics.max_search_ms = world.ecosystem.domestic.max_search_ms
	metrics.max_body_check_ms = world.ecosystem.domestic.max_body_check_ms
	metrics.animals = world.ecosystem.animals.size()
	metrics.domestic = world.ecosystem.domestic.individuals.size()
	metrics.food = world.ecosystem.domestic.plants.size()
	var floor_contacts: int = 0
	var movement: float = 0.0
	for tick in range(180):
		await physics_frame
		for id: String in world.ecosystem.animals:
			if world.ecosystem.domestic.owns(id):
				var animal: Node = world.ecosystem.animals[id]
				floor_contacts += int(animal.is_on_floor())
				expect(animal.basis.y.dot(world.adapter.up_at(world.adapter.location(animal))) > 0.999, "Animal lost radial up")
				expect(Evidence.approved(animal.catalog_species), "Unverified body became active")
				expect(animal.speed == animal.catalog_species.domestication.movement_speed, "Movement ignores D1 traits")
		expect(world.ecosystem.animals.size() <= 4, "Existing four-animal budget exceeded")
	for id: String in world.ecosystem.animals:
		if world.ecosystem.domestic.owns(id): movement += world.ecosystem.animals[id].traveled
	expect(floor_contacts >= 450, "Spherical domestic animals lack physical floor contacts")
	expect(movement > 6.0, "Spherical domestic animals do not move physically")
	# Walk the actual player from the landing marker along every saved route.
	var reached: int = 0
	world.set_paused(true)
	for habitat: Dictionary in catalog.habitats:
		world.walker.place(world.records[world.body_id].spawn)
		world.walker.enabled = true
		world.walker.automatic = true
		world.walker.speed = 4.0
		var arrived: bool = true
		var approached: bool = false
		var target_animal: Node3D = world.ecosystem.animals[Contract.object_id(habitat)]
		for waypoint: Dictionary in habitat.path:
			var point: Vector3 = world.adapter.to_local(waypoint)
			var final: bool = waypoint == habitat.path[-1]
			var close: bool = false
			for tick in range(120):
				if world.walker.position.distance_to(target_animal.position) <= 3.0:
					approached = true
					close = true
					break
				var up: Vector3 = world.walker.up_direction
				var delta: Vector3 = (point - world.walker.position).slide(up)
				if delta.length() < (2.6 if final else 0.8):
					close = true
					break
				world.walker.orbit_axis = up.cross(delta.normalized()).normalized()
				await physics_frame
			if approached: break
			if not close:
				arrived = false
				break
		if arrived and world.walker.position.distance_to(target_animal.position) <= 3.0: reached += 1
		world.walker.enabled = false
		world.walker.automatic = false
	expect(reached == 4, "Player cannot physically approach all four mandatory habitats")
	metrics.physically_reached_habitats = reached
	world.walker.place(world.records[world.body_id].spawn)
	metrics.floor_contacts = floor_contacts
	metrics.movement_m = movement
	world.set_paused(true)
	expect(world.save_lab(), "D12 save failed")
	var snapshot: Dictionary = Save.read(world.store_path).data
	expect(not snapshot.is_empty() and snapshot.schema == Save.SCHEMA, "Spherical save lacks the current header")
	var old_ids: Array = world.ecosystem.domestic.individuals.keys()
	old_ids.sort()
	var frozen: Variant = JSON.parse_string(JSON.stringify(catalog.species))
	expect(world.load_lab(), "D12 reload failed")
	expect(JSON.parse_string(JSON.stringify(world.ecosystem.domestic.catalog.species)) == frozen, "Reload mutated frozen bodies/evidence")
	world.set_paused(false)
	world.walker.enabled = false
	await populate(world)
	expect(same_ids(world.ecosystem.domestic.individuals, old_ids), "Reload replaced domestic identities")
	# Suppress an individual through the shared reservation hook, with no D2 UI.
	if not old_ids.is_empty():
		var reserved: String = old_ids[0]
		world.ecosystem.domestic.object_is_reserved = func(id: String): return id == reserved
		for tick in range(40): await physics_frame
		expect(not world.ecosystem.animals.has(reserved), "Reserved animal duplicated by radial streamer")
		world.ecosystem.domestic.object_is_reserved = Callable()
		await populate(world)
	# A genuine floating-origin transition, followed by unloading and return.
	world.set_paused(true)
	world._capture()
	var before: Dictionary = world.snapshot()
	var origin: Dictionary = world.walker.location()
	var distant: Dictionary = world.adapter.offset(origin, world.walker.basis.x * 220.0, 1.1)
	world.walker.place(distant)
	world.stream_objects()
	world.set_paused(false)
	world.walker.enabled = false
	for tick in range(60): await physics_frame
	var active_domestic: int = 0
	for id: String in world.ecosystem.animals: active_domestic += int(world.ecosystem.domestic.owns(id))
	expect(active_domestic == 0, "Distant domestic animals remain active")
	expect(world.adapter.max_rebase_error_m < 0.001, "Rebase changed body-fixed positions")
	world.set_paused(true)
	world.return_to_marker()
	world.set_paused(false)
	world.walker.enabled = false
	await populate(world)
	expect(same_ids(world.ecosystem.domestic.individuals, old_ids), "Streaming return changed identities")
	world.set_paused(true)
	world._capture()
	expect(JSON.parse_string(JSON.stringify(world.records[world.body_id].fauna_catalog.species)) == frozen, "Streaming regenerated species")
	expect(JSON.stringify(root.get_node("GameState").campaign.export_state()) == campaign_before, "Sphere fauna/food wrote into legacy campaign")
	metrics.before = before.bodies[world.body_id].domestic_fauna
	if "--d12-render" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://d12-fauna.png")
		print("D12_SCREENSHOT ", ProjectSettings.globalize_path("user://d12-fauna.png"))
	world.queue_free()
	await process_frame
	await process_frame
	metrics.failures = failures
	print("D12_RUNTIME ", JSON.stringify(metrics))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func populate(world: Node) -> void:
	for tick in range(1200):
		await physics_frame
		var count: int = 0
		for id: String in world.ecosystem.animals: count += int(world.ecosystem.domestic.owns(id))
		if count == 4 and world.ecosystem.domestic.plants.size() == 4: return
	failures.append("Four live mandatory species and food did not materialize: " + JSON.stringify({"catalog": world.ecosystem.domestic.catalog.habitat_status,
		"individuals": world.ecosystem.domestic.individuals.keys(), "food": world.ecosystem.domestic.plants.size(), "blocked": world.ecosystem.domestic.blocked_placements}))

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func same_ids(individuals: Dictionary, expected: Array) -> bool:
	var ids: Array = individuals.keys()
	ids.sort()
	return ids == expected
