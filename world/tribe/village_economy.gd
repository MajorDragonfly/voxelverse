extends RefCounted
## Village-only economy. No species, ownership, taming or animal production here.
const Home = preload("res://world/home_group/home_group_state.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const Resources = preload("res://world/tribe/resource_catalog.gd")
const Batch = preload("res://world/tribe/resource_batch.gd")
const RESOURCES: Array[String] = Resources.IDS
const SCHEMA: int = 2
const EXTRA: Array[String] = ["water", "fiber", "milk", "eggs"]
const STATIONS: Dictionary = {"well": "water", "forester": "wood", "quarry": "stone", "fiberbed": "fiber"}
const COSTS: Dictionary = {"well": {"wood": 3, "stone": 2}, "forester": {"wood": 4, "stone": 1}, "quarry": {"wood": 4, "stone": 2}, "fiberbed": {"wood": 2, "stone": 1}}
const INTERVALS: Dictionary = {"water": 5.0, "wood": 12.0, "stone": 15.0, "fiber": 12.0}
const TITLES: Dictionary = Resources.TITLES
const JOBS: Dictionary = {"none": "Ohne Beruf", "provider": "Versorger", "forester": "Holzarbeiter", "mason": "Steinmetz", "weaver": "Fasersammler", "builder": "Baumeister", "milk_carrier": "Milchträger", "keeper": "Tierpfleger", "egg_carrier": "Eierträger"}
const JOB_ORDER: Dictionary = {"none": "wait", "provider": "provision", "forester": "wood", "mason": "stone", "weaver": "fiber", "builder": "build", "milk_carrier": "milk", "keeper": "tend", "egg_carrier": "eggs"}
const ORDERS: Array[String] = ["water", "fiber", "milk", "eggs", "laying_site", "drink", "provision", "build", "well", "forester", "quarry", "fiberbed", "tend"]
const TARGETS: Dictionary = {"food": 12, "water": 12, "wood": 16, "stone": 16, "fiber": 12, "milk": 12, "eggs": 12}
const CAPACITY: int = 8
const CARE_THRESHOLD: float = 55.0

static func install(data: Dictionary) -> void:
	data["economy"] = {"schema": SCHEMA, "eggs_received": 0, "eggs_meals": 0, "stations": {}, "clocks": {}, "produced": {}, "incoming": [], "receipts": {}, "drinks": 0, "milk_meals": 0, "milk_received": 0}
	for kind: String in EXTRA:
		data["stock"][kind] = 0
	for kind: String in INTERVALS:
		data["economy"]["clocks"][kind] = 0.0
		data["economy"]["produced"][kind] = 0
	for kind: String in ["water", "fiber"]:
		data["deposits"][kind] = {"id": Ids.scoped("resource", data["home_group_id"], kind), "position": data["anchor"].duplicate(), "remaining": 0}
	for member: Dictionary in data["members"]:
		member.merge({"hydration": 100.0, "profession": "none", "paused_order": "", "task": "", "blocked": false}, true)

static func upgrade(data: Dictionary) -> bool:
	if data.get("economy", {}).get("schema") != 1: return false
	data.economy.schema = SCHEMA
	data.economy["eggs_received"] = 0
	data.economy["eggs_meals"] = 0
	data.stock["eggs"] = 0
	return true

static func tick(data: Dictionary, delta: float) -> bool:
	if delta <= 0 or not is_finite(delta):
		return false
	var economy: Dictionary = data["economy"]
	var changed: bool = false
	for station: String in economy["stations"]:
		var kind: String = STATIONS[station]
		var deposit: Dictionary = data["deposits"][kind]
		if int(deposit["remaining"]) >= CAPACITY:
			economy["clocks"][kind] = 0.0
			continue
		economy["clocks"][kind] += delta
		while float(economy["clocks"][kind]) >= float(INTERVALS[kind]) and int(deposit["remaining"]) < CAPACITY:
			economy["clocks"][kind] -= INTERVALS[kind]
			economy["produced"][kind] += 1
			deposit["remaining"] += 1
			changed = true
		if int(deposit["remaining"]) >= CAPACITY:
			economy["clocks"][kind] = 0.0
	return changed

static func carried(data: Dictionary, kind: String) -> int:
	var count: int = 0
	for member: Dictionary in data["members"]:
		count += 1 if member["cargo"] == kind and member.get("construction_id", "") == "" else 0
	return count

static func reserve(data: Dictionary, kind: String) -> int:
	return int(data["stock"].get(kind, 0)) + carried(data, kind)

static func has_food(data: Dictionary) -> bool:
	return not food_kind(data).is_empty()

static func food_kind(data: Dictionary) -> String:
	for kind: String in Resources.FOODS:
		if int(data.stock.get(kind, 0)) > 0: return kind
	return ""

static func consume(data: Dictionary, kind: String) -> Dictionary:
	var resource: Dictionary = Resources.definition(kind)
	if resource.is_empty() or (resource.nutrition <= 0 and resource.hydration <= 0) or int(data.stock.get(kind, 0)) <= 0: return {}
	data.stock[kind] -= 1
	Resources.add(data.economy, kind, "consumed", 1)
	return resource

static func gather_kind(data: Dictionary, member: Dictionary) -> String:
	var order: String = member["order"]
	if order == "supply":
		return "food"
	if order != "provision":
		return order if order in RESOURCES else ""
	# Persist the selected leg while walking/working; concurrent workers still
	# check the shared target at pickup, so neither food nor water overshoots.
	var task: String = member["task"]
	if task in ["food", "water"] and reserve(data, task) < target(data, task) and int(data["deposits"][task]["remaining"]) > 0:
		return task
	var food_ratio: float = float(reserve(data, "food")) / target(data, "food")
	var water_ratio: float = float(reserve(data, "water")) / target(data, "water")
	var choices: Array = ["water", "food"] if water_ratio <= food_ratio else ["food", "water"]
	for kind: String in choices:
		if reserve(data, kind) < target(data, kind) and int(data["deposits"][kind]["remaining"]) > 0:
			member["task"] = kind
			return kind
	member["task"] = ""
	return ""

static func target(data: Dictionary, kind: String) -> int:
	return maxi(int(TARGETS[kind]), data["members"].size() * 4) if kind in ["food", "water"] else int(TARGETS[kind])

static func at_target(data: Dictionary, member: Dictionary, kind: String) -> bool:
	var limit: int = target(data, kind) if member["order"] in ["supply", "provision"] or member["profession"] != "none" else 48
	return reserve(data, kind) >= limit

static func pending(data: Dictionary, kind: String) -> int:
	var total: int = 0
	for batch: Dictionary in data.economy.incoming:
		if Batch.resource_id(batch) == kind: total += int(batch.remaining)
	return total

static func pickup(data: Dictionary, kind: String) -> Dictionary:
	for batch: Dictionary in data.economy.incoming:
		if Batch.resource_id(batch) == kind: return batch
	return {}

static func collect(data: Dictionary, member: Dictionary, kind: String) -> bool:
	var batch: Dictionary = pickup(data, kind)
	if batch.is_empty() or member.cargo != "" or at_target(data, member, kind) or Home.distance(member.position, batch.position) > 3.0: return false
	batch.remaining -= 1
	if int(batch.remaining) == 0: data.economy.incoming.erase(batch)
	member.cargo = kind
	member.stage = "return"
	return true

static func milk_pending(data: Dictionary) -> int:
	return pending(data, "milk") # Compatibility API for existing D3/UI/tests.

static func receive_milk(data: Dictionary, value: Dictionary) -> String:
	var batch: Dictionary = Batch.canonical(data, value)
	if batch.is_empty() or batch.resource_id != "milk": return "Ungültige Milchlieferung."
	return receive_batch(data, batch)

static func receive_batch(data: Dictionary, value: Dictionary) -> String:
	# Inbox, receipt and producer acknowledgment share the campaign transaction.
	var batch: Dictionary = Batch.canonical(data, value)
	if batch.is_empty(): return "Ungültiger Ressourcenbatch oder unbekannte Revision."
	var kind: String = batch.resource_id
	if kind == "eggs" and data.economy.schema != SCHEMA: return "Eier benötigen das aktuelle Wirtschaftsformat."
	if not Resources.uses_batches(kind): return "Diese Ressource besitzt keinen Produktionsanschluss."
	var receipts: Dictionary = data.economy.receipts
	var identity: String = batch.source_id
	var saved: Dictionary = receipts.get(identity, {})
	var last: Dictionary = Batch.canonical(data, saved)
	if not saved.is_empty() and last.is_empty(): return "Gespeicherter Lieferbeleg ist ungültig."
	if not last.is_empty() and int(batch.sequence) == int(last.sequence):
		return "" if batch == last else "Veränderte Lieferung mit gleicher Nummer."
	if not last.is_empty() and (batch.resource_id != last.resource_id or batch.recipe_id != last.recipe_id or batch.recipe_revision != last.recipe_revision): return "Produktionsquelle hat ihren Vertrag geändert."
	if int(batch.sequence) != int(last.get("sequence", 0)) + 1 or (not receipts.has(identity) and receipts.size() >= 64): return "Lieferung außerhalb der erwarteten Reihenfolge."
	if reserve(data, kind) + pending(data, kind) + int(batch.amount) > int(Resources.definition(kind).capacity): return "Für diese Lieferung fehlt Lagerplatz."
	if Resources.total(data.economy, kind, "received") + int(batch.amount) > 1000000000: return "Produktionsnachweis ist ausgeschöpft."
	Resources.add(data.economy, kind, "received", int(batch.amount))
	receipts[identity] = batch.duplicate(true)
	var incoming: Dictionary = batch.duplicate(true)
	incoming.remaining = int(batch.amount)
	data.economy.incoming.append(incoming)
	return ""

static func has_unsupported_contract(value: Variant) -> bool:
	if not value is Dictionary: return false
	if (value.get("schema") != 1 and value.get("schema") != SCHEMA): return true
	if value.get("receipts") is Dictionary:
		for receipt: Variant in value.receipts.values():
			if Batch.unsupported(receipt): return true
	if value.get("incoming") is Array:
		for batch: Variant in value.incoming:
			if Batch.unsupported(batch): return true
	return false

static func validate(data: Dictionary) -> String:
	var e: Variant = data.get("economy")
	if not e is Dictionary or (e.get("schema") != 1 and e.get("schema") != SCHEMA):
		return "Ungültige Dorfwirtschaft."
	for field in ["stations", "clocks", "produced", "receipts"]:
		if not e.get(field) is Dictionary:
			return "Ungültiger Wirtschaftsvertrag."
	if not integer(e.get("milk_received"), 0, 1000000000) or not integer(e.get("drinks"), 0, 1000000000) or not integer(e.get("milk_meals"), 0, 1000000000):
		return "Ungültiger Verbrauch."
	if e.schema == SCHEMA:
		for counter in ["eggs_received", "eggs_meals"]:
			if not integer(e.get(counter), 0, 1000000000): return "Ungültige Eierbilanz."
	elif data.stock.has("eggs") or e.has("eggs_received") or e.has("eggs_meals"):
		return "Eier benötigen Wirtschaftsformat 2."
	for kind: String in EXTRA:
		if kind == "eggs" and e.schema == 1: continue
		if not integer(data["stock"].get(kind), 0, 48) or reserve(data, kind) > 48:
			return "Ungültiger Zusatzvorrat."
	for kind: String in INTERVALS:
		if not number(e["clocks"].get(kind), 0, INTERVALS[kind]) or not integer(e["produced"].get(kind), 0, 1000000000):
			return "Ungültiger Rohstofftakt."
		var deposit: Variant = data["deposits"].get(kind)
		if not deposit is Dictionary or deposit.get("id") != Ids.scoped("resource", data["home_group_id"], kind) or not local_point(deposit.get("position"), data["anchor"]) or not integer(deposit.get("remaining"), 0, 48):
			return "Ungültiger Rohstoffplatz."
		if int(deposit["remaining"]) + reserve(data, kind) > (48 if kind in ["wood", "stone"] else 0) + int(e["produced"][kind]):
			return "Rohstoff wurde vervielfacht."
	for station: String in e["stations"]:
		var site: Variant = e["stations"][station]
		if station not in STATIONS or not site is Dictionary or site.get("id") != Ids.scoped("workplace", data["id"], station) or not local_point(site.get("position"), data["anchor"]) or int(data["tools"]) != 1:
			return "Ungültiger Arbeitsplatz."
		if site["position"] != data["deposits"][STATIONS[station]]["position"]:
			return "Arbeitsplatz und Rohstoffquelle widersprechen sich."
	for kind: String in INTERVALS:
		var built: bool = e["stations"].has(STATIONS.find_key(kind))
		if not built and (float(e["clocks"][kind]) != 0 or int(e["produced"][kind]) != 0):
			return "Rohstoffe entstehen erst nach dem Arbeitsplatzbau."
	for member: Dictionary in data["members"]:
		if not number(member.get("hydration"), 0, 100) or member.get("profession") not in JOBS or not member.get("paused_order") is String or (member["paused_order"] != "" and member["paused_order"] not in (["wait", "move", "wood", "stone", "food", "tool", "hut", "tent", "pen", "feed", "garden", "supply"] + ORDERS)) or member.get("task") not in ["", "water", "food"] or not member.get("blocked") is bool:
			return "Ungültiger Beruf oder unterbrochener Auftrag."
		if e.schema == 1 and (member.get("order") in ["eggs", "laying_site"] or member.get("paused_order") in ["eggs", "laying_site"] or member.get("cargo") == "eggs" or member.get("profession") == "egg_carrier"): return "Eierauftrag benötigt Wirtschaftsformat 2."
		if member["paused_order"] != "" and member["order"] != "wait":
			return "Unterbrochener Auftrag wird bereits ausgeführt."
	if not e.get("incoming") is Array or e["incoming"].size() > 48 or e["receipts"].size() > 64:
		return "Ungültiges Milchlieferbuch."
	for identity: Variant in e.receipts:
		var receipt: Dictionary = Batch.canonical(data, e.receipts[identity])
		if not receipt.is_empty() and e.schema == 1 and receipt.resource_id == "eggs": return "Eierbeleg benötigt Wirtschaftsformat 2."
		if receipt.is_empty() or receipt.source_id != identity or e.receipts[identity].has("remaining"):
			return "Ungültiger Ressourcenbeleg."
	var keys: Array[String] = []
	for value: Variant in e.incoming:
		var batch: Dictionary = Batch.canonical(data, value)
		if not batch.is_empty() and e.schema == 1 and batch.resource_id == "eggs": return "Eierlieferung benötigt Wirtschaftsformat 2."
		if batch.is_empty() or not e.receipts.has(batch.source_id) or not integer(value.get("remaining"), 1, int(batch.amount)): return "Ungültige offene Ressourcenlieferung."
		var last: Dictionary = Batch.canonical(data, e.receipts[batch.source_id])
		if int(batch.sequence) > int(last.sequence) or batch.resource_id != last.resource_id or batch.recipe_id != last.recipe_id or batch.recipe_revision != last.recipe_revision: return "Lieferung widerspricht ihrem Produktionsbeleg."
		if int(batch.sequence) == int(last.sequence) and batch != last: return "Offene Lieferung wurde nach Annahme verändert."
		if batch.receipt_id in keys: return "Doppelte offene Ressourcenlieferung."
		keys.append(batch.receipt_id)
	for kind: String in RESOURCES:
		if not Resources.uses_batches(kind): continue
		if kind == "eggs" and pending(data, kind) + reserve(data, kind) + Resources.total(e, kind, "consumed") != Resources.total(e, kind, "received"): return "Eier wurden verloren oder doppelt gebucht."
		if pending(data, kind) + reserve(data, kind) + Resources.total(e, kind, "consumed") > Resources.total(e, kind, "received"): return "Ressource wurde vervielfacht."
		if pending(data, kind) + reserve(data, kind) > int(Resources.definition(kind).capacity): return "Ressource überschreitet Lagerkapazität."
	return ""

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func integer(value: Variant, low: int, high: int) -> bool:
	return number(value, low, high) and float(value) == floorf(float(value))

static func text_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 200

static func local_point(value: Variant, anchor: Variant) -> bool:
	return Home.local_place(value, anchor)
