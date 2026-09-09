extends SceneTree
## Real Ogg playback must be released before player nodes leave the tree.
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	var music: Node = audio.music
	music.automatic_tracking = false
	for paused_case in [false, true]:
		var creature := Node3D.new()
		root.add_child(creature)
		var emitter: Node = audio.creatures.attach(creature)
		music.set_context(&"menu")
		await process_frame
		await process_frame
		await create_timer(0.05, true, false, true).timeout
		var voice: AudioStreamPlayer = music._voices[music._active]
		var playback: WeakRef = weakref(voice.get_stream_playback())
		paused = paused_case
		audio.prepare_shutdown()
		_expect(audio.creatures.emitters.is_empty() and not audio.creatures.is_processing(),
			"Shutdown left creature tracking active outside AudioManager.")
		_expect(emitter.is_queued_for_deletion() and not emitter.is_processing() and not emitter.emit_reaction(&"contact"),
			"A surviving creature could emit after audio shutdown began.")
		for item: AudioStreamPlayer in music._voices:
			_expect(item.is_inside_tree() and not item.playing and item.stream == null,
				"Music was not stopped and detached from its stream while still in the tree.")
		# The real mixer releases stopped playback on wall time, even headless.
		await create_timer(0.2, true, false, true).timeout
		await process_frame
		_expect(playback.get_ref() == null, "Ogg playback survived shutdown preparation.")
		paused = false
		creature.queue_free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("AUDIO_SHUTDOWN_PASSED: real Ogg playback released, running and paused.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
