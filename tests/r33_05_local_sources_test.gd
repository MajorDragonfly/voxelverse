extends "res://tests/r32_21_resource_area_test.gd"
const Sources = Areas.LocalSources
const LOCAL_SAVE: String = "user://r33-05-local.json"
const LOCAL_EXPECTED: String = "user://r33-05-expected.json"

func _run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	state.set_process(false)
	saves.autosave_enabled = false
	if "--local-restart" in OS.get_cmdline_user_args():
		_restart_local(state, saves)
		await _finish_local()
		return
	_expect(not saves.create_slot("Örtliche Quellen", 15838, Home.Cube.MODE).is_empty(), "Slot creation failed.")
	saves.save_path = LOCAL_SAVE
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
	_migration_local(body, campaign)
	var proposals: Array[Dictionary] = []
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var candidate: Dictionary = Sources.candidate(anchor, dx, dy)
			if Sources.record_valid(data, candidate) and Home.distance(candidate.position, anchor) > 5.0: proposals.append(candidate)
	var selected: Dictionary = {}
	for proposal: Dictionary in proposals:
		if selected.has(proposal.resource_id): continue
		selected[proposal.resource_id] = proposal
		_expect(Sources.admit(data, proposal), "Admission failed: " + proposal.resource_id)
	_expect(selected.size() == 3, "Deterministic local proposals omitted a resource type.")
	if selected.size() != 3: await _finish_local(); return
	var wood: Dictionary = Sources.get_source(data, selected.wood.id)
	var flint: Dictionary = Sources.get_source(data, selected.flint.id)
	var before: Dictionary = data.duplicate(true)
	_expect(Sources.admit(data, selected.wood) and data == before, "Repeated prop created another source/unit.")
	_corrupt_local(body, campaign, wood.id)
	_overlap_local(data, wood)
	var worker: Dictionary = data.members[1]
	var area: String = Areas.create(data, wood.position, 1.0, "wood", 48)
	_expect(Areas.assign(data, area, [worker]), "Area assignment failed.")
	Areas.dispatch(data, worker, _reachable)
	worker.position = wood.position.duplicate(true)
	before = Work.snapshot(data, worker)
	Work.step(data, worker, 3.0, 1.0, [])
	_expect(wood.remaining == 0 and worker.cargo == "wood" and worker.cargo_source_id == wood.id and data.stock.wood == 0, "Local pickup did not transfer exactly one unit into individual cargo.")
	_expect(Sources.get_source(before, wood.id).remaining == 1 and before.members[1].cargo == "", "Work before-image aliases live source/cargo.")
	_expect(Sources.admit(data, selected.wood) and wood.remaining == 0, "Re-admission refilled exhausted decoration.")
	before = data.duplicate(true)
	Tribe.Economy.tick(data, 10000.0)
	_expect(wood.remaining == 0, "Finite loose object regenerated over simulation time.")
	# Explicit direct world-source order uses the same canonical source as area.
	var direct: Dictionary = data.members[2]
	direct.resource_source_id = flint.id
	direct.order = "flint"
	direct.position = flint.position.duplicate(true)
	_expect(Tribe.Economy.source(data, direct, "flint") == flint and Areas.direct_valid(data, direct), "Direct source disagrees with area/canonical record.")
	Work.step(data, direct, 3.0, 1.0, [])
	_expect(flint.remaining == 0 and direct.cargo == "flint" and data.stock.flint == 0, "Direct flint pickup paid storage or duplicated source.")
	before = data.duplicate(true)
	Work.step(data, direct, 3.0, 1.0, [])
	_expect(data == before, "Cargo was credited before reaching storage.")
	# Withdrawal/reassign must preserve the old source, even across types.
	_expect(Areas.remove(data, area) and worker.cargo_source_id == wood.id and worker.cargo == "wood", "Withdrawal lost source cargo.")
	area = Areas.create(data, selected.stone.position, 1.0, "stone", 48)
	_expect(Areas.assign(data, area, [worker]) and worker.cargo_source_id == wood.id, "Reassignment lost carried provenance.")
	worker.paused_order = worker.order
	worker.order = "wait"
	before = data.duplicate(true)
	Work.step(data, worker, 20.0, 1.0, [])
	_expect(data == before, "Paused cargo progressed or was discarded.")
	_expect(Tribe.validate(data, body, campaign).is_empty(), "Canonical local ledger rejected: " + Tribe.validate(data, body, campaign))
	_certify(body, campaign)
	body.village_simulation.cursor = campaign.elapsed_seconds
	for source: Dictionary in Sources.entries(data).values(): body.village_simulation.roads[Simulation.key(source.position)] = [data.anchor, source.position]
	for member: Dictionary in data.members: body.village_simulation.roads[Simulation.key(member.position)] = [data.anchor, member.position]
	body.village_simulation.owner = "near"
	_expect(saves.save_now(), "Shared local-source save failed: " + saves.last_error)
	_expect(Atomic.write(LOCAL_EXPECTED, {"state": state.export_state(), "wood": wood.id, "flint": flint.id}, false) == OK, "Expected checkpoint failed.")
	var bytes: String = FileAccess.get_file_as_string(LOCAL_SAVE)
	DirAccess.make_dir_absolute(LOCAL_SAVE + ".tmp")
	_expect(not saves.save_now() and FileAccess.get_file_as_string(LOCAL_SAVE) == bytes, "Save failure replaced committed source/cargo bytes.")
	DirAccess.remove_absolute(LOCAL_SAVE + ".tmp")
	var output: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--local-restart"])
	_expect(OS.execute(OS.get_executable_path(), args, output, true) == 0 and not str(output).contains("ERROR"), "Fresh local-source process failed: " + str(output))
	print(str(output))
	await _finish_local()

func _migration_local(body: Dictionary, campaign: Dictionary) -> void:
	var old: Dictionary = body.tribe.duplicate(true)
	old.economy.schema = 5
	old.stock.erase("flint")
	old.deposits.wood.remaining -= 1
	old.members[1].merge({"cargo": "wood", "cargo_source_id": old.deposits.wood.id, "order": "wait", "paused_order": "wood", "stage": "return"}, true)
	var expected: Dictionary = old.duplicate(true)
	_expect(Tribe.validate(old, body, campaign).is_empty(), "Old schema 5 with paused cargo rejected.")
	_expect(Tribe.upgrade(old), "Schema 5 did not upgrade.")
	expected.economy.schema = 6
	expected.stock.flint = 0
	_expect(old == expected and not Tribe.upgrade(old) and not old.economy.has(Sources.FIELD), "Migration changed old sources/amounts or admitted decoration.")

func _overlap_local(data: Dictionary, source: Dictionary) -> void:
	var copy: Dictionary = data.duplicate(true)
	var a: String = Areas.create(copy, source.position, 1.0, source.resource_id, 48)
	var b: String = Areas.create(copy, source.position, 1.0, source.resource_id, 48)
	_expect(a != b and Areas.assign(copy, a, [copy.members[1]]) and Areas.assign(copy, b, [copy.members[2]]), "Overlapping areas failed.")
	for worker: Dictionary in copy.members.slice(1): Areas.dispatch(copy, worker, _reachable)
	_expect(copy.members.filter(func(m: Dictionary) -> bool: return m.get("resource_source_id", "") == source.id).size() == 1, "Last unit claimed by both areas.")
	for worker: Dictionary in copy.members.slice(1):
		worker.position = source.position.duplicate(true)
		Work.step(copy, worker, 3.0, 1.0, [])
	_expect(Sources.get_source(copy, source.id).remaining == 0 and Tribe.Economy.carried(copy, source.resource_id) == 1 and copy.stock[source.resource_id] == 0, "Contending workers created two units.")
	var blocked: Dictionary = data.duplicate(true)
	a = Areas.create(blocked, source.position, 1.0, source.resource_id, 48)
	Areas.assign(blocked, a, [blocked.members[1]])
	blocked.members[1].resource_source_id = source.id
	blocked.members[1].work = 2.5
	Areas.dispatch(blocked, blocked.members[1], func(_w: Dictionary, _s: Dictionary) -> bool: return false)
	_expect(blocked.members[1].get("resource_source_id", "") == "" and blocked.members[1].work == 0.0 and Sources.get_source(blocked, source.id).remaining == 1, "Blocked route consumed stock or retained transferable work.")
	Areas.dispatch(blocked, blocked.members[1], _reachable)
	_expect(blocked.members[1].resource_source_id == source.id, "Reopened route did not restore assignment.")
	Areas.set_workers(blocked, a, 0)
	_expect(blocked.members[1].get("resource_source_id", "") == "" and Sources.get_source(blocked, source.id).remaining == 1, "Withdrawal consumed source.")

func _corrupt_local(body: Dictionary, campaign: Dictionary, id: String) -> void:
	for mode: String in ["id", "region", "body", "place", "slot", "amount", "initial", "type", "regen", "cargo", "future", "downgrade"]:
		var copy: Dictionary = body.duplicate(true)
		var source: Dictionary = Sources.get_source(copy.tribe, id)
		match mode:
			"id": source.id = "foreign"
			"region": source.region_id = "foreign"
			"body": source.body_id = "foreign"
			"place": source.position.u += 0.000001
			"slot": source.slot[2] += 1
			"amount": source.remaining = -1
			"initial": source.initial = 2
			"type": source.resource_id = "food"
			"regen": source.regeneration = "daily"
			"cargo": copy.tribe.members[1].merge({"cargo": source.resource_id, "cargo_source_id": id}, true)
			"future": copy.tribe.economy[Sources.FIELD].schema = 999
			"downgrade": copy.tribe.economy.schema = 5
		_expect(not Tribe.validate(copy.tribe, copy, campaign).is_empty(), "Corrupt local source accepted: " + mode)
		if mode == "future": _expect(Tribe.Economy.has_unsupported_contract(copy.tribe.economy), "Source futureguard missing.")

func _restart_local(state: Node, saves: Node) -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(LOCAL_EXPECTED))
	var loaded: bool = saves.load_now(LOCAL_SAVE)
	_expect(loaded, "Native local reload failed: " + saves.last_error)
	if not loaded: return
	_expect(_fingerprint(state.export_state()) == _fingerprint(expected.state), "Restart changed local source/cargo/address/migration.")
	var body: Dictionary = state.get_current_body_record()
	var data: Dictionary = body.tribe
	var before: Dictionary = body.duplicate(true)
	_expect(not Simulation.advance(body, 150.0) and body == before, "Near village also worked remotely.")
	body.village_simulation.owner = "far"
	data.members[1].order = data.members[1].paused_order
	data.members[1].paused_order = ""
	# Return held wood after reassigning to stone; stop fresh stone gathering.
	Areas.get_area(data, data.members[1].resource_area_id).target = 0
	for i in range(160): Simulation.advance(body, 140.0, 1.0, Callable(), true)
	_expect(data.stock.wood == 1 and data.stock.flint == 1 and data.stock.stone == 0 and data.delivered == 2, "Existing certified return did not credit held local units exactly once.")
	_expect(Sources.get_source(data, expected.wood).remaining == 0 and Sources.get_source(data, expected.flint).remaining == 0, "Far/near switch refilled source.")
	before = body.duplicate(true)
	for i in range(8): Simulation.advance(body, 140.0, 1.0, Callable(), true)
	_expect(body == before, "Repeated cursor redelivered cargo.")
	state.campaign.data.elapsed_seconds = 140.0
	_expect(saves.save_now(), "Returned local ledger did not save: " + saves.last_error)
	var future: Dictionary = saves._read_save(LOCAL_SAVE)
	preload("res://core/campaign/body_registry.gd").active(future.game_state).tribe.economy[Sources.FIELD].schema = 999
	var path: String = "user://r33-05-future.json"
	Atomic.write(path, future, false)
	Atomic.write(path + ".bak", saves._read_save(LOCAL_SAVE), false)
	var bytes: String = FileAccess.get_file_as_string(path)
	_expect(not saves.load_now(path) and not saves.save_now(path) and FileAccess.get_file_as_string(path) == bytes, "Future source version fell back to old backup or was overwritten.")

func _finish_local() -> void:
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("R33_05_LOCAL_SOURCES_PASSED: %d checks; finite sources, overlap, direct flint, cargo, migration, save failure, native restart and futureguard." % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
