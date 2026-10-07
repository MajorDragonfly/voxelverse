extends RefCounted
## One persisted item, one location: free village stock OR one resident's slot.
## Material stock, cargo, escrow and village unlocks stay with their existing owners.
const Economy = preload("res://world/tribe/village_economy.gd")
const Recipes = preload("res://world/tribe/production_catalog.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const FIELD: String = "resident_equipment"
const SCHEMA: int = 1
const MAX_ITEMS: int = 48
const SLOTS: Array[String] = ["tool", "clothing"]
const KINDS: Dictionary = {"stone_tool": "tool", "wooden_tool": "tool", "fiber_tunic": "clothing"}

static func install(data: Dictionary) -> bool:
	if data.has(FIELD): return false # Never replace unknown/future state.
	data[FIELD] = {"schema": SCHEMA, "next_sequence": 1, "items": {}}
	return true

static func recipe(kind: String) -> Dictionary:
	return Recipes.definition("equipment." + kind) if kind in KINDS else {}

static func items(data: Dictionary) -> Dictionary:
	return data.get(FIELD, {}).get("items", {})

static func member(data: Dictionary, identity: String) -> Dictionary:
	var result: Dictionary = {}
	for candidate: Dictionary in data.get("members", []):
		if candidate.get("id") != identity: continue
		if not result.is_empty(): return {} # Ambiguous identity never owns anything.
		result = candidate
	return result

static func owned(data: Dictionary, identity: String, slot: String) -> Dictionary:
	for item: Dictionary in items(data).values():
		if item.owner_id == identity and KINDS.get(item.kind) == slot: return item
	return {}

static func free_items(data: Dictionary, slot: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in items(data).values():
		if item.owner_id == "" and KINDS.get(item.kind) == slot: result.append(item.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.sequence) < int(b.sequence))
	return result

static func snapshot(data: Dictionary, identity: String) -> Dictionary:
	if not data.has(FIELD) or not validate(data).is_empty() or member(data, identity).is_empty(): return {}
	var result: Dictionary = {}
	for slot: String in SLOTS: result[slot] = owned(data, identity, slot).duplicate(true)
	return result

static func preflight(data: Dictionary, request: Dictionary) -> String:
	if not validate(data).is_empty(): return "EQUIPMENT_INVALID"
	if request.get("village_id") != data.get("id"): return "EQUIPMENT_STALE"
	var resident: Dictionary = member(data, str(request.get("resident_id", "")))
	if resident.is_empty(): return "EQUIPMENT_STALE"
	# First usable path is explicit hand crafting / exchange at the warehouse.
	# No teleporting freight, interrupted building delivery or off-body actor copy.
	if resident.get("cargo", "") != "" or resident.get("construction_id", "") != "" or resident.get("care_pen_id", "") != "" or Economy.Home.distance(resident.position, data.anchor) > 3.0: return "EQUIPMENT_AT_WAREHOUSE"
	match request.get("action"):
		"craft":
			var definition: Dictionary = recipe(str(request.get("kind", "")))
			if definition.is_empty(): return "EQUIPMENT_INVALID"
			if int(data.get("tools", 0)) != 1: return "EQUIPMENT_NEEDS_TOOLS"
			if items(data).size() >= MAX_ITEMS: return "EQUIPMENT_FULL"
			for resource: String in definition.inputs:
				# Existing construction/transport reserve by removing stock first.
				# Their capacity holds and pending/cargo are not spendable materials.
				if int(data.stock.get(resource, 0)) < int(definition.inputs[resource]): return "EQUIPMENT_MATERIALS"
		"equip":
			var item: Dictionary = items(data).get(request.get("item_id", ""), {})
			if item.is_empty() or item.owner_id != "" or request.get("slot") != KINDS[item.kind]: return "EQUIPMENT_CLAIMED"
		"return":
			var slot: String = str(request.get("slot", ""))
			if slot not in SLOTS or owned(data, str(resident.id), slot).is_empty(): return "EQUIPMENT_EMPTY"
		_: return "EQUIPMENT_INVALID"
	return ""

static func command(data: Dictionary, request: Dictionary) -> Dictionary:
	var problem: String = preflight(data, request)
	if not problem.is_empty(): return {"ok": false, "code": problem}
	install(data)
	var result: Dictionary = {"ok": true, "code": "EQUIPMENT_SAVED"}
	match request.action:
		"craft":
			var definition: Dictionary = recipe(request.kind)
			for resource: String in definition.inputs: data.stock[resource] -= int(definition.inputs[resource])
			var sequence: int = int(data[FIELD].next_sequence)
			var identity: String = Ids.scoped("equipment", data.id, str(sequence))
			items(data)[identity] = {"id": identity, "sequence": sequence, "kind": request.kind,
				"recipe_id": "equipment." + request.kind, "recipe_revision": definition.revision,
				"owner_id": ""}
			data[FIELD].next_sequence = sequence + 1
			result.item_id = identity
		"equip":
			var previous: Dictionary = owned(data, request.resident_id, request.slot)
			if not previous.is_empty(): previous.owner_id = ""
			items(data)[request.item_id].owner_id = request.resident_id
			result.item_id = request.item_id
		"return":
			var item: Dictionary = owned(data, request.resident_id, request.slot)
			result.item_id = item.id
			item.owner_id = ""
	return result

static func spent(data: Dictionary, resource: String) -> int:
	var total: int = 0
	for item: Dictionary in items(data).values(): total += int(recipe(item.kind).get("inputs", {}).get(resource, 0))
	return total

static func unsupported(data: Variant) -> bool:
	if not data is Dictionary or not data.has(FIELD): return false
	var value: Variant = data[FIELD]
	if not value is Dictionary: return false # Malformed, rejected by validation.
	if value.get("schema") != SCHEMA: return true
	if value.get("items") is Dictionary:
		for item: Variant in value.items.values():
			if not item is Dictionary: continue
			var definition: Dictionary = recipe(str(item.get("kind", "")))
			if definition.is_empty() or item.get("recipe_id") != "equipment." + str(item.get("kind", "")) or item.get("recipe_revision") != definition.get("revision"): return true
	return false

static func validate(data: Dictionary) -> String:
	if not data.has(FIELD): return "" # Old states have no equipment, no free gifts.
	var value: Variant = data[FIELD]
	if not value is Dictionary or value.get("schema") != SCHEMA or not value.get("items") is Dictionary or value.items.size() > MAX_ITEMS or not Economy.integer(value.get("next_sequence"), 1, MAX_ITEMS + 1): return "Ungültiger persönlicher Ausrüstungsvertrag."
	if value.size() != 3 or int(value.next_sequence) != value.items.size() + 1: return "Ungültige Herstellungsfolge."
	var seen: Dictionary = {}
	var slots: Dictionary = {}
	for identity: Variant in value.items:
		var item: Variant = value.items[identity]
		if not item is Dictionary or item.size() != 6 or item.get("kind") not in KINDS or not Economy.integer(item.get("sequence"), 1, int(value.next_sequence) - 1): return "Ungültiger Ausrüstungsgegenstand."
		var definition: Dictionary = recipe(item.kind)
		if definition.is_empty() or item.get("recipe_id") != "equipment." + item.kind or item.get("recipe_revision") != definition.revision: return "Nicht unterstützter Herstellungsbeleg."
		if item.get("id") != identity or identity != Ids.scoped("equipment", str(data.id), str(int(item.sequence))) or seen.has(int(item.sequence)) or not item.get("owner_id") is String: return "Ungültige Ausrüstungskennung."
		seen[int(item.sequence)] = true
		if item.owner_id == "": continue
		if member(data, item.owner_id).is_empty(): return "Ausrüstung gehört keinem eindeutigen Bewohner dieses Dorfes."
		var key: String = item.owner_id + ":" + KINDS[item.kind]
		if slots.has(key): return "Ein persönlicher Platz enthält zwei Gegenstände."
		slots[key] = true
	# Paid receipts consume the same original/produced resource budget. Copies
	# with new IDs cannot manufacture equipment while retaining those materials.
	for resource: String in ["wood", "stone", "fiber"]:
		var paid: int = spent(data, resource)
		if paid == 0: continue
		var produced: int = int(data.get("economy", {}).get("produced", {}).get(resource, 0))
		var original: int = 48 if resource in ["wood", "stone"] else 0
		if Economy.remaining(data, resource) + Economy.goods(data, resource) + paid > original + produced + Economy.Freight.net(data, resource): return "Ausrüstung wurde ohne Materialverbrauch vervielfacht."
	return ""
