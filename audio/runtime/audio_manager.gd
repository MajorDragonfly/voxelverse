extends Node
## Shared sound API. World voices pause; menu previews remain available.

signal settings_changed(channel: StringName, volume: float)
signal preference_changed(preference: StringName, enabled: bool)
signal sound_played(event: StringName, position: Vector3)
signal creature_sound_played(source_id: int, event: StringName, pitch: float, family: String)

const CONFIG_PATH := "user://audio_settings.cfg"
const CHANNELS := {&"master": &"VV Master", &"music": &"VV Music",
	&"ambience": &"VV Ambience", &"effects": &"VV Effects", &"ui": &"VV UI"}
const DEFAULTS := {&"master": 0.8, &"music": 0.5, &"ambience": 0.65,
	&"effects": 0.8, &"ui": 0.6}
const PREFERENCE_DEFAULTS := {&"night_mode": false, &"mute_in_background": false}
const LIBRARY_PATH := "res://audio/runtime/sound_library.gd"
const DIRECTOR = preload("res://audio/runtime/world_audio.gd")
const PANEL = preload("res://audio/ui/audio_settings.gd")
const MAX_WORLD_VOICES := 16
const CREATURES = preload("res://audio/runtime/creature_audio_registry.gd")

var fallback_shortcut_enabled := true
var volumes: Dictionary = DEFAULTS.duplicate()
var director: Node
var creatures: Node
var music: Node
var occlusion: Node
var actions: Node
var scans: Node
var orders: Node
var preferences: Dictionary = PREFERENCE_DEFAULTS.duplicate()
var _night_compressor: AudioEffectCompressor
var _night_effect_index := -1
var _window_focused := true
var _interface_sources: Dictionary = {}
var _interface_bind_clock := 0.0
var _streams: Dictionary = {}
var _last_variant: Dictionary = {}
var _last_time: Dictionary = {}
var _voices: Array[AudioStreamPlayer3D] = []
var _ui_voices: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()
var _filter: AudioEffectLowPassFilter
var _underwater := 0.0
var _underwater_target := 0.0
var _save_pending := false
var _save_delay := 0.0
var _panel: CanvasLayer
var _previous_pause := false
var _previous_mouse := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_build_buses()
	_window_focused = DisplayServer.get_name() == "headless" or get_window().has_focus()
	get_window().focus_entered.connect(_focus_entered)
	get_window().focus_exited.connect(_focus_exited)
	load_settings()
	# Load after asset import, avoiding autoload parse failures on a fresh clone.
	var library: Script = load(LIBRARY_PATH)
	for event in library.SOUNDS:
		_streams[event] = library.SOUNDS[event]
	var creature_library: Script = load("res://audio/runtime/creature_sound_library.gd")
	for event in creature_library.SOUNDS:
		_streams[event] = creature_library.SOUNDS[event]
	var action_library: Script = load("res://audio/runtime/action_sound_library.gd")
	for event in action_library.SOUNDS:
		_streams[event] = action_library.SOUNDS[event]
	var interface_library: Script = load("res://audio/runtime/interface_sound_library.gd")
	for event in interface_library.SOUNDS:
		_streams[event] = interface_library.SOUNDS[event]
	for index in MAX_WORLD_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "WorldVoice%d" % index
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		voice.bus = CHANNELS[&"effects"]
		voice.unit_size = 5.0
		voice.max_distance = 60.0
		voice.max_db = 0.0
		add_child(voice)
		_voices.append(voice)
	for index in 4:
		var voice := AudioStreamPlayer.new()
		voice.bus = CHANNELS[&"ui"]
		add_child(voice)
		_ui_voices.append(voice)
	occlusion = preload("res://audio/runtime/sound_occlusion.gd").new()
	occlusion.name = "SoundOcclusion"
	add_child(occlusion)
	for voice in _voices:
		occlusion.register_voice(voice, CHANNELS[&"effects"])
	director = DIRECTOR.new()
	director.name = "WorldAudio"
	director.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(director)
	creatures = CREATURES.new()
	creatures.name = "CreatureAudio"
	creatures.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(creatures)
	music = preload("res://audio/runtime/music_director.gd").new()
	music.name = "MusicDirector"
	add_child(music)
	actions = preload("res://audio/runtime/action_audio.gd").new()
	actions.name = "ActionAudio"
	add_child(actions)
	scans = preload("res://audio/runtime/scanner_audio.gd").new()
	scans.name = "ScannerAudio"
	add_child(scans)
	orders = preload("res://audio/runtime/order_audio.gd").new()
	orders.name = "OrderAudio"
	add_child(orders)
	_bind_interface_lifecycle()
	get_tree().scene_changed.connect(_scene_changed)


func _build_buses() -> void:
	# Keep the project's existing Master and any third-party buses untouched.
	for bus in [&"VV Master", &"VV World", &"VV Music", &"VV Ambience", &"VV Effects", &"VV UI"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		var destination: StringName = &"VV Master"
		if bus == &"VV Master":
			destination = &"Master"
		elif bus == &"VV Ambience" or bus == &"VV Effects":
			destination = &"VV World"
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus), destination)
	var world_index := AudioServer.get_bus_index(&"VV World")
	_filter = AudioEffectLowPassFilter.new()
	_filter.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(world_index, _filter)
	var master_index := AudioServer.get_bus_index(&"VV Master")
	_night_compressor = AudioEffectCompressor.new()
	_night_compressor.threshold = -16.0
	_night_compressor.ratio = 2.0
	_night_compressor.attack_us = 2000.0
	_night_compressor.release_ms = 150.0
	_night_compressor.gain = 0.0
	_night_compressor.mix = 0.6
	_night_effect_index = AudioServer.get_bus_effect_count(master_index)
	AudioServer.add_bus_effect(master_index, _night_compressor)
	AudioServer.set_bus_effect_enabled(master_index, _night_effect_index, false)
	var limiter := AudioEffectLimiter.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"VV Master"), limiter)


func _process(delta: float) -> void:
	_interface_bind_clock -= delta
	if _interface_bind_clock <= 0.0:
		_interface_bind_clock = 0.5
		_bind_interface_lifecycle()
	_underwater = move_toward(_underwater, _underwater_target, delta * 2.5)
	_filter.cutoff_hz = exp(lerpf(log(20000.0), log(750.0), _underwater))
	if _save_pending:
		_save_delay -= delta
		if _save_delay <= 0.0:
			save_settings()


func _bind_interface_lifecycle() -> void:
	for item in [["GameState", &"world_seed_changed"], ["SaveGameService", &"game_loaded"]]:
		var service := get_node_or_null("/root/" + String(item[0]))
		var previous: Variant = _interface_sources.get(item[0])
		if not is_instance_valid(previous):
			previous = null
			_interface_sources.erase(item[0])
		if service == previous:
			continue
		if is_instance_valid(previous) and previous.is_connected(item[1], _reset_interface_feedback):
			previous.disconnect(item[1], _reset_interface_feedback)
		_interface_sources.erase(item[0])
		if service != null and service.has_signal(item[1]):
			service.connect(item[1], _reset_interface_feedback)
			_interface_sources[item[0]] = service


func _reset_interface_feedback(_value: Variant) -> void:
	scans.reset_scene()
	orders.reset_scene()


func set_volume(channel: StringName, value: float) -> void:
	if not CHANNELS.has(channel) or not is_finite(value):
		return
	volumes[channel] = clampf(value, 0.0, 1.0)
	_apply_volume(channel)
	_save_pending = true
	_save_delay = 0.35
	settings_changed.emit(channel, float(volumes[channel]))


func get_volume(channel: StringName) -> float:
	return float(volumes.get(channel, 0.0))


func _apply_volume(channel: StringName) -> void:
	var index := AudioServer.get_bus_index(CHANNELS[channel])
	var value := get_volume(channel)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(index, value <= 0.0 or (channel == &"master" and get_preference(&"mute_in_background") and not _window_focused))


func set_preference(preference: StringName, enabled: bool) -> bool:
	if not PREFERENCE_DEFAULTS.has(preference):
		return false
	preferences[preference] = enabled
	_apply_preferences()
	_save_pending = true
	_save_delay = 0.35
	preference_changed.emit(preference, enabled)
	return true


func get_preference(preference: StringName) -> bool:
	return bool(preferences.get(preference, false))


func _apply_preferences() -> void:
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(&"VV Master"), _night_effect_index, get_preference(&"night_mode"))
	_apply_volume(&"master")


func is_window_focused() -> bool:
	return _window_focused


func _focus_entered() -> void:
	_window_focused = true
	_apply_volume(&"master")


func _focus_exited() -> void:
	_window_focused = false
	_apply_volume(&"master")
	if is_instance_valid(scans):
		scans.reset_playback()


func load_settings(path: String = CONFIG_PATH) -> void:
	var config := ConfigFile.new()
	config.load(path)
	for channel in CHANNELS:
		var value: Variant = config.get_value("volume", String(channel), DEFAULTS[channel])
		if not (value is float or value is int) or not is_finite(float(value)):
			value = DEFAULTS[channel]
		volumes[channel] = clampf(float(value), 0.0, 1.0)
		_apply_volume(channel)
		settings_changed.emit(channel, float(volumes[channel]))
	for preference in PREFERENCE_DEFAULTS:
		var value: Variant = config.get_value("preferences", String(preference), PREFERENCE_DEFAULTS[preference])
		preferences[preference] = value if value is bool else PREFERENCE_DEFAULTS[preference]
		preference_changed.emit(preference, bool(preferences[preference]))
	_apply_preferences()


func save_settings(path: String = CONFIG_PATH) -> Error:
	var config := ConfigFile.new()
	for channel in CHANNELS:
		config.set_value("volume", String(channel), volumes[channel])
	for preference in PREFERENCE_DEFAULTS:
		config.set_value("preferences", String(preference), preferences[preference])
	var result := config.save(path)
	_save_pending = false
	if result != OK:
		push_warning("Audio settings could not be saved: %s" % error_string(result))
	return result


func reset_volumes() -> void:
	for channel in CHANNELS:
		set_volume(channel, float(DEFAULTS[channel]))


func reset_settings() -> void:
	reset_volumes()
	for preference in PREFERENCE_DEFAULTS:
		set_preference(preference, bool(PREFERENCE_DEFAULTS[preference]))


func set_underwater(enabled: bool) -> void:
	_underwater_target = 1.0 if enabled else 0.0


func register_sound(event: StringName, variants: Array) -> void:
	var valid: Array[AudioStream] = []
	for stream in variants:
		if stream is AudioStream:
			valid.append(stream)
	if not valid.is_empty():
		_streams[event] = valid
		_last_variant.erase(event)


func get_sound_stream(event: StringName) -> AudioStream:
	var variants: Array = _streams.get(event, [])
	return null if variants.is_empty() else variants[0] as AudioStream


func _choose(event: StringName) -> AudioStream:
	var variants: Array = _streams.get(event, [])
	if variants.is_empty():
		return null
	var index := _rng.randi_range(0, variants.size() - 1)
	if variants.size() > 1 and index == int(_last_variant.get(event, -1)):
		index = (index + _rng.randi_range(1, variants.size() - 1)) % variants.size()
	_last_variant[event] = index
	return variants[index] as AudioStream


func play_world(event: StringName, position: Vector3, gain_db: float = 0.0,
		pitch: float = 1.0, source_id: int = 0, priority: int = 1) -> bool:
	if get_tree().paused or not position.is_finite():
		return false
	var key := "%s:%d" % [event, source_id]
	var now := Time.get_ticks_msec()
	if now - int(_last_time.get(key, -1000)) < 80:
		return false
	var stream := _choose(event)
	if stream == null:
		return false
	var selected: AudioStreamPlayer3D
	var lowest_priority := clampi(priority, 0, 2)
	for voice in _voices:
		if not voice.playing:
			selected = voice
			break
		var voice_priority := int(voice.get_meta(&"audio_priority", 1))
		if voice_priority < lowest_priority:
			selected = voice
			lowest_priority = voice_priority
	if selected == null:
		return false
	selected.stop()
	occlusion.reset_voice(selected)
	selected.stream = stream
	selected.global_position = position
	selected.volume_db = clampf(gain_db, -40.0, 3.0) if is_finite(gain_db) else 0.0
	selected.pitch_scale = clampf(pitch, 0.5, 2.0) if is_finite(pitch) else 1.0
	selected.set_meta(&"audio_priority", clampi(priority, 0, 2))
	selected.set_meta(&"audio_source_id", source_id)
	selected.play()
	if _last_time.size() > 512:
		_last_time.clear()
	_last_time[key] = now
	sound_played.emit(event, position)
	return true


func play_creature(event: StringName, source: Node3D) -> bool:
	return creatures.emit_for(source, event)


func play_action(action: StringName, source: Node3D = null, receipt_id: String = "") -> bool:
	return actions.play(action, source, receipt_id)


func update_scan_audio(target_id: int, progress: float, already_known: bool = false) -> bool:
	return scans.update_scan(target_id, progress, already_known)


func complete_scan_audio(species_key: String) -> bool:
	return scans.complete_scan(species_key)


func cancel_scan_audio() -> void:
	scans.cancel_scan()


func play_group_order(order: StringName, command_id: String, accepted: bool = true) -> bool:
	return orders.play_result(order, command_id, accepted)


func set_music_context(context: StringName) -> bool:
	return music.set_context(context)


func resume_music_automation() -> void:
	music.resume_automation()


func notify_music_danger(seconds: float = 10.0) -> void:
	music.notify_danger(seconds)


func stop_source(source_id: int) -> void:
	for voice in _voices:
		if int(voice.get_meta(&"audio_source_id", -1)) == source_id:
			voice.stop()
			voice.stream = null
			occlusion.reset_voice(voice)


func stop_ui() -> void:
	for voice in _ui_voices:
		voice.stop()
		voice.stream = null


func play_ui(event: StringName = &"ui_confirm") -> bool:
	var stream := _choose(event)
	if stream == null:
		return false
	for voice in _ui_voices:
		if not voice.playing:
			voice.stream = stream
			voice.play()
			return true
	return false


func stop_world() -> void:
	for voice in _voices:
		voice.stop()
		voice.stream = null
	_last_time.clear()
	if is_instance_valid(occlusion):
		occlusion.reset()
	set_underwater(false)


func _scene_changed() -> void:
	stop_world()
	director.reset_tracking()
	creatures.clear()
	music.reset_scene()
	actions.reset()
	scans.reset_scene()
	orders.reset_scene()
	if is_instance_valid(_panel):
		close_settings()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if fallback_shortcut_enabled and event.keycode == KEY_F7:
			if is_instance_valid(_panel):
				close_settings()
			else:
				open_settings()
			get_viewport().set_input_as_handled()
		elif is_instance_valid(_panel) and event.keycode == KEY_ESCAPE:
			close_settings()
			get_viewport().set_input_as_handled()
		elif is_instance_valid(_panel) and event.keycode >= KEY_F1 and event.keycode <= KEY_F12:
			# Do not open another debug/settings menu behind this modal panel.
			get_viewport().set_input_as_handled()


func open_settings() -> void:
	if is_instance_valid(_panel):
		return
	_previous_pause = get_tree().paused
	_previous_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel = PANEL.new()
	_panel.layer = 110
	add_child(_panel)
	play_ui()


func close_settings() -> void:
	if not is_instance_valid(_panel):
		return
	_panel.queue_free()
	_panel = null
	get_tree().paused = _previous_pause
	Input.mouse_mode = _previous_mouse
	save_settings()
	play_ui(&"ui_back")


func _exit_tree() -> void:
	if is_instance_valid(scans):
		scans.reset_playback()
	if is_instance_valid(music):
		music.stop_immediately()
	stop_world()
	stop_ui()
	if _save_pending:
		save_settings()
