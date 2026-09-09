extends RefCounted
## Contract 3: synchronous observations of completed village work, never commands.
## The save owns both this bounded evidence ledger and the village it describes.
const Rules = preload("res://core/progression/behavior_catalog.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const EconomyProgress = preload("res://core/progression/tribal_economy_progress.gd")
const Neighbor = preload("res://world/tribe/neighbors/neighbor_state.gd")
const SCHEMA: int = 3
const COUNTERS: Array[String] = ["delivered", "meals", "tools", "huts", "garden"]
const MILESTONES: Dictionary = {
	"neighbor_help": {"name": "Gute Nachbarn", "description": "Mindestens zwei Bewohner liefern gemeinsam 6 Nahrung und 4 Holz an eine Nachbarfraktion deiner Spezies. Deren Bewohner stellen die Unterkunft fertig.", "points": 3},
	"sustained_supply": {"name": "Dauerhaft versorgt", "description": "180 Spielsekunden gesicherte Versorgung mit erneuerbarer Nahrung und Wasser, echten Mahlzeiten/Trinkvorgängen aller Bewohner und Vorräten von 12 Nahrung sowie 6 Wasser.", "points": 3},
	"working_professions": {"name": "Verlässliche Berufe", "description": "Mindestens zwei Bewohner erledigen in zwei verschiedenen Berufen jeweils drei erneuerbare Arbeits- und Lieferzyklen.", "points": 3},
	"shared_stock": {"name": "Gemeinsame Vorräte", "description": "Mindestens zwei Bewohner bringen zusammen acht Rohstoffe ins Lager.", "points": 3},
	"shared_tool": {"name": "Gemeinsames Handwerk", "description": "Mindestens zwei Bewohner arbeiten am selben fertigen Steinwerkzeug.", "points": 3},
	"shared_hut": {"name": "Ein Dach für die Gruppe", "description": "Mindestens zwei Bewohner bauen gemeinsam eine Hütte fertig.", "points": 4},
	"shared_garden": {"name": "Gemeinsamer Anbau", "description": "Mindestens zwei Bewohner legen gemeinsam einen Wurzelgarten an.", "points": 4},
	"shared_meals": {"name": "Die Gruppe versorgt", "description": "Zwei Bewohner liefern zusammen mindestens drei Nahrung; alle drei Bewohner essen danach aus dem Lager.", "points": 4},
}
const NODES: Dictionary = {
	"tribe.social.teamwork": {"name": "Arbeitsteilung", "phase": 1, "track": "social", "cost": 3, "requires": [],
		"effects": {"group_cooperation": 0.10}, "legacy": {}, "description": "Dorfaufgaben werden im Stamm um 10 % schneller erledigt."},
	"tribe.social.practice": {"name": "Eingespielte Gemeinschaft", "phase": 1, "track": "social", "cost": 5, "requires": ["tribe.social.teamwork"],
		"effects": {"group_cooperation": 0.10}, "legacy": {}, "description": "Weitere 10 % auf die Arbeitsrate im Stamm. Keine zusätzliche Produktion ohne Arbeit und Transport."},
}
var data: Dictionary = defaults()

static func defaults() -> Dictionary:
	return {"schema": SCHEMA, "campaign_id": "", "species_id": "", "faction_id": "", "villages": {}, "awards": {}, "purchases": {}}

func reset() -> void:
	data = defaults()

func export_state() -> Dictionary:
	return data.duplicate(true)

func import_state(value: Dictionary) -> bool:
	if not validate(value).is_empty():
		return false
	data = value.duplicate(true)
	data["schema"] = SCHEMA
	for entry: Dictionary in data["villages"].values():
		if not entry.has("economy"):
			entry["economy"] = {}
	return true

func wallet() -> Dictionary:
	var earned: int = 0
	var spent: int = 0
	for id: String in data["awards"]:
		earned += int(MILESTONES[id]["points"])
	for id: String in data["purchases"]:
		spent += int(NODES[id]["cost"])
	return {"earned": {"social": earned, "aggression": 0}, "spent": {"social": spent, "aggression": 0},
		"available": {"social": earned - spent, "aggression": 0}, "earning_cap": 27}

func can_purchase(id: String, phase: int) -> Dictionary:
	if not NODES.has(id):
		return {"ok": false, "reason": "unknown_node"}
	if phase < 1:
		return {"ok": false, "reason": "future_phase"}
	if data["purchases"].has(id):
		return {"ok": false, "reason": "already_purchased"}
	for required: String in NODES[id]["requires"]:
		if not data["purchases"].has(required):
			return {"ok": false, "reason": "prerequisite_missing"}
	if int(wallet()["available"]["social"]) < int(NODES[id]["cost"]):
		return {"ok": false, "reason": "insufficient_points"}
	return {"ok": true, "phase": 1, "node_id": id, "track": "social", "cost": NODES[id]["cost"]}

func purchase(id: String, phase: int) -> Dictionary:
	var receipt: Dictionary = can_purchase(id, phase)
	if receipt["ok"]:
		data["purchases"][id] = true
	return receipt

func nodes(phase: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in NODES:
		var node: Dictionary = NODES[id].duplicate(true)
		node.merge({"id": id, "purchased": data["purchases"].has(id), "purchase_status": can_purchase(id, phase)})
		result.append(node)
	return result

func effect_bonus(effect_id: String, phase: int) -> float:
	var bonus: float = 0.0
	if phase == 1:
		for id: String in data["purchases"]:
			bonus += float(NODES[id]["effects"].get(effect_id, 0.0))
	return bonus

func goals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in MILESTONES:
		var goal: Dictionary = MILESTONES[id].duplicate(true)
		goal.merge({"id": id, "completed": data["awards"].has(id)})
		result.append(goal)
	return result

## before/after must enclose ONE resident's arrived work step. A UI action is not evidence.
func observe(before: Dictionary, after: Dictionary, actor_id: String, body: Dictionary, campaign: Dictionary, phase: int) -> Dictionary:
	var rejected: Dictionary = {"changed": false, "rewards": []}
	if phase != 1 or before.get("id") != after.get("id") or not Tribe.validate(before, body, campaign).is_empty() or not Tribe.validate(after, body, campaign).is_empty():
		return rejected
	if not data["campaign_id"].is_empty() and not matches_campaign(campaign):
		return rejected
	var previous: Dictionary = {}
	var member: Dictionary = {}
	for candidate: Dictionary in before["members"]:
		if candidate["id"] == actor_id:
			previous = candidate
	for candidate: Dictionary in after["members"]:
		if candidate["id"] == actor_id:
			member = candidate
	if previous.is_empty() or member.is_empty() or previous["order"] == "wait":
		return rejected
	var id: String = after["id"]
	var entry: Dictionary = data["villages"].get(id, {})
	if entry.is_empty():
		if data["villages"].size() >= 128:
			return rejected
		entry = {"body_id": after["body_id"], "members": [], "cursors": {}, "deliveries": {}, "food": {}, "fed": {}, "project": {}, "economy": {}}
		for resident: Dictionary in after["members"]:
			entry["members"].append(resident["id"])
		for counter: String in COUNTERS:
			entry["cursors"][counter] = int(before.get(counter, 0))
	else:
		entry = entry.duplicate(true)
	var original: Dictionary = entry.duplicate(true)
	# Housing adds real citizens after the first work observation. Retain earlier
	# contributors and admit only IDs from the fully validated current village.
	for resident: Dictionary in after["members"]:
		if resident["id"] not in entry["members"]:
			entry["members"].append(resident["id"])
	var completed: Array[String] = []
	if EconomyProgress.supported(after):
		if entry["economy"].is_empty():
			entry["economy"] = EconomyProgress.create(before)
		EconomyProgress.observe_work(entry["economy"], before, after, previous, member)
		if EconomyProgress.progress(entry["economy"], after)["professions"]["met"]:
			completed.append("working_professions")
	var cargo: String = previous["cargo"]
	if not cargo.is_empty() and member["cargo"].is_empty() and int(after["delivered"]) == int(before["delivered"]) + 1 and int(after["delivered"]) > int(entry["cursors"]["delivered"]) and int(after["stock"].get(cargo, 0)) == int(before["stock"].get(cargo, 0)) + 1:
		entry["cursors"]["delivered"] = int(after["delivered"])
		entry["deliveries"][actor_id] = mini(8, int(entry["deliveries"].get(actor_id, 0)) + 1)
		if cargo in ["food", "milk"]:
			entry["food"][actor_id] = mini(3, int(entry["food"].get(actor_id, 0)) + 1)
		if entry["deliveries"].size() >= 2 and _sum(entry["deliveries"]) >= 8:
			completed.append("shared_stock")
	if int(after["meals"]) == int(before["meals"]) + 1 and int(after["meals"]) > int(entry["cursors"]["meals"]) and _food(after) == _food(before) - 1 and float(member["hunger"]) > float(previous["hunger"]):
		entry["cursors"]["meals"] = int(after["meals"])
		if entry["food"].size() >= 2 and _sum(entry["food"]) >= 3:
			entry["fed"][actor_id] = 1
			if entry["fed"].size() >= 3:
				completed.append("shared_meals")
	var project: Dictionary = before["project"]
	if not project.is_empty() and project["kind"] in ["tool", "hut", "garden"] and (project["kind"] == previous["order"] or previous["order"] == "build") and cargo.is_empty():
		var kind: String = project["kind"]
		var counter: String = {"tool": "tools", "hut": "huts", "garden": "garden"}[kind]
		var project_id: String = "%s:%d" % [kind, int(before[counter])]
		var done: bool = after["project"].is_empty() and int(after[counter]) == int(before[counter]) + 1
		var progress: float = float(Tribe.WORK[kind]) if done else float(after["project"].get("progress", 0.0))
		if progress > float(project["progress"]) and int(entry["cursors"][counter]) <= int(before[counter]):
			if entry["project"].get("id", "") != project_id:
				entry["project"] = {"id": project_id, "progress": float(project["progress"]), "contributors": {}}
			if progress > float(entry["project"]["progress"]):
				entry["project"]["progress"] = progress
				entry["project"]["contributors"][actor_id] = 1
			if done:
				if entry["project"]["contributors"].size() >= 2:
					completed.append("shared_" + kind)
				entry["cursors"][counter] = int(after[counter])
				entry["project"] = {}
	if original == entry:
		return rejected
	data["campaign_id"] = campaign["id"]
	data["species_id"] = campaign["player_species_id"]
	data["faction_id"] = campaign["player_faction_id"]
	data["villages"][id] = entry
	var rewards: Array[Dictionary] = []
	for goal: String in completed:
		if data["awards"].has(goal):
			continue # Campaign-wide once, even across planets or replaced event cursors.
		data["awards"][goal] = {"village_id": id}
		rewards.append({"ok": true, "phase": 1, "track": "social", "amount": MILESTONES[goal]["points"], "outcome": goal, "available": wallet()["available"]["social"]})
	return {"changed": true, "rewards": rewards}

## Called once per active simulation step, after the village has updated.
func observe_supply(village: Dictionary, body: Dictionary, campaign: Dictionary, phase: int, delta: float) -> Dictionary:
	var result: Dictionary = {"changed": false, "rewards": []}
	if phase != 1 or not is_finite(delta) or delta <= 0.0 or not EconomyProgress.supported(village) or not Tribe.validate(village, body, campaign).is_empty() or not matches_campaign(campaign):
		return result
	# Work observations own the resident identities and initialize from real counters.
	var entry: Dictionary = data["villages"].get(village["id"], {})
	if entry.is_empty() or entry.get("economy", {}).is_empty():
		return result
	result["changed"] = EconomyProgress.tick(entry["economy"], village, delta)
	if EconomyProgress.progress(entry["economy"], village)["supply"]["met"] and not data["awards"].has("sustained_supply"):
		data["awards"]["sustained_supply"] = {"village_id": village["id"]}
		result["changed"] = true
		result["rewards"].append({"ok": true, "phase": 1, "track": "social", "amount": 3, "outcome": "sustained_supply", "available": wallet()["available"]["social"]})
	return result

func economy_progress(village: Dictionary) -> Dictionary:
	var entry: Dictionary = data["villages"].get(village.get("id", ""), {})
	return EconomyProgress.progress(entry.get("economy", {}), village)

func observe_neighbor(before: Dictionary, after: Dictionary, village: Dictionary, campaign: Dictionary, phase: int) -> Dictionary:
	var result: Dictionary = {"changed": false, "rewards": []}
	if phase != 1 or not matches_campaign(campaign) or data["awards"].has("neighbor_help") or not data["villages"].has(village.get("id")):
		return result
	if not Neighbor.validate(before, village, campaign).is_empty() or not Neighbor.validate(after, village, campaign).is_empty() or before["aid"]["status"] != "building" or after["aid"]["status"] != "completed" or before["aid"]["id"] != after["aid"]["id"]:
		return result
	data["awards"]["neighbor_help"] = {"village_id": village["id"], "neighbor_id": after["id"], "agreement_id": after["aid"]["id"]}
	result["changed"] = true
	result["rewards"].append({"ok": true, "phase": 1, "track": "social", "amount": 3, "outcome": "neighbor_help", "available": wallet()["available"]["social"]})
	return result

static func _food(village: Dictionary) -> int:
	return int(village["stock"].get("food", 0)) + int(village["stock"].get("milk", 0))

func matches_campaign(campaign: Dictionary) -> bool:
	return data["campaign_id"].is_empty() or (data["campaign_id"] == campaign.get("id") and data["species_id"] == campaign.get("player_species_id") and data["faction_id"] == campaign.get("player_faction_id"))

static func _sum(values: Dictionary) -> int:
	var total: int = 0
	for value: Variant in values.values():
		total += int(value)
	return total

static func has_unsupported_contract(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if Rules.is_newer_version(value.get("schema"), SCHEMA):
		return true
	if value.get("villages") is Dictionary:
		for entry: Variant in value["villages"].values():
			if entry is Dictionary and entry.get("economy") is Dictionary and Rules.is_newer_version(entry["economy"].get("schema"), EconomyProgress.SCHEMA):
				return true
	return false

static func validate(value: Variant) -> String:
	if not value is Dictionary or not Rules.is_integer(value.get("schema"), 1, SCHEMA):
		return "Nicht unterstützter Stammesfortschritt."
	for key: String in ["campaign_id", "species_id", "faction_id"]:
		if not value.get(key) is String or value[key].length() > 256:
			return "Ungültige Fortschrittsidentität."
	for key: String in ["villages", "awards", "purchases"]:
		if not value.get(key) is Dictionary:
			return "Ungültiger Gemeinschaftsnachweis."
	if value["villages"].size() > 128 or value["awards"].size() > MILESTONES.size() or value["purchases"].size() > NODES.size():
		return "Gemeinschaftsnachweis überschreitet seine Grenze."
	if value["campaign_id"].is_empty():
		return "" if value["species_id"].is_empty() and value["faction_id"].is_empty() and value["villages"].is_empty() and value["awards"].is_empty() and value["purchases"].is_empty() else "Fortschritt ohne Kampagne."
	if value["species_id"].is_empty() or value["faction_id"].is_empty():
		return "Fortschritt ohne eigene Spezies und Fraktion."
	for id: Variant in value["villages"]:
		var village: Variant = value["villages"][id]
		if not id is String or id.is_empty() or id.length() > 256 or not village is Dictionary or not village.get("body_id") is String or village["body_id"].is_empty():
			return "Ungültiger Fortschrittsort."
		if not village.get("members") is Array or village["members"].is_empty() or village["members"].size() > 128:
			return "Ungültige Mitwirkende."
		var unique: Dictionary = {}
		for member: Variant in village["members"]:
			if not member is String or member.is_empty() or member.length() > 256 or unique.has(member):
				return "Ungültiger Bewohnernachweis."
			unique[member] = true
		if int(value["schema"]) >= 2 and not village.has("economy"):
			return "Wirtschaftsnachweis fehlt."
		var economy_problem: String = EconomyProgress.validate(village.get("economy", {}), unique)
		if not economy_problem.is_empty():
			return economy_problem
		if not village.get("cursors") is Dictionary or village["cursors"].size() != COUNTERS.size():
			return "Ungültige Arbeitszähler."
		for counter: String in COUNTERS:
			if not Rules.is_integer(village["cursors"].get(counter), 0, 1000000000):
				return "Ungültiger Arbeitszähler."
		for key: String in ["deliveries", "food", "fed"]:
			if not _valid_contributions(village.get(key), unique, 8 if key == "deliveries" else 3 if key == "food" else 1):
				return "Ungültige Lieferungs- oder Versorgungsnachweise."
		var project: Variant = village.get("project")
		if not project is Dictionary:
			return "Ungültiger Arbeitsnachweis."
		if not project.is_empty():
			if project.get("id") not in ["tool:0", "hut:0", "hut:1", "garden:0"] or not Tribe.number(project.get("progress"), 0, 20) or not _valid_contributions(project.get("contributors"), unique, 1):
				return "Ungültige Gemeinschaftsbaustelle."
	var earned: int = 0
	for id: Variant in value["awards"]:
		var award: Variant = value["awards"][id]
		if not MILESTONES.has(id) or not award is Dictionary or not value["villages"].has(award.get("village_id", "")):
			return "Ungültiger Stammesverdienst."
		if id in ["sustained_supply", "working_professions"]:
			if int(value["schema"]) < 2 or value["villages"][award["village_id"]].get("economy", {}).is_empty():
				return "Wirtschaftserfolg ohne Nachweis."
		if id == "neighbor_help" and (int(value["schema"]) < 3 or not award.get("neighbor_id") is String or not award.get("agreement_id") is String or award["neighbor_id"].is_empty() or award["agreement_id"].is_empty()):
			return "Nachbarhilfe ohne Fraktion und Vereinbarung."
		earned += int(MILESTONES[id]["points"])
	var spent: int = 0
	for id: Variant in value["purchases"]:
		if not NODES.has(id) or not value["purchases"][id] is bool or not value["purchases"][id]:
			return "Ungültiger Stammeskauf."
		for required: String in NODES[id]["requires"]:
			if not value["purchases"].has(required):
				return "Stammeskauf ohne Voraussetzung."
		spent += int(NODES[id]["cost"])
	return "" if spent <= earned else "Stammespunkte mehrfach ausgegeben."

static func _valid_contributions(value: Variant, members: Dictionary, maximum: int) -> bool:
	if not value is Dictionary or value.size() > members.size():
		return false
	for id: Variant in value:
		if not members.has(id) or not Rules.is_integer(value[id], 1, maximum):
			return false
	return true
