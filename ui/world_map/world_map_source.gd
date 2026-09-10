extends RefCounted
const Source = preload("res://ui/minimap/minimap_source.gd")
const Surface = preload("res://core/map/surface_map_projection.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const Home = preload("res://world/home_group/home_group_state.gd")

static func campaign_snapshot(player: Node3D, tree: SceneTree) -> Dictionary:
	var snapshot: Dictionary = Source.campaign_snapshot(player, tree)
	if snapshot.is_empty(): return {}
	if snapshot.address.mode == Source.Cube.MODE:
		if not snapshot.has("explorers"): snapshot["explorers"] = [snapshot.address]
		return snapshot
	var tribe := tree.get_first_node_in_group(&"tribe_controller")
	var explorers: Array[Dictionary] = []
	if tribe != null and tribe.is_active():
		for actor: Node3D in tribe.actors.values():
			if is_instance_valid(actor): explorers.append(Surface.plane_address(snapshot.address.body_id, actor.global_position))
	else:
		explorers.append(Surface.plane_address(snapshot.address.body_id, player.global_position))
	# Camera panning is deliberately not an explorer.
	snapshot["explorers"] = explorers
	return snapshot

static func known_places(player: Node3D, tree: SceneTree, snapshot: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if snapshot.address.mode == Source.Cube.MODE:
		return tree.current_scene.known_map_places() if tree.current_scene.has_method("known_map_places") else result
	var state := tree.root.get_node("GameState")
	var body: Dictionary = state.get_current_body_record()
	var species_id: String = state.campaign.data.player_species_id
	for nest: Node3D in tree.get_nodes_in_group(&"player_nest"):
		if not is_instance_valid(nest): continue
		var address: Dictionary = Surface.plane_address(body.id, nest.global_position)
		var id: String = Ids.scoped("place", body.id, "player_nest:%d:%d" % [roundi(nest.global_position.x), roundi(nest.global_position.z)])
		result.append(_place(id, "Eigenes Nest", "nest", species_id, "", true, address))
	var home: Dictionary = state.get_current_body_record().get("home_group", {})
	if home.get("body_id") == body.id and Home.valid_position(home.get("anchor")):
		result.append(_place(str(home.id), "Heimat deiner Spezies", "home", species_id, "", true, Surface.plane_address(body.id, Home.vector(home.anchor))))
	var progression := tree.root.get_node("ProgressionService")
	# This reads the authoritative existing encounter ledger, never a second
	# species-wide friendship model. One ally doesn't turn its species into allies.
	for entry: Dictionary in progression._encounters.entries.values():
		if result.size() >= 2048: break
		if entry.body_id != body.id or entry.relation != "ally" or entry.dead or not entry.has("habitat"): continue
		var cell: PackedStringArray = str(entry.habitat.cell).split(":")
		if cell.size() != 2 or not cell[0].is_valid_int() or not cell[1].is_valid_int(): continue
		# Same stable placement as the fauna streamer, not the individual's last
		# moving position. This is its known habitat, not an invented nest.
		var random := RandomNumberGenerator.new()
		random.seed = int((str(state.get_world_seed()) + ":" + entry.habitat.cell).sha256_text().left(8).hex_to_int())
		var point := Vector3((int(cell[0]) + random.randf_range(0.3, 0.7)) * 12.0, 0, (int(cell[1]) + random.randf_range(0.3, 0.7)) * 12.0)
		var observed: Dictionary = progression.discovered_species.get(progression.species_discovery_key(int(entry.habitat.species_seed)), {})
		var name: String = str(observed.get("name", "Befreundete Kreatur")).left(180)
		result.append(_place(entry.object_id + ":habitat", name + " · Lebensraum", "friend_habitat", entry.species_id, entry.object_id, false, Surface.plane_address(body.id, point)))
	# Future real nest providers must supply a body-owned species/object identity.
	for provider: Node in tree.get_nodes_in_group(&"map_place_source"):
		if result.size() >= 2048: break
		if not provider.has_method("map_place"): continue
		var place: Dictionary = provider.map_place()
		if place.get("species_id") == species_id:
			place["own"] = true
		elif place.get("object_id") is String:
			var encounter: Dictionary = progression.get_saved_creature_encounter(place.object_id)
			if encounter.get("relation") != "ally" or encounter.get("dead", true) or encounter.get("body_id") != body.id: continue
			place["own"] = false
		else: continue
		if place.get("address", {}).get("body_id") == body.id: result.append(place)
	return result

static func visible_places(record: Dictionary, tree: SceneTree) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var progression := tree.root.get_node("ProgressionService")
	for place: Dictionary in record.get("places", {}).values():
		if not place.own:
			var entry: Dictionary = progression.get_saved_creature_encounter(place.object_id)
			if entry.get("body_id") != record.body_id or entry.get("relation") != "ally" or entry.get("dead", true): continue
		result.append(place)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return bool(a.own) if a.own != b.own else str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return result

static func visible_place_page(atlas: RefCounted, tree: SceneTree, offset: int = 0) -> Dictionary:
	var page: Dictionary = atlas.place_page(offset)
	if page.is_empty(): return {}
	var records: Dictionary = {}
	for place: Dictionary in page.places: records[place.id] = place
	# Friendship/death still comes from the encounter owner, never the atlas.
	page.places = visible_places({"body_id": atlas.data.body_id, "places": records}, tree)
	return page

static func _place(id: String, name: String, kind: String, species: String, object: String, own: bool, address: Dictionary) -> Dictionary:
	return {"id": id, "name": name, "kind": kind, "species_id": species, "object_id": object, "own": own, "address": address}
