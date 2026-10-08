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
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const MAX_NESTS: int = 6
const MAX_ANIMALS: int = 12
const MAX_PLANTS: int = 16
const ACTIVE_DISTANCE: float = 82.0
# Failed floor/shape checks are work too. Rotate blocked candidates instead
# of scanning every stored individual in the same quarter-second update.
const MAX_SPAWN_ATTEMPTS: int = 2
const GENERATION_FRAME_BUDGET_USEC: int = 4000
const SKIN_FRAME_BUDGET_USEC: int = 2000
const SKIN_FRAME_MAX_UNITS: int = 4096
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
var _spawn_after_generation: bool = false
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
var max_spawn_stage_ms: Dictionary = {}
var max_tick_stage_ms: Dictionary = {}
# Opt-in route diagnostics. No retained traces or callback work in gameplay.
var work_probe: Callable
var _skin_job: Model.SkinBuild
var _skin_record: Dictionary = {}
var _skin_ready_id: String = ""
var max_skin_slice_ms: float = 0.0
var skin_jobs_completed: int = 0
var skin_jobs_cancelled: int = 0
var _preview_script: Script = Preview

func _begin_generation_probe() -> int:
	return Time.get_ticks_usec() if work_probe.is_valid() else 0

func _end_generation_probe(label: String, started: int) -> void:
	if started > 0 and work_probe.is_valid():
		work_probe.call("generation", label, started, Time.get_ticks_usec())

func _record_spawn_stage(label: String, started: int) -> void:
	var now: int = Time.get_ticks_usec()
	max_spawn_stage_ms[label] = maxf(float(max_spawn_stage_ms.get(label, 0.0)), (now - started) / 1000.0)
	if work_probe.is_valid(): work_probe.call("spawn", label, started, now)

func _record_tick_stage(label: String, started: int) -> int:
	var now: int = Time.get_ticks_usec()
	max_tick_stage_ms[label] = maxf(float(max_tick_stage_ms.get(label, 0.0)), (now - started) / 1000.0)
	if work_probe.is_valid(): work_probe.call("tick", label, started, now)
	return now

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
	_advance_skin(started)
	max_frame_work_ms = maxf(max_frame_work_ms, (Time.get_ticks_usec() - started) / 1000.0)

func _cancel_skin() -> void:
	_skin_ready_id = ""
	if _skin_job == null: return
	_skin_job.cancel()
	_skin_job = null
	_skin_record = {}
	skin_jobs_cancelled += 1

func _advance_skin(frame_started: int) -> void:
	if _skin_job == null: return
	# Canonical coordinates survive origin rebases. Never retain a local spawn
	# point across frames; floor/ownership checks are repeated at publication.
	if not storage_error.is_empty() or _reserved(_skin_record.id) or _skin_record.get("encounter", {}).get("dead", false) or Space.resolve(self, _skin_record.location).distance_squared_to(player.global_position) >= ACTIVE_DISTANCE * ACTIVE_DISTANCE:
		_cancel_skin()
		return
	var budget: int = SKIN_FRAME_BUDGET_USEC - (Time.get_ticks_usec() - frame_started)
	if budget <= 0: return
	var started: int = Time.get_ticks_usec()
	var complete: bool = _skin_job.advance(budget, SKIN_FRAME_MAX_UNITS)
	var finished: int = Time.get_ticks_usec()
	max_skin_slice_ms = maxf(max_skin_slice_ms, (finished - started) / 1000.0)
	if work_probe.is_valid(): work_probe.call("mesh", "skin_prepare_chunk", started, finished)
	if complete:
		# Only complete immutable geometry enters the existing eight-entry LRU.
		_preview_script.call("remember_species_skin", Encoding.decode(_skin_record.blueprint), _skin_job.mesh)
		_skin_ready_id = _skin_record.id
		_skin_job = null
		_skin_record = {}
		skin_jobs_completed += 1

func _skin_available(record: Dictionary) -> bool:
	# A manually driven/disabled owner cannot advance a deferred job. Preserve
	# the direct spawn contract for those consumers; live streaming owns slices.
	if not is_processing(): return true
	# The narrow shared cache port is supplied by R33-01's product owner patch.
	# Older consumers retain their existing synchronous preview behavior.
	if not _preview_script.has_method("cached_species_skin"): return true
	var design: Dictionary = Encoding.decode(record.blueprint)
	if _preview_script.call("cached_species_skin", design) != null: return true
	if _skin_job == null:
		_skin_record = record
		_skin_job = Model.SkinBuild.new(design)
	return false

func _tick() -> void:
	var stage_started: int = Time.get_ticks_usec()
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
	stage_started = _record_tick_stage("pin_habitats", stage_started)
	var keys: Array = wanted.keys()
	var generation_debt: bool = _spawn_after_generation
	_spawn_after_generation = false
	if not generation_debt and not keys.is_empty():
		_generate(_generation_cell(wanted, player.location()))
	var generation_usec: int = Time.get_ticks_usec() - stage_started
	stage_started = _record_tick_stage("generation", stage_started)
	for id in animals.keys():
		if not is_instance_valid(animals[id]): animals.erase(id); continue
		if animals[id].global_position.distance_to(player.global_position) > ACTIVE_DISTANCE + 12.0 or _reserved(id):
			_capture_one(id)
			_remove(animals, id)
	for id in plants.keys():
		if not is_instance_valid(plants[id]): plants.erase(id); continue
		if plants[id].global_position.distance_to(player.global_position) > ACTIVE_DISTANCE + 12.0: _remove(plants, id)
	stage_started = _record_tick_stage("retire", stage_started)
	var candidates: Array[Dictionary] = []
	var plant_candidates: Array[Dictionary] = []
	var distances: Dictionary = {}
	for key in wanted:
		var region: Dictionary = storage.region(key, false)
		if region.is_empty(): continue
		for record: Dictionary in region.objects.values():
			if animals.has(record.id) or _reserved(record.id): continue
			var distance: float = Space.resolve(self, record.location).distance_squared_to(player.global_position)
			if distance < ACTIVE_DISTANCE * ACTIVE_DISTANCE:
				candidates.append(record)
				distances[record.id] = distance
		for record: Dictionary in region.plants.values():
			if plants.has(record.id) or plants.size() >= MAX_PLANTS: continue
			var distance: float = Space.resolve(self, record.location).distance_squared_to(player.global_position)
			if distance < ACTIVE_DISTANCE * ACTIVE_DISTANCE:
				plant_candidates.append(record)
				distances[record.id] = distance
	stage_started = _record_tick_stage("candidates", stage_started)
	_prioritize_catalog(candidates, distances)
	stage_started = _record_tick_stage("prioritize", stage_started)
	plant_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return distances[a.id] < distances[b.id])
	if generation_usec > GENERATION_FRAME_BUDGET_USEC and (not candidates.is_empty() or not plant_candidates.is_empty()):
		# A freshly generated colony can take tens of milliseconds. Give the
		# next process frame to its actor/plant instead of stacking both costs.
		last_spawn_attempts = 0
		_spawn_after_generation = true
		_timer = 0.0
	else:
		_spawn_candidates(candidates, plant_candidates)
	stage_started = _record_tick_stage("spawn", stage_started)
	_sync_nests(wanted)
	_record_tick_stage("nests", stage_started)
	peak_animals = maxi(peak_animals, animals.size())

func _generation_cell(wanted: Dictionary, observer: Dictionary) -> Dictionary:
	# Keep the observer's own cell first, then fill the nearest missing cell.
	# A fixed 5x5 ring otherwise spends its first updates on distant corners
	# while adjacent nests and food still have no canonical records.
	var central: Dictionary = Model.cell(descriptor, observer)
	var pending: Array[Dictionary] = []
	for cell: Dictionary in wanted.values():
		var region: Dictionary = storage.region(cell.id, false)
		if region.is_empty() or not bool(region.get("generated", false)):
			if cell.id == central.id: return cell
			pending.append(cell)
	if not pending.is_empty(): return Model.nearest_cell(descriptor, observer, pending)
	# Old generated regions can still need an additive colony upgrade. Retain
	# the bounded rotating maintenance path once new cells are complete.
	var keys: Array = wanted.keys()
	_generation_cursor %= keys.size()
	var cell: Dictionary = wanted[keys[_generation_cursor]]
	_generation_cursor += 1
	return cell

func _spawn_candidates(candidates: Array[Dictionary], plant_candidates: Array[Dictionary]) -> void:
	last_spawn_attempts = 0
	var pending: Dictionary = {}
	for index in range(candidates.size()): pending[candidates[index].id] = index
	var preparing_id: String = str(_skin_record.get("id", _skin_ready_id))
	if not preparing_id.is_empty():
		if not pending.has(preparing_id) or animals.size() >= MAX_ANIMALS: _cancel_skin()
		else: _animal_cursor = int(pending[preparing_id])
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
			# Sorting changes when a family gains a resident. Revisit its new
			# highest-priority sibling on the next update; rotate only failures.
			if spawned: _animal_cursor = 0
			elif _skin_job == null: _animal_cursor += 1
			animal_attempts += 1
		_prefer_plant = not choose_plant
		last_spawn_attempts += 1
		max_spawn_attempt_ms = maxf(max_spawn_attempt_ms, (Time.get_ticks_usec() - started) / 1000.0)
		# At most one actor/plant construction succeeds per update.
		if spawned: break
	peak_spawn_attempts = maxi(peak_spawn_attempts, last_spawn_attempts)

func _prioritize_catalog(candidates: Array[Dictionary], distances: Dictionary = {}) -> void:
	var represented: Dictionary = {}
	var families: Dictionary = {}
	for actor: Node in animals.values():
		var species_id: String = str(actor.catalog_species.get("id", ""))
		if not species_id.is_empty(): represented[species_id] = int(represented.get(species_id, 0)) + 1
		var colony_id: String = str(actor.get("colony_id")) if actor.has_method("get_campaign_identity") else ""
		if not colony_id.is_empty(): families[colony_id] = int(families.get(colony_id, 0)) + 1
	var priority: Callable = func(record: Dictionary) -> int:
		var encounter: Dictionary = record.get("encounter", {})
		if encounter.get("dead", false) and float(encounter.get("carcass_food", 0.0)) <= 0.0: return 3
		if not record.has("catalog_species_id"): return 1
		return 2 if represented.has(record.catalog_species_id) else 0
	# Resolve each canonical place once per update, not for every comparison.
	# This cache dies with the tick, so movement and origin rebases stay fresh.
	var ranks: Dictionary = {}
	for record: Dictionary in candidates:
		ranks[record.id] = {"priority":priority.call(record),
			"family":int(families.get(str(record.get("colony_id", "")), 0)),
			"distance":distances[record.id] if distances.has(record.id) else Space.resolve(self, record.location).distance_squared_to(player.global_position)}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: Dictionary = ranks[a.id]
		var right: Dictionary = ranks[b.id]
		if left.priority != right.priority: return left.priority < right.priority
		if left.priority == 1:
			# Fill a visible family before spending the remaining bounded slots on
			# another nest. The missing catalog role still always comes first.
			if left.family != right.family: return left.family > right.family
		return left.distance < right.distance)
	if animals.size() < MAX_ANIMALS or candidates.is_empty() or ranks[candidates[0].id].priority != 0: return
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
	var probe_started: int = _begin_generation_probe()
	var region: Dictionary = storage.region(cell.id)
	_end_generation_probe("region_access", probe_started)
	if region.is_empty(): return
	if region.generated:
		# Upgrade only the original ordinary resident, even after it migrated.
		if not region.has("colony"):
			var center: Dictionary = Cube.address(descriptor.id, cell.face, -1.0 + (cell.x + 0.5) * cell.step, -1.0 + (cell.y + 0.5) * cell.step)
			var original_id: String = Ids.scoped("object", Habitat.region_id(descriptor.id, center), cell.id + ":resident")
			probe_started = _begin_generation_probe()
			Colony.ensure(self, region, storage.record(original_id))
			_end_generation_probe("colony_upgrade", probe_started)
		return
	probe_started = _begin_generation_probe()
	region.generated = true
	var point: Dictionary = Cube.address(descriptor.id, cell.face, -1.0 + (cell.x + 0.5) * cell.step, -1.0 + (cell.y + 0.5) * cell.step)
	point.height = adapter.sample(point).height
	if not Planner.dry(adapter.terrain.surface, point): return
	point = _place_value(point)
	_end_generation_probe("placement", probe_started)
	var seed_value: int = maxi(1, int((cell.id + ":species:" + str(descriptor.seed)).sha256_text().left(7).hex_to_int()))
	var individual: int = int((cell.id + ":animal").sha256_text().left(7).hex_to_int())
	var role: String = "grazer" if posmod(seed_value, 4) != 0 else "predator"
	# Only newly generated regions receive this minority role. Existing records,
	# frozen bodies and species identities remain the authoritative population.
	if posmod(seed_value, 16) == 1: role = "scavenger"
	probe_started = _begin_generation_probe()
	var blueprint: Dictionary = Species.create_species(seed_value, Vector2i.ZERO, role)
	_end_generation_probe("frozen_species", probe_started)
	probe_started = _begin_generation_probe()
	var region_id: String = Habitat.region_id(descriptor.id, point)
	var id: String = Ids.scoped("object", region_id, cell.id + ":resident")
	var identity := {"object_id": id, "species_id": Ids.scoped("species", descriptor.id, str(seed_value)), "body_id": descriptor.id,
		"region_id": region_id, "habitat_cell": cell.id.sha256_text().left(32), "species_seed": seed_value,
		"design_ref": {"design_id": blueprint.get("design_id", ""), "revision": 0}}
	storage.put({"id": id, "identity": identity, "location": point, "home": point.duplicate(true),
		"species_seed": seed_value, "individual_seed": individual, "role": role, "blueprint": Encoding.encode(blueprint)})
	_end_generation_probe("record_write", probe_started)
	probe_started = _begin_generation_probe()
	Colony.ensure(self, region, storage.record(id))
	_end_generation_probe("colony_records", probe_started)
	probe_started = _begin_generation_probe()
	var food: Dictionary = adapter.offset(point, adapter.frame_at(point).x * 5.0)
	if Planner.dry(adapter.terrain.surface, food):
		var food_id: String = id + ":food"
		storage.put({"id": food_id, "location": _place_value(food), "food_key": food_id}, true)
	_end_generation_probe("food_record", probe_started)

func _reserved(id: String) -> bool:
	var own: Dictionary = body().get("domesticated_animals", {})
	return own.get("registry", {}).get("animals", {}).has(id)

func _spawn_animal(record: Dictionary) -> bool:
	var stage_started: int = Time.get_ticks_usec()
	var encounter: Dictionary = record.get("encounter", {})
	if encounter.get("dead", false) and float(encounter.get("carcass_food", 0.0)) <= 0: return false
	var species: Dictionary = Catalog.species_for(body().fauna_catalog, str(record.get("catalog_species_id", "")))
	var point: Vector3 = _restore_position(record, species) if not encounter.get("dead", false) else _spawn_position(Space.resolve(self, record.location), species)
	_record_spawn_stage("position", stage_started)
	if not point.is_finite():
		if _skin_record.get("id", _skin_ready_id) == record.id: _cancel_skin()
		return false
	if not _skin_available(record): return false
	_skin_ready_id = ""
	stage_started = Time.get_ticks_usec()
	var actor: CharacterBody3D = preload("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	actor.configure(int(record.species_seed), int(record.individual_seed), Vector2i.ZERO, record.role, record.identity.get("habitat_cell", ""), species)
	actor.supplied_identity = record.identity.duplicate(true)
	actor.frozen_blueprint = Encoding.decode(record.blueprint)
	if work_probe.is_valid() and actor.has_method("set_work_probe"):
		actor.call("set_work_probe", work_probe)
	_record_spawn_stage("configure", stage_started)
	stage_started = Time.get_ticks_usec()
	actor.colony_id = str(record.get("colony_id", ""))
	actor.position = point
	actor.collision_mask = 1 | 2
	get_parent().add_child(actor)
	if work_probe.is_valid():
		work_probe.call("publication", "actor_add_child", stage_started, Time.get_ticks_usec())
	_record_spawn_stage("actor_ready", stage_started)
	stage_started = Time.get_ticks_usec()
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
	_record_spawn_stage("post_ready", stage_started)
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
	_cancel_skin()
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
	_cancel_skin()
	_spawn_after_generation = false
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
	_cancel_skin()
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
	var nearby: Array[Dictionary] = []
	for key: String in wanted:
		var colony: Dictionary = storage.region(key, false).get("colony", {})
		if colony.is_empty(): continue
		var point: Vector3 = Space.resolve(self, colony.anchor)
		if point.distance_to(player.global_position) <= ACTIVE_DISTANCE:
			nearby.append({"colony": colony, "point": point})
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.point.distance_squared_to(player.global_position) < b.point.distance_squared_to(player.global_position))
	var created: bool = false
	for entry: Dictionary in nearby:
		var colony: Dictionary = entry.colony
		var point: Vector3 = entry.point
		if not nests.has(colony.id):
			if created or nests.size() >= MAX_NESTS or not Space.ground_ready(self, point): continue
			var hit: Dictionary = Space.floor_hit(player, point)
			if hit.is_empty(): continue
			var nest := WildNest.new()
			nest.position = hit.position + Space.up(self, point) * 0.03
			get_parent().add_child(nest)
			Space.orient(nest)
			var presentation: Dictionary = colony.duplicate()
			presentation.name = Colony.display_name(self, colony)
			nest.setup(presentation, adapter.terrain.surface.terrain, str(adapter.sample(colony.anchor).biome))
			Space.track(nest, colony.id)
			nests[colony.id] = nest
			created = true
		nests[colony.id].refresh(player, Colony.living_members(self, colony))
