extends Node

const PROFILE = preload("res://audio/runtime/creature_voice_profile.gd")
const REACTIONS := [&"contact", &"warn", &"attack", &"hurt", &"death", &"friend"]
var source: Node3D
var registry: Node
var audio: Node
var profile: Dictionary
var automatic_calls := true
var _rng := RandomNumberGenerator.new()
var _health := NAN
var _maximum := NAN
var _dead_reported := false
var _clock := 0.0
var _call_clock := 0.0
var _reaction_clock := 0.0
var _last_reaction: StringName
var _source_id := 0


func _ready() -> void:
	_source_id = source.get_instance_id()
	_rng.seed = _source_id
	profile = PROFILE.from_creature(source)
	_call_clock = _rng.randf_range(2.5, 7.0)
	_snapshot()
	_dead_reported = source.get("is_dead") == true
	_connect_if("health_changed", _health_changed)
	_connect_if("creature_defeated", _creature_defeated)
	_connect_if("died", _died)
	_connect_if("respawned", _respawned)
	_connect_if("creature_attacked", _creature_attacked)
	_connect_if("audio_event", _audio_event)


func _connect_if(signal_name: StringName, callback: Callable) -> void:
	if source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _process(delta: float) -> void:
	_reaction_clock = maxf(0.0, _reaction_clock - delta)
	_clock -= delta
	_call_clock -= delta
	if _clock > 0.0:
		return
	_clock = 0.1
	if not is_instance_valid(source) or source.is_queued_for_deletion():
		return
	var dead_value: Variant = source.get("is_dead")
	var dead: bool = _dead_reported if dead_value == null else dead_value == true
	if dead and not _dead_reported:
		emit_reaction(&"death")
	elif not dead and _dead_reported:
		_respawned()
	else:
		_observe_health(_number("current_health"), _number("maximum_health"))
	if automatic_calls and not source.is_in_group(&"player") and not dead and _call_clock <= 0.0:
		_call_clock = _rng.randf_range(9.0, 19.0)
		if registry.automatic_tracking:
			emit_reaction(&"contact")


func _number(property: StringName) -> float:
	var value: Variant = source.get(property)
	return float(value) if value is float or value is int else NAN


func _snapshot() -> void:
	_health = _number("current_health")
	_maximum = _number("maximum_health")


func _observe_health(current: float, maximum: float) -> void:
	# Rebuilding a creature can change max health: do not treat that as a hit.
	var damage := is_finite(current) and is_finite(_health) and current < _health - 0.001
	var same_max := (is_nan(maximum) and is_nan(_maximum)) or is_equal_approx(maximum, _maximum)
	_health = current
	_maximum = maximum
	if source.get("is_dead") == true:
		if not _dead_reported:
			emit_reaction(&"death")
	elif damage and same_max:
		emit_reaction(&"hurt")


func emit_reaction(event: StringName) -> bool:
	if not event in REACTIONS or not is_instance_valid(source) or source.is_queued_for_deletion():
		return false
	if get_tree().paused or source.get_meta(&"audio_disabled", false):
		return false
	if event == &"death":
		if _dead_reported:
			return false
		_dead_reported = true
	elif _dead_reported or source.get("is_dead") == true:
		return false
	if _reaction_clock > 0.0 and (event == _last_reaction or event == &"contact"):
		return false
	_snapshot()
	if not registry.audible(source):
		return false
	if event == &"contact" and not registry.allow_contact():
		return false
	profile = PROFILE.from_creature(source)
	var key := StringName("creature_%s_%s" % [profile["family"], event])
	var pitch := float(profile["pitch"]) * _rng.randf_range(0.97, 1.03)
	var priority := 0 if event == &"contact" else 2
	if event != &"contact":
		audio.stop_source(_source_id)
	var gain := -11.0 if event == &"contact" else -5.0
	if not audio.play_world(key, source.global_position, gain, pitch, _source_id, priority):
		return false
	_reaction_clock = 1.5 if event in [&"warn", &"friend"] else 0.3
	_last_reaction = event
	_call_clock = _rng.randf_range(9.0, 19.0)
	audio.creature_sound_played.emit(_source_id, event, pitch, String(profile["family"]))
	return true


func _health_changed(current: float, maximum: float) -> void:
	_observe_health(current, maximum)


func _creature_defeated(_creature: Node) -> void:
	emit_reaction(&"death")


func _died() -> void:
	emit_reaction(&"death")


func _respawned() -> void:
	_dead_reported = false
	_snapshot()
	profile = PROFILE.from_creature(source)
	_call_clock = _rng.randf_range(3.0, 8.0)


func _creature_attacked(target: Node, damage: float) -> void:
	if is_instance_valid(target) and is_finite(damage) and damage > 0.0:
		emit_reaction(&"attack")


func _audio_event(event: StringName) -> void:
	emit_reaction(event)


func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop_source(_source_id)
