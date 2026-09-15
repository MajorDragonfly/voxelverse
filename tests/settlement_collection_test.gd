extends SceneTree
const Settlements = preload("res://world/tribe/settlement_collection.gd")
const Campaign = preload("res://core/campaign/campaign_state.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Tribe = Settlements.Tribe
const Home = Settlements.Home
const Simulation = Settlements.Simulation
const Work = Simulation.Work
const FILE: String = "user://arch26-contract-fixture.json"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("GameState").set_process(false)
	if "--restart-check" in OS.get_cmdline_user_args():
		_restart()
		await _finish()
		return
	var fixture: Dictionary = _legacy()
	var source: Dictionary = fixture.body
	var campaign: Dictionary = fixture.campaign
	_expect(Tribe.validate(source.tribe, source, campaign).is_empty(), "Legacy radial fixture is invalid.")
	_migration_inflight(source, campaign)
	var before: Dictionary = source.duplicate(true)
	var prepared: Dictionary = Settlements.prepare_legacy(source, campaign)
	_expect(prepared.ok, "Copy migration failed: " + str(prepared))
	if not prepared.ok: await _finish(); return
	var body: Dictionary = prepared.body
	var origin: String = Settlements.origin_id(body)
	_expect(source == before, "Migration mutated the source.")
	_expect(body.settlements.entries[origin].village == source.tribe, "Migration changed the legacy village payload or identities.")
	_expect(body.settlements.entries[origin].simulation == source.village_simulation, "Migration lost simulation routes/cursor.")
	_expect(not body.has("tribe") and not body.has("village_simulation"), "Copied body has two authorities.")
	_expect(body.domesticated_animals == source.domesticated_animals and body.tribal_neighbor == source.tribal_neighbor, "Migration modified foreign modules.")
	var repeated: Dictionary = Settlements.prepare_legacy(body, campaign)
	_expect(repeated.ok and not repeated.changed and repeated.body == body, "Migration is not idempotent.")
	Settlements.instance_view(body, origin).tribe.members[1].name = "Geänderter Name"
	_expect(source == before, "Prepared body aliases the source.")
	_expect(body.settlements.entries[origin].village.members[1].name == "Geänderter Name", "Instance adapter does not share its authoritative record.")
	# Neighbor runtime is not involved in this bounded two-settlement probe.
	body.erase("tribal_neighbor")
	var secondary: String = _second(body, campaign)
	var a: Dictionary = Settlements.instance_view(body, origin)
	var b: Dictionary = Settlements.instance_view(body, secondary)
	_expect(Settlements.validate(body, campaign).is_empty(), "Two-instance fixture failed: " + Settlements.validate(body, campaign))
	_expect(not Tribe.validate(b.tribe, b, campaign).is_empty(), "Live legacy validator silently accepted the secondary instance.")
	_expect(not Simulation.validate(b.village_simulation, b, campaign.elapsed_seconds).is_empty(), "Legacy simulation validator no longer requires its original player.")
	var places_a: Dictionary = Settlements.workplaces(body, origin)
	var places_b: Dictionary = Settlements.workplaces(body, secondary)
	_expect(a.tribe.economy.stations.well.id != b.tribe.economy.stations.well.id, "Same-kind workplaces share an ID.")
	_expect(places_a.has(a.tribe.economy.stations.well.id) and places_b.has(b.tribe.economy.stations.well.id), "Workplace index omitted an instance.")
	places_a[a.tribe.economy.stations.well.id].position.height += 100
	_expect(a.tribe.anchor == body.home_group.anchor, "Read-only workplace view changed live geometry.")
	var view_before: Dictionary = body.duplicate(true)
	_expect(Settlements.select(body, secondary).is_empty(), "Valid selection failed.")
	view_before.settlements.selected_settlement_id = secondary
	_expect(body == view_before, "Selection changed ownership, time or resources.")
	_expect(not Settlements.select(body, "unknown").is_empty() and body == view_before, "Unknown selection created or changed a settlement.")
	_rejections(body, campaign, origin, secondary)
	_duplicate_producers(body, campaign, origin, secondary)
	# Two simultaneous reservations and actual carried construction units.
	_project(a.tribe, a.tribe.members[1])
	_project(b.tribe, b.tribe.members[0])
	b.tribe.members[0].blocked = true
	_certify(a, campaign)
	_certify(b, campaign)
	_expect(Settlements.validate(body, campaign).is_empty(), "Concurrent reservations are invalid: " + Settlements.validate(body, campaign))
	var b_before: Dictionary = b.tribe.duplicate(true)
	for tick in range(120):
		Simulation.advance(a, 30.0)
	_expect(a.tribe.huts == 1 and a.tribe.project.is_empty(), "First settlement did not carry materials and complete its hut.")
	_expect(b.tribe == b_before, "Advancing A mutated B's work/stock/cargo.")
	for tick in range(120): Simulation.advance(b, 30.0)
	_expect(b.tribe.members[0].cargo == "wood" and b.tribe.project.delivered_materials.wood == 5 and b.tribe.huts == 0, "Blocked construction cargo arrived remotely.")
	_expect(a.tribe.stock.water > 0 and b.tribe.stock.water == 0, "Independent resources were not preserved.")
	_expect(a.tribe.economy.produced.water == 8 and b.tribe.economy.produced.water == 6 and a.tribe.deposits.water.remaining == 6 and b.tribe.deposits.water.remaining == 6, "Two wells mixed or duplicated their timed production.")
	_expect(Settlements.validate(body, campaign).is_empty(), "Work invalidated the collection: " + Settlements.validate(body, campaign))
	var paused: String = _fingerprint(body)
	for tick in range(8):
		_expect(not Simulation.advance(a, 30.0) and not Simulation.advance(b, 30.0), "Paused campaign clock advanced work.")
	_expect(_fingerprint(body) == paused, "Pause changed cargo or production.")
	a.village_simulation.owner = "near"
	paused = _fingerprint(body)
	_expect(not Simulation.advance(a, 80.0) and _fingerprint(body) == paused, "Near instance was also simulated far.")
	# Contract fixture only: common atomic writer, deliberately no new save service.
	fixture = {"body": body, "campaign": campaign, "origin": origin, "secondary": secondary}
	_expect(Atomic.write(FILE, fixture, false) == OK, "Could not checkpoint the contract fixture.")
	var text_before: String = FileAccess.get_file_as_string(FILE)
	DirAccess.make_dir_absolute(FILE + ".tmp")
	_expect(Atomic.write(FILE, {"partial": true}, false) != OK and FileAccess.get_file_as_string(FILE) == text_before, "Failed staging changed the committed fixture.")
	DirAccess.remove_absolute(FILE + ".tmp")
	var output: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--restart-check"])
	_expect(OS.execute(OS.get_executable_path(), args, output, true) == 0 and not str(output).contains("SCRIPT ERROR"), "Fresh process failed: " + str(output))
	print(str(output))
	# No physical route or region-paging claim is made by this model fixture.
	await _finish()

func _legacy() -> Dictionary:
	var model := Campaign.new()
	model.reset("arch26-fixture")
	var campaign: Dictionary = model.data
	campaign.elapsed_seconds = 100.0
	var body: Dictionary = model.ensure_body(15838, 23757)
	body.surface_mode = Home.Cube.MODE
	body.surface_context = {"radius": 50000.0}
	var anchor: Dictionary = Home.Cube.address(body.id, 0, 0.99995, 0.0)
	anchor.radius = 50000.0
	var home: Dictionary = Home.create(body.id, campaign.player_species_id, Vector3.ZERO)
	home.merge({"schema": Home.SCHEMA, "surface_mode": Home.Cube.MODE, "anchor": anchor}, true)
	for member: Dictionary in home.members: member.position = Home.offset_place(anchor, Home.vector(member.position))
	body.home_group = home
	body.tribe = Tribe.create(home, campaign, {"surface_address": anchor}, _sites(anchor))
	_well(body.tribe, 2)
	# Body-owned foreign state must remain byte-for-byte data, never copied into
	# an instance ledger. Full D1/D2 validation remains the future save participant.
	body.domesticated_animals = {"schema": 1, "registry": {"animals": {}}, "sources": {}}
	body.tribal_neighbor = {"preserved_foreign_record": true}
	_certify(body, campaign)
	return {"body": body, "campaign": campaign}

func _sites(anchor: Dictionary) -> Dictionary:
	return {"wood": Home.offset_place(anchor, Vector3(-5, 0, -4)), "stone": Home.offset_place(anchor, Vector3(5, 0, -4)),
		"food": Home.offset_place(anchor, Vector3(-5, 0, 4)), "huts": [Home.offset_place(anchor, Vector3(5, 0, 4)), Home.offset_place(anchor, Vector3(8, 0, 0))]}

func _well(village: Dictionary, units: int) -> void:
	village.tools = 1
	village.economy.stations.well = {"id": Tribe.Ids.scoped("workplace", village.id, "well"), "position": village.anchor.duplicate(true)}
	village.economy.produced.water = units
	village.stock.water = units

func _second(body: Dictionary, campaign: Dictionary) -> String:
	var original: Dictionary = Settlements.instance_view(body, Settlements.origin_id(body)).tribe
	var id: String = Tribe.Ids.scoped("settlement", body.id, "second-fixture")
	var anchor: Dictionary = Home.offset_place(original.anchor, Vector3(120, 0, 0))
	var home: Dictionary = body.home_group.duplicate(true)
	home.anchor = anchor
	var village: Dictionary = Tribe.create(home, campaign, {"surface_address": anchor}, _sites(anchor))
	village.id = id
	# Fixture allocation moves an existing resident; no duplicate or free citizen.
	var resident: Dictionary = original.members.pop_back()
	resident.position = anchor.duplicate(true)
	resident.destination = anchor.duplicate(true)
	village.members = [resident]
	for kind: String in village.deposits: village.deposits[kind].id = Tribe.Ids.scoped("resource", id, kind)
	_well(village, 0)
	body.settlements.entries[id] = {"schema": 1, "settlement_id": id, "village": village, "simulation": {}}
	var view: Dictionary = Settlements.instance_view(body, id)
	_certify(view, campaign)
	return id

func _migration_inflight(source: Dictionary, campaign: Dictionary) -> void:
	var loaded: Dictionary = source.duplicate(true)
	_project(loaded.tribe, loaded.tribe.members[1])
	loaded.tribe.members[1].work = 1.125
	loaded.tribe.economy.clocks.water = 1.875
	loaded.village_simulation.legs[loaded.tribe.members[1].id] = [loaded.tribe.project.entrance.duplicate(true)]
	var snapshot: Dictionary = loaded.duplicate(true)
	var converted: Dictionary = Settlements.prepare_legacy(loaded, campaign)
	_expect(converted.ok and loaded == snapshot, "In-flight migration failed or mutated its source.")
	if converted.ok:
		var view: Dictionary = Settlements.instance_view(converted.body, Settlements.origin_id(converted.body))
		_expect(view.tribe == loaded.tribe and view.village_simulation == loaded.village_simulation, "Migration lost held freight, reservation, partial timer or route.")
	for mode: String in ["future", "plane"]:
		var bad: Dictionary = source.duplicate(true)
		if mode == "future": bad.tribe.schema = 999
		else: bad.surface_mode = "legacy_plane_v9"
		var before: Dictionary = bad.duplicate(true)
		_expect(not Settlements.prepare_legacy(bad, campaign).ok and bad == before, "Unsupported source was migrated: " + mode)

func _duplicate_producers(body: Dictionary, campaign: Dictionary, a: String, b: String) -> void:
	var duplicated: Dictionary = body.duplicate(true)
	for id: String in [a, b]:
		var village: Dictionary = Settlements.instance_view(duplicated, id).tribe
		var batch: Dictionary = Tribe.Economy.Batch.create(village, "shared-production-source", 1, 1, village.anchor, Tribe.Economy.Batch.Production.MILK)
		_expect(Tribe.Economy.receive_batch(village, batch).is_empty(), "Could not create valid receipt fixture.")
	_expect(Settlements.validate(duplicated, campaign) == "settlements.duplicate_receipt", "Duplicate producer ledger was accepted in two settlements.")
	duplicated = body.duplicate(true)
	for id: String in [a, b]:
		var village: Dictionary = Settlements.instance_view(duplicated, id).tribe
		var pen: Dictionary = Tribe.Housing.site(village, "pen", Home.offset_place(village.anchor, Vector3(0, 0, 7)), 0)
		pen.merge({"animal_id": "", "food": 0.0, "water": 0.0})
		village.husbandry.pens.append(pen)
		var animal: Dictionary = {"object_id": "shared-animal", "species_id": "foreign-milk-species", "design_ref": {"id": "milk-design", "revision": 1}}
		_expect(Tribe.Husbandry.bind(village, pen, animal, {"milk_yield": 2.0, "milk_interval": 300.0, "water_need": 4.0}).is_empty(), "Could not create pen-assignment fixture.")
	_expect(Settlements.validate(duplicated, campaign) == "settlements.duplicate_animal_assignment", "One animal was assigned to two settlements.")
	for id: String in [a, b]:
		var village: Dictionary = Settlements.instance_view(duplicated, id).tribe
		_expect(Tribe.Husbandry.unbind(village, village.husbandry.pens[0]).is_empty(), "Could not retain unbound production history.")
	_expect(Settlements.validate(duplicated, campaign) == "settlements.duplicate_production_record", "Unbinding allowed a duplicate production history.")

func _certify(view: Dictionary, campaign: Dictionary) -> void:
	var village: Dictionary = view.tribe
	var points: Array = [village.anchor]
	for member: Dictionary in village.members: points.append(member.position)
	for deposit: Dictionary in village.deposits.values(): points.append(deposit.position)
	if not village.project.is_empty(): points.append(village.project.entrance)
	var roads: Dictionary = {}
	for point: Dictionary in points: roads[Simulation.key(point)] = [village.anchor.duplicate(true), point.duplicate(true)]
	var simulation: Dictionary = Simulation.create(view.id, 0.0, roads, [], campaign.player_object_id)
	# Keep a previously bound instance dictionary rather than replacing its alias.
	if view.get("village_simulation") is Dictionary:
		view.village_simulation.clear()
		view.village_simulation.merge(simulation)
	else: view.village_simulation = simulation

func _project(village: Dictionary, worker: Dictionary) -> void:
	var project: Dictionary = Tribe.Housing.site(village, "hut", village.sites[0], village.housing.homes.size())
	project.merge({"progress": 0.0, "materials": {"wood": 0, "stone": 0}, "delivered_materials": {"wood": 5, "stone": 3}})
	village.project = project
	village.deposits.wood.remaining -= 6
	village.deposits.stone.remaining -= 3
	worker.order = "hut"
	worker.cargo = "wood"
	worker.construction_id = project.id
	worker.stage = "return"

func _rejections(body: Dictionary, campaign: Dictionary, a: String, b: String) -> void:
	for mode: String in ["future", "future_instance", "future_village", "future_economy", "duplicate_authority", "selection", "foreign_body", "radius", "foreign_faction", "foreign_species", "duplicate_resident", "unknown_resident", "two_near", "traveler", "foreign_road", "foreign_cargo", "missing_origin"]:
		var bad: Dictionary = body.duplicate(true)
		var first: Dictionary = bad.settlements.entries[a]
		var second: Dictionary = bad.settlements.entries[b]
		match mode:
			"future": bad.settlements.schema = 999
			"future_instance": second.schema = 999
			"future_village": second.village.schema = 999
			"future_economy": second.village.economy.schema = 999
			"duplicate_authority": bad.tribe = first.village.duplicate(true)
			"selection": bad.settlements.selected_settlement_id = "missing"
			"foreign_body": second.village.anchor.body_id = "foreign-body"
			"radius": second.village.anchor.radius += 1.0
			"foreign_faction": second.village.faction_id = "foreign-faction"
			"foreign_species": second.village.species_id = "wild-species"
			"duplicate_resident": second.village.members[0].id = first.village.members[1].id
			"unknown_resident": second.village.members[0].id = "invented-resident"
			"two_near":
				first.simulation.owner = "near"
				second.simulation.owner = "near"
			"traveler": second.simulation.traveler = second.village.members[0].id
			"foreign_road": second.simulation.roads.values()[0][0].body_id = "other-body"
			"foreign_cargo": second.village.members[0].construction_id = "other-project"
			"missing_origin": bad.settlements.entries.erase(a)
		var before: String = _fingerprint(bad)
		_expect(not Settlements.validate(bad, campaign).is_empty(), "Accepted malformed contract: " + mode)
		_expect(not Settlements.prepare_legacy(bad, campaign).ok and _fingerprint(bad) == before, "Repaired/overwrote rejected contract: " + mode)

func _restart() -> void:
	var fixture: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(FILE))
	_expect(not fixture.is_empty(), "Fresh process cannot read the fixture.")
	if fixture.is_empty(): return
	var body: Dictionary = fixture.body
	_expect(Settlements.validate(body, fixture.campaign).is_empty(), "Fresh-process contract is invalid.")
	var a: Dictionary = Settlements.instance_view(body, fixture.origin)
	var b: Dictionary = Settlements.instance_view(body, fixture.secondary)
	_expect(a.tribe.huts == 1 and b.tribe.huts == 0 and b.tribe.members[0].cargo == "wood", "Restart lost completed building or held cargo.")
	_expect(a.village_simulation.cursor == 30.0 and b.village_simulation.cursor == 30.0 and a.village_simulation.owner == "near", "Restart lost independent cursor/owner.")
	var a_before: String = _fingerprint(a.tribe)
	var before: String = _fingerprint(body)
	_expect(not Simulation.advance(b, 30.0) and _fingerprint(body) == before, "Restart or paused clock produced offline work.")
	b.tribe.members[0].blocked = false
	for tick in range(120): Simulation.advance(b, 60.0)
	_expect(b.tribe.huts == 1 and b.tribe.project.is_empty() and b.tribe.members[0].cargo.is_empty(), "Held cargo did not resume exactly once.")
	_expect(_fingerprint(a.tribe) == a_before, "B completion changed A after restart.")
	_expect(Settlements.validate(body, fixture.campaign).is_empty(), "Resumed contract broke conservation.")
	# The same shared arrived-work function also operates on a near instance.
	var worker: Dictionary = a.tribe.members[1]
	worker.order = "wood"
	worker.blocked = false
	worker.position = a.tribe.deposits.wood.position.duplicate(true)
	for tick in range(12): Work.step(a.tribe, worker, 0.25, 1.0, [])
	_expect(worker.cargo == "wood" and a.tribe.stock.wood == 0, "Near harvesting skipped cargo.")
	worker.position = a.tribe.anchor.duplicate(true)
	Work.step(a.tribe, worker, 0.25, 1.0, [])
	_expect(worker.cargo.is_empty() and a.tribe.stock.wood == 1 and b.tribe.stock.wood == 0, "Near arrival credited the wrong settlement.")
	_expect(Settlements.validate(body, fixture.campaign).is_empty(), "Near/far continuation invalidated the contract.")

func _fingerprint(value: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value))).sha256_text()

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _finish() -> void:
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("SETTLEMENT_COLLECTION_PASSED: %d checks; copy migration, identity, two work instances, held cargo, pause, failed write and fresh process." % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
