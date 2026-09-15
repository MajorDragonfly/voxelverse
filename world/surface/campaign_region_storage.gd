extends RefCounted
## Campaign-owned storage, shared by population, needs and social services.
## No second clock or offline production; unloaded records are frozen.
const Store = preload("res://core/persistence/region_store.gd")
const Model = preload("res://world/surface/campaign_population_state.gd")
const Foraging = preload("res://world/resources/plants/foraging_state.gd")
const Drinking = preload("res://creatures/ai/drinking_state.gd")
const Encounters = preload("res://core/progression/creature_encounters.gd")
var store := Store.new()
var owner: Node
var descriptor: Dictionary
var checked: Dictionary = {}
var _legacy_moves: Array = []

func open(host: Node, body_descriptor: Dictionary) -> bool:
	owner = host
	descriptor = body_descriptor
	store.validate_value = _validate_payload
	var body: Dictionary = owner.body()
	var data: Dictionary = body.surface_population
	if data.schema == Model.PAGED_SCHEMA: return store.open(data.storage)
	# One-time upgrade of the finite inline source. Commit all pages before
	# dropping its original envelope. An interrupted conversion is retryable.
	for key in data.regions:
		var value: Dictionary = data.regions[key].duplicate(true)
		for record: Dictionary in value.objects.values():
			_take_legacy(record, false)
			if not _index(record, key, false): return false
		for record: Dictionary in value.plants.values():
			_take_legacy(record, true)
			if not _index(record, key, true): return false
		if not store.put("r:" + str(key), value): return false
	if body.has("surface_ecology"):
		for key in body.surface_ecology.places:
			var place: Dictionary = body.surface_ecology.places[key]
			var value: Dictionary = region(Model.cell(descriptor, place).id)
			if value.is_empty(): return false
			if not value.has("ecology"): value.ecology = {}
			value.ecology[key] = body.surface_ecology.legacy_state.regions[key].duplicate(true)
	var manifest: Dictionary = store.checkpoint()
	if manifest.is_empty(): return false
	_commit_legacy()
	body.surface_population = {"schema": Model.PAGED_SCHEMA, "body_id": body.id, "storage": manifest}
	# Exact originals remain in the migration archive / earlier slot version.
	body.erase("surface_ecology")
	return true

func region(key: String, create: bool = true) -> Dictionary:
	var value: Dictionary = store.get_value("r:" + key, true)
	if value.is_empty() and store.last_error.is_empty() and create:
		value = {"schema": 1, "key": key, "objects": {}, "plants": {}, "generated": false}
		if not store.put("r:" + key, value): return {}
	if value.is_empty(): return {}
	# Validate each newly loaded payload, never fill damaged records with defaults.
	if checked.has(key) and is_same(checked[key], value): return value
	for old_key in checked.keys():
		if not store.cache.has("r:" + str(old_key)): checked.erase(old_key)
	var problem: String = _validate_payload("r:" + key, value)
	if not problem.is_empty(): store._fail(problem); return {}
	checked[key] = value
	return value

func _validate_payload(key: String, value: Dictionary) -> String:
	if not key.begins_with("r:"):
		return "" if value.get("region") is String and value.get("id") is String else "Ungültige Individuenzuordnung."
	var problem: String = Model.validate_region(value, descriptor)
	if not problem.is_empty(): return problem
	if value.has("ecology") and not value.ecology is Dictionary: return "Ungültiger regionaler Ökologiestand."
	for record: Dictionary in value.objects.values():
		for field in ["foraging", "drinking", "encounter"]:
			if not record.has(field): continue
			var extension: Dictionary = {"schema": 1, "body_id": descriptor.id, "animals": {record.id: record[field]}, "plants": {}}
			problem = Foraging.validate(extension, descriptor.id) if field == "foraging" else (Drinking.validate(extension, descriptor.id) if field == "drinking" else Encounters.validate_entry(record[field]))
			if not problem.is_empty(): return problem
	for record: Dictionary in value.plants.values():
		if record.has("food"):
			problem = Foraging.validate({"schema": 1, "body_id": descriptor.id, "animals": {}, "plants": {record.food_key: record.food}}, descriptor.id)
			if not problem.is_empty(): return problem
	for record: Dictionary in value.get("ecology", {}).values():
		problem = preload("res://world/surface/campaign_ecology_state.gd").record_problem(record)
		if not problem.is_empty(): return problem
	return ""

func record(id: String, plant: bool = false) -> Dictionary:
	var pointer: Dictionary = store.get_value(("p:" if plant else "i:") + id)
	if pointer.is_empty(): return {}
	if not pointer.get("region") is String or not pointer.get("id") is String: store._fail("Ungültige Individuenzuordnung."); return {}
	var value: Dictionary = region(pointer.region, false)
	if value.is_empty(): store._fail("Individuenregion fehlt."); return {}
	var objects: Dictionary = value.plants if plant else value.objects
	if not objects.has(pointer.id): store._fail("Individuum fehlt in seiner Region."); return {}
	return objects[pointer.id]

func put(record_value: Dictionary, plant: bool = false) -> bool:
	var key: String = Model.cell(descriptor, record_value.location).id
	# Loading/indexing can evict a page. Keep the destination resident until
	# both its contents and its identity pointer have been updated.
	var previous_pins: Dictionary = store.pinned.duplicate()
	store.pinned["r:" + key] = true
	var result: bool = _put_record(record_value, key, plant)
	store.pinned = previous_pins
	return result

func _put_record(record_value: Dictionary, key: String, plant: bool) -> bool:
	var value: Dictionary = region(key)
	if value.is_empty(): return false
	var collection: Dictionary = value.plants if plant else value.objects
	if not collection.has(record_value.id) and collection.size() >= Model.MAX_OBJECTS_PER_REGION: return store._fail("Objektbudget der Zielregion ist ausgeschöpft.")
	if not _index(record_value, key, plant): return false
	collection[record_value.id] = record_value
	_take_legacy(record_value, plant)
	return true

func move(record_value: Dictionary, location: Dictionary) -> bool:
	var pointer: Dictionary = store.get_value("i:" + record_value.id)
	if pointer.is_empty(): return store._fail("Individuenzuordnung fehlt beim Regionswechsel.")
	var key: String = Model.cell(descriptor, location).id
	var previous_pins: Dictionary = store.pinned.duplicate()
	store.pinned["r:" + str(pointer.region)] = true
	store.pinned["r:" + key] = true
	var result: bool = _move_record(record_value, location, pointer.region, key)
	store.pinned = previous_pins
	# An active animal's borrowed needs move with it until the next host tick.
	if result and previous_pins.has("r:" + str(pointer.region)): store.pinned["r:" + key] = true
	return result

func _move_record(record_value: Dictionary, location: Dictionary, source: String, key: String) -> bool:
	var origin: Dictionary = region(source, false)
	if origin.is_empty(): return store._fail("Quellregion des Individuums fehlt.")
	if not is_same(origin.objects.get(record_value.id), record_value): return store._fail("Veraltetes Individuenabbild beim Regionswechsel.")
	if source == key:
		record_value.location = location
		return true
	var destination: Dictionary = region(key)
	if destination.is_empty() or destination.objects.size() >= Model.MAX_OBJECTS_PER_REGION: return store._fail("Zielregion kann das Individuum nicht übernehmen.")
	if not _index(record_value, key, false): return false
	record_value.location = location
	destination.objects[record_value.id] = record_value
	origin.objects.erase(record_value.id)
	return true

func pin(keys: Array) -> void:
	_touch_active()
	store.pinned.clear()
	for key in keys: store.pinned["r:" + str(key)] = true

func checkpoint() -> bool:
	_touch_active()
	var manifest: Dictionary = store.checkpoint()
	if manifest.is_empty(): return false
	_commit_legacy()
	owner.body().surface_population.storage = manifest
	return true

func _touch_active() -> void:
	# AI retains mutable hunger/thirst dictionaries between frames. A previous
	# checkpoint cleared dirty flags, not those references. Flush their owners
	# again before saving or releasing them for eviction; work stays bounded by
	# the host's active regions rather than the lifetime number of animals.
	for key in store.pinned:
		if store.cache.has(key): store.dirty[key] = true

func _index(value: Dictionary, key: String, plant: bool) -> bool:
	return store.put(("p:" + str(value.food_key)) if plant else ("i:" + str(value.id)), {"region": key, "id": value.id})

func _take_legacy(value: Dictionary, plant: bool) -> void:
	var body: Dictionary = owner.body()
	if plant:
		var foods: Dictionary = body.get("wildlife_foraging", {}).get("plants", {})
		if foods.has(value.food_key) and not value.has("food"):
			value.food = foods[value.food_key].duplicate(true)
			_legacy_moves.append([foods, value.food_key])
		return
	for pair in [["wildlife_foraging", "foraging"], ["wildlife_drinking", "drinking"]]:
		var entries: Dictionary = body.get(pair[0], {}).get("animals", {})
		if entries.has(value.id) and not value.has(pair[1]):
			value[pair[1]] = entries[value.id].duplicate(true)
			_legacy_moves.append([entries, value.id])
	var encounters: Dictionary = owner.get_node("/root/ProgressionService")._encounters.entries
	if encounters.has(value.id) and not value.has("encounter"):
		value.encounter = encounters[value.id].duplicate(true)
		_legacy_moves.append([encounters, value.id])

func _commit_legacy() -> void:
	for move in _legacy_moves: move[0].erase(move[1])
	_legacy_moves.clear()
