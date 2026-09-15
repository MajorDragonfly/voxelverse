extends RefCounted
## D3 owns feed credits and production, never a second animal/species register.
const Production = preload("res://world/tribe/production_catalog.gd")
const E = preload("res://world/tribe/village_economy.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const SCHEMA: int = 2
const SITE_KINDS: Array[String] = ["pen", "laying_site"]
const MAX_PENS: int = 2
const MAX_RECORDS: int = 32
const CAPACITY: Dictionary = {"food": 4.0, "water": 8.0}
const TARGET: Dictionary = {"food": 2.0, "water": 4.0}
const CARE_SECONDS: float = Production.CARE_SECONDS

static func install(data: Dictionary) -> void:
	data["husbandry"] = {"schema": SCHEMA, "pens": [], "records": {},
		"withdrawn": {"food": 0, "water": 0}, "returned": {"food": 0, "water": 0},
		"delivered": {"food": 0, "water": 0}, "consumed": {"food": 0.0, "water": 0.0}}
	for member: Dictionary in data["members"]:
		member["care_pen_id"] = ""

static func upgrade(data: Dictionary) -> bool:
	if data.get("husbandry", {}).get("schema") != 1: return false
	# Old milk parameters, fractional clocks, IDs and receipts remain untouched.
	data.husbandry.schema = SCHEMA
	return true

static func site_recipe(p: Dictionary) -> String:
	return Production.EGGS if p.get("kind", "pen") == "laying_site" else Production.MILK

static func recipe_id(parameters: Dictionary) -> String:
	return str(parameters.get("recipe_id", Production.MILK))

static func pending_key(record: Dictionary) -> String:
	return "pending_output" if recipe_id(record.recipe) == Production.EGGS else "pending_milk"

static func pending(record: Dictionary) -> int:
	return int(record[pending_key(record)])

static func production_recipe(record: Dictionary) -> Dictionary:
	return Production.from_parameters(recipe_id(record.recipe), record.recipe)

static func parameters_valid(value: Dictionary) -> bool:
	var definition: Dictionary = Production.definition(recipe_id(value))
	if definition.is_empty(): return false
	if value.has("recipe_id") and value.get("recipe_revision") != definition.revision: return false
	if definition.resource_id == "eggs" and value.get("recipe_revision") != definition.revision: return false
	return E.number(value.get(definition.yield_field), 0, 100) and float(value[definition.yield_field]) > 0 \
		and (definition.resource_id != "eggs" or float(value[definition.yield_field]) >= 1.0) \
		and E.number(value.get(definition.interval_field), 1, 86400) \
		and E.number(value.get("water_need"), 0, 100) and float(value.water_need) > 0

static func has_unsupported_contract(value: Variant) -> bool:
	if not value is Dictionary: return false
	if (value.get("schema") != 1 and value.get("schema") != SCHEMA): return true
	if value.get("records") is Dictionary:
		for record: Variant in value.records.values():
			if not record is Dictionary or not record.get("recipe") is Dictionary: continue
			var parameters: Dictionary = record.recipe
			var definition: Dictionary = Production.definition(recipe_id(parameters))
			if definition.is_empty() or (parameters.has("recipe_revision") and parameters.recipe_revision != definition.revision): return true
	return false

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
	if not parameters_valid(recipe) or recipe_id(recipe) != site_recipe(p): return "Dieses Tier passt nicht zu diesem Haltungsplatz."
	if recipe_id(recipe) == Production.EGGS and data.husbandry.schema != SCHEMA: return "Legestellen benötigen Tierhaltungsformat 2."
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
			return "Art oder Körper des gespeicherten Tieres hat sich geändert."
	else:
		if records.size() >= MAX_RECORDS or data["economy"]["receipts"].has(identity) or data["economy"]["receipts"].size() >= 64:
			return "Für dieses Tier ist kein freier Produktionsnachweis verfügbar."
		records[identity] = {"species_id": animal["species_id"], "design_ref": animal["design_ref"].duplicate(),
			"recipe": recipe.duplicate(), "clock": 0.0, "cycles": 0, "produced": 0, "pending_milk": 0,
			"handed_over": 0, "sequence": 0, "pickup": p["entrance"].duplicate()}
		if recipe_id(recipe) == Production.EGGS:
			records[identity].erase("pending_milk")
			records[identity]["pending_output"] = 0
	p["animal_id"] = identity
	return ""

static func matches(record: Dictionary, animal: Dictionary, recipe: Dictionary) -> bool:
	if record["species_id"] != animal["species_id"] or record["design_ref"]["id"] != animal["design_ref"]["id"] or int(record["design_ref"]["revision"]) != int(animal["design_ref"]["revision"]):
		return false
	if not parameters_valid(recipe) or recipe_id(record.recipe) != recipe_id(recipe): return false
	var definition: Dictionary = Production.definition(recipe_id(recipe))
	for field: String in [definition.yield_field, definition.interval_field, "water_need"]:
		if float(record["recipe"][field]) != float(recipe[field]):
			return false
	return true

static func unbind(data: Dictionary, p: Dictionary) -> String:
	if p["animal_id"] == "":
		return ""
	var record: Dictionary = data["husbandry"]["records"][p["animal_id"]]
	if pending(record) > 0:
		return "Hole zuerst die fertigen Produkte ab und schaffe Lagerplatz."
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
	var recipe: Dictionary = production_recipe(record)
	var seconds: float = delta
	for kind: String in recipe.inputs:
		seconds = minf(seconds, float(p[kind]) * float(recipe.care_seconds) / float(recipe.inputs[kind]))
	if seconds <= 0:
		return false
	for kind: String in recipe.inputs:
		var used: float = seconds / CARE_SECONDS * float(recipe.inputs[kind])
		p[kind] = maxf(0.0, float(p[kind]) - used)
		data["husbandry"]["consumed"][kind] += used
	if pending(record) > 0:
		return false # Continue upkeep but keep at most one completed batch.
	record["clock"] = minf(float(recipe.interval), float(record["clock"]) + seconds)
	if float(record["clock"]) + 0.0000001 < float(recipe.interval):
		return false
	record["clock"] = 0.0
	record["cycles"] += 1
	# One stock unit is one litre. Fractional yields accumulate without rounding up.
	var produced: int = Production.produced(int(record["cycles"]), recipe)
	record[pending_key(record)] = produced - int(record["produced"])
	record["produced"] = produced
	record["pickup"] = p["entrance"].duplicate()
	return true

static func offer(data: Dictionary, identity: String) -> bool:
	var record: Dictionary = data["husbandry"]["records"][identity]
	var recipe: Dictionary = production_recipe(record)
	var kind: String = recipe.resource_id
	var space: int = int(E.Resources.definition(kind).capacity) - E.reserve(data, kind) - E.pending(data, kind)
	var amount: int = mini(space, pending(record))
	if amount <= 0: return false
	var batch: Dictionary = E.Batch.create(data, identity, int(record.sequence) + 1, amount, record.pickup, recipe.recipe_id)
	if not E.receive_batch(data, batch).is_empty(): return false
	# Same campaign transaction as the inbox: no acknowledgment gap or second file.
	record["sequence"] += 1
	record[pending_key(record)] -= amount
	record["handed_over"] += amount
	return true

static func validate(data: Dictionary) -> String:
	var h: Variant = data.get("husbandry")
	if not h is Dictionary or (h.get("schema") != 1 and h.get("schema") != SCHEMA) or not h.get("pens") is Array or h["pens"].size() > MAX_PENS or not h.get("records") is Dictionary or h["records"].size() > MAX_RECORDS:
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
		if p.get("kind", "pen") not in SITE_KINDS or (h.schema == 1 and p.get("kind", "pen") != "pen"): return "Unbekannte Haltungsplatzart."
		if Home.distance(p["entrance"], Home.offset_place(p["position"], Vector3(0, 0, 2))) > 0.01:
			return "Ungültiger Zugang zum Tierplatz."
		if p["animal_id"] != "":
			if not h["records"].has(p["animal_id"]) or p["animal_id"] in occupied:
				return "Tierplatz und Produktionsnachweis widersprechen sich."
			var stored: Variant = h.records[p.animal_id]
			if not stored is Dictionary or not stored.get("recipe") is Dictionary or recipe_id(stored.recipe) != site_recipe(p): return "Tier und Haltungsplatz widersprechen sich."
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
	var handed: Dictionary = {"milk": 0, "eggs": 0}
	var required_food: float = 0.0
	var required_water: float = 0.0
	for identity: Variant in h["records"]:
		var r: Variant = h["records"][identity]
		if not E.text_id(identity) or not r is Dictionary or not E.text_id(r.get("species_id")) or r["species_id"] == data["species_id"] or not r.get("design_ref") is Dictionary or not E.text_id(r["design_ref"].get("id")) or not E.integer(r["design_ref"].get("revision"), 0, 1000000000) or not r.get("recipe") is Dictionary or not E.local_point(r.get("pickup"), data["anchor"]):
			return "Ungültiger Produktionsnachweis."
		if not parameters_valid(r.recipe): return "Ungültiges Produktionsrezept."
		var recipe: Dictionary = production_recipe(r)
		if h.schema == 1 and recipe.recipe_id != Production.MILK: return "Eier benötigen Tierhaltungsformat 2."
		if not E.number(r.get("clock"), 0, recipe.interval): return "Ungültiges Produktionsintervall."
		var output: String = pending_key(r)
		if r.has("pending_milk" if output == "pending_output" else "pending_output"): return "Doppelte Produktionsablage."
		for field: String in ["cycles", "produced", output, "handed_over", "sequence"]:
			if not E.integer(r.get(field), 0, 100 if field == output else 1000000000): return "Ungültige Produktionsmenge."
		if int(r.produced) != Production.produced(int(r.cycles), recipe) or int(r.produced) != pending(r) + int(r.handed_over):
			return "Produktion wurde verloren oder doppelt gebucht."
		var receipt: Dictionary = data["economy"]["receipts"].get(identity, {})
		if int(r["sequence"]) != int(receipt.get("sequence", 0)) or (int(r["sequence"]) == 0 and int(r["handed_over"]) != 0):
			return "Milchproduktion und Quittung widersprechen sich."
		if not receipt.is_empty() and E.Batch.resource_id(receipt) != recipe.resource_id: return "Produktion und Ressourcenbeleg widersprechen sich."
		handed[recipe.resource_id] += int(r["handed_over"])
		var serviced: float = (float(r["cycles"]) * float(recipe.interval) + float(r["clock"])) / CARE_SECONDS
		required_food += serviced
		required_water += serviced * float(recipe.inputs.water)
	for kind: String in handed:
		if handed[kind] > E.Resources.total(data.economy, kind, "received"): return "Produkte wurden ohne gemeinsame Annahme ausgeliefert."
	if required_food > float(h["consumed"]["food"]) + 0.0001 or required_water > float(h["consumed"]["water"]) + 0.0001:
		return "Produkte entstanden ohne passende Futter- und Wasserversorgung."
	if data["project"].get("kind", "") in SITE_KINDS:
		var p: Dictionary = data["project"]
		if h.schema == 1 and p.kind != "pen": return "Legestellen benötigen Tierhaltungsformat 2."
		if h["pens"].size() >= MAX_PENS or int(data["tools"]) != 1 or p.get("id") != Ids.scoped("pen", data["id"], str(h["pens"].size())) or not E.local_point(p.get("position"), data["anchor"]) or not E.local_point(p.get("entrance"), data["anchor"]) or Home.distance(p["entrance"], Home.offset_place(p["position"], Vector3(0, 0, 2))) > 0.01:
			return "Ungültige Tierplatzbaustelle."
	return ""
