extends SceneTree
const Neighbor = preload("res://world/tribe/neighbors/neighbor_state.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const Tribal = preload("res://core/progression/tribal_progression.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var campaign: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/home_group_pr20.json"))["campaign"]
	var body: Dictionary = campaign["bodies"]["15838"]
	var anchor: Array = body["home_group"]["anchor"]
	var village: Dictionary = Tribe.create(body["home_group"], campaign, {"position": anchor}, {"wood": anchor, "stone": anchor, "food": anchor, "huts": [anchor, anchor]})
	var center: Vector3 = Tribe.Home.vector(anchor) + Vector3(10, 0, 0)
	var neighbor: Dictionary = Neighbor.create(campaign, village, center, [center + Vector3(1, 0, 1), center + Vector3(-1, 0, 1)])
	var ids: Array = village["members"].map(func(m: Dictionary) -> String: return m["id"])
	_expect(Neighbor.validate(neighbor, village, campaign).is_empty(), "Fresh neighbor contract is invalid")
	_expect(not Neighbor.begin(neighbor, village, [ids[0]]).is_empty() and neighbor["aid"]["status"] == "offered", "Solo assignment started a community agreement")
	_expect(Neighbor.begin(neighbor, village, [ids[0], ids[1]]).is_empty(), "Valid assignment failed")
	var member: Dictionary = village["members"][0]
	var pending: Dictionary = neighbor.duplicate(true)
	Neighbor.work(neighbor, village, member)
	_expect(neighbor == pending and member["cargo"] == "", "Empty home stock produced aid")
	for kind: String in ["wood", "food"]:
		village["stock"][kind] = 18
		village["deposits"][kind]["remaining"] -= 18
	# The producer's arrival check is independently required by the pure contract.
	member["position"] = Tribe.Home.vector_array(center)
	Neighbor.work(neighbor, village, member)
	_expect(member["cargo"] == "", "Remote stock pickup succeeded")
	member["position"] = anchor.duplicate()
	Neighbor.work(neighbor, village, member)
	_expect(member["cargo"] == "food" and neighbor["stock"]["food"] == 0, "Pickup teleported into neighbor stock")
	member["order"] = "wait"
	var stopped: Dictionary = JSON.parse_string(JSON.stringify(neighbor))
	Neighbor.work(neighbor, village, member)
	_expect(JSON.parse_string(JSON.stringify(neighbor)) == stopped, "Stopped carrier delivered")
	member["order"] = "wood"
	Neighbor.target(neighbor, village, member)
	Neighbor.work(neighbor, village, member)
	_expect(village["stock"]["food"] == 18 and village["delivered"] == 0 and neighbor["aid"]["returned"]["food"] == 1, "Cancelled aid duplicated stock or farming credit")
	# Reassign only free people; preserve the still-running other courier.
	_expect(Neighbor.begin(neighbor, village, [ids[0], ids[2]]).is_empty(), "Free replacement pair rejected")
	for actor: String in [ids[0], ids[1]]:
		member = Neighbor.resident(village, actor)
		for unit in range(5):
			member["position"] = anchor.duplicate()
			Neighbor.work(neighbor, village, member)
			member["position"] = Tribe.Home.vector_array(center)
			Neighbor.work(neighbor, village, member)
			_expect(Neighbor.validate(neighbor, village, campaign).is_empty(), "Actual delivery violates conservation")
		if actor == ids[0]:
			member["position"] = anchor.duplicate()
			Neighbor.work(neighbor, village, member)
			_expect(member["cargo"] == "" and neighbor["aid"]["carriers"][actor] == 5 and neighbor["aid"]["status"] == "active", "One carrier exceeded quota or completed aid alone")
	_expect(neighbor["aid"]["status"] == "building" and not Neighbor.progress(neighbor)["met"], "Arrived goods skipped actual construction")
	neighbor = JSON.parse_string(JSON.stringify(neighbor))
	_expect(Neighbor.validate(neighbor, village, campaign).is_empty(), "JSON migration breaks a partially completed agreement")
	var builders: Array = neighbor["members"].map(func(m: Dictionary) -> String: return m["id"])
	var before: Dictionary = neighbor.duplicate(true)
	for delta: float in [0.0, -1.0, NAN, INF]:
		Neighbor.build(neighbor, builders[0], delta)
	_expect(neighbor == before, "Pause or invalid delta builds a shelter")
	Neighbor.build(neighbor, builders[0], 24.0)
	_expect(not Neighbor.progress(neighbor)["met"], "One neighbor built the communal shelter alone")
	before = neighbor.duplicate(true)
	Neighbor.build(neighbor, builders[1], 0.1)
	_expect(Neighbor.progress(neighbor)["met"] and Neighbor.validate(neighbor, village, campaign).is_empty(), "Finished real construction rejected")
	var complete: Dictionary = neighbor.duplicate(true)
	Neighbor.build(neighbor, builders[1], 24.0)
	_expect(neighbor == complete, "Completed shelter consumed wood twice")
	for key: String in ["species_id", "phase", "stock", "members", "aid"]:
		var bad: Dictionary = neighbor.duplicate(true)
		bad[key] = null
		_expect(not Neighbor.validate(bad, village, campaign).is_empty(), "Corrupted " + key + " accepted")
	var bad: Dictionary = neighbor.duplicate(true)
	bad["aid"]["withdrawn"]["wood"] += 1
	_expect(not Neighbor.validate(bad, village, campaign).is_empty(), "Missing cargo passed conservation")
	bad = neighbor.duplicate(true)
	bad["aid"]["carriers"]["wild-animal"] = 1
	_expect(not Neighbor.validate(bad, village, campaign).is_empty(), "Wild animal accepted as a community carrier")
	bad = neighbor.duplicate(true)
	bad["schema"] = Neighbor.SCHEMA + 1
	_expect(Neighbor.has_unsupported_contract(bad), "Future neighbor schema was not protected")
	var old: Dictionary = Tribal.defaults()
	old["schema"] = 2
	var progression = Tribal.new()
	_expect(progression.import_state(old) and progression.export_state()["schema"] == 3 and progression.wallet()["earned"]["social"] == 0, "Previous tribal format did not migrate without invented aid")
	print(JSON.stringify({"test": "tribal_neighbors_contract", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
