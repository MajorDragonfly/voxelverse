extends RefCounted
## The village owns its original residents, deposits and outstanding work.
## Orders and cargo live in the same save snapshot as stock and construction.
const Home = preload("res://world/home_group/home_group_state.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const SCHEMA: int = 2
const KINDS: Array[String] = ["wood", "stone", "food"]
const ORDERS: Array[String] = ["wait", "move", "wood", "stone", "food", "tool", "hut", "feed", "garden", "supply"]
const COSTS: Dictionary = {"tool": {"wood": 3, "stone": 2}, "hut": {"wood": 6, "stone": 3}, "garden": {"wood": 4, "stone": 1}}
const WORK: Dictionary = {"tool": 10.0, "hut": 20.0, "garden": 15.0}
const STORAGE: int = 48
const FOOD_TARGET: int = 12
const GROW_SECONDS: float = 20.0
const GARDEN_CAPACITY: int = 8

static func create(home: Dictionary, campaign: Dictionary, player: Dictionary, sites: Dictionary) -> Dictionary:
	var members: Array = []
	var originals: Array = [{"id": campaign["player_object_id"], "name": "Deine Kreatur", "position": player["position"]}]
	originals.append_array(home["members"])
	for original: Dictionary in originals:
		members.append({"id": original["id"], "name": original["name"], "position": original["position"].duplicate(),
			"order": "wait", "destination": original["position"].duplicate(), "stage": "outbound", "work": 0.0,
			"cargo": "", "hunger": clampf(float(player.get("hunger_ratio", 1.0)) * 100.0, 0.0, 100.0) if members.is_empty() else 75.0})
	var deposits: Dictionary = {}
	for kind: String in KINDS:
		deposits[kind] = {"id": Ids.scoped("resource", home["id"], kind), "position": sites[kind].duplicate(), "remaining": 48}
	return {"schema": SCHEMA, "id": Ids.scoped("tribe", home["id"], "settled"), "home_group_id": home["id"],
		"body_id": home["body_id"], "species_id": home["species_id"], "faction_id": campaign["player_faction_id"],
		"anchor": home["anchor"].duplicate(), "members": members, "deposits": deposits,
		"stock": {"wood": 0, "stone": 0, "food": 0}, "tools": 0, "huts": 0,
		"sites": sites["huts"].duplicate(true), "project": {}, "delivered": 0, "meals": 0,
		"garden": 0, "growth": 0.0, "grown": 0}

static func upgrade(data: Dictionary) -> bool:
	# Call only after validation. Old jobs, cargo and all finite stock stay intact.
	if int(data.get("schema", 0)) != 1:
		return false
	data.merge({"garden": 0, "growth": 0.0, "grown": 0}, true)
	data["schema"] = SCHEMA
	return true

static func cargo_count(data: Dictionary, kind: String) -> int:
	var count: int = 0
	for member: Dictionary in data["members"]:
		count += 1 if member["cargo"] == kind else 0
	return count

static func available_storage(data: Dictionary, kind: String) -> int:
	return STORAGE - int(data["stock"][kind]) - cargo_count(data, kind)

static func grow(data: Dictionary, delta: float) -> bool:
	# Simulation time only: no harvest on load, wall clock or while paused.
	if int(data["garden"]) == 0 or int(data["deposits"]["food"]["remaining"]) >= GARDEN_CAPACITY:
		return false
	data["growth"] = float(data["growth"]) + delta
	var changed: bool = false
	while float(data["growth"]) >= GROW_SECONDS and int(data["deposits"]["food"]["remaining"]) < GARDEN_CAPACITY:
		data["growth"] -= GROW_SECONDS
		data["deposits"]["food"]["remaining"] += 1
		data["grown"] += 1
		changed = true
	if int(data["deposits"]["food"]["remaining"]) >= GARDEN_CAPACITY:
		data["growth"] = 0.0
	return changed

static func validate(value: Variant, body: Dictionary, campaign: Dictionary) -> String:
	if not value is Dictionary or not integer(value.get("schema"), 1, SCHEMA):
		return "Nicht unterstützter Stammesstand."
	var renewable: bool = int(value["schema"]) >= 2
	if renewable and (not integer(value.get("garden"), 0, 1) or not number(value.get("growth"), 0, GROW_SECONDS) or not integer(value.get("grown"), 0, 1000000000)):
		return "Ungültiger Gartenstand."
	if renewable and int(value["garden"]) == 0 and (float(value["growth"]) != 0 or int(value["grown"]) != 0):
		return "Nahrung wächst erst nach dem Gartenbau."
	var home: Variant = body.get("home_group")
	if not Home.validate(home, str(body.get("id", "")), str(campaign.get("player_species_id", ""))).is_empty():
		return "Dem Stamm fehlt seine ursprüngliche Nestgruppe."
	if value.get("home_group_id") != home["id"] or value.get("id") != Ids.scoped("tribe", home["id"], "settled") or value.get("body_id") != body["id"] or value.get("species_id") != campaign["player_species_id"] or value.get("faction_id") != campaign["player_faction_id"]:
		return "Stamm und Herkunft stimmen nicht überein."
	if value.get("anchor") != home["anchor"] or not point(value.get("anchor")):
		return "Ungültiger Dorfplatz."
	var members: Variant = value.get("members")
	if not members is Array or members.size() != 3:
		return "Der Stamm benötigt seine drei ursprünglichen Mitglieder."
	var ids: Array = [campaign["player_object_id"], home["members"][0]["id"], home["members"][1]["id"]]
	for i in range(3):
		var member: Variant = members[i]
		if not member is Dictionary or member.get("id") != ids[i] or not member.get("name") is String or member["name"].is_empty() or member["name"].length() > 32:
			return "Ungültiges Stammesmitglied."
		if not local_point(member.get("position"), value["anchor"]) or not local_point(member.get("destination"), value["anchor"]) or member.get("order") not in ORDERS or member.get("stage") not in ["outbound", "return", "meal"] or member.get("cargo") not in ["", "wood", "stone", "food"] or not number(member.get("work"), 0, 4) or not number(member.get("hunger"), 0, 100):
			return "Ungültiger Auftrag oder Zustand eines Bewohners."
		if not renewable and (member["order"] in ["garden", "supply"] or member["stage"] == "meal"):
			return "Versorgungsauftrag benötigt Stammesformat 2."
		if member["stage"] == "meal" and (member["cargo"] != "" or member["order"] in ["wait", "feed"]):
			return "Ungültige Essenspause."
	if not value.get("deposits") is Dictionary or not value.get("stock") is Dictionary:
		return "Ungültige Dorfvorräte."
	for kind: String in KINDS:
		var deposit: Variant = value["deposits"].get(kind)
		if not deposit is Dictionary or deposit.get("id") != Ids.scoped("resource", home["id"], kind) or not local_point(deposit.get("position"), value["anchor"]) or not integer(deposit.get("remaining"), 0, 48) or not integer(value["stock"].get(kind), 0, 48):
			return "Ungültiger Materialbestand."
		var carried: int = 0
		for member: Dictionary in members:
			carried += 1 if member["cargo"] == kind else 0
		var produced: int = int(value.get("grown", 0)) if kind == "food" and renewable else 0
		if int(deposit["remaining"]) + int(value["stock"][kind]) + carried > 48 + produced or int(value["stock"][kind]) + carried > STORAGE:
			return "Material wurde vervielfacht."
	for key in ["tools", "huts", "delivered", "meals"]:
		if not integer(value.get(key), 0, 1000000000 if renewable else 144):
			return "Ungültiger Dorffortschritt."
	if int(value["tools"]) > 1 or int(value["huts"]) > 2 or not value.get("sites") is Array or value["sites"].size() != 2:
		return "Ungültige Dorfgebäude."
	if renewable and int(value["garden"]) == 1 and int(value["tools"]) != 1:
		return "Ein Wurzelgarten benötigt ein Steinwerkzeug."
	for site: Variant in value["sites"]:
		if not local_point(site, value["anchor"]):
			return "Ungültiger Bauplatz."
	var project: Variant = value.get("project")
	if not project is Dictionary:
		return "Ungültige Baustelle."
	if not project.is_empty():
		if project.get("kind") not in ["tool", "hut", "garden"] or not number(project.get("progress"), 0, 20):
			return "Ungültiger Baufortschritt."
		if (project["kind"] == "tool" and int(value["tools"]) != 0) or (project["kind"] == "hut" and (int(value["tools"]) != 1 or int(value["huts"]) >= 2)):
			return "Baustelle ist bereits abgeschlossen oder ohne Werkzeug."
		if project["kind"] == "garden" and (not renewable or int(value["tools"]) != 1 or int(value["garden"]) != 0):
			return "Ungültiger Gartenbau."
	return ""

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func integer(value: Variant, low: int, high: int) -> bool:
	return number(value, low, high) and float(value) == floorf(float(value))

static func point(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component: Variant in value:
		if not number(component, -1.0e7, 1.0e7):
			return false
	return true

static func local_point(value: Variant, anchor: Array) -> bool:
	return point(value) and Home.vector(value).distance_to(Home.vector(anchor)) <= 22.0
