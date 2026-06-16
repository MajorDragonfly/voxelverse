extends CharacterBody3D

const STARVATION_DAMAGE_INTERVAL: float = 1.0
const DEHYDRATION_DAMAGE_INTERVAL: float = 1.0
const DEVELOPMENT_DEBUG_UPDATE_INTERVAL: float = 0.25
const SIMULATION_SPEEDS: Array[float] = [
	0.25,
	0.5,
	1.0,
	2.0,
	4.0,
	8.0,
	16.0,
]


const CREATURE_PART_VOXEL_SIZE: float = 0.22

const BODY_PARTS: Array[Dictionary] = [
	{
		"id": &"balanced_core",
		"name": "Balanced Core",
		"size": Vector3i(3, 4, 3),
		"color": Color(0.38, 0.52, 0.76, 1.0),
		"health_bonus": 0.0,
		"speed_multiplier": 1.0,
		"hunger_multiplier": 1.0,
	},
	{
		"id": &"heavy_shell",
		"name": "Heavy Shell",
		"size": Vector3i(4, 4, 4),
		"color": Color(0.44, 0.38, 0.30, 1.0),
		"health_bonus": 40.0,
		"speed_multiplier": 0.82,
		"hunger_multiplier": 1.30,
	},
	{
		"id": &"long_grazer_core",
		"name": "Long Grazer Core",
		"size": Vector3i(3, 3, 5),
		"color": Color(0.48, 0.34, 0.18, 1.0),
		"health_bonus": 15.0,
		"speed_multiplier": 1.05,
		"hunger_multiplier": 1.10,
	},
]

const LEG_PARTS: Array[Dictionary] = [
	{
		"id": &"stubby_legs",
		"name": "Stubby Legs",
		"leg_count": 4,
		"leg_height": 2,
		"leg_thickness": 1,
		"color": Color(0.23, 0.18, 0.14, 1.0),
		"speed_multiplier": 0.80,
		"jump_multiplier": 0.75,
		"hunger_multiplier": 0.90,
	},
	{
		"id": &"walker_legs",
		"name": "Walker Legs",
		"leg_count": 4,
		"leg_height": 3,
		"leg_thickness": 1,
		"color": Color(0.28, 0.20, 0.14, 1.0),
		"speed_multiplier": 1.0,
		"jump_multiplier": 1.0,
		"hunger_multiplier": 1.0,
	},
	{
		"id": &"sprinter_legs",
		"name": "Sprinter Legs",
		"leg_count": 6,
		"leg_height": 3,
		"leg_thickness": 1,
		"color": Color(0.20, 0.17, 0.13, 1.0),
		"speed_multiplier": 1.28,
		"jump_multiplier": 0.90,
		"hunger_multiplier": 1.20,
	},
]

const MOUTH_PARTS: Array[Dictionary] = [
	{
		"id": &"grazer_mouth",
		"name": "Grazer Mouth",
		"color": Color(0.18, 0.34, 0.15, 1.0),
		"size": Vector3(0.44, 0.22, 0.22),
		"hunger_multiplier": 0.90,
		"food_style": "plants",
	},
	{
		"id": &"broad_beak",
		"name": "Broad Beak",
		"color": Color(0.72, 0.55, 0.24, 1.0),
		"size": Vector3(0.52, 0.18, 0.28),
		"hunger_multiplier": 1.0,
		"food_style": "mixed",
	},
	{
		"id": &"predator_jaws",
		"name": "Predator Jaws",
		"color": Color(0.50, 0.16, 0.12, 1.0),
		"size": Vector3(0.46, 0.28, 0.30),
		"hunger_multiplier": 1.15,
		"food_style": "meat",
	},
]


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
@export_range(1.0, 1000.0, 1.0)
var maximum_health: float = 100.0

@export_range(1.0, 1000.0, 1.0)
var maximum_hunger: float = 100.0

@export_range(1.0, 1000.0, 1.0)
var maximum_thirst: float = 100.0

@export_range(0.0, 100.0, 0.1)
var hunger_loss_per_second: float = 0.2

@export_range(0.0, 100.0, 0.1)
var thirst_loss_per_second: float = 0.3

@export_range(1.0, 100.0, 1.0)
var water_drink_amount: float = 35.0

@export_range(0.0, 100.0, 0.1)
var starvation_damage_per_second: float = 5.0

@export_range(0.0, 100.0, 0.1)
var dehydration_damage_per_second: float = 7.0

@export_range(0.5, 30.0, 0.5)
var status_output_interval: float = 2.0

@export_range(0.0, 30.0, 0.5)
var respawn_delay: float = 2.0

@export_category("Development Debug")
@export var show_development_debug_overlay: bool = true
@export var enable_simulation_speed_controls: bool = true
@export_range(0, 6, 1)
var initial_simulation_speed_index: int = 2

@export_category("Creature Builder Prototype")
@export var enable_creature_builder_debug_keys: bool = true
@export_range(0, 2, 1)
var starting_body_part_index: int = 0
@export_range(0, 2, 1)
var starting_leg_part_index: int = 1
@export_range(0, 2, 1)
var starting_mouth_part_index: int = 0


var current_health: float
var current_hunger: float
var current_thirst: float
var is_dead: bool = false

var _starvation_damage_timer: float = 0.0
var _dehydration_damage_timer: float = 0.0
var _status_output_timer: float = 0.0
var _development_debug_timer: float = 0.0
var _development_debug_label: Label = null
var _simulation_speed_index: int = 2

var _base_move_speed: float = 5.0
var _base_jump_velocity: float = 6.0
var _base_maximum_health: float = 100.0
var _base_hunger_loss_per_second: float = 0.2

var _body_part_index: int = 0
var _leg_part_index: int = 1
var _mouth_part_index: int = 0
var _creature_visual_root: Node3D = null


@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

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

	_cache_base_creature_stats()
	_initialize_creature_builder()

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
	_initialize_simulation_speed()
	_initialize_development_debug_overlay()
	_update_hud()
	_update_development_debug_overlay(0.0, true)
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
	_update_development_debug_overlay(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _handle_development_debug_key(event):
		return

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
		_starvation_damage_timer -= (
			STARVATION_DAMAGE_INTERVAL
		)

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
		_dehydration_damage_timer -= (
			DEHYDRATION_DAMAGE_INTERVAL
		)

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


func _initialize_development_debug_overlay() -> void:
	if not show_development_debug_overlay:
		return

	var hud := get_node_or_null("HUD") as CanvasLayer

	if hud == null:
		push_error(
			"Development debug overlay could not be created: "
			+ "HUD was not found."
		)
		return

	_development_debug_label = Label.new()
	_development_debug_label.name = "DevelopmentDebugLabel"
	_development_debug_label.position = Vector2(8.0, 238.0)
	_development_debug_label.custom_minimum_size = (
		Vector2(660.0, 190.0)
	)
	_development_debug_label.text = "Development Debug"
	_development_debug_label.add_theme_color_override(
		"font_color",
		Color.WHITE
	)
	_development_debug_label.add_theme_color_override(
		"font_shadow_color",
		Color.BLACK
	)
	_development_debug_label.add_theme_constant_override(
		"shadow_offset_x",
		2
	)
	_development_debug_label.add_theme_constant_override(
		"shadow_offset_y",
		2
	)

	hud.add_child(_development_debug_label)


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


func _update_development_debug_overlay(
	delta: float,
	force_update: bool = false
) -> void:
	if _development_debug_label == null:
		return

	if not show_development_debug_overlay:
		_development_debug_label.visible = false
		return

	_development_debug_label.visible = true
	_development_debug_timer += delta

	if (
		not force_update
		and _development_debug_timer < DEVELOPMENT_DEBUG_UPDATE_INTERVAL
	):
		return

	_development_debug_timer = 0.0

	var world_x: float = global_position.x
	var world_z: float = global_position.z
	var logical_height: float = WorldGenerator.get_terrain_height(
		world_x,
		world_z
	)
	var visual_height: float = WorldGenerator.get_visual_terrain_height(
		world_x,
		world_z
	)
	var biome: int = WorldGenerator.get_biome(
		world_x,
		world_z,
		logical_height
	)
	var biome_name: String = WorldGenerator.get_biome_name(biome)
	var temperature: float = WorldGenerator.get_temperature(
		world_x,
		world_z
	)
	var moisture: float = WorldGenerator.get_moisture(
		world_x,
		world_z
	)
	var sea_level: float = WorldGenerator.get_sea_level()
	var distance_to_spawn: float = Vector2(
		world_x,
		world_z
	).length()

	var ecosystem_counts: Dictionary = _get_ecosystem_counts()

	var part_summary: Dictionary = _get_current_creature_part_summary()

	_development_debug_label.text = (
		"World Seed: %s | Phase: %s | Time: %sx\n"
		+ "Parts: %s | %s | %s\n"
		+ "Stats: Speed %s | Jump %s | Health %s | Hunger drain %s\n"
		+ "Biome: %s | Height: %s | Visual: %s | Sea: %s\n"
		+ "Temp: %s | Moisture: %s | Pos X/Z: %s / %s | SpawnDist: %s\n"
		+ "Grazers: %d alive / %d dead / %d total | F/M: %d/%d\n"
		+ "Grazer states: %d mature | %d ready | %d pregnant | Descendants: %d\n"
		+ "Berry bushes: %d available / %d depleted / %d total\n"
		+ "Keys: -/+ time | 0 normal | O overlay | B body | L legs | M mouth"
	) % [
		_get_world_seed_text(),
		_get_phase_text(),
		_format_float(Engine.time_scale, 0.01),
		part_summary.get("body", "Unknown Body"),
		part_summary.get("legs", "Unknown Legs"),
		part_summary.get("mouth", "Unknown Mouth"),
		_format_float(move_speed, 0.01),
		_format_float(jump_velocity, 0.01),
		_format_float(maximum_health, 0.1),
		_format_float(hunger_loss_per_second, 0.01),
		biome_name,
		_format_float(logical_height, 0.01),
		_format_float(visual_height, 0.01),
		_format_float(sea_level, 0.01),
		_format_float(temperature, 0.01),
		_format_float(moisture, 0.01),
		_format_float(world_x, 0.1),
		_format_float(world_z, 0.1),
		_format_float(distance_to_spawn, 0.1),
		ecosystem_counts.get("living_grazers", 0),
		ecosystem_counts.get("dead_grazers", 0),
		ecosystem_counts.get("total_grazers", 0),
		ecosystem_counts.get("female_grazers", 0),
		ecosystem_counts.get("male_grazers", 0),
		ecosystem_counts.get("mature_grazers", 0),
		ecosystem_counts.get("ready_grazers", 0),
		ecosystem_counts.get("pregnant_grazers", 0),
		ecosystem_counts.get("descendant_grazers", 0),
		ecosystem_counts.get("available_berry_bushes", 0),
		ecosystem_counts.get("depleted_berry_bushes", 0),
		ecosystem_counts.get("total_berry_bushes", 0)
	]


func _get_ecosystem_counts() -> Dictionary:
	var living_grazers: int = 0
	var dead_grazers: int = 0
	var total_grazers: int = 0
	var female_grazers: int = 0
	var male_grazers: int = 0
	var mature_grazers: int = 0
	var ready_grazers: int = 0
	var pregnant_grazers: int = 0
	var maximum_generation: int = 0
	var descendant_grazers: int = 0

	for grazer in get_tree().get_nodes_in_group(&"grazer"):
		if not is_instance_valid(grazer):
			continue

		total_grazers += 1

		if grazer.get("is_dead") == true:
			dead_grazers += 1
		else:
			living_grazers += 1

		if grazer.has_method("get_biological_sex"):
			var grazer_sex: int = int(
				grazer.call("get_biological_sex")
			)

			if grazer_sex == 0:
				female_grazers += 1
			elif grazer_sex == 1:
				male_grazers += 1

		if (
			grazer.has_method("is_sexually_mature")
			and bool(grazer.call("is_sexually_mature"))
		):
			mature_grazers += 1

		if (
			grazer.has_method("is_reproduction_ready")
			and bool(grazer.call("is_reproduction_ready"))
		):
			ready_grazers += 1

		if (
			grazer.has_method("is_pregnant")
			and bool(grazer.call("is_pregnant"))
		):
			pregnant_grazers += 1

		if grazer.has_method("get_genetic_generation"):
			var generation: int = int(
				grazer.call("get_genetic_generation")
			)

			maximum_generation = maxi(
				maximum_generation,
				generation
			)

			if generation > 0:
				descendant_grazers += 1

	var available_berry_bushes: int = 0
	var depleted_berry_bushes: int = 0
	var total_berry_bushes: int = 0

	for berry_bush in get_tree().get_nodes_in_group(&"berry_bush"):
		if not is_instance_valid(berry_bush):
			continue

		total_berry_bushes += 1

		if _berry_bush_has_available_food(berry_bush):
			available_berry_bushes += 1
		else:
			depleted_berry_bushes += 1

	return {
		"living_grazers": living_grazers,
		"dead_grazers": dead_grazers,
		"total_grazers": total_grazers,
		"female_grazers": female_grazers,
		"male_grazers": male_grazers,
		"mature_grazers": mature_grazers,
		"ready_grazers": ready_grazers,
		"pregnant_grazers": pregnant_grazers,
		"maximum_generation": maximum_generation,
		"descendant_grazers": descendant_grazers,
		"available_berry_bushes": available_berry_bushes,
		"depleted_berry_bushes": depleted_berry_bushes,
		"total_berry_bushes": total_berry_bushes,
	}


func _berry_bush_has_available_food(berry_bush: Node) -> bool:
	if berry_bush.has_method("has_food_available"):
		return bool(berry_bush.call("has_food_available"))

	if berry_bush.has_method("has_available_food"):
		return bool(berry_bush.call("has_available_food"))

	if berry_bush.get("is_depleted") == true:
		return false

	return true


func _get_world_seed_text() -> String:
	if GameState.has_method("get_world_seed"):
		return str(GameState.call("get_world_seed"))

	return str(GameState.world_seed)


func _get_phase_text() -> String:
	if GameState.has_method("get_phase_name"):
		return str(GameState.call("get_phase_name"))

	return "Unknown"


func _format_float(value: float, step: float) -> String:
	return str(snappedf(value, step))


func _cache_base_creature_stats() -> void:
	_base_move_speed = move_speed
	_base_jump_velocity = jump_velocity
	_base_maximum_health = maximum_health
	_base_hunger_loss_per_second = hunger_loss_per_second


func _initialize_creature_builder() -> void:
	_body_part_index = clampi(
		starting_body_part_index,
		0,
		BODY_PARTS.size() - 1
	)
	_leg_part_index = clampi(
		starting_leg_part_index,
		0,
		LEG_PARTS.size() - 1
	)
	_mouth_part_index = clampi(
		starting_mouth_part_index,
		0,
		MOUTH_PARTS.size() - 1
	)

	if body_mesh != null:
		body_mesh.visible = false

	_creature_visual_root = Node3D.new()
	_creature_visual_root.name = "CreaturePartVisuals"
	add_child(_creature_visual_root)

	_apply_creature_part_blueprint(false)


func _apply_creature_part_blueprint(
	preserve_current_values: bool = true
) -> void:
	var health_ratio: float = 1.0
	var hunger_ratio: float = 1.0
	var thirst_ratio: float = 1.0

	if preserve_current_values:
		health_ratio = get_health_ratio()
		hunger_ratio = get_hunger_ratio()
		thirst_ratio = get_thirst_ratio()

	var body_part: Dictionary = BODY_PARTS[_body_part_index]
	var leg_part: Dictionary = LEG_PARTS[_leg_part_index]
	var mouth_part: Dictionary = MOUTH_PARTS[_mouth_part_index]

	var body_speed_multiplier: float = float(
		body_part.get("speed_multiplier", 1.0)
	)
	var leg_speed_multiplier: float = float(
		leg_part.get("speed_multiplier", 1.0)
	)
	var leg_jump_multiplier: float = float(
		leg_part.get("jump_multiplier", 1.0)
	)
	var body_hunger_multiplier: float = float(
		body_part.get("hunger_multiplier", 1.0)
	)
	var leg_hunger_multiplier: float = float(
		leg_part.get("hunger_multiplier", 1.0)
	)
	var mouth_hunger_multiplier: float = float(
		mouth_part.get("hunger_multiplier", 1.0)
	)
	var health_bonus: float = float(
		body_part.get("health_bonus", 0.0)
	)

	move_speed = (
		_base_move_speed
		* body_speed_multiplier
		* leg_speed_multiplier
	)
	jump_velocity = _base_jump_velocity * leg_jump_multiplier
	maximum_health = _base_maximum_health + health_bonus
	hunger_loss_per_second = (
		_base_hunger_loss_per_second
		* body_hunger_multiplier
		* leg_hunger_multiplier
		* mouth_hunger_multiplier
	)

	if preserve_current_values:
		current_health = clampf(
			maximum_health * health_ratio,
			0.0,
			maximum_health
		)
		current_hunger = clampf(
			maximum_hunger * hunger_ratio,
			0.0,
			maximum_hunger
		)
		current_thirst = clampf(
			maximum_thirst * thirst_ratio,
			0.0,
			maximum_thirst
		)

	_rebuild_creature_part_visuals()
	_update_hud()
	_update_development_debug_overlay(0.0, true)

	print(
		"Creature parts changed: ",
		body_part.get("name", "Unknown Body"),
		" | ",
		leg_part.get("name", "Unknown Legs"),
		" | ",
		mouth_part.get("name", "Unknown Mouth")
	)


func _rebuild_creature_part_visuals() -> void:
	if _creature_visual_root == null:
		return

	for child in _creature_visual_root.get_children():
		child.queue_free()

	var body_part: Dictionary = BODY_PARTS[_body_part_index]
	var leg_part: Dictionary = LEG_PARTS[_leg_part_index]
	var mouth_part: Dictionary = MOUTH_PARTS[_mouth_part_index]

	var body_size: Vector3i = body_part.get(
		"size",
		Vector3i(3, 4, 3)
	)
	var leg_height_voxels: int = int(
		leg_part.get("leg_height", 3)
	)
	var leg_thickness_voxels: int = int(
		leg_part.get("leg_thickness", 1)
	)

	var voxel: float = CREATURE_PART_VOXEL_SIZE
	var body_dimensions := Vector3(
		float(body_size.x) * voxel,
		float(body_size.y) * voxel,
		float(body_size.z) * voxel
	)
	var leg_height: float = float(leg_height_voxels) * voxel
	var body_center_y: float = leg_height + body_dimensions.y * 0.5

	_add_visual_box(
		"BodyCore",
		Vector3(0.0, body_center_y, 0.0),
		body_dimensions,
		body_part.get("color", Color.WHITE)
	)

	_add_leg_visuals(
		body_size,
		leg_part,
		body_center_y,
		body_dimensions
	)

	_add_mouth_visual(
		body_size,
		mouth_part,
		body_center_y,
		body_dimensions
	)

	_add_eye_visuals(
		body_size,
		body_center_y,
		body_dimensions
	)


func _add_leg_visuals(
	body_size: Vector3i,
	leg_part: Dictionary,
	body_center_y: float,
	body_dimensions: Vector3
) -> void:
	var leg_count: int = int(leg_part.get("leg_count", 4))
	var leg_height_voxels: int = int(leg_part.get("leg_height", 3))
	var leg_thickness_voxels: int = int(
		leg_part.get("leg_thickness", 1)
	)
	var voxel: float = CREATURE_PART_VOXEL_SIZE
	var leg_dimensions := Vector3(
		float(leg_thickness_voxels) * voxel,
		float(leg_height_voxels) * voxel,
		float(leg_thickness_voxels) * voxel
	)
	var leg_y: float = leg_dimensions.y * 0.5
	var x_offset: float = maxf(
		body_dimensions.x * 0.35,
		voxel * 0.75
	)
	var z_front: float = -body_dimensions.z * 0.28
	var z_back: float = body_dimensions.z * 0.28

	var leg_positions: Array[Vector3] = [
		Vector3(-x_offset, leg_y, z_front),
		Vector3(x_offset, leg_y, z_front),
		Vector3(-x_offset, leg_y, z_back),
		Vector3(x_offset, leg_y, z_back),
	]

	if leg_count >= 6:
		leg_positions.append(Vector3(-x_offset, leg_y, 0.0))
		leg_positions.append(Vector3(x_offset, leg_y, 0.0))

	for leg_index in range(mini(leg_count, leg_positions.size())):
		_add_visual_box(
			"Leg%d" % leg_index,
			leg_positions[leg_index],
			leg_dimensions,
			leg_part.get("color", Color.WHITE)
		)


func _add_mouth_visual(
	body_size: Vector3i,
	mouth_part: Dictionary,
	body_center_y: float,
	body_dimensions: Vector3
) -> void:
	var mouth_size: Vector3 = mouth_part.get(
		"size",
		Vector3(0.44, 0.22, 0.22)
	)
	var mouth_position := Vector3(
		0.0,
		body_center_y + body_dimensions.y * 0.10,
		-body_dimensions.z * 0.5 - mouth_size.z * 0.5
	)

	_add_visual_box(
		"MouthPart",
		mouth_position,
		mouth_size,
		mouth_part.get("color", Color.WHITE)
	)


func _add_eye_visuals(
	body_size: Vector3i,
	body_center_y: float,
	body_dimensions: Vector3
) -> void:
	var eye_size := Vector3(0.07, 0.07, 0.04)
	var eye_y: float = body_center_y + body_dimensions.y * 0.23
	var eye_z: float = -body_dimensions.z * 0.5 - 0.025
	var eye_x: float = body_dimensions.x * 0.22

	_add_visual_box(
		"LeftEye",
		Vector3(-eye_x, eye_y, eye_z),
		eye_size,
		Color(0.03, 0.03, 0.025, 1.0)
	)
	_add_visual_box(
		"RightEye",
		Vector3(eye_x, eye_y, eye_z),
		eye_size,
		Color(0.03, 0.03, 0.025, 1.0)
	)


func _add_visual_box(
	box_name: String,
	local_position: Vector3,
	box_size: Vector3,
	box_color: Color
) -> void:
	if _creature_visual_root == null:
		return

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = box_name

	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = local_position

	var material := StandardMaterial3D.new()
	material.albedo_color = box_color
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_BACK
	mesh_instance.material_override = material

	_creature_visual_root.add_child(mesh_instance)


func _cycle_body_part() -> void:
	if not enable_creature_builder_debug_keys:
		return

	_body_part_index = (_body_part_index + 1) % BODY_PARTS.size()
	_apply_creature_part_blueprint()


func _cycle_leg_part() -> void:
	if not enable_creature_builder_debug_keys:
		return

	_leg_part_index = (_leg_part_index + 1) % LEG_PARTS.size()
	_apply_creature_part_blueprint()


func _cycle_mouth_part() -> void:
	if not enable_creature_builder_debug_keys:
		return

	_mouth_part_index = (_mouth_part_index + 1) % MOUTH_PARTS.size()
	_apply_creature_part_blueprint()


func _get_current_creature_part_summary() -> Dictionary:
	return {
		"body": str(BODY_PARTS[_body_part_index].get("name", "Body")),
		"legs": str(LEG_PARTS[_leg_part_index].get("name", "Legs")),
		"mouth": str(MOUTH_PARTS[_mouth_part_index].get("name", "Mouth")),
	}


func _initialize_simulation_speed() -> void:
	_simulation_speed_index = clampi(
		initial_simulation_speed_index,
		0,
		SIMULATION_SPEEDS.size() - 1
	)
	_apply_simulation_speed(false)


func _handle_development_debug_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event := event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return false

	match key_event.keycode:
		KEY_MINUS, KEY_KP_SUBTRACT:
			_decrease_simulation_speed()
			return true
		KEY_EQUAL, KEY_KP_ADD:
			_increase_simulation_speed()
			return true
		KEY_0, KEY_KP_0:
			_set_simulation_speed_index(2)
			return true
		KEY_O:
			_toggle_development_debug_overlay()
			return true
		KEY_B:
			_cycle_body_part()
			return true
		KEY_L:
			_cycle_leg_part()
			return true
		KEY_M:
			_cycle_mouth_part()
			return true
		_:
			return false


func _increase_simulation_speed() -> void:
	if not enable_simulation_speed_controls:
		return

	_set_simulation_speed_index(_simulation_speed_index + 1)


func _decrease_simulation_speed() -> void:
	if not enable_simulation_speed_controls:
		return

	_set_simulation_speed_index(_simulation_speed_index - 1)


func _set_simulation_speed_index(new_index: int) -> void:
	if not enable_simulation_speed_controls:
		return

	_simulation_speed_index = clampi(
		new_index,
		0,
		SIMULATION_SPEEDS.size() - 1
	)
	_apply_simulation_speed(true)


func _apply_simulation_speed(announce_change: bool) -> void:
	Engine.time_scale = SIMULATION_SPEEDS[_simulation_speed_index]

	if announce_change:
		print("Simulation speed changed to: ", Engine.time_scale, "x")

	_update_development_debug_overlay(0.0, true)


func _toggle_development_debug_overlay() -> void:
	show_development_debug_overlay = not show_development_debug_overlay

	if _development_debug_label != null:
		_development_debug_label.visible = show_development_debug_overlay

	print("Development debug overlay visible: ", show_development_debug_overlay)


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
	_development_debug_timer = 0.0
	is_dead = false

	_update_hud()
	_update_development_debug_overlay(0.0, true)
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
