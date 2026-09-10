extends SceneTree
const Work = preload("res://world/tribe/village_work.gd")
const Sim = preload("res://world/tribe/village_simulation.gd")
const Tribal = preload("res://core/progression/tribal_progression.gd")
const Campaign = preload("res://core/campaign/campaign_state.gd")
const Animal = preload("res://world/domestication/animal_state.gd")
const Home = Work.Home
const Model = Work.Model
const Economy = Work.Economy
const Housing = Work.Housing
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	for radial in [false, true]:
		_work_cases(radial)
		_build_cases(radial)
		_care_cases(radial)
	_simulation_speeds()
	_benchmark()
	print(JSON.stringify({"test": "village_work_snapshot", "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _fixture(radial: bool = false) -> Dictionary:
	var campaign := Campaign.new()
	campaign.reset("arch15-snapshot")
	var body: Dictionary = campaign.body_for_seed(15838, 1)
	var home: Dictionary = Home.create(body.id, campaign.data.player_species_id, Vector3.ZERO)
	if radial:
		body["surface_mode"] = Home.Cube.MODE
		home.schema = 2
		home.surface_mode = Home.Cube.MODE
		var address: Dictionary = Home.Cube.address(body.id, 2, 1.0, -1.0)
		address["radius"] = 6371000.0
		home.anchor = address
		for member: Dictionary in home.members: member.position = Home.offset_place(address, Home.vector(member.position))
	body["home_group"] = home
	var anchor: Variant = home.anchor
	var village: Dictionary = Model.create(home, campaign.data, {"position": anchor}, {
		"wood": Home.offset_place(anchor, Vector3(-5, 0, -4)), "stone": Home.offset_place(anchor, Vector3(5, 0, -4)),
		"food": Home.offset_place(anchor, Vector3(-5, 0, 4)), "huts": [Home.offset_place(anchor, Vector3(5, 0, 4)), Home.offset_place(anchor, Vector3(8, 0, 0))]})
	body["tribe"] = village
	return {"campaign": campaign.data, "body": body, "village": village, "optimized": Tribal.new(), "reference": Tribal.new()}

func _work_cases(radial: bool) -> void:
	for order: String in ["wait", "move", "wood", "stone", "food", "supply", "provision", "water", "fiber"]:
		var context: Dictionary = _fixture(radial)
		var data: Dictionary = context.village
		var member: Dictionary = data.members[1]
		member.order = order
		if order in ["water", "fiber"]: _station(data, "well" if order == "water" else "fiberbed", 8)
		var resource: String = Economy.gather_kind(data, member.duplicate())
		if data.deposits.has(resource): member.position = data.deposits[resource].position.duplicate(true)
		member.work = 2.75
		_step(context, "arrived " + order)
		if member.cargo != "":
			member.position = data.anchor.duplicate(true)
			_step(context, "delivered " + order)
	for resource: String in ["food", "milk", "water"]:
		var context: Dictionary = _fixture(radial)
		var data: Dictionary = context.village
		var member: Dictionary = data.members[1]
		if resource == "water":
			_station(data, "well", 2)
			data.deposits.water.remaining -= 2
			data.stock.water = 2
		elif resource == "milk":
			_milk(data, 2)
			member.order = "milk"
			member.position = data.economy.incoming[0].position.duplicate(true)
			_step(context, "batch partial pickup")
			member.position = data.anchor.duplicate(true)
			_step(context, "batch delivery")
			member.position = data.economy.incoming[0].position.duplicate(true)
			_step(context, "batch removal")
			member.position = data.anchor.duplicate(true)
			_step(context, "last batch delivery")
		else:
			data.deposits.food.remaining -= 2
			data.stock.food = 2
		member.order = "drink" if resource == "water" else "feed"
		member.position = data.anchor.duplicate(true)
		member.hunger = 40.0
		member.hydration = 40.0
		_step(context, "consume " + resource)
	# Automatic need overrides still preserve the original gathering task.
	var context: Dictionary = _fixture(radial)
	context.village.deposits.food.remaining -= 1
	context.village.stock.food = 1
	context.village.members[1].merge({"order": "wood", "stage": "meal", "hunger": 40.0}, true)
	_step(context, "automatic meal")
	# Two real carriers retain the bounded campaign-wide reward and replay guards.
	context = _fixture(radial)
	for index in range(8):
		var member: Dictionary = context.village.members[1 + index % 2]
		member.order = "wood"
		member.work = 2.75
		member.position = context.village.deposits.wood.position.duplicate(true)
		_step(context, "cooperative pickup", 1 + index % 2)
		member.position = context.village.anchor.duplicate(true)
		_step(context, "cooperative delivery", 1 + index % 2)
	_expect(context.optimized.data.awards.has("shared_stock"), "Real cooperative deliveries earned no milestone.")

func _build_cases(radial: bool) -> void:
	for kind: String in ["tool", "garden", "hut", "tent", "pen", "well", "forester", "quarry", "fiberbed"]:
		var context: Dictionary = _fixture(radial)
		var data: Dictionary = context.village
		data.tools = 0 if kind == "tool" else 1
		var costs: Dictionary = Model.COSTS.get(kind, Economy.COSTS.get(kind, {}))
		for resource: String in costs:
			if resource == "fiber": _station(data, "fiberbed", int(costs[resource]))
			data.deposits[resource].remaining -= int(costs[resource])
		var position: Variant = Home.offset_place(data.anchor, Vector3(6, 0, 6))
		data.project = {"kind": kind, "progress": 0.0, "position": position}
		if kind in Housing.BUILDS:
			data.project = Housing.site(data, kind, position, 0)
			data.project.merge({"progress": 0.0, "materials": costs.duplicate(), "delivered_materials": {}})
			for resource: String in costs: data.project.delivered_materials[resource] = 0
		for member: Dictionary in data.members:
			member.order = kind
			member.position = (data.deposits.food.position if kind == "garden" else position if kind in Economy.STATIONS else data.anchor).duplicate(true)
		if kind in Housing.BUILDS:
			while Housing.pending(data.project):
				_step(context, kind + " construction pickup")
				data.members[1].position = data.project.entrance.duplicate(true)
				_step(context, kind + " construction delivery")
				data.members[1].position = data.anchor.duplicate(true)
			data.members[1].position = data.project.entrance.duplicate(true)
		# One resident contributes; another completes and resets every worker.
		_step(context, kind + " progress", 1)
		data.project.progress = float(Model.WORK.get(kind, 15.0)) - 0.25
		data.members[2].position = data.members[1].position.duplicate(true)
		_step(context, kind + " completion", 2, true)
		_expect(data.project.is_empty(), "Construction did not finish: " + kind)
		if kind in ["tool", "hut", "garden"]:
			_expect(context.optimized.data.awards.has("shared_" + kind), "Shared construction lost its contributors: " + kind)

func _care_cases(radial: bool) -> void:
	var context: Dictionary = _fixture(radial)
	var data: Dictionary = context.village
	_station(data, "well", 8)
	data.deposits.water.remaining -= 8
	data.stock.water = 8
	data.deposits.food.remaining -= 4
	data.stock.food = 4
	var pen: Dictionary = Housing.site(data, "pen", Home.offset_place(data.anchor, Vector3(0, 0, 7)), 0)
	pen.merge({"animal_id": "", "food": 0.0, "water": 0.0})
	data.husbandry.pens.append(pen)
	var animal: Dictionary = Animal.individual("arch15-animal", "arch15-milk-species", data.body_id, {"id": "arch15-design", "revision": 1}, Vector3.ZERO)
	animal.merge({"position": pen.position.duplicate(true), "owner_faction_id": data.faction_id, "status": "tamed", "order": "wait"}, true)
	_expect(Sim.H.bind(data, pen, animal, {"milk_yield": 2.0, "milk_interval": 300.0, "water_need": 4.0}).is_empty(), "Care fixture could not bind.")
	context.body["domesticated_animals"] = {"registry": {"animals": {animal.object_id: animal}}}
	context.body["village_simulation"] = Sim.create(data.body_id, 0, {Sim.key(pen.entrance): [data.anchor, pen.entrance]}, [animal.object_id], data.members[0].id)
	data.members[1].order = "tend"
	data.members[1].position = data.anchor.duplicate(true)
	_step(context, "care pickup")
	data.members[1].position = pen.entrance.duplicate(true)
	_step(context, "care delivery")
	data.members[1].position = data.anchor.duplicate(true)
	_step(context, "care pickup before animal loss")
	animal.status = "lost"
	_step(context, "care return after animal loss")

func _step(context: Dictionary, label: String, index: int = 1, far_build: bool = false) -> void:
	var data: Dictionary = context.village
	var member: Dictionary = data.members[index]
	var frozen: Dictionary = data.duplicate(true)
	var before: Dictionary = Work.snapshot(data, member)
	_expect(data == frozen and before == frozen, label + ": capture changed input or omitted data")
	_expect(Model.validate(before, context.body, context.campaign).is_empty(), label + ": invalid starting fixture: " + Model.validate(before, context.body, context.campaign))
	var effects: Array = []
	Work.step(data, member, 0.25, 1.0, effects)
	for effect: Dictionary in effects:
		if effect.kind == "care_pickup": Sim._pickup(context.body, member)
		elif effect.kind == "care_delivery": Sim._deliver(context.body, member)
		elif far_build and effect.kind == "construction" and effect.data.kind in Housing.BUILDS:
			# The far adapter invalidates ALL worker routes on building completion.
			for worker: Dictionary in data.members: worker.blocked = true
	_expect(before == frozen, label + ": work changed its saved before-image")
	_expect(Model.validate(data, context.body, context.campaign).is_empty(), label + ": work broke the village: " + Model.validate(data, context.body, context.campaign))
	var actual: Dictionary = context.optimized.observe(before, data, member.id, context.body, context.campaign, 1)
	var expected: Dictionary = context.reference.observe(frozen, data, member.id, context.body, context.campaign, 1)
	_expect(actual == expected and context.optimized.export_state() == context.reference.export_state(), label + ": bounded progress differs from full-copy reference")
	var once: Dictionary = context.optimized.export_state()
	context.optimized.observe(before, data, member.id, context.body, context.campaign, 1)
	_expect(context.optimized.export_state() == once, label + ": repeated observation paid twice")

func _station(data: Dictionary, kind: String, produced: int) -> void:
	data.tools = 1
	var resource: String = Economy.STATIONS[kind]
	data.economy.stations[kind] = {"id": Model.Ids.scoped("workplace", data.id, kind), "position": data.deposits[resource].position.duplicate(true)}
	data.economy.produced[resource] = produced
	data.deposits[resource].remaining = produced

func _simulation_speeds() -> void:
	var state: Node = root.get_node("GameState")
	state.set_process(false)
	root.get_node("SaveGameService").autosave_enabled = false
	var baseline: Dictionary = {}
	var progress: Dictionary = {}
	for speed: float in [0.0, 1.0, 2.0, 4.0]:
		var context: Dictionary = _fixture(true)
		var data: Dictionary = context.village
		data.members[1].order = "wood"
		data.members[2].merge({"order": "stone", "cargo": "stone", "stage": "return", "blocked": true}, true)
		data.deposits.stone.remaining -= 1
		var roads: Dictionary = {}
		for point in [data.anchor, data.deposits.wood.position, data.members[1].position]:
			roads[Sim.key(point)] = [data.anchor.duplicate(true), point.duplicate(true)]
		context.body["village_simulation"] = Sim.create(data.body_id, 0, roads, [], data.members[0].id)
		var frozen: Dictionary = data.duplicate(true)
		var observer: Callable = func(before: Dictionary, actor_id: String, body: Dictionary, _delta: float) -> void:
			if not actor_id.is_empty(): context.optimized.observe(before, body.tribe, actor_id, body, context.campaign, 1)
		_expect(state.set_simulation_speed(speed), "Supported simulation speed was rejected.")
		var clock: float = 0.0
		for frame in range(240 if speed == 0 else int(240 / speed)):
			clock += state.simulation_delta(0.25)
			# Catch up in the existing fixed quarter-second work slices.
			while Sim.advance(context.body, clock, 1.0, observer): pass
		if speed == 0:
			_expect(data == frozen and context.body.village_simulation.cursor == 0, "Pause advanced work or cargo.")
			continue
		_expect(data.stock.wood > 0 and data.members[2].cargo == "stone" and data.stock.stone == 0, "Speed changed arrival/blocked cargo rules.")
		_expect(Model.validate(data, context.body, context.campaign).is_empty(), "Speed probe broke conservation.")
		if speed == 1:
			baseline = data.duplicate(true)
			progress = context.optimized.export_state()
		else:
			_expect(data == baseline and context.optimized.export_state() == progress, "Equal campaign time at 1/2/4x changed work or rewards.")
	state.set_simulation_speed(1.0)

func _milk(data: Dictionary, amount: int, id: String = "arch15-source") -> void:
	_expect(Economy.receive_milk(data, {"schema": 1, "source_id": id, "sequence": 1, "amount": amount, "body_id": data.body_id, "faction_id": data.faction_id, "position": Home.offset_place(data.anchor, Vector3(0, 0, -7))}).is_empty(), "Milk fixture rejected.")

func _benchmark() -> void:
	var context: Dictionary = _fixture(true)
	var data: Dictionary = context.village
	data.tools = 1
	for index in range(3): data.housing.homes.append(Housing.site(data, "hut", Home.offset_place(data.anchor, Vector3(index * 5, 0, 6)), index))
	data.huts = 3
	for index in range(3, 6):
		var member: Dictionary = data.members[0].duplicate(true)
		member.id = Housing.resident_id(data, index)
		data.members.append(member)
	var pen: Dictionary = Housing.site(data, "pen", Home.offset_place(data.anchor, Vector3(-6, 0, -6)), 0)
	pen.merge({"animal_id": "", "food": 0.0, "water": 0.0})
	data.husbandry.pens.append(pen)
	for index in range(32):
		var animal: Dictionary = Animal.individual("past-animal-" + str(index), "milk-species", data.body_id, {"id": "design", "revision": 1}, Vector3.ZERO)
		_expect(Sim.H.bind(data, pen, animal, {"milk_yield": 2.0, "milk_interval": 300.0, "water_need": 4.0}).is_empty(), "Benchmark animal binding failed.")
		Sim.H.unbind(data, pen)
	for index in range(64):
		_milk(data, 1, "old-source-" + str(index))
		if index < 16:
			data.economy.incoming.clear()
			data.economy.milk_meals += 1
			data.meals += 1
	data.members[1].order = "wood"
	_expect(Model.validate(data, context.body, context.campaign).is_empty(), "Benchmark exceeds real village limits.")
	var original: Dictionary = data.duplicate(true)
	var old: Dictionary = _legacy_snapshot(data)
	var targeted: Dictionary = Work.snapshot(data, data.members[1])
	var old_count: int = _copied_containers(old, data)
	var new_count: int = _copied_containers(targeted, data)
	_expect(old == targeted and new_count < old_count / 4, "Targeted observation still copies unrelated history.")
	var old_times: Array = []
	var new_times: Array = []
	for sample in range(5):
		var start: int = Time.get_ticks_usec()
		for iteration in range(1000): _legacy_snapshot(data)
		old_times.append(float(Time.get_ticks_usec() - start) / 1000.0)
		start = Time.get_ticks_usec()
		for iteration in range(1000): Work.snapshot(data, data.members[1])
		new_times.append(float(Time.get_ticks_usec() - start) / 1000.0)
	_expect(data == original, "Benchmark changed live work.")
	print(JSON.stringify({"benchmark": "arch15_arrived_work_snapshot", "kind": "headless_cpu_microbenchmark", "residents": 6, "production_records": 32, "receipts": 64, "pending_batches": 48, "iterations_per_sample": 1000, "old_copied_containers": old_count, "new_copied_containers": new_count, "old_us_per_capture": old_times, "new_us_per_capture": new_times}))

func _legacy_snapshot(data: Dictionary) -> Dictionary:
	# Exact pre-ARCH-15 algorithm from ea900f2, kept only as a measurement baseline.
	var before: Dictionary = data.duplicate()
	for key in ["members", "stock", "deposits", "project", "housing", "husbandry"]: before[key] = data[key].duplicate(true)
	before.economy = data.economy.duplicate()
	before.economy.incoming = data.economy.incoming.duplicate(true)
	before.economy.stations = data.economy.stations.duplicate(true)
	return before

func _copied_containers(value: Variant, source: Variant) -> int:
	if not (value is Array or value is Dictionary) or is_same(value, source): return 0
	var count: int = 1
	if value is Array:
		for index in range(value.size()): count += _copied_containers(value[index], source[index])
	else:
		for key in value: count += _copied_containers(value[key], source[key])
	return count

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
