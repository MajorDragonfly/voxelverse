extends SceneTree
## Real physics obstacles, action signals and timed music cadence.

var audio: Node
var scene: Node3D
var failures: Array[String] = []
var action_events: Array[StringName] = []

class Actor extends CharacterBody3D:
	signal audio_action(action: StringName)
	var current_health := 40.0
	var maximum_health := 40.0
	var current_hunger := 20.0
	var current_thirst := 30.0
	var is_dead := false
	var species_seed := 42
	var ecological_role := "grazer"


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, reason: String) -> void:
	if not value:
		failures.append(reason)
		push_error(reason)


func frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame
		check(audio.occlusion.queries_last_frame <= audio.occlusion.MAX_RAYS_PER_FRAME, "Global occlusion ray budget")


func settle(context: StringName) -> void:
	var deadline := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.03).timeout
		if audio.music.current_context == context and not audio.music._fading:
			return
	check(false, "Music failed to settle: " + String(context))


func wait_for_rest() -> void:
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if audio.music.is_resting():
			return
	check(false, "Automatic exploration never entered a quiet interval")


func actor(position: Vector3) -> Actor:
	var value := Actor.new()
	value.position = position
	var collision := CollisionShape3D.new()
	collision.shape = SphereShape3D.new()
	value.add_child(collision)
	scene.add_child(value)
	return value


func find_voice(source_id: int) -> AudioStreamPlayer3D:
	for voice in audio._voices:
		if voice.playing and voice.get_meta(&"audio_source_id", -1) == source_id:
			return voice
	return null


func run() -> void:
	audio = root.get_node("AudioManager")
	audio.director.automatic_tracking = false
	audio.creatures.automatic_tracking = false
	audio.set_music_context(&"silent")
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var listener := actor(Vector3.ZERO)
	listener.add_to_group(&"player")
	var camera := Camera3D.new()
	listener.add_child(camera)
	camera.current = true
	var source := actor(Vector3(0, 0, -6))
	var right_source := actor(Vector3(7, 0, -6))
	var wall := StaticBody3D.new()
	wall.position = Vector3(20, 0, -3)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.5)
	collision.shape = box
	wall.add_child(collision)
	scene.add_child(wall)
	var test_loop: AudioStreamWAV = audio.director.loop_stream(audio.get_sound_stream(&"creature_chirp_warn"))
	audio.register_sound(&"expansion_test_loop", [test_loop])
	await frames(3)
	check(audio.play_world(&"expansion_test_loop", source.position, -6.0, 1.0, source.get_instance_id()), "Start real spatial loop")
	check(audio.play_world(&"expansion_test_loop", right_source.position, -6.0, 1.0, right_source.get_instance_id()), "Start unobstructed control voice")
	var voice := find_voice(source.get_instance_id())
	var right_voice := find_voice(right_source.get_instance_id())
	await frames(18)
	check(audio.occlusion.get_amount(voice) < 0.01, "Source and listener colliders do not self-occlude")
	wall.position.x = 0.0
	await frames(24)
	check(audio.occlusion.get_amount(voice) > 0.95, "Real obstacle muffles only the blocked source")
	check(audio.occlusion.get_amount(right_voice) < 0.01, "Other voices remain clear")
	var slot: Dictionary = audio.occlusion._slots[voice.get_meta(&"occlusion_slot")]
	check(slot.filter.cutoff_hz < 1700.0, "Blocked source gets its own low-pass filter")
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(voice.bus)) < -8.5, "Blocked source is quieter")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(voice.bus)) == &"VV Effects", "Occlusion retains effects settings route")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(audio.director._shore.bus)) == &"VV Ambience", "Shoreline retains ambience route")
	paused = true
	var amount: float = audio.occlusion.get_amount(voice)
	wall.position.x = 20.0
	await create_timer(0.2).timeout
	check(is_equal_approx(audio.occlusion.get_amount(voice), amount), "Occlusion freezes with world pause")
	paused = false
	await frames(30)
	check(audio.occlusion.get_amount(voice) < 0.01, "Removing a wall restores clear sound smoothly")
	wall.position.x = 0.0
	wall.set_meta(&"audio_transparent", true)
	await frames(20)
	check(audio.occlusion.get_amount(voice) < 0.01, "Transparent geometry opt-out")
	wall.remove_meta(&"audio_transparent")
	await frames(20)
	check(audio.occlusion.get_amount(voice) > 0.95, "Restoring obstacle restores occlusion")
	audio.occlusion.enabled = false
	await frames(25)
	check(audio.occlusion.get_amount(voice) < 0.01, "Disabling occlusion restores original mix")
	audio.occlusion.enabled = true
	await frames(20)
	audio.stop_source(source.get_instance_id())
	check(audio.occlusion.get_amount(voice) == 0.0, "Recycled voice does not inherit muffling")
	audio.stop_world()
	var bus_count := AudioServer.bus_count
	for index in audio.MAX_WORLD_VOICES:
		audio.play_world(&"expansion_test_loop", Vector3(index * 0.1, 0, -6), -25.0, 1.0, 1000 + index, 2)
	await frames(36)
	check(audio.occlusion._slots.size() == 17 and AudioServer.bus_count == bus_count, "Full pool never grows audio buses")

	# Rejected playback must not consume action receipts.
	audio.actions.action_played.connect(func(action: StringName, _id: int): action_events.append(action))
	check(not audio.play_action(&"gather", source, "retry"), "Full higher-priority pool rejects action sound")
	audio.stop_world()
	check(audio.play_action(&"gather", source, "retry"), "Rejected receipt remains retryable")
	check(not audio.play_action(&"gather", source, "retry"), "Immediate duplicate prevented")
	await create_timer(0.3).timeout
	check(not audio.play_action(&"gather", source, "retry"), "Receipt remains deduplicated after cooldown")
	check(audio.play_action(&"gather", source, "next"), "New successful action has its own receipt")
	for event in [&"eat", &"drink", &"gather", &"evolve"]:
		check(audio._streams[StringName("action_" + String(event))].size() == 3, "Three imported action variants")
	var emitter: Node = audio.creatures.attach(source)
	emitter.automatic_calls = false
	source.audio_action.emit(&"eat")
	check(action_events.count(&"eat") == 1, "Optional action signal reaches sound playback")
	check(not audio.play_action(&"eat", source), "Signal plus direct call deduplicated")
	source.current_hunger += 10.0
	source.current_thirst += 10.0
	await frames(10)
	check(action_events.count(&"eat") == 1 and action_events.count(&"drink") == 0, "Stat restoration never guesses eating or drinking")
	check(audio.play_action(&"drink", source), "Explicit drinking works")
	check(source.current_hunger == 30.0 and source.current_thirst == 40.0 and source.current_health == 40.0, "Audio never changes gameplay statistics")
	paused = true
	check(not audio.play_action(&"eat", source), "World actions cannot play while paused")
	check(audio.play_action(&"evolve", null, "design-1"), "Evolution confirmation works in paused editor")
	paused = false
	check(not audio.play_action(&"eat") and not audio.play_action(&"unknown", source), "Invalid action/source ignored")
	source.is_dead = true
	check(not audio.play_action(&"gather", source), "Dead actors cannot perform action sounds")
	source.is_dead = false
	source.set_meta(&"audio_disabled", true)
	check(not audio.play_action(&"drink", source), "Audio-disabled actors remain silent")
	source.remove_meta(&"audio_disabled")
	audio.creatures.clear()
	audio.stop_world()
	audio.stop_ui()

	# Real-time cadence, including danger arriving during the fade into silence.
	scene.set_meta(&"audio_music_context", &"exploration")
	audio.set_music_context(&"exploration")
	await settle(&"exploration")
	check(not audio.music.configure_rest_cycle(NAN, 1.0, 2.0), "Reject malformed cadence")
	check(not audio.music.configure_rest_cycle(1.0, 3.0, 2.0), "Reject reversed rest interval")
	check(audio.music.configure_rest_cycle(4.0, 1.2, 1.2), "Configure short test cadence")
	audio.resume_music_automation()
	await wait_for_rest()
	await settle(&"silent")
	check(audio.music.is_resting(), "Automatic cadence creates an actual quiet interval")
	var quiet_remaining: float = audio.music._rest_remaining
	paused = true
	await create_timer(0.3).timeout
	check(is_equal_approx(audio.music._rest_remaining, quiet_remaining), "Pause freezes quiet countdown")
	paused = false
	await settle(&"exploration")
	check(not audio.music.is_resting(), "Exploration returns automatically after quiet")
	await wait_for_rest()
	check(audio.music._fading, "Second rest begins by fading the old cue")
	audio.notify_music_danger(4.0)
	await create_timer(0.1).timeout
	check(audio.music.current_context == &"danger" and not audio.music.is_resting(), "Danger interrupts a fade into silence immediately")
	await settle(&"danger")
	check(audio.music.get_child_count() == 2, "Urgent rest interruption still uses only two voices")
	audio.set_music_context(&"exploration")
	await settle(&"exploration")
	await create_timer(4.3).timeout
	check(not audio.music.is_resting(), "Explicit audition keeps playing without automatic rests")
	scene.set_meta(&"audio_music_context", &"silent")
	scene_changed.emit()
	check(audio.music._rest_remaining == 0.0 and audio.actions._receipts.is_empty(), "Scene change clears rest and action history")
	await settle(&"silent")
	audio.music.configure_rest_cycle()
	audio.music.stop_immediately()
	audio.stop_world()
	audio.stop_ui()
	scene.queue_free()
	await create_timer(0.3).timeout
	print("AUDIO_EXPANSION_RESULT ", JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
