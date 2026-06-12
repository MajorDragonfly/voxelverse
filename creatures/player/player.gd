extends CharacterBody3D


@export var move_speed: float = 5.0
@export var jump_velocity: float = 6.0
@export var fall_acceleration: float = 20.0


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	var direction := Vector3(
		input_vector.x,
		0.0,
		input_vector.y
	)

	if direction != Vector3.ZERO:
		direction = direction.normalized()

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	if is_on_floor():
		velocity.y = 0.0

		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= fall_acceleration * delta

	move_and_slide()
