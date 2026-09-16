extends "res://tests/settlement_collection_test.gd"
## Model/save checks use synthetic radial geometry. Physical arrival is tested
## separately in workplace_runtime_test on the normal spherical campaign.
const E = Tribe.Economy
const Progress = preload("res://core/progression/tribal_economy_progress.gd")
const SAVE_PATH: String = "user://workplaces.json"
const EXPECTED_PATH: String = "user://workplaces-expected.json"

func _run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	state.set_process(false)
	if "--workplace-restart" in OS.get_cmdline_user_args():
		await _reload(state, saves)
		await _finish_workplaces()
		return
	var slot: String = saves.create_slot("Workplace contract", 15838, Home.Cube.MODE)
	_expect(not slot.is_empty(), "Native slot creation failed.")
	saves.save_path = SAVE_PATH
	state.current_phase = 1
	state.campaign.data.elapsed_seconds = 100.0
	var campaign: Dictionary = state.campaign.data
	var body: Dictionary = state.get_current_body_record()
	var anchor: Dictionary = body.surface_context.spawn.duplicate(true)
	anchor.radius = body.surface_context.radius
	var home: Dictionary = Home.create(body.id, campaign.player_species_id, Vector3.ZERO)
	home.merge({"schema": Home.SCHEMA, "surface_mode": Home.Cube.MODE, "anchor": anchor}, true)
	for member: Dictionary in home.members: member.position = Home.offset_place(anchor, Home.vector(member.position))
	body.home_group = home
	body.tribe = Tribe.create(home, campaign, {"surface_address": anchor}, _sites(anchor))
	var data: Dictionary = body.tribe
	_well(data, 0)
	for kind: String in ["wood", "stone"]:
		data.stock[kind] = 20
		data.deposits[kind].remaining -= 20
	# JSON numeric types and paid old projects must migrate without changing any
	# amount, position, ID or partial work, including an old in-flight unit.
	var legacy: Dictionary = data.duplicate(true)
	legacy.economy.schema = 2
	legacy.economy.clocks.water = 1.125
	legacy.project = {"kind": "forester", "position": legacy.deposits.wood.position, "progress": 4.5}
	legacy.members[1].merge({"cargo": "wood", "order": "wait", "paused_order": "wood", "stage": "return"}, true)
	legacy.deposits.wood.remaining -= 1
	legacy = Atomic.parse_dictionary(Atomic.stringify(legacy))
	var legacy_body: Dictionary = Atomic.parse_dictionary(Atomic.stringify(body))
	_expect(Tribe.validate(legacy, legacy_body, campaign).is_empty() and Progress.supported(legacy), "Economy 2 no longer loads: " + Tribe.validate(legacy, legacy_body, campaign))
	var before: Dictionary = legacy.duplicate(true)
	_expect(Tribe.upgrade(legacy), "Economy 2 did not migrate.")
	before.economy.schema = E.SCHEMA
	_expect(legacy == before and not Tribe.upgrade(legacy), "Migration changed old jobs or ran twice.")
	_expect(Tribe.validate(legacy, legacy_body, campaign).is_empty(), "Migrated paid project is invalid: " + Tribe.validate(legacy, legacy_body, campaign))
	_all_kinds(body, campaign)
	_build(data, "well", Vector3(0, 0, -7))
	_expect(data.economy.stations.size() == 2 and E.next_station(data, "well").is_empty(), "Two-well limit failed.")
	var first: Dictionary = data.economy.stations.well
	var second: Dictionary = data.economy.stations["well:2"]
	_expect(first.id != second.id and data.deposits.water.id != second.id, "Same-kind identities collide.")
	data.economy.clocks.water = 4.0
	second.clock = 1.0
	E.tick(data, 1.0)
	_expect(data.deposits.water.remaining == 1 and second.remaining == 0 and second.clock == 2.0, "Independent production clocks mixed.")
	E.tick(data, 1000.0)
	_expect(data.deposits.water.remaining == 8 and second.remaining == 8 and data.economy.produced.water == 16, "Independent capacities failed.")
	var a: Dictionary = data.members[1]
	var b: Dictionary = data.members[2]
	a.merge({"order": "water", "profession": "provider", "workplace_id": first.id, "position": first.position.duplicate(true)}, true)
	b.merge({"order": "water", "profession": "provider", "workplace_id": second.id, "position": second.position.duplicate(true)}, true)
	var record: Dictionary = Progress.create(data)
	for worker: Dictionary in [a, b]:
		before = Work.snapshot(data, worker)
		var previous: Dictionary = before.members[data.members.find(worker)]
		Work.step(data, worker, 3.0, 1.0, [])
		Progress.observe_work(record, before, data, previous, worker)
		_expect(worker.cargo == "water" and before.members[data.members.find(worker)].cargo == "", "Snapshot changed with arrived work.")
		_expect(record.pending.get(worker.id, {}).get("source_id") == worker.get("cargo_source_id"), "Profession evidence lost the actual source.")
	_expect(data.deposits.water.remaining == 7 and second.remaining == 7 and data.stock.water == 0, "Pickup credited store or changed both sources.")
	# Reassignment while carrying does not alter provenance or finish the trip.
	b.workplace_id = first.id
	_expect(b.cargo_source_id == second.id and Work.target(data, b) == data.anchor, "Reassignment teleported or replaced freight.")
	before = data.duplicate(true)
	b.order = "wait"
	Work.step(data, b, 100.0, 1.0, [])
	before.members[2].order = "wait"
	_expect(data == before, "Paused freight was delivered.")
	b.order = "water"
	b.workplace_id = second.id
	for worker: Dictionary in [a, b]:
		worker.position = data.anchor.duplicate(true)
		before = Work.snapshot(data, worker)
		Work.step(data, worker, 0.25, 1.0, [])
		Progress.observe_work(record, before, data, before.members[data.members.find(worker)], worker)
	_expect(data.stock.water == 2 and record.jobs.get("provider", {}).get("units", 0) == 2 and record.pending.is_empty(), "Arrived work did not book exactly once.")
	_expect(Tribe.validate(data, body, campaign).is_empty(), "Two-source ledger invalid: " + Tribe.validate(data, body, campaign))
	_reject_instances(body, campaign)
	_capacity_race(data)
	_cross_site(body, campaign)
	# Build a first forester, then checkpoint a second with reserved materials
	# and a real construction binding. Existing wells work on certified routes.
	a.order = "wait"
	b.order = "wait"
	_build(data, "forester", Vector3(-6, 0, -4))
	_begin(data, "forester", Vector3(7, 0, -4))
	var builder: Dictionary = data.members[0]
	builder.order = "forester"
	builder.position = data.anchor.duplicate(true)
	Work.step(data, builder, 0.25, 1.0, [])
	_expect(builder.cargo == "wood" and builder.construction_id == data.project.id and data.project.materials.wood == 3, "Second construction did not reserve and bind its freight.")
	for worker: Dictionary in [a, b]:
		worker.order = "water"
		worker.position = E.source(data, worker, "water").position.duplicate(true)
		Work.step(data, worker, 3.0, 1.0, [])
		worker.blocked = true
	_certify_all(body, campaign)
	body.village_simulation.owner = "near"
	_expect(saves.save_now(), "Native workplace save failed: " + saves.last_error)
	var committed: String = FileAccess.get_file_as_string(SAVE_PATH)
	DirAccess.make_dir_absolute(SAVE_PATH + ".tmp")
	_expect(not saves.save_now() and FileAccess.get_file_as_string(SAVE_PATH) == committed, "Failed save replaced committed construction.")
	DirAccess.remove_absolute(SAVE_PATH + ".tmp")
	_expect(Atomic.write(EXPECTED_PATH, {"state": state.export_state()}, false) == OK, "Restart evidence failed.")
	var output: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--workplace-restart"])
	_expect(OS.execute(OS.get_executable_path(), args, output, true) == 0 and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"), "Native restart failed: " + str(output))
	print(str(output))
	await _finish_workplaces()

func _begin(data: Dictionary, kind: String, offset: Vector3) -> void:
	data.project = E.station_project(data, kind, Home.offset_place(data.anchor, offset))
	for resource: String in E.COSTS[kind]: data.stock[resource] -= E.COSTS[kind][resource]

func _all_kinds(body: Dictionary, campaign: Dictionary) -> void:
	var copy: Dictionary = body.duplicate(true)
	var data: Dictionary = copy.tribe
	for resource: String in ["wood", "stone"]:
		data.stock[resource] += data.deposits[resource].remaining
		data.deposits[resource].remaining = 0
	var row: int = 0
	for kind: String in E.STATIONS:
		while not E.next_station(data, kind).is_empty():
			var key: String = E.next_station(data, kind)
			_build(data, kind, Vector3(-9 if key == kind else 9, 0, -9 + row * 6))
			_expect(data.economy.stations[key].id == Tribe.Ids.scoped("workplace", data.id, key), "Wrong instance ID for " + key)
		row += 1
	E.tick(data, 1000.0)
	_expect(data.economy.stations.size() == 8, "Four kinds did not reach exactly eight bounded instances.")
	for resource: String in E.INTERVALS:
		_expect(E.remaining(data, resource) == 16, "Independent eight-unit capacities failed: " + resource)
	_expect(Tribe.validate(data, copy, campaign).is_empty(), "Full workplace budget invalid: " + Tribe.validate(data, copy, campaign))

func _build(data: Dictionary, kind: String, offset: Vector3) -> void:
	_begin(data, kind, offset)
	var worker: Dictionary = data.members[0]
	worker.order = kind
	for index in range(200):
		if data.project.is_empty(): break
		worker.position = Work.target(data, worker).duplicate(true)
		Work.step(data, worker, 0.25, 1.0, [])
	_expect(data.project.is_empty(), "Construction did not finish: " + kind)

func _reject_instances(body: Dictionary, campaign: Dictionary) -> void:
	for mode: String in ["foreign_id", "third", "missing_first", "invalid_first", "overlap", "negative", "fractional", "overfull", "clock", "nan", "owner", "cargo", "duplicate_stock", "downgrade", "future"]:
		var copy: Dictionary = body.duplicate(true)
		var data: Dictionary = copy.tribe
		var site: Dictionary = data.economy.stations["well:2"]
		match mode:
			"foreign_id": site.id = "foreign-workplace"
			"third": data.economy.stations["well:3"] = site.duplicate(true)
			"missing_first": data.economy.stations.erase("well")
			"invalid_first":
				data.economy.stations.erase("well")
				data.economy.stations["well"] = "invalid"
			"overlap": site.position = data.economy.stations.well.position
			"negative": site.remaining = -1
			"fractional": site.remaining = 1.5
			"overfull": site.remaining = 9
			"clock": site.clock = 5.5
			"nan": site.clock = NAN
			"owner": data.members[1].workplace_id = "another-village-well"
			"cargo": data.members[1].cargo_source_id = site.id
			"duplicate_stock": data.stock.water = 20
			"downgrade": data.economy.schema = 2
			"future": data.economy.schema = 999
		_expect(not Tribe.validate(data, copy, campaign).is_empty(), "Corrupt instance accepted: " + mode)
		if mode in ["downgrade", "future"]: _expect(E.has_unsupported_contract(data.economy), "Unsupported contract could fall back: " + mode)

func _capacity_race(data: Dictionary) -> void:
	var copy: Dictionary = data.duplicate(true)
	copy.stock.water = 47
	copy.economy.produced.water = 61
	for index in [1, 2]:
		var worker: Dictionary = copy.members[index]
		worker.profession = "none"
		worker.position = E.source(copy, worker, "water").position.duplicate(true)
		Work.step(copy, worker, 3.0, 1.0, [])
	_expect(E.reserve(copy, "water") == 48 and E.carried(copy, "water") == 1, "Two workplaces exceeded shared storage capacity.")

func _cross_site(body: Dictionary, campaign: Dictionary) -> void:
	var prepared: Dictionary = Settlements.prepare_legacy(body, campaign)
	_expect(prepared.ok, "Workplaces could not enter collection format.")
	if not prepared.ok: return
	var copy: Dictionary = prepared.body
	var original: String = Settlements.origin_id(copy)
	# Fixture-only resident allocation; no claim of founding a distant site.
	Settlements.instance_view(copy, original).tribe.members.back().erase("workplace_id")
	var second: String = _second(copy, campaign)
	var other: Dictionary = Settlements.instance_view(copy, second).tribe
	for resource: String in ["wood", "stone"]:
		other.stock[resource] = 10
		other.deposits[resource].remaining -= 10
	_build(other, "well", Vector3(0, 0, -7))
	var origin: Dictionary = Settlements.instance_view(copy, original).tribe
	_expect(Settlements.validate(copy, campaign).is_empty(), "Two instances per site invalid: " + Settlements.validate(copy, campaign))
	var before: Dictionary = origin.duplicate(true)
	E.tick(other, 7.0)
	_expect(origin == before and origin.economy.stations["well:2"].id != other.economy.stations["well:2"].id, "Sources leaked across settlement owners.")
	other.members[0]["workplace_id"] = origin.economy.stations["well:2"].id
	_expect(not Settlements.validate(copy, campaign).is_empty(), "A resident accepted another settlement's source.")

func _certify_all(body: Dictionary, campaign: Dictionary) -> void:
	_certify(body, campaign)
	body.village_simulation.cursor = campaign.elapsed_seconds
	for site: Dictionary in body.tribe.economy.stations.values():
		body.village_simulation.roads[Simulation.key(site.position)] = [body.tribe.anchor, site.position]

func _reload(state: Node, saves: Node) -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED_PATH))
	_expect(saves.load_now(SAVE_PATH), "Native reload failed: " + saves.last_error)
	_expect(_fingerprint(state.export_state()) == _fingerprint(expected.state), "Restart changed clocks, IDs, construction, routes or freight.")
	var body: Dictionary = state.get_current_body_record()
	var data: Dictionary = body.tribe
	var paused: String = _fingerprint(data)
	for index in range(4): Simulation.advance(body, 120.0)
	_expect(_fingerprint(data) == paused, "Near village was also advanced remotely.")
	body.village_simulation.owner = "far"
	for index in range(320): Simulation.advance(body, 180.0, 1.0, Callable(), true)
	_expect(data.project.is_empty() and data.economy.stations.has("forester:2"), "Second construction did not resume after process restart.")
	for worker: Dictionary in data.members.slice(1):
		_expect(worker.cargo == "water" and worker.blocked, "Blocked cargo arrived in the far simulation.")
		worker.blocked = false
	for index in range(160): Simulation.advance(body, 220.0, 1.0, Callable(), true)
	state.campaign.data.elapsed_seconds = 220.0
	_expect(data.stock.water > 2, "Held water did not resume over certified paths.")
	_expect(Tribe.validate(data, body, state.campaign.data).is_empty(), "Restarted ledger invalid: " + Tribe.validate(data, body, state.campaign.data))
	paused = _fingerprint(body)
	for index in range(4): Simulation.advance(body, 220.0)
	_expect(_fingerprint(body) == paused, "Unchanged campaign clock created production.")
	_expect(saves.save_now(), "Resumed workplace state did not save: " + saves.last_error)
	var future: Dictionary = saves._read_save(SAVE_PATH)
	preload("res://core/campaign/body_registry.gd").active(future.game_state).tribe.economy.schema = 999
	_expect(Atomic.write("user://workplace-future.json", future, false) == OK, "Future fixture failed.")
	_expect(Atomic.write("user://workplace-future.json.bak", saves._read_save(SAVE_PATH), false) == OK, "Backup fixture failed.")
	var bytes: String = FileAccess.get_file_as_string("user://workplace-future.json")
	_expect(not saves.load_now("user://workplace-future.json") and not saves.save_now("user://workplace-future.json"), "Future workplace version fell back or was overwritten.")
	_expect(FileAccess.get_file_as_string("user://workplace-future.json") == bytes, "Future save bytes changed.")

func _finish_workplaces() -> void:
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("WORKPLACE_INSTANCES_PASSED: %d checks; independent sources, material reservations, provenance, profession evidence and native restart." % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
