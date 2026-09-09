extends SceneTree
const Tribal = preload("res://core/progression/tribal_progression.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const Civilization = preload("res://core/progression/civilization_contract.gd")
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
	_expect(Tribe.validate(village, body, campaign).is_empty(), "Invalid village fixture")
	_expect(Tribal.validate(JSON.parse_string(JSON.stringify(Tribal.defaults()))).is_empty(), "Empty JSON migration fails")
	for index in range(8):
		_delivery(0, "wood")
	_expect(model.wallet()["earned"]["social"] == 0, "Solo grinding earned community points")
	_delivery(1, "wood")
	_expect(model.wallet()["earned"]["social"] == 3, "Two contributing carriers did not earn the stock milestone")
	var earned: Dictionary = model.export_state()
	var working: Dictionary = village.duplicate(true)
	working["members"][0]["order"] = "wood"
	for index in range(20):
		model.observe(working, working, str(working["members"][0]["id"]), body, campaign, 1)
	_expect(model.export_state() == earned, "Idle orders or repeated observations earned progress")
	var foreign: Dictionary = village.duplicate(true)
	foreign["species_id"] = "wild_species"
	_expect(not model.observe(village, foreign, str(village["members"][0]["id"]), body, campaign, 1)["changed"], "Foreign species earned civilization progress")
	var newcomer = Tribal.new()
	var prior: Dictionary = village.duplicate(true)
	_expect(not newcomer.observe(prior, village, str(village["members"][0]["id"]), body, campaign, 0)["changed"], "Creature phase earned tribal progress")
	_expect(not newcomer.observe(prior, village, "owned-animal", body, campaign, 1)["changed"], "An animal counted as a citizen")
	# A real partially completed construction retains worker attribution through JSON.
	village["stock"]["wood"] -= 3
	village["project"] = {"kind": "tool", "progress": 0.0}
	_work(0, 3.0, false)
	var halfway: Dictionary = JSON.parse_string(JSON.stringify(model.export_state()))
	_expect(model.import_state(halfway), "Partial work failed to deserialize")
	_work(1, 10.0, true)
	_expect(model.wallet()["earned"]["social"] == 6, "Reload lost cooperation on an unfinished project")
	_expect(model.can_purchase("tribe.social.teamwork", 0)["reason"] == "future_phase", "Tribal skill purchasable before the tribe")
	_expect(model.purchase("tribe.social.teamwork", 1)["ok"], "Earned tribal skill cannot be bought")
	_expect(not model.purchase("tribe.social.teamwork", 1)["ok"], "Same skill bought twice")
	_expect(is_equal_approx(model.effect_bonus("group_cooperation", 1), 0.1) and model.effect_bonus("group_cooperation", 0) == 0.0 and model.effect_bonus("group_cooperation", 2) == 0.0, "Tribal effect stacked or leaked to another phase")
	_expect(model.wallet()["available"]["aggression"] == 0, "Production created combat points")
	for index in range(20):
		_delivery(index % 2, "stone")
	_expect(model.wallet()["earned"]["social"] == 6, "Repeated deliveries farmed the same milestone")
	var bad: Dictionary = model.export_state()
	bad["schema"] = Tribal.SCHEMA + 1
	_expect(Tribal.has_unsupported_contract(bad) and not model.import_state(bad), "Future tribal state was silently downgraded")
	bad = model.export_state()
	bad["villages"][village["id"]]["deliveries"]["owned-animal"] = 2
	_expect(not model.import_state(bad), "Saved animal admitted as a contributor")
	var snapshot: Dictionary = campaign.duplicate(true)
	var neighbor: Dictionary = Civilization.neighbor_plan(campaign, body["id"], 0)
	_expect(neighbor == Civilization.neighbor_plan(campaign, body["id"], 0), "Neighbor identity is not deterministic")
	_expect(neighbor["id"] != campaign["player_faction_id"] and neighbor["id"] != Civilization.neighbor_plan(campaign, body["id"], 1)["id"] and neighbor["species_id"] == campaign["player_species_id"], "Neighbor faction identity conflates species or factions")
	_expect(Civilization.validate_faction(neighbor, campaign).is_empty(), "Own-species neighbor rejected")
	neighbor["species_id"] = "wild_species"
	_expect(not Civilization.validate_faction(neighbor, campaign).is_empty(), "Wild species allowed to advance")
	for phase: int in [2, 3]:
		var description: Dictionary = Civilization.describe(campaign, "15838", phase - 1, phase)
		_expect(not description["available"] and not description["implemented"] and description["requires_confirmation"], "Unimplemented epoch opened")
	_expect(campaign == snapshot, "Planning changed live campaign, inhabitants or wildlife")
	# The retention contract protects unknown future animal extensions too.
	var before: Dictionary = campaign.duplicate(true)
	before["bodies"]["15838"]["animals"] = {"animal_a": {"species_id": "milk_species", "owner": campaign["player_faction_id"], "trust": 0.7, "order": "home"}}
	var after: Dictionary = before.duplicate(true)
	after["technology"] = {"new_era": true}
	_expect(Civilization.validate_retention(before, after).is_empty(), "Lossless additive transition rejected")
	after["bodies"]["15838"]["animals"]["animal_a"]["species_id"] = campaign["player_species_id"]
	_expect(not Civilization.validate_retention(before, after).is_empty(), "Epoch turned an animal into the player species")
	after = before.duplicate(true)
	after["bodies"]["15838"]["tribe"]["members"].pop_back()
	_expect(not Civilization.validate_retention(before, after).is_empty(), "Epoch lost a resident")
	print(JSON.stringify({"test": "tribal_progression", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _delivery(index: int, kind: String) -> void:
	var member: Dictionary = village["members"][index]
	member["order"] = kind
	member["cargo"] = kind
	village["deposits"][kind]["remaining"] -= 1
	var before: Dictionary = village.duplicate(true)
	member["cargo"] = ""
	village["stock"][kind] += 1
	village["delivered"] += 1
	model.observe(before, village, str(member["id"]), body, campaign, 1)
	var once: Dictionary = model.export_state()
	model.observe(before, village, str(member["id"]), body, campaign, 1)
	_expect(model.export_state() == once, "Duplicate delivery observation paid twice")

func _work(index: int, progress: float, done: bool) -> void:
	var member: Dictionary = village["members"][index]
	member["order"] = "tool"
	var before: Dictionary = village.duplicate(true)
	village["project"]["progress"] = progress
	if done:
		village["tools"] += 1
		village["project"] = {}
		member["order"] = "wait"
	model.observe(before, village, str(member["id"]), body, campaign, 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
