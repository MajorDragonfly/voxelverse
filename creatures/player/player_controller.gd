extends CharacterBody3D
class_name PlayerController

signal died
signal respawned
signal gameplay_message(text: String)
signal creature_attacked(target: Node, damage: float)

const STARVATION_DAMAGE_INTERVAL: float = 1.0
const DEHYDRATION_DAMAGE_INTERVAL: float = 1.0

@export_category("Movement")
@export var move_speed: float = 5.0
@export var jump_velocity: float = 6.0
@export var fall_acceleration: float = 20.0
@export_range(0.10, 1.20, 0.05) var maximum_step_height: float = 0.58
@export_range(0.02, 0.30, 0.01) var step_floor_probe: float = 0.10

@export_category("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var minimum_camera_angle: float = -60.0
@export var maximum_camera_angle: float = 35.0

@export_category("Interaction")
@export var interaction_range: float = 3.2
@export_range(0.2, 3.0, 0.05) var bite_cooldown: float = 0.68
@export_range(0.5, 20.0, 0.5) var bite_damage_scale: float = 8.0

@export_category("Creature Stats")
@export_range(0.0, 100.0, 0.1) var attack_power: float = 1.0
@export_range(0.0, 100.0, 0.1) var defense_rating: float = 1.0
@export_range(0.0, 100.0, 0.1) var diet_plant: float = 0.0
@export_range(0.0, 100.0, 0.1) var diet_meat: float = 0.0

@export_category("Survival")
@export_range(1.0, 1000.0, 1.0) var maximum_health: float = 100.0
@export_range(1.0, 1000.0, 1.0) var maximum_hunger: float = 100.0
@export_range(1.0, 1000.0, 1.0) var maximum_thirst: float = 100.0
@export_range(0.0, 100.0, 0.01) var hunger_loss_per_second: float = 0.2
@export_range(0.0, 100.0, 0.01) var thirst_loss_per_second: float = 0.3
@export_range(1.0, 100.0, 1.0) var water_drink_amount: float = 35.0
@export_range(0.0, 100.0, 0.1) var starvation_damage_per_second: float = 5.0
@export_range(0.0, 100.0, 0.1) var dehydration_damage_per_second: float = 7.0
@export_range(0.0, 30.0, 0.5) var respawn_delay: float = 2.0

var current_health: float = 100.0
var current_hunger: float = 100.0
var current_thirst: float = 100.0
var is_dead: bool = false
var is_swimming: bool = false

var _starvation_damage_timer: float = 0.0
var _dehydration_damage_timer: float = 0.0
var _bite_cooldown_timer: float = 0.0
var _message_label: Label
var _message_timer: float = 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var interaction_ray: RayCast3D = $CameraPivot/SpringArm3D/Camera3D/InteractionRay
@onready var health_label: Label = $HUD/StatusContainer/HealthLabel
@onready var health_bar: ProgressBar = $HUD/StatusContainer/HealthBar
@onready var hunger_label: Label = $HUD/StatusContainer/HungerLabel
@onready var hunger_bar: ProgressBar = $HUD/StatusContainer/HungerBar
@onready var thirst_label: Label = $HUD/StatusContainer/ThirstLabel
@onready var thirst_bar: ProgressBar = $HUD/StatusContainer/ThirstBar
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	add_to_group(&"player")
	floor_snap_length = maximum_step_height + 0.12
	floor_max_angle = deg_to_rad(52.0)
	floor_stop_on_slope = true
	floor_constant_speed = true
	current_health = maximum_health
	current_hunger = maximum_hunger
	current_thirst = maximum_thirst
	spring_arm.add_excluded_object(get_rid())
	interaction_ray.add_exception(self)
	interaction_ray.target_position = Vector3(0.0, 0.0, -maxf(interaction_range, 0.1))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_initialize_hud()
	_create_message_label()
	_update_hud()
	var behavior := preload("res://creatures/behavior/player_behavior_controller.gd").new()
	behavior.name = "BehaviorController"
	add_child(behavior)


func _process(delta: float) -> void:
	_bite_cooldown_timer = maxf(_bite_cooldown_timer - delta, 0.0)
	if not is_dead:
		_update_survival(delta)
	_update_message(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotation.x -= event.screen_relative.y * mouse_sensitivity
		camera_pivot.rotation.y -= event.screen_relative.x * mouse_sensitivity
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x,
			deg_to_rad(minimum_camera_angle),
			deg_to_rad(maximum_camera_angle)
		)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
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
	var direction: Vector3 = camera_right * input_vector.x + camera_forward * -input_vector.y
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	var grounded_before_move: bool = is_on_floor()
	_update_water_movement(delta)
	if is_swimming:
		velocity.x *= 0.62
		velocity.z *= 0.62
	elif grounded_before_move:
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= fall_acceleration * delta

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_just_pressed("primary_action"):
			_try_primary_action()
		if Input.is_action_just_pressed("bite_action"):
			_try_bite_action()
	if grounded_before_move and velocity.y <= 0.0 and not is_swimming:
		_attempt_step_up(delta)
	move_and_slide()
	if is_on_floor() and not is_swimming:
		apply_floor_snap()


func _update_water_movement(delta: float) -> void:
	var water: float = WorldGenerator.get_water_level(global_position.x, global_position.z)
	var depth: float = water - WorldGenerator.get_terrain_height(global_position.x, global_position.z)
	var immersion: float = water - global_position.y
	is_swimming = depth > 1.1 and immersion > (0.15 if is_swimming else 0.45)
	floor_snap_length = 0.0 if is_swimming else maximum_step_height + 0.12
	if not is_swimming:
		return
	# Damped buoyancy works at elevated lakes as well as sea level. Keep normal
	# collision so shore steps, rocks and buildings still block the creature.
	var acceleration: float = clampf((immersion - 0.65) * 12.0 - velocity.y * 5.0, -fall_acceleration, fall_acceleration)
	velocity.y = clampf(velocity.y + acceleration * delta, -3.5, 3.5)
	if Input.is_action_just_pressed("jump"):
		velocity.y = 3.5


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


func _process_dead_movement(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= fall_acceleration * delta
	move_and_slide()


func _update_survival(delta: float) -> void:
	current_hunger = maxf(current_hunger - hunger_loss_per_second * delta, 0.0)
	current_thirst = maxf(current_thirst - thirst_loss_per_second * delta, 0.0)
	if current_hunger <= 0.0:
		_starvation_damage_timer += delta
		while _starvation_damage_timer >= STARVATION_DAMAGE_INTERVAL:
			_starvation_damage_timer -= STARVATION_DAMAGE_INTERVAL
			receive_damage(starvation_damage_per_second * STARVATION_DAMAGE_INTERVAL)
			if is_dead:
				return
	else:
		_starvation_damage_timer = 0.0
	if current_thirst <= 0.0:
		_dehydration_damage_timer += delta
		while _dehydration_damage_timer >= DEHYDRATION_DAMAGE_INTERVAL:
			_dehydration_damage_timer -= DEHYDRATION_DAMAGE_INTERVAL
			receive_damage(dehydration_damage_per_second * DEHYDRATION_DAMAGE_INTERVAL)
			if is_dead:
				return
	else:
		_dehydration_damage_timer = 0.0
	_update_hud()


func _try_primary_action() -> void:
	if is_swimming:
		_try_drink_water()
		return
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return
	var collision_point: Vector3 = interaction_ray.get_collision_point()
	if global_position.distance_to(collision_point) > interaction_range:
		return
	if WorldGenerator.is_water_at(collision_point.x, collision_point.z):
		_try_drink_water()
		return
	var collider: Object = interaction_ray.get_collider()
	if collider != null and collider.has_method("interact"):
		collider.call("interact", self)


func _try_bite_action() -> void:
	if _bite_cooldown_timer > 0.0:
		return
	if not can_perform_action(&"bite"):
		show_gameplay_message("Bite is not available in this phase.")
		return
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		show_gameplay_message("Nothing in bite range.", 1.2)
		return
	var collision_point: Vector3 = interaction_ray.get_collision_point()
	if global_position.distance_to(collision_point) > interaction_range:
		show_gameplay_message("Target is too far away.", 1.2)
		return
	var collider := interaction_ray.get_collider() as Node
	if collider == null or not collider.has_method("receive_creature_attack"):
		show_gameplay_message("That cannot be bitten.", 1.2)
		return
	_bite_cooldown_timer = bite_cooldown
	var damage: float = clampf(attack_power * bite_damage_scale, 2.0, 80.0)
	collider.call("receive_creature_attack", damage, self)
	creature_attacked.emit(collider, damage)


func _try_drink_water() -> void:
	if not can_perform_action(&"drink"):
		show_gameplay_message("You cannot drink yet.")
		return
	if current_thirst >= maximum_thirst - 0.01:
		show_gameplay_message("Not thirsty.")
		return
	restore_thirst(water_drink_amount)
	show_gameplay_message("Drank water.")


func can_perform_action(action: StringName) -> bool:
	return GameState.has_ability(action)


func get_behavior_multiplier(effect_id: String) -> float:
	return float(ProgressionService.get_behavior_effect(effect_id, GameState.current_phase).get("value", 1.0))


func get_bite_damage() -> float:
	# Body attack remains the raw source; purchased effects are never baked into it.
	return clampf(attack_power * bite_damage_scale, 2.0, 80.0) * get_behavior_multiplier("attack_efficiency")


func receive_damage(damage: float) -> void:
	if is_dead or damage <= 0.0:
		return
	var mitigation: float = 1.0 + maxf(defense_rating, 0.0) * 0.12
	var effective_damage: float = maxf(damage / mitigation, damage * 0.25)
	current_health = maxf(current_health - effective_damage, 0.0)
	_update_hud()
	if current_health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = minf(current_health + amount, maximum_health)
	_update_hud()


func restore_hunger(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_hunger = minf(current_hunger + amount, maximum_hunger)
	_starvation_damage_timer = 0.0
	_update_hud()


func restore_thirst(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_thirst = minf(current_thirst + amount, maximum_thirst)
	_dehydration_damage_timer = 0.0
	_update_hud()


func consume_food(food_type: String, base_nutrition: float) -> bool:
	if is_dead or base_nutrition <= 0.0:
		return false
	var affinity: float = get_diet_affinity(food_type)
	if affinity <= 0.05:
		show_gameplay_message("Your mouth cannot digest this food well.")
		return false
	if current_hunger >= maximum_hunger - 0.01:
		show_gameplay_message("Not hungry.")
		return false
	var efficiency: float = clampf(0.35 + affinity * 0.25, 0.35, 1.25)
	var nutrition: float = base_nutrition * efficiency
	restore_hunger(nutrition)
	if affinity >= 2.0:
		heal(base_nutrition * 0.04)
	show_gameplay_message(
		"Ate %s food · +%d hunger" % [food_type, roundi(nutrition)]
	)
	return true


func get_diet_affinity(food_type: String) -> float:
	match food_type:
		"plant": return maxf(diet_plant, 0.0)
		"meat": return maxf(diet_meat, 0.0)
		_: return 0.0


func get_health_ratio() -> float:
	return current_health / maxf(maximum_health, 0.001)


func get_hunger_ratio() -> float:
	return current_hunger / maxf(maximum_hunger, 0.001)


func get_thirst_ratio() -> float:
	return current_thirst / maxf(maximum_thirst, 0.001)


func show_gameplay_message(text: String, duration: float = 3.0) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_label.visible = true
	_message_timer = maxf(duration, 0.2)
	gameplay_message.emit(text)


func export_runtime_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"camera_yaw": camera_pivot.rotation.y,
		"camera_pitch": camera_pivot.rotation.x,
		"health_ratio": get_health_ratio(),
		"hunger_ratio": get_hunger_ratio(),
		"thirst_ratio": get_thirst_ratio(),
		"behavior_runtime": get_node("BehaviorController").export_state(),
	}


func import_runtime_state(data: Dictionary) -> void:
	var position_value: Variant = data.get("position", [])
	if position_value is Array and position_value.size() >= 3:
		global_position = Vector3(
			float(position_value[0]),
			float(position_value[1]),
			float(position_value[2])
		)
	rotation.y = float(data.get("yaw", rotation.y))
	camera_pivot.rotation.y = float(data.get("camera_yaw", camera_pivot.rotation.y))
	camera_pivot.rotation.x = clampf(
		float(data.get("camera_pitch", camera_pivot.rotation.x)),
		deg_to_rad(minimum_camera_angle),
		deg_to_rad(maximum_camera_angle)
	)
	current_health = maximum_health * clampf(float(data.get("health_ratio", 1.0)), 0.0, 1.0)
	current_hunger = maximum_hunger * clampf(float(data.get("hunger_ratio", 1.0)), 0.0, 1.0)
	current_thirst = maximum_thirst * clampf(float(data.get("thirst_ratio", 1.0)), 0.0, 1.0)
	velocity = Vector3.ZERO
	is_dead = false
	get_node("BehaviorController").import_state(data.get("behavior_runtime", {}))
	_update_hud()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	current_health = 0.0
	velocity = Vector3.ZERO
	_update_hud()
	show_gameplay_message("You died.", respawn_delay)
	died.emit()
	await get_tree().create_timer(respawn_delay).timeout
	_respawn_at_nest()


func _respawn_at_nest() -> void:
	var nest := get_tree().get_first_node_in_group(&"player_nest")
	if nest == null or not nest.has_method("get_respawn_position"):
		push_error("Respawn failed: player nest is unavailable.")
		return
	global_position = nest.call("get_respawn_position")
	velocity = Vector3.ZERO
	current_health = maximum_health
	current_hunger = maximum_hunger
	current_thirst = maximum_thirst
	_starvation_damage_timer = 0.0
	_dehydration_damage_timer = 0.0
	is_dead = false
	_update_hud()
	show_gameplay_message("Respawned at the nest.")
	respawned.emit()
	var save_service := get_node_or_null("/root/SaveGameService")
	if save_service != null and save_service.has_method("save_now"):
		save_service.call_deferred("save_now")


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
	if health_bar == null:
		return
	health_bar.max_value = maximum_health
	health_bar.value = current_health
	hunger_bar.max_value = maximum_hunger
	hunger_bar.value = current_hunger
	thirst_bar.max_value = maximum_thirst
	thirst_bar.value = current_thirst
	health_label.text = "Health: %d / %d" % [roundi(current_health), roundi(maximum_health)]
	hunger_label.text = "Hunger: %d / %d" % [roundi(current_hunger), roundi(maximum_hunger)]
	thirst_label.text = "Thirst: %d / %d" % [roundi(current_thirst), roundi(maximum_thirst)]


func _create_message_label() -> void:
	_message_label = Label.new()
	_message_label.name = "GameplayMessage"
	_message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message_label.offset_left = -320.0
	_message_label.offset_top = 52.0
	_message_label.offset_right = 320.0
	_message_label.offset_bottom = 92.0
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.add_theme_font_size_override("font_size", 18)
	_message_label.add_theme_color_override("font_color", Color(0.84, 0.95, 0.91, 1.0))
	_message_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_message_label.add_theme_constant_override("shadow_offset_x", 2)
	_message_label.add_theme_constant_override("shadow_offset_y", 2)
	_message_label.visible = false
	hud.add_child(_message_label)


func _update_message(delta: float) -> void:
	if _message_label == null or not _message_label.visible:
		return
	_message_timer -= delta
	if _message_timer <= 0.0:
		_message_label.visible = false
