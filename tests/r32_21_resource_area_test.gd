extends "res://tests/settlement_collection_test.gd"
## Radial model + real SaveGameService/process restart. Physical campaign work
## is a separate test; no synthetic path is claimed as collision certification.
const Areas = preload("res://world/tribe/resource_area_model.gd")
const SAVE: String = "user://r32-21-areas.json"
const EXPECTED: String = "user://r32-21-expected.json"

func _run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	state.set_process(false)
	saves.autosave_enabled = false
	if "--area-restart" in OS.get_cmdline_user_args():
		_restart_areas(state, saves)
		await _finish_areas()
		return
	_expect(not saves.create_slot("Sammelgebiete", 15838, Home.Cube.MODE).is_empty(), "Native slot creation failed.")
	saves.save_path = SAVE
	state.current_phase = 1
	state.campaign.data.elapsed_seconds = 100.0
	var body: Dictionary = state.get_current_body_record()
	var campaign: Dictionary = state.campaign.data
	var anchor: Dictionary = body.surface_context.spawn.duplicate(true)
	anchor.radius = body.surface_context.radius
	var home: Dictionary = Home.create(body.id, campaign.player_species_id, Vector3.ZERO)
	home.merge({"schema": Home.SCHEMA, "surface_mode": Home.Cube.MODE, "anchor": anchor}, true)
	for member: Dictionary in home.members: member.position = Home.offset_place(anchor, Home.vector(member.position))
	body.home_group = home
	body.tribe = Tribe.create(home, campaign, {"surface_address": anchor}, _sites(anchor))
	var data: Dictionary = body.tribe
	_well(data, 0)
	data.economy.stations.forester = {"id": Tribe.Ids.scoped("workplace", data.id, "forester"), "position": data.deposits.wood.position.duplicate(true)}
	data.economy.stations["forester:2"] = {"id": Tribe.Ids.scoped("workplace", data.id, "forester:2"),
		"position": Home.offset_place(anchor, Vector3(7, 0, -4)), "remaining": 2, "clock": 0.0}
	data.economy.produced.wood = 2
	# Schema 4 migration preserves amounts, addresses, identities and cargo;
	# installing an area does not refill or subdivide any source.
	data.economy.schema = 4
	data.stock.erase("flint")
	var before: Dictionary = data.duplicate(true)
	_expect(Tribe.validate(data, body, campaign).is_empty(), "Legacy format 4 rejected.")
	_expect(Tribe.upgrade(data), "Format 4 did not migrate.")
	before.economy.schema = Tribe.Economy.SCHEMA
	before.stock.flint = 0
	_expect(data == before and not Tribe.upgrade(data), "Migration changed material or ran twice.")
	var inflight: Dictionary = data.duplicate(true)
	inflight.economy.schema = 4
	inflight.stock.erase("flint")
	inflight.deposits.wood.remaining -= 1
	inflight.members[1].merge({"order": "wait", "paused_order": "wood", "cargo": "wood", "cargo_source_id": inflight.deposits.wood.id, "stage": "return"}, true)
	inflight = Atomic.parse_dictionary(Atomic.stringify(inflight))
	var held_before: Dictionary = inflight.duplicate(true)
	_expect(Tribe.validate(inflight, Atomic.parse_dictionary(Atomic.stringify(body)), campaign).is_empty() and Tribe.upgrade(inflight), "Legacy in-flight format 4 did not validate/migrate: " + Tribe.validate(inflight, Atomic.parse_dictionary(Atomic.stringify(body)), campaign))
	held_before.economy.schema = Tribe.Economy.SCHEMA
	held_before.stock.flint = 0
	_expect(inflight == held_before, "Migration lost old paused cargo/source/amount/address.")
	var a: String = Areas.create(data, data.deposits.wood.position, 2.0, "wood", 2)
	var b: String = Areas.create(data, data.economy.stations["forester:2"].position, 2.0, "wood", 2)
	_expect(not a.is_empty() and not b.is_empty() and a != b, "Two stable areas failed.")
	_expect(data.deposits == before.deposits and data.stock == before.stock and data.economy.stations == before.economy.stations, "Creating a boundary changed material.")
	var wa: Dictionary = data.members[1]
	var wb: Dictionary = data.members[2]
	_expect(Areas.assign(data, a, [wa]) and Areas.assign(data, b, [wb]), "Resident assignment failed.")
	for member: Dictionary in [wa, wb]:
		Areas.dispatch(data, member, _reachable)
		var source: Dictionary = Tribe.Economy.source(data, member, "wood")
		_expect(not source.is_empty(), "Area found no matching local source.")
		member.position = source.position.duplicate(true)
		before = Work.snapshot(data, member)
		Work.step(data, member, 3.0, 1.0, [])
		_expect(member.cargo == "wood" and data.stock.wood == 0 and before.members[data.members.find(member)].cargo == "", "Pickup credited storage or corrupted its before-image.")
		_expect(member.cargo_source_id == source.id and Tribe.Economy.source(before, before.members[data.members.find(member)], "wood").remaining == source.remaining + 1, "Actual source/provenance missing from snapshot.")
	var source_a: String = wa.cargo_source_id
	var source_b: String = wb.cargo_source_id
	before = data.duplicate(true)
	Work.step(data, wa, 0.25, 1.0, [])
	_expect(data == before, "Cargo delivered while resident was still at the source.")
	_expect(Areas.remove(data, a), "Area removal failed.")
	_expect(wa.cargo == "wood" and wa.cargo_source_id == source_a and wa.order == "move", "Removal lost or credited carried cargo.")
	_expect(Areas.assign(data, b, [wa]) and wa.cargo_source_id == source_a, "Reassignment changed held provenance.")
	_expect(Tribe.validate(data, body, campaign).is_empty(), "In-flight area ledger invalid: " + Tribe.validate(data, body, campaign))
	_corrupt_cases(body, campaign, b)
	_competition(data, b)
	_overlapping_areas(data, b)
	_bounds_and_ids(data, b)
	_worker_count(data, b)
	_certify_all_areas(body, campaign)
	body.village_simulation.owner = "near"
	before = body.duplicate(true)
	_expect(not Simulation.advance(body, 120.0) and body == before, "Near village advanced twice.")
	_expect(saves.save_now(), "Native area save failed: " + saves.last_error)
	_expect(Atomic.write(EXPECTED, {"state": state.export_state(), "area": b, "sources": [source_a, source_b]}, false) == OK, "Expected restart snapshot failed.")
	var committed: String = FileAccess.get_file_as_string(SAVE)
	DirAccess.make_dir_absolute(SAVE + ".tmp")
	_expect(not saves.save_now() and FileAccess.get_file_as_string(SAVE) == committed, "Failed staging changed committed area/cargo bytes.")
	DirAccess.remove_absolute(SAVE + ".tmp")
	var output: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--area-restart"])
	_expect(OS.execute(OS.get_executable_path(), args, output, true) == 0 and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"), "Fresh area process failed: " + str(output))
	print(str(output))
	await _finish_areas()

func _reachable(_worker: Dictionary, _source: Dictionary) -> bool: return true

func _competition(data: Dictionary, identity: String) -> void:
	var copy: Dictionary = data.duplicate(true)
	var area: Dictionary = Areas.get_area(copy, identity)
	var source: Dictionary = copy.economy.stations["forester:2"]
	area.target = 48
	source.remaining = 1
	for worker: Dictionary in copy.members:
		worker.cargo = ""
		worker.erase("cargo_source_id")
		worker.erase("resource_source_id")
	Areas.assign(copy, identity, copy.members)
	for worker: Dictionary in copy.members: Areas.dispatch(copy, worker, _reachable)
	_expect(copy.members.filter(func(w: Dictionary) -> bool: return w.get("resource_source_id", "") == source.id).size() == 1, "One source unit was reserved by several residents.")
	for worker: Dictionary in copy.members:
		worker.position = source.position.duplicate(true)
		Work.step(copy, worker, 3.0, 1.0, [])
	_expect(source.remaining == 0 and Tribe.Economy.carried(copy, "wood") == 1 and copy.stock.wood == 0, "Contending pickups duplicated material or paid storage.")
	var worker: Dictionary = copy.members[0]
	worker.cargo = ""
	worker.erase("cargo_source_id")
	worker.work = 2.5
	Areas.dispatch(copy, worker, _reachable)
	_expect(worker.get("resource_source_id", "") == "" and worker.work == 0.0, "Exhaustion retained a stale source/work timer.")
	source.remaining = 1
	Areas.dispatch(copy, worker, func(_w: Dictionary, _s: Dictionary) -> bool: return false)
	_expect(worker.get("resource_source_id", "") == "", "Unreachable source got a work claim.")
	# Enlarging an explicitly edited area can select another existing source;
	# failed reachability never falls back to an out-of-area base deposit.
	Areas.update(copy, identity, copy.anchor, 8.0, "wood", 48)
	copy.deposits.wood.remaining = 1
	Areas.dispatch(copy, worker, func(_w: Dictionary, s: Dictionary) -> bool: return s.id == copy.deposits.wood.id)
	_expect(worker.get("resource_source_id", "") == copy.deposits.wood.id and worker.work == 0.0, "Source switch transferred work or ignored explicit bounds.")
	copy.stock.wood = 47
	for w: Dictionary in copy.members: w.cargo = ""
	for w: Dictionary in copy.members:
		Areas.dispatch(copy, w, _reachable)
		var s: Dictionary = Tribe.Economy.source(copy, w, "wood")
		if not s.is_empty():
			w.position = s.position.duplicate(true)
			Work.step(copy, w, 3.0, 1.0, [])
	_expect(Tribe.Economy.reserve(copy, "wood") == 48, "Shared storage/cargo target overshot under concurrent areas.")

func _overlapping_areas(data: Dictionary, identity: String) -> void:
	# Two independently identified boundaries compete for the SAME final source
	# unit. Finish existing freight through Work first; no fabricated stock.
	var copy: Dictionary = data.duplicate(true)
	for worker: Dictionary in copy.members:
		if worker.cargo != "":
			worker.position = copy.anchor.duplicate(true)
			Work.step(copy, worker, 0.25, 1.0, [])
	Areas.set_workers(copy, identity, 0)
	var source: Dictionary = copy.economy.stations["forester:2"]
	var area: Dictionary = Areas.get_area(copy, identity)
	Areas.update(copy, identity, area.center, area.radius, "wood", 48)
	var other: String = Areas.create(copy, area.center, area.radius, "wood", 48)
	var first: Dictionary = copy.members[1]
	var second: Dictionary = copy.members[2]
	_expect(not other.is_empty() and other != identity and source.remaining == 1 and Areas.assign(copy, identity, [first]) and Areas.assign(copy, other, [second]), "Overlapping independently identified area assignments failed.")
	for worker: Dictionary in [first, second]: Areas.dispatch(copy, worker, _reachable)
	_expect(first.get("resource_source_id", "") == source.id and second.get("resource_source_id", "") == "", "Two different areas both reserved the same final unit.")
	var stock: int = int(copy.stock.wood)
	for worker: Dictionary in [first, second]:
		worker.position = source.position.duplicate(true)
		Work.step(copy, worker, 3.0, 1.0, [])
	_expect(source.remaining == 0 and first.cargo == "wood" and second.cargo == "" and copy.stock.wood == stock, "Competing areas duplicated a pickup or credited storage.")
	var provenance: String = first.cargo_source_id
	_expect(Areas.remove(copy, identity) and Areas.assign(copy, other, [first]) and first.cargo == "wood" and first.cargo_source_id == provenance and copy.stock.wood == stock, "Area withdrawal/reassignment lost or paid the final source unit.")
	first.position = copy.anchor.duplicate(true)
	Work.step(copy, first, 0.25, 1.0, [])
	for worker: Dictionary in [first, second]:
		Areas.dispatch(copy, worker, _reachable)
		Work.step(copy, worker, 3.0, 1.0, [])
	_expect(copy.stock.wood == stock + 1 and first.cargo == "" and second.cargo == "" and source.remaining == 0 and Areas.validate(copy).is_empty(), "Exhausted overlapping areas paid the same unit twice or broke their bindings.")

func _bounds_and_ids(data: Dictionary, identity: String) -> void:
	var copy: Dictionary = data.duplicate(true)
	var previous: Dictionary = copy.duplicate(true)
	_expect(Areas.create(copy, Home.offset_place(copy.anchor, Vector3(19, 0, 0)), 2.0, "stone").is_empty() and copy == previous, "Boundary escaped the fixed village extent.")
	_expect(not Areas.update(copy, identity, Home.offset_place(copy.anchor, Vector3(0, 0, 0)), NAN, "wood", 12) and copy == previous, "Nonfinite radius changed the record.")
	var foreign: Dictionary = copy.anchor.duplicate(true)
	foreign.body_id = "foreign"
	_expect(Areas.create(copy, foreign, 2.0, "wood").is_empty(), "Area accepted another body.")
	var removed: String = Areas.create(copy, copy.anchor, 1.0, "stone")
	Areas.remove(copy, removed)
	var replacement: String = Areas.create(copy, copy.anchor, 1.0, "stone")
	_expect(removed != replacement, "Deleted area identity reused.")
	while Areas.entries(copy).size() < Areas.MAX_AREAS: Areas.create(copy, copy.anchor, 1.0, "food")
	previous = copy.duplicate(true)
	_expect(Areas.create(copy, copy.anchor, 1.0, "food").is_empty() and copy == previous, "Finite area budget exceeded.")

func _worker_count(data: Dictionary, identity: String) -> void:
	var copy: Dictionary = data.duplicate(true)
	var before: Dictionary = copy.duplicate(true)
	_expect(not Areas.set_workers(copy, identity, 4) and copy == before, "Impossible count changed assignments.")
	_expect(Areas.set_workers(copy, identity, 0), "Assignment withdrawal failed.")
	_expect(copy.members[1].cargo == data.members[1].cargo and copy.members[2].cargo == data.members[2].cargo and copy.stock == data.stock, "Withdrawal paid/discarded held cargo.")
	for worker: Dictionary in copy.members:
		worker.cargo = ""
		worker.erase("cargo_source_id")
		worker.order = "wait"
	_expect(Areas.set_workers(copy, identity, 2), "Explicit worker count failed.")
	_expect(Areas.get_area(copy, identity).workers == 2 and Areas.validate(copy).is_empty(), "Count and actual resident identities diverged.")
	before = copy.duplicate(true)
	_expect(not Areas.assign(copy, identity, [copy.members[0], copy.members[0]]) and copy == before, "Repeated selected resident was assigned twice.")

func _corrupt_cases(body: Dictionary, campaign: Dictionary, identity: String) -> void:
	for mode: String in ["id", "body", "radius", "center", "target", "workers", "source", "missing", "extension_future", "downgrade"]:
		var copy: Dictionary = body.duplicate(true)
		var area: Dictionary = Areas.get_area(copy.tribe, identity)
		match mode:
			"id": area.id = "foreign"
			"body": area.body_id = "foreign"
			"radius": area.radius = 100
			"center": area.center = Home.offset_place(copy.tribe.anchor, Vector3(40, 0, 0))
			"target": area.target = 1.5
			"workers": area.workers = 0
			"source": copy.tribe.members[1].resource_source_id = copy.tribe.deposits.stone.id
			"missing": copy.tribe.economy.erase("resource_areas")
			"extension_future": copy.tribe.economy.resource_areas.schema = 999
			"downgrade": copy.tribe.economy.schema = 4
		_expect(not Tribe.validate(copy.tribe, copy, campaign).is_empty(), "Corrupt area accepted: " + mode)
		if mode == "extension_future": _expect(Tribe.Economy.has_unsupported_contract(copy.tribe.economy), "Future area extension allowed fallback.")

func _certify_all_areas(body: Dictionary, campaign: Dictionary) -> void:
	_certify(body, campaign)
	for source: Dictionary in body.tribe.economy.stations.values():
		body.village_simulation.roads[Simulation.key(source.position)] = [body.tribe.anchor, source.position]
	for worker: Dictionary in body.tribe.members:
		body.village_simulation.roads[Simulation.key(worker.position)] = [body.tribe.anchor, worker.position]
	body.village_simulation.cursor = campaign.elapsed_seconds

func _restart_areas(state: Node, saves: Node) -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED))
	_expect(saves.load_now(SAVE), "Native reload failed: " + saves.last_error)
	_expect(_fingerprint(state.export_state()) == _fingerprint(expected.state), "Process restart changed area boundaries/IDs, cargo, amounts or cursor.")
	var body: Dictionary = state.get_current_body_record()
	var data: Dictionary = body.tribe
	var before: Dictionary = body.duplicate(true)
	for i in range(8): Simulation.advance(body, 100.0)
	_expect(body == before, "Paused clock/near owner produced material.")
	body.village_simulation.owner = "far"
	var delivered: int = data.delivered
	for i in range(160): Simulation.advance(body, 140.0, 1.0, Callable(), true)
	_expect(data.delivered == delivered + 2 and data.stock.wood == 2, "Certified return did not deliver precisely the two held units.")
	_expect(data.members[1].cargo == "" and data.members[2].cargo == "", "Old cargo retained after committed delivery.")
	before = body.duplicate(true)
	for i in range(8): Simulation.advance(body, 140.0, 1.0, Callable(), true)
	_expect(body == before, "Repeated cursor paid the same freight twice.")
	body.village_simulation.owner = "near"
	before = body.duplicate(true)
	_expect(not Simulation.advance(body, 170.0) and body == before, "Near/far ownership paid twice.")
	state.campaign.data.elapsed_seconds = 140.0
	_expect(Tribe.validate(data, body, state.campaign.data).is_empty(), "Resumed area ledger invalid: " + Tribe.validate(data, body, state.campaign.data))
	_expect(saves.save_now(), "Returned area state failed to save: " + saves.last_error)
	var future: Dictionary = saves._read_save(SAVE)
	preload("res://core/campaign/body_registry.gd").active(future.game_state).tribe.economy.resource_areas.schema = 999
	_expect(Atomic.write("user://r32-21-future.json", future, false) == OK, "Future fixture write failed.")
	_expect(Atomic.write("user://r32-21-future.json.bak", saves._read_save(SAVE), false) == OK, "Backup fixture write failed.")
	var bytes: String = FileAccess.get_file_as_string("user://r32-21-future.json")
	_expect(not saves.load_now("user://r32-21-future.json") and not saves.save_now("user://r32-21-future.json"), "Future area version fell back or was overwritten.")
	_expect(FileAccess.get_file_as_string("user://r32-21-future.json") == bytes, "Future save bytes changed.")

func _finish_areas() -> void:
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("R32_21_RESOURCE_AREA_PASSED: %d checks; bounded areas, source contention, cargo, migration, native restart, near/far cursor and future protection." % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
