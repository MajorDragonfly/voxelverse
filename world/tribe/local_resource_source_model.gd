extends RefCounted
## One admitted surface object, one unit, one mutable remaining field. Empty
## records are permanent tombstones; streaming, camera and time never refill.
const Home = preload("res://world/home_group/home_group_state.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const FIELD: String = "local_resource_sources"
const SCHEMA: int = 1
const MAX_SOURCES: int = 64
const LIMIT: float = 20.0
const KINDS: Array[String] = ["wood", "stone", "flint"]
const PROPS: Dictionary = {"wood": "loose_stick", "stone": "small_stone", "flint": "flint"}

static func entries(data: Dictionary) -> Dictionary:
	return data.get("economy", {}).get(FIELD, {}).get("entries", {})

static func install(data: Dictionary) -> void:
	if not data.economy.has(FIELD): data.economy[FIELD] = {"schema": SCHEMA, "entries": {}}

static func level(radius: float) -> int:
	return ceili(log(radius * 2.0 / 4.0) / log(2.0))

static func candidate(anchor: Dictionary, dx: int, dy: int) -> Dictionary:
	var grid: int = level(float(anchor.radius))
	var count: int = 1 << grid
	var step: float = 2.0 / count
	var x: int = floori((float(anchor.u) + 1.0) / step) + dx
	var y: int = floori((float(anchor.v) + 1.0) / step) + dy
	var place: Dictionary = Home.Cube.address(anchor.body_id, anchor.face, -1.0 + (x + 0.5) * step, -1.0 + (y + 0.5) * step)
	x = clampi(floori((float(place.u) + 1.0) / step), 0, count - 1)
	y = clampi(floori((float(place.v) + 1.0) / step), 0, count - 1)
	place = Home.Cube.address(anchor.body_id, place.face, -1.0 + (x + 0.5) * step, -1.0 + (y + 0.5) * step)
	place.radius = anchor.radius
	place.height = anchor.height
	var slot: Array = [grid, int(place.face), x, y]
	var region: String = region_id(str(anchor.body_id), slot)
	var identity: String = identity_for(str(anchor.body_id), slot)
	var kind: String = KINDS[posmod(identity.hash(), KINDS.size())]
	return {"id": identity, "body_id": anchor.body_id, "region_id": region, "slot": slot,
		"position": place, "resource_id": kind, "prop_kind": PROPS[kind],
		"initial": 1, "remaining": 1, "regeneration": "none"}

static func region_id(body_id: String, slot: Array) -> String:
	return "%s:loose1:%d:%d:%d:%d" % [body_id, int(slot[0]) - 4, int(slot[1]), int(slot[2]) / 16, int(slot[3]) / 16]

static func identity_for(body_id: String, slot: Array) -> String:
	return Ids.scoped("local_source", body_id, "%d:%d:%d:%d" % [int(slot[0]), int(slot[1]), int(slot[2]), int(slot[3])])

static func admit(data: Dictionary, proposal: Dictionary) -> bool:
	if int(data.economy.get("schema", 0)) != 6 or not record_valid(data, proposal): return false
	var existing: Dictionary = entries(data).get(proposal.id, {})
	if not existing.is_empty():
		var immutable: Dictionary = existing.duplicate(true)
		immutable.remaining = proposal.remaining
		return immutable == proposal # Do not write, including after exhaustion.
	if entries(data).size() >= MAX_SOURCES or proposal.remaining != 1: return false
	install(data)
	entries(data)[proposal.id] = proposal.duplicate(true)
	return true

static func get_source(data: Dictionary, identity: String) -> Dictionary:
	return entries(data).get(identity, {})

static func sources(data: Dictionary, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: Dictionary in entries(data).values():
		if source.resource_id == kind: result.append(source)
	return result

static func initial(data: Dictionary, kind: String) -> int:
	return sources(data, kind).size()

static func remaining(data: Dictionary, kind: String) -> int:
	var amount: int = 0
	for source: Dictionary in sources(data, kind): amount += int(source.remaining)
	return amount

static func withdrawn(data: Dictionary, kind: String) -> int:
	return initial(data, kind) - remaining(data, kind)

static func take(source: Dictionary) -> bool:
	if source.get("regeneration") != "none" or int(source.get("remaining", 0)) <= 0: return false
	source.remaining -= 1
	return true

static func unsupported(economy: Variant) -> bool:
	return economy is Dictionary and economy.has(FIELD) and (not economy[FIELD] is Dictionary or economy[FIELD].get("schema") != SCHEMA)

static func record_valid(data: Dictionary, value: Variant) -> bool:
	if not value is Dictionary or value.size() != 10 or not value.get("slot") is Array or value.slot.size() != 4: return false
	if not data.get("anchor") is Dictionary: return false
	var grid: int = level(float(data.anchor.radius))
	for index in range(4):
		if not integer(value.slot[index], 0, 1 << grid): return false
	if int(value.slot[0]) != grid or int(value.slot[1]) > 5 or int(value.slot[2]) >= 1 << grid or int(value.slot[3]) >= 1 << grid: return false
	if value.get("body_id") != data.body_id or value.get("id") != identity_for(data.body_id, value.slot) or value.get("region_id") != region_id(data.body_id, value.slot): return false
	var kind: String = KINDS[posmod(str(value.id).hash(), KINDS.size())]
	if value.get("resource_id") != kind or value.get("prop_kind") != PROPS[kind] or value.get("regeneration") != "none" or not integer(value.get("initial"), 1, 1) or not integer(value.get("remaining"), 0, 1): return false
	var place: Variant = value.get("position")
	if not Home.local_place(place, data.anchor, LIMIT) or not place is Dictionary or place.radius != data.anchor.radius or int(place.face) != int(value.slot[1]): return false
	var step: float = 2.0 / (1 << grid)
	return absf(float(place.u) - (-1.0 + (int(value.slot[2]) + 0.5) * step)) < 1.0e-12 and absf(float(place.v) - (-1.0 + (int(value.slot[3]) + 0.5) * step)) < 1.0e-12

static func validate(data: Dictionary) -> String:
	if not data.get("economy", {}).has(FIELD): return ""
	var bank: Variant = data.economy[FIELD]
	if int(data.economy.get("schema", 0)) != 6 or not bank is Dictionary or bank.size() != 2 or bank.get("schema") != SCHEMA or not bank.get("entries") is Dictionary or bank.entries.size() > MAX_SOURCES: return "Ungültiger örtlicher Quellenvertrag."
	for id: Variant in bank.entries:
		if not record_valid(data, bank.entries[id]) or bank.entries[id].id != id: return "Ungültige örtliche Quelle oder Ortsbindung."
	var held: Dictionary = {}
	for member: Dictionary in data.members:
		var source: Dictionary = get_source(data, str(member.get("cargo_source_id", "")))
		if source.is_empty(): continue
		if member.cargo != source.resource_id: return "Örtliche Fracht hat einen fremden Ressourcentyp."
		held[source.id] = int(held.get(source.id, 0)) + 1
		if int(held[source.id]) > int(source.initial) - int(source.remaining): return "Örtliche Quellenfracht wurde vervielfacht."
	return ""

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high
