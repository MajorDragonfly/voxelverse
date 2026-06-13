extends CharacterBody3D


const STARVATION_DAMAGE_INTERVAL: float = 1.0
const DEHYDRATION_DAMAGE_INTERVAL: float = 1.0


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
@export_range(1.0, 1000.0, 1.0) var maximum_thirst: float = 100.0

@export_range(0.0, 100.0, 0.1) var hunger_loss_per_second: float = 0.2
@export_range(0.0, 100.0, 0.1) var thirst_loss_per_second: float = 0.3

@export_range(1.0, 100.0, 1.0) var water_drink_amount: float = 35.0

@export_range(0.0, 100.0, 0.1) var starvation_damage_per_second: float = 5.0
@export_range(0.0, 100.0, 0.1) var dehydration_damage_per_second: float = 7.0

@export_range(0.5, 30.0, 0.5) var status_output_interval: float = 2.0
@export_range(0.0, 30.0, 0.5) var respawn_delay: float = 2.0


var current_health: float
var current_hunger: float
var current_thirst: float
var is_dead: bool = false

var _starvation_damage_timer: float = 0.0
var _dehydration_damage_timer: float = 0.0
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

@onready var thirst_label: Label = (
	$HUD/StatusContainer/ThirstLabel
)

@onready var thirst_bar: ProgressBar = (
	$HUD/StatusContainer/ThirstBar
)


func _ready() -> void:
	add_to_group(&"player")

	current_health = maximum_health
	current_hunger = maximum_hunger
	current_thirst = maximum_thirst

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

	if is_dead:
		return

	_update_thirst(delta)

	if is_dead:
		return

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

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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

	var camera_forward := -camera_pivot.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()

	var camera_right := camera_pivot.global_transform.basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()

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
		_starvation_damage_timer -= STARVATION_DAMAGE_INTERVAL

		receive_damage(
			starvation_damage_per_second
			* STARVATION_DAMAGE_INTERVAL
		)

		if is_dead:
			return


func _update_thirst(delta: float) -> void:
	current_thirst = maxf(
		current_thirst - thirst_loss_per_second * delta,
		0.0
	)

	if current_thirst > 0.0:
		_dehydration_damage_timer = 0.0
		return

	_dehydration_damage_timer += delta

	while (
		_dehydration_damage_timer
		>= DEHYDRATION_DAMAGE_INTERVAL
	):
		_dehydration_damage_timer -= DEHYDRATION_DAMAGE_INTERVAL

		receive_damage(
			dehydration_damage_per_second
			* DEHYDRATION_DAMAGE_INTERVAL
		)

		if is_dead:
			return


func _initialize_hud() -> void:
	health_bar.min_value = 0.0
	health_bar.max_value = maximum_health

	hunger_bar.min_value = 0.0
	hunger_bar.max_value = maximum_hunger

	thirst_bar.min_value = 0.0
	thirst_bar.max_value = maximum_thirst

	health_bar.show_percentage = false
	hunger_bar.show_percentage = false
	thirst_bar.show_percentage = false


func _update_hud() -> void:
	health_bar.max_value = maximum_health
	health_bar.value = current_health

	hunger_bar.max_value = maximum_hunger
	hunger_bar.value = current_hunger

	thirst_bar.max_value = maximum_thirst
	thirst_bar.value = current_thirst

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

	thirst_label.text = (
		"Durst: %d / %d"
		% [
			roundi(current_thirst),
			roundi(maximum_thirst)
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

	if WorldGenerator.is_below_sea_level(
		collision_point.x,
		collision_point.z
	):
		_try_drink_water()
		return

	var collider := interaction_ray.get_collider()

	if collider == null:
		return

	if collider.has_method("interact"):
		collider.call("interact", self)


func _try_drink_water() -> void:
	if not can_perform_action(&"drink"):
		print(
			"Player does not have the ability to drink."
		)
		return

	if current_thirst >= maximum_thirst:
		print("Player is not thirsty.")
		return

	restore_thirst(water_drink_amount)

	print(
		"Player drank water: ",
		water_drink_amount
	)


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


func restore_thirst(amount: float) -> void:
	if is_dead:
		return

	if amount <= 0.0:
		return

	current_thirst = minf(
		current_thirst + amount,
		maximum_thirst
	)

	_dehydration_damage_timer = 0.0

	_update_hud()

	print(
		"Thirst restored: ",
		amount,
		" | Thirst: ",
		current_thirst,
		" / ",
		maximum_thirst
	)


func get_health_ratio() -> float:
	if maximum_health <= 0.0:
		return 0.0

	return current_health / maximum_health


func get_hunger_ratio() -> float:
	if maximum_hunger <= 0.0:
		return 0.0

	return current_hunger / maximum_hunger


func get_thirst_ratio() -> float:
	if maximum_thirst <= 0.0:
		return 0.0

	return current_thirst / maximum_thirst


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	current_health = 0.0
	velocity = Vector3.ZERO

	_update_hud()
	health_label.text = "Gesundheit: TOT"

	print(
		"Player died. Respawn in ",
		respawn_delay,
		" seconds."
	)

	await get_tree().create_timer(
		respawn_delay
	).timeout

	_respawn_at_nest()


func _respawn_at_nest() -> void:
	var nest := get_tree().get_first_node_in_group(
		"player_nest"
	)

	if nest == null:
		push_error(
			"Respawn failed: No node in group "
			+ "'player_nest' was found."
		)
		return

	if not nest.has_method("get_respawn_position"):
		push_error(
			"Respawn failed: The nest has no "
			+ "get_respawn_position() method."
		)
		return

	var respawn_position: Vector3 = (
		nest.get_respawn_position()
	)

	global_position = respawn_position
	velocity = Vector3.ZERO

	current_health = maximum_health
	current_hunger = maximum_hunger
	current_thirst = maximum_thirst

	_starvation_damage_timer = 0.0
	_dehydration_damage_timer = 0.0
	_status_output_timer = 0.0

	is_dead = false

	_update_hud()
	_print_status()

	print(
		"Player respawned at nest: ",
		respawn_position
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
		maximum_hunger,
		" | Thirst: ",
		current_thirst,
		" / ",
		maximum_thirst
	)
