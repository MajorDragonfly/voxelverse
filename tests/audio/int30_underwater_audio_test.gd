extends SceneTree
## Real director/mixer, radial diagnostic water port and fresh-process settings.
const Shutdown = preload("res://core/runtime_shutdown.gd")
var failures: Array[String] = []
var checks := 0
var audio: Node
var director: Node
var scene: Node3D
var camera: Camera3D
var player: Swimmer
var events: Array[StringName] = []
var measurements := {}
var capture: AudioEffectCapture
var recorder: AudioEffectCapture
var recording_frames := PackedVector2Array()
var capture_index := -1
var record_index := -1
var capture_dir := ""
var peak_transitions := 0
var base_nodes := 0
var baseline_loop_id := 0
var timeline: Array = []
var source_hashes := {}
var started := 0

class Swimmer extends CharacterBody3D:
	var is_dead := false
	var is_swimming := true

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	for path in ["res://audio/runtime/world_audio.gd", "res://audio/runtime/water_foley.gd", "res://tests/audio/int30_underwater_audio_test.gd"]:
		source_hashes[path] = FileAccess.get_sha256(path)
	root.get_node("SaveGameService").autosave_enabled = false
	audio = root.get_node("AudioManager")
	director = audio.director
	audio.creatures.automatic_tracking = false
	audio.music.automatic_tracking = false
	audio.music.stop_immediately()
	audio.scans.automatic_binding = false
	audio.orders.automatic_binding = false
	var args := OS.get_cmdline_user_args()
	if "--underwater-restart" in args:
		_expect(is_equal_approx(audio.get_volume(&"ambience"), 0.0) and is_equal_approx(audio.get_volume(&"master"), 0.57), "Fresh process lost saved mute/master")
		_expect(not director._underwater and audio._underwater_target == 0.0, "Fresh process inherited immersion")
		for voice in director._ambience.values(): _expect(not voice.playing, "Fresh process inherited a playing loop")
		_setup(true)
		await _wait(0.7)
		_expect(director._underwater and events.is_empty(), "Submerged restart fabricated a dive cue")
		_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"VV Ambience")), "Restart did not apply saved ambience mute")
		print("INT30_UNDERWATER_RESTART_PASSED" if failures.is_empty() else "INT30_UNDERWATER_RESTART_FAILED")
		await _finish()
		return
	if "--capture-dir" in args: capture_dir = args[args.find("--capture-dir") + 1]
	_foley_contract()
	audio.reset_settings()
	for channel in audio.CHANNELS: audio.set_volume(channel, 1.0)
	audio.set_preference(&"mute_in_background", false)
	_setup(false)
	await _wait(0.6)
	base_nodes = director.get_child_count()
	baseline_loop_id = director._ambience[&"underwater_loop"].get_instance_id()
	var master := AudioServer.get_bus_index(&"Master")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 1.0
	capture_index = AudioServer.get_bus_effect_count(master)
	AudioServer.add_bus_effect(master, capture)
	if not capture_dir.is_empty():
		recorder = AudioEffectCapture.new()
		recorder.buffer_length = 2.0
		record_index = AudioServer.get_bus_effect_count(master)
		AudioServer.add_bus_effect(master, recorder)
	started = Time.get_ticks_msec()
	_mark("dive")
	camera.position.x = 2.0
	director._sample_clock = 0.0
	await _wait(1.8)
	_expect(director._underwater and audio._underwater > 0.99, "Real water port did not immerse mixer/listener")
	var full := await _rms()
	measurements["submerged_rms"] = full
	_expect(full > 0.0001, "No production underwater output")
	# Keep the complete bed running over its eight-second wrap in the audition.
	_mark("steady bed, includes loop wrap")
	await _wait(7.0 if not capture_dir.is_empty() else 0.1)
	_expect(events.count(&"water_dive") == 1 and not events.has(&"underwater_bubbles"), "Idle repeated entry or movement bubbles")
	_mark("pause")
	var gain: float = director._gains[&"underwater_loop"]
	var bubble_clock: float = director._water_foley._bubble_clock
	paused = true
	var silent := await _rms()
	measurements["paused_rms"] = silent
	_expect(silent < 0.000001 and is_equal_approx(gain, director._gains[&"underwater_loop"]) and is_equal_approx(bubble_clock, director._water_foley._bubble_clock), "Pause leaked world audio or advanced foley")
	paused = false
	_mark("resume")
	await _wait(0.2)
	for channel in [&"ambience", &"master"]:
		_mark(String(channel) + " muted")
		audio.set_volume(channel, 0.0)
		silent = await _rms()
		measurements[String(channel) + "_muted_rms"] = silent
		_expect(silent < 0.000001, "Production underwater loop bypasses " + String(channel) + " mute")
		audio.set_volume(channel, 1.0)
		await _wait(0.2)
	_expect(director._ambience[&"underwater_loop"].get_instance_id() == baseline_loop_id, "Unmute allocated another loop")
	_mark("surface")
	camera.position.x = 3.2
	director._sample_clock = 0.0
	await _wait(0.55)
	_expect(not director._underwater and not director._ambience[&"underwater_loop"].playing, "Underwater noise lingered after surfacing")
	await _wait(0.5)
	# Crossing again at 0.67 s used to overlap the 0.75/0.82 s transition clips.
	_mark("repeated surface crossing, 0.67 s intervals")
	for index in 10:
		camera.position.x = 2.0 if index % 2 == 0 else 3.2
		director._sample_clock = 0.0
		await _wait(0.67)
	_expect(peak_transitions <= 1, "Repeated waterline crossings overlapped transition voices")
	_expect(events.count(&"water_dive") >= 3 and events.count(&"water_surface") >= 2, "Repeated crossing lost all transition feedback")
	# Motion-driven bubbles use the existing cadence and bounded shared pool.
	camera.position.x = 2.0
	director._sample_clock = 0.0
	await _wait(1.1)
	_mark("moving underwater")
	var before := events.count(&"underwater_bubbles")
	var move_until := Time.get_ticks_msec() + 5600
	while Time.get_ticks_msec() < move_until:
		await physics_frame
		_record_frames()
		player.position.z -= 0.025
		player.velocity.z = -1.5
	_expect(events.count(&"underwater_bubbles") > before and events.count(&"underwater_bubbles") - before <= 2, "Bubble cadence missing or unbounded")
	_expect(director.get_child_count() == base_nodes and audio._voices.size() == 16, "Water audio grew its voice pool")
	_expect(director.peak_sample_queries <= 4, "Foley added extra water queries")
	_mark("effects muted during real crossing; ambience muted to isolate cue")
	audio.set_volume(&"ambience", 0.0)
	audio.set_volume(&"effects", 0.0)
	camera.position.x = 3.2
	director._sample_clock = 0.0
	await _wait(1.2)
	before = events.count(&"water_dive")
	camera.position.x = 2.0
	director._sample_clock = 0.0
	await _wait(0.1)
	silent = await _rms()
	measurements["effects_muted_rms"] = silent
	_expect(events.count(&"water_dive") > before and silent < 0.000001, "Muted effects crossing was missing or leaked output")
	audio.set_volume(&"effects", 1.0)
	audio.set_volume(&"ambience", 1.0)
	_mark("scene removal and reset")
	scene.remove_child(player)
	await _wait(0.1)
	_expect(director._player == null and not director._underwater and not director._ambience[&"underwater_loop"].playing, "Detached scene retained underwater loop")
	scene.add_child(player)
	await _wait(0.6)
	_expect(director._underwater and director._ambience[&"underwater_loop"].playing, "Restored listener did not resume existing loop")
	paused = true
	director.sample_provider = Callable()
	_expect(change_scene_to_file("res://audio/fixtures/int30_underwater_exit.tscn") == OK, "Actual scene switch failed")
	await scene_changed
	await process_frame
	scene = current_scene
	_expect(not director._underwater and audio._underwater_target == 0.0, "Scene change retained immersion target")
	for voice in director._ambience.values(): _expect(not voice.playing, "Scene reset retained ambience")
	for voice in audio._voices: _expect(not voice.playing, "Scene reset retained foley")
	_expect(paused, "Scene change changed another pause owner")
	paused = false
	if recorder != null:
		_record_frames()
		var recording := AudioStreamWAV.new()
		recording.format = AudioStreamWAV.FORMAT_16_BITS
		recording.mix_rate = int(AudioServer.get_mix_rate())
		recording.stereo = true
		var data := PackedByteArray()
		data.resize(recording_frames.size() * 4)
		for i in recording_frames.size():
			data.encode_s16(i * 4, clampi(roundi(recording_frames[i].x * 32767.0), -32768, 32767))
			data.encode_s16(i * 4 + 2, clampi(roundi(recording_frames[i].y * 32767.0), -32768, 32767))
		recording.data = data
		_expect(recording.save_to_wav(capture_dir.path_join("mixer.wav")) == OK, "Mixer audition could not be saved")
		_expect(recorder.get_discarded_frames() == 0, "Mixer audition lost captured frames")
		AudioServer.remove_bus_effect(master, record_index)
	AudioServer.remove_bus_effect(master, capture_index)
	audio.set_volume(&"ambience", 0.0)
	audio.set_volume(&"master", 0.57)
	_expect(audio.save_settings() == OK, "Restart settings save failed")
	var output: Array = []
	print("INT30_UNDERWATER_RESTART_START")
	var command := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/audio/int30_underwater_audio_test.gd", "--", "--underwater-restart"])
	var code := OS.execute(OS.get_executable_path(), command, output, true)
	measurements["restart_exit"] = code
	measurements["restart_output"] = str(output)
	_expect(code == 0 and str(output).contains("INT30_UNDERWATER_RESTART_PASSED"), "Fresh underwater process failed: " + str(output))
	await _finish()

func _setup(submerged: bool) -> void:
	audio.sound_played.connect(func(event: StringName, _point: Vector3): events.append(event))
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	player = Swimmer.new()
	player.up_direction = Vector3.RIGHT
	player.set_meta("surface_mode", "cube_sphere_v1")
	scene.add_child(player)
	player.position.x = 2.7
	player.add_to_group(&"player")
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.position.x = 2.0 if submerged else 3.2
	camera.make_current()
	director.sample_provider = func(_point: Vector3): return {"water_present": true, "water_point": Vector3(3.0, 0, 0), "up": Vector3.RIGHT, "biome_name": "Lake"}
	director.reset_tracking()

func _foley_contract() -> void:
	var foley := preload("res://audio/runtime/water_foley.gd").new()
	_expect(foley.advance(0.02, false, 0.0, true).is_empty(), "Foley spawn emitted an entry")
	_expect(foley.advance(0.02, true, 0.0, true).get("event") == &"water_dive", "First crossing was lost")
	_expect(foley.advance(0.02, false, 0.0, true).is_empty(), "Opposite crossing played before previous cue finished")
	var cues: Array = []
	for i in 50:
		var cue: Dictionary = foley.advance(0.02, false, 0.0, true)
		if not cue.is_empty(): cues.append(cue.event)
	_expect(cues == [&"water_surface"], "Held crossing did not present latest state once")
	foley.reset()
	foley.advance(0.02, false, 0.0, true)
	foley.advance(0.02, true, 0.0, true)
	foley.advance(0.02, false, 0.0, true)
	foley.advance(0.02, true, 0.0, true)
	cues.clear()
	for i in 50:
		var cue: Dictionary = foley.advance(0.02, true, 0.0, true)
		if not cue.is_empty(): cues.append(cue.event)
	_expect(cues.is_empty(), "Cancelled surface crossing played a stale/duplicate cue")
	foley.advance(0.02, false, 0.0, true)
	foley.advance(0.02, true, 0.0, true)
	foley.advance(1.0, true, 0.0, true)
	_expect(foley.advance(0.02, true, 0.0, true).is_empty(), "Stall retained a delayed crossing")
	foley.reset()
	foley.advance(0.02, false, 0.0, true)
	foley.advance(0.02, true, 0.0, true)
	for i in 6:
		_expect(foley.advance(0.2, false, 0.0, true, false).is_empty(), "Simulation catch-up overrode playing mixer cue")
	_expect(foley.advance(0.02, false, 0.0, true, true).get("event") == &"water_surface", "Mixer finish lost held crossing")

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		_record_frames()
		var active := 0
		for voice in audio._voices:
			if voice.playing and (voice.stream == audio.get_sound_stream(&"water_dive") or voice.stream == audio.get_sound_stream(&"water_surface")): active += 1
		peak_transitions = maxi(peak_transitions, active)

func _record_frames() -> void:
	if recorder != null:
		recording_frames.append_array(recorder.get_buffer(recorder.get_frames_available()))

func _rms() -> float:
	await _wait(0.18)
	capture.clear_buffer()
	await _wait(0.14)
	var frames := capture.get_buffer(capture.get_frames_available())
	_expect(not frames.is_empty(), "Mixer capture returned no frames")
	var energy := 0.0
	for frame in frames: energy += frame.length_squared() * 0.5
	return sqrt(energy / maxf(float(frames.size()), 1.0))

func _mark(label: String) -> void:
	_record_frames()
	timeline.append({"wall_seconds": (Time.get_ticks_msec() - started) / 1000.0,
		"recorded_seconds": recording_frames.size() / AudioServer.get_mix_rate() if recorder != null else null, "action": label})
	print("INT30_UNDERWATER_STAGE ", label)

func _expect(value: bool, reason: String) -> void:
	checks += 1
	if not value: failures.append(reason)

func _finish() -> void:
	paused = false
	director.sample_provider = Callable()
	director.reset_tracking()
	if is_instance_valid(scene):
		current_scene = null
		scene.queue_free()
		await process_frame
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "measurements": measurements, "peak_transition_voices": peak_transitions, "timeline": timeline, "events": events, "engine": Engine.get_version_info().string, "source_hashes": source_hashes}
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("lifecycle.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("INT30_UNDERWATER ", JSON.stringify(report))
	for failure in failures: push_error(failure)
	await Shutdown.finish(self, 0 if failures.is_empty() else 1)
