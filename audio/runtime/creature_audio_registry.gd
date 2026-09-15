extends Node
## Audio-only observers. Incremental scene discovery never copies wildlife groups.

const EMITTER = preload("res://audio/runtime/creature_audio_emitter.gd")
const MAX_TRACKED := 64
const MAX_WALK_STEPS := 64
const MAX_WALK_DEPTH := 128
const MAX_POLLS := 8
const MAX_ATTACHMENTS := 4 # Two automatic, two reserved for explicit reactions.
const MAX_AUTOMATIC_ATTACHMENTS := 2
const MAX_RETIREMENTS := 2
const HEARING_DISTANCE := 48.0
const RELEASE_DISTANCE := 56.0
const REPLACEMENT_MARGIN := 4.0
var automatic_tracking := true
var emitters: Dictionary = {}
var generation := 0
var _ambient_gap := 0.0
var _progression: Node
var _notice_gap := 0.0
var _bind_clock := 0.0
var _elapsed := 0.0
var _poll_cursor := 0
var _walk: Array[Dictionary] = []
var _scene_id := 0
var _scan_wait := 0.0
var _budget_frame := -1
var _attached := 0
var _attempted := 0
var _retired := 0
var _walk_steps := 0
var _polled := 0
var _completed_sweeps := 0
var _depth_skips := 0


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_begin_frame()
	var scene := get_tree().current_scene
	var scene_id := scene.get_instance_id() if is_instance_valid(scene) else 0
	if _scene_id != scene_id:
		if _scene_id != 0:
			clear()
		_scene_id = scene_id
	_elapsed += delta
	_ambient_gap = maxf(0.0, _ambient_gap - delta)
	_notice_gap = maxf(0.0, _notice_gap - delta)
	_poll_emitters()
	_scan_wait -= delta
	if automatic_tracking and _scan_wait <= 0.0:
		_discover(scene if scene != null else get_tree().root)
	_bind_clock -= delta
	if _bind_clock <= 0.0:
		_bind_clock = 0.5
		_bind_progression()


func _begin_frame() -> void:
	var frame := Engine.get_process_frames()
	if frame == _budget_frame:
		return
	_budget_frame = frame
	_attached = 0
	_attempted = 0
	_retired = 0
	_walk_steps = 0
	_polled = 0


func _discover(scene: Node) -> void:
	if _walk.is_empty():
		_walk.append({"node": weakref(scene), "child": -1})
	while not _walk.is_empty() and _walk_steps < MAX_WALK_STEPS:
		_walk_steps += 1
		var entry: Dictionary = _walk.back()
		var node: Node = entry.node.get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion():
			_walk.pop_back()
			continue
		if node != scene and not scene.is_ancestor_of(node):
			_walk.pop_back() # Reparented out during a sweep.
			continue
		if int(entry.child) == -1:
			if node is Node3D and node.is_node_ready() and _creature_group(node) and audible(node):
				if not emitters.has(node.get_instance_id()) and _attempted >= MAX_AUTOMATIC_ATTACHMENTS:
					return # Retry this candidate next frame.
				attach(node, true)
			entry.child = 0
		if int(entry.child) >= node.get_child_count():
			_walk.pop_back()
		elif _walk.size() >= MAX_WALK_DEPTH:
			_depth_skips += 1
			_walk.pop_back()
		else:
			var child := node.get_child(int(entry.child))
			entry.child = int(entry.child) + 1
			_walk.append({"node": weakref(child), "child": -1})
	if _walk.is_empty():
		_completed_sweeps += 1
		_scan_wait = 0.25


func _poll_emitters() -> void:
	var ids := emitters.keys() # At most MAX_TRACKED, independent of population size.
	if ids.is_empty():
		_poll_cursor = 0
		return
	var visited := 0
	while visited < ids.size() and _polled < MAX_POLLS:
		_poll_cursor %= ids.size()
		var id: int = ids[_poll_cursor]
		_poll_cursor += 1
		visited += 1
		_polled += 1
		var emitter: Node = emitters.get(id)
		if not is_instance_valid(emitter):
			emitters.erase(id)
			continue
		if not emitter._active() or (emitter.managed and (not _keep_source(emitter.source) \
				or (emitter.group_tracked and not _creature_group(emitter.source)))):
			if _retired < MAX_RETIREMENTS:
				_retire(id)
			continue
		var delta: float = maxf(0.0, _elapsed - float(emitter.last_sample))
		emitter.last_sample = _elapsed
		emitter.sample(delta)


func attach(source: Node3D, managed: bool = false) -> Node:
	if not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_inside_tree():
		return null
	if source.get_meta(&"audio_disabled", false):
		return null
	var id := source.get_instance_id()
	if is_instance_valid(emitters.get(id)):
		return emitters[id]
	_begin_frame()
	if _attempted >= MAX_ATTACHMENTS or source.has_node("_VoxelverseAudio"):
		return null
	_attempted += 1
	if emitters.size() >= MAX_TRACKED and not _make_room(source):
		return null
	var emitter := EMITTER.new()
	emitter.name = "_VoxelverseAudio"
	emitter.source = source
	emitter.registry = self
	emitter.audio = get_parent()
	emitter.managed = managed
	emitter.group_tracked = managed and _creature_group(source)
	emitter.generation = generation
	emitter.last_sample = _elapsed
	emitter.process_mode = Node.PROCESS_MODE_PAUSABLE
	emitters[id] = emitter
	_attached += 1
	source.add_child(emitter)
	return emitter


func _make_room(source: Node3D) -> bool:
	if _retired >= MAX_RETIREMENTS or not audible(source):
		return false
	var camera := get_viewport().get_camera_3d()
	var distance := source.global_position.distance_to(camera.global_position)
	var worst := -1
	var worst_distance_squared := pow(distance + REPLACEMENT_MARGIN, 2.0)
	if source.is_in_group(&"player"):
		worst_distance_squared = -1.0
	for id in emitters:
		var emitter: Node = emitters[id]
		if not is_instance_valid(emitter):
			worst = id
			break
		if not emitter.managed:
			continue
		var candidate: Node3D = emitter.source
		if not is_instance_valid(candidate) or not candidate.is_inside_tree() or candidate.is_queued_for_deletion():
			worst = id
			break
		if candidate.is_in_group(&"player"):
			continue
		if not candidate.is_visible_in_tree() or candidate.get_meta(&"audio_disabled", false):
			worst = id
			break
		# Scope is checked by the bounded poller. Ranking must not repeat all
		# viewport/environment queries for every slot and incoming candidate.
		var candidate_distance: float = candidate.global_position.distance_squared_to(camera.global_position)
		if not is_finite(candidate_distance) or candidate_distance > worst_distance_squared:
			worst_distance_squared = candidate_distance
			worst = id
	if worst < 0:
		return false
	_retire(worst)
	return true


func _retire(id: int) -> void:
	var emitter: Node = emitters.get(id)
	emitters.erase(id)
	_retired += 1
	if is_instance_valid(emitter):
		emitter.deactivate()
		# Removal permits reattachment before the old node is freed this frame.
		if emitter.get_parent() != null:
			emitter.get_parent().remove_child(emitter)
		emitter.queue_free()


func release(id: int, emitter: Node) -> void:
	if emitters.get(id) == emitter:
		emitters.erase(id)


func owns(id: int, emitter: Node, source_generation: int) -> bool:
	return generation == source_generation and emitters.get(id) == emitter


func emit_for(source: Node3D, event: StringName) -> bool:
	if get_tree().paused or not event in EMITTER.REACTIONS or not audible(source):
		return false
	var emitter := attach(source, true)
	return emitter != null and emitter.emit_reaction(event)


func allow_contact() -> bool:
	if _ambient_gap > 0.0:
		return false
	_ambient_gap = 0.65
	return true


func _creature_group(source: Node) -> bool:
	return source.is_in_group(&"player") or source.is_in_group(&"wildlife") or source.is_in_group(&"grazer")


func _keep_source(source: Node3D) -> bool:
	return _in_listener_scope(source, RELEASE_DISTANCE)


func _in_listener_scope(source: Node3D, distance: float) -> bool:
	if not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion() \
			or not source.is_visible_in_tree() or source.get_meta(&"audio_disabled", false):
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null or source.get_viewport() != camera.get_viewport() or source.get_world_3d() != camera.get_world_3d():
		return false
	var scene := get_tree().current_scene
	if scene != null and source != scene and not scene.is_ancestor_of(source):
		return false
	if not source.global_position.is_finite() or not camera.global_position.is_finite() \
			or source.global_position.distance_squared_to(camera.global_position) > distance * distance:
		return false
	var environment := get_tree().get_first_node_in_group(&"planet_visual_environment")
	return environment == null or not environment.has_method("get_visual_mode") or int(environment.get_visual_mode()) == 0


func audible(source: Node3D) -> bool:
	return _in_listener_scope(source, HEARING_DISTANCE)


func diagnostics() -> Dictionary:
	return {"tracked": emitters.size(), "walk_depth": _walk.size(), "walk_steps": _walk_steps,
		"attached": _attached, "attempted": _attempted, "retired": _retired, "polled": _polled, "generation": generation,
		"completed_sweeps": _completed_sweeps, "depth_skips": _depth_skips}


func clear() -> void:
	generation += 1 # Invalidate callbacks before any source is detached.
	for id in emitters.keys():
		_retire(id)
	emitters.clear()
	_walk.clear()
	_ambient_gap = 0.0
	_notice_gap = 0.0
	_scan_wait = 0.0
	_poll_cursor = 0


func _exit_tree() -> void:
	_unbind_progression()
	clear()


func _bind_progression() -> void:
	var service := get_node_or_null("/root/ProgressionService")
	if service == _progression:
		return
	_unbind_progression()
	_progression = service
	if service == null:
		return
	if service.has_signal("species_discovered"):
		service.connect("species_discovered", _species_discovered)
	if service.has_signal("behavior_node_purchased"):
		service.connect("behavior_node_purchased", _node_purchased)


func _unbind_progression() -> void:
	if is_instance_valid(_progression):
		for pair in [[&"species_discovered", _species_discovered], [&"behavior_node_purchased", _node_purchased]]:
			if _progression.is_connected(pair[0], pair[1]):
				_progression.disconnect(pair[0], pair[1])
	_progression = null


func _species_discovered(_key: String, _display_name: String) -> void:
	if is_instance_valid(_progression) and _progression.has_method("has_species_scan"):
		return
	_notice(&"discovery")


func _node_purchased(_node_id: String) -> void:
	_notice(&"ui_confirm")


func _notice(event: StringName) -> void:
	if _notice_gap <= 0.0:
		get_parent().play_ui(event)
		_notice_gap = 0.35
