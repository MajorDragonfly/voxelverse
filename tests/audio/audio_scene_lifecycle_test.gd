extends SceneTree
## Exercise the removal-to-free interval of a real cached audio listener.
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	var director: Node = audio.director
	director.set_physics_process(false)
	director.sample_provider = func(_point: Vector3): return {}
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var player := CharacterBody3D.new()
	scene.add_child(player)
	player.add_to_group(&"player")
	director._bind_clock = 0.0
	director._physics_process(1.0 / 60.0)
	_expect(director._player == player, "Audio did not bind the active player.")
	# change_scene_to_file removes the outgoing scene immediately; cached Node
	# references can remain valid until it is freed at the end of the frame.
	scene.remove_child(player)
	director._sample_clock = 0.0
	director._physics_process(1.0 / 60.0)
	_expect(director._player == null and director._sample.is_empty(), "Detached player remained an audio listener.")
	scene.add_child(player)
	director._bind_clock = 0.0
	director._physics_process(1.0 / 60.0)
	_expect(director._player == player, "Audio did not rebind a restored player.")
	player.queue_free()
	director._sample_clock = 0.0
	director._physics_process(1.0 / 60.0)
	_expect(director._player == null, "Queued player remained an audio listener.")
	await process_frame
	scene.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("AUDIO_SCENE_LIFECYCLE_PASSED: detached, restored and queued player.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
