extends SceneTree
const View = preload("res://ui/tribe/resident_details_view.gd")
const Model = preload("res://world/tribe/tribe_state.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Work = preload("res://world/tribe/village_work.gd")
const Simulation = preload("res://world/tribe/village_simulation.gd")
class HealthActor:
	extends Node
	var member_id: String
	var maximum_health: float = 200
	var current_health: float = 72
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.set_process(false)
	state.start_world_with_seed(15838)
	var body: Dictionary = state.get_current_body_record()
	body.home_group = Home.create(body.id, state.campaign.data.player_species_id, Vector3.ZERO)
	body.tribe = Model.create(body.home_group, state.campaign.data, {"position": [0,0,0]},
		{"wood": [-5,0,-4], "stone": [5,0,-4], "food": [-5,0,4], "huts": [[5,0,4],[8,0,0]]})
	var data: Dictionary = body.tribe
	var member: Dictionary = data.members[1]
	var selected: Array = [member.id]
	var actor := HealthActor.new()
	actor.member_id = member.id
	var actors: Dictionary = {member.id: actor}
	var before: String = JSON.stringify(data)
	var first: Dictionary = View.snapshot(data, selected, actors)
	_expect(first.id == member.id and first.name == member.name and first.health_percent == 36.0, "Identity or actor health disagrees with canonical member")
	_expect(JSON.stringify(data) == before, "Reading details mutated village")
	_expect(View.snapshot(data, []).is_empty() and View.snapshot(data, [member.id, data.members[0].id]).is_empty(), "Empty/multiple selection opens a single detail")
	_expect(View.snapshot(data, ["enemy"]).is_empty(), "Unknown/enemy identity gets a detail")
	var duplicate: Dictionary = data.duplicate(true)
	duplicate.members.append(member.duplicate(true))
	_expect(View.snapshot(duplicate, selected).is_empty(), "Duplicate canonical identity gets a detail")
	member.name = "TRIBE_BOOK {count}"
	member.order = "wood"
	member.position = data.deposits.wood.position.duplicate()
	var effects: Array = []
	Work.prepare(data, member, 1.0)
	Work.step(data, member, 3.0, 1.0, effects)
	var carrying: Dictionary = View.snapshot(data, selected, actors)
	_expect(carrying.name == "TRIBE_BOOK {count}" and carrying.order == "wood" and carrying.cargo == "wood", "Actual arrived work is not reflected in details")
	_expect(carrying.food == member.hunger and first.food != carrying.food and first.cargo == "", "Snapshot aliased later needs/cargo")
	member.position = data.anchor.duplicate()
	Work.step(data, member, 0.1, 1.0, effects)
	_expect(View.snapshot(data, selected).cargo == "" and data.stock.wood == 1, "Actual delivery leaves stale cargo")
	member.hydration = 30.0
	data.stock.water = 1
	var thirsty: Dictionary = View.snapshot(data, selected)
	Work.drink(data, member, effects)
	_expect(View.snapshot(data, selected).water > thirsty.water and data.economy.drinks == 1 and data.stock.water == 0, "Actual consumption leaves stale needs")
	data.tools = 1
	member.equipment = {"tool": "not_a_contract"}
	_expect(View.snapshot(data, selected).personal_equipment.tool.is_empty() and View.snapshot(data, selected).personal_equipment.clothing.is_empty(), "Village tools or unvalidated extra keys fabricated ownership")
	member.erase("equipment")
	var site: Dictionary = Model.Economy.station_project(data, "forester", data.deposits.wood.position)
	Model.Economy.complete_station(data, site)
	member.workplace_id = data.economy.stations.forester.id
	_expect(View.snapshot(data, selected).workplace_kind == "forester", "Assigned workplace did not resolve through exact site ID")
	member.erase("workplace_id")
	_expect(View.snapshot(data, selected).workplace_key == "", "Removed workplace stayed cached")
	actor.current_health = 20
	_expect(View.snapshot(data, selected, actors).health_percent == 10, "Live health changed but detail stayed stale")
	actor.member_id = "enemy"
	_expect(View.snapshot(data, selected, actors).health_percent == null, "Mismatched actor leaked another resident's health")
	actor.free()
	_expect(View.snapshot(data, selected, actors).health_percent == null, "Freed actor was dereferenced or fabricated health")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(data))
	var stable: Dictionary = View.snapshot(data, selected)
	_expect(View.snapshot(restored, selected) == stable, "Restored JSON retained stale member references or changed identity/values")
	var roads: Dictionary = {}
	for place: Variant in [data.anchor, data.deposits.wood.position, data.members[0].position, member.position, data.members[2].position]:
		roads[Simulation.key(place)] = [data.anchor.duplicate(), place.duplicate()]
	body.village_simulation = Simulation.create(body.id, 0.0, roads, [], state.campaign.data.player_object_id)
	member.order = "wood"
	var pre_far: Dictionary = View.snapshot(data, selected)
	for tick in range(160): Simulation.advance(body, (tick + 1) * 0.25)
	var far: Dictionary = View.snapshot(body.tribe, selected)
	_expect(far.id == pre_far.id and far.food < pre_far.food and far.water < pre_far.water and data.delivered > 1, "Authoritative far work did not feed fresh resident details")
	_expect(far.health_percent == null, "Unloaded health became fake full health")
	body.village_simulation.owner = "near"
	before = JSON.stringify(data)
	Simulation.advance(body, 100.0)
	_expect(JSON.stringify(data) == before, "Far simulation continued after near handoff")
	print(JSON.stringify({"test": "r32_19_resident_model", "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
