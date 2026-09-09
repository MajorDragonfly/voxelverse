extends SceneTree
const Model = preload("res://world/tribe/tribe_state.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Campaign = preload("res://core/campaign/campaign_state.gd")
class MilkInbox extends "res://world/tribe/tribe_controller.gd":
	var snapshot: Dictionary = {}
	func is_active() -> bool:
		return true
	func village() -> Dictionary:
		return snapshot
	func body() -> Dictionary:
		return {"tribe": snapshot}

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var campaign := Campaign.new()
	campaign.reset("m6-contract-fixture")
	var body: Dictionary = campaign.body_for_seed(15838, 1)
	body["home_group"] = Home.create(body["id"], campaign.data["player_species_id"], Vector3.ZERO)
	var village: Dictionary = Model.create(body["home_group"], campaign.data, {"position": [0, 0, 0]}, {"wood": [-5, 0, -4], "stone": [5, 0, -4], "food": [-5, 0, 4], "huts": [[5, 0, 4], [8, 0, 0]]})
	_expect(Model.validate(village, body, campaign.data).is_empty(), "Invalid fresh village contract.")
	var batch: Dictionary = {"schema": 1, "source_id": "D3-owned-animal", "sequence": 1, "amount": 3, "position": [0, 0, -6], "body_id": body["id"], "faction_id": village["faction_id"]}
	var with_milk: Dictionary = village.duplicate(true)
	_expect(Economy.receive_milk(with_milk, batch).is_empty(), "Valid D3 offer rejected.")
	with_milk = JSON.parse_string(JSON.stringify(with_milk))
	var before: Dictionary = with_milk.duplicate(true)
	_expect(Economy.receive_milk(with_milk, batch).is_empty() and with_milk == before, "JSON reload allowed repeat production or rejected its identical retry.")
	for field: String in ["body_id", "faction_id", "sequence", "amount", "position", "source_id"]:
		var bad: Dictionary = batch.duplicate(true)
		bad[field] = {"body_id": "another-body", "faction_id": "another-owner", "sequence": 3, "amount": 49, "position": [200, 0, 0], "source_id": ""}[field]
		_expect(not Economy.receive_milk(with_milk, bad).is_empty() and with_milk == before, "Rejected D3 offer changed the store: " + field)
	var inbox := MilkInbox.new()
	inbox.snapshot = with_milk.duplicate(true)
	# Empty runtime graph represents a no-longer-reachable old pickup site.
	_expect(inbox.receive_milk(batch), "Saved receipt was no longer acknowledged after its old route disappeared.")
	inbox.free()
	var full: Dictionary = village.duplicate(true)
	var full_batch: Dictionary = batch.duplicate(true)
	full_batch["amount"] = 48
	_expect(Economy.receive_milk(full, full_batch).is_empty(), "Full legal milk queue rejected.")
	full_batch["sequence"] = 2
	full_batch["amount"] = 1
	var full_before: Dictionary = full.duplicate(true)
	_expect(not Economy.receive_milk(full, full_batch).is_empty() and full == full_before, "Pending milk did not reserve store capacity.")
	# Never accept corrupt economy structures by coercing missing fields to zero.
	for field: String in ["economy", "produced", "clocks", "stations", "receipts", "incoming"]:
		var corrupt: Dictionary = village.duplicate(true)
		if field == "economy":
			corrupt[field] = "broken"
		else:
			corrupt["economy"][field] = "broken"
		_expect(not Model.validate(corrupt, body, campaign.data).is_empty(), "Malformed nested contract accepted: " + field)
	var forged: Dictionary = with_milk.duplicate(true)
	forged["stock"]["milk"] = 1
	_expect(not Model.validate(forged, body, campaign.data).is_empty(), "Untransported milk can be credited twice.")
	forged = with_milk.duplicate(true)
	forged["economy"]["incoming"].append(forged["economy"]["incoming"][0].duplicate(true))
	_expect(not Model.validate(forged, body, campaign.data).is_empty(), "Duplicate queued delivery accepted.")
	var growing: Dictionary = village.duplicate(true)
	growing["tools"] = 1
	growing["economy"]["stations"]["well"] = {"id": Model.Ids.scoped("workplace", village["id"], "well"), "position": [0, 0, -6]}
	growing["deposits"]["water"]["position"] = [0, 0, -6]
	Economy.tick(growing, 4000)
	_expect(growing["deposits"]["water"]["remaining"] == 8 and growing["economy"]["clocks"]["water"] == 0 and growing["economy"]["produced"]["water"] == 8, "Full source banked an unlimited catch-up backlog.")
	var no_time: Dictionary = growing.duplicate(true)
	Economy.tick(growing, 0)
	Economy.tick(growing, -1)
	_expect(growing == no_time, "No simulation time still created resources.")
	_expect(Model.validate(growing, body, campaign.data).is_empty(), "Renewal created an invalid source balance.")
	print(JSON.stringify({"test": "tribal_age_economy_contract", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
