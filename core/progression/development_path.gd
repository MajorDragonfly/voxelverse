extends RefCounted
class_name DevelopmentPath

## Read-only adapter for the published PR #20 home_group schema 1.
## Does not create members, move them, change phase or write a save extension.
const Ids = preload("res://core/campaign/campaign_ids.gd")
const Rules = preload("res://core/progression/behavior_catalog.gd")


static func describe(campaign: Dictionary, body_key: String, phase: int, runtime_available: bool) -> Dictionary:
	var home: Dictionary = read_home(campaign, body_key)
	home["runtime_available"] = runtime_available
	var own_group: bool = home["status"] == "saved"
	var result: Dictionary = {
		"current_phase": phase, "current_stage": "creature" if phase == 0 else "tribe" if phase == 1 else "later",
		"home": home,
		"transition": {"implemented": false, "available": false,
			"message": "Der Wechsel zum Stamm ist noch nicht verfügbar. Gruppenaufgaben, Werkzeuge und Dorfaufbau folgen gemeinsam mit der spielbaren Stammesphase."},
		"stages": [
			{"id": "creature", "title": "1 · Deine Kreatur", "status": "Aktuelle Phase" if phase == 0 else "Frühere Phase",
				"control": "Eine Kreatur direkt steuern",
				"description": "Erkunden, den eigenen Körper entwickeln, befreunden, helfen oder jagen. Fähigkeiten wirken auf deine Kreatur."},
			{"id": "nest_group", "title": "2 · Deine Nestgruppe", "status": "Vorstufe innerhalb der Kreaturenphase",
				"control": "Deine Kreatur mit eigenen Artgenossen",
				"description": "Ein Nest als Heimat; Gefährten folgen, warten oder kehren heim. Diese Gruppe ist noch kein Stamm mit Dorfwirtschaft."},
			{"id": "tribe", "title": "3 · Dein Stamm", "status": "Geplant · eigentliche Stammesphase",
				"control": "Gruppen befehligen und Aufgaben verteilen",
				"description": "Material sammeln → Werkzeuge herstellen → Behausung bauen → Bewohner versorgen → Dorf erweitern. Spezies, Heimat, Mitglieder und Beziehungen bleiben die Grundlage."},
		],
	}
	if phase == 0 and own_group:
		result["current_stage"] = "nest_group"
	return result


static func read_home(campaign: Dictionary, body_key: String) -> Dictionary:
	var missing: Dictionary = {"status": "missing", "member_count": 0, "message": "Auf diesem Planeten ist noch keine eigene Nestgruppe gespeichert."}
	var bodies: Variant = campaign.get("bodies", {})
	if not bodies is Dictionary:
		return _invalid()
	var body: Variant = bodies.get(body_key, {})
	if not body is Dictionary:
		return _invalid()
	if not body.has("home_group"):
		return missing
	var home: Variant = body["home_group"]
	if not home is Dictionary:
		return _invalid()
	if not Rules.is_integer(home.get("schema"), 1, 1):
		return {"status": "unsupported", "member_count": 0, "message": "Diese gespeicherte Gruppenversion kann hier noch nicht angezeigt werden. Ihre Daten bleiben erhalten."}
	var body_id: String = str(body.get("id", ""))
	var species_id: String = str(campaign.get("player_species_id", ""))
	if body_id.is_empty() or species_id.is_empty() or home.get("body_id") != body_id or home.get("species_id") != species_id or home.get("surface_mode") != "legacy_plane_v9" or body.get("surface_mode") != "legacy_plane_v9":
		return _invalid()
	var group_id: String = Ids.scoped("group", body_id, species_id + ":home")
	if home.get("id") != group_id or not _position(home.get("anchor")):
		return _invalid()
	var members: Variant = home.get("members")
	if not members is Array or members.size() != 2:
		return _invalid()
	for index in range(members.size()):
		var member: Variant = members[index]
		if not member is Dictionary or member.get("id") != Ids.scoped("object", group_id, str(index)) or member.get("order") not in ["follow", "wait", "home"]:
			return _invalid()
		if not member.get("name") is String or member["name"].is_empty() or member["name"].length() > 32 or not _position(member.get("position")):
			return _invalid()
	# The view exposes summaries, never mutable references to live member records.
	return {"status": "saved", "member_count": members.size(), "message": "%d eigene Gefährten und ein Heimatplatz sind gespeichert." % members.size()}


static func _position(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)) or absf(float(component)) > 1.0e7:
			return false
	return true


static func _invalid() -> Dictionary:
	return {"status": "invalid", "member_count": 0, "message": "Die gespeicherte Gruppe lässt sich diesem Heimatort und deiner Spezies nicht sicher zuordnen. Ihre Daten bleiben erhalten."}
