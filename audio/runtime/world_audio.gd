extends Node
const Space = preload("res://world/surface/gameplay_space.gd")
const ShoreSearch = preload("res://audio/runtime/shore_search.gd")
const Immersion = preload("res://world/surface/water_immersion.gd")
## Read-only adapter for the existing player and generator. No movement changes.
## The spherical campaign supplies Water.audio_sample; explicit diagnostic
## scenes may supply sample_provider(position). A radial listener never falls
## through to planar sampling when its surface or water port is missing.

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
var _shore_job: RefCounted
var _source_generation: int = 0
var _bound_scope: Array = []
var _on_surface: bool = true
var last_sample_queries: int = 0
var peak_sample_queries: int = 0
var last_shore_queries: int = 0
var completed_shore_searches: int = 0
var cancelled_shore_searches: int = 0
var max_environment_step_ms: float = 0.0


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
	_source_generation += 1
	_cancel_shore_search()
	_bound_scope.clear()
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
	last_sample_queries = 0
	last_shore_queries = 0
	var started: int = Time.get_ticks_usec()
	_track_world(delta)
	peak_sample_queries = maxi(peak_sample_queries, last_sample_queries)
	max_environment_step_ms = maxf(max_environment_step_ms, (Time.get_ticks_usec() - started) / 1000.0)


func _track_world(delta: float) -> void:
	if not automatic_tracking:
		return
	# Scene changes detach the old player before freeing it. A valid cached
	# reference cannot be used for transforms or physics in that interval.
	if is_instance_valid(_player) and (not _player.is_inside_tree() or _player.is_queued_for_deletion() or not _in_current_scene(_player)):
		reset_tracking()
		return
	if is_instance_valid(_player) and _bound_scope != _source_scope():
		_audio.stop_world()
		reset_tracking()
	if not is_instance_valid(_player):
		_bind_clock -= delta
		if _bind_clock > 0.0:
			return
		_bind_clock = 0.25
		var candidate: CharacterBody3D = _find_player()
		# A radial listener needs its own surface or an explicit local port;
		# missing capabilities must never enable the legacy planar sampler.
		if candidate != null and candidate.get_meta("surface_mode", "legacy_plane_v9") != "legacy_plane_v9" and Space.adapter(self) == null and not _has_sample_provider():
			reset_tracking()
			_bind_clock = 0.5
			return
		if candidate == null or candidate.is_queued_for_deletion():
			reset_tracking()
			_bind_clock = 0.25
			return
		_player = candidate
		_bound_scope = _source_scope()
		_reset_motion()
		_update_environment()
		_sample_clock = 0.35
	var position := _player.global_position
	var up := _player.up_direction.normalized()
	var motion := position - _last_position
	var horizontal := motion.slide(up).length()
	var vertical_speed := _player.velocity.dot(up)
	var grounded := _player.is_on_floor()
	# Teleport/respawn and long stalls must not synthesize a burst of steps.
	if motion.length() > maxf(5.0, _player.velocity.length() * delta * 3.0) or delta > 0.2:
		_audio.stop_world()
		_source_generation += 1
		_cancel_shore_search()
		_shore_target = 0.0
		_reset_motion()
		_update_environment()
		_sample_clock = 0.35
		return
	_sample_clock -= delta
	if _sample_clock <= 0.0:
		_sample_clock = 0.35
		_update_environment()
	_step_shore_search()
	_settle = maxf(0.0, _settle - delta)
	var wet := bool(_sample.get("water_present", false)) and _depth(_sample, position) > 0.04
	var depth := _depth(_sample, position) if wet else 0.0
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
	last_sample_queries += 1
	if _has_sample_provider():
		return sample_provider.call(position)
	if Space.adapter(self) != null:
		var water: Node = get_tree().current_scene.get_node_or_null("Water")
		return water.audio_sample(position) if is_instance_valid(water) and water.has_method("audio_sample") else {}
	if is_instance_valid(_player) and _player.get_meta("surface_mode", "legacy_plane_v9") != "legacy_plane_v9":
		return {}
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
	_underwater = Immersion.submerged(bool(listener_sample.get("water_present", false)), _depth(listener_sample, listener_position), _underwater)
	_audio.set_underwater(_underwater)
	var environment := get_tree().get_first_node_in_group(&"planet_visual_environment")
	_on_surface = true
	if environment != null and environment.has_method("get_visual_mode"):
		_on_surface = int(environment.get_visual_mode()) == 0
	var foliage := "forest" in String(_sample.get("biome_name", "")).to_lower()
	_targets[&"wind_loop"] = 0.7 if _on_surface and not _underwater else 0.0
	_targets[&"foliage_loop"] = 0.65 if _on_surface and foliage and not _underwater else 0.0
	_targets[&"underwater_loop"] = 0.8 if _on_surface and _underwater else 0.0
	if not _on_surface or _underwater:
		_shore_target = 0.0
		_cancel_shore_search()
		return
	# Finish the current bounded scan even at low FPS. Restarting every 0.35 s
	# would starve a 25-probe search that needs 13 low-frequency physics ticks.
	if _shore_job == null:
		var frame: Basis = Space.frame(self, listener_position) if Space.adapter(self) != null else Space.Cube.frame(_player.up_direction)
		_shore_job = ShoreSearch.new(listener_position, frame, _source_generation)


func _listener_position() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	return camera.global_position if camera != null else _player.global_position + _player.up_direction * 1.5


func _step_shore_search() -> void:
	last_shore_queries = 0
	if _shore_job == null: return
	if not is_instance_valid(_player) or not _player.is_inside_tree() or not _in_current_scene(_player) \
		or _shore_job.generation != _source_generation or (not _bound_scope.is_empty() and _bound_scope != _source_scope()):
		_cancel_shore_search()
		_shore_target = 0.0
		return
	var listener: Vector3 = _listener_position()
	if listener.distance_to(_shore_job.listener) > ShoreSearch.MAX_OBSERVER_DRIFT:
		_cancel_shore_search()
		_shore_target = 0.0
		_sample_clock = 0.0
		return
	_shore_job.step(sample_at)
	last_shore_queries = _shore_job.queries_last_step
	if not _shore_job.complete(): return
	_shore_target = 0.0
	if _on_surface and not _underwater and _shore_job.nearest < 40.0 \
		and _shore_job.nearest_position.distance_to(listener) < 40.0:
		_shore.global_position = _shore_job.nearest_position
		_shore_target = 0.75
	_shore_job = null
	completed_shore_searches += 1


func _cancel_shore_search() -> void:
	if _shore_job != null: cancelled_shore_searches += 1
	_shore_job = null


func _in_current_scene(node: Node) -> bool:
	var scene: Node = get_tree().current_scene
	return scene == null or node == scene or scene.is_ancestor_of(node)


func _find_player() -> CharacterBody3D:
	for candidate in get_tree().get_nodes_in_group(&"player"):
		if candidate is CharacterBody3D and not candidate.is_queued_for_deletion() and _in_current_scene(candidate):
			return candidate
	return null


func _has_sample_provider() -> bool:
	if not sample_provider.is_valid(): return false
	var owner: Object = sample_provider.get_object()
	return not owner is Node or (owner.is_inside_tree() and not owner.is_queued_for_deletion() and _in_current_scene(owner))


func _source_scope() -> Array:
	var scene: Node = get_tree().current_scene
	var surface: RefCounted = Space.adapter(self)
	var water: Node = scene.get_node_or_null("Water") if scene != null else null
	var camera: Camera3D = get_viewport().get_camera_3d()
	return [camera.get_instance_id() if camera != null else 0, scene.get_instance_id() if scene != null else 0,
		_player.get_instance_id() if is_instance_valid(_player) else 0,
		surface.get_instance_id() if surface != null else 0,
		str(surface.terrain.surface.body.id) if surface != null else "",
		water.get_instance_id() if water != null else 0, sample_provider if _has_sample_provider() else Callable()]


func sampling_diagnostics() -> Dictionary:
	return {"pending_searches": int(_shore_job != null), "pending_probes": ShoreSearch.PROBE_COUNT - _shore_job.cursor if _shore_job != null else 0,
		"generation": _source_generation, "last_queries": last_sample_queries, "peak_queries": peak_sample_queries,
		"last_shore_queries": last_shore_queries, "completed_searches": completed_shore_searches,
		"cancelled_searches": cancelled_shore_searches, "max_step_ms": max_environment_step_ms}

func _depth(sample: Dictionary, point: Vector3) -> float:
	if sample.has("water_point"): return (sample.water_point - point).dot(sample.up)
	return float(sample.get("water_height", -INF)) - point.y

func surface_origin_shifted(shift: Vector3) -> void:
	_last_position += shift
	_shore.global_position += shift
	if _sample.has("water_point"): _sample.water_point += shift
	if _shore_job != null: _shore_job.rebase(shift)
	for voice: AudioStreamPlayer3D in _audio._voices:
		if voice.playing: voice.global_position += shift


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
