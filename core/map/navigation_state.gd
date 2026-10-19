extends RefCounted
## Optional, bounded body participant in the existing campaign save. Pins never
## reveal terrain and known-place targets resolve through the authoritative atlas.
const Surface = preload("res://core/map/surface_map_projection.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const FIELD: String = "map_navigation"
const SCHEMA: int = 1
const CAPACITY: int = 24
const NAME_LIMIT: int = 48

static func create(body: Dictionary) -> Dictionary:
	return {"schema": SCHEMA, "body_id": body.id, "mode": body.surface_mode,
		"next_id": 1, "waypoints": {}, "target": {}}

static func view(body: Dictionary) -> Dictionary:
	return body.get(FIELD, {})

static func clean_name(value: String) -> String:
	var result: String = ""
	for character in value:
		if character.unicode_at(0) >= 32 and character.unicode_at(0) != 127:
			result += character
	return result.strip_edges().left(NAME_LIMIT)

static func add(body: Dictionary, address: Dictionary, title: String, atlas: RefCounted) -> String:
	if not validate(body).is_empty() or not _address(address, body): return ""
	if atlas == null or atlas.data.get("body_id") != body.id or not atlas.known(address): return ""
	var name: String = clean_name(title)
	if name.is_empty(): return ""
	var record: Dictionary = view(body)
	if record.get("waypoints", {}).size() >= CAPACITY or int(record.get("next_id", 1)) >= 1000000000: return ""
	if record.is_empty():
		record = create(body)
		body[FIELD] = record
	var id: String = Ids.scoped("waypoint", body.id, str(record.next_id))
	if record.waypoints.has(id): return ""
	record.next_id = int(record.next_id) + 1
	record.waypoints[id] = {"id": id, "name": name, "kind": "waypoint", "own": true, "address": address.duplicate(true)}
	record.target = {"kind": "waypoint", "id": id}
	return id

static func rename(body: Dictionary, id: String, title: String) -> bool:
	if not validate(body).is_empty(): return false
	var point: Dictionary = view(body).get("waypoints", {}).get(id, {})
	var name: String = clean_name(title)
	if point.is_empty() or name.is_empty() or name == point.name: return false
	point.name = name
	return true

static func remove(body: Dictionary, id: String) -> bool:
	if not validate(body).is_empty(): return false
	var record: Dictionary = view(body)
	if not record.get("waypoints", {}).has(id): return false
	record.waypoints.erase(id)
	if record.target.get("kind") == "waypoint" and record.target.get("id") == id: record.target = {}
	return true

static func track(body: Dictionary, id: String, kind: String, atlas: RefCounted) -> bool:
	if not validate(body).is_empty() or kind not in ["waypoint", "place"]: return false
	var point: Dictionary = view(body).get("waypoints", {}).get(id, {}) if kind == "waypoint" else (atlas.get_place(id) if atlas != null else {})
	if point.is_empty() or not _address(point.get("address", {}), body): return false
	if kind == "place" and not point.get("own", false) and not atlas.known(point.address): return false
	if not body.has(FIELD): body[FIELD] = create(body)
	var value: Dictionary = {"kind": kind, "id": id}
	if body[FIELD].target == value: return false
	body[FIELD].target = value
	return true

static func clear_target(body: Dictionary) -> bool:
	if not validate(body).is_empty() or view(body).get("target", {}).is_empty(): return false
	body[FIELD].target = {}
	return true

static func target(body: Dictionary, atlas: RefCounted) -> Dictionary:
	if not validate(body).is_empty(): return {}
	var selected: Dictionary = view(body).get("target", {})
	if selected.is_empty(): return {}
	if selected.kind == "waypoint": return view(body).waypoints.get(selected.id, {})
	if atlas == null or atlas.data.get("body_id") != body.get("id"): return {}
	var point: Dictionary = atlas.get_place(selected.id)
	if point.is_empty() or not _address(point.get("address", {}), body): return {}
	return point if point.get("own", false) or atlas.known(point.address) else {}

static func unsupported(body: Dictionary) -> bool:
	return body.get(FIELD) is Dictionary and body[FIELD].get("schema") != SCHEMA

static func validate(body: Dictionary) -> String:
	if not body.has(FIELD): return ""
	var record: Variant = body[FIELD]
	if not record is Dictionary or record.get("schema") != SCHEMA: return "Unsupported navigation record."
	if record.get("body_id") != body.get("id") or record.get("mode") != body.get("surface_mode"): return "Navigation belongs to another surface."
	var next: Variant = record.get("next_id")
	if not (next is int or next is float) or not is_finite(float(next)) or float(next) != floorf(float(next)) or float(next) < 1 or float(next) > 1000000000: return "Invalid waypoint sequence."
	if not record.get("waypoints") is Dictionary or record.waypoints.size() > CAPACITY: return "Invalid waypoint collection."
	for id: Variant in record.waypoints:
		var point: Variant = record.waypoints[id]
		if not _id(id) or not point is Dictionary or point.get("id") != id or point.get("kind") != "waypoint" or point.get("own") != true: return "Invalid waypoint identity."
		if not point.get("name") is String or point.name.is_empty() or clean_name(point.name) != point.name: return "Invalid waypoint name."
		if not _address(point.get("address", {}), body): return "Invalid waypoint address."
	var selected: Variant = record.get("target")
	if not selected is Dictionary: return "Invalid navigation target."
	if not selected.is_empty():
		if selected.size() != 2 or selected.get("kind") not in ["waypoint", "place"] or not _id(selected.get("id")): return "Invalid navigation target identity."
		if selected.kind == "waypoint" and not record.waypoints.has(selected.id): return "Navigation target has no waypoint."
	return ""

static func _id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 256

static func _address(address: Variant, body: Dictionary) -> bool:
	return address is Dictionary and Surface.valid(address) and address.body_id == body.get("id") and address.mode == body.get("surface_mode")
