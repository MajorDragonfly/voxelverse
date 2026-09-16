extends "res://tests/workplace_instances_test.gd"
const Construction = Tribe.Construction
const CHECKPOINT: String = "user://construction-control.json"
const EXPECTED: String = "user://construction-control-expected.json"

func _run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	state.set_process(false)
	if "--construction-restart" in OS.get_cmdline_user_args():
		await _restart_control(state, saves)
		await _end_control()
		return
	var slot: String = saves.create_slot("Construction control", 15838, Home.Cube.MODE)
	_expect(not slot.is_empty(), "Cannot create construction test slot.")
	saves.save_path = CHECKPOINT
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
	# A real renewable source accounts for fiber, including every returned unit.
	data.economy.stations.fiberbed = {"id": Tribe.Ids.scoped("workplace", data.id, "fiberbed"), "position": data.deposits.fiber.position}
	data.economy.produced.fiber = 8
	data.stock.fiber = 8
	_all_control_kinds(body, campaign)
	_legacy_economy(body, campaign)
	_contribution_attempts(body, campaign)
	_start_site(data, "hut")
	var worker: Dictionary = data.members[1]
	worker.order = "build"
	worker.position = data.anchor.duplicate(true)
	Work.step(data, worker, 1, 1, [])
	_expect(worker.construction_id == data.project.id, "No real reserved pickup.")
	_expect(Construction.command(data, "pause").ok, "Cannot pause.")
	var untouched: Dictionary = data.duplicate(true)
	_expect(not Construction.command(data, "pause").ok and data == untouched, "Repeated pause changed state.")
	worker.position = data.project.entrance.duplicate(true)
	Work.step(data, worker, 30, 1, [])
	_expect(worker.cargo == "" and data.project.delivered_materials.wood == 1 and data.project.progress == 0, "In-flight delivery did not finish safely during pause.")
	untouched = data.duplicate(true)
	Work.step(data, worker, 30, 1, [])
	_expect(data == untouched and Construction.idle(data, worker) and Work.target(data, worker) == worker.position, "Paused construction picked up or worked.")
	_certify_all(body, campaign)
	body.village_simulation.roads[Simulation.key(data.project.entrance)] = [data.anchor, data.project.entrance]
	body.village_simulation.owner = "near"
	_expect(saves.save_now(), "Paused project cannot save: " + saves.last_error)
	_expect(Atomic.write("user://construction-paused.json", saves._read_save(CHECKPOINT), false) == OK, "Paused checkpoint failed.")
	_expect(Construction.command(data, "resume").ok, "Cannot resume.")
	worker.position = data.anchor.duplicate(true)
	Work.step(data, worker, 1, 1, [])
	worker.position = Home.offset_place(data.anchor, Vector3(0, 0, 4))
	var delivered: int = data.delivered
	_expect(Construction.command(data, "cancel").ok, "Cannot begin recovery.")
	_expect(data.stock.wood == 18 and worker.cargo == "wood" and data.project.delivered_materials.wood == 1, "Cancellation teleported on-site or carried goods.")
	_expect(E.reserve(data, "wood") == 20 and Tribe.available_storage(data, "wood") == 28, "Return space is not reserved.")
	untouched = data.duplicate(true)
	Work.step(data, worker, 1, 1, [])
	_expect(data == untouched, "Recovery arrived from outside the warehouse.")
	_expect(not Construction.command(data, "cancel").ok and data == untouched, "Repeated cancellation refunded twice.")
	_expect(not Construction.command(data, "resume").ok and data == untouched, "Recovery changed back into construction.")
	_corruptions(body, campaign)
	_capacity_check(data)
	_two_sites(body, campaign)
	_far_recovery(body, campaign)
	_expect(Tribe.validate(data, body, campaign).is_empty(), "Recovery state is invalid: " + Tribe.validate(data, body, campaign))
	_expect(saves.save_now(), "Recovery save failed: " + saves.last_error)
	var bytes: String = FileAccess.get_file_as_string(CHECKPOINT)
	DirAccess.make_dir_absolute(CHECKPOINT + ".tmp")
	_expect(not saves.save_now() and FileAccess.get_file_as_string(CHECKPOINT) == bytes, "Failed writer changed the recovery checkpoint.")
	DirAccess.remove_absolute(CHECKPOINT + ".tmp")
	_expect(Atomic.write(EXPECTED, {"state": state.export_state(), "delivered": delivered}, false) == OK, "Restart expectation failed.")
	var output: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--construction-restart"])
	_expect(OS.execute(OS.get_executable_path(), args, output, true) == 0 and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"), "Fresh construction process failed: " + str(output))
	print(str(output))
	await _end_control()

func _start_site(data: Dictionary, kind: String) -> void:
	var point: Variant = Home.offset_place(data.anchor, Vector3(7, 0, 3))
	if kind in E.STATIONS:
		data.project = E.station_project(data, kind, point)
	else:
		data.project = Tribe.Housing.site(data, kind, point, 0)
		data.project.merge({"progress": 0.0, "materials": Tribe.Housing.COSTS[kind].duplicate(), "delivered_materials": {}})
		for resource: String in data.project.materials: data.project.delivered_materials[resource] = 0
	for resource: String in Construction.costs(data.project): data.stock[resource] -= Construction.costs(data.project)[resource]

func _all_control_kinds(body: Dictionary, campaign: Dictionary) -> void:
	for kind: String in Tribe.Housing.BUILDS + E.STATIONS.keys():
		var copy: Dictionary = body.duplicate(true)
		var data: Dictionary = copy.tribe
		var original: Dictionary = data.stock.duplicate()
		_start_site(data, kind)
		_expect(Tribe.validate(data, copy, campaign).is_empty(), "Invalid fixture: " + kind + " " + Tribe.validate(data, copy, campaign))
		_expect(Construction.command(data, "pause").ok and Construction.command(data, "resume").ok, "Pause/resume rejected: " + kind)
		_expect(Construction.command(data, "cancel").ok and data.project.is_empty() and data.stock == original, "Untouched reservation did not return exactly: " + kind)
		_expect(Tribe.validate(data, copy, campaign).is_empty(), "Cancelled fixture invalid: " + kind)
	# Old prepaid tool/garden projects retain their exact costs and work.
	for kind: String in ["tool", "garden"]:
		var data: Dictionary = body.tribe.duplicate(true)
		var original: Dictionary = data.stock.duplicate()
		data.project = {"kind": kind, "progress": 3.0}
		for resource: String in Tribe.COSTS[kind]: data.stock[resource] -= Tribe.COSTS[kind][resource]
		_expect(Construction.command(data, "pause").ok and data.project.progress == 3.0, "Legacy project progress changed.")
		_expect(Construction.command(data, "cancel").ok and data.stock == original and data.project.is_empty(), "Prepaid project was refunded incorrectly.")

func _capacity_check(data: Dictionary) -> void:
	var copy: Dictionary = data.duplicate(true)
	copy.project.control = {"schema": 1, "state": "paused"}
	# Recreate an unstarted valid reservation for this arithmetic-only capacity case.
	copy.project.materials = Tribe.Housing.COSTS.hut.duplicate()
	copy.project.delivered_materials = {"wood": 0, "stone": 0}
	copy.members[1].cargo = ""
	copy.members[1].construction_id = ""
	copy.stock.wood = 43
	var before: Dictionary = copy.duplicate(true)
	_expect(Construction.command(copy, "cancel").code == "CONSTRUCTION_STORAGE_FULL" and copy == before, "Full warehouse accepted or partly applied cancellation.")
	copy.stock.wood = 42
	_expect(Construction.command(copy, "cancel").ok and copy.stock.wood == 48, "Exact capacity rejected.")
	copy = data.duplicate(true)
	copy.stock.wood = 46
	copy.economy.freight = E.Freight.create()
	_expect(E.reserve(copy, "wood") == 48 and Tribe.available_storage(copy, "wood") == 0, "Recovery did not reserve the last two spaces.")
	copy.economy.freight.held.wood = 1
	_expect(E.reserve(copy, "wood") == 49 and Tribe.available_storage(copy, "wood") < 0, "Inbound warehouse transport ignored recovery reservations.")

func _legacy_economy(body: Dictionary, campaign: Dictionary) -> void:
	var copy: Dictionary = body.duplicate(true)
	var data: Dictionary = copy.tribe
	_start_site(data, "forester")
	data.economy.schema = 3
	data.members[1].order = "forester"
	data.members[1].position = data.anchor.duplicate(true)
	Work.step(data, data.members[1], 1, 1, [])
	data.economy.clocks.water = 1.125
	var before: Dictionary = data.duplicate(true)
	_expect(Tribe.validate(data, copy, campaign).is_empty(), "Schema 3 checkpoint cannot be read before migration.")
	_expect(Tribe.upgrade(data), "Schema 3 did not upgrade.")
	before.economy.schema = E.SCHEMA
	_expect(data == before and not Tribe.upgrade(data), "Schema 3 migration lost cargo, time or project identity.")

func _far_recovery(body: Dictionary, campaign: Dictionary) -> void:
	var copy: Dictionary = body.duplicate(true)
	_certify_all(copy, campaign)
	var data: Dictionary = copy.tribe
	var worker: Dictionary = data.members[1]
	worker.blocked = true
	for tick in range(20): Simulation.advance(copy, 105.0, 1.0, Callable(), true)
	_expect(data.stock.wood == 18 and worker.cargo == "wood", "Blocked far carrier teleported its return cargo.")
	var fixed: Dictionary = copy.duplicate(true)
	for tick in range(4): Simulation.advance(copy, 105.0, 1.0, Callable(), true)
	_expect(copy == fixed, "Unchanged campaign time advanced recovery.")
	worker.blocked = false
	for tick in range(160): Simulation.advance(copy, 145.0, 1.0, Callable(), true)
	_expect(data.project.is_empty() and data.stock.wood == 20 and data.stock.stone == 20 and data.huts == 0, "Certified far paths did not complete material recovery.")
	_expect(data.delivered == body.tribe.delivered and Tribe.validate(data, copy, campaign).is_empty(), "Far recovery earned credit or invalidated the village.")

func _contribution_attempts(body: Dictionary, campaign: Dictionary) -> void:
	var copy: Dictionary = body.duplicate(true)
	copy.tribe = Tribe.create(copy.home_group, campaign, {"surface_address": copy.home_group.anchor}, _sites(copy.home_group.anchor))
	var data: Dictionary = copy.tribe
	for kind: String in ["wood", "stone"]:
		data.stock[kind] = 20
		data.deposits[kind].remaining -= 20
	var progress = preload("res://core/progression/tribal_progression.gd").new()
	data.project = {"kind": "tool", "progress": 0.0, "attempt_id": Tribe.Ids.create("construction")}
	for kind: String in Tribe.COSTS.tool: data.stock[kind] -= Tribe.COSTS.tool[kind]
	for index in [0, 1]:
		var worker: Dictionary = data.members[index]
		worker.order = "tool"
		var before: Dictionary = Work.snapshot(data, worker)
		Work.step(data, worker, 2, 1, [])
		progress.observe(before, data, worker.id, copy, campaign, 1)
		var observed: Dictionary = progress.export_state()
		progress.observe(before, data, worker.id, copy, campaign, 1)
		_expect(progress.export_state() == observed, "Repeated construction observation changed contributors.")
	_expect(Construction.command(data, "cancel").ok and data.tools == 0, "Could not cancel the unfinished tool.")
	data.project = {"kind": "tool", "progress": 0.0, "attempt_id": Tribe.Ids.create("construction")}
	for kind: String in Tribe.COSTS.tool: data.stock[kind] -= Tribe.COSTS.tool[kind]
	var worker: Dictionary = data.members[1]
	worker.order = "tool"
	var before: Dictionary = Work.snapshot(data, worker)
	Work.step(data, worker, 10, 1, [])
	progress.observe(before, data, worker.id, copy, campaign, 1)
	_expect(data.tools == 1 and not progress.export_state().awards.has("shared_tool"), "Cancelled attempt contributed to a later solo construction reward.")

func _corruptions(body: Dictionary, campaign: Dictionary) -> void:
	for mode: String in ["schema", "state", "negative", "fraction", "duplicate", "missing", "reserved", "downgrade", "bad_economy"]:
		var copy: Dictionary = body.duplicate(true)
		match mode:
			"schema": copy.tribe.project.control.schema = 999
			"state": copy.tribe.project.control.state = "future"
			"negative": copy.tribe.project.control.refunded.wood = -1
			"fraction": copy.tribe.project.control.refunded.wood = 0.5
			"duplicate": copy.tribe.project.control.refunded.wood += 1
			"missing": copy.tribe.project.control.erase("refunded")
			"reserved": copy.tribe.project.materials.wood = 1
			"downgrade": copy.tribe.economy.schema = 3
			"bad_economy": copy.tribe.economy = "invalid"
		_expect(not Tribe.validate(copy.tribe, copy, campaign).is_empty(), "Corrupt recovery accepted: " + mode)
		if mode in ["schema", "state", "downgrade", "bad_economy"]: _expect(Construction.unsupported(copy.tribe), "Future project is not protected.")

func _two_sites(body: Dictionary, campaign: Dictionary) -> void:
	var prepared: Dictionary = Settlements.prepare_legacy(body, campaign)
	_expect(prepared.ok, "Recovery cannot enter settlement collection.")
	if not prepared.ok: return
	var copy: Dictionary = prepared.body
	var second: String = _second(copy, campaign)
	_expect(Settlements.validate(copy, campaign).is_empty(), "Two-site recovery invalid: " + Settlements.validate(copy, campaign))
	var other: Dictionary = copy.settlements.entries[second].village.duplicate(true)
	copy.settlements.entries[Settlements.origin_id(copy)].village.project.control.schema = 999
	_expect(Settlements.unsupported(copy), "Secondary collection future protection missing.")
	_expect(copy.settlements.entries[second].village == other, "Source recovery modified another village.")

func _restart_control(state: Node, saves: Node) -> void:
	_expect(saves.load_now("user://construction-paused.json"), "Paused save did not load.")
	var body: Dictionary = state.get_current_body_record()
	var data: Dictionary = body.tribe
	var snapshot: Dictionary = data.project.duplicate(true)
	body.village_simulation.owner = "far"
	for tick in range(40): Simulation.advance(body, 110.0, 1.0, Callable(), true)
	_expect(data.project == snapshot, "Paused project worked in a fresh far process.")
	_expect(saves.load_now(CHECKPOINT), "Recovery save did not load: " + saves.last_error)
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED))
	_expect(_fingerprint(state.export_state()) == _fingerprint(expected.state), "Reload changed project, cargo, identities or simulation time.")
	body = state.get_current_body_record()
	data = body.tribe
	var worker: Dictionary = data.members[1]
	var effects: Array = []
	worker.position = data.anchor.duplicate(true)
	Work.step(data, worker, 1, 1, effects)
	_expect(data.stock.wood == 19 and worker.cargo == "" and data.project.control.refunded.wood == 5, "Held return cargo was not delivered once.")
	worker.position = data.project.entrance.duplicate(true)
	Work.step(data, worker, 1, 1, effects)
	_expect(worker.cargo == "wood" and data.stock.wood == 19, "On-site recovery skipped carrying.")
	worker.order = "wait"
	var held: Dictionary = data.duplicate(true)
	Work.step(data, worker, 100, 1, effects)
	_expect(data == held, "Stopped return carrier moved goods.")
	worker.order = "wood" # A reassigned carrier still completes its bound return.
	data.members[2].order = "hut"
	worker.position = data.anchor.duplicate(true)
	var full_before: Dictionary = data.duplicate(true)
	var step_before: Dictionary = Work.snapshot(data, worker)
	Work.step(data, worker, 1, 1, effects)
	_expect(step_before == full_before, "Recovery completion changed another resident through the observation snapshot.")
	_expect(data.project.is_empty() and data.stock.wood == 20 and data.stock.stone == 20 and data.huts == 0, "Recovery did not restore the exact original materials.")
	_expect(data.delivered == expected.delivered and effects.all(func(effect: Dictionary) -> bool: return effect.kind in ["changed", "construction_recovered"]), "Recovery created delivery or construction credit.")
	_expect(Tribe.validate(data, body, state.campaign.data).is_empty(), "Returned goods invalidate save: " + Tribe.validate(data, body, state.campaign.data))
	_expect(saves.save_now(), "Recovered state cannot save.")
	var future: Dictionary = saves._read_save("user://construction-paused.json")
	preload("res://core/campaign/body_registry.gd").active(future.game_state).tribe.project.control.schema = 999
	_expect(Atomic.write("user://construction-future.json", future, false) == OK, "Future fixture write failed.")
	_expect(Atomic.write("user://construction-future.json.bak", saves._read_save("user://construction-paused.json"), false) == OK, "Future backup failed.")
	var bytes: String = FileAccess.get_file_as_string("user://construction-future.json")
	_expect(not saves.load_now("user://construction-future.json") and not saves.save_now("user://construction-future.json"), "Future construction loaded a backup or allowed overwrite.")
	_expect(bytes == FileAccess.get_file_as_string("user://construction-future.json"), "Future bytes changed.")

func _end_control() -> void:
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("CONSTRUCTION_CONTROL_PASSED: %d checks; material conservation, pause, recovery, capacity, two sites, native restart and future protection." % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
