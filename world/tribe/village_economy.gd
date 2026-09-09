extends RefCounted
## Village-only economy. No species, ownership, taming or animal production here.
const Home = preload("res://world/home_group/home_group_state.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const RESOURCES: Array[String] = ["wood", "stone", "food", "water", "fiber", "milk"]
const EXTRA: Array[String] = ["water", "fiber", "milk"]
const STATIONS: Dictionary = {"well": "water", "forester": "wood", "quarry": "stone", "fiberbed": "fiber"}
const COSTS: Dictionary = {"well": {"wood": 3, "stone": 2}, "forester": {"wood": 4, "stone": 1}, "quarry": {"wood": 4, "stone": 2}, "fiberbed": {"wood": 2, "stone": 1}}
const INTERVALS: Dictionary = {"water": 5.0, "wood": 12.0, "stone": 15.0, "fiber": 12.0}
const TITLES: Dictionary = {"water": "Wasser", "wood": "Holz", "stone": "Stein", "fiber": "Fasern", "food": "Nahrung", "milk": "Milch"}
const JOBS: Dictionary = {"none": "Ohne Beruf", "provider": "Versorger", "forester": "Holzarbeiter", "mason": "Steinmetz", "weaver": "Fasersammler", "builder": "Baumeister", "milk_carrier": "Milchträger"}
const JOB_ORDER: Dictionary = {"none": "wait", "provider": "provision", "forester": "wood", "mason": "stone", "weaver": "fiber", "builder": "build", "milk_carrier": "milk"}
const ORDERS: Array[String] = ["water", "fiber", "milk", "drink", "provision", "build", "well", "forester", "quarry", "fiberbed"]
const TARGETS: Dictionary = {"food": 12, "water": 12, "wood": 16, "stone": 16, "fiber": 12, "milk": 12}
const CAPACITY: int = 8

static func install(data: Dictionary) -> void:
	data["economy"] = {"schema": 1, "stations": {}, "clocks": {}, "produced": {}, "incoming": [], "receipts": {}, "drinks": 0, "milk_meals": 0, "milk_received": 0}
	for kind: String in EXTRA:
		data["stock"][kind] = 0
	for kind: String in INTERVALS:
		data["economy"]["clocks"][kind] = 0.0
		data["economy"]["produced"][kind] = 0
	for kind: String in ["water", "fiber"]:
		data["deposits"][kind] = {"id": Ids.scoped("resource", data["home_group_id"], kind), "position": data["anchor"].duplicate(), "remaining": 0}
	for member: Dictionary in data["members"]:
		member.merge({"hydration": 100.0, "profession": "none", "paused_order": "", "task": "", "blocked": false}, true)

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
		count += 1 if member["cargo"] == kind else 0
	return count

static func reserve(data: Dictionary, kind: String) -> int:
	return int(data["stock"][kind]) + carried(data, kind)

static func has_food(data: Dictionary) -> bool:
	return int(data["stock"]["food"]) + int(data["stock"]["milk"]) > 0

static func gather_kind(data: Dictionary, member: Dictionary) -> String:
	var order: String = member["order"]
	if order == "supply":
		return "food"
	if order != "provision":
		return order if order in RESOURCES else ""
	# Persist the selected leg while walking/working; concurrent workers still
	# check the shared target at pickup, so neither food nor water overshoots.
	var task: String = member["task"]
	if task in ["food", "water"] and reserve(data, task) < int(TARGETS[task]) and int(data["deposits"][task]["remaining"]) > 0:
		return task
	var food_ratio: float = float(reserve(data, "food")) / TARGETS["food"]
	var water_ratio: float = float(reserve(data, "water")) / TARGETS["water"]
	var choices: Array = ["water", "food"] if water_ratio <= food_ratio else ["food", "water"]
	for kind: String in choices:
		if reserve(data, kind) < int(TARGETS[kind]) and int(data["deposits"][kind]["remaining"]) > 0:
			member["task"] = kind
			return kind
	member["task"] = ""
	return ""

static func at_target(data: Dictionary, member: Dictionary, kind: String) -> bool:
	var limit: int = int(TARGETS[kind]) if member["order"] in ["supply", "provision"] or member["profession"] != "none" else 48
	return reserve(data, kind) >= limit

static func milk_pending(data: Dictionary) -> int:
	var total: int = 0
	for batch: Dictionary in data["economy"]["incoming"]:
		total += int(batch["remaining"])
	return total

static func receive_milk(data: Dictionary, batch: Dictionary) -> String:
	# D3 passes a completed production batch. Acceptance is saved by controller
	# before acknowledgment. Retries of the last identical sequence are harmless.
	if batch.get("schema") != 1 or batch.get("body_id") != data["body_id"] or batch.get("faction_id") != data["faction_id"] or not text_id(batch.get("source_id")) or not integer(batch.get("sequence"), 1, 1000000000) or not integer(batch.get("amount"), 1, 48) or not local_point(batch.get("position"), data["anchor"]):
		return "Ungültige Milchlieferung."
	# JSON numbers must compare identically before and after a disk round trip.
	batch = JSON.parse_string(JSON.stringify(batch))
	var receipts: Dictionary = data["economy"]["receipts"]
	var identity: String = batch["source_id"]
	var last: Dictionary = receipts.get(identity, {})
	if not last.is_empty() and int(batch["sequence"]) == int(last["sequence"]):
		return "" if batch == last else "Veränderte Milchlieferung mit gleicher Nummer."
	if int(batch["sequence"]) != int(last.get("sequence", 0)) + 1 or (not receipts.has(identity) and receipts.size() >= 64):
		return "Milchlieferung außerhalb der erwarteten Reihenfolge."
	if reserve(data, "milk") + milk_pending(data) + int(batch["amount"]) > 48:
		return "Für diese Milchlieferung fehlt Lagerplatz."
	data["economy"]["milk_received"] += int(batch["amount"])
	receipts[identity] = batch.duplicate(true)
	var incoming: Dictionary = batch.duplicate(true)
	incoming["remaining"] = int(batch["amount"])
	data["economy"]["incoming"].append(incoming)
	return ""

static func validate(data: Dictionary) -> String:
	var e: Variant = data.get("economy")
	if not e is Dictionary or e.get("schema") != 1:
		return "Ungültige Dorfwirtschaft."
	for field in ["stations", "clocks", "produced", "receipts"]:
		if not e.get(field) is Dictionary:
			return "Ungültiger Wirtschaftsvertrag."
	if not integer(e.get("milk_received"), 0, 1000000000) or not integer(e.get("drinks"), 0, 1000000000) or not integer(e.get("milk_meals"), 0, 1000000000):
		return "Ungültiger Verbrauch."
	for kind: String in EXTRA:
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
		if not number(member.get("hydration"), 0, 100) or member.get("profession") not in JOBS or not member.get("paused_order") is String or (member["paused_order"] != "" and member["paused_order"] not in (["wait", "move", "wood", "stone", "food", "tool", "hut", "feed", "garden", "supply"] + ORDERS)) or member.get("task") not in ["", "water", "food"] or not member.get("blocked") is bool:
			return "Ungültiger Beruf oder unterbrochener Auftrag."
		if member["paused_order"] != "" and member["order"] != "wait":
			return "Unterbrochener Auftrag wird bereits ausgeführt."
	if not e.get("incoming") is Array or e["incoming"].size() > 48 or e["receipts"].size() > 64:
		return "Ungültiges Milchlieferbuch."
	for identity: Variant in e["receipts"]:
		var receipt: Variant = e["receipts"][identity]
		if not receipt is Dictionary or not text_id(identity) or receipt.get("source_id") != identity or receipt.get("schema") != 1 or receipt.get("body_id") != data["body_id"] or receipt.get("faction_id") != data["faction_id"] or not integer(receipt.get("sequence"), 1, 1000000000) or not integer(receipt.get("amount"), 1, 48) or not local_point(receipt.get("position"), data["anchor"]):
			return "Ungültige Milchquittung."
	var keys: Array[String] = []
	for batch: Variant in e["incoming"]:
		if not batch is Dictionary or not text_id(batch.get("source_id")) or not e["receipts"].has(batch["source_id"]) or not integer(batch.get("sequence"), 1, int(e["receipts"][batch["source_id"]]["sequence"])) or not integer(batch.get("amount"), 1, 48) or not integer(batch.get("remaining"), 1, int(batch["amount"])) or not local_point(batch.get("position"), data["anchor"]) or batch.get("body_id") != data["body_id"] or batch.get("faction_id") != data["faction_id"] or batch.get("schema") != 1:
			return "Ungültige offene Milchlieferung."
		var key: String = "%s:%s" % [batch["source_id"], batch["sequence"]]
		if key in keys:
			return "Doppelte offene Milchlieferung."
		keys.append(key)
	if milk_pending(data) + reserve(data, "milk") + int(e["milk_meals"]) > int(e["milk_received"]):
		return "Milch wurde vervielfacht."
	if milk_pending(data) + reserve(data, "milk") > 48:
		return "Milch überschreitet Lagerkapazität."
	return ""

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func integer(value: Variant, low: int, high: int) -> bool:
	return number(value, low, high) and float(value) == floorf(float(value))

static func text_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 200

static func local_point(value: Variant, anchor: Array) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component: Variant in value:
		if not number(component, -1e7, 1e7):
			return false
	return Home.vector(value).distance_to(Home.vector(anchor)) <= 22.0
