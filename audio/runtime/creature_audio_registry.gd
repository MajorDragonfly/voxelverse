extends Node
## Attaches audio-only children to live creatures; never writes gameplay state.

const EMITTER = preload("res://audio/runtime/creature_audio_emitter.gd")
const MAX_TRACKED := 64
var automatic_tracking := true
var emitters: Dictionary = {}
var _scan_clock := 0.0
var _ambient_gap := 0.0
var _progression: Node
var _notice_gap := 0.0


func _process(delta: float) -> void:
	_ambient_gap = maxf(0.0, _ambient_gap - delta)
	_notice_gap = maxf(0.0, _notice_gap - delta)
	_scan_clock -= delta
	if _scan_clock > 0.0:
		return
	_scan_clock = 0.5
	for id in emitters.keys():
		if not is_instance_valid(emitters[id]):
			emitters.erase(id)
	if not automatic_tracking:
		return
	for group in [&"player", &"wildlife", &"grazer"]:
		for creature in get_tree().get_nodes_in_group(group):
			if creature is Node3D and creature.is_node_ready():
				attach(creature)
	_bind_progression()


func attach(source: Node3D) -> Node:
	if not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_inside_tree():
		return null
	if source.get_meta(&"audio_disabled", false):
		return null
	var id := source.get_instance_id()
	if is_instance_valid(emitters.get(id)):
		return emitters[id]
	if emitters.size() >= MAX_TRACKED or source.has_node("_VoxelverseAudio"):
		return null
	var emitter := EMITTER.new()
	emitter.name = "_VoxelverseAudio"
	emitter.source = source
	emitter.registry = self
	emitter.audio = get_parent()
	emitter.process_mode = Node.PROCESS_MODE_PAUSABLE
	source.add_child(emitter)
	emitters[id] = emitter
	return emitter


func emit_for(source: Node3D, event: StringName) -> bool:
	var emitter := attach(source)
	return emitter != null and emitter.emit_reaction(event)


func allow_contact() -> bool:
	if _ambient_gap > 0.0:
		return false
	_ambient_gap = 0.65
	return true


func audible(source: Node3D) -> bool:
	if not is_instance_valid(source) or not source.is_visible_in_tree():
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null or source.global_position.distance_squared_to(camera.global_position) > 48.0 * 48.0:
		return false
	var environment := get_tree().get_first_node_in_group(&"planet_visual_environment")
	return environment == null or not environment.has_method("get_visual_mode") or int(environment.get_visual_mode()) == 0


func clear() -> void:
	for emitter in emitters.values():
		if is_instance_valid(emitter):
			emitter.set_process(false)
			emitter.queue_free()
	emitters.clear()
	_ambient_gap = 0.0
	_scan_clock = 0.0


func _exit_tree() -> void:
	clear()


func _bind_progression() -> void:
	var service := get_node_or_null("/root/ProgressionService")
	if service == null or service == _progression:
		return
	_progression = service
	# Verified optional contracts. No dependency on the other branch's scripts.
	if service.has_signal("species_discovered"):
		service.connect("species_discovered", _species_discovered)
	if service.has_signal("behavior_node_purchased"):
		service.connect("behavior_node_purchased", _node_purchased)


func _species_discovered(_key: String, _display_name: String) -> void:
	# Scan-aware progression can report first sighting before scanning completes.
	# Its scanner owns the success cue; legacy discovery-only services keep theirs.
	if is_instance_valid(_progression) and _progression.has_method("has_species_scan"):
		return
	_notice(&"discovery")


func _node_purchased(_node_id: String) -> void:
	_notice(&"ui_confirm")


func _notice(event: StringName) -> void:
	if _notice_gap <= 0.0:
		get_parent().play_ui(event)
		_notice_gap = 0.35
