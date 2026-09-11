extends RefCounted
## Fixed tribal shelters and own-species residents; no editor or wildlife rules.
const Home = preload("res://world/home_group/home_group_state.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
const KINDS: Array[String] = ["hut", "tent"]
const ANIMAL_SITES: Array[String] = ["pen", "laying_site"]
const BUILDS: Array[String] = ["hut", "tent", "pen", "laying_site"]
const COSTS: Dictionary = {"hut": {"wood": 6, "stone": 3}, "tent": {"wood": 3, "fiber": 2}, "pen": {"wood": 4, "fiber": 2}, "laying_site": {"wood": 4, "fiber": 2}}
const BEDS: Dictionary = {"hut": 2, "tent": 1}
const MAX_RESIDENTS: int = 6
const MAX_HOMES: int = 6
const GROW_SECONDS: float = 90.0

static func resident_id(data: Dictionary, index: int) -> String:
	return Ids.scoped("resident", data["id"], str(index))

static func site(data: Dictionary, kind: String, position: Variant, index: int) -> Dictionary:
	return {"id": Ids.scoped("pen" if kind in ANIMAL_SITES else "shelter", data["id"], str(index)), "kind": kind,
		"position": position.duplicate(), "entrance": Home.offset_place(position, Vector3(0, 0, 2))}

static func install(data: Dictionary) -> void:
	data["housing"] = {"schema": 1, "homes": [], "clock": 0.0}
	for i in range(int(data["huts"])):
		data["housing"]["homes"].append(site(data, "hut", data["sites"][i], i))
	for member: Dictionary in data["members"]:
		member.merge({"species_id": data["species_id"], "faction_id": data["faction_id"], "construction_id": ""}, true)
	if data["project"].get("kind", "") == "hut":
		# Old construction was already paid and worked on site. Preserve progress.
		var project: Dictionary = data["project"]
		project.merge(site(data, "hut", data["sites"][int(data["huts"])], int(data["huts"])))
		project["materials"] = {"wood": 0, "stone": 0}
		project["delivered_materials"] = COSTS["hut"].duplicate()

static func beds(data: Dictionary) -> int:
	var total: int = 0
	for shelter: Dictionary in data["housing"]["homes"]:
		total += int(BEDS[shelter["kind"]])
	return total

static func obstacles(data: Dictionary) -> Array:
	var result: Array = data.get("housing", {}).get("homes", []).duplicate()
	if data.get("project", {}).get("kind", "") in BUILDS and data["project"].has("entrance"):
		result.append(data["project"])
	return result

static func contains(shelter: Dictionary, position: Variant, margin: float = 0.55) -> bool:
	var offset: Vector3 = Home.local_offset(shelter["position"], Home.place(position))
	return absf(offset.x) < 1.05 + margin and absf(offset.z) < 1.05 + margin

static func pending(project: Dictionary) -> bool:
	for amount: int in project["materials"].values():
		if amount > 0:
			return true
	return false

static func supplied(project: Dictionary) -> bool:
	for kind: String in COSTS[project["kind"]]:
		if int(project["delivered_materials"][kind]) != int(COSTS[project["kind"]][kind]):
			return false
	return true

static func growth_blocker(data: Dictionary) -> String:
	var count: int = data["members"].size()
	if count >= MAX_RESIDENTS:
		return "Dein Stamm zählt sechs Bewohner."
	if beds(data) <= count:
		return "Dorfwachstum: Baue zusätzliche Schlafplätze."
	if int(data["garden"]) != 1 or not data["economy"]["stations"].has("well"):
		return "Dorfwachstum: Wurzelgarten und Brunnen werden benötigt."
	var reserve: int = (count + 1) * 2
	if int(data["stock"]["food"]) < reserve or int(data["stock"]["water"]) < reserve:
		return "Dorfwachstum: Halte je %d Nahrung und Wasser im Lager bereit." % reserve
	for member: Dictionary in data["members"]:
		if float(member["hunger"]) < 50.0 or float(member["hydration"]) < 50.0:
			return "Dorfwachstum: Alle Bewohner müssen mindestens halb satt und mit Wasser versorgt sein."
	return ""

static func tick(data: Dictionary, delta: float) -> bool:
	if delta <= 0 or not is_finite(delta):
		return false
	if not growth_blocker(data).is_empty():
		data["housing"]["clock"] = 0.0
		return false
	data["housing"]["clock"] = minf(GROW_SECONDS, float(data["housing"]["clock"]) + delta)
	return float(data["housing"]["clock"]) >= GROW_SECONDS

static func add_resident(data: Dictionary, position: Variant) -> Dictionary:
	if not growth_blocker(data).is_empty() or float(data["housing"]["clock"]) < GROW_SECONDS or not Economy.local_point(Home.place(position), data["anchor"]):
		return {}
	var index: int = data["members"].size()
	var member: Dictionary = {"id": resident_id(data, index), "name": "Dorfbewohner %d" % (index + 1),
		"species_id": data["species_id"], "faction_id": data["faction_id"], "position": Home.place(position),
		"destination": Home.place(position), "order": "wait", "stage": "outbound", "work": 0.0,
		"cargo": "", "hunger": 75.0, "hydration": 100.0, "profession": "none", "paused_order": "", "task": "", "blocked": false, "construction_id": ""}
	if int(data["schema"]) >= 5:
		member["care_pen_id"] = ""
	data["members"].append(member)
	data["stock"]["food"] -= 2
	data["stock"]["water"] -= 2
	data["housing"]["clock"] = 0.0
	return member

static func validate(data: Dictionary) -> String:
	var h: Variant = data.get("housing")
	if not h is Dictionary or h.get("schema") != 1 or not h.get("homes") is Array or h["homes"].size() > MAX_HOMES or not Economy.number(h.get("clock"), 0, GROW_SECONDS):
		return "Ungültiger Wohnraum oder Wachstumstakt."
	var huts: int = 0
	var all_sites: Array = h["homes"].duplicate()
	var project: Dictionary = data["project"]
	var building: bool = project.get("kind", "") in BUILDS
	if building and not Economy.text_id(project.get("id")):
		return "Der Baustelle fehlt ihre Kennung."
	if project.get("kind", "") in KINDS:
		if all_sites.size() >= MAX_HOMES or int(data["tools"]) != 1:
			return "Für diese Unterkunft fehlt Werkzeug oder Bauplatz."
		all_sites.append(project)
	for i in range(all_sites.size()):
		var shelter: Variant = all_sites[i]
		if not shelter is Dictionary or not shelter.get("kind") is String or shelter["kind"] not in KINDS or shelter.get("id") != Ids.scoped("shelter", data["id"], str(i)) or not Economy.local_point(shelter.get("position"), data["anchor"]) or not Economy.local_point(shelter.get("entrance"), data["anchor"]):
			return "Ungültige Unterkunft."
		if Home.distance(shelter["entrance"], Home.offset_place(shelter["position"], Vector3(0, 0, 2))) > 0.01:
			return "Ungültiger Gebäudeeingang."
		if i < h["homes"].size():
			huts += 1 if shelter["kind"] == "hut" else 0
	if int(data["huts"]) != huts or (not all_sites.is_empty() and int(data["tools"]) != 1):
		return "Wohnraum und Hüttenstand widersprechen sich."
	if data["members"].size() > 3 and beds(data) < data["members"].size():
		return "Für neue Bewohner fehlt Wohnraum."
	for member: Dictionary in data["members"]:
		if member.get("species_id") != data["species_id"] or member.get("faction_id") != data["faction_id"] or not member.get("construction_id") is String:
			return "Bewohner und Stamm gehören nicht zusammen."
		if member["construction_id"] != "" and (not building or member["construction_id"] != project["id"] or member["cargo"] not in COSTS[project["kind"]]):
			return "Baufracht ohne zugehörige Baustelle."
	if building:
		var costs: Dictionary = COSTS[project["kind"]]
		for field: String in ["materials", "delivered_materials"]:
			if not project.get(field) is Dictionary or project[field].size() != costs.size():
				return "Ungültige Baumaterialreservierung."
		for kind: String in costs:
			if not Economy.integer(project["materials"].get(kind), 0, costs[kind]) or not Economy.integer(project["delivered_materials"].get(kind), 0, costs[kind]):
				return "Ungültige Baumaterialmenge."
			var cargo: int = 0
			for member: Dictionary in data["members"]:
				cargo += 1 if member["construction_id"] == project["id"] and member["cargo"] == kind else 0
			if int(project["materials"][kind]) + int(project["delivered_materials"][kind]) + cargo != int(costs[kind]):
				return "Baumaterial fehlt oder wurde vervielfacht."
			var budget: int = (48 if kind in ["wood", "stone"] else 0) + int(data["economy"]["produced"][kind])
			if int(data["deposits"][kind]["remaining"]) + Economy.reserve(data, kind) + int(costs[kind]) > budget:
				return "Reserviertes Baumaterial wurde zusätzlich ins Lager gebucht."
		if float(project["progress"]) > 0 and not supplied(project):
			return "Baufortschritt ohne angelieferte Materialien."
	return ""
