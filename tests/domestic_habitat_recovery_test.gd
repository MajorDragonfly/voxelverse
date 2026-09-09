extends SceneTree
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Planner = preload("res://world/fauna/domestication/domestic_habitat_planner.gd")
const Recovery = preload("res://world/fauna/domestication/domestic_habitat_recovery.gd")
const Terrain = preload("res://tests/fixtures/domestic_recovery_terrain.gd")
var failures: Array[String] = []
var reports: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	state.start_world_with_seed(15838)
	state.campaign.reset("d11-recovery")
	var template: Dictionary = Catalog.ensure(state).duplicate(true)
	var terrain := Terrain.new()
	root.add_child(terrain)
	var radial := Planner.new()
	radial.begin(terrain)
	while not radial.finished: radial.step(terrain, template, 64)
	check(radial.habitats.size() < 3, "Bend fixture did not reproduce radial search failure")
	template["habitats"] = radial.habitats
	template["habitat_status"] = "unavailable"
	var uninterrupted: Dictionary = template.duplicate(true)
	var search := Recovery.new()
	search.begin(terrain, uninterrupted)
	run_search(search, terrain, uninterrupted, 31)
	check(uninterrupted["habitat_status"] == "ready", "Connected bent terrain was not recovered")
	check(Catalog.validate(uninterrupted, state.get_current_body()).is_empty(), "Recovery catalog invalid: " + Catalog.validate(uninterrupted, state.get_current_body()))
	var resumed: Dictionary = template.duplicate(true)
	search = Recovery.new()
	search.begin(terrain, resumed)
	search.step(terrain, resumed, 73)
	check(resumed["habitat_recovery"]["direction"] != 0 and resumed["habitat_recovery"]["status"] == "searching", "Restart fixture is not inside a search node")
	resumed = JSON.parse_string(JSON.stringify(resumed))
	search = Recovery.new()
	search.begin(terrain, resumed)
	run_search(search, terrain, resumed, 1)
	check(JSON.stringify(JSON.parse_string(JSON.stringify(resumed))) == JSON.stringify(JSON.parse_string(JSON.stringify(uninterrupted))), "Resume/frame budget changed habitats or next search edge")
	# Existing identities/tombstones must remain untouched while missing roles fill.
	var partial: Dictionary = template.duplicate(true)
	if not uninterrupted["habitats"].is_empty():
		partial["habitats"] = [uninterrupted["habitats"][0].duplicate(true)]
		partial["habitats"][0]["generation"] = 9
		partial["habitats"][0]["replacement_at"] = 12345.0
		var old_habitat: String = JSON.stringify(partial["habitats"][0])
		var old_identity: String = Catalog.object_id(state, partial["habitats"][0])
		search = Recovery.new()
		search.begin(terrain, partial)
		run_search(search, terrain, partial, 17)
		check(partial["habitat_status"] == "ready" and JSON.stringify(partial["habitats"][0]) == old_habitat and Catalog.object_id(state, partial["habitats"][0]) == old_identity, "Recovery replaced an existing population")
	for habitat: Dictionary in uninterrupted["habitats"]:
		check(habitat["path"].size() > 100 and habitat["travel_mode"] == "swim_walk", "Bend route skipped the physical detour")
		for p: Array in habitat["path"]:
			check(float(p[1]) < 10.0, "Recovery crossed a cliff")
		reports.append({"fixture": "bent_channel", "position": habitat["position"], "steps": habitat["path"].size() - 1})
	terrain.sealed = true
	var sealed_catalog: Dictionary = template.duplicate(true)
	search = Recovery.new()
	search.begin(terrain, sealed_catalog)
	run_search(search, terrain, sealed_catalog, 2)
	check(search.data["status"] == "blocked" and sealed_catalog["habitats"].is_empty(), "Sealed terrain fabricated reachable habitats")
	var blocked: String = JSON.stringify(sealed_catalog)
	search.step(terrain, sealed_catalog, 999)
	check(JSON.stringify(sealed_catalog) == blocked, "Blocked search restarted every frame")
	var corrupt: Dictionary = resumed.duplicate(true)
	corrupt["habitat_recovery"]["nodes"][1]["parent"] = 1
	check(not Catalog.validate(corrupt, state.get_current_body()).is_empty(), "Cyclic recovery parent accepted")
	corrupt = resumed.duplicate(true)
	corrupt["habitat_recovery"]["algorithm"] = "future_v2"
	check(Catalog.has_unsupported(corrupt), "Future recovery algorithm accepted")
	terrain.free()
	# Real terrain, including a known small-island start. Force only the old status.
	for seed_value in [15838, 63352, 23757, 1060]:
		state.start_world_with_seed(seed_value)
		state.campaign.reset("d11-real-recovery")
		var catalog: Dictionary = Catalog.ensure(state)
		if seed_value == 63352:
			var island_radial := Planner.new()
			island_radial.begin(root.get_node("WorldGenerator"))
			while not island_radial.finished: island_radial.step(root.get_node("WorldGenerator"), catalog, 64)
			check(not island_radial.habitats.is_empty(), "Missing reachable island anchor")
			catalog["habitats"] = island_radial.habitats.slice(0, 1)
		catalog["habitat_status"] = "unavailable"
		search = Recovery.new()
		search.begin(root.get_node("WorldGenerator"), catalog)
		run_search(search, root.get_node("WorldGenerator"), catalog, 64)
		check(catalog["habitat_status"] == "ready", "Real terrain recovery failed: %d" % seed_value)
		check(Catalog.validate(catalog, state.get_current_body()).is_empty(), "Invalid real recovery: %d %s" % [seed_value, Catalog.validate(catalog, state.get_current_body())])
		reports.append({"seed": seed_value, "nodes": search.data["nodes"].size(), "status": search.data["status"], "habitats": catalog["habitats"].size()})
	print(JSON.stringify({"test": "domestic_habitat_recovery", "failures": failures, "measurements": reports}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
func run_search(search: RefCounted, terrain: Node, catalog: Dictionary, budget: int) -> void:
	var calls: int = 0
	while search.data["status"] == "searching" and calls < Recovery.MAX_NODES * 8:
		search.step(terrain, catalog, budget)
		calls += 1
	check(search.data["status"] != "searching", "Recovery exceeded finite work limit")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
