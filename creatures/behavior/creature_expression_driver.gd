extends Node
## One observer per live actor, context sampled at 5 Hz. No world scans or archive
## queries here. The actor supplies existing AI/ownership facts through a read port.
const Emotion = preload("res://creatures/behavior/creature_emotion.gd")
var emotion := Emotion.new()
var _actor: Node3D
var _preview: Node3D
var _context: Dictionary = {}
var _sample_remaining: float = 0.0
var _pose_remaining: float = 0.0
var _pose_elapsed: float = 0.0
var _pose_interval: float = 0.0


func _ready() -> void:
	_actor = get_parent()
	_preview = _actor.get("_preview")
	emotion.configure(int(_actor.get("individual_seed")))
	process_priority = -5
	get_node("/root/SaveGameService").game_loaded.connect(_loaded)


func _loaded(_path: String) -> void:
	emotion.reset()
	_context.clear()
	_sample_remaining = 0.0
	_pose_remaining = 0.0
	_pose_elapsed = 0.0
	if is_instance_valid(_preview): _preview.set_expression_pose({})


func react(event: String) -> void:
	emotion.react(event)
	_sample_remaining = 0.0
	_pose_remaining = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(_preview): return
	var state: Node = get_node("/root/GameState")
	# The existing preview speed port covers gait, breathing and jaw actions.
	# Only wildlife has this driver; workshop/player preview clocks stay owned
	# by their callers. Run before the early return so zero speed freezes all.
	_preview.motion_speed_scale = state.simulation_delta(1.0)
	var dt: float = state.simulation_delta(delta)
	if dt <= 0.0: return
	_sample_remaining -= dt
	_pose_remaining -= dt
	_pose_elapsed += dt
	if _sample_remaining <= 0.0 or bool(_actor.get("is_dead")):
		var old_intent: String = str(_context.get("intent", ""))
		var old_threat: bool = bool(_context.get("threat", false))
		_context = _actor.get_expression_context()
		_pose_interval = _interval_for_camera()
		_sample_remaining = 0.2 if _pose_interval < 0.5 else 0.5
		if old_intent != str(_context.get("intent", "")) or old_threat != bool(_context.get("threat", false)):
			_pose_remaining = 0.0
	if bool(_actor.get("is_dead")):
		emotion.reset()
		_preview.set_expression_pose({})
		_pose_elapsed = 0.0
		return
	if not bool(_context.get("active", true)):
		_preview.set_expression_pose({})
		_pose_remaining = 0.0
		_pose_elapsed = 0.0
		return
	if _pose_remaining > 0.0: return
	_preview.set_expression_pose(emotion.advance(_pose_elapsed, _context))
	_pose_elapsed = 0.0
	_pose_remaining = _pose_interval


func _interval_for_camera() -> float:
	# Only expression sampling is throttled. Locomotion and foot planting keep
	# their existing update rate; no distance-dependent gameplay state is saved.
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null: return 0.0
	var distance: float = camera.global_position.distance_to(_actor.global_position)
	if distance > 85.0: return 0.5
	if distance > 25.0: return 0.12
	return 0.0
