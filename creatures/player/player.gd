extends CharacterBody3D


@export_category("Movement")
@export var move_speed: float = 5.0
@export var jump_velocity: float = 6.0
@export var fall_acceleration: float = 20.0

@export_category("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var minimum_camera_angle: float = -60.0
@export var maximum_camera_angle: float = 35.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D


func _ready() -> void:
	# Die Kamera soll nicht mit dem eigenen Player kollidieren.
	spring_arm.add_excluded_object(get_rid())

	# Maus für die Kamerasteuerung einfangen.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			camera_pivot.rotation.x -= (
				event.screen_relative.y * mouse_sensitivity
			)

			camera_pivot.rotation.y -= (
				event.screen_relative.x * mouse_sensitivity
			)

			camera_pivot.rotation.x = clampf(
				camera_pivot.rotation.x,
				deg_to_rad(minimum_camera_angle),
				deg_to_rad(maximum_camera_angle)
			)

	# Escape gibt die Maus wieder frei.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Linksklick fängt die Maus erneut ein.
	if event is InputEventMouseButton:
		if (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	# Blickrichtung der Kamera ohne vertikale Neigung.
	var camera_forward := -camera_pivot.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()

	var camera_right := camera_pivot.global_transform.basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()

	# Bewegung relativ zur Kamerarichtung.
	var direction := (
		camera_right * input_vector.x
		+ camera_forward * -input_vector.y
	)

	if direction.length_squared() > 0.0:
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
