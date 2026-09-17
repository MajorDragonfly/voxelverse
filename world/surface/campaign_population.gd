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
const Colony = preload("res://world/surface/wildlife_colony.gd")
const WildNest = preload("res://world/resources/nests/wildlife_nest.gd")
const MAX_NESTS: int = 6
const MAX_ANIMALS: int = 12
const MAX_PLANTS: int = 16
const ACTIVE_DISTANCE: float = 82.0
# Failed floor/shape checks are work too. Rotate blocked candidates instead
# of scanning every stored individual in the same quarter-second update.
const MAX_SPAWN_ATTEMPTS: int = 2
# One point per existing spawn attempt: saved point, then two nearby rings.
const RESTORE_POINTS: int = 17
var _spawn_offsets: Dictionary = {}
var _spawn_origins: Dictionary = {}
var animals: Dictionary = {}
var plants: Dictionary = {}
var nests: Dictionary = {}
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
	elif not _upgrade_catalog(): return
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
	_prioritize_catalog(candidates)
	_spawn_candidates(candidates, plant_candidates)
	_sync_nests(wanted)
	peak_animals = maxi(peak_animals, animals.size())

func _spawn_candidates(candidates: Array[Dictionary], plant_candidates: Array[Dictionary]) -> void:
	last_spawn_attempts = 0
	var pending: Dictionary = {}
	for record: Dictionary in candidates: pending[record.id] = true
	for id: String in _spawn_offsets.keys():
		if not pending.has(id):
			_spawn_offsets.erase(id)
			_spawn_origins.erase(id)
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

func _prioritize_catalog(candidates: Array[Dictionary]) -> void:
	var represented: Dictionary = {}
	for actor: Node in animals.values():
		var species_id: String = str(actor.catalog_species.get("id", ""))
		if not species_id.is_empty(): represented[species_id] = int(represented.get(species_id, 0)) + 1
	var priority: Callable = func(record: Dictionary) -> int:
		if not record.has("catalog_species_id"): return 2
		var encounter: Dictionary = record.get("encounter", {})
		if encounter.get("dead", false) and float(encounter.get("carcass_food", 0.0)) <= 0.0: return 2
		return 1 if represented.has(record.catalog_species_id) else 0
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if priority.call(a) != priority.call(b): return priority.call(a) < priority.call(b)
		return Space.resolve(self, a.location).distance_squared_to(player.global_position) < Space.resolve(self, b.location).distance_squared_to(player.global_position))
	if animals.size() < MAX_ANIMALS or candidates.is_empty() or priority.call(candidates[0]) != 0: return
	# A full old population must not starve the additive fourth role. Preserve
	# the sole nearby representative of each other role; unload one ordinary
	# animal or duplicate through the existing capture/streaming path.
	# Keep the animal under the player's camera stable through scanning and
	# returning from its journal. Another ordinary animal can release the slot.
	var focused: Node = player.get_scan_target() if is_instance_valid(player) and player.has_method("get_scan_target") else null
	for id: String in animals:
		if animals[id] == focused: continue
		var species_id: String = str(animals[id].catalog_species.get("id", ""))
		if not species_id.is_empty() and int(represented.get(species_id, 0)) <= 1: continue
		_capture_one(id)
		_remove(animals, id)
		# The freed slot belongs to the missing role at the front of this queue.
		# A cursor retained from another region must not refill it with a duplicate.
		_animal_cursor = 0
		return

func _place_value(point: Dictionary) -> Dictionary:
	var result: Dictionary = point.duplicate(true)
	result["radius"] = descriptor.radius
	return result

func _generate(cell: Dictionary) -> void:
	var region: Dictionary = storage.region(cell.id)
	if region.is_empty(): return
	if region.generated:
		# Upgrade only the original ordinary resident, even after it migrated.
		if not region.has("colony"):
			var center: Dictionary = Cube.address(descriptor.id, cell.face, -1.0 + (cell.x + 0.5) * cell.step, -1.0 + (cell.y + 0.5) * cell.step)
			var original_id: String = Ids.scoped("object", Habitat.region_id(descriptor.id, center), cell.id + ":resident")
			Colony.ensure(self, region, storage.record(original_id))
		return
	region.generated = true
	var point: Dictionary = Cube.address(descriptor.id, cell.face, -1.0 + (cell.x + 0.5) * cell.step, -1.0 + (cell.y + 0.5) * cell.step)
	point.height = adapter.sample(point).height
	if not Planner.dry(adapter.terrain.surface, point): return
	point = _place_value(point)
	var seed_value: int = maxi(1, int((cell.id + ":species:" + str(descriptor.seed)).sha256_text().left(7).hex_to_int()))
	var individual: int = int((cell.id + ":animal").sha256_text().left(7).hex_to_int())
	var role: String = "grazer" if posmod(seed_value, 4) != 0 else "predator"
	# Only newly generated regions receive this minority role. Existing records,
	# frozen bodies and species identities remain the authoritative population.
	if posmod(seed_value, 16) == 1: role = "scavenger"
	var blueprint: Dictionary = Species.create_species(seed_value, Vector2i.ZERO, role)
	var region_id: String = Habitat.region_id(descriptor.id, point)
	var id: String = Ids.scoped("object", region_id, cell.id + ":resident")
	var identity := {"object_id": id, "species_id": Ids.scoped("species", descriptor.id, str(seed_value)), "body_id": descriptor.id,
		"region_id": region_id, "habitat_cell": cell.id.sha256_text().left(32), "species_seed": seed_value,
		"design_ref": {"design_id": blueprint.get("design_id", ""), "revision": 0}}
	storage.put({"id": id, "identity": identity, "location": point, "home": point.duplicate(true),
		"species_seed": seed_value, "individual_seed": individual, "role": role, "blueprint": Encoding.encode(blueprint)})
	Colony.ensure(self, region, storage.record(id))
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
	var point: Vector3 = _restore_position(record, species) if not encounter.get("dead", false) else _spawn_position(Space.resolve(self, record.location), species)
	if not point.is_finite(): return false
	var actor: CharacterBody3D = preload("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	actor.configure(int(record.species_seed), int(record.individual_seed), Vector2i.ZERO, record.role, record.identity.get("habitat_cell", ""), species)
	actor.supplied_identity = record.identity.duplicate(true)
	actor.frozen_blueprint = Encoding.decode(record.blueprint)
	actor.colony_id = str(record.get("colony_id", ""))
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

func _restore_position(record: Dictionary, species: Dictionary) -> Vector3:
	# Scenery or a building may now occupy a saved animal's exact position.
	# Retry within four metres without changing its identity, body or home.
	# Never scan the whole neighborhood in a single quarter-second update.
	# A changed canonical location invalidates the previous search. Retrying
	# an old offset can skip the now-clear exact point and hit another obstacle.
	# Store canonical coordinates so an origin rebase does not reset progress.
	var same_origin: bool = _spawn_origins.get(record.id) == record.location
	var attempt: int = int(_spawn_offsets.get(record.id, 0)) if same_origin else 0
	var candidate: Vector3 = Space.resolve(self, record.location)
	if attempt > 0:
		var angle: float = float((attempt - 1) % 8) * TAU / 8.0
		var distance: float = 2.0 if attempt <= 8 else 4.0
		candidate = Space.offset(self, candidate, Vector3(cos(angle), 0, sin(angle)) * distance)
	var point: Vector3 = _spawn_position(candidate, species, {}, attempt > 0)
	if point.is_finite():
		_spawn_offsets.erase(record.id)
		_spawn_origins.erase(record.id)
	else:
		_spawn_offsets[record.id] = (attempt + 1) % RESTORE_POINTS
		if not same_origin: _spawn_origins[record.id] = record.location.duplicate(true)
	return point

func _spawn_position(saved: Vector3, species: Dictionary = {}, diagnostic: Dictionary = {}, relocated: bool = false) -> Vector3:
	var inspect: bool = not diagnostic.is_empty()
	var ready: bool = Space.ground_ready(self, saved)
	if inspect: diagnostic.ground_ready = ready
	if not ready: return Vector3.INF
	var hit: Dictionary = Space.floor_hit(player, saved)
	if inspect: diagnostic.floor_found = not hit.is_empty()
	if hit.is_empty(): return Vector3.INF
	var up: Vector3 = Space.up(self, hit.position)
	var floor_point: Vector3 = hit.position + up * 0.03
	if relocated and (not Space.dry(self, floor_point) or hit.normal.dot(up) < 0.94): return Vector3.INF
	var geometry: Dictionary = Wildlife.collision_geometry(species)
	var shape := CapsuleShape3D.new()
	shape.radius = geometry.radius
	shape.height = geometry.height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1 | 2 | 4 | 8
	query.transform = Transform3D(Space.frame(self, floor_point), floor_point + up * float(geometry.center))
	var collisions: Array[Dictionary] = player.get_world_3d().direct_space_state.intersect_shape(query, 4 if inspect else 1)
	if inspect: diagnostic.obstacles = collisions.map(func(value: Dictionary) -> String: return str(value.collider.get_path()))
	return floor_point if collisions.is_empty() else Vector3.INF

func _spawn_plant(record: Dictionary) -> bool:
	var point: Vector3 = Space.resolve(self, record.location)
	if not Space.ground_ready(self, point): return false
	var bush: Node3D = preload("res://world/resources/plants/berry_bush.tscn").instantiate()
	bush.snap_to_terrain = false
	bush.persistent_food_key = record.food_key
	bush.visual_profile = adapter.terrain.surface.terrain
	bush.visual_biome = str(adapter.terrain.surface.sample(record.location).biome)
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
	_spawn_offsets.clear()
	_spawn_origins.clear()
	_plant_cursor = 0
	_prefer_plant = true
	last_spawn_attempts = 0
	for id in animals.keys(): _remove(animals, id)
	for id in plants.keys(): _remove(plants, id)
	for id in nests.keys(): _remove(nests, id)
	records.clear()
	storage = preload("res://world/surface/campaign_region_storage.gd").new()
	storage_error = ""
	if not storage.open(self, descriptor): _storage_failed(); return
	if not _upgrade_catalog(): return
	planner = null
	if body().get("fauna_catalog", {}).get("habitat_status") == "pending":
		planner = Planner.new()
		planner.begin(adapter.terrain.surface, body().fauna_catalog)

func _upgrade_catalog() -> bool:
	var record: Dictionary = body()
	var catalog: Dictionary = record.get("fauna_catalog", {})
	if catalog.get("schema") == Catalog.ROLE_SCHEMA: return true
	var used: Dictionary = {}
	for entry: Dictionary in get_node("/root/ProgressionService").discovered_species.values():
		if entry.get("body_id") == descriptor.id: used[int(entry.get("species_seed", 0))] = true
	var upgraded: Dictionary = Catalog.upgrade_surface(catalog, descriptor, used)
	if upgraded.is_empty():
		storage.store._fail("Pflichtarten konnten nicht verlustfrei ergänzt werden.")
		_storage_failed()
		return false
	record.fauna_catalog = upgraded
	get_node("/root/SaveGameService").schedule_autosave()
	return true

func _exit_tree() -> void:
	# The scene owns these siblings and is already removing them. Only detach
	# their origin bindings here; normal eviction removes physical nodes earlier.
	for collection in [animals, plants, nests]:
		for actor in collection.values():
			if is_instance_valid(actor): Space.untrack(actor)
	animals.clear()
	plants.clear()
	nests.clear()
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

func _sync_nests(wanted: Dictionary) -> void:
	for id: String in nests.keys():
		if nests[id].global_position.distance_to(player.global_position) > ACTIVE_DISTANCE + 12.0: _remove(nests, id)
	var created: bool = false
	for key: String in wanted:
		var colony: Dictionary = storage.region(key, false).get("colony", {})
		if colony.is_empty(): continue
		var point: Vector3 = Space.resolve(self, colony.anchor)
		if point.distance_to(player.global_position) > ACTIVE_DISTANCE: continue
		if not nests.has(colony.id):
			if created or nests.size() >= MAX_NESTS or not Space.ground_ready(self, point): continue
			var hit: Dictionary = Space.floor_hit(player, point)
			if hit.is_empty(): continue
			var nest := WildNest.new()
			nest.position = hit.position + Space.up(self, point) * 0.03
			get_parent().add_child(nest)
			Space.orient(nest)
			nest.setup(colony, adapter.terrain.surface.terrain, str(adapter.sample(colony.anchor).biome))
			Space.track(nest, colony.id)
			nests[colony.id] = nest
			created = true
		var living: int = 0
		for member: String in colony.members:
			if not storage.record(member).get("encounter", {}).get("dead", false): living += 1
		nests[colony.id].refresh(player, living)
