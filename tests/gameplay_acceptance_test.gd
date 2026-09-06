extends SceneTree

const SpawnSelector = preload(
	"res://world/generation/adventure_spawn_selector.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_player_creature_interaction()
	await _test_planet_cycle_runtime()
	_test_scenic_spawn_selector()
	_finish()


func _test_player_creature_interaction() -> void:
	var player_scene := load("res://creatures/player/player.tscn") as PackedScene
	var wildlife_scene := load(
		"res://creatures/wildlife/procedural_wildlife_v7.tscn"
	) as PackedScene
	_expect(player_scene != null, "Player scene could not load.")
	_expect(wildlife_scene != null, "Wildlife scene could not load.")
	if player_scene == null or wildlife_scene == null:
		return

	var player := player_scene.instantiate()
	root.add_child(player)
	player.global_position = Vector3(0.0, 2.5, 0.0)
	for _frame in range(5):
		await process_frame

	_expect(player.has_method("perform_bite_on_target"), "Player has no real bite targeting API.")
	_expect(player.has_method("get_nearby_wildlife"), "Player has no inspection proximity API.")
	var ray := player.get_node_or_null(
		"CameraPivot/SpringArm3D/Camera3D/InteractionRay"
	) as RayCast3D
	_expect(ray != null, "Player interaction ray is missing.")
	if ray != null:
		_expect(
			absf(ray.target_position.z) >= 10.0,
			"Third-person interaction ray still ends before the player."
		)

	var wildlife := wildlife_scene.instantiate()
	wildlife.call("configure", 2_771_337, 911_227, Vector2i.ZERO, "forager")
	root.add_child(wildlife)
	wildlife.global_position = player.global_position + Vector3(0.0, 0.0, -2.2)
	for _frame in range(4):
		await process_frame

	_expect(wildlife.has_method("get_inspection_data"), "Wildlife exposes no inspection data.")
	_expect(wildlife.has_method("get_target_health_data"), "Wildlife exposes no target health data.")
	var health_before: float = float(wildlife.get("current_health"))
	var bite_result: bool = bool(player.call("perform_bite_on_target", wildlife))
	var health_after: float = float(wildlife.get("current_health"))
	_expect(bite_result, "Player bite API rejected a creature in range.")
	_expect(health_after < health_before, "Player bite did not reduce creature health.")

	var nearby_value: Variant = player.call("get_nearby_wildlife", 6)
	_expect(nearby_value is Array, "Inspection nearby query did not return an array.")
	if nearby_value is Array:
		_expect(wildlife in nearby_value, "Nearby creature is missing from inspection query.")

	var inspection_event := InputEventKey.new()
	inspection_event.pressed = true
	inspection_event.keycode = KEY_E
	inspection_event.physical_keycode = KEY_E
	player.call("_unhandled_input", inspection_event)
	_expect(
		bool(player.call("is_inspection_mode_enabled")),
		"E did not enable creature inspection mode."
	)

	if is_instance_valid(wildlife):
		wildlife.queue_free()
	if is_instance_valid(player):
		player.queue_free()
	await process_frame


func _test_planet_cycle_runtime() -> void:
	var game_state := root.get_node_or_null("GameState")
	_expect(game_state != null, "GameState is missing during planet-cycle test.")
	if game_state == null:
		return
	var original_state: Dictionary = game_state.call("export_state")
	var runtime_script := load(
		"res://world/space/star_system_runtime_v7.gd"
	) as Script
	_expect(runtime_script != null, "Star-system runtime could not load.")
	if runtime_script == null:
		return
	var runtime := runtime_script.new()
	runtime.set("reload_scene_on_planet_change", false)
	root.add_child(runtime)
	await process_frame
	_expect(
		str(runtime.call("get_debug_cycle_key_name")) == "P",
		"Planet cycle is still bound to Godot's F8 stop shortcut."
	)
	var system: Dictionary = runtime.call("get_system")
	var planets: Array = system.get("planets", [])
	if planets.size() > 1:
		var before: Dictionary = runtime.call("get_active_planet")
		runtime.call("cycle_to_next_planet")
		await process_frame
		var after: Dictionary = runtime.call("get_active_planet")
		_expect(
			int(after.get("index", -1)) != int(before.get("index", -1)),
			"Planet cycle did not activate the next planet."
		)
	if is_instance_valid(runtime):
		runtime.queue_free()
	game_state.call("import_state", original_state, true)
	await process_frame


func _test_scenic_spawn_selector() -> void:
	var generator := root.get_node_or_null("WorldGenerator")
	_expect(generator != null, "WorldGenerator missing during spawn test.")
	if generator == null:
		return
	var spawn: Vector3 = SpawnSelector.find_spawn(generator, Vector2.ZERO, 90.0)
	var sea_level: float = float(generator.call("get_sea_level"))
	_expect(spawn.y > sea_level + 0.5, "Scenic spawn selector returned an underwater spawn.")
	if generator.has_method("get_terrain_slope"):
		var slope: float = float(generator.call(
			"get_terrain_slope",
			spawn.x,
			spawn.z,
			0.75
		))
		_expect(slope <= 0.55, "Scenic spawn selector returned an excessively steep spawn.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Gameplay acceptance test passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
