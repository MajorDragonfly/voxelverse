extends SceneTree

const SpeciesFactory = preload(
	"res://creatures/wildlife/species_assembly_factory_v7.gd"
)
const RegionEcologyScript = preload(
	"res://world/simulation/region_ecology_simulation.gd"
)

const TEST_SAVE_PATH: String = "user://voxelverse_meta_runtime_test.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	var progression := root.get_node_or_null("ProgressionService")
	var save_service := root.get_node_or_null("SaveGameService")
	_expect(game_state != null, "GameState autoload missing.")
	_expect(progression != null, "ProgressionService autoload missing.")
	_expect(save_service != null, "SaveGameService autoload missing.")
	if game_state == null or progression == null or save_service == null:
		_finish()
		return

	save_service.set("autosave_enabled", false)
	_test_game_state_roundtrip(game_state)
	_test_progression(progression)
	await _test_region_persistence()
	await _test_clean_player_runtime()
	_test_save_service(save_service)
	_test_removed_legacy_resources()
	_cleanup()
	_finish()


func _test_game_state_roundtrip(game_state: Node) -> void:
	var original: Dictionary = game_state.call("export_state")
	game_state.call("import_state", {
		"phase": 0,
		"system_seed": 808_080,
		"world_seed": 909_090,
		"planet_index": 2,
	}, false)
	var changed: Dictionary = game_state.call("export_state")
	_expect(int(changed.get("system_seed", 0)) == 808_080, "GameState system seed import failed.")
	_expect(int(changed.get("world_seed", 0)) == 909_090, "GameState world seed import failed.")
	_expect(int(changed.get("planet_index", -1)) == 2, "GameState planet index import failed.")
	game_state.call("import_state", original, false)


func _test_progression(progression: Node) -> void:
	progression.call("reset_for_new_game")
	var starter_count: int = int(progression.call("get_unlocked_count"))
	_expect(starter_count >= 5, "Creature progression has too few starter parts.")
	var species: Dictionary = SpeciesFactory.create_species(
		771_337,
		Vector2i(1, -2),
		"predator"
	)
	var first: Dictionary = progression.call(
		"register_species_discovery",
		771_337,
		species,
		123_456
	)
	var repeated: Dictionary = progression.call(
		"register_species_discovery",
		771_337,
		species,
		123_456
	)
	_expect(bool(first.get("is_new", false)), "First species observation was not registered.")
	_expect(not bool(repeated.get("is_new", true)), "Species discovery was not deduplicated.")
	_expect(int(progression.call("get_discovered_species_count")) == 1, "Species count is incorrect.")
	_expect(int(progression.get("discovery_points")) >= 3, "Species discovery awarded no insight.")
	var exported: Dictionary = progression.call("export_state")
	progression.call("reset_for_new_game")
	progression.call("import_state", exported)
	_expect(int(progression.call("get_discovered_species_count")) == 1, "Progression import lost species discovery.")


func _test_region_persistence() -> void:
	var simulation := RegionEcologyScript.new()
	root.add_child(simulation)
	await process_frame
	var coordinates := Vector2i(2, 3)
	var initial: Dictionary = simulation.call("get_region_state", coordinates)
	_expect(not initial.is_empty(), "Region ecology did not create deterministic state.")
	var exported: Dictionary = simulation.call("export_state")
	simulation.call("register_plant_consumption", coordinates, 0.25)
	simulation.call("register_carcass_addition", coordinates, 0.20)
	var changed: Dictionary = simulation.call("get_region_state", coordinates)
	_expect(
		float(changed.get("carcass_biomass", 0.0)) >= float(initial.get("carcass_biomass", 0.0)),
		"Carcass biomass did not react to a wildlife death."
	)
	simulation.call("import_state", exported)
	var restored: Dictionary = simulation.call("get_region_state", coordinates)
	_expect(
		is_equal_approx(
			float(restored.get("plant_biomass", 0.0)),
			float(initial.get("plant_biomass", -1.0))
		),
		"Region ecology import did not restore plant biomass."
	)
	simulation.queue_free()
	await process_frame


func _test_clean_player_runtime() -> void:
	var scene := load("res://creatures/player/player.tscn") as PackedScene
	_expect(scene != null, "Player scene could not load.")
	if scene == null:
		return
	var player := scene.instantiate()
	root.add_child(player)
	for _frame in range(5):
		await process_frame
	_expect(player.has_method("export_runtime_state"), "Player has no runtime save API.")
	_expect(player.has_method("receive_damage"), "Player has no survival damage API.")
	_expect(player.has_method("consume_food"), "Player has no diet-driven feeding API.")
	_expect(not player.has_method("_toggle_creature_builder_mode"), "Legacy in-game creature builder is still active.")
	_expect(InputMap.has_action("bite_action"), "Creature bite action is not registered.")
	var runtime_visual := player.get_node_or_null("CreatureRuntimeVisual/BlueprintCreatureVisual")
	_expect(runtime_visual != null, "Runtime creature visual did not bind to locomotion path.")
	var animator := player.get_node_or_null("AdaptiveLocomotionAnimator")
	_expect(animator != null, "Adaptive locomotion animator is not active.")
	if animator != null:
		_expect(animator.has_method("get_gait_debug_state"), "Adaptive locomotion has no diagnostics API.")

	await _test_wildlife_combat(player)
	player.queue_free()
	await process_frame


func _test_wildlife_combat(player: Node) -> void:
	var wildlife_scene := load("res://creatures/wildlife/procedural_wildlife_v7.tscn") as PackedScene
	_expect(wildlife_scene != null, "Modular wildlife scene could not load.")
	if wildlife_scene == null:
		return
	var wildlife := wildlife_scene.instantiate()
	wildlife.call("configure", 991_771, 441_552, Vector2i.ZERO, "grazer")
	root.add_child(wildlife)
	for _frame in range(3):
		await process_frame
	_expect(wildlife.has_method("receive_creature_attack"), "Wildlife has no creature combat API.")
	var maximum_health: float = float(wildlife.get("maximum_health"))
	wildlife.call("receive_creature_attack", maximum_health + 10.0, player)
	_expect(bool(wildlife.get("is_dead")), "Lethal creature attack did not create a carcass.")
	var carcass_before: float = float(wildlife.get("carcass_food_remaining"))
	_expect(carcass_before > 0.0, "Dead wildlife has no edible carcass resource.")
	player.set("diet_meat", 2.0)
	player.set("current_hunger", 40.0)
	wildlife.call("interact", player)
	var carcass_after: float = float(wildlife.get("carcass_food_remaining"))
	_expect(carcass_after < carcass_before, "Meat-compatible player could not consume carcass food.")
	if is_instance_valid(wildlife):
		wildlife.queue_free()
	await process_frame


func _test_save_service(save_service: Node) -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)
	var saved: bool = bool(save_service.call("save_now", TEST_SAVE_PATH))
	_expect(saved, "Meta save service could not write an atomic save.")
	_expect(FileAccess.file_exists(TEST_SAVE_PATH), "Meta save file was not created.")
	if not FileAccess.file_exists(TEST_SAVE_PATH):
		return
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if file != null:
		file.close()
	_expect(parsed is Dictionary, "Meta save file is not valid JSON.")
	if parsed is Dictionary:
		_expect(int(parsed.get("schema", 0)) >= 2, "Meta save schema is missing.")
		_expect(parsed.get("progression", {}) is Dictionary, "Progression is missing from save.")
		_expect(parsed.get("regions_by_world", {}) is Dictionary, "Regional state is missing from save.")


func _test_removed_legacy_resources() -> void:
	for path in [
		"res://creatures/editor/creature_evolution_generator.gd",
		"res://creatures/animals/grazer/grazer.gd",
		"res://creatures/player/player.gd",
		"res://creatures/player/player_v6.gd",
	]:
		_expect(not ResourceLoader.exists(path), "Legacy runtime still exists: %s" % path)


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Meta Runtime test passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
