extends RefCounted
## D3 owns feed credits and production, never a second animal/species register.
const E = preload("res://world/tribe/village_economy.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const MAX_PENS: int = 2
const MAX_RECORDS: int = 32
const CAPACITY: Dictionary = {"food": 4.0, "water": 8.0}
const TARGET: Dictionary = {"food": 2.0, "water": 4.0}
const CARE_SECONDS: float = 300.0

static func install(data: Dictionary) -> void:
	data["husbandry"] = {"schema": 1, "pens": [], "records": {},
		"withdrawn": {"food": 0, "water": 0}, "returned": {"food": 0, "water": 0},
		"delivered": {"food": 0, "water": 0}, "consumed": {"food": 0.0, "water": 0.0}}
	for member: Dictionary in data["members"]:
		member["care_pen_id"] = ""

static func pen(data: Dictionary, identity: String) -> Dictionary:
	for p: Dictionary in data["husbandry"]["pens"]:
		if p["id"] == identity:
			return p
	return {}

static func carried(data: Dictionary, identity: String, kind: String) -> int:
	var total: int = 0
	for member: Dictionary in data["members"]:
		total += 1 if member.get("care_pen_id", "") == identity and member["cargo"] == kind else 0
	return total

static func needed(data: Dictionary, p: Dictionary) -> String:
	for kind: String in ["water", "food"]:
		var amount: float = float(p[kind]) + carried(data, p["id"], kind)
		if amount < float(TARGET[kind]) - 0.000001 and amount + 1 <= float(CAPACITY[kind]) and int(data["stock"][kind]) > 0:
			return kind
	return ""

static func bind(data: Dictionary, p: Dictionary, animal: Dictionary, recipe: Dictionary) -> String:
	var identity: String = animal["object_id"]
	var records: Dictionary = data["husbandry"]["records"]
	if p["animal_id"] == identity:
		return ""
	if p["animal_id"] != "":
		return "Dieser Tierplatz ist bereits belegt."
	for other: Dictionary in data["husbandry"]["pens"]:
		if other["animal_id"] == identity:
			return "Dieses Tier hat bereits einen Tierplatz."
	if records.has(identity):
		if not matches(records[identity], animal, recipe):
			return "Art oder Körper des gespeicherten Milchtieres hat sich geändert."
	else:
		if records.size() >= MAX_RECORDS or data["economy"]["receipts"].has(identity) or data["economy"]["receipts"].size() >= 64:
			return "Für dieses Tier ist kein freier Produktionsnachweis verfügbar."
		records[identity] = {"species_id": animal["species_id"], "design_ref": animal["design_ref"].duplicate(),
			"recipe": recipe.duplicate(), "clock": 0.0, "cycles": 0, "produced": 0, "pending_milk": 0,
			"handed_over": 0, "sequence": 0, "pickup": p["entrance"].duplicate()}
	p["animal_id"] = identity
	return ""

static func matches(record: Dictionary, animal: Dictionary, recipe: Dictionary) -> bool:
	if record["species_id"] != animal["species_id"] or record["design_ref"]["id"] != animal["design_ref"]["id"] or int(record["design_ref"]["revision"]) != int(animal["design_ref"]["revision"]):
		return false
	for field: String in ["milk_yield", "milk_interval", "water_need"]:
		if float(record["recipe"][field]) != float(recipe[field]):
			return false
	return true

static func unbind(data: Dictionary, p: Dictionary) -> String:
	if p["animal_id"] == "":
		return ""
	var record: Dictionary = data["husbandry"]["records"][p["animal_id"]]
	if int(record["pending_milk"]) > 0:
		return "Hole zuerst die fertige Milch ab und schaffe Lagerplatz."
	for member: Dictionary in data["members"]:
		if member["care_pen_id"] == p["id"]:
			return "Warte, bis unterwegs befindliches Tierfutter und Wasser abgeliefert sind."
	p["animal_id"] = ""
	return ""

static func advance(data: Dictionary, p: Dictionary, delta: float) -> bool:
	# Called only after live D1/D2 and physical pen attendance were checked.
	if not E.number(delta, 0.000001, 0.25):
		return false
	var record: Dictionary = data["husbandry"]["records"][p["animal_id"]]
	var recipe: Dictionary = record["recipe"]
	var seconds: float = minf(delta, minf(float(p["food"]) * CARE_SECONDS, float(p["water"]) * CARE_SECONDS / float(recipe["water_need"])))
	if seconds <= 0:
		return false
	for kind: String in ["food", "water"]:
		var used: float = seconds / CARE_SECONDS * (float(recipe["water_need"]) if kind == "water" else 1.0)
		p[kind] = maxf(0.0, float(p[kind]) - used)
		data["husbandry"]["consumed"][kind] += used
	if int(record["pending_milk"]) > 0:
		return false # Continue upkeep but keep at most one completed batch.
	record["clock"] = minf(float(recipe["milk_interval"]), float(record["clock"]) + seconds)
	if float(record["clock"]) + 0.0000001 < float(recipe["milk_interval"]):
		return false
	record["clock"] = 0.0
	record["cycles"] += 1
	# One stock unit is one litre. Fractional yields accumulate without rounding up.
	var produced: int = floori(float(record["cycles"]) * float(recipe["milk_yield"]))
	record["pending_milk"] = produced - int(record["produced"])
	record["produced"] = produced
	record["pickup"] = p["entrance"].duplicate()
	return true

static func offer(data: Dictionary, identity: String) -> bool:
	var record: Dictionary = data["husbandry"]["records"][identity]
	var space: int = 48 - E.reserve(data, "milk") - E.milk_pending(data)
	var amount: int = mini(space, int(record["pending_milk"]))
	if amount <= 0:
		return false
	var batch: Dictionary = {"schema": 1, "source_id": identity, "body_id": data["body_id"], "faction_id": data["faction_id"],
		"sequence": int(record["sequence"]) + 1, "amount": amount, "position": record["pickup"].duplicate()}
	if not E.receive_milk(data, batch).is_empty():
		return false
	# Same campaign transaction as the inbox: no acknowledgment gap or second file.
	record["sequence"] += 1
	record["pending_milk"] -= amount
	record["handed_over"] += amount
	return true

static func validate(data: Dictionary) -> String:
	var h: Variant = data.get("husbandry")
	if not h is Dictionary or h.get("schema") != 1 or not h.get("pens") is Array or h["pens"].size() > MAX_PENS or not h.get("records") is Dictionary or h["records"].size() > MAX_RECORDS:
		return "Ungültige Tierhaltung."
	for field: String in ["withdrawn", "returned", "delivered", "consumed"]:
		if not h.get(field) is Dictionary:
			return "Ungültige Versorgungsbilanz."
		for kind: String in CAPACITY:
			if not E.number(h[field].get(kind), 0, 1000000000) or (field != "consumed" and not E.integer(h[field][kind], 0, 1000000000)):
				return "Ungültige Tierfuttermenge."
	var occupied: Array[String] = []
	for i in range(h["pens"].size()):
		var p: Variant = h["pens"][i]
		if not p is Dictionary or p.get("id") != Ids.scoped("pen", data["id"], str(i)) or not E.local_point(p.get("position"), data["anchor"]) or not E.local_point(p.get("entrance"), data["anchor"]) or not p.get("animal_id") is String or int(data["tools"]) != 1:
			return "Ungültiger Tierplatz."
		if Home.distance(p["entrance"], Home.offset_place(p["position"], Vector3(0, 0, 2))) > 0.01:
			return "Ungültiger Zugang zum Tierplatz."
		if p["animal_id"] != "":
			if not h["records"].has(p["animal_id"]) or p["animal_id"] in occupied:
				return "Tierplatz und Produktionsnachweis widersprechen sich."
			occupied.append(p["animal_id"])
		for kind: String in CAPACITY:
			if not E.number(p.get(kind), 0, CAPACITY[kind]) or float(p[kind]) + carried(data, p["id"], kind) > float(CAPACITY[kind]) + 0.000001:
				return "Tierplatz ist überfüllt."
	for member: Dictionary in data["members"]:
		if not member.get("care_pen_id") is String:
			return "Tierpflegeauftrag fehlt."
		if member["care_pen_id"] != "" and (pen(data, member["care_pen_id"]).is_empty() or member["cargo"] not in ["food", "water"] or member["construction_id"] != ""):
			return "Tierfutter ohne gültigen Transportauftrag."
	for kind: String in CAPACITY:
		var cargo: int = 0
		var stores: float = 0.0
		for p: Dictionary in h["pens"]:
			cargo += carried(data, p["id"], kind)
			stores += float(p[kind])
		if int(h["withdrawn"][kind]) != int(h["returned"][kind]) + int(h["delivered"][kind]) + cargo or absf(float(h["delivered"][kind]) - float(h["consumed"][kind]) - stores) > 0.0001:
			return "Tierfutter wurde verloren oder doppelt gebucht."
		var produced: int = 48 + int(data["grown"]) if kind == "food" else int(data["economy"]["produced"]["water"])
		if float(h["consumed"][kind]) + stores + E.reserve(data, kind) + int(data["deposits"][kind]["remaining"]) > produced + 0.0001:
			return "Tierfutter wurde zusätzlich ins Lager gebucht."
	var handed: int = 0
	var required_food: float = 0.0
	var required_water: float = 0.0
	for identity: Variant in h["records"]:
		var r: Variant = h["records"][identity]
		if not E.text_id(identity) or not r is Dictionary or not E.text_id(r.get("species_id")) or r["species_id"] == data["species_id"] or not r.get("design_ref") is Dictionary or not E.text_id(r["design_ref"].get("id")) or not E.integer(r["design_ref"].get("revision"), 0, 1000000000) or not r.get("recipe") is Dictionary or not E.local_point(r.get("pickup"), data["anchor"]):
			return "Ungültiger Milchproduktionsnachweis."
		var recipe: Dictionary = r["recipe"]
		if not E.number(recipe.get("milk_yield"), 0, 100) or float(recipe["milk_yield"]) <= 0 or not E.number(recipe.get("milk_interval"), 1, 86400) or not E.number(recipe.get("water_need"), 0, 100) or float(recipe["water_need"]) <= 0 or not E.number(r.get("clock"), 0, recipe["milk_interval"]):
			return "Ungültiges Milchintervall."
		for field: String in ["cycles", "produced", "pending_milk", "handed_over", "sequence"]:
			if not E.integer(r.get(field), 0, 100 if field == "pending_milk" else 1000000000):
				return "Ungültige Milchmenge."
		if int(r["produced"]) != floori(float(r["cycles"]) * float(recipe["milk_yield"])) or int(r["produced"]) != int(r["pending_milk"]) + int(r["handed_over"]):
			return "Milchproduktion wurde doppelt gebucht."
		var receipt: Dictionary = data["economy"]["receipts"].get(identity, {})
		if int(r["sequence"]) != int(receipt.get("sequence", 0)) or (int(r["sequence"]) == 0 and int(r["handed_over"]) != 0):
			return "Milchproduktion und Quittung widersprechen sich."
		handed += int(r["handed_over"])
		var serviced: float = (float(r["cycles"]) * float(recipe["milk_interval"]) + float(r["clock"])) / CARE_SECONDS
		required_food += serviced
		required_water += serviced * float(recipe["water_need"])
	if handed > int(data["economy"]["milk_received"]):
		return "Milch wurde ohne gemeinsame Annahme ausgeliefert."
	if required_food > float(h["consumed"]["food"]) + 0.0001 or required_water > float(h["consumed"]["water"]) + 0.0001:
		return "Milch entstand ohne passende Futter- und Wasserversorgung."
	if data["project"].get("kind", "") == "pen":
		var p: Dictionary = data["project"]
		if h["pens"].size() >= MAX_PENS or int(data["tools"]) != 1 or p.get("id") != Ids.scoped("pen", data["id"], str(h["pens"].size())) or not E.local_point(p.get("position"), data["anchor"]) or not E.local_point(p.get("entrance"), data["anchor"]) or Home.distance(p["entrance"], Home.offset_place(p["position"], Vector3(0, 0, 2))) > 0.01:
			return "Ungültige Tierplatzbaustelle."
	return ""
