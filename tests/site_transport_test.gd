extends "res://tests/settlement_collection_test.gd"
const Freight = preload("res://world/tribe/transport/site_transport_state.gd")
const SAVE: String = "user://site-freight-save.json"
const EXPECTED: String = "user://site-freight-expected.json"
var state: Node
var saves: Node

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	state.set_process(false)
	if "--site-freight-restart" in OS.get_cmdline_user_args():
		var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED))
		_expect(saves.load_now(SAVE), "Fresh-process common save failed: " + saves.last_error)
		var body: Dictionary = state.get_current_body_record()
		_expect(_fingerprint(body) == expected.fingerprint, "Restart changed stocks, capacity, identity or partial travel.")
		var b: Dictionary = Freight.village(body, Freight.job(body).destination.settlement_id)
		var previous: int = int(b.stock.wood)
		_finish_far(body)
		_expect(b.stock.wood == previous + 3 and Freight.job(body).status == "delivered", "Fresh process did not deliver once.")
		_expect(Freight.validate(body, state.campaign.data).is_empty(), "Restart broke freight balance.")
		_expect(saves.save_now(SAVE), "Completed native shipment did not save: " + saves.last_error)
		await _done()
		return
	_expect(not saves.create_slot("Inter-site freight fixture", 15838, Home.Cube.MODE).is_empty(), "Could not create native radial save.")
	saves.save_path = SAVE
	state.current_phase = 1
	state.campaign.data.elapsed_seconds = 100.0
	var body: Dictionary = state.get_current_body_record()
	_setup(body, state.campaign.data)
	var pristine: Dictionary = body.duplicate(true)
	for kind: String in Freight.Ledger.KINDS:
		body.clear(); body.merge(pristine.duplicate(true)); _clocks(body, 100.0)
		var ids: Array = Settlements.ids(body)
		var a: Dictionary = Freight.village(body, ids[0])
		var b: Dictionary = Freight.village(body, ids[1])
		_seed(a, kind, 4)
		var result: Dictionary = _reserve(body, kind, 3)
		_expect(result.ok, "Reserve failed for " + kind + ": " + str(result))
		if not result.ok: continue
		_expect(a.stock[kind] == 1 and b.stock[kind] == 0 and Freight.Economy.reserve(a, kind) == 4 and Freight.Economy.reserve(b, kind) == 3, "Stock/capacity reservation failed for " + kind)
		_expect(saves.save_now(), "Reserved native save failed for " + kind + ": " + saves.last_error)
		var reserved: Dictionary = body.duplicate(true)
		_expect(Freight.cancel(body) and a.stock[kind] == 4 and b.stock[kind] == 0, "Reserved cancellation lost goods: " + kind)
		_expect(not Freight.cancel(body), "Cancellation replay accepted.")
		_expect(saves.save_now(), "Cancelled native save failed: " + saves.last_error)
		body.clear(); body.merge(reserved)
		_finish_far(body)
		a = Freight.village(body, ids[0]); b = Freight.village(body, ids[1])
		_expect(a.stock[kind] == 1 and b.stock[kind] == 3, "Arrival did not credit correct village: " + kind)
		_expect(not Freight.settle(body), "Arrival replay accepted.")
		_expect(saves.save_now(), "Delivered native save failed for " + kind + ": " + saves.last_error)
	# Shared ARCH-26/27 acceptance: two producing wells at both endpoints.
	body.clear(); body.merge(pristine.duplicate(true)); _clocks(body, 100.0)
	for id: String in Settlements.ids(body):
		var data: Dictionary = Freight.village(body, id)
		_seed(data, "water", 4 if id == Settlements.ids(body)[0] else 0)
		var project: Dictionary = Freight.Economy.station_project(data, "well", Home.offset_place(data.anchor, Vector3(0, 0, -7)))
		Freight.Economy.complete_station(data, project)
		Freight.Economy.tick(data, 10.0)
		_expect(Freight.Economy.remaining(data, "water") == 4, "Two-well fixture lost a producing source.")
	_expect(_reserve(body, "water", 3).ok, "Two-well shipment reservation failed.")
	_expect(saves.save_now(), "Reserved two-well shipment failed the shared save contract: " + saves.last_error)
	_finish_far(body)
	var well_destination: Dictionary = Freight.village(body, Settlements.ids(body)[1])
	_expect(well_destination.stock.water == 3 and Freight.Economy.remaining(well_destination, "water") == 4, "Transport altered workplace sources or duplicated stock.")
	_expect(saves.save_now(), "Delivered two-well shipment failed the shared save contract: " + saves.last_error)
	# Faults and lifecycle cases use three actual units and certified model geometry.
	body.clear(); body.merge(pristine.duplicate(true)); _clocks(body, 100.0)
	_seed(Freight.village(body, Settlements.ids(body)[0]), "wood", 4)
	var unloaded: Dictionary = body.duplicate(true)
	_expect(_reserve(body, "wood", 3).ok, "Lifecycle reservation failed.")
	_expect(Freight.depart(body), "Pickup failed.")
	_expect(Freight.handoff(body, "far"), "Near-to-far at source failed.")
	_clocks(body, 100.25)
	_expect(Freight.advance(body, 100.25), "Far movement failed.")
	_expect(Freight.job(body).elapsed > 0 and Freight.job(body).status == "moving", "One slice skipped the route.")
	var moving: Dictionary = body.duplicate(true)
	var paused: String = _fingerprint(body)
	for i: int in 8: _expect(not Freight.advance(body, 100.25), "Paused clock advanced travel.")
	_expect(_fingerprint(body) == paused, "Pause changed position/stock/reservations.")
	# A missing regional graph suspends, never interprets eviction as arrival.
	body[Freight.FIELD].graph = {}
	_clocks(body, 120)
	Freight.advance(body, 120)
	_expect(Freight.job(body).blocked == "route.network_unavailable" and Freight.job(body).elapsed == moving[Freight.FIELD].job.elapsed, "Evicted network granted travel.")
	_expect(saves.save_now(), "Suspended graph could not save: " + saves.last_error)
	body[Freight.FIELD].graph = moving[Freight.FIELD].graph.duplicate(true)
	var held_elapsed: float = Freight.job(body).elapsed
	_clocks(body, 120.25)
	Freight.advance(body, 120.25)
	_expect(is_equal_approx(Freight.job(body).elapsed, held_elapsed + 0.25), "Reopening awarded blocked time.")
	# Return request is persisted mid-leg, then travels a real reverse route.
	_expect(Freight.cancel(body), "Loaded return was rejected.")
	var home_stock: int = Freight.village(body, Freight.job(body).source.settlement_id).stock.wood
	_expect(home_stock == 1, "Loaded cancellation teleported stock home.")
	_finish_far(body)
	_expect(Freight.job(body).status == "returned" and Freight.village(body, Freight.job(body).source.settlement_id).stock.wood == 4, "Return failed to conserve goods.")
	_expect(saves.save_now(), "Returned native save failed: " + saves.last_error)
	# Mid-segment handoffs retain cursor, position and exactly one carrier.
	body.clear(); body.merge(moving.duplicate(true))
	_clocks(body, 100.25)
	var location: Dictionary = Freight.member(body).position.duplicate(true)
	_expect(Freight.handoff(body, "near") and Freight.member(body).position == location, "Far-to-near moved the carrier.")
	_expect(Freight.handoff(body, "far") and Freight.member(body).position == location, "Near-to-far moved the carrier.")
	_expect(saves.save_now(), "Handoff native save failed: " + saves.last_error)
	# The real return preflight drains both existing village clocks and the load
	# before rebinding the source as near; no wall-clock time is introduced.
	state.campaign.data.elapsed_seconds = 125.0
	saves._body_transfer = {"player": saves._export_player_state()}
	_expect(await saves.prepare_body_target(state.system_seed, state.current_planet_index, state.world_seed, body.id), "Return with active shipment failed: " + saves.last_error)
	body = state.get_current_body_record()
	_expect(Freight.job(body).status == "delivered" and Freight.village(body, Freight.job(body).destination.settlement_id).stock.wood == 3, "Return preflight dropped or duplicated active shipment.")
	_expect(Freight.validate(body, state.campaign.data).is_empty(), "Return invalidated transport balances.")
	_expect(saves.save_now(SAVE), "Returning shipment could not save: " + saves.last_error)
	saves._body_transfer.clear()
	body.clear(); body.merge(moving.duplicate(true)); _clocks(body, 100.25)
	# Changed graph revision blocks; existing route is not a fresh certificate.
	var value: Dictionary = Freight.job(body)
	var edge: Dictionary = body[Freight.FIELD].graph.edges[value.route.legs[int(value.leg)].id]
	edge.revision += 1
	_clocks(body, 101)
	Freight.advance(body, 101)
	_expect(Freight.job(body).blocked == "route.recertification_required", "Revised route remained usable.")
	# Incoming capacity cannot be stolen by gathering or a second shipment.
	body.clear(); body.merge(unloaded.duplicate(true))
	var destination: Dictionary = Freight.village(body, Settlements.ids(body)[1])
	_seed(destination, "wood", 47)
	var full: String = _fingerprint(body)
	_expect(not _reserve(body, "wood", 3).ok and _fingerprint(body) == full, "Full destination accepted or mutated shipment.")
	body.clear(); body.merge(moving.duplicate(true)); _clocks(body, 100.25)
	var repeated: String = _fingerprint(body)
	_expect(not _reserve(body, "wood", 1).ok and _fingerprint(body) == repeated, "Double carrier/reservation accepted.")
	# Late receiving village must catch up before new stock becomes spendable.
	var delayed: Dictionary = body.duplicate(true)
	Freight.handoff(delayed, "near")
	for step in range(8):
		if Freight.job(delayed).status != "moving": break
		var j: Dictionary = Freight.job(delayed)
		Freight.member(delayed).position = j.route.nodes[int(j.leg) + 1].place.duplicate(true)
		Freight.observe(delayed, Freight.member(delayed).position, 102, true, false)
	_expect(Freight.job(delayed).status == "arrived" and Freight.village(delayed, Freight.job(delayed).destination.settlement_id).stock.wood == 0, "Arrival was consumed in past village time.")
	_clocks(delayed, 102)
	_expect(Freight.settle(delayed), "Caught-up destination did not accept arrived cargo.")
	# Validate corruption before restore; no stock-only or orphan capacity saves.
	for mode: String in ["missing_job", "counter", "held", "carrier", "destination"]:
		var bad: Dictionary = body.duplicate(true)
		match mode:
			"missing_job": bad.erase(Freight.FIELD)
			"counter": Freight.village(bad, Freight.job(bad).source.settlement_id).economy.freight.exports.wood += 1
			"held": Freight.village(bad, Freight.job(bad).destination.settlement_id).economy.freight.held.wood = 0
			"carrier": Freight.member(bad).order = "wood"
			"destination": Freight.job(bad).destination.settlement_id = "missing"
		_expect(not Freight.validate(bad, state.campaign.data).is_empty(), "Accepted corrupt freight: " + mode)
	for contract: String in ["job", "graph", "route", "resource"]:
		var future: Dictionary = body.duplicate(true)
		if contract in ["job", "graph"]: future[Freight.FIELD][contract].schema = 99
		elif contract == "route": future[Freight.FIELD].job.route.schema = 99
		else: future[Freight.FIELD].job.resource_revision = 99
		_expect(Freight.unsupported(future), "Future contract failed protection: " + contract)
	# Reaching the existing long-term counter cap is a rejected, read-only command.
	var capped: Dictionary = unloaded.duplicate(true)
	var capped_ids: Array = Settlements.ids(capped)
	for id: String in capped_ids: Freight.village(capped, id).economy.freight = Freight.Ledger.create()
	Freight.village(capped, capped_ids[0]).economy.freight.exports.wood = 1000000000
	Freight.village(capped, capped_ids[1]).economy.freight.imports.wood = 1000000000
	var capped_before: String = _fingerprint(capped)
	_expect(not _reserve(capped, "wood", 1).ok and _fingerprint(capped) == capped_before, "Counter limit partially mutated live ledgers.")
	# Real common-writer failure plus the same runtime rollback used by the UI.
	_expect(saves.save_now(SAVE), "Pre-error native save failed: " + saves.last_error)
	var committed: String = FileAccess.get_file_as_string(SAVE)
	var before: Dictionary = body.duplicate(true)
	DirAccess.make_dir_absolute(SAVE + ".tmp")
	_expect(Freight.cancel(body), "Could not stage return for write-failure check.")
	_expect(not saves.save_now() and FileAccess.get_file_as_string(SAVE) == committed, "Failed write replaced committed shipment.")
	body.clear(); body.merge(before)
	DirAccess.remove_absolute(SAVE + ".tmp")
	_expect(saves.load_now(SAVE), "Common save reload failed after write error.")
	body = state.get_current_body_record()
	_expect(_fingerprint(body) == _fingerprint(before), "Reload changed original shipment after write failure.")
	_expect(Atomic.write(EXPECTED, {"fingerprint": _fingerprint(body)}, false) == OK, "Could not write restart expectation.")
	var output: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--site-freight-restart"])
	_expect(OS.execute(OS.get_executable_path(), args, output, true) == 0 and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"), "Fresh process failed: " + str(output))
	# Future field versions must prevent fallback to the older complete backup.
	var saved: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(SAVE))
	var saved_body: Dictionary = saved.game_state.campaign.bodies[body.id]
	saved_body[Freight.FIELD].schema = 99
	_expect(Atomic.write(SAVE, saved, false) == OK, "Could not stage future schema.")
	_expect(not saves.load_now(SAVE) and not saves.save_now(SAVE), "Future freight schema allowed fallback/overwrite.")
	await _done()

func _setup(body: Dictionary, campaign: Dictionary) -> void:
	var anchor: Dictionary = body.surface_context.spawn.duplicate(true)
	anchor.radius = body.surface_context.radius
	var home: Dictionary = Home.create(body.id, campaign.player_species_id, Vector3.ZERO)
	home.merge({"schema": Home.SCHEMA, "surface_mode": Home.Cube.MODE, "anchor": anchor}, true)
	for m: Dictionary in home.members: m.position = Home.offset_place(anchor, Home.vector(m.position))
	body.home_group = home
	body.tribe = Tribe.create(home, campaign, {"surface_address": anchor}, _sites(anchor))
	var target: Dictionary = Home.offset_place(anchor, Vector3(17, 0, 0))
	body.tribe.members[2].position = target.duplicate(true)
	body.tribe.members[2].destination = target.duplicate(true)
	var result: Dictionary = Settlements.found(body, campaign, body.tribe.members[2].id, target, _sites(target))
	_expect(result.ok, "Native fixture founding failed: " + str(result))
	if not result.ok: return
	body.clear(); body.merge(result.body)
	var origin: Dictionary = Freight.village(body, Settlements.ids(body)[0])
	origin.members[1].position = origin.anchor.duplicate(true)
	origin.members[1].destination = origin.anchor.duplicate(true)
	for id: String in Settlements.ids(body): _certify(Settlements.view(body, id), campaign)

func _seed(data: Dictionary, kind: String, amount: int) -> void:
	if kind in ["wood", "stone", "food"]:
		data.deposits[kind].remaining -= amount
		data.stock[kind] += amount
	elif kind in ["water", "fiber"]:
		data.tools = 1
		var station: String = "well" if kind == "water" else "fiberbed"
		data.economy.stations[station] = {"id": Tribe.Ids.scoped("workplace", data.id, station), "position": data.deposits[kind].position.duplicate(true)}
		data.economy.produced[kind] += amount
		data.stock[kind] += amount
	else:
		var recipe: String = Freight.Economy.Batch.Production.MILK if kind == "milk" else Freight.Economy.Batch.Production.EGGS
		var batch: Dictionary = Freight.Economy.Batch.create(data, "freight-test-" + kind, 1, amount, data.anchor, recipe)
		_expect(Freight.Economy.receive_batch(data, batch).is_empty(), "Could not produce batch fixture.")
		var carrier: Dictionary = data.members[0]
		carrier.position = data.anchor.duplicate(true)
		carrier.order = kind
		for i: int in amount:
			_expect(Freight.Economy.collect(data, carrier, kind), "Could not pick up source batch.")
			Work.step(data, carrier, 0, 1, [])
		carrier.order = "wait"

func _reserve(body: Dictionary, kind: String, amount: int) -> Dictionary:
	var ids: Array = Settlements.ids(body)
	var a: Dictionary = Freight.village(body, ids[0])
	var b: Dictionary = Freight.village(body, ids[1])
	var network: Dictionary = Freight.graph(body, ids[0], ids[1], [a.anchor, Home.offset_place(a.anchor, Vector3(8, 0, 0)), b.anchor])
	return Freight.reserve(body, state.campaign.data, ids[0], ids[1], a.members[1].id, kind, amount, network)

func _clocks(body: Dictionary, clock: float) -> void:
	state.campaign.data.elapsed_seconds = clock
	for entry: Dictionary in body.settlements.entries.values(): entry.simulation.cursor = clock

func _finish_far(body: Dictionary) -> void:
	for i: int in 300:
		if not Freight.active(body): return
		_clocks(body, float(state.campaign.data.elapsed_seconds) + 0.25)
		Freight.advance(body, state.campaign.data.elapsed_seconds)
	_expect(false, "Shipment never finished: " + str(Freight.job(body)))

func _done() -> void:
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("SITE_TRANSPORT_PASSED: %d checks; seven resources, native save/restart, held capacity, returns, pause, network eviction, owner handoff and future schema." % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
