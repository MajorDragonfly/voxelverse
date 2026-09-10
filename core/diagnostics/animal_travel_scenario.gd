extends RefCounted
## Reuses a genuinely tamed and supplied animal from the shared sphere probe.
## Never creates an animal, pen, milk batch or second simulation itself.
const Simulation = preload("res://world/tribe/village_simulation.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Migration = preload("res://core/campaign/spherical_migration.gd")
const CHECKPOINT: String = "user://animal_travel_restart.json"
var probe: Node

func _init(owner: Node) -> void:
	probe = owner

func run(tribe: Node, identity: String, carrier: String) -> Node:
	var state: Node = probe.state
	var saves: Node = probe.saves
	var flow: Node = probe.flow
	var tree: SceneTree = probe.tree
	var a: String = state.active_body_id
	var source_path: String = saves.save_path
	var original: Dictionary = tribe.domestication.controller.record(identity)
	var pen_id: String = tribe.village().husbandry.pens[0].id
	var old_actor_id: int = tribe.domestication.actor_for(identity).get_instance_id()
	var old_scene_id: int = tree.current_scene.get_instance_id()
	var stock: int = tribe.village().stock.milk
	var residents: Array = tribe.village().members.map(func(member: Dictionary) -> String: return member.id)
	if not _check(original.status == "tamed" and tribe.member_record(carrier).cargo == "milk" and tree.paused,
			"Animal travel needs the actual paused D2/D3 milk checkpoint."): return null
	var attendance: String = tribe.husbandry.attendance(tribe.village().husbandry.pens[0]).error
	if not _check(attendance.is_empty(), "The source animal is not physically eligible before departure: " + attendance): return null
	# Hold other village work through its real command port. The already supplied
	# animal keeps producing, while a keeper's drink/meal trip cannot legitimately
	# change the stock that this interrupted-freight checkpoint keeps exact.
	flow.resume()
	tribe.select_all()
	var held: bool = tribe.issue_order("wait")
	tribe.select_member(carrier)
	flow.toggle_pause()
	if not _check(held, "Cannot hold resident work for the travel checkpoint."): return null
	# This durable, real-game fixture also permits a focused local replay after a
	# failure without recreating or fabricating the preceding production chain.
	var fixture_path: String = "user://animal_travel_fixture_save.json"
	if not _check(Atomic.write(fixture_path, saves._read_save(source_path), false) == OK,
			"Cannot preserve the real pre-travel fixture."): return null
	if not _check(Atomic.write("user://animal_travel_fixture.json", {"path": source_path, "snapshot": fixture_path,
			"animal_id": identity, "carrier": carrier}, false) == OK, "Cannot record the real fixture's original slot."): return null
	probe._stage("animal_travel_failed_write")
	var before: String = Migration.fingerprint(state.export_state())
	var saved_before: String = FileAccess.get_file_as_string(source_path)
	var autosave: bool = saves.autosave_enabled
	saves.save_path = "user://missing-animal-travel-parent/blocked.json"
	var departed: bool = await flow.travel_to_planet(23757, 0, 15838)
	saves.save_path = source_path
	if not _check(not departed and state.active_body_id == a and is_instance_id_valid(old_scene_id)
			and is_instance_id_valid(old_actor_id), "Failed departure released the held animal or its source host."): return null
	if not _check(Migration.fingerprint(state.export_state()) == before and saves.autosave_enabled == autosave
			and FileAccess.get_file_as_string(source_path) == saved_before,
			"Failed departure changed animal/cargo/production, autosave or the last complete save."): return null
	probe._stage("animal_travel_depart")
	if not await _travel(23757, ""): return null
	var b: String = state.active_body_id
	var remote: Dictionary = state.campaign.body_record(a)
	if not _check(a != b and state.world_seed == 15838 and state.campaign.data.bodies.size() == 2,
			"Animal travel reused a same-seed body's identity."): return null
	if not _check(not is_instance_id_valid(old_actor_id) and not is_instance_id_valid(old_scene_id),
			"Source animal/host survived on another planet."): return null
	if not _check(remote.village_simulation.owner == "far" and identity in remote.village_simulation.attending,
			"Held animal was not certified for remote attendance: " + str({"body_id": a,
			"owner": remote.village_simulation.owner, "attending": remote.village_simulation.attending,
			"roads": remote.village_simulation.roads.size()})): return null
	if not _check(Simulation._attending(remote, remote.tribe.husbandry.pens[0]),
			"The real saved D2 animal cannot feed the existing far-production read port."): return null
	if not _check(_same_animal(remote, identity, original) and _cargo(remote, carrier) == "milk"
			and remote.tribe.stock.milk == stock and _active_count(identity) == 0,
			"Departure lost/duplicated the animal or credited waiting milk cargo."): return null
	# Let the actual campaign scheduler advance while B is played. Five seconds
	# of production proves a partial cycle survives the handoff without skipping
	# an interval or constructing the old isolated D2 test dictionary.
	var record: Dictionary = remote.tribe.husbandry.records[identity]
	var service_before: float = _serviced(record)
	var consumed_before: float = remote.tribe.husbandry.consumed.food
	# Exercise owed time deterministically instead of relying on incidental CI
	# load to exceed the scheduler's 0.25-second slice. This caps only this probe's
	# real played frames; it does not edit the clock or call a second simulation.
	var previous_max_fps: int = Engine.max_fps
	Engine.max_fps = 2
	flow.resume()
	await probe._until(func() -> bool: return _serviced(state.campaign.body_record(a).tribe.husbandry.records[identity]) >= service_before + 5.0, 18000)
	flow.toggle_pause()
	Engine.max_fps = previous_max_fps
	remote = state.campaign.body_record(a)
	if not _check(float(state.campaign.data.elapsed_seconds) - float(remote.village_simulation.cursor) > 0.25,
			"Slow played frames did not exercise pending far simulation time."): return null
	if not _check(_serviced(remote.tribe.husbandry.records[identity]) >= service_before + 5.0
			and float(remote.tribe.husbandry.consumed.food) > consumed_before,
			"Held animal stopped consuming supplies or advancing its cycle during actual far play."): return null
	if not _check(_cargo(remote, carrier) == "milk" and remote.tribe.stock.milk == stock,
			"Far work automatically delivered paused milk cargo."): return null
	print("ANIMAL_TRAVEL_FAR ", {"body_id": a, "animal_id": identity,
		"production_seconds_before": service_before, "production_seconds_after": _serviced(remote.tribe.husbandry.records[identity]),
		"food_consumed": float(remote.tribe.husbandry.consumed.food) - consumed_before,
		"cargo": _cargo(remote, carrier), "milk_stock": remote.tribe.stock.milk})
	var paused: String = Migration.fingerprint(state.export_state())
	for index in range(15): await tree.process_frame
	if not _check(Migration.fingerprint(state.export_state()) == paused, "Pause advanced far animal production."): return null
	if not _check(saves.save_now(), "Far animal checkpoint failed: " + saves.last_error): return null
	var expected: Dictionary = {"path": source_path, "source_id": a, "active_id": b, "animal_id": identity,
		"carrier": carrier, "clock": state.campaign.data.elapsed_seconds, "source": state.campaign.body_record(a).duplicate(true)}
	if not _check(Atomic.write(CHECKPOINT, expected, false) == OK, "Cannot record actual far-animal restart evidence."): return null
	probe._stage("animal_travel_far_restart")
	var output: Array = []
	var args := PackedStringArray(["--headless"])
	if OS.has_feature("editor"): args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--", "--sphere-gameplay-smoke", "--animal-travel-restart"])
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	if not _check(code == 0 and str(output).contains("ANIMAL_TRAVEL_FRESH_PROCESS_PASSED")
			and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"),
			"Fresh process lost or replayed the remote held animal: " + str(output)): return null
	probe._stage("animal_travel_return")
	if not await _travel(15838, a): return null
	var returned: Dictionary = state.campaign.body_record(a)
	# Loading adds no campaign time, but the bounded far scheduler can still owe
	# part of the already played interval. Check its independent time/feed balance
	# instead of requiring an unfinished far snapshot to remain frozen on return.
	if not _check(absf(float(state.campaign.data.elapsed_seconds) - float(expected.clock)) < 0.000001,
			"Return loading created campaign time."): return null
	if not _return_husbandry(expected.source, returned, identity, float(expected.clock)): return null
	for field: String in ["economy", "stock"]:
		if not _check(Migration.fingerprint(returned.tribe[field]) == Migration.fingerprint(expected.source.tribe[field]),
				"Return replayed or lost the remote " + field + " state."): return null
	if not _check(returned.village_simulation.owner == "near" and _same_animal(returned, identity, original),
			"Return did not preserve the original animal and exclusive near owner."): return null
	flow.resume()
	tribe = tree.current_scene.get_node("Nest/Tribe")
	await probe._until(func() -> bool: return (tribe.is_active() and tribe.navigation.is_ready()
		and tribe.domestication.is_active() and tribe.domestication.animals.has(identity)
		and tribe.husbandry.attendance(tribe.village().husbandry.pens[0]).error.is_empty()), 45000)
	if not _check(tribe.domestication.animals.has(identity) and _active_count(identity) == 1,
			"Return failed to reconstruct exactly one physical owned animal."): return null
	if not _check(tribe.village().members.map(func(member: Dictionary) -> String: return member.id) == residents
			and tribe.husbandry.attendance(tribe.village().husbandry.pens[0]).error.is_empty()
			and tribe.village().husbandry.pens[0].id == pen_id and _cargo(tribe.body(), carrier) == "milk",
			"Return changed residents, pen admission or the actual waiting carrier."): return null
	flow.toggle_pause()
	if not _check(saves.save_now(), "Returned animal checkpoint failed: " + saves.last_error): return null
	print("ANIMAL_TRAVEL_PASSED: real D1/D2 animal, pen and milk cargo; A-B-A, five far production seconds, failed write, pause, fresh process and single physical return.")
	return tribe

func _return_husbandry(before: Dictionary, returned: Dictionary, identity: String, clock: float) -> bool:
	var debt: float = maxf(0.0, clock - float(before.village_simulation.cursor))
	if not _check(absf(float(returned.village_simulation.cursor) - clock) < 0.000001,
			"Return left campaign time unprocessed."): return false
	var old: Dictionary = before.tribe.husbandry
	var actual: Dictionary = returned.tribe.husbandry.duplicate(true)
	var record: Dictionary = old.records[identity]
	# This checkpoint exercises an interrupted partial cycle, with the previous
	# milk batch still carried. It must not cross another production boundary.
	if not _check(record.pending_milk == 0 and float(record.clock) + debt < float(record.recipe.milk_interval),
			"Travel checkpoint no longer represents a partial milk cycle."): return false
	if not _check(absf(_serviced(actual.records[identity]) - _serviced(record) - debt) < 0.000001,
			"Return lost or replayed partial animal production."): return false
	actual.records[identity].clock = record.clock
	for kind: String in ["food", "water"]:
		var used: float = debt / Simulation.H.CARE_SECONDS * (1.0 if kind == "food" else float(record.recipe.water_need))
		if not _check(float(old.pens[0][kind]) >= used
				and absf(float(actual.consumed[kind]) - float(old.consumed[kind]) - used) < 0.000001
				and absf(float(old.pens[0][kind]) - float(actual.pens[0][kind]) - used) < 0.000001,
				"Return lost or replayed animal " + kind + " consumption."): return false
		actual.consumed[kind] = old.consumed[kind]
		actual.pens[0][kind] = old.pens[0][kind]
	# Only the explicitly balanced fractional fields may differ. Pen admission,
	# identity, recipes, cycles, batch receipts and all other records stay exact.
	if not _check(Migration.fingerprint(actual) == Migration.fingerprint(old),
			"Return changed the remote husbandry state beyond owed production."): return false
	print("ANIMAL_TRAVEL_RETURN_BALANCE ", {"owed_seconds": debt, "campaign_clock": clock,
		"returned_cursor": returned.village_simulation.cursor})
	return true

func restart() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(CHECKPOINT))
	if not _check(not expected.is_empty(), "Far-animal restart evidence is missing."): return
	await probe._open(expected.path, true)
	if not probe._expect_world(): return
	var state: Node = probe.state
	var body: Dictionary = state.campaign.body_record(expected.source_id)
	_check(state.active_body_id == expected.active_id and state.campaign.data.bodies.size() == 2,
			"Restart changed the active body or duplicated a planet.")
	_check(Migration.fingerprint(body) == Migration.fingerprint(expected.source), "Restart changed the complete remote body, including animal and milk freight.")
	_check(absf(float(state.campaign.data.elapsed_seconds) - float(expected.clock)) < 0.000001,
			"Closed application created offline animal production.")
	_check(_active_count(expected.animal_id) == 0 and _cargo(body, expected.carrier) == "milk"
			and body.get("village_simulation", {}).get("owner") == "far",
			"Restart spawned the remote animal locally or replayed waiting cargo.")
	if probe.failures.is_empty(): print("ANIMAL_TRAVEL_FRESH_PROCESS_PASSED")
	probe.flow.return_to_title()
	await probe.tree.scene_changed

func _travel(system_seed: int, body_id: String) -> bool:
	probe.flow.world_started.connect(probe.flow.toggle_pause, CONNECT_ONE_SHOT)
	if not await probe.flow.travel_to_planet(system_seed, 0, 15838, body_id):
		if probe.flow.world_started.is_connected(probe.flow.toggle_pause): probe.flow.world_started.disconnect(probe.flow.toggle_pause)
		return _check(false, "Held-animal travel request failed: " + probe.saves.last_error)
	await probe._until(func() -> bool: return not probe.flow.loading, 150000)
	return probe._expect_world()

func _same_animal(body: Dictionary, identity: String, original: Dictionary) -> bool:
	var animal: Dictionary = body.get("domesticated_animals", {}).get("registry", {}).get("animals", {}).get(identity, {})
	for key: String in ["object_id", "species_id", "body_id", "design_ref", "owner_faction_id", "status", "order", "trust"]:
		if animal.get(key) != original.get(key): return false
	return Home.distance(animal.position, original.position) < 0.1

func _active_count(identity: String) -> int:
	var count: int = 0
	for actor: Node in probe.tree.get_nodes_in_group(&"wildlife"):
		if not actor.is_queued_for_deletion() and actor.has_method("get_campaign_identity"):
			if actor.get_campaign_identity().object_id == identity: count += 1
	return count

func _cargo(body: Dictionary, identity: String) -> String:
	for member: Dictionary in body.tribe.members:
		if member.id == identity: return member.cargo
	return "missing-carrier"

func _serviced(record: Dictionary) -> float:
	return float(record.cycles) * float(record.recipe.milk_interval) + float(record.clock)

func _check(condition: bool, message: String) -> bool:
	probe._expect(condition, message)
	return condition
