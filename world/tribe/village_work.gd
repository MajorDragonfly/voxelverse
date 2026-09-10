extends RefCounted
## Shared arrived-work rules. State in, state plus committed effects out; no scene,
## physics, UI or autoload dependency. Physical/far arrival belongs to the caller.
const Model = preload("res://world/tribe/tribe_state.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
const Housing = preload("res://world/tribe/village_housing.gd")

static func effective_order(data: Dictionary, member: Dictionary) -> String:
	return str(data["project"].get("kind", "build")) if member["order"] == "build" else str(member["order"])

static func snapshot(data: Dictionary) -> Dictionary:
	# Share immutable places/IDs and the potentially long milk receipt ledger.
	# Copy only fields which a single arrived work step can mutate.
	var before: Dictionary = data.duplicate()
	for key in ["members", "stock", "deposits", "project", "housing", "husbandry"]:
		before[key] = data[key].duplicate(true)
	before.economy = data.economy.duplicate()
	before.economy.incoming = data.economy.incoming.duplicate(true)
	before.economy.stations = data.economy.stations.duplicate(true)
	return before

static func prepare(data: Dictionary, member: Dictionary, delta: float) -> void:
	member.hunger = maxf(0.0, float(member.hunger) - delta * 0.08)
	member.hydration = maxf(0.0, float(member.hydration) - delta * 0.06)
	var order: String = effective_order(data, member)
	if member.cargo != "" or order in ["wait", "feed", "drink"]: return
	if member.stage not in ["meal", "drink"]:
		if member.hydration < Economy.CARE_THRESHOLD and int(data.stock.water) > 0: member.stage = "drink"
		elif member.hunger < Economy.CARE_THRESHOLD and Economy.has_food(data): member.stage = "meal"
	elif (member.stage == "meal" and not Economy.has_food(data)) or (member.stage == "drink" and int(data.stock.water) == 0):
		member.stage = "outbound"

static func target(data: Dictionary, member: Dictionary) -> Variant:
	var order: String = effective_order(data, member)
	if order == "wait": return member.position
	if member.construction_id != "": return data.project.entrance
	if member.cargo != "" or member.stage in ["meal", "drink"]: return data.anchor
	if order == "milk":
		var incoming: Array = data.economy.incoming
		return incoming[0].position if not incoming.is_empty() and not Economy.at_target(data, member, "milk") else data.anchor
	if order in Economy.RESOURCES or order in ["supply", "provision"]:
		var kind: String = Economy.gather_kind(data, member)
		return data.deposits[kind].position if not kind.is_empty() and not Economy.at_target(data, member, kind) else data.anchor
	if order in Housing.BUILDS and data.project.get("kind") == order:
		return data.anchor if Housing.pending(data.project) else data.project.entrance
	if order == "garden": return data.deposits.food.position
	if order in Economy.STATIONS and not data.project.is_empty(): return data.project.position
	if order == "move": return member.destination
	return data.anchor

static func step(data: Dictionary, member: Dictionary, delta: float, rate: float, effects: Array) -> void:
	var order: String = effective_order(data, member)
	if order == "wait":
		return
	if member["construction_id"] != "":
		var project: Dictionary = data["project"]
		if Home.distance(member["position"], project["entrance"]) <= 3.0:
			project["delivered_materials"][member["cargo"]] += 1
			member["cargo"] = ""
			member["construction_id"] = ""
			member["stage"] = "outbound"
			effects.append({"kind": "changed"})
		return
	if member["care_pen_id"] != "":
		effects.append({"kind": "care_delivery"})
		return
	if member["cargo"] != "":
		var kind: String = member["cargo"]
		data["stock"][kind] += 1
		data["delivered"] += 1
		member["cargo"] = ""
		member["stage"] = "outbound"
		effects.append({"kind": "delivery", "data": {"resource": kind, "amount": 1, "member_id": member["id"], "sequence": data["delivered"], "tribe_id": data["id"]}})
		effects.append({"kind": "changed"})
		return
	if member["stage"] in ["meal", "drink"]:
		if member["stage"] == "meal":
			eat(data, member, effects)
		else:
			drink(data, member, effects)
		member["stage"] = "outbound"
		effects.append({"kind": "changed"})
		return
	if order == "tend":
		effects.append({"kind": "care_pickup"})
	elif order == "milk":
		var incoming: Array = data["economy"]["incoming"]
		if incoming.is_empty() or Economy.at_target(data, member, "milk"):
			return
		# A batch may change while another carrier is walking. Recheck arrival.
		if Home.distance(member["position"], incoming[0]["position"]) > 3.0:
			return
		incoming[0]["remaining"] -= 1
		if int(incoming[0]["remaining"]) == 0:
			incoming.pop_front()
		member["cargo"] = "milk"
		member["stage"] = "return"
		effects.append({"kind": "changed"})
	elif order in Economy.RESOURCES or order in ["supply", "provision"]:
		var kind: String = Economy.gather_kind(data, member)
		if kind.is_empty() or Economy.at_target(data, member, kind):
			return
		var deposit: Dictionary = data["deposits"][kind]
		if int(deposit["remaining"]) == 0:
			return # Keep ownership of work across empty sources and full stores.
		if Home.distance(member["position"], deposit["position"]) > 3.0:
			return
		member["work"] = minf(4.0, float(member["work"]) + delta * rate)
		if float(member["work"]) >= 3.0:
			deposit["remaining"] -= 1
			member["cargo"] = kind
			member["stage"] = "return"
			member["work"] = 0.0
			effects.append({"kind": "changed"})
	elif order in ["feed", "drink"]:
		if eat(data, member, effects) if order == "feed" else drink(data, member, effects):
			effects.append({"kind": "changed"})
		member["order"] = "wait"
	elif order in Model.COSTS or order in Economy.STATIONS:
		var project: Dictionary = data["project"]
		if project.is_empty() or project["kind"] != order:
			if member["order"] != "build":
				member["order"] = "wait"
			return
		if order in Housing.BUILDS:
			if Housing.pending(project):
				if Home.distance(member["position"], data["anchor"]) <= 3.0:
					for kind: String in project["materials"]:
						if int(project["materials"][kind]) > 0:
							project["materials"][kind] -= 1
							member["cargo"] = kind
							member["construction_id"] = project["id"]
							member["stage"] = "return"
							effects.append({"kind": "changed"})
							break
				return
			if not Housing.supplied(project) or Home.distance(member["position"], project["entrance"]) > 3.0:
				return
		project["progress"] = minf(20.0, float(project["progress"]) + delta * rate)
		if float(project["progress"]) >= float(Model.WORK.get(order, 15.0)):
			if order in Housing.KINDS:
				data["housing"]["homes"].append(Housing.site(data, order, project["position"], data["housing"]["homes"].size()))
				if order == "hut":
					data["huts"] += 1
			elif order == "pen":
				var p: Dictionary = Housing.site(data, order, project["position"], data["husbandry"]["pens"].size())
				p.merge({"animal_id": "", "food": 0.0, "water": 0.0})
				data["husbandry"]["pens"].append(p)
			elif order in Economy.STATIONS:
				data["economy"]["stations"][order] = {"id": Model.Ids.scoped("workplace", data["id"], order), "position": project["position"].duplicate()}
				data["deposits"][Economy.STATIONS[order]]["position"] = project["position"].duplicate()
			else:
				data[{"tool": "tools", "hut": "huts", "garden": "garden"}[order]] += 1
			var completed_id: String = str(project.get("id", Model.Ids.scoped("workplace", data["id"], order)))
			data["project"] = {}
			for worker: Dictionary in data["members"]:
				if worker["order"] == order:
					worker["order"] = Economy.JOB_ORDER[worker["profession"]]
					worker["stage"] = "return" if worker["cargo"] != "" else "outbound"
			effects.append({"kind": "construction", "data": {"kind": order, "tribe_id": data["id"], "huts": data["huts"], "building_id": completed_id}})
			effects.append({"kind": "changed"})
	elif order == "move":
		member["order"] = "wait"

static func eat(data: Dictionary, member: Dictionary, effects: Array) -> bool:
	if float(member["hunger"]) >= 95.0 or not Economy.has_food(data):
		return false
	var food: String = "milk" if int(data["stock"]["milk"]) > 0 else "food"
	data["stock"][food] -= 1
	if food == "milk":
		data["economy"]["milk_meals"] += 1
	data["meals"] += 1
	effects.append({"kind": "meal", "data": {"resource": food, "sequence": data["meals"], "tribe_id": data["id"], "member_id": member["id"]}})
	member["hunger"] = minf(100.0, float(member["hunger"]) + 25.0)
	return true

static func drink(data: Dictionary, member: Dictionary, effects: Array) -> bool:
	if float(member["hydration"]) >= 95.0 or int(data["stock"]["water"]) <= 0:
		return false
	data["stock"]["water"] -= 1
	data["economy"]["drinks"] += 1
	member["hydration"] = minf(100.0, float(member["hydration"]) + 30.0)
	effects.append({"kind": "drink", "data": {"sequence": data["economy"]["drinks"], "tribe_id": data["id"], "member_id": member["id"]}})
	return true
