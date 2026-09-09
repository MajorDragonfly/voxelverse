extends RefCounted
## Versioned planning + hard runtime gates. Saved points/flags are never releases.
const Ids = preload("res://core/campaign/campaign_ids.gd")
const VERSION: int = 2
const PHASES: Dictionary = {
	2: {"name": "Antike / Mittelalter", "action": "Jetzt ins Mittelalter fortschreiten", "implemented": false,
		"requirements": [
			["housing", "Zwei fertige Hütten für die ursprünglichen drei Bewohner", true],
			["craft", "Ein fertig hergestelltes Steinwerkzeug", true],
			["farming", "Ein angelegter Wurzelgarten mit tatsächlich nachgewachsener Nahrung", true],
			["supply", "Alle Bewohner 180 Spielsekunden mit erneuerbarer Nahrung und Wasser versorgen; jeder hat gegessen und getrunken; am Ende mindestens 12 Nahrung und 6 Wasser im Lager", true],
			["professions", "Mindestens zwei Bewohner erledigen in zwei Berufen jeweils drei erneuerbare Arbeits- und Lieferzyklen", true],
			["neighbors", "Mit einer Nachbarfraktion der eigenen Spezies eine Hilfs-/Handelslieferung erfüllen ODER das Dorf in einem abgeschlossenen Gruppenkonflikt verteidigen", false],
			["runtime", "Spielbares Mittelalter mit Siedlungsverwaltung, Handwerk, Wegen und Handel sowie geprüftem Speichern/Laden", false],
		]},
	3: {"name": "Neuzeit / Weltmacht", "action": "Jetzt in die Neuzeit fortschreiten", "implemented": false,
		"requirements": [
			["settlements", "Zwei eigene Siedlungen mit Wohnraum und 180 Spielsekunden gesicherter Nahrung und Wasserversorgung", false],
			["trade", "Eine begehbare Verbindung zwischen den Siedlungen transportiert insgesamt 30 Waren bis zum Ziellager", false],
			["industry", "Eine vollständige Rohstoffkette verarbeitet 12 Erz zu 6 Metall und daraus 3 nutzbare Werkzeuge", false],
			["energy", "Eine Energiequelle betreibt einen Arbeitsplatz für 30 Spielsekunden; Verbrauch und Erzeugung werden bilanziert", false],
			["institutions", "Ein regionales Abkommen erfüllen ODER ein begrenztes Verteidigungsziel mit Versorgung der eigenen Truppen abschließen", false],
			["runtime", "Spielbare Neuzeit mit Industrie, Energienetz, globalen Orten und Fraktionsverwaltung sowie geprüftem Speichern/Laden", false],
		]},
}

static func describe(campaign: Dictionary, body_key: String, current_phase: int, target: int, economy_progress: Dictionary = {}) -> Dictionary:
	var rules: Dictionary = PHASES.get(target, {})
	if rules.is_empty():
		return {}
	var village: Dictionary = campaign.get("bodies", {}).get(body_key, {}).get("tribe", {})
	var owned: bool = not village.is_empty() and village.get("species_id") == campaign.get("player_species_id") and village.get("faction_id") == campaign.get("player_faction_id")
	var facts: Dictionary = {"housing": owned and int(village.get("huts", 0)) >= 2,
		"craft": owned and int(village.get("tools", 0)) >= 1,
		"farming": owned and int(village.get("garden", 0)) >= 1 and int(village.get("grown", 0)) >= 1}
	for goal: String in ["supply", "professions"]:
		facts[goal] = owned and bool(economy_progress.get(goal, {}).get("met", false))
	var requirements: Array[Dictionary] = []
	for requirement: Array in rules["requirements"]:
		requirements.append({"id": requirement[0], "text": str(requirement[1]) + ("\n" + str(economy_progress[requirement[0]]["text"]) if economy_progress.has(requirement[0]) else ""), "supported": requirement[2],
			"met": bool(requirement[2]) and bool(facts.get(requirement[0], false))})
	return {"version": VERSION, "target": target, "name": rules["name"], "action": rules["action"],
		"implemented": false, "available": false, "requires_confirmation": true,
		"sequential": target == current_phase + 1, "requirements": requirements,
		"blockers": ["%s bleibt gesperrt: Spielablauf und sichere Epochenübergabe fehlen noch." % rules["name"]],
		"retention": "Deine Spezies, Bewohner, Heimat, Gebäude, Vorräte, Aufträge, Entdeckungen und individuellen Tiere mit Besitz und Bindung bleiben erhalten. Der Wechsel benötigt eine ausdrückliche Bestätigung und einen vollständigen gemeinsamen Speicherstand."}

## Only a plan: calling this never spawns a settlement or promotes wildlife.
static func neighbor_plan(campaign: Dictionary, body_id: String, slot: int) -> Dictionary:
	if str(campaign.get("player_species_id", "")).is_empty() or str(campaign.get("player_faction_id", "")).is_empty() or body_id.is_empty() or slot < 0 or slot >= 16:
		return {}
	return {"contract": VERSION, "id": Ids.scoped("faction", str(campaign["player_species_id"]), body_id + ":neighbor:" + str(slot)),
		"species_id": campaign["player_species_id"], "body_id": body_id, "phase": 1,
		"technology": {}, "relation": "neutral", "status": "planned"}

static func validate_faction(faction: Dictionary, campaign: Dictionary) -> String:
	if faction.get("species_id") != campaign.get("player_species_id") or str(faction.get("species_id", "")).is_empty():
		return "Fremde Wildarten können keine Kulturfraktion bilden."
	if not faction.get("id") is String or faction["id"].is_empty() or faction["id"] == campaign.get("player_species_id"):
		return "Fraktion und Spezies benötigen getrennte Identitäten."
	if not faction.get("technology") is Dictionary or not preload("res://core/progression/behavior_catalog.gd").is_integer(faction.get("phase"), 1, 3):
		return "Eine Fraktion benötigt einen eigenen Technik- und Epochenstand."
	return ""

## Integration gate for the eventual transition adapter. Added fields are fine;
## existing bodies/extensions (including future D2 animal records) must survive.
static func validate_retention(before: Dictionary, after: Dictionary) -> String:
	for key: String in ["id", "player_species_id", "player_faction_id", "player_object_id"]:
		if not before.has(key) or before[key] != after.get(key):
			return "Epochenwechsel verändert eine bestehende Identität."
	for key: String in before:
		if key in ["recent_events", "event_cursors", "pending_transition", "completed_transitions"]:
			continue
		if not after.has(key) or not _retained(before[key], after[key]):
			return "Epochenwechsel verliert oder verändert Bestandsdaten: " + key
	return ""

static func _retained(before: Variant, after: Variant) -> bool:
	if before is Dictionary:
		if not after is Dictionary:
			return false
		for key: Variant in before:
			if not after.has(key) or not _retained(before[key], after[key]):
				return false
		return true
	return before == after
