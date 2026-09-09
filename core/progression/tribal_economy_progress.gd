extends RefCounted
## Observes M6 work and active simulation. Never produces, consumes or transports.
const Economy = preload("res://world/tribe/village_economy.gd")
const Rules = preload("res://core/progression/behavior_catalog.gd")
const SCHEMA: int = 1
const SUPPLY_SECONDS: float = 180.0
const JOBS: Dictionary = {"provider": ["food", "water"], "forester": ["wood"], "mason": ["stone"], "weaver": ["fiber"]}
const SOURCES: Dictionary = {"water": "well", "wood": "forester", "stone": "quarry", "fiber": "fiberbed"}

static func supported(village: Dictionary) -> bool:
	return int(village.get("schema", 0)) == 3 and village.get("economy") is Dictionary and int(village["economy"].get("schema", 0)) == 1

static func create(village: Dictionary) -> Dictionary:
	return {"schema": SCHEMA, "delivery_cursor": int(village["delivered"]), "meal_cursor": int(village["meals"]),
		"drink_cursor": int(village["economy"]["drinks"]), "pending": {}, "jobs": {}, "fed": {}, "drunk": {}, "healthy_seconds": 0.0}

static func observe_work(record: Dictionary, before: Dictionary, after: Dictionary, previous: Dictionary, member: Dictionary) -> bool:
	var original: Dictionary = record.duplicate(true)
	var actor: String = member["id"]
	var cargo: String = previous["cargo"]
	var picked: String = member["cargo"]
	# An entire cycle must be witnessed: work at a renewable workplace, pickup,
	# and later delivery. Legacy cargo and changing professions earn no free work.
	if int(after["delivered"]) >= int(record["delivery_cursor"]) and cargo.is_empty() and not picked.is_empty() and picked in Economy.RESOURCES and picked != "milk":
		var profession: String = previous["profession"]
		if JOBS.has(profession) and picked in JOBS[profession] and previous["order"] == Economy.JOB_ORDER[profession] and _renewable(after, picked) and int(after["deposits"][picked]["remaining"]) == int(before["deposits"][picked]["remaining"]) - 1:
			record["pending"][actor] = {"resource": picked, "profession": profession, "source_id": after["deposits"][picked]["id"]}
	var sequence: int = int(after["delivered"])
	if sequence == int(before["delivered"]) + 1 and sequence > int(record["delivery_cursor"]) and not cargo.is_empty() and picked.is_empty() and int(after["stock"][cargo]) == int(before["stock"][cargo]) + 1:
		record["delivery_cursor"] = sequence
		var pending: Dictionary = record["pending"].get(actor, {})
		if pending.get("resource", "") == cargo:
			var profession: String = pending["profession"]
			if not record["jobs"].has(profession):
				record["jobs"][profession] = {"units": 0, "workers": {}}
			var job: Dictionary = record["jobs"][profession]
			job["units"] = mini(3, int(job["units"]) + 1)
			job["workers"][actor] = true
		record["pending"].erase(actor)
	var meals: int = int(after["meals"])
	if meals == int(before["meals"]) + 1 and meals > int(record["meal_cursor"]) and _food(after) == _food(before) - 1 and float(member["hunger"]) > float(previous["hunger"]):
		record["meal_cursor"] = meals
		record["fed"][actor] = true
	var drinks: int = int(after["economy"]["drinks"])
	if drinks == int(before["economy"]["drinks"]) + 1 and drinks > int(record["drink_cursor"]) and int(after["stock"]["water"]) == int(before["stock"]["water"]) - 1 and float(member["hydration"]) > float(previous["hydration"]):
		record["drink_cursor"] = drinks
		record["drunk"][actor] = true
	return original != record

static func tick(record: Dictionary, village: Dictionary, delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0:
		return false
	if not _healthy(village):
		var changed: bool = float(record["healthy_seconds"]) > 0.0 or not record["fed"].is_empty() or not record["drunk"].is_empty()
		record["healthy_seconds"] = 0.0
		record["fed"].clear()
		record["drunk"].clear()
		return changed
	var before: float = float(record["healthy_seconds"])
	record["healthy_seconds"] = minf(SUPPLY_SECONDS, before + delta)
	return before != float(record["healthy_seconds"])

static func progress(record: Dictionary, village: Dictionary) -> Dictionary:
	var ready_jobs: int = 0
	var workers: Dictionary = {}
	var job_details: PackedStringArray = []
	for profession: String in JOBS:
		var job: Dictionary = record.get("jobs", {}).get(profession, {})
		var units: int = int(job.get("units", 0))
		job_details.append("%s %d/3" % [Economy.JOBS[profession], units])
		if units >= 3:
			ready_jobs += 1
			workers.merge(job["workers"])
	var seconds: float = float(record.get("healthy_seconds", 0.0))
	var fed: int = record.get("fed", {}).size()
	var drunk: int = record.get("drunk", {}).size()
	var count: int = village.get("members", []).size()
	var food: int = _food(village) if supported(village) else 0
	var water: int = int(village.get("stock", {}).get("water", 0))
	return {"supply": {"met": supported(village) and _healthy(village) and seconds >= SUPPLY_SECONDS and fed == count and drunk == count and food >= 12 and water >= 6,
		"seconds": seconds, "text": "%d/180 Spielsekunden · gegessen %d/%d · getrunken %d/%d · Nahrung %d/12 · Wasser %d/6" % [mini(180, floori(seconds + 0.001)), fed, count, drunk, count, food, water]},
		"professions": {"met": ready_jobs >= 2 and workers.size() >= 2, "completed": ready_jobs, "text": ", ".join(job_details)}}

static func _food(village: Dictionary) -> int:
	return int(village["stock"].get("food", 0)) + int(village["stock"].get("milk", 0))

static func _renewable(village: Dictionary, resource: String) -> bool:
	if resource == "food":
		return int(village.get("garden", 0)) > 0 and int(village.get("grown", 0)) > 0
	return SOURCES.has(resource) and village["economy"]["stations"].has(SOURCES[resource]) and int(village["economy"]["produced"].get(resource, 0)) > 0

static func _healthy(village: Dictionary) -> bool:
	if not supported(village) or not _renewable(village, "food") or not _renewable(village, "water") or _food(village) <= 0 or int(village["stock"]["water"]) <= 0:
		return false
	for member: Dictionary in village["members"]:
		if float(member["hunger"]) < 20.0 or float(member["hydration"]) < 20.0:
			return false
	return not village["members"].is_empty()

static func validate(record: Variant, members: Dictionary) -> String:
	if not record is Dictionary:
		return "Ungültiger Wirtschaftsnachweis."
	if record.is_empty():
		return ""
	if not Rules.is_integer(record.get("schema"), SCHEMA, SCHEMA):
		return "Nicht unterstützte Wirtschaftsnachweisversion."
	for counter: String in ["delivery_cursor", "meal_cursor", "drink_cursor"]:
		if not Rules.is_integer(record.get(counter), 0, 1000000000):
			return "Ungültiger Wirtschaftsereigniszähler."
	var seconds: Variant = record.get("healthy_seconds")
	if not (seconds is int or seconds is float) or not is_finite(float(seconds)) or float(seconds) < 0.0 or float(seconds) > SUPPLY_SECONDS:
		return "Ungültige Versorgungsdauer."
	for key: String in ["fed", "drunk"]:
		if not _workers(record.get(key), members):
			return "Ungültige versorgte Bewohner."
	if not record.get("pending") is Dictionary or record["pending"].size() > members.size() or not record.get("jobs") is Dictionary or record["jobs"].size() > JOBS.size():
		return "Ungültiger Berufsnachweis."
	for actor: Variant in record["pending"]:
		var cargo: Variant = record["pending"][actor]
		if not members.has(actor) or not cargo is Dictionary or not JOBS.has(cargo.get("profession")) or cargo.get("resource") not in JOBS[cargo["profession"]] or not cargo.get("source_id") is String or cargo["source_id"].is_empty() or cargo["source_id"].length() > 256:
			return "Ungültige Berufs-Fracht."
	for profession: Variant in record["jobs"]:
		var job: Variant = record["jobs"][profession]
		if not JOBS.has(profession) or not job is Dictionary or not Rules.is_integer(job.get("units"), 1, 3) or not _workers(job.get("workers"), members) or job["workers"].is_empty():
			return "Ungültige abgeschlossene Berufsarbeit."
	return ""

static func _workers(value: Variant, members: Dictionary) -> bool:
	if not value is Dictionary or value.size() > members.size():
		return false
	for id: Variant in value:
		if not members.has(id) or not value[id] is bool or not value[id]:
			return false
	return true
