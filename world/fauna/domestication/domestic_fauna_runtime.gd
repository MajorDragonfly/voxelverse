extends RefCounted
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Planner = preload("res://world/fauna/domestication/domestic_habitat_planner.gd")
const BodyEvidence = preload("res://world/fauna/domestication/domestic_body_evidence.gd")
const Recovery = preload("res://world/fauna/domestication/domestic_habitat_recovery.gd")
const Bush = preload("res://world/resources/plants/berry_bush.tscn")
var catalog: Dictionary = {}
var planner: RefCounted
var recovery: RefCounted
var next_recovery_save: int = 0
var body_check_usec: Dictionary = {}
var body_id: String = ""
var plants: Dictionary = {}
var next_food_retry: int = 0
## D2 can reserve individuals that are owned/persistent outside this streamer.
var object_is_reserved: Callable

func reset(streamer: Node3D) -> void:
	catalog = {}
	planner = null
	recovery = null
	next_recovery_save = 0
	body_check_usec.clear()
	body_id = ""
	for fauna in streamer._active_fauna:
		if is_instance_valid(fauna) and not fauna.catalog_species.is_empty(): fauna.queue_free()
	for plant in plants.values():
		if is_instance_valid(plant): plant.queue_free()
	plants.clear()

func update(streamer: Node3D) -> void:
	var state: Node = streamer.get_node("/root/GameState")
	var scene: Node = streamer.get_tree().current_scene
	var manager: Node = scene.get_node_or_null("WorldManager") if scene != null else null
	if manager == null or not bool(manager.get("world_initialized")): return
	var body_key: String = str(int(state.get_world_seed()))
	var current_body: Dictionary = state.campaign.data["bodies"].get(body_key, {})
	if current_body.is_empty(): current_body = state.get_current_body()
	if body_id != str(current_body["id"]):
		reset(streamer)
		body_id = current_body["id"]
		catalog = Catalog.ensure(state)
		if not catalog.is_empty() and catalog["habitat_status"] == "pending":
			planner = Planner.new()
			planner.begin(streamer.get_node("/root/WorldGenerator"))
	if planner != null:
		planner.step(streamer.get_node("/root/WorldGenerator"), catalog, 2)
		if planner.finished:
			catalog["habitats"] = planner.habitats
			catalog["habitat_status"] = "ready" if planner.habitats.size() >= 3 else "unavailable"
			planner = null
			streamer.get_node("/root/SaveGameService").schedule_autosave()
	if catalog.is_empty(): return
	if catalog["habitat_status"] == "unavailable":
		if recovery == null:
			recovery = Recovery.new()
			recovery.begin(streamer.get_node("/root/WorldGenerator"), catalog)
		if recovery.data["status"] == "searching":
			recovery.step(streamer.get_node("/root/WorldGenerator"), catalog, 16, 2000)
			# In-memory progress is always in the campaign; batch disk scheduling.
			if Time.get_ticks_msec() >= next_recovery_save or recovery.data["status"] != "searching":
				next_recovery_save = Time.get_ticks_msec() + 5000
				streamer.get_node("/root/SaveGameService").schedule_autosave()
	var now: float = state.campaign.data["elapsed_seconds"]
	for habitat: Dictionary in catalog["habitats"]:
		var identity: String = Catalog.object_id(state, habitat)
		if object_is_reserved.is_valid() and bool(object_is_reserved.call(identity)): continue
		var encounter: Dictionary = streamer.get_node("/root/ProgressionService").get_saved_creature_encounter(identity)
		if not bool(encounter.get("dead", false)): continue
		if float(habitat["replacement_at"]) == 0.0:
			habitat["replacement_at"] = now + Catalog.REPLACEMENT_SECONDS
		elif now >= float(habitat["replacement_at"]):
			# New representative, new object ID. Tombstones and rewards stay closed.
			habitat["generation"] = int(habitat["generation"]) + 1
			habitat["replacement_at"] = 0.0
	if Time.get_ticks_msec() >= next_food_retry:
		next_food_retry = Time.get_ticks_msec() + 1000
		for animal in streamer._active_fauna:
			if not is_instance_valid(animal) or animal.is_queued_for_deletion() or animal.is_dead or animal.catalog_species.is_empty(): continue
			for habitat: Dictionary in catalog["habitats"]:
				if Catalog.object_id(state, habitat) == animal.get_campaign_identity()["object_id"] and not plants.has(habitat["key"]):
					_ensure_food(streamer, streamer.get_node("/root/WorldGenerator"), habitat, animal.global_position)
					break
	for key in plants.keys():
		var plant: Node3D = plants[key]
		if not is_instance_valid(plant): plants.erase(key)
		elif plant.global_position.distance_to(streamer._player.global_position) > streamer.despawn_radius:
			plant.queue_free()
			plants.erase(key)

func try_spawn(streamer: Node3D) -> bool:
	if catalog.is_empty() or catalog["habitat_status"] != "ready": return false
	var state: Node = streamer.get_node("/root/GameState")
	var generator: Node = streamer.get_node("/root/WorldGenerator")
	var occupied: Array = []
	for animal in streamer._active_fauna:
		if is_instance_valid(animal) and not animal.is_queued_for_deletion() and not animal.is_dead and not animal.catalog_species.is_empty():
			occupied.append(animal.catalog_species["id"])
	for habitat: Dictionary in catalog["habitats"]:
		if habitat["species_id"] in occupied or float(habitat["replacement_at"]) > 0.0: continue
		var object_identity: String = Catalog.object_id(state, habitat)
		if streamer._has_active_identity(object_identity) or (object_is_reserved.is_valid() and bool(object_is_reserved.call(object_identity))): continue
		var p: Array = habitat["position"]
		var point := Vector3(p[0], p[1], p[2])
		var distance: float = point.distance_to(streamer._player.global_position)
		if distance > minf(streamer.despawn_radius - 4.0, maxf(streamer.maximum_spawn_radius, 40.0)) or distance < streamer.minimum_spawn_radius: continue
		var entry: Dictionary = Catalog.species_for(catalog, habitat["species_id"])
		if entry.has("body_evidence") and not BodyEvidence.approved(entry): continue
		var floor: Dictionary = habitat_placement(streamer, generator, habitat, float(entry["visual_scale"]))
		if floor.is_empty(): continue
		# Reserve three of the existing population slots; ordinary fauna cannot
		# indefinitely starve a mandatory role. The global maximum stays intact.
		var victim: Node3D = null
		if streamer._active_fauna.size() >= mini(streamer.target_population, streamer.maximum_population):
			for animal in streamer._active_fauna:
				if is_instance_valid(animal) and (animal.catalog_species.is_empty() or animal.is_dead):
					if victim == null or animal.global_position.distance_squared_to(streamer._player.global_position) > victim.global_position.distance_squared_to(streamer._player.global_position): victim = animal
			if victim == null: return false
		var animal: Node3D = streamer.WILDLIFE_SCENE.instantiate()
		var region := Vector2i(floori(point.x / 256.0), floori(point.z / 256.0))
		var individual_seed: int = int(object_identity.sha256_text().left(8).hex_to_int() % 2147483647)
		animal.configure(int(entry["species_seed"]), individual_seed, region, entry["role"], Catalog.cell_key(habitat), entry)
		streamer.add_child(animal)
		if not entry.has("body_evidence"):
			for species: Dictionary in catalog["species"]:
				if species["id"] != entry["id"]: continue
				var started: int = Time.get_ticks_usec()
				BodyEvidence.confirm(species, streamer, animal._preview)
				body_check_usec[species["id"]] = Time.get_ticks_usec() - started
				entry["body_evidence"] = species["body_evidence"].duplicate(true)
				animal.catalog_species["body_evidence"] = entry["body_evidence"].duplicate(true)
				streamer.get_node("/root/SaveGameService").schedule_autosave()
				break
		if not BodyEvidence.approved(entry):
			animal.free()
			return false
		if victim != null:
			streamer._active_fauna.erase(victim)
			victim.queue_free()
		animal.global_position = floor["position"] + Vector3.UP * 0.05
		habitat["spawn_position"] = [floor["position"].x, floor["position"].y, floor["position"].z]
		streamer._active_fauna.append(animal)
		_ensure_food(streamer, generator, habitat, floor["position"])
		return true
	return false

func _ensure_food(streamer: Node3D, generator: Node, habitat: Dictionary, origin: Vector3) -> void:
	if plants.has(habitat["key"]) and is_instance_valid(plants[habitat["key"]]): return
	if plants.size() >= 6: return
	var anchor: Array = habitat.get("spawn_position", habitat["position"])
	origin = Vector3(anchor[0], anchor[1], anchor[2])
	for i in range(64):
		var point: Vector3 = origin + Vector3(cos(i * TAU / 16), 0, sin(i * TAU / 16)) * (3.0 + float(i / 16) * 2.0)
		point.y = generator.get_visual_terrain_height(point.x, point.z)
		if not Planner.dry(generator, point) or Planner.land_path(generator, origin, point).is_empty(): continue
		var floor: Dictionary = placement(streamer, point, 0.88)
		if floor.is_empty(): continue
		var bush: Node3D = Bush.instantiate()
		bush.snap_to_terrain = false
		streamer.add_child(bush)
		bush.global_position = floor["position"]
		plants[habitat["key"]] = bush
		return

static func habitat_placement(streamer: Node3D, generator: Node, habitat: Dictionary, visual_scale: float) -> Dictionary:
	var p: Array = habitat.get("spawn_position", habitat["position"])
	var origin := Vector3(p[0], p[1], p[2])
	var floor: Dictionary = placement(streamer, origin, visual_scale)
	if not floor.is_empty() or habitat.has("spawn_position"): return floor
	# Terrain routes predate loaded trees/rocks. Try a small deterministic patch;
	# keep the first actual placement in the save instead of changing identity.
	for i in range(24):
		var point: Vector3 = origin + Vector3(cos(i * TAU / 8), 0, sin(i * TAU / 8)) * (1.5 + float(i / 8) * 1.5)
		point.y = generator.get_visual_terrain_height(point.x, point.z)
		if not Planner.dry(generator, point) or Planner.land_path(generator, origin, point).is_empty(): continue
		floor = placement(streamer, point, visual_scale)
		if not floor.is_empty(): return floor
	return {}

static func placement(streamer: Node3D, point: Vector3, visual_scale: float) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = streamer.get_world_3d().direct_space_state
	var floor: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.0, point - Vector3.UP * 1.0, 1))
	if floor.is_empty() or absf(floor["position"].y - point.y) > 0.5 or floor["normal"].dot(Vector3.UP) < 0.9: return {}
	var shape := CapsuleShape3D.new()
	shape.radius = maxf(0.34, visual_scale * 0.72)
	shape.height = maxf(1.15, visual_scale * 1.95)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, floor["position"] + Vector3.UP * (shape.height * 0.5 + 0.06))
	query.collision_mask = 1 | 2 | 4
	if not space.intersect_shape(query, 1).is_empty(): return {}
	return floor
