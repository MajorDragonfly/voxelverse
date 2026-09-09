extends SceneTree
## Imported Ogg playback, real time fades, scene contracts and creature signals.

var audio: Node
var music: Node
var scene: Node3D
var failures: Array[String] = []

class Creature extends Node3D:
	signal audio_event(event: StringName)
	var species_seed := 42
	var ecological_role := "predator"


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, reason: String) -> void:
	if not condition:
		failures.append(reason)
		push_error(reason)


func settle(context: StringName) -> void:
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.04).timeout
		if music.current_context == context and not music._fading:
			return
	check(false, "Timed out waiting for music context: " + String(context))


func playing_count() -> int:
	var count := 0
	for voice in music._voices:
		if voice.playing:
			count += 1
	return count


func run() -> void:
	audio = root.get_node("AudioManager")
	music = audio.music
	audio.director.automatic_tracking = false
	audio.creatures.automatic_tracking = false
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	await create_timer(0.3).timeout
	check(playing_count() == 0, "Unknown scene stays silent")
	check(not audio.set_music_context(&"missing"), "Unknown context rejected")
	check(music._tracks.size() == 3, "All three exported scores are available")
	for context in music._tracks:
		var stream: AudioStreamOggVorbis = music._tracks[context]
		check(stream.loop and stream.loop_offset == 0.0, "Ogg loop enabled: " + String(context))
		check(absf(stream.get_length() - (60.0 if context == &"exploration" else 40.0)) < 0.01,
			"Exact musical duration: " + String(context))
	scene.scene_file_path = music.MENU_SCENE
	await settle(&"menu")
	check(playing_count() == 1, "Menu scene contract starts one streaming voice")
	var voice: AudioStreamPlayer = music._voices[music._active]
	voice.seek(voice.stream.get_length() - 0.12)
	await create_timer(0.5).timeout
	check(voice.playing and voice.get_playback_position() < 2.0, "Ogg continues across its loop boundary")

	# Real scene change: clear the menu cue, infer exploration from a live player.
	scene.scene_file_path = ""
	var player := Node3D.new()
	scene.add_child(player)
	player.add_to_group(&"player")
	scene_changed.emit()
	await create_timer(0.4).timeout
	check(playing_count() == 2, "Scene transition overlaps only two music voices")
	await settle(&"exploration")
	check(playing_count() == 1, "Outgoing stream released after crossfade")
	check(music._voices[music._active].get_playback_position() > 1.0, "Crossfade retains musical phase")

	# Repeated UI requests coalesce without resource growth, including mute midway.
	audio.set_music_context(&"menu")
	await create_timer(0.15).timeout
	for context in [&"danger", &"silent", &"menu", &"exploration", &"danger"]:
		audio.set_music_context(context)
		await create_timer(0.02).timeout
		check(playing_count() <= 2 and music.get_child_count() == 2, "Rapid context changes keep a bounded pool")
	await settle(&"danger")
	check(playing_count() == 1, "Last rapid request wins")
	audio.set_volume(&"music", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"VV Music")), "Music slider reaches true mute")
	audio.set_volume(&"music", 0.5)
	audio.set_underwater(true)
	await create_timer(0.5).timeout
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(&"VV Music")) == &"VV Master",
		"Music bypasses the underwater filter")

	audio.resume_music_automation()
	await settle(&"exploration")
	var creature := Creature.new()
	scene.add_child(creature)
	creature.position.z = -5
	var emitter: Node = audio.creatures.attach(creature)
	emitter.automatic_calls = false
	creature.audio_event.emit(&"hurt")
	await create_timer(0.12).timeout
	check(music._danger_remaining == 0.0, "Health loss alone does not guess combat")
	creature.audio_event.emit(&"warn")
	await settle(&"danger")
	check(music._danger_remaining > 7.0, "A real nearby warning starts danger music")
	var remaining: float = music._danger_remaining
	audio.open_settings()
	await create_timer(0.4).timeout
	check(paused and is_equal_approx(music._danger_remaining, remaining), "Pause freezes danger expiry")
	check(playing_count() == 1 and music._duck <= 0.51, "Music continues quietly while settings stay usable")
	audio.close_settings()
	await create_timer(0.35).timeout
	check(not paused and music._duck >= 0.99, "Closing settings restores music gain")
	creature.position.z = -30
	remaining = music._danger_remaining
	creature.audio_event.emit(&"attack")
	check(music._danger_remaining <= remaining, "Distant audible attacks do not extend local danger")
	audio.notify_music_danger(NAN)
	audio.notify_music_danger(-5)
	check(is_finite(music._danger_remaining), "Invalid danger duration is ignored")

	# A scene change clears both manual overrides and old danger leases.
	scene.set_meta(&"audio_music_context", &"exploration")
	scene_changed.emit()
	await settle(&"exploration")
	check(music._danger_remaining == 0.0, "Scene change clears stale danger")
	audio.notify_music_danger(2.0)
	await settle(&"danger")
	await settle(&"exploration")
	check(playing_count() == 1, "Danger expires back to exploration")
	scene.set_meta(&"audio_music_context", &"silent")
	await settle(&"silent")
	check(playing_count() == 0, "Silent context fades out and releases both streams")
	for stopped_voice in music._voices:
		check(stopped_voice.stream == null, "Inactive music does not retain playback resources")
	audio.creatures.clear()
	audio.stop_world()
	audio.stop_ui()
	music.stop_immediately()
	scene.queue_free()
	await create_timer(0.3).timeout
	if failures.is_empty():
		print("MUSIC RUNTIME TEST PASSED: loops, scene contexts, fades, danger, pause, mute and cleanup")
		await preload("res://core/runtime_shutdown.gd").finish(self, 0)
	else:
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
