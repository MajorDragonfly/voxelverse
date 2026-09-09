extends Node
## Two streaming voices, phase-aligned fades and a refreshable danger lease.
## Contexts may be supplied explicitly or inferred from public scene contracts.

signal context_changed(context: StringName, title: String)

const CONTEXTS := [&"menu", &"exploration", &"danger", &"silent"]
const MENU_SCENE := "res://ui/frontend/main_menu.tscn"
const FADE_SECONDS := 3.0
const DANGER_FADE_SECONDS := 1.2
const TRACK_GAIN_DB := -7.0
const DANGER_RADIUS := 24.0

var automatic_tracking := true
var current_context: StringName = &"silent"
var requested_context: StringName = &"silent"
var _override: StringName = &""
var _danger_remaining := 0.0
var _tracks: Dictionary = {}
var _titles: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _gains := [0.0, 0.0]
var _from := [0.0, 0.0]
var _to := [0.0, 0.0]
var _active := -1
var _fade_elapsed := 0.0
var _fade_duration := 0.0
var _fading := false
var _duck := 1.0
var _scan_clock := 0.0
var _base_context: StringName = &"silent"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Delayed loading also works during the first import of a fresh checkout.
	var library: Script = load("res://audio/runtime/music_library.gd")
	_titles = library.TITLES
	for context in library.TRACKS:
		var stream: AudioStreamOggVorbis = library.TRACKS[context].duplicate()
		stream.loop = true
		stream.loop_offset = 0.0
		_tracks[context] = stream
	for index in 2:
		var voice := AudioStreamPlayer.new()
		voice.name = "MusicVoice%d" % index
		voice.bus = &"VV Music"
		voice.volume_db = -80.0
		add_child(voice)
		_voices.append(voice)
	get_parent().creature_sound_played.connect(_creature_event)


func set_context(context: StringName) -> bool:
	if context not in CONTEXTS:
		return false
	_override = context
	_update_request()
	return true


func resume_automation() -> void:
	_override = &""
	_scan_clock = 0.0


func notify_danger(seconds: float = 10.0) -> void:
	if get_tree().paused or not is_finite(seconds) or seconds <= 0.0:
		return
	_danger_remaining = maxf(_danger_remaining, clampf(seconds, 0.1, 30.0))
	_update_request()


func reset_scene() -> void:
	_override = &""
	_danger_remaining = 0.0
	_base_context = &"silent"
	_scan_clock = 0.0


func get_title() -> String:
	return String(_titles.get(current_context, ""))


func _process(delta: float) -> void:
	if not get_tree().paused:
		_danger_remaining = maxf(0.0, _danger_remaining - delta)
	_scan_clock -= delta
	if automatic_tracking and _scan_clock <= 0.0:
		_scan_clock = 0.25
		_base_context = _scene_context()
	_update_request()
	# Finish the current fade before accepting the latest requested transition.
	# Rapid UI/event changes cannot allocate a third voice or cut a playing one.
	if not _fading and requested_context != current_context:
		_begin_transition(requested_context)
	if _fading:
		_fade_elapsed += delta
		var progress := clampf(_fade_elapsed / _fade_duration, 0.0, 1.0)
		var weight := smoothstep(0.0, 1.0, progress)
		for index in 2:
			_gains[index] = lerpf(_from[index], _to[index], weight)
		if progress >= 1.0:
			_fading = false
			for index in 2:
				if _to[index] == 0.0:
					_release(index)
	var duck_target := 0.5 if get_tree().paused and current_context != &"menu" else 1.0
	_duck = move_toward(_duck, duck_target, delta * 2.0)
	for index in 2:
		_voices[index].volume_db = TRACK_GAIN_DB + linear_to_db(maxf(float(_gains[index]) * _duck, 0.0001))


func _update_request() -> void:
	if _override != &"":
		requested_context = _override
	elif _base_context == &"exploration" and _danger_remaining > 0.0:
		requested_context = &"danger"
	else:
		requested_context = _base_context


func _scene_context() -> StringName:
	var scene := get_tree().current_scene
	if is_instance_valid(scene):
		# Metadata is an optional public integration point, no menu dependency.
		var explicit := StringName(str(scene.get_meta(&"audio_music_context", "")))
		if explicit in CONTEXTS:
			return explicit
		if scene.scene_file_path == MENU_SCENE:
			return &"menu"
	var player := get_tree().get_first_node_in_group(&"player")
	if is_instance_valid(player) and player is Node3D and not player.is_queued_for_deletion():
		return &"exploration"
	return &"silent"


func _begin_transition(context: StringName) -> void:
	_from = _gains.duplicate()
	_to = [0.0, 0.0]
	if context != &"silent":
		var next := 0 if _active != 0 else 1
		var phase := 0.0
		if _active >= 0 and _voices[_active].playing:
			phase = _voices[_active].get_playback_position()
		var voice := _voices[next]
		voice.stream = _tracks[context]
		voice.volume_db = -80.0
		# All scores share tempo, metre and an eight-bar harmony cycle.
		voice.play(fposmod(phase, voice.stream.get_length()))
		_to[next] = 1.0
		_active = next
	else:
		_active = -1
	_fade_elapsed = 0.0
	_fade_duration = DANGER_FADE_SECONDS if context == &"danger" else FADE_SECONDS
	_fading = true
	current_context = context
	context_changed.emit(context, get_title())


func _creature_event(source_id: int, event: StringName, _pitch: float, _family: String) -> void:
	if event != &"attack" and event != &"warn":
		return
	var source := instance_from_id(source_id) as Node3D
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_instance_valid(source) or not is_instance_valid(player):
		return
	if source.global_position.distance_squared_to(player.global_position) <= DANGER_RADIUS * DANGER_RADIUS:
		notify_danger()


func _release(index: int) -> void:
	_voices[index].stop()
	_voices[index].stream = null


func stop_immediately() -> void:
	for index in _voices.size():
		_release(index)
	_gains = [0.0, 0.0]
	_fading = false
	_active = -1
	current_context = &"silent"
	requested_context = &"silent"
	_override = &"silent"
	_danger_remaining = 0.0


func _exit_tree() -> void:
	stop_immediately()
