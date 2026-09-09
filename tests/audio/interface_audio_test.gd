extends SceneTree
## Scanner public contract, group receipts, focus events and captured compressor DSP.

var audio: Node
var scene: Node3D
var failures: Array[String] = []
var scan_events: Array[StringName] = []
var order_events: Array[StringName] = []
var capture: AudioEffectCapture
var tone: AudioStreamPlayer
const CONFIG := "user://audio_interface_test.cfg"

class ScannerFixture extends Node:
	signal scan_completed(species_key: String)
	var target: Node3D
	var known := false
	var enabled := true
	var progress := 0.0
	func active() -> bool:
		return enabled and not get_tree().paused
	func ratio() -> float:
		return 1.0 if known else progress

class OrdersFixture extends Node:
	signal order_resolved(order: StringName, command_id: String, accepted: bool)

class SaveFixture extends Node:
	signal game_loaded(path: String)

class ScanProgressionFixture extends Node:
	signal species_discovered(key: String, display_name: String)
	signal behavior_node_purchased(node_id: String)
	func has_species_scan(_species_seed: int, _world_seed: int = 0) -> bool:
		return false


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, reason: String) -> void:
	if not value:
		failures.append(reason)
		push_error(reason)


func tick(seconds: float = 0.12) -> void:
	await create_timer(seconds).timeout


func run() -> void:
	audio = root.get_node("AudioManager")
	audio.director.automatic_tracking = false
	audio.creatures.automatic_tracking = false
	audio.set_music_context(&"silent")
	audio.scans.automatic_binding = false
	audio.orders.automatic_binding = false
	audio.reset_settings()
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var scanner := ScannerFixture.new()
	scene.add_child(scanner)
	var target := Node3D.new()
	scene.add_child(target)
	var second := Node3D.new()
	scene.add_child(second)
	scanner.target = target
	scanner.progress = 0.2
	audio.scans.feedback_played.connect(func(event: StringName): scan_events.append(event))
	check(audio.scans.bind_scanner(scanner) and audio.scans.bind_scanner(scanner), "Scanner binding is idempotent")
	check(not audio.scans.bind_scanner(scene), "Unrelated nodes cannot become scanners")
	await tick(0.25)
	check(scan_events.count(&"scan_acquire") == 1 and audio.scans._loop.playing, "Target acquisition starts one quiet scanner loop")
	var low_pitch: float = audio.scans._loop.pitch_scale
	scanner.progress = 0.85
	await tick(0.25)
	check(audio.scans._loop.pitch_scale > low_pitch + 0.15, "Pitch follows real scan progress")
	scanner.progress = 1.0
	await tick(0.1)
	check(scan_events.count(&"discovery") == 0, "Full progress alone does not announce a successful discovery")
	var service := ScanProgressionFixture.new()
	service.name = "ProgressionService"
	root.add_child(service)
	audio.creatures._bind_progression()
	service.species_discovered.emit("planet:species", "Test species")
	var generic_discovery := false
	for voice in audio._ui_voices:
		generic_discovery = generic_discovery or voice.playing
	check(not generic_discovery, "Scan-aware progression does not emit premature duplicate discovery")
	scanner.known = true
	scanner.scan_completed.emit("planet:species")
	scanner.scan_completed.emit("planet:species")
	await tick(0.15)
	check(scan_events.count(&"discovery") == 1 and not audio.scans._loop.playing, "One explicit completion stops loop and plays existing discovery cue once")
	var count := scan_events.size()
	scanner.target = second
	scanner.known = true
	await tick(0.25)
	check(scan_events.size() == count, "Known species remain quiet when targeted")
	scanner.known = false
	scanner.progress = 0.3
	await tick(0.22)
	scanner.target = null
	await tick(0.15)
	check(scan_events.count(&"scan_abort") == 1 and not audio.scans._loop.playing, "Losing a target produces one abort and no hanging loop")
	scanner.target = target
	await tick(0.22)
	paused = true
	await tick(0.1)
	check(not audio.scans._loop.playing and not audio.scans._cue.playing, "Paused scanner stops all its playback")
	paused = false
	scanner.enabled = false
	await tick()
	check(not audio.scans._loop.playing, "Inactive scanning mode stays silent")
	scanner.queue_free()
	await tick()
	check(audio.update_scan_audio(1234, 0.4), "Explicit scanner API remains usable")
	await tick(0.55)
	check(not audio.scans._loop.playing, "Missing progress updates expire the scanner loop")
	check(not audio.update_scan_audio(1234, NAN), "Malformed progress is rejected")
	check(not audio.complete_scan_audio("stale"), "Stale completion cannot play success")

	# One result per command, regardless of how many group members report it.
	var orders := OrdersFixture.new()
	scene.add_child(orders)
	orders.add_to_group(&"tribe_controller")
	audio.orders.automatic_binding = true
	audio.orders.feedback_played.connect(func(order: StringName, _id: String, _ok: bool): order_events.append(order))
	await tick(0.55)
	for index in 12:
		orders.order_resolved.emit(&"move", "group-order-1", true)
	check(order_events.size() == 1, "Twelve members sharing a command cause only one confirmation")
	await tick(0.25)
	check(not audio.play_group_order(&"move", "group-order-1"), "Receipt remains deduplicated beyond short debounce")
	check(audio.play_group_order(&"wood", "group-order-2"), "Existing tribe gather names map to gathering cue")
	await tick(0.25)
	check(audio.play_group_order(&"attack", "group-order-3", false), "Rejected command gets its own feedback")
	var rejected_voice := false
	for voice in audio._ui_voices:
		rejected_voice = rejected_voice or voice.stream == audio.get_sound_stream(&"order_reject")
	check(rejected_voice, "Rejection plays rejection sound rather than attack confirmation")
	check(not audio.play_group_order(&"move", "") and not audio.play_group_order(&"unknown", "x"), "Invalid commands and missing group receipts rejected")
	paused = true
	check(not audio.play_group_order(&"move", "paused"), "Paused world cannot acknowledge a new order")
	paused = false
	orders.queue_free()
	await tick(0.55)
	check(audio.orders._sources.is_empty(), "Freed order controllers are pruned")

	var saves := SaveFixture.new()
	saves.name = "SaveGameService"
	root.add_child(saves)
	await tick(0.55)
	saves.game_loaded.emit("another-campaign")
	check(audio.scans._completed.is_empty() and audio.orders._receipts.is_empty(), "Loading a campaign clears stale scan and order receipts")
	saves.queue_free()
	await tick(0.55)
	check(not audio._interface_sources.has("SaveGameService"), "Freed lifecycle services are safely removed")

	# Boolean settings, actual Window focus signal delivery and true zero volume.
	audio.set_preference(&"night_mode", true)
	audio.set_preference(&"mute_in_background", true)
	check(audio.save_settings(CONFIG) == OK, "Comfort preferences can be saved")
	audio.reset_settings()
	audio.load_settings(CONFIG)
	check(audio.get_preference(&"night_mode") and audio.get_preference(&"mute_in_background"), "Comfort settings survive reload")
	audio.set_volume(&"master", 0.63)
	root.focus_exited.emit()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"VV Master")), "Window losing focus mutes audio when opted in")
	audio.set_volume(&"master", 0.4)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"VV Master")), "Changing volume cannot bypass background mute")
	root.focus_entered.emit()
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"VV Master")) and is_equal_approx(audio.get_volume(&"master"), 0.4), "Refocus restores selected volume")
	audio.set_volume(&"master", 0.0)
	root.focus_exited.emit()
	root.focus_entered.emit()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"VV Master")), "Refocus never unmutes zero volume")
	audio.set_volume(&"master", 0.8)
	audio.set_preference(&"mute_in_background", false)
	root.focus_exited.emit()
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"VV Master")), "Background audio remains available when preference is off")
	check(not audio.update_scan_audio(456, 0.5), "Background focus still prevents scanning audio")
	root.focus_entered.emit()
	var malformed := ConfigFile.new()
	malformed.set_value("preferences", "night_mode", "false")
	malformed.set_value("preferences", "mute_in_background", 1)
	malformed.save(CONFIG)
	audio.load_settings(CONFIG)
	check(not audio.get_preference(&"night_mode") and not audio.get_preference(&"mute_in_background"), "Malformed or old preferences use strict safe defaults")
	audio.open_settings()
	await tick()
	check(audio._panel._preferences.size() == 2, "Both comfort settings appear in F7")
	audio.set_preference(&"night_mode", true)
	check(audio._panel._preferences[&"night_mode"].button_pressed, "External preference changes synchronize controls")
	audio.close_settings()

	# Capture the real audio graph to verify that compression reduces dynamics.
	audio.stop_ui()
	audio.stop_world()
	audio.scans.reset_playback()
	audio.set_volume(&"master", 1.0)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 1.0
	var master := AudioServer.get_bus_index(&"VV Master")
	var capture_index := AudioServer.get_bus_effect_count(master)
	AudioServer.add_bus_effect(master, capture)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(22050 * 2)
	for index in 22050:
		bytes.encode_s16(index * 2, roundi(sin(TAU * 440.0 * index / 22050.0) * 0.7 * 32767.0))
	stream.data = bytes
	tone = AudioStreamPlayer.new()
	tone.bus = &"VV Master"
	tone.stream = audio.director.loop_stream(stream)
	scene.add_child(tone)
	tone.play()
	var normal_quiet := await measured_rms(-30.0, false)
	var normal_loud := await measured_rms(0.0, false)
	var night_quiet := await measured_rms(-30.0, true)
	var night_loud := await measured_rms(0.0, true)
	check(normal_quiet > 0.0001 and night_quiet > 0.0001, "Capture contains real quiet audio")
	check(night_loud > night_quiet * 1.5, "Compression preserves the relative loudness order")
	check(night_loud < normal_loud * 0.65, "Night compressor lowers loud output")
	check(night_loud / maxf(night_quiet, 0.00001) < normal_loud / maxf(normal_quiet, 0.00001) * 0.65, "Night mode reduces measured loud/quiet contrast")
	print("NIGHT_MODE_CAPTURE ", JSON.stringify({"normal_quiet": normal_quiet, "normal_loud": normal_loud, "night_quiet": night_quiet, "night_loud": night_loud}))
	tone.stop()
	tone.stream = null
	AudioServer.remove_bus_effect(master, capture_index)
	audio.scans.reset_scene()
	audio.orders.reset_scene()
	audio.reset_settings()
	audio.save_settings()
	audio.stop_ui()
	service.queue_free()
	scene.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	await tick(0.3)
	print("INTERFACE_AUDIO_RESULT ", JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func measured_rms(gain_db: float, night: bool) -> float:
	audio.set_preference(&"night_mode", night)
	tone.volume_db = gain_db
	await tick(0.6)
	capture.clear_buffer()
	await tick(0.2)
	var frames := capture.get_buffer(capture.get_frames_available())
	var energy := 0.0
	for frame in frames:
		energy += frame.length_squared() * 0.5
	return sqrt(energy / maxf(float(frames.size()), 1.0))
