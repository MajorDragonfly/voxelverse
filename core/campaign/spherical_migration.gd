extends RefCounted
## Pure, fail-closed migration planning. Runtime services perform source
## validation and the atomic copy; this module never writes or imports a game.
const Surface = preload("res://core/campaign/surface_context.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Atlas = preload("res://core/map/exploration_atlas.gd")
const SCHEMA: int = 1
const MAX_SOURCE_BYTES: int = 16 * 1024 * 1024

static func blockers(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if int(source.get("schema", 0)) < 3:
		return ["Diesen alten Stand zuerst laden und speichern, damit Identitäten und Entwürfe eingebettet sind."]
	var state: Dictionary = source.game_state
	var campaign: Dictionary = state.campaign
	if int(state.phase) != 0: result.append("Die Stammesphase benötigt noch die radialen Bewohner-, Bau- und Transportanschlüsse (M1g).")
	if not campaign.pending_transition.is_empty(): result.append("Ein Phasenwechsel ist noch nicht abgeschlossen.")
	for body: Dictionary in campaign.bodies.values():
		var id: String = str(body.id)
		if body.surface_mode != Surface.LEGACY: result.append(id + ": bereits Kugelwelt; kein erneuter Flachweltumzug.")
		for field in ["home_group", "tribe", "tribal_neighbor", "domesticated_animals", "fauna_catalog"]:
			if body.has(field): result.append(id + "/" + field + ": Zielorte und zugehörige Laufzeit sind noch nicht vollständig angebunden.")
		# Unknown body extensions may contain ownership or places. A whitelist is
		# intentional: adding a consumer requires an explicit migration adapter.
		for field in body:
			if field not in ["id", "system_id", "seed", "generator_version", "surface_mode", "exploration_atlas",
					"home_group", "tribe", "tribal_neighbor", "domesticated_animals", "fauna_catalog"]:
				result.append(id + "/" + str(field) + ": unbekannte Körperdaten; Übernahme muss ausdrücklich geprüft werden.")
	for key in source.get("regions_by_world", {}):
		if not source.regions_by_world[key] is Dictionary or not source.regions_by_world[key].is_empty():
			result.append("Regionen von Welt " + str(key) + ": persistente Ökologie/Änderungen benötigen eine regionale Zielzuordnung.")
	for entry: Dictionary in source.progression.get("creature_encounters", {}).get("entries", {}).values():
		if entry.get("relation") == "ally" and not entry.get("dead", false):
			result.append("Befreundetes Individuum " + str(entry.get("object_id", "")) + ": Lebensraum und Wiederbegegnung müssen auf der Kugel angebunden sein (M1f).")
	if source.player.has("position") and not Surface.vector(source.player.position, 1.0e7):
		result.append("Der alte Spielerort ist ungültig.")
	for field in ["yaw", "camera_yaw", "camera_pitch"]:
		if source.player.has(field) and not Surface.number(source.player[field], -1.0e8, 1.0e8): result.append("Ungültiger Spielerwert: " + field)
	for field in ["health_ratio", "hunger_ratio", "thirst_ratio"]:
		if source.player.has(field) and not Surface.number(source.player[field], 0.0, 1.0): result.append("Ungültiger Spielerwert: " + field)
	return result

static func plan(source: Dictionary, source_text: String, source_path: String) -> Dictionary:
	var errors: Array[String] = blockers(source)
	if source_text.to_utf8_buffer().size() > MAX_SOURCE_BYTES: errors.append("Quelle überschreitet das 16-MiB-Budget dieser Kopiermigration.")
	if not errors.is_empty(): return {"ok": false, "blockers": errors}
	var data: Dictionary = source.duplicate(true)
	var campaign: Dictionary = data.game_state.campaign
	var mappings: Array = []
	for key in campaign.bodies.keys():
		var old: Dictionary = campaign.bodies[key]
		var body: Dictionary = Surface.create(old)
		if body.is_empty():
			return {"ok": false, "blockers": [str(old.id) + ": kein trockener, hinreichend ebener Zielbereich im begrenzten Suchbudget."]}
		if body.has("exploration_atlas"):
			body.legacy_exploration_atlas = body.exploration_atlas
		body.exploration_atlas = Atlas.create(body.id, Cube.MODE, body.surface_context.radius)
		campaign.bodies[key] = body
		mappings.append({"body_id": body.id, "source_mode": Surface.LEGACY, "target_mode": Cube.MODE,
			"target_spawn": body.surface_context.spawn.duplicate(true), "target_context_sha256": fingerprint(body.surface_context)})
	var active: Dictionary = campaign.bodies.get(str(int(data.game_state.world_seed)), {})
	if active.is_empty(): return {"ok": false, "blockers": ["Der aktive Körper fehlt im Quellstand."]}
	var player: Dictionary = data.player
	var address: Dictionary = active.surface_context.spawn
	var up: Vector3 = Cube.vector(Cube.direction(address.face, address.u, address.v))
	var heading: Vector3 = -Cube.frame(up).z
	if Surface.number(player.get("yaw", 0.0), -1.0e8, 1.0e8): heading = heading.rotated(up, float(player.get("yaw", 0.0)))
	player.merge({"surface_address": address.duplicate(true), "surface_forward": [heading.x, heading.y, heading.z],
		"surface_velocity": [0.0, 0.0, 0.0], "surface_pitch": clampf(float(player.get("camera_pitch", -0.18)), -0.85, 0.5)}, true)
	# Old XYZ/camera/needs remain intact as source evidence. The new runtime
	# consumes surface_address only. No species, object, award or design is made.
	campaign.schema = 2
	campaign.surface_policy = Cube.MODE
	data.schema = 8
	var manifest := {"schema": SCHEMA, "algorithm": "early_campaign_copy_v1",
		"source_path": source_path, "source_sha256": source_text.sha256_text(),
		"source_schema": source.schema, "source_campaign_schema": source.game_state.campaign.schema,
		"campaign_id": campaign.id, "mapping": mappings,
		"inventory": inventory(source), "source_text": source_text,
		"source_player_address": source.player.get("surface_address", {}).duplicate(true)}
	manifest["id"] = fingerprint(manifest)
	campaign.surface_migration = manifest
	data.slot_origin = {"kind": "spherical_migration", "campaign_id": campaign.id, "manifest_id": manifest.id}
	data.slot_name = str(data.get("slot_name", "Mein Abenteuer")).left(32) + " – Kugelkopie"
	data.erase("slot_history")
	return {"ok": true, "blockers": [], "data": data, "manifest": manifest}

static func inventory(source: Dictionary) -> Dictionary:
	var campaign: Dictionary = source.game_state.campaign
	return {"progression_sha256": fingerprint(source.progression), "designs_sha256": fingerprint(source.design_files),
		"regions_sha256": fingerprint(source.get("regions_by_world", {})),
		"events_sha256": fingerprint([campaign.event_cursors, campaign.recent_events, campaign.completed_transitions]),
		"identity_sha256": fingerprint([campaign.id, campaign.player_object_id, campaign.player_species_id, campaign.player_faction_id]),
		"elapsed_seconds": campaign.elapsed_seconds, "body_count": campaign.bodies.size()}

static func fingerprint(value: Variant) -> String:
	# Match AtomicJson's JSON precision, including the int/float round trip.
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true).sha256_text()

static func validate(manifest: Variant) -> String:
	if not manifest is Dictionary or manifest.get("schema") != SCHEMA or manifest.get("algorithm") != "early_campaign_copy_v1":
		return "Unbekanntes Umzugsmanifest."
	if not manifest.get("source_text") is String or manifest.source_text.to_utf8_buffer().size() > MAX_SOURCE_BYTES:
		return "Quellarchiv fehlt oder überschreitet das Budget."
	if manifest.get("source_sha256") != manifest.source_text.sha256_text(): return "Quellarchiv stimmt nicht mit dem Manifest überein."
	var signed: Dictionary = manifest.duplicate(true)
	signed.erase("id")
	if manifest.get("id") != fingerprint(signed): return "Umzugsmanifest wurde beschädigt."
	var source: Variant = JSON.parse_string(manifest.source_text)
	if not source is Dictionary or not source.get("game_state") is Dictionary or not source.game_state.get("campaign") is Dictionary:
		return "Quellarchiv ist nicht lesbar."
	for key in ["progression", "design_files", "regions_by_world", "player"]:
		if not source.get(key) is Dictionary: return "Ungültiger Quellabschnitt: " + key
	var campaign: Dictionary = source.game_state.campaign
	for key in ["bodies", "event_cursors", "completed_transitions"]:
		if not campaign.get(key) is Dictionary: return "Ungültiger Kampagnenabschnitt im Archiv: " + key
	if not campaign.get("recent_events") is Array or not Surface.number(campaign.get("elapsed_seconds"), 0.0, 1.0e15): return "Ungültige Zeit-/Ereignisdaten im Archiv."
	for key in ["id", "player_object_id", "player_species_id", "player_faction_id"]:
		if not campaign.get(key) is String: return "Fehlende Identität im Quellarchiv: " + key
	if source.game_state.campaign.has("surface_migration") and not source.game_state.campaign.surface_migration.is_empty():
		return "Verschachtelte Umzugsarchive sind nicht erlaubt."
	if manifest.get("campaign_id") != source.game_state.campaign.get("id") or manifest.get("source_schema") != source.get("schema") or manifest.get("source_campaign_schema") != source.game_state.campaign.get("schema"):
		return "Quellversion oder Identität stimmt nicht überein."
	if not manifest.get("inventory") is Dictionary or fingerprint(manifest.inventory) != fingerprint(inventory(source)): return "Quellinventar stimmt nicht überein."
	if not manifest.get("mapping") is Array or manifest.mapping.size() != source.game_state.campaign.bodies.size(): return "Körperzuordnung ist unvollständig."
	var seen: Dictionary = {}
	for row in manifest.mapping:
		if not row is Dictionary or not row.get("body_id") is String or seen.has(row.body_id) or row.get("source_mode") != Surface.LEGACY or row.get("target_mode") != Cube.MODE or not Surface.location(row.get("target_spawn"), row.body_id) or not row.get("target_context_sha256") is String or row.target_context_sha256.length() != 64:
			return "Ungültige oder doppelte Zielzuordnung."
		seen[row.body_id] = true
	for body in source.game_state.campaign.bodies.values():
		if not body is Dictionary or not seen.has(body.get("id")): return "Quellkörper fehlt in der Zielzuordnung."
	return ""
