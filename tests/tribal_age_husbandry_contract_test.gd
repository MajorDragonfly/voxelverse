extends SceneTree
const Model = preload("res://world/tribe/tribe_state.gd")
const H = preload("res://world/tribe/village_husbandry.gd")
const Housing = preload("res://world/tribe/village_housing.gd")
const D1 = preload("res://world/fauna/domestication/domestication_contract.gd")
const D2 = preload("res://world/domestication/animal_state.gd")
const Campaign = preload("res://core/campaign/campaign_state.gd")
var failures: Array[String] = []
var campaign := Campaign.new()
var body: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func fixture(yield_amount: float = 2, interval: float = 300) -> Dictionary:
	var data: Dictionary = Model.create(body["home_group"], campaign.data, {"position": [0, 0, 0]}, {"wood": [-5, 0, -4], "stone": [5, 0, -4], "food": [-5, 0, 4], "huts": [[5, 0, 4], [8, 0, 0]]})
	data["tools"] = 1
	data["deposits"]["food"]["remaining"] -= 4
	data["economy"]["produced"]["water"] = 8
	data["economy"]["stations"]["well"] = {"id": Model.Ids.scoped("workplace", data["id"], "well"), "position": data["anchor"].duplicate()}
	var p: Dictionary = Housing.site(data, "pen", [0, 0, 7], 0)
	p.merge({"animal_id": "", "food": 4.0, "water": 8.0})
	data["husbandry"]["pens"].append(p)
	data["husbandry"]["withdrawn"] = {"food": 4, "water": 8}
	data["husbandry"]["delivered"] = {"food": 4, "water": 8}
	var animal: Dictionary = D2.individual("d3-unit-animal", "d1-unit-species", body["id"], {"id": "unit-design", "revision": 1}, Vector3(0, 0, 7))
	var traits: Dictionary = D1.suitability("milk")
	traits["milk_yield"] = yield_amount
	traits["milk_interval"] = interval
	_expect(D1.validate(traits).is_empty(), "Test recipe broke canonical D1 contract.")
	_expect(H.bind(data, p, animal, {"milk_yield": traits["milk_yield"], "milk_interval": traits["milk_interval"], "water_need": traits["water_need"]}).is_empty(), "Could not bind valid production fixture.")
	return data

func _run() -> void:
	campaign.reset("d3-husbandry-contract")
	body = campaign.body_for_seed(15838, 1)
	body["home_group"] = Model.Home.create(body["id"], campaign.data["player_species_id"], Vector3.ZERO)
	var data: Dictionary = fixture()
	_expect(valid(data), "Invalid initial care ledger: " + Model.validate(data, body, campaign.data))
	var second: Dictionary = Housing.site(data, "pen", [6, 0, 7], 1)
	second.merge({"animal_id": "", "food": 0.0, "water": 0.0})
	data["husbandry"]["pens"].append(second)
	var duplicate: Dictionary = D2.individual("d3-unit-animal", "d1-unit-species", body["id"], {"id": "unit-design", "revision": 1}, Vector3.ZERO)
	_expect(not H.bind(data, second, duplicate, data["husbandry"]["records"]["d3-unit-animal"]["recipe"]).is_empty() and second["animal_id"] == "" and valid(data), "One animal occupied two pens.")
	var over_capacity: Dictionary = data.duplicate(true)
	over_capacity["husbandry"]["pens"].append(second.duplicate(true))
	_expect(not valid(over_capacity), "Third pen exceeded village capacity.")
	data["husbandry"]["pens"].pop_back()
	# Schema 4 migration preserves actual construction, growth and old milk receipts.
	var legacy: Dictionary = data.duplicate(true)
	legacy["schema"] = 4
	legacy.erase("husbandry")
	for member: Dictionary in legacy["members"]:
		member.erase("care_pen_id")
	legacy["housing"]["clock"] = 17.5
	legacy["members"][0].merge({"order": "wait", "profession": "forester", "paused_order": "wood", "work": 1.5, "cargo": "wood", "stage": "return"}, true)
	legacy["deposits"]["wood"]["remaining"] -= 4
	legacy["project"] = Housing.site(legacy, "tent", [5, 0, 5], 0)
	legacy["project"].merge({"progress": 0.0, "materials": {"wood": 3, "fiber": 1}, "delivered_materials": {"wood": 0, "fiber": 0}})
	legacy["members"][1].merge({"cargo": "fiber", "construction_id": legacy["project"]["id"], "order": "tent", "stage": "return"}, true)
	legacy["economy"]["produced"]["fiber"] = 2
	legacy["economy"]["stations"]["fiberbed"] = {"id": Model.Ids.scoped("workplace", legacy["id"], "fiberbed"), "position": legacy["anchor"].duplicate()}
	_expect(Model.Economy.receive_milk(legacy, {"schema": 1, "source_id": "prior-d3-source", "body_id": legacy["body_id"], "faction_id": legacy["faction_id"], "sequence": 1, "amount": 2, "position": [0, 0, -7]}).is_empty(), "Legacy milk fixture rejected.")
	var before: Dictionary = legacy.duplicate(true)
	_expect(valid(legacy) and Model.upgrade(legacy) and valid(legacy), "Schema 4 migration invalid.")
	for key: String in ["economy", "housing", "project", "stock", "deposits"]:
		_expect(legacy[key] == before[key], "Migration reset " + key)
	for i in range(3):
		for key: String in before["members"][i]:
			_expect(legacy["members"][i][key] == before["members"][i][key], "Migration changed member " + key)
	before = legacy.duplicate(true)
	_expect(not Model.upgrade(legacy) and legacy == before, "Migration repeated.")
	# Partial cycle, pause, JSON roundtrip, exact canonical D1 yield and consumption.
	for i in range(600):
		H.advance(data, data["husbandry"]["pens"][0], 0.25)
	before = data.duplicate(true)
	for delta: float in [0.0, -1.0, INF, 30.0]:
		H.advance(data, data["husbandry"]["pens"][0], delta)
	_expect(data == before, "Invalid/offline time granted production.")
	data = JSON.parse_string(JSON.stringify(data))
	for i in range(600):
		H.advance(data, data["husbandry"]["pens"][0], 0.25)
	var r: Dictionary = data["husbandry"]["records"]["d3-unit-animal"]
	_expect(r["pending_milk"] == 2 and r["cycles"] == 1 and absf(data["husbandry"]["consumed"]["food"] - 1.0) < 0.000001 and absf(data["husbandry"]["consumed"]["water"] - 4.0) < 0.000001, "Canonical cycle created wrong milk or free supplies.")
	_expect(H.offer(data, "d3-unit-animal") and valid(data), "Joint production and inbox receipt invalid.")
	before = JSON.parse_string(JSON.stringify(data))
	data = before.duplicate(true)
	_expect(not H.offer(data, "d3-unit-animal") and data == before, "Repeat offer duplicated milk.")
	var receipt: Dictionary = data["economy"]["receipts"]["d3-unit-animal"]
	_expect(Model.Economy.receive_milk(data, receipt).is_empty() and data == before, "Acknowledged milk retry changed state.")
	_expect(H.unbind(data, data["husbandry"]["pens"][0]).is_empty(), "Delivered animal could not be released.")
	var original: Dictionary = data["husbandry"]["records"].duplicate(true)
	var animal: Dictionary = D2.individual("d3-unit-animal", "d1-unit-species", body["id"], {"id": "unit-design", "revision": 1}, Vector3.ZERO)
	_expect(H.bind(data, data["husbandry"]["pens"][0], animal, r["recipe"]).is_empty() and data["husbandry"]["records"] == original, "Rebinding reset receipts or progress.")
	# A full 100-litre D1 yield is held and split into capacity-limited receipts.
	data = fixture(100, 1)
	for i in range(4): H.advance(data, data["husbandry"]["pens"][0], 0.25)
	_expect(H.offer(data, "d3-unit-animal") and Model.Economy.milk_pending(data) == 48, "High yield was not split at warehouse capacity.")
	before = data.duplicate(true)
	_expect(not H.offer(data, "d3-unit-animal") and data == before and valid(data), "Full warehouse lost or duplicated producer backlog.")
	for amount: int in [48, 48]:
		data["economy"]["incoming"].clear()
		data["economy"]["milk_meals"] += amount
		data["meals"] += amount
		_expect(H.offer(data, "d3-unit-animal"), "Backlog did not resume after capacity freed.")
	_expect(data["husbandry"]["records"]["d3-unit-animal"]["handed_over"] == 100 and Model.Economy.milk_pending(data) == 4 and valid(data), "Split batches changed total production.")
	# A yield immediately below a whole litre must not be rounded up by an epsilon.
	var near_one: Dictionary = fixture(0.999999999, 1)
	for i in range(4): H.advance(near_one, near_one["husbandry"]["pens"][0], 0.25)
	_expect(near_one["husbandry"]["records"]["d3-unit-animal"]["produced"] == 0 and valid(near_one), "Near-integer yield rounded up.")
	# Sub-litre yields accumulate; absent feed freezes unfinished work.
	data = fixture(0.25, 1)
	for i in range(12): H.advance(data, data["husbandry"]["pens"][0], 0.25)
	_expect(data["husbandry"]["records"]["d3-unit-animal"]["produced"] == 0, "Fractional yields rounded up.")
	for i in range(4): H.advance(data, data["husbandry"]["pens"][0], 0.25)
	_expect(data["husbandry"]["records"]["d3-unit-animal"]["produced"] == 1 and valid(data), "Fractional milk failed to accumulate.")
	data["husbandry"]["consumed"]["food"] += data["husbandry"]["pens"][0]["food"]
	data["husbandry"]["pens"][0]["food"] = 0.0
	before = data.duplicate(true)
	H.advance(data, data["husbandry"]["pens"][0], 0.25)
	_expect(data == before, "Animal produced or drank without food.")
	# Reject malformed nested data and duplicated supplies, without runtime exceptions.
	for field: String in ["pens", "records", "withdrawn", "returned", "delivered", "consumed"]:
		var bad: Dictionary = data.duplicate(true)
		bad["husbandry"][field] = "broken"
		_expect(not valid(bad), "Malformed field accepted: " + field)
	for field: String in ["recipe", "design_ref", "pickup", "pending_milk", "cycles", "sequence"]:
		var bad: Dictionary = data.duplicate(true)
		bad["husbandry"]["records"]["d3-unit-animal"][field] = "broken"
		_expect(not valid(bad), "Malformed production accepted: " + field)
	var bad: Dictionary = data.duplicate(true)
	bad["husbandry"]["pens"][0]["water"] += 1
	_expect(not valid(bad), "Free trough water accepted.")
	bad = data.duplicate(true)
	bad["members"][0]["care_pen_id"] = "missing"
	bad["members"][0]["cargo"] = "water"
	_expect(not valid(bad), "Orphan care cargo accepted.")
	bad = data.duplicate(true)
	bad["project"] = {"kind": "pen", "progress": 0}
	_expect(not valid(bad), "Incomplete pen construction accepted.")
	print(JSON.stringify({"test": "tribal_age_husbandry_contract", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func valid(data: Dictionary) -> bool:
	return Model.validate(data, body, campaign.data).is_empty()

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
