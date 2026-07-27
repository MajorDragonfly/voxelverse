extends "res://creatures/player/player.gd"

# Creature movement V6 keeps the existing survival/editor integration but adds
# automatic stair stepping for the terraced voxel surface. Small height changes
# no longer require a jump; larger ledges still block the player normally.

@export_range(0.10, 1.20, 0.05)
var maximum_step_height: float = 0.58

@export_range(0.02, 0.30, 0.01)
var step_floor_probe: float = 0.10


func _ready() -> void:
	super._ready()
	floor_snap_length = maximum_step_height + 0.12
	floor_max_angle = deg_to_rad(52.0)
	floor_stop_on_slope = true
	floor_constant_speed = true


func _physics_process(delta: float) -> void:
	if is_dead:
		_process_dead_movement(delta)
		return

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	var camera_forward := -camera_pivot.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right := camera_pivot.global_transform.basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var direction := camera_right * input_vector.x + camera_forward * -input_vector.y
	if direction.length_squared() > 0.0:
		direction = direction.normalized()

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	var grounded_before_move: bool = is_on_floor()
	if grounded_before_move:
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= fall_acceleration * delta

	if (
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		and Input.is_action_just_pressed("primary_action")
	):
		_try_primary_action()

	if grounded_before_move and velocity.y <= 0.0:
		_attempt_step_up(delta)
	move_and_slide()
	if is_on_floor():
		apply_floor_snap()


func _attempt_step_up(delta: float) -> bool:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length_squared() < 0.01:
		return false
	var horizontal_motion: Vector3 = horizontal_velocity * delta
	var original_transform: Transform3D = global_transform
	if not test_move(original_transform, horizontal_motion):
		return false

	var up_motion := Vector3.UP * maximum_step_height
	if test_move(original_transform, up_motion):
		return false
	var raised_transform: Transform3D = original_transform.translated(up_motion)
	if test_move(raised_transform, horizontal_motion):
		return false

	var forward_transform: Transform3D = raised_transform.translated(horizontal_motion)
	var ground_probe := Vector3.DOWN * (maximum_step_height + step_floor_probe)
	if not test_move(forward_transform, ground_probe):
		return false

	global_transform = raised_transform
	return true
