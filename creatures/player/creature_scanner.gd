extends Node

signal scan_completed(species_key: String)
const Tracker = preload("res://core/discovery/scan_tracker.gd")
var tracker := Tracker.new()
var target: Node3D
var known: bool = false
var _player: Node
var _progression: Node
var _world_seed: int = 0
var _campaign_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_parent()
	_progression = get_node("/root/ProgressionService")
	_player.inspection_mode_changed.connect(func(_enabled: bool): reset())

func active() -> bool:
	var flow := get_node_or_null("/root/SessionFlow")
	return is_instance_valid(_player) and _player.is_physics_processing() and _player.inspection_mode_enabled and not _player.is_dead and not get_tree().paused and (flow == null or not flow.loading) and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless")

func reset() -> void:
	tracker.reset()
	target = null
	known = false

func _physics_process(delta: float) -> void:
	if not active():
		reset()
		return
	var state: Node = get_node("/root/GameState")
	var seed_value: int = state.get_world_seed()
	var identity: String = state.campaign.data.id
	if seed_value != _world_seed or identity != _campaign_id:
		reset()
		_world_seed = seed_value
		_campaign_id = identity
	var aimed: Node3D = _player.get_scan_target()
	var changed: bool = aimed != target
	target = aimed
	known = false
	if target == null:
		tracker.reset()
		return
	var species_seed: int = int(target.get("species_seed"))
	known = _progression.has_species_scan(species_seed, _world_seed)
	if known:
		tracker.reset()
		if changed:
			_progression.register_species_scan(species_seed, target.get("blueprint"), _world_seed)
		_player.guidance_action.emit("inspect", 1.0)
		return
	if tracker.advance(target.get_instance_id(), delta):
		var result: Dictionary = _progression.register_species_scan(species_seed, target.get("blueprint"), _world_seed)
		known = _progression.has_species_scan(species_seed, _world_seed)
		if known:
			_player.guidance_action.emit("inspect", 1.0)
			scan_completed.emit(str(result.get("species_key", "")))

func ratio() -> float:
	return 1.0 if known else tracker.ratio()
