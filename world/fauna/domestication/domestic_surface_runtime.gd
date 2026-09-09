extends RefCounted
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Contract = preload("res://world/fauna/domestication/domestic_surface_contract.gd")
const Planner = preload("res://world/fauna/domestication/domestic_surface_planner.gd")
const Evidence = preload("res://world/fauna/domestication/domestic_body_evidence.gd")
const Creature = preload("res://world/fauna/domestication/domestic_surface_creature.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var catalog: Dictionary = {}
var individuals: Dictionary = {}
var plants: Dictionary = {}
var planner: RefCounted
var object_is_reserved: Callable
var max_body_check_ms: float = 0.0
var max_search_ms: float = 0.0
var built_this_update: bool = false
var blocked_placements: int = 0

func configure(body: Dictionary, record: Dictionary, source: RefCounted) -> void:
	if not record.has("fauna_catalog"):
		var anchor: Dictionary = record.spawn.duplicate(true)
		anchor.height = source.sample(anchor).height
		var used: Dictionary = {}
		for old: Dictionary in record.get("fauna", {}).values():
			var design: Dictionary = JSON.to_native(old.design, false)
			used[int(design.get("species", {}).get("seed", 0))] = true
		record.fauna_catalog = Catalog.create_surface(body, anchor, used)
	catalog = record.fauna_catalog
	if catalog.is_empty() or not Catalog.validate(catalog, body).is_empty():
		push_error("D12 catalog rejected at runtime: " + Catalog.validate(catalog, body))
		catalog = {}
		return
	if not record.has("domestic_fauna"): record.domestic_fauna = {}
	individuals = record.domestic_fauna
	if catalog.habitat_status == "pending":
		planner = Planner.new()
		planner.begin(source, catalog)

func owns(id: String) -> bool:
	return individuals.has(id)

func update(stream: Node) -> void:
	built_this_update = false
	if catalog.is_empty(): return
	if catalog.habitat_status == "pending":
		var started: int = Time.get_ticks_usec()
		planner.step(catalog)
		max_search_ms = maxf(max_search_ms, (Time.get_ticks_usec() - started) / 1000.0)
	for id in stream.animals.keys():
		if not owns(id): continue
		var animal: CharacterBody3D = stream.animals[id]
		animal.enabled = not stream.paused
		if animal.position.distance_to(stream.player.position) > 105.0 or _reserved(id):
			capture_one(stream, id)
			_remove(stream, id)
	for id in plants.keys():
		if not stream.animals.has(id):
			stream.adapter.unbind(id + ":food")
			plants[id].queue_free()
			plants.erase(id)
	for habitat: Dictionary in catalog.habitats:
		var active_id: String = Contract.object_id(habitat)
		if stream.animals.has(active_id): _ensure_food(stream, active_id, habitat)
	for plant: Node in plants.values(): plant.set_process(not stream.paused)
	if stream.paused or catalog.habitat_status != "ready": return
	for habitat: Dictionary in catalog.habitats:
		var id: String = Contract.object_id(habitat)
		if stream.animals.has(id) or _reserved(id): continue
		var entry: Dictionary = Catalog.species_for(catalog, habitat.species_id)
		if entry.has("body_evidence") and not Evidence.approved(entry): continue
		var saved: Dictionary = individuals.get(id, {})
		var location: Dictionary = saved.get("location", habitat.get("spawn_position", habitat.position)).duplicate(true)
		var scale_value: float = entry.visual_scale
		var height: float = maxf(1.15, scale_value * 1.95)
		if not saved.is_empty(): location.height -= height * 0.5 + 0.05
		if stream.adapter.to_local(location).distance_to(stream.player.position) > 70.0: continue
		var placed: Dictionary = placement(stream, location, scale_value)
		# Only unmaterialized habitats may choose a nearby clear floor. Once an
		# individual exists its precise saved pose is retained even if obstructed.
		if placed.is_empty() and saved.is_empty() and not habitat.has("spawn_position"):
			var basis: Basis = stream.adapter.frame_at(location)
			for index in range(24):
				var candidate: Dictionary = Planner.offset(stream.adapter.terrain.surface, location,
					(basis.x * cos(index * TAU / 8) + basis.z * sin(index * TAU / 8)) * (1.5 + float(index / 8) * 1.5))
				if Planner.path(stream.adapter.terrain.surface, location, candidate).is_empty(): continue
				placed = placement(stream, candidate, scale_value)
				if not placed.is_empty(): break
		if placed.is_empty():
			blocked_placements += 1
			continue
		var victim: String = ""
		if stream.animals.size() >= stream.MAX_ANIMALS:
			for other: String in stream.animals:
				if not owns(other): victim = other; break
			if victim.is_empty(): return
		var animal := Creature.new()
		animal.adapter = stream.adapter
		animal.catalog_species = entry
		animal.habitat = habitat
		animal.object_identity = id
		animal.enabled = false
		var spawn_location: Dictionary = placed.duplicate(true)
		spawn_location.height += height * 0.5 + 0.05
		if saved.is_empty():
			var goal: Dictionary = habitat.path[maxi(0, habitat.path.size() - 2)].duplicate(true)
			goal.height += height * 0.5 + 0.05
			var forward: Vector3 = -stream.adapter.frame_at(spawn_location).z
			saved = {"schema": 1, "species_id": entry.id, "habitat_key": habitat.key, "location": spawn_location,
				"home": spawn_location.duplicate(true), "goal": goal, "forward": [forward.x, forward.y, forward.z],
				"velocity": [0.0, 0.0, 0.0], "returning": false, "traveled": 0.0}
		animal.home = saved.home.duplicate(true)
		animal.goal = saved.goal.duplicate(true)
		animal.forward = Cube.vector(saved.forward)
		animal.velocity = Cube.vector(saved.velocity)
		animal.returning = saved.returning
		animal.traveled = saved.traveled
		var started: int = Time.get_ticks_usec()
		stream.get_parent().add_child(animal)
		if not entry.has("body_evidence"):
			var proof_start: int = Time.get_ticks_usec()
			# Measure at origin before radial rotation; evidence is in design units.
			# Use a unit preview transform so scaled foot roundoff cannot reject B1.
			var previous: Transform3D = animal.preview.transform
			animal.preview.transform = Transform3D.IDENTITY
			Evidence.confirm(entry, stream, animal.preview)
			animal.preview.transform = previous
			max_body_check_ms = maxf(max_body_check_ms, (Time.get_ticks_usec() - proof_start) / 1000.0)
			for species: Dictionary in catalog.species:
				if species.id == entry.id: species.body_evidence = entry.body_evidence.duplicate(true)
		if not Evidence.approved(entry):
			animal.free()
			return
		if not victim.is_empty():
			stream._capture_animal(victim)
			_remove(stream, victim)
		individuals[id] = saved
		if not habitat.has("spawn_position"): habitat.spawn_position = placed.duplicate(true)
		stream.adapter.bind(id, animal, saved.location, animal.forward)
		animal.enabled = true
		stream.animals[id] = animal
		built_this_update = true
		_ensure_food(stream, id, habitat)
		stream.max_animal_build_ms = maxf(stream.max_animal_build_ms, (Time.get_ticks_usec() - started) / 1000.0)
		return

func _reserved(id: String) -> bool:
	return object_is_reserved.is_valid() and bool(object_is_reserved.call(id))

func _remove(stream: Node, id: String) -> void:
	var animal: Node = stream.animals[id]
	stream.adapter.unbind(id)
	animal.get_parent().remove_child(animal)
	animal.queue_free()
	stream.animals.erase(id)

func capture_one(stream: Node, id: String) -> void:
	var animal: CharacterBody3D = stream.animals[id]
	individuals[id].merge({"location": stream.adapter.location(animal), "forward": [animal.forward.x, animal.forward.y, animal.forward.z],
		"velocity": [animal.velocity.x, animal.velocity.y, animal.velocity.z], "returning": animal.returning, "traveled": animal.traveled}, true)

func _ensure_food(stream: Node, id: String, habitat: Dictionary) -> void:
	if plants.has(id): return
	var point: Dictionary = habitat.food_position
	if placement(stream, point, 0.88).is_empty():
		if habitat.has("food_state"): return
		var found: bool = false
		var basis: Basis = stream.adapter.frame_at(point)
		for index in range(8):
			var candidate: Dictionary = Planner.offset(stream.adapter.terrain.surface, habitat.position,
				(basis.x * cos(index * TAU / 8) + basis.z * sin(index * TAU / 8)) * 5.0)
			if Planner.path(stream.adapter.terrain.surface, habitat.position, candidate).is_empty() or placement(stream, candidate, 0.88).is_empty(): continue
			point = candidate
			found = true
			break
		if not found: return
		habitat.food_position = point
	if not habitat.has("food_state"):
		habitat.food_state = {"schema": 1, "remaining": 30.0, "regrow_remaining": 0.0}
	var bush: Node3D = load("res://world/resources/plants/berry_bush.tscn").instantiate()
	bush.set_script(load("res://world/fauna/domestication/domestic_surface_food.gd"))
	bush.adapter = stream.adapter
	bush.identity = id + ":food"
	bush.food_state = habitat.food_state
	bush.snap_to_terrain = false
	stream.get_parent().add_child(bush)
	stream.adapter.bind(id + ":food", bush, point)
	plants[id] = bush

func set_paused(value: bool) -> void:
	for plant: Node in plants.values(): plant.set_process(not value)

func close(stream: Node) -> void:
	for id: String in plants:
		stream.adapter.unbind(id + ":food")
		plants[id].get_parent().remove_child(plants[id])
		plants[id].queue_free()
	plants.clear()

static func placement(stream: Node, point: Dictionary, scale_value: float) -> Dictionary:
	var adapter: RefCounted = stream.adapter
	if not adapter.collision_ready(point) or not Planner.dry(adapter.terrain.surface, point): return {}
	var world: World3D = stream.get_parent().get_world_3d()
	var local: Vector3 = adapter.to_local(point)
	var up: Vector3 = adapter.up_at(point)
	var floor: Dictionary = world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(local + up * 1.5, local - up * 1.5, 1))
	if floor.is_empty() or floor.normal.dot(up) < 0.9: return {}
	var shape := CapsuleShape3D.new()
	shape.radius = maxf(0.34, scale_value * 0.72)
	shape.height = maxf(1.15, scale_value * 1.95)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(adapter.frame_at(point), floor.position + up * (shape.height * 0.5 + 0.06))
	query.collision_mask = 1 | 2 | 4 | 8
	if not world.direct_space_state.intersect_shape(query, 1).is_empty(): return {}
	return Cube.from_cartesian(point.body_id, Cube.global_position(floor.position, adapter.terrain.origin), adapter.terrain.surface.body.radius)
