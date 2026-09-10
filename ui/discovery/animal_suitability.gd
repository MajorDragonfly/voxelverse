extends RefCounted
## D1 reader only. Never generates suitability or searches an unscanned catalog.
const Records = preload("res://core/discovery/discovery_records.gd")
const CONTRACT_PATH := "res://world/fauna/domestication/domestication_contract.gd"
const ROLES := {"milk": "Milchtier", "draught": "Zugtier", "riding": "Reittier", "companion": "Begleittier", "eggs": "Eiertier"}

static func contract() -> Script:
	return load(CONTRACT_PATH) as Script if ResourceLoader.exists(CONTRACT_PATH) else null

static func read(entry: Dictionary, validator: Script) -> Dictionary:
	var scan: Dictionary = Records.as_dictionary(entry.get("scan", {}))
	if scan.get("version") != 1 or scan.get("complete") != true:
		return {}
	var visual: Dictionary = Records.visual_for(entry)
	var species: Dictionary = Records.as_dictionary(visual.get("species", {}))
	var value: Variant = species.get("domestication")
	if validator == null or not value is Dictionary or not validator.has_method("validate"):
		return {}
	# D1 owns supported role revisions, units and suitability rules.
	if validator.get("SCHEMA") != 1:
		return {}
	if not str(validator.call("validate", value)).is_empty():
		return {}
	return value.duplicate(true)

static func describe(profile: Dictionary) -> String:
	if profile.is_empty():
		return "TIERROLLEN\nFür diese Beobachtung sind keine lesbaren Eignungsdaten vorhanden.\n\nEin Artenscan oder eine Freundschaft bedeutet keine Zähmung."
	var roles := PackedStringArray()
	for role in profile["roles"]:
		roles.append(ROLES[role])
	var food := PackedStringArray()
	for kind in profile["diet"]:
		food.append("Pflanzen" if kind == "plant" else "Fleisch")
	var lines := PackedStringArray(["TIERROLLEN · GESCANNTE ART", " · ".join(roles),
		"Grundsätzlich zähmbar · %s" % ("ruhiges Temperament" if profile["temperament"] == "calm" else "soziales Temperament"),
		"Nahrung: %s · Wasser: %s l je 300 Spielsekunden" % [", ".join(food), number(profile["water_need"])],
		"Lernfähigkeit: %d %% · Sozialverträglichkeit: %d %% · Bindungsfähigkeit: %d %%" % [roundi(profile["trainability"] * 100), roundi(profile["sociality"] * 100), roundi(profile["bonding"] * 100)],
		"Ausdauer bei Nennlast: %s s · Bodentempo: %s m/s" % [number(profile["stamina"]), number(profile["movement_speed"])],
		"Wahrnehmung: %s m" % number(profile["perception_range"])])
	if "milk" in profile["roles"]:
		lines.append("Milcheignung: %s l je %s aktive Spielsekunden" % [number(profile["milk_yield"]), number(profile["milk_interval"])])
	if "eggs" in profile["roles"]:
		lines.append("Eiertier: geeignet für spätere Eierhaltung. Eiergewinnung ist noch nicht verfügbar.")
	if "draught" in profile["roles"]:
		lines.append("Zugkraft: %s N · benötigt passenden Geschirr-Anschluss" % number(profile["strength"]))
	if "riding" in profile["roles"]:
		lines.append("Zusätzliche Traglast: %s kg · benötigt passenden Sattel-Anschluss" % number(profile["carry_capacity"]))
	lines.append("\nArt-Eignung ist kein Tierbesitz. Zähmung beginnt im Stammeszeitalter. Reiten, Pflügen und Milchgewinnung benötigen ein eigenes Tier und die passende Versorgung und Ausrüstung.")
	return "\n".join(lines)

static func number(value: float) -> String:
	return ("%.1f" % value).trim_suffix("0").trim_suffix(".").replace(".", ",")
