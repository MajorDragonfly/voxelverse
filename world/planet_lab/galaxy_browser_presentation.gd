extends RefCounted
## Bounded, read-only presentation over the existing catalogue and addresses.
const Catalog = preload("res://world/space/galaxy_catalog.gd")
const Address = preload("res://world/space/galaxy_address.gd")
const Ui = preload("res://core/localization/ui_text.gd")
const PAGE_SIZE: int = 4
const SEARCH_LIMIT: int = 160

static func text(key: String, fallback: String, values: Dictionary = {}) -> String:
	var translated: String = Ui.text(key)
	return Ui._substitute(fallback if translated == key else translated, values)

static func resolve(source: RefCounted, query: String) -> Dictionary:
	var id: String = query.strip_edges()
	var address: Dictionary = Address.parse(id)
	if address.is_empty() or address.kind not in ["sector", "system", "body"] or not source.owns(id, address.kind):
		return {}
	# A syntactically valid slot need not exist in this deterministic sector.
	if address.kind == "system" and source.system(id).is_empty():
		return {}
	if address.kind == "body" and source.body(id).is_empty():
		return {}
	return address

static func matching_indices(entries: Array, query: String) -> Array[int]:
	var indices: Array[int] = []
	var needle: String = query.strip_edges().to_lower()
	if needle.length() > SEARCH_LIMIT:
		return indices
	for index in range(mini(entries.size(), Address.MAX_SYSTEMS)):
		var entry: Dictionary = entries[index]
		if needle.is_empty() or needle in str(entry.id).to_lower() or needle in str(entry.name).to_lower():
			indices.append(index)
	return indices

static func ordered_bodies(system: Dictionary) -> Array:
	var bodies: Array = system.get("bodies", {}).values()
	bodies.sort_custom(func(a: Dictionary, b: Dictionary): return int(Address.parse(a.id).get("body_slot", 0)) < int(Address.parse(b.id).get("body_slot", 0)))
	return bodies

static func kind_label(kind: String) -> String:
	match kind:
		"star": return text("GALAXY_STAR", "Stern")
		"planet": return text("GALAXY_PLANET", "Gesteinsplanet")
		"gas_giant": return text("GALAXY_GAS_GIANT", "Gasriese")
		"moon": return text("GALAXY_MOON", "Mond")
	return "—"

static func size_km(metres: float) -> String:
	return Ui.number(metres / 1000.0, 1) + " km"

static func orbit_distance(metres: float) -> String:
	var kilometres: String = size_km(metres)
	return Ui.number(metres / Catalog.AU_M, 3) + " AU (" + kilometres + ")" if metres >= Catalog.AU_M * 0.01 else kilometres

static func period(seconds: float) -> String:
	return Ui.number(seconds / 86400.0, 2) + text("GALAXY_DAYS_UNIT", " Tage") if seconds >= 86400.0 else Ui.number(seconds / 3600.0, 2) + " h"

static func distance_ly(position: Dictionary, origin: Dictionary) -> String:
	var delta: Array = Address.relative_ly(position, origin)
	if delta.size() != 3:
		return "—"
	var length: float = sqrt(delta[0] * delta[0] + delta[1] * delta[1] + delta[2] * delta[2])
	return Ui.number(length, 3) + text("GALAXY_LY_UNIT", " Lichtjahre")

static func body_details(system: Dictionary, body: Dictionary, visit: Dictionary = {}) -> String:
	if body.is_empty():
		return ""
	var lines: PackedStringArray = [str(body.name), kind_label(body.kind), str(body.id), ""]
	lines.append(text("GALAXY_DIAMETER", "Durchmesser: {value}", {"value": size_km(float(body.radius) * 2.0)}))
	lines.append(text("GALAXY_RADIUS", "Radius: {value}", {"value": size_km(body.radius)}))
	lines.append(text("GALAXY_GRAVITY", "Oberflächengravitation: {value} m/s²", {"value": Ui.number(body.gravity, 2)}))
	if body.kind == "star":
		lines.append(text("GALAXY_SPECTRAL", "Spektralklasse: {value}", {"value": body.get("spectral_class", "—")}))
	if body.orbit_radius > 0:
		var parent: String = str(system.bodies.get(body.parent_id, {}).get("name", text("GALAXY_BARYCENTRE", "Gemeinsamer Schwerpunkt")))
		lines.append(text("GALAXY_ORBIT_PARENT", "Umlauf um: {parent}", {"parent": parent}))
		lines.append(text("GALAXY_ORBIT_DISTANCE", "Abstand zum Bahnzentrum: {value}", {"value": orbit_distance(body.orbit_radius)}))
		lines.append(text("GALAXY_ORBIT_PERIOD", "Umlaufzeit: {value}", {"value": period(body.orbit_period)}))
	lines.append(text("GALAXY_ROTATION", "Rotationsdauer: {value}", {"value": period(body.rotation_period)}))
	lines.append(text("GALAXY_LANDABLE", "Begehbare Oberfläche") if body.landable else text("GALAXY_NOT_LANDABLE", "Keine begehbare Oberfläche"))
	if body.landable:
		if visit.get("error", ERR_UNCONFIGURED) != OK:
			lines.append(text("GALAXY_VISIT_UNKNOWN", "Besuchsdaten nicht verfügbar"))
		elif visit.get("record", {}).get("bodies", {}).has(body.id):
			lines.append(text("GALAXY_VISITED", "Bereits besucht · Rückkehrpunkt gespeichert"))
		else:
			lines.append(text("GALAXY_NOT_VISITED", "Kein gespeicherter Besuch"))
	return "\n".join(lines)
