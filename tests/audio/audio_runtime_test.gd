extends SceneTree
## Real physics + audio graph test. Run with an isolated XDG_DATA_HOME.

var failures: Array[String] = []
var events: Array[StringName] = []
var audio: Node
var player: CharacterBody3D
var wet := false
var camera: Camera3D
const TEST_CONFIG := "user://audio_test_only.cfg"


class TestPlayer extends CharacterBody3D:
	var is_dead := false
	var walking := false
	var jump_next := false
	func _physics_process(delta: float) -> void:
		velocity.x = 4.0 if walking else 0.0
		velocity.y -= 20.0 * delta
		if jump_next:
			velocity.y = 6.0
			jump_next = false
		move_and_slide()


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func run() -> void:
	audio = root.get_node("AudioManager")
	audio.sound_played.connect(func(event: StringName, _position: Vector3): events.append(event))
	# Verify routing, true mute, persistence and invalid values.
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(&"VV Effects")) == &"VV World", "Effects must route through underwater processing")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(&"VV UI")) == &"VV Master", "UI must bypass underwater processing")
	audio.set_volume(&"effects", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"VV Effects")), "Zero volume must mute")
	audio.set_volume(&"effects", 0.37)
	check(audio.save_settings(TEST_CONFIG) == OK, "Settings save")
	audio.set_volume(&"effects", 0.91)
	audio.load_settings(TEST_CONFIG)
	check(is_equal_approx(audio.get_volume(&"effects"), 0.37), "Settings survive reload")
	audio.set_volume(&"effects", NAN)
	check(is_equal_approx(audio.get_volume(&"effects"), 0.37), "NaN rejected")
	var config := ConfigFile.new()
	config.set_value("volume", "effects", "broken")
	config.save(TEST_CONFIG)
	audio.load_settings(TEST_CONFIG)
	check(is_equal_approx(audio.get_volume(&"effects"), 0.8), "Malformed setting restores default")
	audio.reset_volumes()
	# The fixture is intentionally independent of concurrent player/world changes.
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var floor_body := StaticBody3D.new()
	floor_body.set_meta(&"audio_surface", "wood")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 0.2, 400)
	shape.shape = box
	floor_body.position.y = -0.1
	floor_body.add_child(shape)
	scene.add_child(floor_body)
	player = TestPlayer.new()
	player.name = "AudioTestPlayer"
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.6
	capsule.radius = 0.3
	body_shape.shape = capsule
	body_shape.position.y = 0.8
	player.add_child(body_shape)
	scene.add_child(player)
	player.add_to_group(&"player")
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 3, 6)
	camera.current = true
	audio.director.sample_provider = sample
	await frames(40)
	check(events.is_empty(), "Spawn/idle must not make footsteps or landing sounds")
	player.walking = true
	await frames(80)
	check(events.count(&"step_wood") >= 2, "Actual movement must trigger collider material footsteps")
	player.walking = false
	await frames(3)
	var stationary_count := events.size()
	await frames(25)
	check(events.size() == stationary_count, "Stationary player stays quiet")
	player.jump_next = true
	await frames(65)
	check(events.count(&"jump") == 1, "Jump emits once")
	check(events.count(&"land") == 1, "Landing emits once")
	var before_teleport := events.size()
	player.position.x += 50.0
	await frames(35)
	check(events.size() == before_teleport, "Teleport must not emit movement sounds")
	wet = true
	player.walking = true
	await frames(80)
	check(events.has(&"splash") and events.has(&"swim"), "Water entry and movement")
	camera.position.y = 0.2
	await frames(65)
	check(audio._underwater > 0.9, "Listener below water enables filter")
	camera.position.y = 3.0
	await frames(65)
	check(audio._underwater < 0.1, "Listener above water restores filter")
	# Pool is bounded and world playback is disallowed while paused.
	player.walking = false
	paused = true
	check(not audio.play_world(&"land", Vector3.ZERO), "World playback blocked in pause")
	check(audio.play_ui(), "Menu sound works in pause")
	audio.open_settings()
	await process_frame
	check(paused, "Settings retain existing pause")
	check(is_instance_valid(audio._panel), "Settings panel opens")
	audio.close_settings()
	check(paused, "Closing settings must preserve another menu's pause")
	paused = false
	await frames(40)
	for i in 25:
		audio.play_world(&"splash", Vector3(float(i), 0, 0), 0.0, 1.0, i + 1)
	var playing := 0
	for voice in audio._voices:
		if voice.playing:
			playing += 1
	check(playing <= 16, "Bounded voice pool")
	audio.stop_world()
	for voice in audio._voices:
		check(not voice.playing, "World voice cleanup")
	# Check loop resources and consecutive footstep variation.
	for key in [&"wind_loop", &"foliage_loop", &"water_loop", &"underwater_loop"]:
		var loop: AudioStreamWAV = audio.director.loop_stream(audio.get_sound_stream(key))
		check(loop.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop.loop_end > 0, "Loop configured: " + String(key))
	var previous: AudioStream
	for i in 15:
		var next: AudioStream = audio._choose(&"step_grass")
		check(next != previous, "Footstep variant must not immediately repeat")
		previous = next
	wet = false
	# A sample refresh plus the 1.5 s fade can exceed 110 physics frames.
	# Wait for the observable state, with a bounded three-second deadline.
	for index in 180:
		await frames(1)
		if audio.director._shore_target == 0.0 and not audio.director._shore.playing:
			break
	check(not audio.director._shore.playing, "Dry world has no water loop")
	player.queue_free()
	await frames(40)
	for voice in audio.director._ambience.values():
		check(not voice.playing, "No player: ambience stops")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CONFIG))
	print("AUDIO_RUNTIME_RESULT ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "events": events}))
	quit(0 if failures.is_empty() else 1)


func sample(_position: Vector3) -> Dictionary:
	return {"water_present": wet, "water_height": 1.2 if wet else -5.0,
		"ground_height": 0.0, "biome_name": "Forest"}
