extends RefCounted
## Pure, fail-closed migration planning. Runtime services perform source
## validation and the atomic copy; this module never writes or imports a game.
const Surface = preload("res://core/campaign/surface_context.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Atlas = preload("res://core/map/exploration_atlas.gd")
const Blueprint = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Places = preload("res://core/campaign/spherical_place_migration.gd")
const Registry = preload("res://core/campaign/body_registry.gd")
const SCHEMA: int = 1
const MAX_SOURCE_BYTES: int = 16 * 1024 * 1024

static func blockers(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if int(source.get("schema", 0)) < 3:
		return ["Diesen alten Stand zuerst laden und speichern, damit Identitäten und Entwürfe eingebettet sind."]
	var state: Dictionary = source.game_state
	var campaign: Dictionary = state.campaign
	if source.design_files.has(Blueprint.SAVE_PATH):
		var design: Variant = JSON.parse_string(source.design_files[Blueprint.SAVE_PATH])
		if not design is Dictionary or design.get("version") != Blueprint.SAVE_VERSION:
			result.append("Der aktuelle Kreaturenentwurf hat ein unbekanntes Format und bleibt unverändert.")
	if int(state.phase) not in [0, 1]: result.append("Für dieses Zeitalter fehlt noch eine vollständige Kugellaufzeit.")
	if int(state.phase) == 1 and not Registry.active(state).has("tribe"): result.append("M1g: Stammesphase ohne gespeichertes Dorf.")
	if not campaign.pending_transition.is_empty(): result.append("Ein Phasenwechsel ist noch nicht abgeschlossen.")
	for body: Dictionary in campaign.bodies.values():
		var id: String = str(body.id)
		if body.surface_mode != Surface.LEGACY: result.append(id + ": bereits Kugelwelt; kein erneuter Flachweltumzug.")
		# Unknown body extensions may contain ownership or places. A whitelist is
		# intentional: adding a consumer requires an explicit migration adapter.
		for field in body:
			if field not in ["id", "system_id", "seed", "generator_version", "surface_mode", "exploration_atlas",
					"home_group", "tribe", "tribal_neighbor", "domesticated_animals", "fauna_catalog", "wildlife_foraging", "wildlife_drinking", "legacy_population"]:
				result.append(id + "/" + str(field) + ": unbekannte Körperdaten; Übernahme muss ausdrücklich geprüft werden.")
	for key in source.get(Registry.regions_field(source), {}):
		var record: Variant = source[Registry.regions_field(source)][key]
		if not record is Dictionary or (not record.is_empty() and (record.get("schema") != 1 or not record.get("regions") is Dictionary)):
			result.append("Regionen von Welt " + str(key) + ": unbekannter regionaler Vertrag.")
		elif not record.is_empty():
			var seed_value: int = int(Registry.by_id(campaign, str(key)).get("seed", 0)) if int(source.schema) >= Registry.SAVE_SCHEMA else int(key)
			var problem: String = preload("res://world/surface/campaign_ecology_state.gd").legacy_problem(record, seed_value)
			if not problem.is_empty(): result.append(str(key) + ": " + problem)
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
	var active_id: String = str(Registry.active(data.game_state).get("id", ""))
	var regions_field: String = Registry.regions_field(data)
	var mappings: Array = []
	var player_address: Dictionary = {}
	for key in campaign.bodies.keys():
		var old: Dictionary = campaign.bodies[key]
		var body: Dictionary = Surface.create(old)
		if body.is_empty():
			return {"ok": false, "blockers": [str(old.id) + ": kein trockener, hinreichend ebener Zielbereich im begrenzten Suchbudget."]}
		var converter := Places.new()
		var active_player: Dictionary = source.player if old.id == active_id else {}
		var converted: Dictionary = converter.convert(old, body, active_player,
			source.progression.get("creature_encounters", {}).get("entries", {}), source.get(regions_field, {}).get(key, {}))
		if not converted.ok: return {"ok": false, "blockers": converted.errors}
		body = converted.body
		if not active_player.is_empty(): player_address = converted.player
		if body.has("surface_ecology"): data[regions_field].erase(key)
		if body.has("exploration_atlas"):
			body.legacy_exploration_atlas = body.exploration_atlas
		body.exploration_atlas = Atlas.create(body.id, Cube.MODE, body.surface_context.radius)
		campaign.bodies[key] = body
		mappings.append({"body_id": body.id, "source_mode": Surface.LEGACY, "target_mode": Cube.MODE,
			"target_spawn": body.surface_context.spawn.duplicate(true), "target_context_sha256": fingerprint(body.surface_context), "regions": converted.regions, "places": converted.places})
	var active: Dictionary = Registry.active(data.game_state)
	if active.is_empty(): return {"ok": false, "blockers": ["Der aktive Körper fehlt im Quellstand."]}
	var player: Dictionary = data.player
	var address: Dictionary = player_address if not player_address.is_empty() else active.surface_context.spawn
	var up: Vector3 = Cube.vector(Cube.direction(address.face, address.u, address.v))
	var heading: Vector3 = -Cube.frame(up).z
	if Surface.number(player.get("yaw", 0.0), -1.0e8, 1.0e8): heading = heading.rotated(up, float(player.get("yaw", 0.0)))
	player.merge({"surface_address": address.duplicate(true), "surface_forward": [heading.x, heading.y, heading.z],
		"surface_velocity": [0.0, 0.0, 0.0], "surface_pitch": clampf(float(player.get("camera_pitch", -0.18)), -0.85, 0.5)}, true)
	# Old XYZ/camera/needs remain intact as source evidence. The new runtime
	# consumes surface_address only. No species, object, award or design is made.
	campaign.schema = maxi(2, int(campaign.schema))
	campaign.surface_policy = Cube.MODE
	data.schema = maxi(8, int(data.schema))
	var manifest := {"schema": SCHEMA, "algorithm": "campaign_places_copy_v2",
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

static func inventory(source: Dictionary, include_gameplay: bool = true) -> Dictionary:
	var campaign: Dictionary = source.game_state.campaign
	var result := {"progression_sha256": fingerprint(source.progression), "designs_sha256": fingerprint(source.design_files),
		"regions_sha256": fingerprint(regional_inventory(source)),
		"events_sha256": fingerprint([campaign.event_cursors, campaign.recent_events, campaign.completed_transitions]),
		"identity_sha256": fingerprint([campaign.id, campaign.player_object_id, campaign.player_species_id, campaign.player_faction_id]),
		"elapsed_seconds": campaign.elapsed_seconds, "body_count": campaign.bodies.size()}
	if include_gameplay:
		var gameplay: Dictionary = {}
		for body: Dictionary in campaign.bodies.values():
			var objects: Dictionary = {}
			for section in ["home_group", "tribe", "tribal_neighbor", "domesticated_animals", "wildlife_foraging", "wildlife_drinking", "fauna_catalog"]:
				if not body.has(section): continue
				var value: Dictionary = body[section].duplicate(true)
				if section == "tribe": Places.Tribe.upgrade(value)
				if section == "fauna_catalog" and value.has("migration_source"): value = value.migration_source.catalog
				objects[section] = _nonspatial(value)
			gameplay[body.id] = objects
		result["gameplay_sha256"] = fingerprint(gameplay)
	return result

static func _nonspatial(value: Variant, field: String = "") -> Variant:
	if field in ["blueprint", "recipe", "design_ref"]: return value
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			if key in ["schema", "surface_mode", "anchor", "position", "destination", "entrance", "workplace", "pickup", "home", "wait_position", "sites", "foundation", "path"]: continue
			result[key] = _nonspatial(value[key], key)
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(_nonspatial(item))
		return result
	return value

static func regional_inventory(source: Dictionary) -> Dictionary:
	var result: Dictionary = source.get(Registry.regions_field(source), {}).duplicate(true)
	for key in source.game_state.campaign.bodies:
		var body: Dictionary = source.game_state.campaign.bodies[key]
		if body.has("surface_ecology"): result[key] = body.surface_ecology.legacy_state.duplicate(true)
	return result

static func fingerprint(value: Variant) -> String:
	# Match AtomicJson's JSON precision, including the int/float round trip.
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true).sha256_text()

static func validate(manifest: Variant) -> String:
	if not manifest is Dictionary or manifest.get("schema") != SCHEMA or manifest.get("algorithm") not in ["early_campaign_copy_v1", "campaign_places_copy_v2"]:
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
	for key in ["progression", "design_files", Registry.regions_field(source), "player"]:
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
	if not manifest.get("inventory") is Dictionary or fingerprint(manifest.inventory) != fingerprint(inventory(source, manifest.algorithm == "campaign_places_copy_v2")): return "Quellinventar stimmt nicht überein."
	if not manifest.get("mapping") is Array or manifest.mapping.size() != source.game_state.campaign.bodies.size(): return "Körperzuordnung ist unvollständig."
	var seen: Dictionary = {}
	for row in manifest.mapping:
		if not row is Dictionary or not row.get("body_id") is String or seen.has(row.body_id) or row.get("source_mode") != Surface.LEGACY or row.get("target_mode") != Cube.MODE or not Surface.location(row.get("target_spawn"), row.body_id) or not row.get("target_context_sha256") is String or row.target_context_sha256.length() != 64:
			return "Ungültige oder doppelte Zielzuordnung."
		seen[row.body_id] = true
		if manifest.algorithm == "campaign_places_copy_v2":
			if not row.get("places") is Dictionary or not row.get("regions") is Dictionary or row.places.size() > Places.MAX_PLACES or row.regions.is_empty(): return "Unvollständiges Ortsmanifest."
			for key in row.places:
				var p: Variant = row.places[key]
				if not p is Dictionary or not Surface.vector(p.get("source"), 1e7) or key != JSON.stringify(p.source) or not Surface.location(p.get("target"), row.body_id): return "Ungültige Quell-/Zieladresse im Manifest."
			for p in row.regions.values():
				if not p is Dictionary or not Surface.vector(p.get("source"), 1e7) or not Surface.location(p.get("target"), row.body_id): return "Ungültige Regionszuordnung im Manifest."
	for body in source.game_state.campaign.bodies.values():
		if not body is Dictionary or not seen.has(body.get("id")): return "Quellkörper fehlt in der Zielzuordnung."
	return ""
