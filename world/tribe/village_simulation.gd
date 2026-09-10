extends RefCounted
## One persisted owner and simulation cursor per village. Far work follows the
## last physically verified paths; absence of a route never produces arrival.
const Work = preload("res://world/tribe/village_work.gd")
const Model = preload("res://world/tribe/tribe_state.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
const H = preload("res://world/tribe/village_husbandry.gd")
const Neighbor = preload("res://world/tribe/neighbors/neighbor_state.gd")
# 6 residents, 48 pending batches, 32 husbandry records, deposits, pens,
# project and two neighbor residents fit below 128 certified endpoints.
const MAX_ROADS: int = 128
const MAX_POINTS: int = 256
const STEP: float = 0.25

static func key(place: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(place))).sha256_text()

static func create(body_id: String, cursor: float, roads: Dictionary, attending: Array, traveler: String) -> Dictionary:
	return {"schema": 1, "body_id": body_id, "owner": "far", "cursor": cursor,
		"roads": roads, "attending": attending, "legs": {}, "traveler": traveler}

static func validate(value: Variant, body: Dictionary, clock: float) -> String:
	if not value is Dictionary or value.get("schema") != 1 or value.get("body_id") != body.id or value.get("owner") not in ["near", "far"]: return "Ungültiger Simulationsbesitzer."
	if not Economy.number(value.get("cursor"), 0, clock + 0.000001) or not value.get("roads") is Dictionary or value.roads.size() > MAX_ROADS or not value.get("legs") is Dictionary or value.legs.size() > 8 or not value.get("attending") is Array or value.attending.size() > H.MAX_PENS or not value.get("traveler") is String: return "Ungültiger Simulationscursor oder Arbeitsvorrat."
	var village: Dictionary = body.get("tribe", {})
	if village.is_empty(): return "Fernsimulation ohne eigenes Dorf."
	var members: Array = []
	for member: Dictionary in village.members: members.append(member.id)
	if value.traveler not in members: return "Abwesender Spieler gehört nicht zum Dorf."
	for member: Dictionary in body.get("tribal_neighbor", {}).get("members", []): members.append(member.id)
	for id in value.attending:
		if not id is String or not village.husbandry.records.has(id): return "Unbekanntes fernversorgtes Tier."
	for id in value.legs:
		if id not in members: return "Transport gehört nicht zum Dorf."
	for paths: Dictionary in [value.roads, value.legs]:
		for path: Variant in paths.values():
			if not path is Array or path.size() > MAX_POINTS * 3: return "Fernweg überschreitet das Budget."
			for point: Variant in path:
				if not Economy.local_point(point, village.anchor): return "Fernweg verlässt seinen lokalen Dorfbereich."
	return ""

static func path_to(data: Dictionary, simulation: Dictionary, from: Variant, to: Variant) -> Array:
	if Home.distance(from, to) < 0.05: return []
	var first: Array = simulation.roads.get(key(from), [])
	var last: Array = simulation.roads.get(key(to), [])
	if first.is_empty() or last.is_empty(): return []
	var path: Array = first.duplicate(true)
	path.reverse()
	path.append_array(last)
	return path

static func advance(body: Dictionary, clock: float, cooperation: float = 1.0, observer: Callable = Callable()) -> bool:
	var simulation: Dictionary = body.get("village_simulation", {})
	if simulation.is_empty() or simulation.owner != "far": return false
	var delta: float = minf(STEP, clock - float(simulation.cursor))
	if delta < 0.000001: return false
	var data: Dictionary = body.tribe
	var neighbor: Dictionary = body.get("tribal_neighbor", {})
	Model.grow(data, delta)
	Economy.tick(data, delta)
	for member: Dictionary in data.members:
		# The traveling player cannot simultaneously work on another planet.
		if member.id == simulation.traveler: continue
		Work.prepare(data, member, delta)
		if member.order == "wait" or member.blocked: continue
		var target: Variant = Work.target(data, member)
		if member.care_pen_id != "":
			var pen: Dictionary = H.pen(data, member.care_pen_id)
			target = pen.entrance if _attending(body, pen) else data.anchor
		if not neighbor.is_empty():
			var delivery_target: Variant = Neighbor.target(neighbor, data, member)
			if delivery_target is Dictionary or (delivery_target is Vector3 and delivery_target.is_finite()): target = Home.place(delivery_target)
		if not move_member(data, simulation, member, target, delta * 3.8 * (0.6 if minf(member.hunger, member.hydration) < 20.0 else 1.0)): continue
		var before: Dictionary = Work.snapshot(data) if observer.is_valid() else {}
		var effects: Array = []
		var aid_work: bool = not neighbor.is_empty() and Neighbor.work(neighbor, data, member)
		if not aid_work:
			Work.step(data, member, delta, cooperation * (0.5 if minf(member.hunger, member.hydration) < 20.0 else 1.0), effects)
		for effect: Dictionary in effects:
			if effect.kind == "care_pickup": _pickup(body, member)
			elif effect.kind == "care_delivery": _deliver(body, member)
			elif effect.kind == "construction" and effect.data.kind in Work.Housing.BUILDS:
				# New obstacles need physical recertification; existing cargo stays.
				simulation.roads.clear()
				simulation.legs.clear()
				for worker: Dictionary in data.members: worker.blocked = true
		# Completed effects and construction contribution feed the same bounded
		# ledger. Gathering timers alone carry no new progression evidence.
		if observer.is_valid() and (aid_work or not effects.is_empty() or before.project.get("progress", 0) != data.project.get("progress", 0)):
			observer.call(before, str(member.id), body, delta)
	if not neighbor.is_empty() and neighbor.aid.status == "building":
		var before: Dictionary = neighbor.duplicate(true)
		for resident: Dictionary in neighbor.members:
			if not resident.blocked and move_member(data, simulation, resident, resident.workplace, delta * 3.8): Neighbor.build(neighbor, resident.id, delta)
		if observer.is_valid() and before.aid.status != neighbor.aid.status: observer.call(before, str(neighbor.id), body, delta)
	for pen: Dictionary in data.husbandry.pens:
		if _attending(body, pen): H.advance(data, pen, delta)
	for id: String in data.husbandry.records:
		var record: Dictionary = data.husbandry.records[id]
		if record.pending_milk > 0 and simulation.roads.has(key(record.pickup)): H.offer(data, id)
	simulation.cursor = minf(clock, float(simulation.cursor) + delta)
	if observer.is_valid(): observer.call({}, "", body, delta)
	return true

static func move_member(data: Dictionary, simulation: Dictionary, member: Dictionary, target: Variant, movement: float) -> bool:
	var leg: Array = simulation.legs.get(member.id, [])
	if not leg.is_empty() and Home.distance(leg.back(), target) > 0.05:
		var extension: Array = path_to(data, simulation, leg.back(), target)
		if extension.is_empty() or leg.size() + extension.size() > MAX_POINTS * 3:
			member.blocked = true
			return false
		leg.append_array(extension)
	if leg.is_empty() and Home.distance(member.position, target) > 0.05:
		leg = path_to(data, simulation, member.position, target)
		if leg.is_empty():
			member.blocked = true
			return false
	while not leg.is_empty() and movement > 0:
		var distance: float = Home.distance(member.position, leg[0])
		if distance <= movement:
			member.position = leg.pop_front().duplicate(true)
			movement -= distance
		else:
			member.position = _interpolate(member.position, leg[0], movement / distance)
			movement = 0
	simulation.legs[member.id] = leg
	return leg.is_empty()

static func _attending(body: Dictionary, pen: Dictionary) -> bool:
	if pen.is_empty() or pen.animal_id not in body.village_simulation.attending: return false
	var animal: Dictionary = body.get("domesticated_animals", {}).get("registry", {}).get("animals", {}).get(pen.animal_id, {})
	var record: Dictionary = body.tribe.husbandry.records.get(pen.animal_id, {})
	return not animal.is_empty() and animal.get("status") == "tamed" and animal.get("owner_faction_id") == body.tribe.faction_id and animal.get("order") in ["home", "wait"] and animal.get("species_id") == record.get("species_id") and animal.get("design_ref") == record.get("design_ref") and Home.distance(animal.position, pen.position) <= 1.8 and body.village_simulation.roads.has(key(pen.entrance))

static func _pickup(body: Dictionary, member: Dictionary) -> void:
	var data: Dictionary = body.tribe
	for pen: Dictionary in data.husbandry.pens:
		if not _attending(body, pen): continue
		var kind: String = H.needed(data, pen)
		if kind.is_empty(): continue
		data.stock[kind] -= 1
		data.husbandry.withdrawn[kind] += 1
		member.cargo = kind
		member.care_pen_id = pen.id
		member.stage = "return"
		return

static func _deliver(body: Dictionary, member: Dictionary) -> void:
	var data: Dictionary = body.tribe
	var pen: Dictionary = H.pen(data, member.care_pen_id)
	var kind: String = member.cargo
	if _attending(body, pen):
		pen[kind] += 1.0
		data.husbandry.delivered[kind] += 1
	else:
		data.stock[kind] += 1
		data.husbandry.returned[kind] += 1
	member.cargo = ""
	member.care_pen_id = ""
	member.stage = "outbound"

static func _interpolate(a: Variant, b: Variant, weight: float) -> Variant:
	if a is Array: return Home.vector_array(Home.vector(a).lerp(Home.vector(b), weight))
	var first: Array = Home.Cube.cartesian(a, a.radius)
	var last: Array = Home.Cube.cartesian(b, b.radius)
	var p: Array = [lerpf(first[0], last[0], weight), lerpf(first[1], last[1], weight), lerpf(first[2], last[2], weight)]
	var result: Dictionary = Home.Cube.from_cartesian(a.body_id, p, a.radius)
	result.radius = a.radius
	return result
