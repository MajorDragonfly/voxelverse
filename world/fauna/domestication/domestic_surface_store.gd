extends RefCounted
## Optional D1 data inside M1d's existing body record, never a second species DB.
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Contract = preload("res://world/fauna/domestication/domestic_surface_contract.gd")
const Pose = preload("res://world/surface/surface_lab_store.gd")

static func valid(record: Dictionary, descriptor: Dictionary, save_schema: int) -> bool:
	if not record.has("fauna_catalog") and not record.has("domestic_fauna"): return true
	if save_schema != 2 or not record.get("fauna_catalog") is Dictionary or not record.get("domestic_fauna") is Dictionary: return false
	var body: Dictionary = descriptor.duplicate(true)
	body.surface_mode = Contract.Cube.MODE
	body.surface_generation = Contract.GENERATION
	body.inhabited = true
	var catalog: Dictionary = record.fauna_catalog
	if not Catalog.validate(catalog, body).is_empty() or int(catalog.schema) not in [Contract.SCHEMA, Catalog.ROLE_SCHEMA]: return false
	if record.domestic_fauna.size() > (25 if catalog.schema == Catalog.ROLE_SCHEMA else 24): return false
	var habitats: Dictionary = {}
	for habitat: Dictionary in catalog.habitats: habitats[Contract.object_id(habitat)] = habitat
	for id in record.domestic_fauna:
		var state: Variant = record.domestic_fauna[id]
		if not id is String or not habitats.has(id) or not state is Dictionary or state.get("schema") != 1: return false
		var habitat: Dictionary = habitats[id]
		if state.get("species_id") != habitat.species_id or state.get("habitat_key") != habitat.key or not habitat.has("spawn_position"): return false
		if not Pose.pose_valid(state, body.id) or not state.get("returning") is bool \
			or not Contract.location(state.get("home"), body.id) or not Contract.location(state.get("goal"), body.id): return false
		if Contract.distance(state.home, habitat.spawn_position, body.radius) > 2.0 \
			or Contract.distance(state.goal, habitat.position, body.radius) > 10.0 \
			or Contract.distance(state.location, state.home, body.radius) > 128.0: return false
		var entry: Dictionary = Catalog.species_for(catalog, state.species_id)
		if not Catalog.BodyEvidence.approved(entry): return false
	return true
