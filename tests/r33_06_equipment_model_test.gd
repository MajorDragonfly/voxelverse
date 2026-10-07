extends SceneTree
const Equipment = preload("res://world/tribe/resident_equipment_model.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Work = preload("res://world/tribe/village_work.gd")
const Simulation = preload("res://world/tribe/village_simulation.gd")
const View = preload("res://ui/tribe/resident_details_view.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _request(data: Dictionary, resident: String, action: String, extra: Dictionary = {}) -> Dictionary:
	return {"village_id": data.id, "resident_id": resident, "action": action}.merged(extra)
func _harvest(data: Dictionary, resource: String, count: int) -> void:
	var resident: Dictionary = data.members[1]
	for index in range(count):
		resident.order = resource
		resident.stage = "outbound"
		resident.work = 0.0
		resident.position = data.deposits[resource].position.duplicate(true)
		var effects: Array = []
		Work.step(data, resident, 3.0, 1.0, effects)
		_expect(resident.cargo == resource, "Fixture did not actually extract " + resource)
		resident.position = data.anchor.duplicate(true)
		Work.step(data, resident, 0.1, 1.0, effects)
		_expect(resident.cargo == "", "Fixture did not actually deliver " + resource)
	resident.order = "wait"
func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.set_process(false)
	state.start_world_with_seed(15838)
	var body: Dictionary = state.get_current_body_record()
	body.home_group = Home.create(body.id, state.campaign.data.player_species_id, Vector3.ZERO)
	body.tribe = Tribe.create(body.home_group, state.campaign.data, {"position": [0,0,0]},
		{"wood": [-5,0,-4], "stone": [5,0,-4], "food": [-5,0,4], "huts": [[5,0,4],[8,0,0]]})
	var data: Dictionary = body.tribe
	var first: String = data.members[1].id
	var second: String = data.members[2].id
	data.members[2].position = data.anchor.duplicate(true)
	_expect(Equipment.items(data).is_empty() and Equipment.snapshot(data, first).tool.is_empty(), "New residents received free gear")
	var legacy: Dictionary = data.duplicate(true)
	legacy.erase(Equipment.FIELD)
	var before: Dictionary = legacy.duplicate(true)
	_expect(Tribe.upgrade(legacy), "Old empty equipment contract not migrated")
	legacy.erase(Equipment.FIELD)
	_expect(legacy == before, "Empty migration altered existing resources/residents/extra data")
	Equipment.install(legacy)
	_expect(not Tribe.upgrade(legacy), "Equipment migration not idempotent")
	var no_materials: Dictionary = data.duplicate(true)
	no_materials.tools = 1
	_expect(not Equipment.command(no_materials, _request(data,first,"craft",{"kind":"stone_tool"})).ok and Equipment.items(no_materials).is_empty(), "Materials-free craft succeeded")
	_harvest(data, "wood", 12)
	_harvest(data, "stone", 6)
	_expect(Equipment.preflight(data,_request(data,first,"craft",{"kind":"stone_tool"})) == "EQUIPMENT_NEEDS_TOOLS", "Village tool progression gate bypassed")
	# Prebuilt workstation fixture; the UI test separately builds the actual tool.
	data.tools = 1
	Tribe.Economy.complete_station(data, Tribe.Economy.station_project(data,"fiberbed",data.deposits.fiber.position))
	Tribe.Economy.tick(data, 96.0)
	_harvest(data,"fiber",5)
	var stock: Dictionary = data.stock.duplicate(true)
	var crafted: Dictionary = Equipment.command(data, _request(data,first,"craft",{"kind":"stone_tool"}))
	_expect(crafted.ok and data.stock.wood == stock.wood-3 and data.stock.stone == stock.stone-2, "Stone recipe did not spend exact live materials")
	var identity: String = crafted.get("item_id", "")
	_expect(Equipment.free_items(data,"tool").size() == 1 and Equipment.snapshot(data,first).tool.is_empty(), "Craft auto-equipped or duplicated village inventory")
	_expect(Equipment.command(data,_request(data,first,"equip",{"slot":"tool","item_id":identity})).ok, "First resident could not equip actual stock")
	stock = data.stock.duplicate(true)
	var after_first: Dictionary = data.duplicate(true)
	_expect(not Equipment.command(data,_request(data,second,"equip",{"slot":"tool","item_id":identity})).ok and data == after_first, "Competing resident stole/duplicated limited item")
	_expect(Equipment.owned(data, first,"tool").id == identity and Equipment.owned(data,second,"tool").is_empty(), "Ownership is not person-bound")
	var replacement: Dictionary = Equipment.command(data,_request(data,first,"craft",{"kind":"wooden_tool"}))
	_expect(replacement.ok, "Paid wooden-tool recipe failed")
	_expect(Equipment.command(data,_request(data,first,"equip",{"slot":"tool","item_id":replacement.item_id})).ok, "Swap failed")
	_expect(Equipment.items(data)[identity].owner_id == "" and Equipment.owned(data,first,"tool").id == replacement.item_id, "Swap discarded old ID or duplicated ownership")
	_expect(Equipment.command(data,_request(data,second,"equip",{"slot":"tool","item_id":identity})).ok, "Second resident could not claim returned old tool")
	var tunic: Dictionary = Equipment.command(data,_request(data,first,"craft",{"kind":"fiber_tunic"}))
	_expect(tunic.ok and data.stock.fiber == 0, "Clothing not manufactured with exact fiber costs")
	_expect(Equipment.command(data,_request(data,first,"equip",{"slot":"clothing","item_id":tunic.item_id})).ok, "Clothing did not become actual personal possession")
	stock = data.stock.duplicate(true)
	_expect(Equipment.command(data,_request(data,first,"return",{"slot":"tool"})).ok and Equipment.command(data,_request(data,first,"return",{"slot":"clothing"})).ok, "Returns failed")
	_expect(data.stock == stock and Equipment.free_items(data,"tool")[0].id == replacement.item_id and Equipment.items(data)[tunic.item_id].owner_id == "", "Return manufactured materials or changed the actual item")
	_expect(Equipment.validate(data).is_empty() and Tribe.validate(data,body,state.campaign.data).is_empty(), "Paid live ledger invalid: " + Equipment.validate(data))
	var invalid: Dictionary = data.duplicate(true)
	invalid.stock.wood += 3
	invalid.deposits.wood.remaining += 3
	_expect(not Equipment.validate(invalid).is_empty(), "Unpaid equipment was accepted by conservation check")
	invalid = data.duplicate(true)
	invalid[Equipment.FIELD].items[tunic.item_id].owner_id = "foreign-resident"
	_expect(not Equipment.validate(invalid).is_empty(), "Foreign owner accepted")
	invalid = data.duplicate(true)
	invalid[Equipment.FIELD].items[replacement.item_id].owner_id = second
	_expect(not Equipment.validate(invalid).is_empty(), "Two tools in one resident slot accepted")
	invalid = data.duplicate(true)
	invalid[Equipment.FIELD].schema = 2
	_expect(Equipment.unsupported(invalid) and not Equipment.install(invalid) and invalid[Equipment.FIELD].schema == 2, "Future equipment reset or accepted")
	invalid = data.duplicate(true)
	invalid[Equipment.FIELD].items[identity].recipe_revision = 2
	_expect(Equipment.unsupported(invalid), "Future recipe revision accepted")
	data.members[1].cargo = "wood"
	_expect(Equipment.preflight(data,_request(data,first,"equip",{"slot":"tool","item_id":replacement.item_id})) == "EQUIPMENT_AT_WAREHOUSE", "Carried material bypassed storage-local exchange")
	data.members[1].cargo = ""
	data.members[1].position = data.deposits.wood.position.duplicate(true)
	_expect(Equipment.preflight(data,_request(data,first,"equip",{"slot":"tool","item_id":replacement.item_id})) == "EQUIPMENT_AT_WAREHOUSE", "Distant resident teleported equipment")
	data.members[1].position = data.anchor.duplicate(true)
	var stale: Dictionary = _request(data,first,"return",{"slot":"tool"})
	stale.village_id = "old village"
	_expect(Equipment.preflight(data,stale) == "EQUIPMENT_STALE", "Stale village command accepted")
	# Construction has already paid into its own reserved materials; crafting
	# sees only what remains in stock. No subtraction of capacity-only escrow.
	var reserved: Dictionary = data.duplicate(true)
	for resource: String in ["wood","stone"]: reserved.stock[resource] = 0
	reserved.project = {"kind":"tent","materials":{"wood":3,"fiber":2},"delivered_materials":{"wood":0,"fiber":0}}
	var reserved_before: Dictionary = reserved.duplicate(true)
	_expect(not Equipment.command(reserved,_request(data,first,"craft",{"kind":"stone_tool"})).ok and reserved == reserved_before, "Construction reservation was spent again")
	reserved.project = {}
	reserved.economy.freight = Tribe.Economy.Freight.create()
	reserved.economy.freight.held.wood = 3
	_expect(not Equipment.command(reserved,_request(data,first,"craft",{"kind":"stone_tool"})).ok, "Held freight capacity became manufactured materials")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(data))
	_expect(Equipment.snapshot(restored,second) == Equipment.snapshot(data,second) and Equipment.validate(restored).is_empty(), "JSON restore changed IDs/ownership")
	var personal: Dictionary = Equipment.items(data).duplicate(true)
	var roads: Dictionary = {}
	for resident: Dictionary in data.members: roads[Simulation.key(resident.position)] = [data.anchor.duplicate(),resident.position.duplicate()]
	body.village_simulation = Simulation.create(body.id,0.0,roads,[],state.campaign.data.player_object_id)
	for tick in range(16): Simulation.advance(body,(tick+1)*0.25)
	_expect(Equipment.items(data) == personal and View.snapshot(data,[second]).personal_equipment.tool.id == identity, "Far simulation changed or lost personal inventory")
	body.village_simulation.owner = "near"
	before = data.duplicate(true)
	Simulation.advance(body,20.0)
	_expect(data == before, "Near handoff produced duplicated work or equipment")
	print(JSON.stringify({"test":"r33_06_equipment_model","checks":checks,"passed":failures.is_empty(),"failures":failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self,0 if failures.is_empty() else 1)
