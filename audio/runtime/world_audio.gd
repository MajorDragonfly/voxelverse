extends Node
## Read-only adapter for the existing player and generator. No movement changes.
## Future local-planet/hydrology code can supply sample_provider(position).

var sample_provider: Callable
var automatic_tracking := true
var _player: CharacterBody3D
var _last_position := Vector3.ZERO
var _last_grounded := false
var _last_vertical_speed := 0.0
var _last_wet := false
var _distance := 0.0
var _sample_clock := 0.0
var _bind_clock := 0.0
var _settle := 0.0
var _sample: Dictionary = {}
var _ambience: Dictionary = {}
var _gains := {&"wind_loop": 0.0, &"foliage_loop": 0.0, &"underwater_loop": 0.0}
var _targets := {&"wind_loop": 0.0, &"foliage_loop": 0.0, &"underwater_loop": 0.0}
var _shore: AudioStreamPlayer3D
var _shore_gain := 0.0
var _shore_target := 0.0
var _underwater := false
var _audio: Node


func _ready() -> void:
	_audio = get_parent()
	process_physics_priority = 100
	for event in _targets:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"VV Ambience"
		voice.stream = loop_stream(_audio.get_sound_stream(event))
		voice.volume_db = -80.0
		add_child(voice)
		_ambience[event] = voice
	_shore = AudioStreamPlayer3D.new()
	_shore.bus = &"VV Ambience"
	_shore.stream = loop_stream(_audio.get_sound_stream(&"water_loop"))
	_shore.unit_size = 9.0
	_shore.max_distance = 45.0
	_shore.max_db = 0.0
	_shore.volume_db = -80.0
	add_child(_shore)
	_audio.occlusion.register_voice(_shore, &"VV Ambience")
	var generator := get_node_or_null("/root/WorldGenerator")
	if generator != null and generator.has_signal("world_profile_changed"):
		generator.connect("world_profile_changed", _world_changed)


static func loop_stream(source: AudioStreamWAV) -> AudioStreamWAV:
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream


func _world_changed(_seed: int) -> void:
	_audio.stop_world()
	reset_tracking()


func reset_tracking() -> void:
	_player = null
	_distance = 0.0
	_sample_clock = 0.0
	_bind_clock = 0.0
	_sample.clear()
	_underwater = false
	_audio.set_underwater(false)
	for event in _ambience:
		_ambience[event].stop()
		_gains[event] = 0.0
		_targets[event] = 0.0
	_shore.stop()
	_shore_gain = 0.0
	_shore_target = 0.0


func _physics_process(delta: float) -> void:
	if not automatic_tracking:
		return
	# Scene changes detach the old player before freeing it. A valid cached
	# reference cannot be used for transforms or physics in that interval.
	if is_instance_valid(_player) and (not _player.is_inside_tree() or _player.is_queued_for_deletion()):
		reset_tracking()
		return
	if not is_instance_valid(_player):
		_bind_clock -= delta
		if _bind_clock > 0.0:
			return
		_bind_clock = 0.25
		var candidate := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
		# The current automatic sampler interprets XYZ as planar coordinates.
		# Radial campaigns must supply their hydrology/audio adapter (M1h);
		# never sample an unrelated plane at the floating origin.
		if candidate != null and candidate.get_meta("surface_mode", "legacy_plane_v9") != "legacy_plane_v9" and not sample_provider.is_valid():
			reset_tracking()
			_bind_clock = 0.5
			return
		if candidate == null or candidate.is_queued_for_deletion():
			reset_tracking()
			_bind_clock = 0.25
			return
		_player = candidate
		_reset_motion()
		_update_environment()
	var position := _player.global_position
	var up := _player.up_direction.normalized()
	var motion := position - _last_position
	var horizontal := motion.slide(up).length()
	var vertical_speed := _player.velocity.dot(up)
	var grounded := _player.is_on_floor()
	# Teleport/respawn and long stalls must not synthesize a burst of steps.
	if motion.length() > maxf(5.0, _player.velocity.length() * delta * 3.0) or delta > 0.2:
		_audio.stop_world()
		_reset_motion()
		_update_environment()
		return
	_sample_clock -= delta
	if _sample_clock <= 0.0:
		_sample_clock = 0.35
		_update_environment()
	_settle = maxf(0.0, _settle - delta)
	var wet := bool(_sample.get("water_present", false)) and position.y < float(_sample.get("water_height", -INF)) - 0.04
	var depth := float(_sample.get("water_height", position.y)) - position.y if wet else 0.0
	var alive: bool = _player.get("is_dead") != true
	if alive and _settle <= 0.0:
		if wet != _last_wet:
			_audio.play_world(&"splash", position, -5.0, 1.0, _player.get_instance_id())
		elif _last_grounded and not grounded and vertical_speed > 1.0:
			_audio.play_world(&"jump", position, -6.0, 1.0, _player.get_instance_id())
		elif not _last_grounded and grounded and _last_vertical_speed < -1.5:
			_audio.play_world(&"land", position, clampf(absf(_last_vertical_speed) - 12.0, -9.0, 0.0), 1.0, _player.get_instance_id())
			_distance = 0.0
		if horizontal > 0.002 and (grounded or wet):
			_distance += horizontal
			var stride := 1.65 if depth > 0.8 else 1.35
			if _distance >= stride:
				_distance = fmod(_distance, stride)
				var event: StringName = &"swim" if depth > 0.8 else StringName("step_" + _surface(wet))
				_audio.play_world(event, position, -3.0, randf_range(0.94, 1.06), _player.get_instance_id())
		else:
			_distance = 0.0
	_last_position = position
	_last_grounded = grounded
	_last_vertical_speed = vertical_speed
	_last_wet = wet


func _reset_motion() -> void:
	_last_position = _player.global_position
	_last_grounded = _player.is_on_floor()
	_last_vertical_speed = 0.0
	_last_wet = false
	_distance = 0.0
	_settle = 0.4


func _surface(wet: bool) -> String:
	if wet:
		return "water"
	var up := _player.up_direction.normalized()
	var query := PhysicsRayQueryParameters3D.create(
		_player.global_position + up * 0.25, _player.global_position - up * 0.6,
		_player.collision_mask, [_player.get_rid()])
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider")
	if collider != null and collider.has_meta(&"audio_surface"):
		var material := String(collider.get_meta(&"audio_surface"))
		if material in ["grass", "sand", "stone", "snow", "wood"]:
			return material
	return surface_for_biome(String(_sample.get("biome_name", "Grassland")))


static func surface_for_biome(biome: String) -> String:
	var lower := biome.to_lower()
	if "snow" in lower or "ice" in lower:
		return "snow"
	if "rock" in lower or "alpine" in lower:
		return "stone"
	if "coast" in lower or "desert" in lower or "steppe" in lower:
		return "sand"
	return "grass"


func sample_at(position: Vector3) -> Dictionary:
	if sample_provider.is_valid():
		return sample_provider.call(position)
	var generator := get_node_or_null("/root/WorldGenerator")
	if generator == null or not generator.has_method("get_terrain_height"):
		return {}
	var height: float = generator.get_terrain_height(position.x, position.z)
	var water: float = (float(generator.get_water_level(position.x, position.z)) if generator.has_method("get_water_level") else float(generator.get_sea_level())) + 0.03
	var biome: int = generator.get_biome(position.x, position.z, height)
	return {"water_present": height < water - 0.04, "water_height": water,
		"ground_height": height, "biome_name": generator.get_biome_name(biome)}


func _update_environment() -> void:
	_sample = sample_at(_player.global_position)
	var camera := get_viewport().get_camera_3d()
	var listener_position := _player.global_position + _player.up_direction * 1.5
	if camera != null:
		listener_position = camera.global_position
	var listener_sample := sample_at(listener_position)
	var water_height := float(listener_sample.get("water_height", -INF))
	var threshold := 0.06 if _underwater else -0.06
	_underwater = bool(listener_sample.get("water_present", false)) and listener_position.y < water_height + threshold
	_audio.set_underwater(_underwater)
	var environment := get_tree().get_first_node_in_group(&"planet_visual_environment")
	var on_surface := true
	if environment != null and environment.has_method("get_visual_mode"):
		on_surface = int(environment.get_visual_mode()) == 0
	var foliage := "forest" in String(_sample.get("biome_name", "")).to_lower()
	_targets[&"wind_loop"] = 0.7 if on_surface and not _underwater else 0.0
	_targets[&"foliage_loop"] = 0.65 if on_surface and foliage and not _underwater else 0.0
	_targets[&"underwater_loop"] = 0.8 if on_surface and _underwater else 0.0
	_shore_target = 0.0
	if not on_surface or _underwater:
		return
	# Only rendered water counts; river biome/noise alone does not imply water.
	var nearest := INF
	var nearest_position := Vector3.ZERO
	for radius in [0.0, 7.0, 18.0, 30.0]:
		for direction in 8 if radius > 0.0 else 1:
			var angle := float(direction) * TAU / 8.0
			var point: Vector3 = listener_position + Vector3(cos(angle), 0, sin(angle)) * float(radius)
			var probe := sample_at(point)
			if not bool(probe.get("water_present", false)):
				continue
			point.y = float(probe["water_height"])
			var distance: float = point.distance_to(listener_position)
			if distance < nearest:
				nearest = distance
				nearest_position = point
	if nearest < 40.0:
		_shore.global_position = nearest_position
		_shore_target = 0.75


func _process(delta: float) -> void:
	for event in _ambience:
		_gains[event] = move_toward(float(_gains[event]), float(_targets[event]), delta * 0.45)
		var voice: AudioStreamPlayer = _ambience[event]
		_set_loop_gain(voice, float(_gains[event]))
	_shore_gain = move_toward(_shore_gain, _shore_target, delta * 0.5)
	_set_loop_gain(_shore, _shore_gain)


func _set_loop_gain(voice: Node, gain: float) -> void:
	if gain < 0.001:
		voice.stop()
		return
	voice.volume_db = linear_to_db(gain)
	if not voice.playing:
		voice.play()
