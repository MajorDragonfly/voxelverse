extends RefCounted
## One authoritative place per ID and a stable ordinal index in the same root.
## The bounded pending overlay belongs to the atlas, never just this live cache.
const Store = preload("res://core/persistence/region_store.gd")
const PENDING_LIMIT: int = 96
const PAGE_SIZE: int = 64
const MAX_COUNT: int = 9007199254740991
var data: Dictionary = {}
var store := Store.new()
var last_error: String = ""
var validate_place: Callable
var _pending_order: Dictionary = {}
signal failed(message: String)

func bind(record: Dictionary, directory: String, validator: Callable) -> bool:
	data = record
	validate_place = validator
	last_error = ""
	store = Store.new()
	store.directory = directory
	_pending_order.clear()
	if not data.has("place_storage"): return true
	if not store.open(data.place_storage): return _fail(store.last_error)
	for id: String in data.place_ordinals: _pending_order[int(data.place_ordinals[id])] = id
	return true

func migrate() -> bool:
	if not last_error.is_empty(): return false
	if data.has("place_storage"): return true
	# The old inline record is untouched until both indexes are fully durable.
	var ordinal: int = 0
	for id: String in data.places:
		if not _write(id, ordinal, data.places[id]): return false
		ordinal += 1
	var manifest: Dictionary = store.checkpoint()
	if manifest.is_empty(): return _fail(store.last_error)
	data.place_storage = manifest
	data.place_count = ordinal
	data.place_ordinals = {}
	data.places.clear()
	return true

func get_place(id: String) -> Dictionary:
	if not last_error.is_empty(): return {}
	if data.places.has(id): return data.places[id].duplicate(true)
	if not data.has("place_storage"): return {}
	var entry: Dictionary = _entry(id)
	return entry.place.duplicate(true) if not entry.is_empty() else {}

func remember(place: Dictionary) -> bool:
	if not last_error.is_empty(): return false
	var id: String = place.id
	var ordinal: int = -1
	var previous: Dictionary
	if data.places.has(id):
		previous = data.places[id]
		ordinal = int(data.place_ordinals[id])
	else:
		var entry: Dictionary = _entry(id)
		if not last_error.is_empty(): return false
		if not entry.is_empty(): previous = entry.place; ordinal = int(entry.ordinal)
	if previous == place: return false
	if not data.places.has(id) and data.places.size() >= PENDING_LIMIT:
		if not spill(1): return false
	if ordinal == -1:
		if int(data.place_count) >= MAX_COUNT: return _fail("Adressraum des Ortsregisters erschöpft.")
		ordinal = int(data.place_count)
		data.place_count = ordinal + 1
	data.places[id] = place.duplicate(true)
	data.place_ordinals[id] = ordinal
	_pending_order[ordinal] = id
	return true

func spill(limit: int = PENDING_LIMIT) -> bool:
	if not last_error.is_empty(): return false
	var keys: Array = data.places.keys().slice(0, limit)
	for id: String in keys:
		if not _write(id, int(data.place_ordinals[id]), data.places[id]): return false
	var manifest: Dictionary = store.checkpoint()
	if manifest.is_empty(): return _fail(store.last_error)
	data.place_storage = manifest
	for id: String in keys:
		_pending_order.erase(int(data.place_ordinals[id]))
		data.place_ordinals.erase(id)
		data.places.erase(id)
	return true

func count() -> int:
	return int(data.place_count) if data.has("place_storage") else data.places.size()

func page(offset: int = 0, limit: int = PAGE_SIZE) -> Dictionary:
	if not last_error.is_empty(): return {}
	var start: int = clampi(offset, 0, count())
	var end: int = mini(start + clampi(limit, 1, PAGE_SIZE), count())
	var values: Array[Dictionary] = []
	if not data.has("place_storage"):
		var inline_values: Array = data.places.values()
		for i in range(start, end): values.append(inline_values[i].duplicate(true))
	else:
		for ordinal in range(start, end):
			var place: Dictionary = _at(ordinal)
			if place.is_empty(): return {}
			values.append(place)
	return {"places": values, "offset": start, "next": end, "total": count()}

func _at(ordinal: int) -> Dictionary:
	if _pending_order.has(ordinal): return data.places[_pending_order[ordinal]].duplicate(true)
	var pointer: Dictionary = store.get_value("o:" + str(ordinal))
	if not store.last_error.is_empty(): _fail(store.last_error); return {}
	if pointer.get("schema") != 1 or pointer.get("body_id") != data.body_id or not pointer.get("id") is String or pointer.id.is_empty():
		_fail("Ortsindex fehlt oder ist beschädigt: " + str(ordinal)); return {}
	var entry: Dictionary = _entry(pointer.id)
	if entry.is_empty() or entry.get("ordinal") != ordinal:
		_fail("Ortsindex und Ort widersprechen sich."); return {}
	return entry.place.duplicate(true)

func _entry(id: String) -> Dictionary:
	var key: String = "p:" + id
	var entry: Dictionary = store.get_value(key)
	if not store.last_error.is_empty(): _fail(store.last_error); return {}
	if entry.is_empty() and not store.cache.has(key): return {}
	if entry.get("schema") != 1 or entry.get("body_id") != data.body_id or not integer(entry.get("ordinal"), 0, int(data.place_count) - 1) or not validate_place.call(entry.get("place")):
		_fail("Unbekannter oder beschädigter gespeicherter Ort: " + id); return {}
	if entry.place.id != id: _fail("Ortsidentität passt nicht zum Index."); return {}
	return entry

func _write(id: String, ordinal: int, place: Dictionary) -> bool:
	if not store.put("p:" + id, {"schema": 1, "body_id": data.body_id, "ordinal": ordinal, "place": place.duplicate(true)}): return _fail(store.last_error)
	if not store.put("o:" + str(ordinal), {"schema": 1, "body_id": data.body_id, "id": id}): return _fail(store.last_error)
	return true

func _fail(message: String) -> bool:
	if last_error.is_empty(): last_error = message; failed.emit(message)
	return false

static func validate(record: Dictionary, directory: String) -> String:
	if not integer(record.get("place_count"), 0, MAX_COUNT): return "Ungültige Anzahl bekannter Orte."
	if not record.get("place_ordinals") is Dictionary or record.place_ordinals.size() != record.places.size() or record.places.size() > PENDING_LIMIT: return "Ungültiger offener Ortspuffer."
	var ordinals: Dictionary = {}
	for id in record.place_ordinals:
		var ordinal: Variant = record.place_ordinals[id]
		if not record.places.has(id) or not integer(ordinal, 0, int(record.place_count) - 1) or ordinals.has(int(ordinal)): return "Ungültige offene Ortszuordnung."
		ordinals[int(ordinal)] = true
	var problem: String = Store.manifest_problem(record.get("place_storage"))
	if not problem.is_empty(): return problem
	var probe := Store.new()
	probe.directory = directory
	return "" if probe.open(record.place_storage) else probe.last_error

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high
