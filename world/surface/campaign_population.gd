extends Node
## One bounded physical owner around the observer. Unloaded individuals retain
## canonical records; social/needs/owned-animal services keep their authority.
const Model = preload("res://world/surface/campaign_population_state.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Habitat = preload("res://world/fauna/domestication/domestic_surface_contract.gd")
const Planner = preload("res://world/fauna/domestication/domestic_surface_planner.gd")
const Evidence = preload("res://world/fauna/domestication/domestic_body_evidence.gd")
const Encoding = preload("res://world/fauna/domestication/domestication_contract.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Wildlife = preload("res://creatures/wildlife/procedural_wildlife_v7.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const MAX_ANIMALS: int = 12
const MAX_PLANTS: int = 16
const ACTIVE_DISTANCE: float = 82.0
# Failed floor/shape checks are work too. Rotate blocked candidates instead
# of scanning every stored individual in the same quarter-second update.
const MAX_SPAWN_ATTEMPTS: int = 2
var animals: Dictionary = {}
var plants: Dictionary = {}
var records: Dictionary = {}
var adapter: RefCounted
var player: CharacterBody3D
var descriptor: Dictionary
var planner: RefCounted
var _timer: float = 0.0
var _generation_cursor: int = 0
var peak_animals: int = 0
var max_frame_work_ms: float = 0.0
var storage := preload("res://world/surface/campaign_region_storage.gd").new()
var storage_error: String = ""
var _animal_cursor: int = 0
var _plant_cursor: int = 0
var _prefer_plant: bool = true
var last_spawn_attempts: int = 0
var peak_spawn_attempts: int = 0
var max_spawn_attempt_ms: float = 0.0

func body() -> Dictionary:
	var state := get_node("/root/GameState")
	return state.get_current_body_record()

func _ready() -> void:
	var record: Dictionary = body()
	if not record.has("surface_population"): record.surface_population = Model.create(record.id)
	if not storage.open(self, descriptor):
		_storage_failed()
		return
	if not record.has("fauna_catalog"):
		var anchor: Dictionary = record.surface_context.spawn.duplicate(true)
		anchor.height = adapter.sample(anchor).height
		record.fauna_catalog = Catalog.create_surface(descriptor, anchor)
	if record.get("fauna_catalog", {}).get("habitat_status") == "pending":
		planner = Planner.new()
		planner.begin(adapter.terrain.surface, record.fauna_catalog)
	get_node("/root/SaveGameService").save_started.connect(capture)
	get_node("/root/SaveGameService").game_loaded.connect(_loaded)
	add_to_group(&"campaign_surface_population")

func _process(delta: float) -> void:
	if not storage_error.is_empty() or get_node("/root/SessionFlow").loading or not get_parent().world_initialized: return
	var started: int = Time.get_ticks_usec()
	if planner != null and body().fauna_catalog.habitat_status == "pending": planner.step(body().fauna_catalog)
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.25
		_tick()
		if not storage.store.last_error.is_empty(): _storage_failed()
	max_frame_work_ms = maxf(max_frame_work_ms, (Time.get_ticks_usec() - started) / 1000.0)

func _tick() -> void:
	var wanted: Dictionary = Model.Cells.nearby(descriptor, player.location())
	var active_keys: Array = wanted.keys()
	for record: Dictionary in records.values(): active_keys.append(Model.cell(descriptor, record.location).id)
	storage.pin(active_keys)
	for habitat: Dictionary in body().fauna_catalog.habitats:
		var id: String = Habitat.object_id(habitat)
		var encounter: Dictionary = saved_encounter(id)
		if not _reserved(id) and encounter.get("dead", false):
			var now: float = get_node("/root/GameState").campaign.data.elapsed_seconds
			if habitat.replacement_at == 0: habitat.replacement_at = now + Catalog.REPLACEMENT_SECONDS
			elif now >= habitat.replacement_at:
				habitat.generation += 1
				habitat.replacement_at = 0.0
				id = Habitat.object_id(habitat)
		if not storage.record(id).is_empty(): continue
		var species: Dictionary = Catalog.species_for(body().fauna_catalog, habitat.species_id)
		var identity := {"object_id": id, "species_id": species.id, "body_id": descriptor.id,
			"region_id": habitat.region_id, "habitat_cell": "d1:" + habitat.key + ":" + str(int(habitat.generation)), "species_seed": species.species_seed,
			"design_ref": {"design_id": species.blueprint.get("design_id", ""), "revision": 0}}
		var point: Dictionary = _place_value(habitat.get("spawn_position", habitat.position))
		storage.put({"id": id, "identity": identity, "location": point,
			"home": point.duplicate(true), "species_seed": species.species_seed, "individual_seed": int(id.sha256_text().left(7).hex_to_int()),
			"role": species.role, "blueprint": species.blueprint.duplicate(true), "catalog_species_id": species.id})
		var food_id: String = id + ":food"
		storage.put({"id": food_id, "location": _place_value(habitat.food_position), "food_key": food_id}, true)
	var keys: Array = wanted.keys()
	if not keys.is_empty():
		_generation_cursor %= keys.size()
		_generate(wanted[keys[_generation_cursor]])
		_generation_cursor += 1
	for id in animals.keys():
		if not is_instance_valid(animals[id]): animals.erase(id); continue
		if animals[id].global_position.distance_to(player.global_position) > ACTIVE_DISTANCE + 12.0 or _reserved(id):
			_capture_one(id)
			_remove(animals, id)
	for id in plants.keys():
		if not is_instance_valid(plants[id]): plants.erase(id); continue
		if plants[id].global_position.distance_to(player.global_position) > ACTIVE_DISTANCE + 12.0: _remove(plants, id)
	var candidates: Array[Dictionary] = []
	var plant_candidates: Array[Dictionary] = []
	for key in wanted:
		var region: Dictionary = storage.region(key, false)
		if region.is_empty(): continue
		for record: Dictionary in region.objects.values():
			if not animals.has(record.id) and not _reserved(record.id) and Space.resolve(self, record.location).distance_to(player.global_position) < ACTIVE_DISTANCE:
				candidates.append(record)
		for record: Dictionary in region.plants.values():
			if not plants.has(record.id) and plants.size() < MAX_PLANTS and Space.resolve(self, record.location).distance_to(player.global_position) < ACTIVE_DISTANCE:
				plant_candidates.append(record)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.has("catalog_species_id") != b.has("catalog_species_id"): return a.has("catalog_species_id")
		return Space.resolve(self, a.location).distance_squared_to(player.global_position) < Space.resolve(self, b.location).distance_squared_to(player.global_position))
	_spawn_candidates(candidates, plant_candidates)
	peak_animals = maxi(peak_animals, animals.size())

func _spawn_candidates(candidates: Array[Dictionary], plant_candidates: Array[Dictionary]) -> void:
	last_spawn_attempts = 0
	if animals.size() >= MAX_ANIMALS: candidates = []
	if plants.size() >= MAX_PLANTS: plant_candidates = []
	var animal_attempts: int = 0
	var plant_attempts: int = 0
	while last_spawn_attempts < MAX_SPAWN_ATTEMPTS:
		var has_animal: bool = animal_attempts < candidates.size()
		var has_plant: bool = plant_attempts < plant_candidates.size()
		if not has_animal and not has_plant: break
		var choose_plant: bool = has_plant and (_prefer_plant or not has_animal)
		var started: int = Time.get_ticks_usec()
		var spawned: bool
		if choose_plant:
			_plant_cursor %= plant_candidates.size()
			spawned = _spawn_plant(plant_candidates[_plant_cursor])
			# A successful candidate disappears next tick: its successor now
			# occupies the same slot. Failed candidates advance to avoid stalls.
			if not spawned: _plant_cursor += 1
			plant_attempts += 1
		else:
			_animal_cursor %= candidates.size()
			spawned = _spawn_animal(candidates[_animal_cursor])
			if not spawned: _animal_cursor += 1
			animal_attempts += 1
		_prefer_plant = not choose_plant
		last_spawn_attempts += 1
		max_spawn_attempt_ms = maxf(max_spawn_attempt_ms, (Time.get_ticks_usec() - started) / 1000.0)
		# At most one actor/plant construction succeeds per update.
		if spawned: break
	peak_spawn_attempts = maxi(peak_spawn_attempts, last_spawn_attempts)

func _place_value(point: Dictionary) -> Dictionary:
	var result: Dictionary = point.duplicate(true)
	result["radius"] = descriptor.radius
	return result

func _generate(cell: Dictionary) -> void:
	var region: Dictionary = storage.region(cell.id)
	if region.is_empty() or region.generated: return
	region.generated = true
	var point: Dictionary = Cube.address(descriptor.id, cell.face, -1.0 + (cell.x + 0.5) * cell.step, -1.0 + (cell.y + 0.5) * cell.step)
	point.height = adapter.sample(point).height
	if not Planner.dry(adapter.terrain.surface, point): return
	point = _place_value(point)
	var seed_value: int = maxi(1, int((cell.id + ":species:" + str(descriptor.seed)).sha256_text().left(7).hex_to_int()))
	var individual: int = int((cell.id + ":animal").sha256_text().left(7).hex_to_int())
	var role: String = "grazer" if posmod(seed_value, 4) != 0 else "predator"
	var blueprint: Dictionary = Species.create_species(seed_value, Vector2i.ZERO, role)
	var region_id: String = Habitat.region_id(descriptor.id, point)
	var id: String = Ids.scoped("object", region_id, cell.id + ":resident")
	var identity := {"object_id": id, "species_id": Ids.scoped("species", descriptor.id, str(seed_value)), "body_id": descriptor.id,
		"region_id": region_id, "habitat_cell": cell.id.sha256_text().left(32), "species_seed": seed_value,
		"design_ref": {"design_id": blueprint.get("design_id", ""), "revision": 0}}
	storage.put({"id": id, "identity": identity, "location": point, "home": point.duplicate(true),
		"species_seed": seed_value, "individual_seed": individual, "role": role, "blueprint": Encoding.encode(blueprint)})
	var food: Dictionary = adapter.offset(point, adapter.frame_at(point).x * 5.0)
	if Planner.dry(adapter.terrain.surface, food):
		var food_id: String = id + ":food"
		storage.put({"id": food_id, "location": _place_value(food), "food_key": food_id}, true)

func _reserved(id: String) -> bool:
	var own: Dictionary = body().get("domesticated_animals", {})
	return own.get("registry", {}).get("animals", {}).has(id)

func _spawn_animal(record: Dictionary) -> bool:
	var encounter: Dictionary = record.get("encounter", {})
	if encounter.get("dead", false) and float(encounter.get("carcass_food", 0.0)) <= 0: return false
	var species: Dictionary = Catalog.species_for(body().fauna_catalog, str(record.get("catalog_species_id", "")))
	var point: Vector3 = _spawn_position(Space.resolve(self, record.location), species)
	if not point.is_finite(): return false
	var actor: CharacterBody3D = preload("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	actor.configure(int(record.species_seed), int(record.individual_seed), Vector2i.ZERO, record.role, record.identity.get("habitat_cell", ""), species)
	actor.supplied_identity = record.identity.duplicate(true)
	actor.frozen_blueprint = Encoding.decode(record.blueprint)
	actor.position = point
	actor.collision_mask = 1 | 2
	get_parent().add_child(actor)
	Space.track(actor, record.id)
	if not species.is_empty():
		for entry: Dictionary in body().fauna_catalog.species:
			if entry.id != species.id: continue
			if not entry.has("body_evidence"):
				var before: Transform3D = actor._preview.transform
				actor._preview.transform = Transform3D.IDENTITY
				Evidence.confirm(entry, self, actor._preview)
				actor._preview.transform = before
			if not Evidence.approved(entry):
				Space.untrack(actor)
				actor.queue_free()
				return false
	actor._anchor = Space.resolve(self, record.get("home", record.location))
	actor._anchor_ready = true
	if not species.is_empty(): actor.territory_radius = 6.0
	actor._progress_position = point
	records[record.id] = record
	animals[record.id] = actor
	return true

func _spawn_position(saved: Vector3, species: Dictionary = {}) -> Vector3:
	if not Space.ground_ready(self, saved): return Vector3.INF
	var hit: Dictionary = Space.floor_hit(player, saved)
	if hit.is_empty(): return Vector3.INF
	var up: Vector3 = Space.up(self, hit.position)
	var floor_point: Vector3 = hit.position + up * 0.03
	var geometry: Dictionary = Wildlife.collision_geometry(species)
	var shape := CapsuleShape3D.new()
	shape.radius = geometry.radius
	shape.height = geometry.height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1 | 2 | 4 | 8
	query.transform = Transform3D(Space.frame(self, floor_point), floor_point + up * float(geometry.center))
	return floor_point if player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty() else Vector3.INF

func _spawn_plant(record: Dictionary) -> bool:
	var point: Vector3 = Space.resolve(self, record.location)
	if not Space.ground_ready(self, point): return false
	var bush: Node3D = preload("res://world/resources/plants/berry_bush.tscn").instantiate()
	bush.snap_to_terrain = false
	bush.persistent_food_key = record.food_key
	bush.position = point
	get_parent().add_child(bush)
	Space.track(bush, record.id)
	plants[record.id] = bush
	return true

func _capture_one(id: String) -> void:
	if is_instance_valid(animals.get(id)) and records.has(id): storage.move(records[id], Space.encode(self, animals[id].global_position))

func capture(_path: String = "") -> void:
	for id in animals: _capture_one(id)
	if not storage.checkpoint(): _storage_failed()

func _remove(collection: Dictionary, id: String) -> void:
	var node: Node3D = collection[id]
	Space.untrack(node)
	node.get_parent().remove_child(node)
	node.queue_free()
	collection.erase(id)
	records.erase(id)

func _loaded(_path: String) -> void:
	_animal_cursor = 0
	_plant_cursor = 0
	_prefer_plant = true
	last_spawn_attempts = 0
	for id in animals.keys(): _remove(animals, id)
	for id in plants.keys(): _remove(plants, id)
	records.clear()
	storage = preload("res://world/surface/campaign_region_storage.gd").new()
	storage_error = ""
	if not storage.open(self, descriptor): _storage_failed(); return
	planner = null
	if body().get("fauna_catalog", {}).get("habitat_status") == "pending":
		planner = Planner.new()
		planner.begin(adapter.terrain.surface, body().fauna_catalog)

func _exit_tree() -> void:
	# The scene owns these siblings and is already removing them. Only detach
	# their origin bindings here; normal eviction removes physical nodes earlier.
	for collection in [animals, plants]:
		for actor in collection.values():
			if is_instance_valid(actor): Space.untrack(actor)
	animals.clear()
	plants.clear()
	records.clear()

func _storage_failed() -> void:
	storage_error = storage.store.last_error
	if storage_error.is_empty(): storage_error = "Regionsdaten konnten nicht übernommen werden."
	get_node("/root/SaveGameService")._write_blocked = true
	get_node("/root/SessionFlow").call_deferred("_fail_loading", storage_error)

func needs(id: String, kind: String, initial: float) -> Dictionary:
	var record: Dictionary = storage.record(id, kind == "food")
	if record.is_empty(): return {}
	if not record.has(kind):
		record[kind] = {"remaining": initial, "regrow_at": 0.0} if kind == "food" else {"satiety" if kind == "foraging" else "hydration": initial, "seeking": initial < 45.0}
	return record[kind]

func saved_encounter(id: String) -> Dictionary:
	return storage.record(id).get("encounter", {}).duplicate(true)

func store_encounter(id: String, entry: Dictionary) -> bool:
	var record: Dictionary = storage.record(id)
	if record.is_empty(): return false
	if entry.is_empty(): record.erase("encounter")
	else: record.encounter = entry.duplicate(true)
	return true
