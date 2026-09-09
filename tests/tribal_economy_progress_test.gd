extends SceneTree
const Tribal = preload("res://core/progression/tribal_progression.gd")
const Evidence = preload("res://core/progression/tribal_economy_progress.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const Epoch = preload("res://core/progression/civilization_contract.gd")
var failures: Array[String] = []
var campaign: Dictionary
var body: Dictionary
var village: Dictionary
var model = Tribal.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	campaign = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/home_group_pr20.json"))["campaign"]
	body = campaign["bodies"]["15838"]
	var anchor: Array = body["home_group"]["anchor"]
	village = Tribe.create(body["home_group"], campaign, {"position": anchor}, {"wood": anchor, "stone": anchor, "food": anchor, "huts": [anchor, anchor]})
	body["tribe"] = village
	village["tools"] = 1
	village["garden"] = 1
	village["grown"] = 24
	village["stock"]["food"] = 18
	village["stock"]["water"] = 12
	for station: String in Economy.STATIONS:
		var resource: String = Economy.STATIONS[station]
		village["economy"]["stations"][station] = {"id": Ids.scoped("workplace", village["id"], station), "position": anchor.duplicate()}
		village["economy"]["produced"][resource] = 24
		village["deposits"][resource]["remaining"] = 8
	_expect(Tribe.validate(village, body, campaign).is_empty(), "Invalid renewable fixture")
	_assign(0, "forester")
	_observe(village.duplicate(true), 0)
	_expect(model.wallet()["earned"]["social"] == 0 and _evidence()["jobs"].is_empty(), "Job assignment invented an achievement")
	# Cargo already present when this contract first loads has no witnessed pickup.
	village["members"][0]["cargo"] = "wood"
	village["deposits"]["wood"]["remaining"] -= 1
	_deliver(0)
	_expect(_evidence()["jobs"].is_empty(), "Legacy cargo counted as a full work cycle")
	for cycle in range(3):
		_cycle(0, "forester", "wood")
	for cycle in range(3):
		_cycle(0, "mason", "stone")
	_expect(not model.economy_progress(village)["professions"]["met"], "One resident cycling professions counted as community work")
	# Pause and reload while carrying: retain the profession that did the work.
	_assign(1, "mason")
	_pickup(1, "stone")
	village["members"][1]["order"] = "wait"
	village["members"][1]["paused_order"] = "stone"
	var paused_state: Dictionary = JSON.parse_string(JSON.stringify(model.export_state()))
	_expect(model.import_state(paused_state), "In-flight work did not deserialize")
	_observe(village.duplicate(true), 1)
	_expect(JSON.parse_string(JSON.stringify(model.export_state())) == paused_state, "Waiting completed the saved transport")
	_assign(1, "weaver")
	_deliver(1)
	_expect(model.economy_progress(village)["professions"]["met"] and model.export_state()["awards"].has("working_professions"), "Completed shared professions were not rewarded")
	_expect(not _evidence()["jobs"].has("weaver"), "Changing the title reassigned previous work")
	var earned: int = model.wallet()["earned"]["social"]
	_cycle(1, "mason", "stone")
	_expect(model.wallet()["earned"]["social"] == earned, "Completed professions paid twice")
	# A timer and stored resources alone never establish actual resident consumption.
	model.observe_supply(village, body, campaign, 1, 180.0)
	_expect(not model.economy_progress(village)["supply"]["met"], "Timer or stock alone fulfilled supply")
	var clock: Dictionary = model.export_state()
	for delta: float in [0.0, -1.0, NAN, INF]:
		model.observe_supply(village, body, campaign, 1, delta)
	_expect(model.export_state() == clock, "Pause or invalid time advanced evidence")
	for index in range(3):
		_consume(index, false)
		_consume(index, true)
	model.observe_supply(village, body, campaign, 1, 0.1)
	_expect(model.economy_progress(village)["supply"]["met"] and model.export_state()["awards"].has("sustained_supply"), "Actual meals, drinks and sustained reserves did not count")
	var paid: Dictionary = model.export_state()["awards"]
	village["stock"]["water"] = 0
	model.observe_supply(village, body, campaign, 1, 1.0)
	_expect(_evidence()["healthy_seconds"] == 0.0 and _evidence()["fed"].is_empty() and _evidence()["drunk"].is_empty(), "Shortage did not reset the current supply window")
	_expect(model.export_state()["awards"] == paid, "Shortage revoked historical earned points")
	village["stock"]["water"] = 6
	model.observe_supply(village, body, campaign, 1, 180.0)
	_expect(not model.economy_progress(village)["supply"]["met"], "Previous-window consumption counted after a shortage")
	var description: Dictionary = Epoch.describe(campaign, "15838", 1, 2, {"supply": {"met": true, "text": ""}, "professions": {"met": true, "text": ""}})
	_expect(not description["available"] and not description["implemented"], "All economy goals bypassed the missing medieval runtime")
	# Future nested schemas must reach the save service's overwrite protection.
	var future: Dictionary = model.export_state()
	future["villages"][village["id"]]["economy"]["schema"] = Evidence.SCHEMA + 1
	_expect(Tribal.has_unsupported_contract(future) and not model.import_state(future), "Future nested evidence was silently downgraded")
	# Migration retains old paid progress and buys, but starts no economic history.
	var legacy: Dictionary = model.export_state()
	legacy["schema"] = 1
	legacy["awards"].erase("working_professions")
	legacy["awards"].erase("sustained_supply")
	legacy["villages"][village["id"]].erase("economy")
	_expect(model.import_state(legacy), "Tribal schema 1 cannot migrate")
	_expect(model.export_state()["schema"] == 2 and _evidence().is_empty() and model.export_state()["awards"] == legacy["awards"], "Migration lost points or invented economic work")
	print(JSON.stringify({"test": "tribal_economy_progress", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _evidence() -> Dictionary:
	return model.export_state()["villages"][village["id"]]["economy"]

func _assign(index: int, profession: String) -> void:
	village["members"][index]["profession"] = profession
	village["members"][index]["order"] = Economy.JOB_ORDER[profession]
	village["members"][index]["paused_order"] = ""

func _cycle(index: int, profession: String, resource: String) -> void:
	_assign(index, profession)
	var before: Dictionary = village.duplicate(true)
	_pickup(index, resource)
	var picked: Dictionary = village.duplicate(true)
	_deliver(index)
	var once: Dictionary = model.export_state()
	model.observe(before, picked, village["members"][index]["id"], body, campaign, 1)
	_expect(model.export_state() == once, "Replayed old pickup reopened delivered cargo")

func _pickup(index: int, resource: String) -> void:
	var before: Dictionary = village.duplicate(true)
	village["members"][index]["cargo"] = resource
	village["deposits"][resource]["remaining"] -= 1
	_observe(before, index)

func _deliver(index: int) -> void:
	var before: Dictionary = village.duplicate(true)
	var resource: String = village["members"][index]["cargo"]
	village["stock"][resource] += 1
	village["delivered"] += 1
	village["members"][index]["cargo"] = ""
	_observe(before, index)
	var once: Dictionary = model.export_state()
	_observe(before, index)
	_expect(model.export_state() == once, "Delivery replay changed evidence")

func _consume(index: int, water: bool) -> void:
	_assign(index, "provider")
	var need: String = "hydration" if water else "hunger"
	village["members"][index][need] = 39.0
	var before: Dictionary = village.duplicate(true)
	village["members"][index][need] = 70.0
	village["stock"]["water" if water else "food"] -= 1
	if water:
		village["economy"]["drinks"] += 1
	else:
		village["meals"] += 1
	_observe(before, index)

func _observe(before: Dictionary, index: int) -> void:
	_expect(Tribe.validate(before, body, campaign).is_empty() and Tribe.validate(village, body, campaign).is_empty(), "Invalid work fixture")
	model.observe(before, village, village["members"][index]["id"], body, campaign, 1)
	_expect(Tribal.validate(model.export_state()).is_empty(), "Work produced an invalid save")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
