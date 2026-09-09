extends SceneTree
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Contract = preload("res://world/fauna/domestication/domestication_contract.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://d1-runtime.json"
	state.start_world_with_seed(15838)
	change_scene_to_file("res://main/main.tscn")
	await scene_changed
	var player: CharacterBody3D = current_scene.get_node("Player")
	var streamer: Node3D = current_scene.get_node("FaunaStreamerV7")
	var manager: Node = current_scene.get_node("WorldManager")
	player.is_dead = true
	var groups: Dictionary = {}
	for frame in range(900):
		await physics_frame
		if frame % 20 != 0: continue
		for animal in streamer._active_fauna:
			if is_instance_valid(animal) and not animal.catalog_species.is_empty(): groups[animal.catalog_species["group"]] = true
		if groups.size() == 3 and streamer.domestic_fauna.plants.size() >= 3: break
	var catalog: Dictionary = streamer.domestic_fauna.catalog
	if groups.size() < 3:
		print({"player": player.position, "active": streamer._active_fauna.size()})
		for habitat: Dictionary in catalog.get("habitats", []):
			var p: Array = habitat["position"]
			var point := Vector3(p[0], p[1], p[2])
			var entry: Dictionary = Catalog.species_for(catalog, habitat["species_id"])
			print({"group": entry["group"], "position": point, "distance": point.distance_to(player.position), "clear": not streamer.domestic_fauna.placement(streamer, point, entry["visual_scale"]).is_empty()})
	check(bool(manager.world_initialized), "World did not initialize")
	check(not catalog.is_empty() and catalog.get("habitat_status") == "ready", "Live spawner did not prepare guaranteed habitats")
	check(groups.size() == 3, "Three roles did not reach the live scene: " + str(groups))
	check(streamer._active_fauna.size() <= streamer.maximum_population, "Mandatory fauna exceeded spawn cap")
	# Exercise the real limit with all three reserved roles and ordinary fauna.
	streamer.target_population = 3
	streamer.maximum_population = 3
	for frame in range(180): await physics_frame
	var capped_groups: Dictionary = {}
	for animal in streamer._active_fauna:
		if is_instance_valid(animal) and not animal.catalog_species.is_empty(): capped_groups[animal.catalog_species["group"]] = true
	check(streamer._active_fauna.size() <= 3 and capped_groups.size() == 3, "Ordinary population starved a mandatory role at the cap")
	streamer.set_process(false)
	player.set_physics_process(false)
	var bodies: Array = []
	var identities: Array = []
	for animal in streamer._active_fauna:
		if not is_instance_valid(animal) or animal.catalog_species.is_empty(): continue
		animal.set_physics_process(false)
		var entry: Dictionary = animal.catalog_species
		check(Contract.validate(animal.get_inspection_data()["domestication"]).is_empty(), "Inspection missing actual suitability")
		check(animal.get_campaign_identity()["species_id"] == entry["id"], "Runtime species identity mismatch")
		check(animal.blueprint["species"]["id"] == entry["id"], "Runtime regenerated frozen blueprint")
		check(animal._preview._motion._legs.size() == 4, "Runtime body lacks four articulated support legs")
		check(is_equal_approx(animal._move_speed, float(entry["domestication"]["movement_speed"])), "Movement ignored species profile")
		check(is_equal_approx(animal.sight_range, float(entry["domestication"]["perception_range"])), "Perception ignored species profile")
		check(animal.get_node("SocialBehavior").entry()["relation"] == "wild", "Suitability automatically befriended animal")
		bodies.append({"group": entry["group"], "legs": animal._preview._motion._legs.size(), "position": str(animal.position), "speed": animal._move_speed})
		identities.append(animal.get_campaign_identity()["object_id"])
		var social: Dictionary = animal.get_node("SocialBehavior").entry()
		check(root.get_node("ProgressionService").store_creature_encounter(social)["ok"], "Store visible identity")
	var live_food_sources: int = streamer.domestic_fauna.plants.size()
	check(live_food_sources >= 3, "Missing live food at mandatory populations")
	check(saves.save_now(), "Save live fauna: " + saves.last_error)
	check(saves.load_now(), "Reload live fauna: " + saves.last_error)
	await process_frame
	# The reloaded spawner rebinds the persisted catalog, not its stale reference.
	streamer._prune_fauna()
	streamer.domestic_fauna.update(streamer)
	var reloaded: Dictionary = streamer.domestic_fauna.catalog
	check(not reloaded.is_empty(), "Runtime failed to rebind loaded catalog")
	# Kill every representative habitat of one role and use simulation time.
	if not reloaded.is_empty():
		var species: Dictionary = reloaded["species"][0]
		var old_ids: Array = []
		for habitat: Dictionary in reloaded["habitats"]:
			if habitat["species_id"] != species["id"]: continue
			var object_id: String = Catalog.object_id(state, habitat)
			old_ids.append(object_id)
			var identity := {"object_id": object_id, "body_id": reloaded["body_id"], "region_id": habitat["region_id"], "species_id": species["id"], "species_seed": species["species_seed"], "habitat_cell": Catalog.cell_key(habitat)}
			var entry: Dictionary = root.get_node("ProgressionService").get_creature_encounter(identity, species["role"], 999)
			entry["dead"] = true
			entry["health_ratio"] = 0.0
			entry["carcass_food"] = 0.0
			check(root.get_node("ProgressionService").store_creature_encounter(entry)["ok"], "Store depleted role")
		streamer.domestic_fauna.update(streamer)
		var before: String = JSON.stringify(reloaded["habitats"])
		streamer.domestic_fauna.update(streamer)
		check(JSON.stringify(reloaded["habitats"]) == before, "Repeated load/spawn advanced recovery")
		state.campaign.data["elapsed_seconds"] += Catalog.REPLACEMENT_SECONDS + 0.01
		streamer.domestic_fauna.update(streamer)
		for habitat: Dictionary in reloaded["habitats"]:
			if habitat["species_id"] != species["id"]: continue
			check(int(habitat["generation"]) == 1 and Catalog.object_id(state, habitat) not in old_ids, "Extinction recovery resurrected old identity")
		for old_id in old_ids:
			check(root.get_node("ProgressionService").get_saved_creature_encounter(old_id)["dead"], "Recovery erased tombstone")
		check(saves.save_now(), "Save recovery lifecycle")
	print(JSON.stringify({"test": "domestic_fauna_runtime", "failures": failures, "bodies": bodies, "food_sources": live_food_sources}))
	current_scene.queue_free()
	for frame in range(12): await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
