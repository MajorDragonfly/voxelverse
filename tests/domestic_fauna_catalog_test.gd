extends SceneTree
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Contract = preload("res://world/fauna/domestication/domestication_contract.gd")
const Planner = preload("res://world/fauna/domestication/domestic_habitat_planner.gd")
const Legacy = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
var failures: Array[String] = []
var reports: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	var generator: Node = root.get_node("WorldGenerator")
	saves.autosave_enabled = false
	saves._loaded_once = true
	for seed_value in [1, 2, 3, 10, 42, 100, 555, 1337, 15838, 63352, 23757, 99991, 87654321, 2147483647] + range(1000, 1064):
		state.start_world_with_seed(seed_value)
		state.campaign.reset("d1-fixed-test")
		state.active_system_id = ""
		state.set_world_seed(state.world_seed, false)
		var body: Dictionary = state.get_current_body()
		var old_seed: int = generator.get_species_seed(0, 0, 0)
		var old_id: String = state.campaign.species_id(body["id"], old_seed)
		var before: String = JSON.stringify(Contract.encode(Legacy.create_species(old_seed)))
		var catalog: Dictionary = Catalog.ensure(state)
		check(Catalog.validate(catalog, body).is_empty(), "Catalog validation: " + Catalog.validate(catalog, body))
		var signature: String = JSON.stringify(catalog)
		state.get_current_body_record().erase("fauna_catalog")
		var repeated: Dictionary = Catalog.ensure(state)
		check(JSON.stringify(repeated) == signature, "Nondeterministic catalog: %d" % seed_value)
		check(generator.get_species_seed(0, 0, 0) == old_seed and state.campaign.species_id(body["id"], old_seed) == old_id, "Changed legacy identity")
		check(JSON.stringify(Contract.encode(Legacy.create_species(old_seed))) == before, "Changed legacy body")
		var planner := Planner.new()
		planner.begin(generator)
		while not planner.finished: planner.step(generator, repeated, 32)
		repeated["habitats"] = planner.habitats
		repeated["habitat_status"] = "ready" if planner.habitats.size() >= 3 else "unavailable"
		check(planner.habitats.size() >= 3, "Mandatory habitats unavailable: %d" % seed_value)
		check(Catalog.validate(repeated, body).is_empty(), "Habitat validation: " + Catalog.validate(repeated, body))
		var distances: Array = []
		var near_water: int = 0
		for habitat: Dictionary in repeated["habitats"]:
			distances.append(habitat["path"].size() - 1)
			if habitat["water_supply"] == "nearby_freshwater": near_water += 1
		reports.append({"seed": seed_value, "habitats": planner.habitats.size(), "path_metres": distances, "freshwater_nearby": near_water})
		# Exact saved snapshots take precedence over subsequent generator calls.
		repeated["species"][0]["blueprint"]["name"] = "Saved legacy name"
		var saved_signature: String = JSON.stringify(repeated)
		state.campaign.import_state(JSON.parse_string(JSON.stringify(state.campaign.export_state())))
		check(JSON.stringify(Catalog.ensure(state)) == JSON.stringify(JSON.parse_string(saved_signature)), "Reload regenerated catalog")
		print(JSON.stringify(reports.back()))
	for kind in ["star", "gas_giant", "asteroid"]:
		check(not Catalog.eligible({"kind": kind, "inhabited": true, "surface_mode": "legacy_plane_v9"}), "Fauna on " + kind)
	check(not Catalog.eligible({"kind": "planet", "inhabited": false, "surface_mode": "legacy_plane_v9"}), "Fauna on lifeless planet")
	print(JSON.stringify({"test": "domestic_fauna_catalog", "failures": failures, "seeds": reports.size()}))
	quit(0 if failures.is_empty() else 1)
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
