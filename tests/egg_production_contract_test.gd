extends "res://tests/tribal_age_husbandry_contract_test.gd"
const E = preload("res://world/tribe/village_economy.gd")
const Work = preload("res://world/tribe/village_work.gd")
const Simulation = preload("res://world/tribe/village_simulation.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const SAVE: String = "user://arch22-production.json"
const EGG_ID: String = "egg-contract-animal"

func egg_fixture(amount: float = 1.0, interval: float = 300.0) -> Dictionary:
	var data: Dictionary = fixture(0.25, 1.0)
	var p: Dictionary = data.husbandry.pens[0]
	data.husbandry.records.clear()
	p.kind = "laying_site"
	p.animal_id = ""
	var animal: Dictionary = D2.individual(EGG_ID, "egg-contract-species", body.id, {"id": "egg-design", "revision": 1}, Vector3(0, 0, 7))
	_expect(H.bind(data, p, animal, {"recipe_id": H.Production.EGGS, "recipe_revision": 1,
		"egg_yield": amount, "egg_interval": interval, "water_need": 4.0}).is_empty(), "Cannot bind laying animal.")
	return data

func _run() -> void:
	if "--restart-check" in OS.get_cmdline_user_args():
		_restart_eggs()
	else:
		campaign.reset("arch22-production")
		body = campaign.body_for_seed(15838, 1)
		body.home_group = Model.Home.create(body.id, campaign.data.player_species_id, Vector3.ZERO)
		_migration()
		_production()
		_far_work()
		_protection()
		var output: Array = []
		var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--restart-check"])
		var code: int = OS.execute(OS.get_executable_path(), args, output, true)
		_expect(code == 0 and not str(output).contains("SCRIPT ERROR") and "\n".join(output).contains('"passed":true'), "Egg restart failed: " + str(output))
	print(JSON.stringify({"test": "egg_production_contract", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _migration() -> void:
	var data: Dictionary = fixture(0.25, 1.0)
	for tick in range(14): H.advance(data, data.husbandry.pens[0], 0.25)
	# Construct the previous nested schemas explicitly; no new constructor proves compatibility.
	data.economy.schema = 1
	data.husbandry.schema = 1
	data.stock.erase("eggs")
	data.economy.erase("eggs_received")
	data.economy.erase("eggs_meals")
	var before: Dictionary = JSON.parse_string(JSON.stringify(data))
	data = before.duplicate(true)
	_expect(valid(data), "Old milk ledger no longer validates.")
	_expect(Model.upgrade(data) and valid(data), "Old nested contracts did not upgrade.")
	var stripped: Dictionary = data.duplicate(true)
	stripped.stock.erase("eggs")
	stripped.economy.erase("eggs_received")
	stripped.economy.erase("eggs_meals")
	stripped.economy.schema = 1
	stripped.husbandry.schema = 1
	_expect(JSON.parse_string(JSON.stringify(stripped)) == before and data.stock.eggs == 0, "Migration changed old milk clocks, stock, IDs or residents.")
	before = data.duplicate(true)
	_expect(not Model.upgrade(data) and data == before, "Nested migration repeated.")
	var p: Dictionary = data.husbandry.pens[0]
	for tick in range(2): H.advance(data, p, 0.25)
	_expect(H.pending(data.husbandry.records["d3-unit-animal"]) == 1, "Old fractional milk did not finish after migration.")
	# Milk and eggs coexist without sharing their producer counters or resetting the first animal.
	var second: Dictionary = Housing.site(data, "laying_site", [6, 0, 7], 1)
	second.merge({"animal_id": "", "food": 0.0, "water": 0.0})
	data.husbandry.pens.append(second)
	var animal: Dictionary = D2.individual(EGG_ID, "egg-contract-species", body.id, {"id": "egg-design", "revision": 1}, Vector3(6, 0, 7))
	var params: Dictionary = {"recipe_id": H.Production.EGGS, "recipe_revision": 1, "egg_yield": 1.0, "egg_interval": 300.0, "water_need": 4.0}
	before = data.duplicate(true)
	_expect(not H.bind(data, p, animal, params).is_empty() and before == data, "Laying animal occupied a milk-only place.")
	_expect(H.bind(data, second, animal, params).is_empty() and valid(data), "Mixed milk/egg husbandry invalid.")
	_expect(data.husbandry.records["d3-unit-animal"] == before.husbandry.records["d3-unit-animal"], "Second species reset milk.")

func _production() -> void:
	var data: Dictionary = egg_fixture(100.0, 1.0)
	var p: Dictionary = data.husbandry.pens[0]
	_expect(valid(data), "Laying fixture invalid: " + Model.validate(data, body, campaign.data))
	for tick in range(4): H.advance(data, p, 0.25)
	var r: Dictionary = data.husbandry.records[EGG_ID]
	_expect(r.produced == 100 and H.pending(r) == 100 and data.stock.eggs == 0, "Eggs bypassed the laying place.")
	_expect(H.offer(data, EGG_ID) and E.pending(data, "eggs") == 48 and H.pending(r) == 52, "Full warehouse reservation did not split the laying batch.")
	var before: Dictionary = data.duplicate(true)
	_expect(not H.offer(data, EGG_ID) and data == before, "Full warehouse lost backlog.")
	_expect(not H.unbind(data, p).is_empty() and data == before, "Unbinding discarded uncollected eggs.")
	var batch: Dictionary = data.economy.receipts[EGG_ID].duplicate(true)
	_expect(E.receive_batch(data, batch).is_empty() and data == before, "Receipt retry duplicated eggs.")
	_expect(not E.collect(data, data.members[1], "eggs") and data == before, "Egg pickup teleported from laying place.")
	var carrier: Dictionary = data.members[1]
	carrier.order = "eggs"
	carrier.position = p.entrance.duplicate(true)
	var effects: Array = []
	Work.step(data, carrier, 0.25, 1.0, effects)
	_expect(carrier.cargo == "eggs" and data.stock.eggs == 0 and E.pending(data, "eggs") == 47, "Egg pickup skipped the physical cargo stage.")
	carrier.order = "wait"
	carrier.paused_order = "eggs"
	before = data.duplicate(true)
	Work.step(data, carrier, 0.25, 1.0, effects)
	for delta: float in [0.0, -1.0, INF, NAN, 3600.0]: H.advance(data, p, delta)
	_expect(data == before and valid(data), "Paused cargo or invalid elapsed time created eggs.")
	_expect(Atomic.write(SAVE, {"data": data, "body": body, "campaign": campaign.data}, false) == OK, "Cannot persist interrupted laying batch.")
	for field: String in ["recipe", "design_ref", "pickup", "pending_output", "produced", "cycles", "sequence"]:
		var bad: Dictionary = data.duplicate(true)
		bad.husbandry.records[EGG_ID][field] = "broken"
		_expect(not valid(bad), "Malformed laying record accepted: " + field)
	var bad: Dictionary = data.duplicate(true)
	bad.husbandry.records[EGG_ID].pending_output += 1
	_expect(not valid(bad), "Duplicated egg production accepted.")
	bad = data.duplicate(true)
	bad.husbandry.records[EGG_ID]["pending_milk"] = 0
	_expect(not valid(bad), "Two authoritative output counters accepted.")
	bad = data.duplicate(true)
	bad.economy.incoming[0].remaining -= 1
	_expect(not valid(bad), "A missing egg in the inbox was accepted.")
	bad = data.duplicate(true)
	bad.husbandry.pens[0].kind = "pen"
	_expect(not valid(bad), "Saved egg animal accepted at a milk place.")

func _restart_eggs() -> void:
	var saved: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(SAVE))
	body = saved.body
	campaign.data = saved.campaign
	var data: Dictionary = saved.data
	var r: Dictionary = data.husbandry.records[EGG_ID]
	var carrier: Dictionary = data.members[1]
	_expect(valid(data) and r.produced == 100 and H.pending(r) == 52 and carrier.cargo == "eggs" and E.pending(data, "eggs") == 47, "Cold restart lost laying backlog or freight.")
	var before: Dictionary = data.duplicate(true)
	var effects: Array = []
	Work.step(data, carrier, 0.25, 1.0, effects)
	_expect(data == before, "Cold restart delivered paused cargo.")
	carrier.order = "eggs"
	carrier.paused_order = ""
	carrier.position = data.anchor.duplicate(true)
	Work.step(data, carrier, 0.25, 1.0, effects)
	carrier.hunger = 50.0
	_expect(data.stock.eggs == 1 and Work.eat(data, carrier, effects) and carrier.hunger == 75.0, "Delivered eggs were not edible.")
	_expect(data.economy.eggs_meals == 1 and data.economy.milk_meals == 0, "Egg meal changed milk balance.")
	# Animal disappearance cannot delete previously produced food; this port owns no animal.
	_expect(H.offer(data, EGG_ID) and H.pending(r) == 51, "Saved output could not resume without another production cycle.")
	_expect(valid(data) and r.produced == H.pending(r) + E.pending(data, "eggs") + E.reserve(data, "eggs") + data.economy.eggs_meals, "Egg conservation failed across process restart.")

func _far_work() -> void:
	var data: Dictionary = egg_fixture()
	var remote: Dictionary = body.duplicate(true)
	remote.tribe = data
	var p: Dictionary = data.husbandry.pens[0]
	var animal: Dictionary = D2.individual(EGG_ID, "egg-contract-species", body.id, {"id": "egg-design", "revision": 1}, Vector3(0, 0, 7))
	animal.merge({"status": "tamed", "order": "wait", "owner_faction_id": data.faction_id}, true)
	remote.domesticated_animals = {"registry": {"animals": {EGG_ID: animal}}}
	var roads: Dictionary = {}
	for place in [data.anchor, p.entrance]: roads[Simulation.key(place)] = [data.anchor, place]
	remote.village_simulation = Simulation.create(body.id, 0.0, roads, [EGG_ID], data.members[0].id)
	var near: Dictionary = data.duplicate(true)
	for tick in range(1220):
		H.advance(near, near.husbandry.pens[0], 0.25)
		H.offer(near, EGG_ID)
		Simulation.advance(remote, (tick + 1) * 0.25)
	_expect(remote.tribe.husbandry == near.husbandry and E.pending(data, "eggs") == E.pending(near, "eggs") and E.pending(data, "eggs") == 1, "Near/far production uses different balances.")
	var before: Dictionary = data.husbandry.duplicate(true)
	animal.status = "dead"
	Simulation.advance(remote, 305.25)
	_expect(data.husbandry == before, "Dead far animal kept producing.")
	remote.village_simulation.owner = "near"
	_expect(not Simulation.advance(remote, 306.0) and data.husbandry == before, "Two owners produced for one laying animal.")

func _protection() -> void:
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	var path: String = saves.create_slot("ARCH-22 versions", 15838)
	_expect(not path.is_empty(), "Cannot create version-protection slot.")
	if path.is_empty(): return
	var original: String = FileAccess.get_file_as_string(path)
	for target: String in ["economy", "husbandry", "recipe"]:
		var future: Dictionary = JSON.parse_string(original)
		var active: Dictionary = preload("res://core/campaign/body_registry.gd").active(future.game_state)
		active["tribe"] = {target: {"schema": 99}}
		if target == "recipe": active.tribe = {"husbandry": {"schema": 2, "records": {"future": {"recipe": {"recipe_id": H.Production.EGGS, "recipe_revision": 99}}}}}
		_expect(Atomic.write(path, future, false) == OK and Atomic.write(path + ".bak", JSON.parse_string(original), false) == OK, "Cannot write future-version fixture.")
		var primary: String = FileAccess.get_file_as_string(path)
		var backup: String = FileAccess.get_file_as_string(path + ".bak")
		_expect(not saves.load_now(path) and not saves.save_now(path), "Future laying contract used an older backup or was overwritten: " + target)
		_expect(FileAccess.get_file_as_string(path) == primary and FileAccess.get_file_as_string(path + ".bak") == backup, "Future-version rejection changed bytes.")
		Atomic.write(path, JSON.parse_string(original), false)
		_expect(saves.load_now(path), "Original slot did not recover.")
