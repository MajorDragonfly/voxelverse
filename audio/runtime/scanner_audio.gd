extends Node
## Read-only scanner adapter plus a public progress/completion API.
## Progress reaching one does not itself authorize the discovery sound.

signal feedback_played(event: StringName)
const SCANNER_PATH := "res://creatures/player/creature_scanner.gd"
const MAX_COMPLETIONS := 128
var automatic_binding := true
var _scanner: Node
var _loop: AudioStreamPlayer
var _cue: AudioStreamPlayer
var _target_id := 0
var _progress := 0.0
var _gain := 0.0
var _gain_target := 0.0
var _last_update := 0.0
var _feedback_time := -1000
var _completed: Dictionary = {}
var _bind_clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	_loop = AudioStreamPlayer.new()
	_loop.bus = &"VV UI"
	add_child(_loop)
	_cue = AudioStreamPlayer.new()
	_cue.bus = &"VV UI"
	add_child(_cue)


func bind_scanner(scanner: Node) -> bool:
	if not is_instance_valid(scanner) or not scanner.is_inside_tree():
		return false
	if not scanner.has_method("active") or not scanner.has_method("ratio") or not scanner.has_signal("scan_completed"):
		return false
	var fields: Array = []
	for property in scanner.get_property_list():
		fields.append(property.name)
	if &"target" not in fields or &"known" not in fields:
		return false
	if _scanner == scanner:
		return true
	_unbind()
	_scanner = scanner
	_scanner.connect("scan_completed", _on_completed)
	return true


func _find_scanner() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if not is_instance_valid(player):
		return
	var queue: Array[Node] = [player]
	var visited := 0
	while not queue.is_empty() and visited < 64:
		var node: Node = queue.pop_front()
		visited += 1
		var script: Script = node.get_script()
		if script != null and script.resource_path == SCANNER_PATH and node.is_node_ready():
			bind_scanner(node)
			return
		for child in node.get_children():
			if queue.size() < 64:
				queue.append(child)


func _physics_process(delta: float) -> void:
	if get_tree().paused or not get_parent().is_window_focused():
		reset_playback()
		return
	_bind_clock -= delta
	if automatic_binding and not is_instance_valid(_scanner) and _bind_clock <= 0.0:
		_bind_clock = 0.35
		_find_scanner()
	if is_instance_valid(_scanner):
		if _scanner.is_queued_for_deletion() or not _scanner.active():
			cancel_scan(false)
			return
		var target := _scanner.get("target") as Node3D
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			cancel_scan()
		else:
			update_scan(target.get_instance_id(), float(_scanner.ratio()), bool(_scanner.get("known")))


func _process(delta: float) -> void:
	_last_update += delta
	if _target_id != 0 and _last_update > 0.4:
		cancel_scan(false) # A lost producer cannot leave a humming scanner behind.
	_gain = move_toward(_gain, _gain_target, delta * 12.0)
	_loop.volume_db = -17.0 + linear_to_db(maxf(_gain, 0.0001))
	_loop.pitch_scale = lerpf(_loop.pitch_scale, lerpf(0.9, 1.35, _progress), minf(delta * 12.0, 1.0))
	if _gain <= 0.0 and _loop.playing:
		_loop.stop()
		_loop.stream = null


func update_scan(target_id: int, progress: float, already_known: bool = false) -> bool:
	if get_tree().paused or not get_parent().is_window_focused() or target_id <= 0 or not is_finite(progress):
		cancel_scan(false)
		return false
	if already_known:
		cancel_scan(false)
		return true
	_last_update = 0.0
	if target_id != _target_id:
		_target_id = target_id
		_progress = 0.0
		_feedback(&"scan_acquire", -8.0)
	_progress = clampf(progress, 0.0, 1.0)
	_gain_target = 1.0
	if not _loop.playing:
		_loop.stream = get_parent().director.loop_stream(get_parent().get_sound_stream(&"scan_loop"))
		_loop.volume_db = -80.0
		_loop.play()
	return true


func cancel_scan(audible: bool = true) -> void:
	if audible and _target_id != 0 and _progress > 0.02 and not get_tree().paused:
		_feedback(&"scan_abort", -10.0)
	_target_id = 0
	_progress = 0.0
	_gain_target = 0.0


func complete_scan(species_key: String) -> bool:
	if _target_id == 0 or species_key.is_empty() or species_key.length() > 128 or get_tree().paused or not get_parent().is_window_focused():
		return false
	cancel_scan(false)
	if _completed.has(species_key):
		return false
	if _completed.size() >= MAX_COMPLETIONS:
		_completed.erase(_completed.keys()[0])
	_completed[species_key] = true
	_feedback(&"discovery", 0.0, true)
	return true


func _on_completed(species_key: String) -> void:
	# Only the bound scanner's current, observed target can complete this session.
	var target := _scanner.get("target") as Node3D
	if is_instance_valid(target) and not target.is_queued_for_deletion() and target.get_instance_id() == _target_id:
		complete_scan(species_key)


func _feedback(event: StringName, gain: float, force: bool = false) -> void:
	var now := Time.get_ticks_msec()
	if not force and now - _feedback_time < 180:
		return
	_feedback_time = now
	_cue.stop()
	_cue.stream = get_parent().get_sound_stream(event)
	_cue.volume_db = gain
	_cue.play()
	feedback_played.emit(event)


func reset_playback() -> void:
	cancel_scan(false)
	_gain = 0.0
	if is_instance_valid(_loop):
		_loop.stop()
		_loop.stream = null
	if is_instance_valid(_cue):
		_cue.stop()
		_cue.stream = null


func _unbind() -> void:
	if is_instance_valid(_scanner) and _scanner.is_connected("scan_completed", _on_completed):
		_scanner.disconnect("scan_completed", _on_completed)
	_scanner = null
	reset_playback()


func reset_scene() -> void:
	_unbind()
	_completed.clear()
	_feedback_time = -1000
	_bind_clock = 0.0


func _exit_tree() -> void:
	_unbind()
