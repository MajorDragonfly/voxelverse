extends RefCounted
## Body-owned extension: existing campaign readers preserve the complete bodies
## dictionary. No second save file, encounter ledger or campaign schema is used.

const Ids = preload("res://core/campaign/campaign_ids.gd")
const SCHEMA: int = 1
const MEMBER_COUNT: int = 2
const ORDERS: Array[String] = ["follow", "wait", "home"]

static func create(body_id: String, species_id: String, position: Vector3) -> Dictionary:
	var group_id: String = Ids.scoped("group", body_id, species_id + ":home")
	var members: Array = []
	for i in range(MEMBER_COUNT):
		members.append({"id": Ids.scoped("object", group_id, str(i)),
			"name": "Gefährte %d" % (i + 1), "order": "wait",
			"position": vector_array(position + Vector3(-2.5 if i == 0 else 2.5, 1.0, 2.5))})
	return {"schema": SCHEMA, "id": group_id, "body_id": body_id,
		"species_id": species_id, "surface_mode": "legacy_plane_v9",
		"anchor": vector_array(position), "members": members}

static func vector_array(position: Vector3) -> Array:
	return [position.x, position.y, position.z]

static func vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

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
	if value.get("schema") != SCHEMA:
		return "Diese Gruppenversion wird noch nicht unterstützt. Der gespeicherte Stand bleibt erhalten."
	if value.get("body_id") != body_id or value.get("species_id") != species_id or value.get("surface_mode") != "legacy_plane_v9":
		return "Gruppe und aktueller Lebensraum passen nicht zusammen."
	if value.get("id") != Ids.scoped("group", body_id, species_id + ":home") or not valid_position(value.get("anchor")):
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
		if not member.get("name") is String or member["name"].is_empty() or member["name"].length() > 32 or not valid_position(member.get("position")):
			return "Name oder Standort eines Gruppenmitglieds ist ungültig."
		ids.append(expected)
	return ""
