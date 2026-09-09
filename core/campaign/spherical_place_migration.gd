extends RefCounted
## Explicit source-place -> target-place mapping, private to copy migration.
## Every gameplay inventory stays in its existing owner. No live scene is read.
const Surface = preload("res://core/campaign/surface_context.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Population = preload("res://world/surface/campaign_population_state.gd")
const Encoding = preload("res://world/fauna/domestication/domestication_contract.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Habitat = preload("res://world/fauna/domestication/domestic_surface_contract.gd")
const Planner = preload("res://world/fauna/domestication/domestic_surface_planner.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const Neighbor = preload("res://world/tribe/neighbors/neighbor_state.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const MAX_PLACES: int = 32768
var source: Dictionary
var target: Dictionary
var descriptor: Dictionary
var surface: RefCounted
var source_center: Array
var target_center: Dictionary
var mappings: Dictionary = {}
var regions: Dictionary = {}
var errors: Array[String] = []

func convert(old: Dictionary, destination: Dictionary, player: Dictionary, encounters: Dictionary, ecology: Dictionary) -> Dictionary:
	source = old
	target = destination
	descriptor = Surface.descriptor(target)
	surface = Surface.Factory.create(descriptor)
	source_center = old.get("home_group", {}).get("anchor", player.get("position", [0.0, 0.0, 0.0])).duplicate()
	target_center = destination.surface_context.spawn.duplicate(true)
	target_center.height = surface.sample(target_center).height + 0.06
	target_center["radius"] = descriptor.radius
	target_center = Habitat.canonical(target_center)
	regions["home"] = {"source": source_center, "target": target_center}
	if old.has("home_group"):
		target.home_group = convert_tree(old.home_group)
		target.home_group.schema = Home.SCHEMA
		target.home_group.surface_mode = Cube.MODE
	if old.has("tribe"):
		# Upgrade only the already validated legacy contract before translating.
		var village: Dictionary = old.tribe.duplicate(true)
		Tribe.upgrade(village)
		target.tribe = convert_tree(village)
		target.tribe.schema = Tribe.SCHEMA
		_repair_entrances(target.tribe)
	if old.has("tribal_neighbor"):
		target.tribal_neighbor = convert_tree(old.tribal_neighbor)
		target.tribal_neighbor.schema = Neighbor.SCHEMA
	if old.has("domesticated_animals"):
		target.domesticated_animals = old.domesticated_animals.duplicate(true)
		target.domesticated_animals.registry.schema = 2
		for animal: Dictionary in target.domesticated_animals.registry.animals.values():
			for field in ["position", "home", "wait_position"]: animal[field] = point(animal[field])
			animal.surface_mode = Cube.MODE
	if old.has("fauna_catalog"): _catalog()
	if not ecology.is_empty():
		var region_places: Dictionary = {}
		for key in ecology.get("regions", {}):
			var record: Dictionary = ecology.regions[key]
			region_places[key] = point([float(record.x) * 256.0 + 128.0, 0.0, float(record.z) * 256.0 + 128.0])
		target.surface_ecology = {"schema": 1, "body_id": target.id, "legacy_state": ecology.duplicate(true), "places": region_places}
	var known: Dictionary = {}
	for habitat: Dictionary in target.get("fauna_catalog", {}).get("habitats", []): known[Habitat.object_id(habitat)] = true
	for id in target.get("domesticated_animals", {}).get("registry", {}).get("animals", {}): known[id] = true
	for id in old.get("legacy_population", {}).get("animals", {}):
		if known.has(id): continue
		var record: Dictionary = old.legacy_population.animals[id].duplicate(true)
		record.location = point(record.location)
		record.home = point(record.home)
		put_population(record)
		known[id] = true
	target.erase("legacy_population")
	for entry: Dictionary in encounters.values():
		if entry.body_id != old.id or known.has(entry.object_id): continue
		_encounter(entry)
		known[entry.object_id] = true
	# These old ledgers stored opaque object IDs without seed/position metadata.
	# Never invent another animal and transfer the old needs to it.
	for field in ["wildlife_foraging", "wildlife_drinking"]:
		for id in old.get(field, {}).get("animals", {}):
			if not known.has(id): errors.append(field + "/" + id + ": ursprünglicher Lebensraum/Körper fehlt im alten Format; Umzug geschützt abgebrochen. Ein erneuter Besuch im Original kann die Herkunft ergänzen.")
	for key in old.get("wildlife_foraging", {}).get("plants", {}):
		var pieces: PackedStringArray = str(key).split(":")
		if pieces.size() != 3 or pieces[0] != "berry" or not pieces[1].is_valid_int() or not pieces[2].is_valid_int():
			errors.append("Nahrungsquelle ohne auflösbaren Quellort: " + str(key))
			continue
		var place: Dictionary = point([float(pieces[1]) / 100.0, 0.0, float(pieces[2]) / 100.0])
		put_population({"id": str(old.id) + ":" + str(key), "location": place, "food_key": key}, true)
	var player_point: Dictionary = point(player.get("position", source_center), true)
	if old.has("tribe") and not target.tribe.members.is_empty(): player_point = target.tribe.members[0].position.duplicate(true)
	return {"ok": errors.is_empty(), "body": target, "player": player_point, "regions": regions, "places": mappings, "errors": errors}

func point(value: Array, airborne: bool = false) -> Dictionary:
	var key: String = JSON.stringify(value)
	if mappings.has(key): return mappings[key].target.duplicate(true)
	if mappings.size() >= MAX_PLACES:
		errors.append("Ortsinventar überschreitet das geprüfte Umzugsbudget.")
		return target_center.duplicate(true)
	var offset := Vector3(float(value[0]) - source_center[0], 0.0, float(value[2]) - source_center[2])
	var region: Dictionary = regions.home
	if offset.length() > 256.0:
		var cell := Vector2i(floori(value[0] / 256.0), floori(value[2] / 256.0))
		var cell_key: String = "%d:%d" % [cell.x, cell.y]
		if not regions.has(cell_key):
			var index: int = regions.size()
			var found: Dictionary = {}
			for attempt in range(64):
				var angle: float = (index * 1.618 + attempt * 0.37) * TAU
				var reach: float = 768.0 + sqrt(float(index)) * 768.0 + attempt * 48.0
				var candidate: Dictionary = Home.offset_place(target_center, Vector3(cos(angle), 0, sin(angle)) * reach)
				candidate.height = surface.sample(candidate).height + 0.06
				if Surface.landing_problem(surface, candidate).is_empty(): found = candidate; break
			if found.is_empty():
				errors.append("Region " + cell_key + ": kein sicherer Zielbereich im Suchbudget.")
				found = target_center.duplicate(true)
			regions[cell_key] = {"source": [cell.x * 256.0 + 128.0, 0.0, cell.y * 256.0 + 128.0], "target": found}
		region = regions[cell_key]
		offset = Vector3(float(value[0]) - region.source[0], 0, float(value[2]) - region.source[2])
	var mapped: Dictionary = Home.offset_place(region.target, offset)
	var sample: Dictionary = surface.sample(mapped)
	mapped.height = sample.height + (1.1 if airborne else 0.06)
	if sample.water or sample.blocked or sample.normal.dot(Cube.vector(Cube.direction(mapped.face, mapped.u, mapped.v))) < 0.9:
		errors.append("Quellort " + key + ": Ziel liegt im Wasser, ist gesperrt oder zu steil.")
	mapped = Habitat.canonical(mapped)
	mappings[key] = {"source": value.duplicate(), "target": mapped.duplicate(true)}
	return mapped

func convert_tree(value: Variant, field: String = "") -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			# Frozen geometry is in design units, not a world position.
			result[key] = value[key].duplicate(true) if key in ["blueprint", "sources", "recipe"] and value[key] is Dictionary else convert_tree(value[key], key)
		return result
	if value is Array:
		if field in ["anchor", "position", "destination", "entrance", "workplace", "pickup", "home", "wait_position"] and Home.valid_position(value): return point(value)
		var result: Array = []
		for item in value:
			result.append(point(item) if field in ["sites", "foundation", "path"] and Home.valid_position(item) else convert_tree(item, field))
		return result
	return value

func _repair_entrances(village: Dictionary) -> void:
	var objects: Array = village.get("housing", {}).get("homes", []).duplicate()
	objects.append_array(village.get("husbandry", {}).get("pens", []))
	if village.get("project", {}).has("entrance"): objects.append(village.project)
	for item: Dictionary in objects:
		var entrance: Dictionary = Home.offset_place(item.position, Vector3(0, 0, 2))
		if absf(surface.sample(entrance).height - entrance.height) > 0.45: errors.append(str(item.id) + ": Gebäudeeingang passt nicht zum Zielboden.")
		item.entrance = entrance

func _catalog() -> void:
	var old: Dictionary = source.fauna_catalog
	var catalog: Dictionary = old.duplicate(true)
	catalog.schema = Habitat.MIGRATED_SCHEMA
	catalog.surface = {"schema": 1, "mode": Cube.MODE, "generation": Surface.GENERATION, "radius": descriptor.radius,
		"terrain_revision": descriptor.terrain_revision, "anchor": target_center.duplicate(true)}
	catalog.erase("habitat_recovery")
	catalog.migration_source = {"schema": 1, "catalog": old.duplicate(true)}
	for habitat: Dictionary in catalog.habitats:
		var old_position: Array = habitat.position.duplicate()
		habitat.position = point(old_position)
		habitat.spawn_position = point(habitat.get("spawn_position", old_position))
		habitat.path = route(target_center, habitat.position)
		habitat.food_position = Home.offset_place(habitat.position, Vector3(3, 0, 0))
		habitat.food_position.height = surface.sample(habitat.food_position).height + 0.06
		if not Planner.dry(surface, habitat.food_position): errors.append("D1-" + habitat.key + ": Nahrungsplatz ist nicht trocken.")
		habitat.travel_mode = "walk"
		habitat.water_supply = "requires_transport"
		habitat.freshwater_distance = -1
		if habitat.path.is_empty(): errors.append("D1-" + habitat.key + ": keine sichere Zielroute.")
	# A pending legacy search restarts using the same catalog and species IDs.
	if catalog.habitat_status != "ready": catalog.habitat_status = "pending"
	target.fauna_catalog = catalog

func route(from: Dictionary, to: Dictionary) -> Array:
	var delta: Vector3 = Home.local_offset(from, to)
	var count: int = maxi(1, ceili(delta.length() / 2.0))
	if count > 2047: return []
	var result: Array = [from.duplicate(true)]
	for i in range(1, count):
		var p: Dictionary = Home.offset_place(from, delta * float(i) / count)
		p.height = surface.sample(p).height + 0.06
		if not Planner.dry(surface, p) or Home.distance(p, result.back()) > 4.0: return []
		result.append(p)
	result.append(to.duplicate(true))
	return result

func _encounter(entry: Dictionary) -> void:
	var habitat: Dictionary = entry.get("habitat", {})
	var cell: PackedStringArray = str(habitat.get("cell", "")).split(":")
	if cell.size() != 2 or not cell[0].is_valid_int() or not cell[1].is_valid_int():
		errors.append(entry.object_id + ": Lebensraum ist keinem Quellort zuzuordnen.")
		return
	var random := RandomNumberGenerator.new()
	random.seed = int((str(int(source.seed)) + ":" + habitat.cell).sha256_text().left(8).hex_to_int())
	var x: float = (int(cell[0]) + random.randf_range(0.3, 0.7)) * 12.0
	var z: float = (int(cell[1]) + random.randf_range(0.3, 0.7)) * 12.0
	var origin := Vector2i(floori(x / 256.0), floori(z / 256.0))
	var blueprint: Dictionary = Species.create_species(int(habitat.species_seed), origin, habitat.role)
	var location: Dictionary = point([x, 0.0, z])
	var identity := {"object_id": entry.object_id, "species_id": entry.species_id, "body_id": entry.body_id, "region_id": entry.region_id,
		"habitat_cell": habitat.cell, "species_seed": habitat.species_seed, "design_ref": {"design_id": blueprint.get("design_id", ""), "revision": 0}}
	put_population({"id": entry.object_id, "identity": identity, "location": location, "home": location.duplicate(true),
		"species_seed": habitat.species_seed, "individual_seed": habitat.individual_seed, "role": habitat.role, "blueprint": Encoding.encode(blueprint)})

func put_population(record: Dictionary, plant: bool = false) -> void:
	if not target.has("surface_population"): target.surface_population = Population.create(target.id)
	if not Population.put(target.surface_population, descriptor, record, plant): errors.append("Zielbestand überschreitet das Regionsbudget: " + str(record.id))
