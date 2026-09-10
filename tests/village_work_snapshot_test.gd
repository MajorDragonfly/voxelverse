extends SceneTree
const Work = preload("res://world/tribe/village_work.gd")
const Tribe = Work.Model
const Economy = Work.Economy
const Housing = Work.Housing
const Campaign = preload("res://core/campaign/campaign_state.gd")
const Tribal = preload("res://core/progression/tribal_progression.gd")
const Simulation = preload("res://world/tribe/village_simulation.gd")
var failures: Array[String] = []
var steps: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	for rate in [1.0, 2.0, 4.0]:
		for resource in ["wood", "stone", "food", "water", "fiber"]:
			var f: Dictionary = fixture()
			var member: Dictionary = f.village.members[0]
			member.order = resource
			f.village.stock[resource] = 0
			member.profession = {"wood": "forester", "stone": "mason", "food": "provider", "water": "provider", "fiber": "weaver"}[resource]
			member.position = f.village.deposits[resource].position.duplicate(true)
			for tick in range(3): trial(resource + " work", f, 0, 1.0 / rate, rate)
			_expect(member.cargo == resource, "Work did not produce the expected cargo.")
			member.position = f.village.anchor.duplicate(true)
			trial(resource + " delivery", f)
			_expect(member.cargo.is_empty() and f.village.delivered == 1, "Delivery lost or duplicated its unit.")
		var waiting: Dictionary = fixture()
		trial("wait", waiting, 0, 0.25, rate)
	for action in ["feed", "drink"]:
		var f: Dictionary = fixture()
		f.village.members[0].order = action
		f.village.members[0].hunger = 30.0
		f.village.members[0].hydration = 30.0
		trial(action, f)
	for order in ["supply", "provision", "move"]:
		var f: Dictionary = fixture()
		f.village.stock.food = 0
		f.village.stock.water = 0
		f.village.members[0].order = order
		trial(order + " arrived work", f, 0, 3.0)
	for stage in ["meal", "drink"]:
		var f: Dictionary = fixture()
		f.village.members[0].order = "wood"
		f.village.members[0].stage = stage
		f.village.members[0].hunger = 30.0
		f.village.members[0].hydration = 30.0
		trial(stage + " work pause", f)
	for units in [1, 2]:
		var f: Dictionary = fixture()
		var v: Dictionary = f.village
		_expect(Economy.receive_milk(v, {"schema": 1, "source_id": "snapshot-milk", "body_id": v.body_id,
			"faction_id": v.faction_id, "sequence": 1, "amount": units, "position": v.anchor.duplicate(true)}).is_empty(), "Milk setup failed.")
		v.members[0].order = "milk"
		trial("milk pickup/pop", f)
		# A persisted in-flight work receipt must survive until delivery.
		_expect(f.observed.import_state(JSON.parse_string(JSON.stringify(f.observed.export_state()))), "In-flight receipt did not reload.")
		_expect(f.reference.import_state(JSON.parse_string(JSON.stringify(f.reference.export_state()))), "Reference receipt did not reload.")
		trial("milk delivery", f)
		v.members[0].order = "feed"
		v.members[0].hunger = 30.0
		trial("milk meal", f)
	for kind in ["tool", "garden", "well", "forester", "quarry", "fiberbed", "hut", "tent", "pen"]:
		var f: Dictionary = fixture(false)
		var v: Dictionary = f.village
		v.tools = 0 if kind == "tool" else 1
		if kind in Housing.BUILDS:
			v.project = Housing.site(v, kind, [4, 0, 3], 0)
			v.project.merge({"progress": 0.0, "materials": Housing.COSTS[kind].duplicate(), "delivered_materials": {}})
			for resource in Housing.COSTS[kind]: v.project.delivered_materials[resource] = 0
			for resource in Housing.COSTS[kind]:
				if resource == "fiber":
					v.economy.stations.fiberbed = {"id": Tribe.Ids.scoped("workplace", v.id, "fiberbed"), "position": v.anchor.duplicate(true)}
					v.economy.produced.fiber = Housing.COSTS[kind][resource]
				else: v.deposits[resource].remaining -= Housing.COSTS[kind][resource]
		else:
			v.project = {"kind": kind, "progress": 0.0}
			if kind in Economy.STATIONS: v.project.position = [4, 0, 3]
		for member: Dictionary in v.members:
			member.order = kind
			member.profession = "builder"
		if kind in Housing.BUILDS:
			var units: int = 0
			for resource in Housing.COSTS[kind]: units += Housing.COSTS[kind][resource]
			for unit in range(units):
				v.members[0].position = v.anchor.duplicate(true)
				trial(kind + " material pickup", f)
				v.members[0].position = v.project.entrance.duplicate(true)
				trial(kind + " material delivery", f)
		trial(kind + " contribution", f, 0, 0.25)
		if kind in Housing.BUILDS: v.members[1].position = v.project.entrance.duplicate(true)
		trial(kind + " completion", f, 1, 20.0)
		_expect(v.project.is_empty(), "Project did not complete: " + kind)
		if kind in ["tool", "hut", "garden"]:
			_expect(f.observed.export_state().awards.has("shared_" + kind), "Shared construction lost its reward: " + kind)
	care_and_neighbor()
	far_construction()
	var history: Dictionary = fixture()
	add_history(history, 32)
	trial("history remains intact", history)
	if failures.is_empty(): print("VILLAGE_WORK_SNAPSHOT_PASSED ", steps, " arrived steps compared with full copies")
	await finish()

func fixture(renewable: bool = true) -> Dictionary:
	var campaign := Campaign.new()
	campaign.reset("arch15-snapshot-fixture")
	var created: Dictionary = campaign.ensure_body(15838, 15838)
	var body: Dictionary = campaign.body_record(created.id)
	body.home_group = Tribe.Home.create(body.id, campaign.data.player_species_id, Vector3.ZERO)
	body.tribe = Tribe.create(body.home_group, campaign.data, {"position": [0, 0, 0]},
		{"wood": [0, 0, 0], "stone": [0, 0, 0], "food": [0, 0, 0], "huts": [[5, 0, 4], [8, 0, 0]]})
	var v: Dictionary = body.tribe
	if renewable:
		v.tools = 1
		v.garden = 1
		v.grown = 24
		v.stock.food = 18
		v.stock.water = 12
		for station in Economy.STATIONS:
			var resource: String = Economy.STATIONS[station]
			v.economy.stations[station] = {"id": Tribe.Ids.scoped("workplace", v.id, station), "position": v.anchor.duplicate(true)}
			v.deposits[resource].position = v.anchor.duplicate(true)
			v.economy.produced[resource] = 24
			v.deposits[resource].remaining = 8
	return {"campaign": campaign.data, "body": body, "village": v, "observed": Tribal.new(), "reference": Tribal.new()}

func trial(label: String, f: Dictionary, index: int = 0, delta: float = 0.25, rate: float = 1.0) -> void:
	var v: Dictionary = f.village
	var original: Dictionary = v.duplicate(true)
	var before: Dictionary = Work.snapshot(v, v.members[index].id)
	var oracle: Dictionary = original.duplicate(true)
	var actual_effects: Array = []
	var expected_effects: Array = []
	Work.step(v, v.members[index], delta, rate, actual_effects)
	Work.step(oracle, oracle.members[index], delta, rate, expected_effects)
	_expect(v == oracle and actual_effects == expected_effects, label + ": work output changed.")
	compare(label, f, before, original, index)

func compare(label: String, f: Dictionary, before: Dictionary, original: Dictionary, index: int = 0) -> void:
	steps += 1
	_expect(before == original, label + ": work mutated its own evidence copy.")
	var actor: String = f.village.members[index].id
	var actual: Dictionary = f.observed.observe(before, f.village, actor, f.body, f.campaign, 1)
	var expected: Dictionary = f.reference.observe(original, f.village, actor, f.body, f.campaign, 1)
	_expect(actual == expected and f.observed.export_state() == f.reference.export_state(), label + ": progression differs from full-copy evidence.")
	# New copies must still be ordinary complete village dictionaries to observers.
	var before_problem: String = Tribe.validate(before, f.body, f.campaign)
	var after_problem: String = Tribe.validate(f.village, f.body, f.campaign)
	_expect(before_problem.is_empty(), label + ": invalid before: " + before_problem)
	_expect(after_problem.is_empty(), label + ": invalid after: " + after_problem)
	_expect(Tribal.validate(f.observed.export_state()).is_empty(), label + ": invalid progression save.")
	# Replaying the same observation must not pay or open the completed cargo again.
	var paid: Dictionary = f.observed.export_state()
	f.observed.observe(before, f.village, actor, f.body, f.campaign, 1)
	_expect(f.observed.export_state() == paid, label + ": evidence replay changed progression.")

func far_construction() -> void:
	var f: Dictionary = fixture(false)
	var v: Dictionary = f.village
	v.tools = 1
	v.project = Housing.site(v, "hut", [4, 0, 3], 0)
	v.project.merge({"progress": 19.75, "materials": {"wood": 0, "stone": 0}, "delivered_materials": Housing.COSTS.hut.duplicate()})
	for resource in Housing.COSTS.hut: v.deposits[resource].remaining -= Housing.COSTS.hut[resource]
	for member: Dictionary in v.members:
		member.order = "hut"
		member.profession = "builder"
	v.members[0].position = v.project.entrance.duplicate(true)
	f.body.village_simulation = Simulation.create(f.body.id, 0, {}, [], "")
	var original: Dictionary = v.duplicate(true)
	# Far capture follows this resident's needs update and arrival.
	Work.prepare(original, original.members[0], 0.25)
	var calls: Array[int] = [0]
	Simulation.advance(f.body, 0.25, 1.0, func(before: Dictionary, actor: String, _body: Dictionary, _delta: float) -> void:
		if before.is_empty(): return
		calls[0] += 1
		_expect(actor == v.members[0].id, "Unexpected far construction actor.")
		compare("far construction and route recertification", f, before, original)
	)
	_expect(calls[0] == 1 and v.project.is_empty(), "Far construction did not finish exactly once.")
	_expect(v.members.all(func(member: Dictionary) -> bool: return member.blocked), "Far construction did not retain blocked routes.")

func add_history(f: Dictionary, count: int) -> void:
	var v: Dictionary = f.village
	var pen: Dictionary = Housing.site(v, "pen", [0, 0, 7], 0)
	pen.merge({"animal_id": "", "food": 0.0, "water": 0.0})
	v.husbandry.pens.append(pen)
	for index in range(count):
		var animal: Dictionary = preload("res://world/domestication/animal_state.gd").individual("history-" + str(index), "milk-species", f.body.id, {"id": "milk-design", "revision": 1}, Vector3.ZERO)
		_expect(Simulation.H.bind(v, pen, animal, {"milk_yield": 2.0, "milk_interval": 300.0, "water_need": 4.0}).is_empty(), "History setup failed.")
		_expect(Simulation.H.unbind(v, pen).is_empty(), "History release failed.")
	_expect(Tribe.validate(v, f.body, f.campaign).is_empty(), "Invalid history: " + Tribe.validate(v, f.body, f.campaign))

func care_and_neighbor() -> void:
	var f: Dictionary = fixture()
	add_history(f, 1)
	var v: Dictionary = f.village
	var pen: Dictionary = v.husbandry.pens[0]
	pen.animal_id = "history-0"
	var animal: Dictionary = {"status": "tamed", "owner_faction_id": v.faction_id, "order": "wait", "species_id": "milk-species", "design_ref": {"id": "milk-design", "revision": 1}, "position": pen.position.duplicate(true)}
	f.body.domesticated_animals = {"registry": {"animals": {"history-0": animal}}}
	f.body.village_simulation = Simulation.create(f.body.id, 0, {Simulation.key(pen.entrance): [v.anchor, pen.entrance]}, ["history-0"], "")
	v.members[0].order = "tend"
	for action in ["pickup", "deliver", "pickup", "return"]:
		v.members[0].position = pen.entrance.duplicate(true) if action == "deliver" else v.anchor.duplicate(true)
		var original: Dictionary = v.duplicate(true)
		var before: Dictionary = Work.snapshot(v, v.members[0].id)
		if action == "pickup": Simulation._pickup(f.body, v.members[0])
		else:
			if action == "return": f.body.village_simulation.attending.clear()
			Simulation._deliver(f.body, v.members[0])
		compare("care " + action, f, before, original)
		_expect(Tribe.validate(v, f.body, f.campaign).is_empty(), "Care broke conservation: " + action)
	_expect(v.husbandry.withdrawn.water == 2 and v.husbandry.delivered.water == 1 and v.husbandry.returned.water == 1 and pen.water == 1, "Care did not deliver and return exactly one unit each.")
	f = fixture()
	v = f.village
	v.stock.wood = 4
	v.deposits.wood.remaining -= 4
	var neighbor: Dictionary = Simulation.Neighbor.create(f.campaign, v, Vector3(8, 0, 0), [Vector3(7, 0, 1), Vector3(9, 0, 1)])
	_expect(Simulation.Neighbor.begin(neighbor, v, [v.members[0].id, v.members[1].id]).is_empty(), "Neighbor setup failed.")
	for stage in range(2):
		v.members[0].position = v.anchor.duplicate(true) if stage == 0 else neighbor.anchor.duplicate(true)
		var original: Dictionary = v.duplicate(true)
		var before: Dictionary = Work.snapshot(v, v.members[0].id)
		_expect(Simulation.Neighbor.work(neighbor, v, v.members[0]), "Neighbor did not handle its work.")
		compare("neighbor transport", f, before, original)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("SNAPSHOT_CHECK_FAILED: ", message)

func finish() -> void:
	print(JSON.stringify({"test": "village_work_snapshot", "passed": failures.is_empty(), "steps": steps, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
