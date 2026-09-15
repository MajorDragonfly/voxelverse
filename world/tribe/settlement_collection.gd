extends RefCounted
## ARCH-26.1: opt-in data contract, not yet a registered campaign save field.
## Each village payload remains the sole owner of stock, orders and cargo.
const Tribe = preload("res://world/tribe/tribe_state.gd")
const Simulation = preload("res://world/tribe/village_simulation.gd")
const Home = Tribe.Home
const Ids = Tribe.Ids
const Economy = Tribe.Economy
const SCHEMA: int = 1
const MAX_SETTLEMENTS: int = 2

## Prepare a COPY for the future coordinated save migration. Never install it
## into GameState until SaveGameService and all body.tribe consumers are ready.
static func prepare_legacy(body: Dictionary, campaign: Dictionary) -> Dictionary:
	if body.has("settlements"):
		var existing: String = validate(body, campaign)
		return _failure(existing) if not existing.is_empty() else {"ok": true, "code": "", "changed": false, "body": body.duplicate(true)}
	if body.get("surface_mode") != Home.Cube.MODE:
		return _failure("settlements.radial_migration_required")
	var village: Variant = body.get("tribe")
	var problem: String = Tribe.validate(village, body, campaign)
	if not problem.is_empty(): return _failure("settlements.invalid_legacy_village", problem)
	var result: Dictionary = body.duplicate(true)
	var id: String = village.id
	result.settlements = {"schema": SCHEMA, "body_id": body.id, "selected_settlement_id": id,
		"entries": {id: {"schema": SCHEMA, "settlement_id": id, "village": result.tribe,
			"simulation": result.get("village_simulation", {})}}}
	result.erase("tribe")
	result.erase("village_simulation")
	problem = validate(result, campaign)
	if not problem.is_empty(): return _failure(problem)
	return {"ok": true, "code": "", "changed": true, "body": result}

static func _failure(code: String, detail: String = "") -> Dictionary:
	return {"ok": false, "code": code, "detail": detail}

## The adapter shares only the selected village and simulation with the body.
## Existing Work/Economy/Husbandry remain the writers. Never persist this view.
## Neighbor aid belongs to the original village until ARCH-27 supplies routes.
static func instance_view(body: Dictionary, settlement_id: String) -> Dictionary:
	var entry: Dictionary = body.get("settlements", {}).get("entries", {}).get(settlement_id, {})
	if entry.is_empty(): return {}
	var view: Dictionary = body.duplicate(false)
	view.erase("settlements")
	view["tribe"] = entry.village
	view["village_simulation"] = entry.simulation
	if settlement_id != origin_id(body): view.erase("tribal_neighbor")
	return view

static func origin_id(body: Dictionary) -> String:
	return Ids.scoped("tribe", str(body.get("home_group", {}).get("id", "")), "settled")

## Selection is presentation state; it neither grants simulation ownership nor
## teleports inhabitants, changes orders or advances campaign time.
static func select(body: Dictionary, settlement_id: String) -> String:
	var collection: Dictionary = body.get("settlements", {})
	if not collection.get("entries", {}).has(settlement_id): return "settlements.unknown_selection"
	collection.selected_settlement_id = settlement_id
	return ""

## Read model only, derived from the authoritative village. Existing workplace,
## shelter, pen and resource IDs are preserved; no second reservation ledger.
static func workplaces(body: Dictionary, settlement_id: String) -> Dictionary:
	var view: Dictionary = instance_view(body, settlement_id)
	if view.is_empty(): return {}
	var village: Dictionary = view.tribe
	var result: Dictionary = {}
	for kind: String in village.deposits:
		_add_place(result, village.deposits[kind], settlement_id, "deposit", kind)
	for kind: String in village.economy.stations:
		_add_place(result, village.economy.stations[kind], settlement_id, "station", kind)
	for shelter: Dictionary in village.housing.homes:
		_add_place(result, shelter, settlement_id, "shelter", shelter.kind)
	for pen: Dictionary in village.husbandry.pens:
		_add_place(result, pen, settlement_id, "pen", "pen")
	var project: Dictionary = village.project
	if not project.is_empty():
		var place: Dictionary = project.duplicate(true)
		# Legacy tool/garden/station projects have no instance ID or location.
		# This stable READ reference is not written into their legacy payload.
		place["id"] = project.get("id", Ids.scoped("work", settlement_id, "project:" + str(project.kind)))
		place["position"] = project.get("position", village.anchor).duplicate(true)
		_add_place(result, place, settlement_id, "construction", project.kind)
	return result

static func _add_place(result: Dictionary, place: Dictionary, settlement_id: String, role: String, kind: String) -> void:
	result[place.id] = {"schema": 1, "workplace_id": place.id, "settlement_id": settlement_id,
		"role": role, "kind": kind, "position": place.position.duplicate(true),
		"entrance": place.get("entrance", place.position).duplicate(true)}

## Validate before binding a new snapshot; work ticks do not rescan the tree.
## Live SaveGameService deliberately does not consume this contract yet.
static func validate(body: Dictionary, campaign: Dictionary) -> String:
	if body.has("tribe") or body.has("village_simulation"): return "settlements.duplicate_authority"
	if body.get("surface_mode") != Home.Cube.MODE: return "settlements.radial_migration_required"
	var collection: Variant = body.get("settlements")
	if not collection is Dictionary or collection.get("schema") != SCHEMA: return "settlements.unsupported_version"
	if collection.keys().size() != 4 or collection.get("body_id") != body.get("id"): return "settlements.invalid_collection"
	var entries: Variant = collection.get("entries")
	if not entries is Dictionary or entries.is_empty() or entries.size() > MAX_SETTLEMENTS: return "settlements.invalid_entries"
	if not collection.get("selected_settlement_id") is String or not entries.has(collection.selected_settlement_id): return "settlements.unknown_selection"
	if not Home.validate(body.get("home_group"), str(body.get("id", "")), str(campaign.get("player_species_id", ""))).is_empty(): return "settlements.invalid_origin"
	var original: String = origin_id(body)
	if not entries.has(original): return "settlements.missing_origin"
	var seen_members: Dictionary = {}
	var seen_places: Dictionary = {}
	var seen_animals: Dictionary = {}
	var seen_producers: Dictionary = {}
	var seen_batches: Dictionary = {}
	var near_count: int = 0
	var clock: Variant = campaign.get("elapsed_seconds")
	if not Economy.number(clock, 0, 1.0e15): return "settlements.invalid_clock"
	for id: Variant in entries:
		var entry: Variant = entries[id]
		if not Economy.text_id(id) or not entry is Dictionary or entry.get("schema") != SCHEMA: return "settlements.unsupported_instance"
		if entry.keys().size() != 4 or entry.get("settlement_id") != id: return "settlements.invalid_instance"
		var village: Variant = entry.get("village")
		if not village is Dictionary or village.get("schema") != Tribe.SCHEMA: return "settlements.unsupported_village"
		if not Tribe.validate_settlement(village, body, campaign, id).is_empty(): return "settlements.invalid_village"
		if village.anchor.radius != body.get("surface_context", {}).get("radius"): return "settlements.radius_mismatch"
		if id == original and village.anchor != body.home_group.anchor: return "settlements.origin_moved"
		for member: Dictionary in village.members:
			if seen_members.has(member.id): return "settlements.duplicate_resident"
			seen_members[member.id] = true
		# Even after splitting, the existing measured six-resident body budget
		# and original identities remain; founding/growth is a later command.
		if seen_members.size() > Tribe.Housing.MAX_RESIDENTS: return "settlements.resident_budget"
		for place_id: String in workplaces(body, id):
			if seen_places.has(place_id): return "settlements.duplicate_workplace"
			seen_places[place_id] = true
		for pen: Dictionary in village.husbandry.pens:
			if pen.animal_id.is_empty(): continue
			if seen_animals.has(pen.animal_id): return "settlements.duplicate_animal_assignment"
			seen_animals[pen.animal_id] = true
		for producer_id: String in village.husbandry.records:
			if seen_producers.has(producer_id): return "settlements.duplicate_production_record"
			seen_producers[producer_id] = true
		for batch_id: String in village.economy.get("receipts", {}):
			if seen_batches.has(batch_id): return "settlements.duplicate_receipt"
			seen_batches[batch_id] = true
		var simulation: Variant = entry.get("simulation")
		if not simulation is Dictionary: return "settlements.invalid_simulation"
		if not simulation.is_empty():
			if not Simulation.validate_settlement(simulation, instance_view(body, id), float(clock), str(campaign.get("player_object_id", ""))).is_empty(): return "settlements.invalid_simulation"
			if simulation.owner == "near": near_count += 1
	if near_count > 1: return "settlements.multiple_near_owners"
	var originals: Array = [campaign.get("player_object_id"), body.home_group.members[0].id, body.home_group.members[1].id]
	for id: String in originals:
		if not seen_members.has(id): return "settlements.missing_original_resident"
	var allowed: Array = originals.duplicate()
	for index in range(3, Tribe.Housing.MAX_RESIDENTS): allowed.append(Tribe.Housing.resident_id({"id": original}, index))
	for id: String in seen_members:
		if id not in allowed: return "settlements.unknown_resident"
	return ""
