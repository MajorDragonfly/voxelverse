extends Node
## One observer per live actor, context sampled at 5 Hz. No world scans or archive
## queries here. The actor supplies existing AI/ownership facts through a read port.
const Emotion = preload("res://creatures/behavior/creature_emotion.gd")
var emotion := Emotion.new()
var _actor: Node3D
var _preview: Node3D
var _context: Dictionary = {}
var _sample_remaining: float = 0.0


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
	if is_instance_valid(_preview): _preview.set_expression_pose({})


func react(event: String) -> void:
	emotion.react(event)
	_sample_remaining = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(_preview): return
	var dt: float = get_node("/root/GameState").simulation_delta(delta)
	if dt <= 0.0: return
	_sample_remaining -= dt
	if _sample_remaining <= 0.0 or bool(_actor.get("is_dead")):
		_context = _actor.get_expression_context()
		_sample_remaining = 0.2
	if bool(_actor.get("is_dead")):
		emotion.reset()
		_preview.set_expression_pose({})
		return
	if not bool(_context.get("active", true)):
		_preview.set_expression_pose({})
		return
	_preview.set_expression_pose(emotion.advance(dt, _context))
