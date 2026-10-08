extends RefCounted
## Persisted work boundaries, never a second material store. Sources are borrowed
## from deposits, workplaces and local objects; pickup/delivery stay VillageWork.
const Home = preload("res://world/home_group/home_group_state.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const LocalSources = preload("res://world/tribe/local_resource_source_model.gd")
const SCHEMA: int = 1
const ECONOMY_SCHEMA: int = 6
const MAX_AREAS: int = 8
const MAX_RADIUS: float = 8.0
const LOCAL_LIMIT: float = 20.0
const KINDS: Array[String] = ["wood", "stone", "food", "water", "fiber", "flint"]
const STATIONS: Dictionary = {"forester": "wood", "quarry": "stone", "well": "water", "fiberbed": "fiber"}

static func install(data: Dictionary) -> void:
	# Explicit area creation installs boundaries only, never sources or stock.
	if not data.economy.has("resource_areas"):
		data.economy["resource_areas"] = {"schema": SCHEMA, "next_id": 1, "entries": {}}
	# Shared Economy owner migrates 5 -> 6, including the flint stock key.

static func entries(data: Dictionary) -> Dictionary:
	return data.get("economy", {}).get("resource_areas", {}).get("entries", {})

static func get_area(data: Dictionary, identity: String) -> Dictionary:
	return entries(data).get(identity, {})

static func bounds_valid(data: Dictionary, center: Variant, radius: Variant) -> bool:
	return number(radius, 1.0, MAX_RADIUS) and Home.local_place(center, data.anchor, LOCAL_LIMIT) \
		and Home.distance(center, data.anchor) + float(radius) <= LOCAL_LIMIT + 0.00001

static func contains(area: Dictionary, place: Variant) -> bool:
	return Home.local_place(place, area.center, float(area.radius) + 0.00001)

static func create(data: Dictionary, center: Variant, radius: float, kind: String, target: int = 16) -> String:
	if entries(data).size() >= MAX_AREAS or not bounds_valid(data, center, radius) or kind not in KINDS or target < 0 or target > 48: return ""
	install(data)
	var sequence: int = int(data.economy.resource_areas.next_id)
	if sequence >= 1000000000: return ""
	var identity: String = Ids.scoped("resource_area", data.id, str(sequence))
	data.economy.resource_areas.next_id = sequence + 1
	entries(data)[identity] = {"id": identity, "sequence": sequence, "body_id": data.body_id,
		"center": center.duplicate(true), "radius": radius, "kind": kind, "target": target, "workers": 0}
	return identity

static func update(data: Dictionary, identity: String, center: Variant, radius: float, kind: String, target: int) -> bool:
	var area: Dictionary = get_area(data, identity)
	if area.is_empty() or not bounds_valid(data, center, radius) or kind not in KINDS or target < 0 or target > 48: return false
	area.merge({"center": center.duplicate(true), "radius": radius, "kind": kind, "target": target}, true)
	for member: Dictionary in data.members:
		if member.get("resource_area_id", "") != identity: continue
		member.erase("resource_source_id")
		member.work = 0.0
		if member.order == "wait" and member.paused_order != "": member.paused_order = kind
		else: member.order = kind
		member.blocked = false
	return true

static func remove(data: Dictionary, identity: String) -> bool:
	if not entries(data).has(identity): return false
	for member: Dictionary in data.members:
		if member.get("resource_area_id", "") == identity: release(data, member)
	entries(data).erase(identity)
	return true

static func release(data: Dictionary, member: Dictionary) -> void:
	# Cargo/provenance survives removal, edit and reassignment. A move to storage
	# completes the existing trip; there is no immediate stock credit or refund.
	var area: Dictionary = get_area(data, str(member.get("resource_area_id", "")))
	if not area.is_empty(): area.workers = maxi(0, int(area.workers) - 1)
	member.erase("resource_area_id")
	member.erase("resource_source_id")
	member.work = 0.0
	member.paused_order = ""
	member.task = ""
	member.blocked = false
	member.order = "move"
	member.destination = data.anchor.duplicate(true)
	member.stage = "return" if member.cargo != "" else "outbound"

static func assign(data: Dictionary, identity: String, members: Array) -> bool:
	var area: Dictionary = get_area(data, identity)
	if area.is_empty(): return false
	var seen: Array = []
	for member: Dictionary in members:
		if not eligible(member) or member not in data.members or member.id in seen: return false
		seen.append(member.id)
	for member: Dictionary in members:
		if member.get("resource_area_id", "") != identity:
			if member.get("resource_area_id", "") != "": release(data, member)
			area.workers += 1
		member.resource_area_id = identity
		member.erase("resource_source_id")
		member.erase("workplace_id")
		member.merge({"order": area.kind, "paused_order": "", "task": "", "work": 0.0, "blocked": false,
			"stage": "return" if member.cargo != "" else "outbound"}, true)
	return true

static func eligible(member: Dictionary) -> bool:
	return member.get("construction_id", "") == "" and member.get("care_pen_id", "") == ""

static func set_workers(data: Dictionary, identity: String, count: int, unavailable: Array = []) -> bool:
	var area: Dictionary = get_area(data, identity)
	if area.is_empty() or count < 0 or count > data.members.size(): return false
	var assigned: Array = []
	var free: Array = []
	for member: Dictionary in data.members:
		if member.get("resource_area_id", "") == identity: assigned.append(member)
		elif member.id not in unavailable and eligible(member) and member.cargo == "" and member.get("resource_area_id", "") == "" and member.order in ["wait", "move"] and member.paused_order == "": free.append(member)
	if count > assigned.size() + free.size(): return false
	while assigned.size() > count: release(data, assigned.pop_back())
	if assigned.size() < count: return assign(data, identity, free.slice(0, count - assigned.size()))
	return true

static func sources(data: Dictionary, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var primary: String = str(STATIONS.find_key(kind)) if kind in STATIONS.values() else ""
	if data.deposits.has(kind) and (kind not in ["water", "fiber"] or data.economy.stations.has(primary)):
		result.append(data.deposits[kind])
	for key: String in data.economy.stations:
		if key.ends_with(":2") and STATIONS.get(key.trim_suffix(":2")) == kind: result.append(data.economy.stations[key])
	result.append_array(LocalSources.sources(data, kind))
	return result

static func source_by_id(data: Dictionary, kind: String, identity: String) -> Dictionary:
	for source: Dictionary in sources(data, kind):
		if source.id == identity: return source
	return {}

static func source_for(data: Dictionary, member: Dictionary, kind: String) -> Dictionary:
	# Retain pickup provenance for before/after observers even if the area was
	# edited or the resident is carrying. There is still only one source writer.
	if member.cargo == kind and member.get("cargo_source_id", "") != "":
		return source_by_id(data, kind, member.cargo_source_id)
	return source_by_id(data, kind, str(member.get("resource_source_id", "")))

static func claims(data: Dictionary, identity: String, except_member: String) -> int:
	var count: int = 0
	for member: Dictionary in data.members:
		if member.id != except_member and member.cargo == "" and member.order != "wait" and member.get("resource_source_id", "") == identity: count += 1
	return count

static func dispatch(data: Dictionary, member: Dictionary, reachable: Callable, capacity: bool = true) -> void:
	var area: Dictionary = get_area(data, str(member.get("resource_area_id", "")))
	if area.is_empty() and member.get("resource_area_id", "") == "":
		var source: Dictionary = LocalSources.get_source(data, str(member.get("resource_source_id", "")))
		if not source.is_empty() and member.order != "wait" and member.cargo == "":
			member.blocked = not reachable.call(member, source)
			if member.blocked or int(source.remaining) == 0 or not capacity: member.work = 0.0
		return
	if area.is_empty() or member.order == "wait" or member.cargo != "" or member.stage in ["meal", "drink"]: return
	if not capacity:
		member.erase("resource_source_id")
		member.work = 0.0
		return
	var chosen: Dictionary = {}
	var best: float = INF
	var current: String = str(member.get("resource_source_id", ""))
	for source: Dictionary in sources(data, area.kind):
		if not contains(area, source.position) or int(source.remaining) <= claims(data, source.id, member.id) or not reachable.call(member, source): continue
		var distance: float = Home.distance(member.position, source.position)
		# Sticky until exhausted/unreachable/outside; no accumulated work transfer.
		if source.id == current:
			chosen = source
			break
		if distance < best:
			best = distance
			chosen = source
	var next: String = "" if chosen.is_empty() else str(chosen.id)
	if current != next:
		member.work = 0.0
		member.blocked = false
		member.erase("resource_source_id")
		if next != "": member.resource_source_id = next

static func summary(data: Dictionary, identity: String, reachable: Callable = Callable()) -> Dictionary:
	var area: Dictionary = get_area(data, identity)
	if area.is_empty(): return {}
	var total: int = 0
	var possible: int = 0
	var count: int = 0
	var carried: int = 0
	var reserved: int = 0
	for source: Dictionary in sources(data, area.kind):
		if not contains(area, source.position): continue
		count += 1
		total += int(source.remaining)
		if int(source.remaining) > 0 and (not reachable.is_valid() or reachable.call(data.members[0], source)): possible += 1
	for member: Dictionary in data.members:
		if member.get("resource_area_id", "") == identity:
			carried += 1 if member.cargo != "" else 0
			reserved += 1 if member.get("resource_source_id", "") != "" and member.cargo == "" and member.order != "wait" else 0
	return area.merged({"remaining": total, "sources": count, "reachable": possible, "carried": carried, "reserved": reserved})

static func validate(data: Dictionary) -> String:
	var value: Variant = data.get("economy", {}).get("resource_areas")
	if value == null:
		for member: Dictionary in data.members:
			if member.get("resource_area_id", "") != "" or not direct_valid(data, member): return "Sammelauftrag ohne Gebietsvertrag."
		return ""
	if (data.economy.schema != 5 and data.economy.schema != ECONOMY_SCHEMA) or not value is Dictionary or value.get("schema") != SCHEMA or not integer(value.get("next_id"), 1, 1000000000) or not value.get("entries") is Dictionary or value.entries.size() > MAX_AREAS: return "Ungültiger Sammelgebietsvertrag."
	for identity: Variant in value.entries:
		var area: Variant = value.entries[identity]
		if not area is Dictionary or not integer(area.get("sequence"), 1, int(value.next_id) - 1) or identity != area.get("id") or identity != Ids.scoped("resource_area", data.id, str(int(area.sequence))) or area.get("body_id") != data.body_id or not bounds_valid(data, area.get("center"), area.get("radius")) or area.get("kind") not in KINDS or not integer(area.get("target"), 0, 48) or not integer(area.get("workers"), 0, data.members.size()): return "Ungültige Sammelgebietsgrenzen oder Kennung."
		var assigned: int = 0
		for member: Dictionary in data.members:
			if member.get("resource_area_id", "") == identity: assigned += 1
		if assigned != int(area.workers): return "Sammelgebietszuordnung widerspricht der Bewohnerzahl."
	for member: Dictionary in data.members:
		if not member.get("resource_area_id", "") is String or not member.get("resource_source_id", "") is String: return "Ungültige Sammelzuordnung."
		var identity: String = str(member.get("resource_area_id", ""))
		if identity.is_empty():
			if not direct_valid(data, member): return "Quelle ohne gültigen örtlichen Auftrag."
			continue
		var area: Dictionary = get_area(data, identity)
		if area.is_empty() or not eligible(member) or member.get("workplace_id", "") != "" or (member.order != area.kind and not (member.order == "wait" and member.paused_order == area.kind)): return "Fremdes oder widersprüchliches Sammelgebiet."
		if member.get("resource_source_id", "") != "":
			var source: Dictionary = source_by_id(data, area.kind, member.resource_source_id)
			if source.is_empty() or not contains(area, source.position): return "Quelle außerhalb des Sammelgebiets."
	return ""

static func direct_valid(data: Dictionary, member: Dictionary) -> bool:
	var identity: String = str(member.get("resource_source_id", ""))
	if identity.is_empty(): return true
	var source: Dictionary = LocalSources.get_source(data, identity)
	return not source.is_empty() and member.get("workplace_id", "") == "" and eligible(member) and (member.order == source.resource_id or (member.order == "wait" and member.paused_order == source.resource_id))

static func unsupported(value: Variant) -> bool:
	return value is Dictionary and value.has("resource_areas") and (not value.resource_areas is Dictionary or value.resource_areas.get("schema") != SCHEMA)

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func integer(value: Variant, low: int, high: int) -> bool:
	return number(value, low, high) and float(value) == floorf(float(value))
