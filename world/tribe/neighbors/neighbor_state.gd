extends RefCounted
## One local own-species faction and a conserved, finite aid shipment.
const Rules = preload("res://core/progression/behavior_catalog.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const SCHEMA: int = 3
const LEGACY_SCHEMA: int = 2
const COST: Dictionary = {"food": 6, "wood": 4}
const BUILD_SECONDS: float = 12.0
const NAV_EXTENT: int = 18
const SITE_RADIUS: float = 16.0
const MEMBER_RADIUS: float = 22.0

static func faction_id(campaign: Dictionary, body_id: String) -> String:
	return Ids.scoped("faction", campaign["player_species_id"], body_id + ":neighbor:0")

static func create(campaign: Dictionary, village: Dictionary, center: Variant, places: Array, foundation: Array = []) -> Dictionary:
	var id: String = faction_id(campaign, village["body_id"])
	var people: Array[Dictionary] = []
	for index in range(2):
		people.append({"id": Ids.scoped("object", id, "resident:" + str(index)), "name": "Nachbar " + str(index + 1),
			"position": Home.place(places[index]), "workplace": Home.place(places[index]), "blocked": false, "walk": 0})
	if foundation.is_empty():
		for corner: Vector3 in [Vector3(-1,0,-1), Vector3(1,0,-1), Vector3(-1,0,1), Vector3(1,0,1)]:
			foundation.append(Home.offset_place(Home.place(center), corner))
	return {"schema": SCHEMA if center is Dictionary else LEGACY_SCHEMA, "id": id, "species_id": campaign["player_species_id"], "body_id": village["body_id"],
		"village_id": village["id"], "name": "Uferbund", "phase": 1, "technology": {"shelter": 0}, "relation": "neutral",
		"anchor": Home.place(center), "foundation": foundation.duplicate(true), "members": people, "stock": {"food": 0, "wood": 0},
		"aid": {"id": Ids.scoped("agreement", id, "first_shelter"), "status": "offered", "received": {"food": 0, "wood": 0},
			"withdrawn": {"food": 0, "wood": 0}, "returned": {"food": 0, "wood": 0}, "carriers": {}, "shipments": {}, "build_seconds": 0.0, "builders": {}}}

static func in_transit(data: Dictionary, kind: String) -> int:
	var count: int = 0
	for shipment: Dictionary in data["aid"]["shipments"].values():
		count += 1 if shipment["resource"] == kind else 0
	return count

static func begin(data: Dictionary, village: Dictionary, selected: Array) -> String:
	if data["aid"]["status"] not in ["offered", "active"]:
		return "Diese Hilfslieferung ist bereits abgeschlossen."
	if selected.size() < 2:
		return "Wähle mindestens zwei Bewohner für die gemeinsame Hilfslieferung."
	for id: String in selected:
		var member: Dictionary = resident(village, id)
		if member.is_empty() or not member["cargo"].is_empty() or data["aid"]["shipments"].has(id):
			return "Ausgewählte Bewohner müssen ihre laufende Fracht oder Hilfslieferung zuerst beenden."
	data["aid"]["status"] = "active"
	data["schema"] = SCHEMA if data.anchor is Dictionary else LEGACY_SCHEMA
	for id: String in selected:
		var member: Dictionary = resident(village, id)
		member["order"] = "move"
		member["destination"] = village["anchor"].duplicate()
		member["paused_order"] = ""
		member["work"] = 0.0
		member["stage"] = "outbound"
		data["aid"]["shipments"][id] = {"leg": "collect", "resource": ""}
	return ""

static func resident(village: Dictionary, id: String) -> Dictionary:
	for member: Dictionary in village["members"]:
		if member["id"] == id:
			return member
	return {}

static func target(data: Dictionary, village: Dictionary, member: Dictionary) -> Variant:
	var shipment: Dictionary = data["aid"]["shipments"].get(member["id"], {})
	if shipment.is_empty() or member["order"] == "wait":
		return Vector3.INF
	# A new order cancels only future aid pickups. Real carried goods return home
	# before that order proceeds, including across a save between command and tick.
	if member["order"] != "move" or member["destination"] != village["anchor"]:
		if shipment["resource"].is_empty():
			data["aid"]["shipments"].erase(member["id"])
			return Vector3.INF
		shipment["leg"] = "return"
	if member["stage"] in ["meal", "drink"] and member["cargo"].is_empty():
		return Vector3.INF
	var result: Variant = data["anchor"] if shipment["leg"] == "deliver" else village["anchor"]
	return Home.vector(result) if result is Array else result

## Called only after the shared movement controller reached the selected target.
static func work(data: Dictionary, village: Dictionary, member: Dictionary) -> bool:
	var aid: Dictionary = data["aid"]
	var shipment: Dictionary = aid["shipments"].get(member["id"], {})
	if shipment.is_empty() or member["order"] == "wait" or (member["stage"] in ["meal", "drink"] and member["cargo"].is_empty()):
		return false
	var point: Variant = data["anchor"] if shipment["leg"] == "deliver" else village["anchor"]
	if Home.distance(member["position"], point) > 2.9:
		return true
	var kind: String = shipment["resource"]
	if not kind.is_empty():
		if member["cargo"] != kind:
			return true
		if shipment["leg"] == "return":
			village["stock"][kind] += 1
			aid["returned"][kind] += 1
			aid["shipments"].erase(member["id"])
		else:
			data["stock"][kind] += 1
			aid["received"][kind] += 1
			aid["carriers"][member["id"]] = int(aid["carriers"].get(member["id"], 0)) + 1
			shipment["resource"] = ""
			shipment["leg"] = "collect"
		member["cargo"] = ""
		member["stage"] = "outbound"
		if _received_all(aid):
			aid["status"] = "building"
		return true
	# Five units per person make a completed ten-unit delivery require real
	# cooperation; another resident can take over if one carrier stays paused.
	if int(aid["carriers"].get(member["id"], 0)) >= 5 or aid["status"] != "active":
		aid["shipments"].erase(member["id"])
		member["order"] = "wait"
		return true
	for resource: String in COST:
		if int(aid["received"][resource]) + in_transit(data, resource) >= int(COST[resource]):
			continue
		# Keep a food buffer for the home village. Empty reserves retain the job.
		if int(village["stock"][resource]) <= (6 if resource == "food" else 0):
			continue
		village["stock"][resource] -= 1
		aid["withdrawn"][resource] += 1
		shipment["leg"] = "deliver"
		shipment["resource"] = resource
		member["cargo"] = resource
		member["stage"] = "return"
		break
	return true

static func build(data: Dictionary, member_id: String, delta: float) -> bool:
	var aid: Dictionary = data["aid"]
	if aid["status"] != "building" or not is_finite(delta) or delta <= 0.0:
		return false
	var builder: Dictionary = resident(data, member_id)
	if builder.is_empty() or Home.distance(builder["position"], builder["workplace"]) > 0.75:
		return false
	aid["build_seconds"] = minf(BUILD_SECONDS, float(aid["build_seconds"]) + delta * 0.5)
	aid["builders"][member_id] = true
	if float(aid["build_seconds"]) >= BUILD_SECONDS and aid["builders"].size() == 2:
		data["stock"]["wood"] -= 4
		data["technology"]["shelter"] = 1
		data["relation"] = "friendly"
		aid["status"] = "completed"
	return true

static func progress(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {"met": false, "text": "Noch kein Nachbarlager kontaktiert."}
	var aid: Dictionary = data["aid"]
	return {"met": aid["status"] == "completed", "text": "%s · Nahrung %d/6 · Holz %d/4 · Mitwirkende %d · Unterkunft %d %%" % [data["name"], aid["received"]["food"], aid["received"]["wood"], aid["carriers"].size(), roundi(float(aid["build_seconds"]) / BUILD_SECONDS * 100)]}

static func has_unsupported_contract(data: Variant) -> bool:
	return data is Dictionary and (Rules.is_newer_version(data.get("schema"), SCHEMA) or (data.get("schema") == SCHEMA and not data.get("anchor") is Dictionary))

static func validate(data: Variant, village: Dictionary, campaign: Dictionary) -> String:
	if not data is Dictionary or not Rules.is_integer(data.get("schema"), 1, SCHEMA) or village.is_empty():
		return "Nicht unterstütztes Nachbarlager."
	if village.anchor is Dictionary and data.schema != SCHEMA: return "Radiales Nachbarlager benötigt Format 3."
	if data.schema == SCHEMA and not village.anchor is Dictionary: return "Radiales Nachbarlager benötigt einen Kugelheimatort."
	var id: String = faction_id(campaign, village["body_id"])
	if data.get("id") != id or data.get("species_id") != campaign["player_species_id"] or data.get("id") == campaign["player_faction_id"] or data.get("body_id") != village["body_id"] or data.get("village_id") != village["id"] or data.get("phase") != 1 or data.get("name") != "Uferbund":
		return "Nachbarfraktion und eigene Spezies stimmen nicht überein."
	if not _point(data.get("anchor"), village["anchor"], SITE_RADIUS) or not data.get("members") is Array or data["members"].size() != 2:
		return "Ungültiger Nachbarort."
	if not data.get("foundation") is Array or data["foundation"].size() != 4:
		return "Ungültige Bodenauflagen."
	var corners: Array[Vector3] = [Vector3(-1,0,-1), Vector3(1,0,-1), Vector3(-1,0,1), Vector3(1,0,1)]
	for index in range(4):
		var point: Variant = data["foundation"][index]
		if not _point(point, village["anchor"]) or Home.distance(point, Home.offset_place(data["anchor"], corners[index])) > 0.75:
			return "Nachbarunterkunft ohne passende Bodenauflagen."
	var neighbors: Dictionary = {}
	for index in range(2):
		var member: Variant = data["members"][index]
		if not member is Dictionary or member.get("id") != Ids.scoped("object", id, "resident:" + str(index)) or member.get("name") != "Nachbar " + str(index + 1) or not _point(member.get("position"), village["anchor"]) or not _point(member.get("workplace"), village["anchor"]) or not member.get("blocked") is bool or not Rules.is_integer(member.get("walk"), 0, 1):
			return "Ungültiger Nachbarbewohner."
		neighbors[member["id"]] = true
	var aid: Variant = data.get("aid")
	if not aid is Dictionary or aid.get("id") != Ids.scoped("agreement", id, "first_shelter") or aid.get("status") not in ["offered", "active", "building", "completed"]:
		return "Ungültige Hilfsvereinbarung."
	for key: String in ["received", "withdrawn", "returned", "carriers", "shipments", "builders"]:
		if not aid.get(key) is Dictionary:
			return "Ungültiges Lieferbuch."
	var carrier_limit: int = 6 if int(data["schema"]) >= 2 else 3
	if aid["shipments"].size() > carrier_limit or aid["carriers"].size() > carrier_limit or aid["builders"].size() > 2:
		return "Lieferbuch überschreitet seine Grenze."
	var carried: Dictionary = {"food": 0, "wood": 0}
	for actor: Variant in aid["shipments"]:
		var shipment: Variant = aid["shipments"][actor]
		var member: Dictionary = resident(village, str(actor))
		if member.is_empty() or not shipment is Dictionary or shipment.get("leg") not in ["collect", "deliver", "return"] or shipment.get("resource") not in ["", "food", "wood"] or shipment["resource"] != member["cargo"]:
			return "Hilfsfracht und Bewohner stimmen nicht überein."
		if shipment["resource"].is_empty() != (shipment["leg"] == "collect"):
			return "Ungültiger Transportabschnitt."
		if not shipment["resource"].is_empty():
			carried[shipment["resource"]] += 1
	var total: int = 0
	for actor: Variant in aid["carriers"]:
		if resident(village, str(actor)).is_empty() or not Rules.is_integer(aid["carriers"][actor], 1, 5):
			return "Ungültiger Mitwirkender."
		total += int(aid["carriers"][actor])
	if not data.get("stock") is Dictionary or not data.get("technology") is Dictionary or not _number(aid.get("build_seconds"), 0.0, BUILD_SECONDS):
		return "Ungültiger Nachbarbestand."
	var complete: bool = aid["status"] == "completed"
	for resource: String in COST:
		if not Rules.is_integer(aid["received"].get(resource), 0, COST[resource]) or not Rules.is_integer(aid["withdrawn"].get(resource), 0, 1000000000) or not Rules.is_integer(aid["returned"].get(resource), 0, 1000000000):
			return "Ungültige Liefermenge."
		if int(aid["withdrawn"][resource]) != int(aid["received"][resource]) + int(aid["returned"][resource]) + int(carried[resource]) or int(aid["received"][resource]) + int(carried[resource]) > int(COST[resource]) or data["stock"].get(resource) != int(aid["received"][resource]) - (4 if complete and resource == "wood" else 0):
			return "Hilfswaren wurden vervielfacht oder verloren."
	if total != int(aid["received"]["food"]) + int(aid["received"]["wood"]):
		return "Lieferquittungen passen nicht zum Ziellager."
	for builder: Variant in aid["builders"]:
		if not neighbors.has(builder) or not aid["builders"][builder] is bool or not aid["builders"][builder]:
			return "Ungültige Nachbarbauarbeit."
	if data["technology"].get("shelter") != (1 if complete else 0) or data.get("relation") != ("friendly" if complete else "neutral"):
		return "Beziehung oder Technik ohne erfüllte Hilfe."
	if aid["status"] in ["building", "completed"]:
		if not _received_all(aid) or aid["carriers"].size() < 2:
			return "Unterkunft ohne Gemeinschaftslieferung."
	elif float(aid["build_seconds"]) != 0.0 or not aid["builders"].is_empty():
		return "Bau begann ohne Waren."
	if complete and (float(aid["build_seconds"]) != BUILD_SECONDS or aid["builders"].size() != 2):
		return "Unterkunft ohne fertige Bauarbeit."
	if aid["status"] == "offered" and (total != 0 or not aid["shipments"].is_empty() or int(aid["withdrawn"]["food"]) != 0 or int(aid["withdrawn"]["wood"]) != 0):
		return "Hilfslieferung ohne begonnenen Auftrag."
	return ""

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _received_all(aid: Dictionary) -> bool:
	return int(aid["received"]["food"]) == 6 and int(aid["received"]["wood"]) == 4

static func _point(value: Variant, anchor: Variant, limit: float = MEMBER_RADIUS) -> bool:
	return Home.local_place(value, anchor, limit)
