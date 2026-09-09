extends RefCounted
const Values = preload("res://world/fauna/domestication/domestication_contract.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Cube = preload("res://world/space/cube_sphere.gd")

static func legacy_problem(value: Variant, seed_value: int) -> String:
	if not value is Dictionary or value.get("schema") != 1 or value.get("world_seed") != seed_value or not Values.integer(value.get("simulation_tick"), 0, 9007199254740991) or not value.get("regions") is Dictionary or value.regions.size() > 32768: return "Ungültiger regionaler Ökologiestand."
	for key in value.regions:
		var r: Variant = value.regions[key]
		if not r is Dictionary or not Values.integer(r.get("x"), -40000, 40000) or not Values.integer(r.get("z"), -40000, 40000) or key != "%d,%d" % [r.x, r.z]: return "Ungültiger regionaler Quellort."
		var problem: String = record_problem(r)
		if not problem.is_empty(): return problem
	return ""

static func record_problem(r: Dictionary) -> String:
	for field in ["plant_biomass", "water_availability", "carcass_biomass"]:
		if not Values.number(r.get(field), 0, 1): return "Ungültiger regionaler Vorrat."
	if not Values.integer(r.get("last_touched_tick"), 0, 9007199254740991) or not r.get("species") is Array or r.species.size() > 16: return "Ungültiger regionaler Zeit-/Artenbestand."
	for entry in r.species:
		if not entry is Dictionary or not Values.integer(entry.get("species_seed"), 1, 9007199254740991) or not Values.integer(entry.get("slot"), 0, 16) or not Values.number(entry.get("population"), 0, 1e9) or not Values.number(entry.get("carrying_capacity"), 1, 1e9): return "Ungültiger regionaler Artenbestand."
		if entry.get("role") not in ["grazer", "forager", "predator", "scavenger", "climber", "swimmer"]: return "Ungültige regionale Rolle."
	return ""

static func validate(value: Variant, body: Dictionary) -> String:
	if not value is Dictionary or value.get("schema") != 1 or value.get("body_id") != body.id or not value.get("places") is Dictionary: return "Ungültige regionale Kugelzuordnung."
	var problem: String = legacy_problem(value.get("legacy_state"), int(body.seed))
	if not problem.is_empty(): return problem
	if value.places.size() != value.legacy_state.regions.size(): return "Unvollständige regionale Kugelzuordnung."
	for key in value.places:
		if not value.legacy_state.regions.has(key) or not Home.place_valid(value.places[key], Cube.MODE, body.id) or value.places[key].radius != body.surface_context.radius: return "Körperfremde regionale Zuordnung."
	return ""
