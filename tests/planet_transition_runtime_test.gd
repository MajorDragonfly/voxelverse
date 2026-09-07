extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").set("autosave_enabled", false)
	_expect(change_scene_to_file("res://main/main.tscn") == OK, "Main scene could not start.")
	await _wait_for_world()
	if current_scene == null:
		_finish()
		return
	var generator: Node = root.get_node("WorldGenerator")
	var first_profile: Dictionary = generator.call("get_planet_profile")
	var first_height: float = float(generator.call("get_terrain_height", 180.0, -120.0))
	var runtime: Node = current_scene.get_node("StarSystemRuntimeV7")
	var first_index: int = int(runtime.call("get_active_planet").get("index", 0))
	var scene_id: int = current_scene.get_instance_id()
	runtime.call("cycle_to_next_planet")
	await _wait_for_world(scene_id)
	_expect(current_scene != null and current_scene.get_instance_id() != scene_id, "Planet transition did not reload the real main scene.")
	var second_profile: Dictionary = generator.call("get_planet_profile")
	_expect(first_profile != second_profile, "Planet transition retained the previous profile.")
	_expect(int(second_profile.get("visual_generation_version", 0)) == 9, "Reloaded world is not running V9.")
	if current_scene != null:
		runtime = current_scene.get_node("StarSystemRuntimeV7")
		scene_id = current_scene.get_instance_id()
		runtime.call("activate_planet", first_index)
		await _wait_for_world(scene_id)
	_expect(generator.call("get_planet_profile") == first_profile, "Returning to a planet changed its profile.")
	_expect(is_equal_approx(float(generator.call("get_terrain_height", 180.0, -120.0)), first_height), "Returning to a planet changed its terrain.")
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame
	_finish()


func _wait_for_world(previous_scene_id: int = 0) -> void:
	for frame in range(1800):
		await process_frame
		if current_scene == null or current_scene.get_instance_id() == previous_scene_id:
			continue
		var manager: Node = current_scene.get_node_or_null("WorldManager")
		if manager == null or not bool(manager.get("world_initialized")):
			continue
		var player: Node3D = current_scene.get_node("Player")
		_expect(player.global_position.is_finite(), "Player position became non-finite on transition.")
		var chunks: Dictionary = manager.get("loaded_chunks")
		_expect(not chunks.is_empty(), "Reloaded world has no terrain.")
		for chunk: Node in chunks.values():
			var mesh: MeshInstance3D = chunk.get_node("TerrainMesh")
			var collision: CollisionShape3D = chunk.get_node("TerrainCollision")
			if mesh.mesh != null and collision.shape != null:
				for idle in range(8):
					await process_frame
				return
	_expect(false, "Timed out waiting for playable terrain after scene reload.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("Planet scene transition A-B-A passed.")
	quit(0 if _failures.is_empty() else 1)
