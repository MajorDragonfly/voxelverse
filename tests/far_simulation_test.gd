extends SceneTree
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Simulation = preload("res://world/tribe/village_simulation.gd")
const Registry = preload("res://core/campaign/body_registry.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const Migration = preload("res://core/campaign/spherical_migration.gd")
const SAVE: String = "user://far_simulation.json"
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves.save_path = SAVE
	state.set_process(false)
	if "--restart-check" in OS.get_cmdline_user_args():
		_expect(saves.load_now(), "Fresh process lost far state.")
		var snapshot: Dictionary = state.export_state()
		state._process(600.0)
		_expect(state.export_state() == snapshot, "Closed/menu time produced offline work.")
		await _finish()
		return
	state.start_world_with_seed(15838)
	state.current_phase = 1
	var a: Dictionary = state.get_current_body_record()
	a.home_group = Home.create(a.id, state.campaign.data.player_species_id, Vector3.ZERO)
	a.tribe = Tribe.create(a.home_group, state.campaign.data, {"position": [0, 0, 0]}, {"wood": [-5, 0, -4], "stone": [5, 0, -4], "food": [-5, 0, 4], "huts": [[5, 0, 4], [8, 0, 0]]})
	var roads: Dictionary = {}
	for point in [a.tribe.anchor, a.tribe.deposits.wood.position, a.tribe.deposits.stone.position, a.tribe.members[1].position, a.tribe.members[2].position]:
		var path: Array = []
		var count: int = maxi(1, ceili(Home.distance(a.tribe.anchor, point)))
		for index in range(count + 1): path.append(Simulation._interpolate(a.tribe.anchor, point, float(index) / count))
		roads[Simulation.key(point)] = path
	a.village_simulation = Simulation.create(a.id, 0, roads, [], state.campaign.data.player_object_id)
	var worker: Dictionary = a.tribe.members[1]
	worker.order = "wood"
	var blocked: Dictionary = a.tribe.members[2]
	blocked.order = "stone"
	blocked.cargo = "stone"
	blocked.blocked = true
	a.tribe.deposits.stone.remaining -= 1
	var b: Dictionary = state.campaign.ensure_body(15838, 23757)
	state.activate_body(b.id, 23757, 0, false)
	var player := Node3D.new()
	player.add_to_group(&"player")
	root.add_child(player)
	player.set_physics_process(true)
	for index in range(8): state._process(0.25)
	_expect(a.tribe.stock.wood == 0, "Remote stock appeared before walking and work.")
	for index in range(80): state._process(0.25)
	_expect(a.tribe.stock.wood > 0 and a.tribe.delivered > 0, "Far resident never completed work plus transport.")
	_expect(blocked.cargo == "stone" and a.tribe.stock.stone == 0, "Blocked cargo reached remote storage.")
	_expect(a.tribe.members[0].cargo == "" and a.tribe.members[0].work == 0, "Player worked on two bodies.")
	_expect(Tribe.validate(a.tribe, a, state.campaign.data).is_empty(), "Far work violated material conservation.")
	var before: String = Migration.fingerprint(state.export_state())
	state.set_simulation_speed(0.0)
	var paused_state: String = Migration.fingerprint(state.export_state())
	state._process(3600.0)
	_expect(Migration.fingerprint(state.export_state()) == paused_state, "Zero simulation speed advanced the far cursor.")
	state.set_simulation_speed(1.0)
	_expect(Migration.fingerprint(state.export_state()) == before, "Pause altered existing production.")
	root.remove_child(player)
	player.free()
	before = Migration.fingerprint(state.export_state())
	state._process(3600.0)
	_expect(Migration.fingerprint(state.export_state()) == before, "Menu/editor time advanced far work.")
	var stored_before: Dictionary = Atomic.parse_dictionary(Atomic.stringify(state.export_state()))
	_expect(saves.save_now(), "Far owner/cargo/stock did not commit together: " + saves.last_error)
	_expect(saves.load_now(), "Far save could not reload.")
	_expect(Migration.fingerprint(state.export_state()) == Migration.fingerprint(stored_before), "Reload replayed work or lost a cursor.")
	var output: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--restart-check"])
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if "--restart-pack" in user_args:
		args = PackedStringArray(["--headless", "--main-pack", user_args[user_args.find("--restart-pack") + 1], "--script", get_script().resource_path, "--", "--restart-check"])
	_expect(OS.execute(OS.get_executable_path(), args, output, true) == 0 and not str(output).contains("SCRIPT ERROR"), "Fresh-process cursor check failed: " + str(output))
	var active: Dictionary = state.campaign.body_record(a.id)
	active.village_simulation.owner = "near"
	before = Migration.fingerprint(active)
	_expect(not Simulation.advance(active, state.campaign.data.elapsed_seconds + 1.0) and Migration.fingerprint(active) == before, "Far worker ran after near ownership resumed.")
	_neighbor_work(state)
	_milk_work(state)
	await _finish()

func _neighbor_work(state: Node) -> void:
	var Neighbor = Simulation.Neighbor
	state.start_world_with_seed(15838)
	state.current_phase = 1
	var body: Dictionary = state.get_current_body_record()
	body.home_group = Home.create(body.id, state.campaign.data.player_species_id, Vector3.ZERO)
	body.tribe = Tribe.create(body.home_group, state.campaign.data, {"position": [0, 0, 0]}, {"wood": [-5, 0, -4], "stone": [5, 0, -4], "food": [-5, 0, 4], "huts": [[5, 0, 4], [8, 0, 0]]})
	var village: Dictionary = body.tribe
	body.tribal_neighbor = Neighbor.create(state.campaign.data, village, Vector3(8, 0, 0), [Vector3(7, 0, 1), Vector3(9, 0, 1)])
	var neighbor: Dictionary = body.tribal_neighbor
	# Existing rules reserve six food at home. Harvest actual finite deposits.
	village.stock.food = 12
	village.deposits.food.remaining -= 12
	village.stock.wood = 4
	village.deposits.wood.remaining -= 4
	var roads: Dictionary = {}
	var places: Array = [village.anchor, neighbor.anchor]
	for member: Dictionary in village.members + neighbor.members: places.append(member.position)
	for place: Variant in places:
		roads[Simulation.key(place)] = [village.anchor.duplicate(true), place.duplicate(true)]
	body.village_simulation = Simulation.create(body.id, 0, roads, [], state.campaign.data.player_object_id)
	var selected: Array = [village.members[1].id, village.members[2].id]
	_expect(Neighbor.begin(neighbor, village, selected).is_empty(), "Far aid could not begin.")
	var other: Dictionary = state.campaign.ensure_body(23757, 23757)
	state.activate_body(other.id, 23757, 0, false)
	var progression: Node = root.get_node("ProgressionService")
	for tick in range(480):
		state.campaign.data.elapsed_seconds += 0.25
		Simulation.advance(body, state.campaign.data.elapsed_seconds, 1.0, progression.record_far_work.bind(state))
	_expect(neighbor.aid.status == "completed" and neighbor.stock == {"food": 6, "wood": 0} and neighbor.technology.shelter == 1, "Far neighbors did not finish physical aid and construction.")
	_expect(neighbor.aid.received == {"food": 6, "wood": 4} and neighbor.aid.shipments.is_empty(), "Far aid duplicated or lost a shipment.")
	_expect(village.delivered == 0 and village.stock.food == 6 and village.stock.wood == 0, "Aid became ordinary delivery credit or created stock.")
	_expect(Neighbor.validate(neighbor, village, state.campaign.data).is_empty() and Tribe.validate(village, body, state.campaign.data).is_empty(), "Far neighbor aid broke conservation.")
	_expect(progression.export_state().tribal.awards.has("neighbor_help"), "Far completion lost its one earned milestone.")
	var awards: Dictionary = progression.export_state().tribal.awards
	for tick in range(40):
		state.campaign.data.elapsed_seconds += 0.25
		Simulation.advance(body, state.campaign.data.elapsed_seconds, 1.0, progression.record_far_work.bind(state))
	_expect(progression.export_state().tribal.awards == awards and neighbor.aid.received == {"food": 6, "wood": 4}, "Completed far aid ran or rewarded twice.")

func _milk_work(state: Node) -> void:
	var H = Simulation.H
	state.start_world_with_seed(15838)
	var body: Dictionary = state.get_current_body_record()
	body.home_group = Home.create(body.id, state.campaign.data.player_species_id, Vector3.ZERO)
	body.tribe = Tribe.create(body.home_group, state.campaign.data, {"position": [0, 0, 0]}, {"wood": [-5, 0, -4], "stone": [5, 0, -4], "food": [-5, 0, 4], "huts": [[5, 0, 4], [8, 0, 0]]})
	var data: Dictionary = body.tribe
	data.tools = 1
	data.deposits.food.remaining -= 4
	data.economy.produced.water = 8
	data.economy.stations.well = {"id": Tribe.Ids.scoped("workplace", data.id, "well"), "position": data.anchor.duplicate(true)}
	var pen: Dictionary = Simulation.Work.Housing.site(data, "pen", [0, 0, 7], 0)
	pen.merge({"animal_id": "", "food": 4.0, "water": 8.0})
	data.husbandry.pens.append(pen)
	data.husbandry.withdrawn = {"food": 4, "water": 8}
	data.husbandry.delivered = {"food": 4, "water": 8}
	var animal: Dictionary = preload("res://world/domestication/animal_state.gd").individual("far-milk-animal", "far-milk-species", body.id, {"id": "frozen-milk-design", "revision": 1}, Vector3(0, 0, 7))
	animal.merge({"status": "tamed", "order": "wait", "owner_faction_id": data.faction_id}, true)
	_expect(H.bind(data, pen, animal, {"milk_yield": 2.0, "milk_interval": 300.0, "water_need": 4.0}).is_empty(), "Far milk fixture could not bind its D2 identity.")
	# This pure simulation fixture supplies the exact read-only D2 ownership port;
	# full D1/D2 source snapshots are exercised by the real spherical probe.
	body.domesticated_animals = {"registry": {"animals": {animal.object_id: animal}}}
	var record: Dictionary = data.husbandry.records[animal.object_id]
	var roads: Dictionary = {}
	for place: Variant in [data.anchor, pen.entrance, record.pickup, data.members[1].position]:
		roads[Simulation.key(place)] = [data.anchor.duplicate(true), place.duplicate(true)]
	body.village_simulation = Simulation.create(body.id, 0, roads, [animal.object_id], state.campaign.data.player_object_id)
	data.members[1].order = "milk"
	for tick in range(600): Simulation.advance(body, 150.0)
	_expect(record.cycles == 0 and record.clock == 150.0, "Far milk skipped its partial production cycle.")
	body = JSON.parse_string(JSON.stringify(body))
	data = body.tribe
	record = data.husbandry.records[animal.object_id]
	for tick in range(600): Simulation.advance(body, 300.0)
	_expect(record.cycles == 1 and record.produced == 2 and record.handed_over == 2 and data.stock.milk == 0, "Far milk bypassed its real batch, cycle or transport.")
	for tick in range(80):
		if data.members[1].cargo == "milk": break
		Simulation.advance(body, float(body.village_simulation.cursor) + 0.25)
	var carrier: Dictionary = data.members[1]
	_expect(carrier.cargo == "milk", "Far milk never became carrier cargo.")
	carrier.blocked = true
	var position: Variant = carrier.position.duplicate(true)
	for tick in range(40): Simulation.advance(body, float(body.village_simulation.cursor) + 0.25)
	_expect(carrier.position == position and carrier.cargo == "milk" and data.stock.milk == 0, "Blocked far milk reached the warehouse.")
	body.village_simulation.owner = "near"
	var fingerprint: String = Migration.fingerprint(body)
	_expect(not Simulation.advance(body, float(body.village_simulation.cursor) + 600.0) and Migration.fingerprint(body) == fingerprint, "Near milk ownership allowed a second far cycle.")
	carrier.position = data.anchor.duplicate(true)
	carrier.blocked = false
	carrier.order = "wait"
	# Waiting retains the already carried unit, including after a JSON reload.
	Simulation.Work.step(data, carrier, 0.25, 1.0, [])
	_expect(carrier.cargo == "milk" and data.stock.milk == 0, "Paused milk was delivered again on arrival.")
	carrier.order = "milk"
	Simulation.Work.step(data, carrier, 0.25, 1.0, [])
	_expect(carrier.cargo == "" and data.stock.milk == 1 and Simulation.Economy.milk_pending(data) == 1 and record.cycles == 1, "Shared near delivery lost or duplicated far-produced milk.")
	_expect(Tribe.validate(data, body, state.campaign.data).is_empty(), "Far milk violated the shared care/production ledger.")

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish() -> void:
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("FAR_SIMULATION_PASSED: timed travel/work/delivery, blocked cargo, one owner, no offline/editor/pause work, fresh-process cursor.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
