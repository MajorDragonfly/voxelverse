extends RefCounted
## Body-owned extension: existing campaign readers preserve the complete bodies
## dictionary. No second save file, encounter ledger or campaign schema is used.

const Ids = preload("res://core/campaign/campaign_ids.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const SCHEMA: int = 2
const MEMBER_COUNT: int = 2
const ORDERS: Array[String] = ["follow", "wait", "home"]

static func create(body_id: String, species_id: String, position: Vector3) -> Dictionary:
	var group_id: String = Ids.scoped("group", body_id, species_id + ":home")
	var members: Array = []
	for i in range(MEMBER_COUNT):
		members.append({"id": Ids.scoped("object", group_id, str(i)),
			"name": "Gefährte %d" % (i + 1), "order": "wait",
			"position": vector_array(position + Vector3(-2.5 if i == 0 else 2.5, 1.0, 2.5))})
	return {"schema": 1, "id": group_id, "body_id": body_id,
		"species_id": species_id, "surface_mode": "legacy_plane_v9",
		"anchor": vector_array(position), "members": members}

static func vector_array(position: Vector3) -> Array:
	return [position.x, position.y, position.z]

static func vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

static func place_valid(value: Variant, mode: String, body_id: String) -> bool:
	if not Space.valid_place(value, mode, body_id): return false
	return mode != Cube.MODE or ((value.get("radius") is float or value.get("radius") is int) and is_finite(float(value.radius)) and float(value.radius) >= 50000.0 and float(value.radius) <= 1.0e10)

static func displacement(a: Variant, b: Variant) -> Vector3:
	if a is Dictionary and b is Dictionary:
		return Cube.local_position(Cube.cartesian(a, a.radius), Cube.cartesian(b, b.radius))
	return vector(a) - vector(b)

static func distance(a: Variant, b: Variant) -> float:
	return displacement(a, b).length()

static func offset_place(value: Variant, local: Vector3) -> Variant:
	if value is Array: return vector_array(vector(value) + local)
	var origin: Array = Cube.cartesian(value, value.radius)
	var delta: Vector3 = Cube.frame(Cube.vector(Cube.direction(value.face, value.u, value.v))) * local
	var result: Dictionary = Cube.from_cartesian(value.body_id, [origin[0] + delta.x, origin[1] + delta.y, origin[2] + delta.z], value.radius)
	result["radius"] = value.radius
	return result

static func place(value: Variant) -> Variant:
	return vector_array(value) if value is Vector3 else value

static func local_offset(anchor: Variant, point: Variant) -> Vector3:
	var delta: Vector3 = displacement(point, anchor)
	if anchor is Dictionary:
		return Cube.frame(Cube.vector(Cube.direction(anchor.face, anchor.u, anchor.v))).inverse() * delta
	return delta

static func local_place(value: Variant, anchor: Variant, limit: float = 22.0) -> bool:
	if anchor is Dictionary:
		if not place_valid(anchor, Cube.MODE, str(anchor.get("body_id", ""))) or not place_valid(value, Cube.MODE, anchor.body_id) or value.radius != anchor.radius: return false
	elif not valid_position(anchor) or not valid_position(value): return false
	return distance(value, anchor) <= limit

static func valid_position(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number)) > 1.0e7:
			return false
	return true

static func validate(value: Variant, body_id: String, species_id: String) -> String:
	if not value is Dictionary:
		return "Der gespeicherte Gruppenstand ist nicht lesbar."
	if value.get("schema") != 1 and value.get("schema") != SCHEMA:
		return "Diese Gruppenversion wird noch nicht unterstützt. Der gespeicherte Stand bleibt erhalten."
	var mode: String = str(value.get("surface_mode", ""))
	if value.schema == SCHEMA and mode != Cube.MODE: return "Radiales Gruppenformat benötigt eine Kugeloberfläche."
	if value.get("body_id") != body_id or value.get("species_id") != species_id or mode not in ["legacy_plane_v9", Cube.MODE] or (mode == Cube.MODE and value.schema != SCHEMA):
		return "Gruppe und aktueller Lebensraum passen nicht zusammen."
	if value.get("id") != Ids.scoped("group", body_id, species_id + ":home") or not place_valid(value.get("anchor"), mode, body_id):
		return "Der gespeicherte Heimatplatz ist ungültig."
	var members: Variant = value.get("members")
	if not members is Array or members.size() != MEMBER_COUNT:
		return "Die gespeicherten Gruppenmitglieder sind ungültig."
	var ids: Array[String] = []
	for i in range(members.size()):
		var member: Variant = members[i]
		if not member is Dictionary:
			return "Ein Gruppenmitglied ist nicht lesbar."
		var expected: String = Ids.scoped("object", str(value["id"]), str(i))
		if member.get("id") != expected or expected in ids or member.get("order") not in ORDERS:
			return "Identität oder Befehl eines Gruppenmitglieds ist ungültig."
		if not member.get("name") is String or member["name"].is_empty() or member["name"].length() > 32 or not place_valid(member.get("position"), mode, body_id):
			return "Name oder Standort eines Gruppenmitglieds ist ungültig."
		ids.append(expected)
	return ""
