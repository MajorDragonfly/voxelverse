extends CharacterBody3D


const STARVATION_DAMAGE_INTERVAL: float = 1.0


@export_category("Movement")
@export var move_speed: float = 5.0
@export var jump_velocity: float = 6.0
@export var fall_acceleration: float = 20.0

@export_category("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var minimum_camera_angle: float = -60.0
@export var maximum_camera_angle: float = 35.0

@export_category("Interaction")
@export var interaction_range: float = 3.0

@export_category("Survival")
@export_range(1.0, 1000.0, 1.0) var maximum_health: float = 100.0
@export_range(1.0, 1000.0, 1.0) var maximum_hunger: float = 100.0
@export_range(0.0, 100.0, 0.1) var hunger_loss_per_second: float = 5.0
@export_range(0.0, 100.0, 0.1) var starvation_damage_per_second: float = 10.0
@export_range(0.5, 30.0, 0.5) var status_output_interval: float = 2.0


var current_health: float
var current_hunger: float
var is_dead: bool = false

var _starvation_damage_timer: float = 0.0
var _status_output_timer: float = 0.0


@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var interaction_ray: RayCast3D = (
	$CameraPivot/SpringArm3D/Camera3D/InteractionRay
)

@onready var health_label: Label = (
	$HUD/StatusContainer/HealthLabel
)

@onready var health_bar: ProgressBar = (
	$HUD/StatusContainer/HealthBar
)

@onready var hunger_label: Label = (
	$HUD/StatusContainer/HungerLabel
)

@onready var hunger_bar: ProgressBar = (
	$HUD/StatusContainer/HungerBar
)


func _ready() -> void:
	current_health = maximum_health
	current_hunger = maximum_hunger

	# Die Kamera soll nicht mit dem eigenen Player kollidieren.
	spring_arm.add_excluded_object(get_rid())

	# Der Interaktionsstrahl soll den eigenen Player ignorieren.
	interaction_ray.add_exception(self)

	# Maus für die Kamerasteuerung einfangen.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_initialize_hud()
	_update_hud()
	_print_status()


func _process(delta: float) -> void:
	if is_dead:
		return

	_update_hunger(delta)
	_update_hud()
	_update_status_output(delta)


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
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
		):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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

	if (
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		and Input.is_action_just_pressed("primary_action")
	):
		_try_primary_action()

	move_and_slide()


func _process_dead_movement(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= fall_acceleration * delta

	move_and_slide()


func _update_hunger(delta: float) -> void:
	current_hunger = maxf(
		current_hunger - hunger_loss_per_second * delta,
		0.0
	)

	if current_hunger > 0.0:
		_starvation_damage_timer = 0.0
		return

	_starvation_damage_timer += delta

	while (
		_starvation_damage_timer
		>= STARVATION_DAMAGE_INTERVAL
	):
		_starvation_damage_timer -= (
			STARVATION_DAMAGE_INTERVAL
		)

		receive_damage(
			starvation_damage_per_second
			* STARVATION_DAMAGE_INTERVAL
		)

		if is_dead:
			return


func _initialize_hud() -> void:
	health_bar.min_value = 0.0
	health_bar.max_value = maximum_health

	hunger_bar.min_value = 0.0
	hunger_bar.max_value = maximum_hunger

	health_bar.show_percentage = false
	hunger_bar.show_percentage = false


func _update_hud() -> void:
	health_bar.max_value = maximum_health
	health_bar.value = current_health

	hunger_bar.max_value = maximum_hunger
	hunger_bar.value = current_hunger

	health_label.text = (
		"Gesundheit: %d / %d"
		% [
			roundi(current_health),
			roundi(maximum_health)
		]
	)

	hunger_label.text = (
		"Hunger: %d / %d"
		% [
			roundi(current_hunger),
			roundi(maximum_hunger)
		]
	)


func _update_status_output(delta: float) -> void:
	_status_output_timer += delta

	if _status_output_timer < status_output_interval:
		return

	_status_output_timer = 0.0
	_print_status()


func _try_primary_action() -> void:
	interaction_ray.force_raycast_update()

	if not interaction_ray.is_colliding():
		return

	var collision_point := interaction_ray.get_collision_point()
	var distance_to_target := global_position.distance_to(
		collision_point
	)

	if distance_to_target > interaction_range:
		return

	var collider := interaction_ray.get_collider()

	if collider == null:
		return

	if collider.has_method("interact"):
		collider.call("interact", self)


func can_perform_action(action: StringName) -> bool:
	return GameState.has_ability(action)


func receive_damage(damage: float) -> void:
	if is_dead:
		return

	if damage <= 0.0:
		return

	current_health = maxf(
		current_health - damage,
		0.0
	)

	_update_hud()

	print(
		"Player received damage: ",
		damage,
		" | Health: ",
		current_health,
		" / ",
		maximum_health
	)

	if current_health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if is_dead:
		return

	if amount <= 0.0:
		return

	current_health = minf(
		current_health + amount,
		maximum_health
	)

	_update_hud()

	print(
		"Player healed: ",
		amount,
		" | Health: ",
		current_health,
		" / ",
		maximum_health
	)


func restore_hunger(amount: float) -> void:
	if is_dead:
		return

	if amount <= 0.0:
		return

	current_hunger = minf(
		current_hunger + amount,
		maximum_hunger
	)

	_starvation_damage_timer = 0.0

	_update_hud()

	print(
		"Hunger restored: ",
		amount,
		" | Hunger: ",
		current_hunger,
		" / ",
		maximum_hunger
	)


func get_health_ratio() -> float:
	if maximum_health <= 0.0:
		return 0.0

	return current_health / maximum_health


func get_hunger_ratio() -> float:
	if maximum_hunger <= 0.0:
		return 0.0

	return current_hunger / maximum_hunger


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	current_health = 0.0

	_update_hud()

	health_label.text = "Gesundheit: TOT"

	print(
		"Player died. Nest respawn is not implemented yet."
	)


func _print_status() -> void:
	print(
		"Player status | Health: ",
		current_health,
		" / ",
		maximum_health,
		" | Hunger: ",
		current_hunger,
		" / ",
		maximum_hunger
	)
