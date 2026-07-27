extends Node

@export_range(1.0, 20.0, 0.5)
var turn_speed: float = 8.5

@export_range(0.0, 2.0, 0.05)
var minimum_turn_speed: float = 0.18

var _player: CharacterBody3D
var _visual_root: Node3D
var _target_yaw: float = 0.0


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	call_deferred("_bind_visual_root")


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if _visual_root == null or not is_instance_valid(_visual_root):
		_bind_visual_root()
		if _visual_root == null:
			return

	var horizontal_velocity := Vector3(
		_player.velocity.x,
		0.0,
		_player.velocity.z
	)
	if horizontal_velocity.length() < minimum_turn_speed:
		return

	var direction: Vector3 = horizontal_velocity.normalized()
	# Godot's local forward direction is -Z.
	_target_yaw = atan2(-direction.x, -direction.z)
	_visual_root.rotation.y = lerp_angle(
		_visual_root.rotation.y,
		_target_yaw,
		clampf(turn_speed * delta, 0.0, 1.0)
	)


func _bind_visual_root() -> void:
	if _player == null:
		return
	_visual_root = _player.get_node_or_null("CreatureRuntimeVisual") as Node3D
	if _visual_root != null:
		_target_yaw = _visual_root.rotation.y
