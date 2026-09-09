extends SceneTree
const Model = preload("res://world/tribe/tribe_state.gd")
const Housing = preload("res://world/tribe/village_housing.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Campaign = preload("res://core/campaign/campaign_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var campaign := Campaign.new()
	campaign.reset("m6-growth-contract")
	var body: Dictionary = campaign.body_for_seed(15838, 1)
	body["home_group"] = Home.create(body["id"], campaign.data["player_species_id"], Vector3.ZERO)
	var data: Dictionary = Model.create(body["home_group"], campaign.data, {"position": [0, 0, 0]}, {"wood": [-5, 0, -4], "stone": [5, 0, -4], "food": [-5, 0, 4], "huts": [[5, 0, 4], [8, 0, 0]]})
	data["tools"] = 1
	data["huts"] = 1
	data["garden"] = 1
	data["project"] = {"kind": "hut", "progress": 7.25}
	data["deposits"]["wood"]["remaining"] -= 6
	data["deposits"]["stone"]["remaining"] -= 3
	data["schema"] = 3
	data.erase("housing")
	for member: Dictionary in data["members"]:
		for key: String in ["construction_id", "species_id", "faction_id"]:
			member.erase(key)
	var worker: Dictionary = data["members"][1]
	worker.merge({"order": "wait", "paused_order": "wood", "profession": "forester", "cargo": "wood", "stage": "return", "work": 1.25}, true)
	data["deposits"]["wood"]["remaining"] -= 1
	var batch: Dictionary = {"schema": 1, "source_id": "d3-retained-source", "body_id": data["body_id"], "faction_id": data["faction_id"], "sequence": 1, "amount": 3, "position": [0, 0, -7]}
	_expect(Economy.receive_milk(data, batch).is_empty(), "Milk fixture rejected.")
	_expect(Model.validate(data, body, campaign.data).is_empty(), "Invalid real schema-3 fixture.")
	var old: Dictionary = data.duplicate(true)
	_expect(Model.upgrade(data), "Schema 3 was not migrated.")
	_expect(Model.validate(data, body, campaign.data).is_empty(), "Migrated construction invalid.")
	for field: String in ["stock", "deposits", "economy", "sites", "huts", "tools", "grown", "growth"]:
		_expect(data[field] == old[field], "Migration reset " + field)
	for i in range(3):
		for field: String in old["members"][i]:
			_expect(data["members"][i][field] == old["members"][i][field], "Migration changed member " + field)
	_expect(data["project"]["progress"] == 7.25 and data["project"]["position"] == old["sites"][1] and Housing.supplied(data["project"]), "Paid old project lost progress, site or materials.")
	var migrated: Dictionary = data.duplicate(true)
	_expect(not Model.upgrade(data) and data == migrated, "Repeated migration duplicated housing.")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(data))
	_expect(Model.validate(snapshot, body, campaign.data).is_empty(), "JSON changed housing contract.")
	var milk_before: Dictionary = snapshot.duplicate(true)
	_expect(Economy.receive_milk(snapshot, batch).is_empty() and snapshot == milk_before, "Migration/JSON duplicated D3 receipt.")
	# A paid construction unit exists in precisely one place across stop/load.
	data["project"]["progress"] = 0.0
	data["project"]["delivered_materials"]["wood"] -= 1
	worker["construction_id"] = data["project"]["id"]
	_expect(Model.validate(data, body, campaign.data).is_empty(), "Carried building material was rejected.")
	var bad: Dictionary = data.duplicate(true)
	bad["project"]["materials"]["wood"] += 1
	_expect(not Model.validate(bad, body, campaign.data).is_empty(), "Building material counted twice.")
	bad = data.duplicate(true)
	bad["members"][1]["construction_id"] = "missing-site"
	_expect(not Model.validate(bad, body, campaign.data).is_empty(), "Orphan building cargo accepted.")
	# Three completed huts, stable original residents, enough deposited reserves.
	data["project"] = {}
	worker["construction_id"] = ""
	data["housing"]["homes"] = []
	for i in range(3):
		data["housing"]["homes"].append(Housing.site(data, "hut", [5 + i * 4, 0, 5], i))
	data["huts"] = 3
	data["stock"]["food"] = 20
	data["deposits"]["food"]["remaining"] = 0
	data["stock"]["water"] = 20
	data["economy"]["produced"]["water"] = 20
	data["economy"]["stations"]["well"] = {"id": Model.Ids.scoped("workplace", data["id"], "well"), "position": [0, 0, -7]}
	data["deposits"]["water"]["position"] = [0, 0, -7]
	_expect(Model.validate(data, body, campaign.data).is_empty(), "Growth fixture invalid.")
	_expect(not Housing.tick(data, 40) and data["housing"]["clock"] == 40, "Growth clock did not advance.")
	var clock: Dictionary = data.duplicate(true)
	Housing.tick(data, 0)
	Housing.tick(data, -10)
	Housing.tick(data, INF)
	_expect(data == clock, "Pause/invalid time changed population.")
	data["stock"]["water"] = 0
	Housing.tick(data, 1)
	_expect(data["housing"]["clock"] == 0, "Interrupted supply retained sustained-growth credit.")
	data["stock"]["water"] = 20
	for count in range(4, 7):
		_expect(Housing.tick(data, 90), "Supplied growth did not become ready.")
		var new_member: Dictionary = Housing.add_resident(data, Vector3(5, 0, 7))
		_expect(not new_member.is_empty() and data["members"].size() == count and new_member["id"] == Housing.resident_id(data, count - 1), "New resident missing or unstable identity.")
		_expect(new_member["species_id"] == data["species_id"] and new_member["faction_id"] == data["faction_id"], "Resident did not inherit own tribe.")
		_expect(Model.validate(JSON.parse_string(JSON.stringify(data)), body, campaign.data).is_empty(), "Grown snapshot invalid.")
	_expect(data["stock"]["food"] == 14 and data["stock"]["water"] == 14, "Growth did not spend shared supplies exactly once.")
	_expect(not Housing.tick(data, 9000) and Housing.add_resident(data, Vector3.ZERO).is_empty() and data["members"].size() == 6, "Population cap bypassed.")
	bad = data.duplicate(true)
	bad["members"][5]["id"] = bad["members"][4]["id"]
	_expect(not Model.validate(bad, body, campaign.data).is_empty(), "Duplicate resident accepted.")
	bad = data.duplicate(true)
	bad["members"][5]["species_id"] = "foreign-species"
	_expect(not Model.validate(bad, body, campaign.data).is_empty(), "Foreign species resident accepted.")
	for field: String in ["housing", "homes", "clock"]:
		bad = data.duplicate(true)
		if field == "housing":
			bad[field] = "broken"
		else:
			bad["housing"][field] = "broken"
		_expect(not Model.validate(bad, body, campaign.data).is_empty(), "Malformed housing accepted: " + field)
	print(JSON.stringify({"test": "tribal_age_growth_contract", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
