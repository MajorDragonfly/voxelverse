extends SceneTree
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Planner = preload("res://world/fauna/domestication/domestic_habitat_planner.gd")
const Evidence = preload("res://world/fauna/domestication/domestic_body_evidence.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://d11-live-recovery.json"
	state.start_world_with_seed(15838)
	var catalog: Dictionary = Catalog.ensure(state)
	var planner := Planner.new()
	planner.begin(root.get_node("WorldGenerator"))
	while not planner.finished: planner.step(root.get_node("WorldGenerator"), catalog, 32)
	catalog["habitats"] = planner.habitats.slice(0, 1)
	catalog["habitat_status"] = "unavailable"
	catalog["habitats"][0]["generation"] = 7
	var old_habitat: String = JSON.stringify(catalog["habitats"][0])
	var old_identity: String = Catalog.object_id(state, catalog["habitats"][0])
	check(saves.save_now(), "Save a partial D1 catalog")
	change_scene_to_file("res://main/main.tscn")
	await scene_changed
	var player: CharacterBody3D = current_scene.get_node("Player")
	player.is_dead = true
	var streamer: Node3D = current_scene.get_node("FaunaStreamerV7")
	streamer.target_population = 3
	streamer.maximum_population = 3
	var groups: Dictionary = {}
	# Terrain workers and streamed collision advance independently of physics
	# ticks. Fast/catch-up ticks can exhaust a frame count before a habitat's
	# ground exists, even though recovery has already supplied its catalog row.
	var population_started := Time.get_ticks_msec()
	var population_deadline := population_started + 60_000
	while Time.get_ticks_msec() < population_deadline:
		await process_frame
		groups.clear()
		for animal in streamer._active_fauna:
			if is_instance_valid(animal) and not animal.catalog_species.is_empty(): groups[animal.catalog_species["group"]] = true
		if groups.size() == 3 and streamer.domestic_fauna.plants.size() >= 3: break
	var population_wait := {"elapsed_ms": Time.get_ticks_msec() - population_started,
		"body_id": streamer.domestic_fauna.body_id,
		"pending_chunks": current_scene.get_node("WorldManager").get_pending_chunk_count(),
		"active_count": streamer._active_fauna.size(), "plants": streamer.domestic_fauna.plants.size()}
	streamer.set_process(false)
	catalog = streamer.domestic_fauna.catalog
	check(catalog.get("habitat_status") == "ready" and catalog.get("habitat_recovery", {}).get("status") == "ready", "Live runtime did not finish recovery")
	check(groups.size() == 3 and streamer._active_fauna.size() <= 3, "Recovered habitats did not supply all roles under the cap")
	var original: Dictionary = catalog["habitats"][0].duplicate(true)
	original.erase("spawn_position")
	check(JSON.stringify(original) == old_habitat and Catalog.object_id(state, original) == old_identity, "Live recovery changed old habitat/identity")
	for animal in streamer._active_fauna:
		if is_instance_valid(animal) and not animal.catalog_species.is_empty():
			check(Evidence.approved(animal.catalog_species), "Recovered animal bypassed anatomy gate")
	check(saves.save_now() and saves.load_now(), "Save/load recovered runtime: " + saves.last_error)
	await process_frame
	streamer._prune_fauna()
	streamer.domestic_fauna.update(streamer)
	check(streamer.domestic_fauna.catalog.get("habitat_recovery", {}).get("status") == "ready", "Reload discarded completed recovery")
	print(JSON.stringify({"test": "domestic_habitat_runtime", "failures": failures, "groups": groups.keys(), "habitats": catalog["habitats"].size(), "original_object_id": old_identity, "population_wait": population_wait}))
	current_scene.queue_free()
	for frame in range(12): await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
