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

const EYE_PARTS: Array[Dictionary] = [
	{
		"id": &"small_black_eyes",
		"name": "Small Black Eyes",
		"color": Color(0.03, 0.03, 0.025, 1.0),
		"size": Vector3(0.07, 0.07, 0.04),
		"sight_bonus": 0.0,
		"complexity": 4.0,
	},
	{
		"id": &"wide_forager_eyes",
		"name": "Wide Forager Eyes",
		"color": Color(0.06, 0.09, 0.05, 1.0),
		"size": Vector3(0.10, 0.09, 0.045),
		"sight_bonus": 0.12,
		"complexity": 6.0,
	},
	{
		"id": &"stalk_eyes",
		"name": "Stalk Eyes",
		"color": Color(0.02, 0.025, 0.02, 1.0),
		"size": Vector3(0.08, 0.11, 0.045),
		"sight_bonus": 0.20,
		"complexity": 8.0,
	},
]


const ARM_PARTS: Array[Dictionary] = [
	{
		"id": &"no_arms",
		"name": "No Arms",
		"color": Color(0.0, 0.0, 0.0, 0.0),
		"size": Vector3.ZERO,
		"speed_multiplier": 1.0,
		"hunger_multiplier": 1.0,
		"complexity": 0.0,
	},
	{
		"id": &"grasping_arms",
		"name": "Grasping Arms",
		"color": Color(0.32, 0.24, 0.17, 1.0),
		"upper_size": Vector3(0.16, 0.42, 0.16),
		"hand_size": Vector3(0.22, 0.16, 0.20),
		"speed_multiplier": 0.96,
		"hunger_multiplier": 1.10,
		"complexity": 12.0,
	},
	{
		"id": &"climber_arms",
		"name": "Climber Arms",
		"color": Color(0.22, 0.18, 0.13, 1.0),
		"upper_size": Vector3(0.18, 0.50, 0.18),
		"hand_size": Vector3(0.26, 0.18, 0.22),
		"speed_multiplier": 0.92,
		"hunger_multiplier": 1.16,
		"complexity": 16.0,
	},
]

const TAIL_PARTS: Array[Dictionary] = [
	{
		"id": &"no_tail",
		"name": "No Tail",
		"color": Color(0.0, 0.0, 0.0, 0.0),
		"size": Vector3.ZERO,
		"speed_multiplier": 1.0,
		"jump_multiplier": 1.0,
		"hunger_multiplier": 1.0,
		"complexity": 0.0,
	},
	{
		"id": &"balance_tail",
		"name": "Balance Tail",
		"color": Color(0.30, 0.22, 0.15, 1.0),
		"size": Vector3(0.24, 0.22, 0.72),
		"speed_multiplier": 1.04,
		"jump_multiplier": 1.08,
		"hunger_multiplier": 1.06,
		"complexity": 9.0,
	},
	{
		"id": &"club_tail",
		"name": "Club Tail",
		"color": Color(0.27, 0.21, 0.17, 1.0),
		"size": Vector3(0.28, 0.26, 0.82),
		"club_size": Vector3(0.40, 0.34, 0.34),
		"speed_multiplier": 0.94,
		"jump_multiplier": 0.96,
		"hunger_multiplier": 1.12,
		"complexity": 14.0,
	},
]

const HORN_PARTS: Array[Dictionary] = [
	{
		"id": &"no_horns",
		"name": "No Horns",
		"color": Color(0.0, 0.0, 0.0, 0.0),
		"size": Vector3.ZERO,
		"health_bonus": 0.0,
		"hunger_multiplier": 1.0,
		"complexity": 0.0,
	},
	{
		"id": &"small_horns",
		"name": "Small Horns",
		"color": Color(0.78, 0.72, 0.55, 1.0),
		"size": Vector3(0.12, 0.26, 0.12),
		"health_bonus": 5.0,
		"hunger_multiplier": 1.04,
		"complexity": 8.0,
	},
	{
		"id": &"crest_horns",
		"name": "Crest Horns",
		"color": Color(0.72, 0.64, 0.42, 1.0),
		"size": Vector3(0.14, 0.34, 0.14),
		"health_bonus": 10.0,
		"hunger_multiplier": 1.08,
		"complexity": 12.0,
	},
]

const PAINT_PARTS: Array[Dictionary] = [
	{
		"id": &"plain_skin",
		"name": "Plain Skin",
		"tint": Color.WHITE,
		"pattern": "none",
		"pattern_color": Color.WHITE,
		"complexity": 0.0,
	},
	{
		"id": &"forest_spots",
		"name": "Forest Spots",
		"tint": Color(0.88, 1.0, 0.82, 1.0),
		"pattern": "spots",
		"pattern_color": Color(0.12, 0.32, 0.09, 1.0),
		"complexity": 6.0,
	},
	{
		"id": &"sand_stripes",
		"name": "Sand Stripes",
		"tint": Color(1.0, 0.92, 0.70, 1.0),
		"pattern": "stripes",
		"pattern_color": Color(0.48, 0.35, 0.18, 1.0),
		"complexity": 7.0,
	},
	{
		"id": &"warning_marks",
		"name": "Warning Marks",
		"tint": Color(1.0, 0.92, 0.86, 1.0),
		"pattern": "marks",
		"pattern_color": Color(0.75, 0.08, 0.05, 1.0),
		"complexity": 9.0,
	},
]

const BUILDER_SLOT_BODY: int = 0
const BUILDER_SLOT_LEGS: int = 1
const BUILDER_SLOT_MOUTH: int = 2
const BUILDER_SLOT_EYES: int = 3
const BUILDER_SLOT_ARMS: int = 4
const BUILDER_SLOT_TAIL: int = 5
const BUILDER_SLOT_HORNS: int = 6
const BUILDER_SLOT_PAINT: int = 7

const BUILDER_SLOT_NAMES: Array[String] = [
	"Body",
	"Legs",
	"Mouth",
	"Eyes",
	"Arms",
	"Tail",
	"Horns",
	"Paint",
]

const BUILDER_PART_SCALE_STEP: float = 0.10
const BUILDER_PART_MOVE_STEP: float = 0.06
const BUILDER_PART_ROTATE_STEP: float = 15.0
const BODY_SHAPE_STEP: float = 0.10

const MIN_BODY_SHAPE_SCALE: float = 0.65
const MAX_BODY_SHAPE_SCALE: float = 1.70
const MIN_PART_SCALE: float = 0.55
const MAX_PART_SCALE: float = 1.85
const MIN_LEG_SPREAD_SCALE: float = 0.55
const MAX_LEG_SPREAD_SCALE: float = 1.65

const MAX_CREATURE_COMPLEXITY: float = 120.0
const CREATURE_BUILD_SAVE_PATH: String = "user://player_creature_build.json"



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
@export_range(0, 2, 1)
var starting_eye_part_index: int = 0
@export_range(0, 2, 1)
var starting_arm_part_index: int = 0
@export_range(0, 2, 1)
var starting_tail_part_index: int = 0
@export_range(0, 2, 1)
var starting_horn_part_index: int = 0
@export_range(0, 3, 1)
var starting_paint_part_index: int = 0


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
var _eye_part_index: int = 0
var _arm_part_index: int = 0
var _tail_part_index: int = 0
var _horn_part_index: int = 0
var _paint_part_index: int = 0

var _builder_mode_enabled: bool = false
var _builder_slot_index: int = BUILDER_SLOT_BODY

var _body_width_scale: float = 1.0
var _body_height_scale: float = 1.0
var _body_length_scale: float = 1.0

var _leg_scale: float = 1.0
var _leg_spread_scale: float = 1.0
var _leg_position_offset_z: float = 0.0

var _mouth_scale: float = 1.0
var _mouth_position_offset: Vector3 = Vector3.ZERO
var _mouth_rotation_y: float = 0.0

var _eye_scale: float = 1.0
var _eye_position_offset: Vector3 = Vector3.ZERO
var _eye_spread_scale: float = 1.0
var _eye_rotation_y: float = 0.0

var _arm_scale: float = 1.0
var _arm_position_offset: Vector3 = Vector3.ZERO
var _arm_spread_scale: float = 1.0
var _arm_rotation_y: float = 0.0

var _tail_scale: float = 1.0
var _tail_position_offset: Vector3 = Vector3.ZERO
var _tail_rotation_y: float = 0.0

var _horn_scale: float = 1.0
var _horn_position_offset: Vector3 = Vector3.ZERO
var _horn_spread_scale: float = 1.0
var _horn_rotation_y: float = 0.0

var _paint_intensity: float = 1.0

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
	if _handle_creature_builder_key(event):
		return

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
		Vector2(760.0, 230.0)
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
	var builder_state: String = "ON" if _builder_mode_enabled else "OFF"

	_development_debug_label.text = (
		"World Seed: %s | Phase: %s | Time: %sx\n"
		+ "Builder: %s | Slot: %s | Part: %s | Complexity: %s / %s\n"
		+ "Body Shape: %s | Transform: %s\n"
		+ "Core: %s | Legs: %s | Mouth: %s | Eyes: %s\n"
		+ "Arms: %s | Tail: %s | Horns: %s | Paint: %s\n"
		+ "Stats: Speed %s | Jump %s | Health %s | Hunger drain %s\n"
		+ "Biome: %s | Height: %s | Visual: %s | Sea: %s\n"
		+ "Temp: %s | Moisture: %s | Pos X/Z: %s / %s | SpawnDist: %s\n"
		+ "Grazers: %d alive / %d dead / %d total | Bushes: %d available / %d depleted / %d total\n"
		+ "Keys: C builder | Tab slot | Q/E part | ,/. scale | Arrows move/shape | PgUp/PgDn height | R rotate | X reset\n"
		+ "Save: Ctrl+S | Load: Ctrl+L | Reset build: Ctrl+R | Quick: B/L/M/N/I/T/H/P"
	) % [
		_get_world_seed_text(),
		_get_phase_text(),
		_format_float(Engine.time_scale, 0.01),
		builder_state,
		part_summary.get("selected_slot", "Body"),
		part_summary.get("selected_part", "Unknown"),
		_format_float(float(part_summary.get("complexity", 0.0)), 0.1),
		_format_float(MAX_CREATURE_COMPLEXITY, 0.1),
		part_summary.get("body_shape", "-"),
		part_summary.get("selected_transform", "-"),
		part_summary.get("body", "Unknown Body"),
		part_summary.get("legs", "Unknown Legs"),
		part_summary.get("mouth", "Unknown Mouth"),
		part_summary.get("eyes", "Unknown Eyes"),
		part_summary.get("arms", "Unknown Arms"),
		part_summary.get("tail", "Unknown Tail"),
		part_summary.get("horns", "Unknown Horns"),
		part_summary.get("paint", "Unknown Paint"),
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
	_eye_part_index = clampi(
		starting_eye_part_index,
		0,
		EYE_PARTS.size() - 1
	)
	_arm_part_index = clampi(
		starting_arm_part_index,
		0,
		ARM_PARTS.size() - 1
	)
	_tail_part_index = clampi(
		starting_tail_part_index,
		0,
		TAIL_PARTS.size() - 1
	)
	_horn_part_index = clampi(
		starting_horn_part_index,
		0,
		HORN_PARTS.size() - 1
	)
	_paint_part_index = clampi(
		starting_paint_part_index,
		0,
		PAINT_PARTS.size() - 1
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
	var arm_part: Dictionary = ARM_PARTS[_arm_part_index]
	var tail_part: Dictionary = TAIL_PARTS[_tail_part_index]
	var horn_part: Dictionary = HORN_PARTS[_horn_part_index]

	var body_speed_multiplier: float = float(
		body_part.get("speed_multiplier", 1.0)
	)
	var leg_speed_multiplier: float = float(
		leg_part.get("speed_multiplier", 1.0)
	)
	var arm_speed_multiplier: float = float(
		arm_part.get("speed_multiplier", 1.0)
	)
	var tail_speed_multiplier: float = float(
		tail_part.get("speed_multiplier", 1.0)
	)

	var leg_jump_multiplier: float = float(
		leg_part.get("jump_multiplier", 1.0)
	)
	var tail_jump_multiplier: float = float(
		tail_part.get("jump_multiplier", 1.0)
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
	var arm_hunger_multiplier: float = float(
		arm_part.get("hunger_multiplier", 1.0)
	)
	var tail_hunger_multiplier: float = float(
		tail_part.get("hunger_multiplier", 1.0)
	)
	var horn_hunger_multiplier: float = float(
		horn_part.get("hunger_multiplier", 1.0)
	)

	var health_bonus: float = (
		float(body_part.get("health_bonus", 0.0))
		+ float(horn_part.get("health_bonus", 0.0))
	)

	var body_volume_multiplier: float = (
		_body_width_scale
		* _body_height_scale
		* _body_length_scale
	)
	var body_shape_speed_multiplier: float = clampf(
		1.12 - (body_volume_multiplier - 1.0) * 0.18,
		0.65,
		1.35
	)
	var body_shape_hunger_multiplier: float = clampf(
		0.75 + body_volume_multiplier * 0.25,
		0.75,
		1.55
	)
	var body_shape_health_bonus: float = maxf(
		0.0,
		(body_volume_multiplier - 1.0) * 45.0
	)

	var leg_shape_speed_multiplier: float = clampf(
		0.72 + _leg_scale * 0.28,
		0.65,
		1.30
	)
	var leg_shape_jump_multiplier: float = clampf(
		0.72 + _leg_scale * 0.28,
		0.65,
		1.35
	)
	var leg_shape_hunger_multiplier: float = clampf(
		0.82 + _leg_scale * 0.18,
		0.78,
		1.25
	)

	var mouth_shape_hunger_multiplier: float = clampf(
		0.92 + (_mouth_scale - 1.0) * 0.10,
		0.85,
		1.20
	)
	var arm_shape_hunger_multiplier: float = clampf(
		0.94 + (_arm_scale - 1.0) * 0.12,
		0.90,
		1.22
	)
	var tail_shape_hunger_multiplier: float = clampf(
		0.96 + (_tail_scale - 1.0) * 0.10,
		0.92,
		1.20
	)

	move_speed = (
		_base_move_speed
		* body_speed_multiplier
		* leg_speed_multiplier
		* arm_speed_multiplier
		* tail_speed_multiplier
		* body_shape_speed_multiplier
		* leg_shape_speed_multiplier
	)
	jump_velocity = (
		_base_jump_velocity
		* leg_jump_multiplier
		* tail_jump_multiplier
		* leg_shape_jump_multiplier
	)
	maximum_health = (
		_base_maximum_health
		+ health_bonus
		+ body_shape_health_bonus
	)
	hunger_loss_per_second = (
		_base_hunger_loss_per_second
		* body_hunger_multiplier
		* leg_hunger_multiplier
		* mouth_hunger_multiplier
		* arm_hunger_multiplier
		* tail_hunger_multiplier
		* horn_hunger_multiplier
		* body_shape_hunger_multiplier
		* leg_shape_hunger_multiplier
		* mouth_shape_hunger_multiplier
		* arm_shape_hunger_multiplier
		* tail_shape_hunger_multiplier
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
		"Creature builder updated: ",
		_get_selected_builder_slot_name(),
		" | ",
		_get_selected_builder_part_name(),
		" | Complexity: ",
		_format_float(_get_creature_complexity(), 0.1),
		" / ",
		MAX_CREATURE_COMPLEXITY
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

	var voxel: float = CREATURE_PART_VOXEL_SIZE
	var body_dimensions := Vector3(
		float(body_size.x) * voxel * _body_width_scale,
		float(body_size.y) * voxel * _body_height_scale,
		float(body_size.z) * voxel * _body_length_scale
	)
	var leg_height: float = float(leg_height_voxels) * voxel * _leg_scale
	var body_center_y: float = leg_height + body_dimensions.y * 0.5

	_add_visual_box(
		"BodyCore",
		Vector3(0.0, body_center_y, 0.0),
		body_dimensions,
		_get_tinted_body_color(body_part)
	)

	_add_paint_visuals(
		body_center_y,
		body_dimensions
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

	_add_arm_visuals(
		body_center_y,
		body_dimensions
	)

	_add_tail_visual(
		body_center_y,
		body_dimensions
	)

	_add_horn_visuals(
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
		float(leg_thickness_voxels) * voxel * _leg_scale,
		float(leg_height_voxels) * voxel * _leg_scale,
		float(leg_thickness_voxels) * voxel * _leg_scale
	)
	var leg_y: float = leg_dimensions.y * 0.5
	var x_offset: float = maxf(
		body_dimensions.x * 0.35 * _leg_spread_scale,
		voxel * 0.75
	)
	var z_front: float = (
		-body_dimensions.z * 0.28
		+ _leg_position_offset_z
	)
	var z_back: float = (
		body_dimensions.z * 0.28
		+ _leg_position_offset_z
	)

	var leg_positions: Array[Vector3] = [
		Vector3(-x_offset, leg_y, z_front),
		Vector3(x_offset, leg_y, z_front),
		Vector3(-x_offset, leg_y, z_back),
		Vector3(x_offset, leg_y, z_back),
	]

	if leg_count >= 6:
		leg_positions.append(
			Vector3(-x_offset, leg_y, _leg_position_offset_z)
		)
		leg_positions.append(
			Vector3(x_offset, leg_y, _leg_position_offset_z)
		)

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
	mouth_size *= _mouth_scale

	var mouth_position := Vector3(
		0.0,
		body_center_y + body_dimensions.y * 0.10,
		-body_dimensions.z * 0.5 - mouth_size.z * 0.5
	)
	mouth_position += _mouth_position_offset

	_add_visual_box(
		"MouthPart",
		mouth_position,
		mouth_size,
		mouth_part.get("color", Color.WHITE),
		Vector3(0.0, _mouth_rotation_y, 0.0)
	)


func _add_eye_visuals(
	body_size: Vector3i,
	body_center_y: float,
	body_dimensions: Vector3
) -> void:
	var eye_part: Dictionary = EYE_PARTS[_eye_part_index]
	var eye_size: Vector3 = eye_part.get(
		"size",
		Vector3(0.07, 0.07, 0.04)
	)
	eye_size *= _eye_scale

	var eye_y: float = (
		body_center_y
		+ body_dimensions.y * 0.23
		+ _eye_position_offset.y
	)
	var eye_z: float = (
		-body_dimensions.z * 0.5
		- 0.025
		+ _eye_position_offset.z
	)
	var eye_x: float = (
		body_dimensions.x
		* 0.22
		* _eye_spread_scale
		+ _eye_position_offset.x
	)

	_add_visual_box(
		"LeftEye",
		Vector3(-eye_x, eye_y, eye_z),
		eye_size,
		eye_part.get("color", Color.WHITE),
		Vector3(0.0, -_eye_rotation_y, 0.0)
	)
	_add_visual_box(
		"RightEye",
		Vector3(eye_x, eye_y, eye_z),
		eye_size,
		eye_part.get("color", Color.WHITE),
		Vector3(0.0, _eye_rotation_y, 0.0)
	)


func _add_arm_visuals(
	body_center_y: float,
	body_dimensions: Vector3
) -> void:
	var arm_part: Dictionary = ARM_PARTS[_arm_part_index]

	if str(arm_part.get("id", &"no_arms")) == "no_arms":
		return

	var upper_size: Vector3 = arm_part.get(
		"upper_size",
		Vector3(0.16, 0.42, 0.16)
	)
	var hand_size: Vector3 = arm_part.get(
		"hand_size",
		Vector3(0.22, 0.16, 0.20)
	)
	upper_size *= _arm_scale
	hand_size *= _arm_scale

	var arm_y: float = (
		body_center_y
		+ body_dimensions.y * 0.02
		+ _arm_position_offset.y
	)
	var arm_z: float = (
		-body_dimensions.z * 0.08
		+ _arm_position_offset.z
	)
	var arm_x: float = (
		body_dimensions.x * 0.56 * _arm_spread_scale
		+ _arm_position_offset.x
	)

	var hand_drop: float = upper_size.y * 0.55

	_add_visual_box(
		"LeftArm",
		Vector3(-arm_x, arm_y, arm_z),
		upper_size,
		arm_part.get("color", Color.WHITE),
		Vector3(0.0, -_arm_rotation_y, 0.0)
	)
	_add_visual_box(
		"RightArm",
		Vector3(arm_x, arm_y, arm_z),
		upper_size,
		arm_part.get("color", Color.WHITE),
		Vector3(0.0, _arm_rotation_y, 0.0)
	)
	_add_visual_box(
		"LeftHand",
		Vector3(-arm_x, arm_y - hand_drop, arm_z - hand_size.z * 0.3),
		hand_size,
		arm_part.get("color", Color.WHITE)
	)
	_add_visual_box(
		"RightHand",
		Vector3(arm_x, arm_y - hand_drop, arm_z - hand_size.z * 0.3),
		hand_size,
		arm_part.get("color", Color.WHITE)
	)


func _add_tail_visual(
	body_center_y: float,
	body_dimensions: Vector3
) -> void:
	var tail_part: Dictionary = TAIL_PARTS[_tail_part_index]

	if str(tail_part.get("id", &"no_tail")) == "no_tail":
		return

	var tail_size: Vector3 = tail_part.get(
		"size",
		Vector3(0.24, 0.22, 0.72)
	)
	tail_size *= _tail_scale

	var tail_position := Vector3(
		0.0,
		body_center_y - body_dimensions.y * 0.08,
		body_dimensions.z * 0.5 + tail_size.z * 0.5
	)
	tail_position += _tail_position_offset

	_add_visual_box(
		"TailPart",
		tail_position,
		tail_size,
		tail_part.get("color", Color.WHITE),
		Vector3(0.0, _tail_rotation_y, 0.0)
	)

	if tail_part.has("club_size"):
		var club_size: Vector3 = tail_part.get(
			"club_size",
			Vector3(0.35, 0.32, 0.32)
		)
		club_size *= _tail_scale

		var club_position := Vector3(
			tail_position.x,
			tail_position.y,
			tail_position.z + tail_size.z * 0.5
		)

		_add_visual_box(
			"TailClub",
			club_position,
			club_size,
			tail_part.get("color", Color.WHITE),
			Vector3(0.0, _tail_rotation_y, 0.0)
		)


func _add_horn_visuals(
	body_center_y: float,
	body_dimensions: Vector3
) -> void:
	var horn_part: Dictionary = HORN_PARTS[_horn_part_index]

	if str(horn_part.get("id", &"no_horns")) == "no_horns":
		return

	var horn_size: Vector3 = horn_part.get(
		"size",
		Vector3(0.12, 0.26, 0.12)
	)
	horn_size *= _horn_scale

	var horn_y: float = (
		body_center_y
		+ body_dimensions.y * 0.54
		+ horn_size.y * 0.5
		+ _horn_position_offset.y
	)
	var horn_z: float = (
		-body_dimensions.z * 0.26
		+ _horn_position_offset.z
	)
	var horn_x: float = (
		body_dimensions.x * 0.24 * _horn_spread_scale
		+ _horn_position_offset.x
	)

	_add_visual_box(
		"LeftHorn",
		Vector3(-horn_x, horn_y, horn_z),
		horn_size,
		horn_part.get("color", Color.WHITE),
		Vector3(0.0, -_horn_rotation_y, 0.0)
	)
	_add_visual_box(
		"RightHorn",
		Vector3(horn_x, horn_y, horn_z),
		horn_size,
		horn_part.get("color", Color.WHITE),
		Vector3(0.0, _horn_rotation_y, 0.0)
	)


func _add_paint_visuals(
	body_center_y: float,
	body_dimensions: Vector3
) -> void:
	var paint_part: Dictionary = PAINT_PARTS[_paint_part_index]
	var pattern: String = str(paint_part.get("pattern", "none"))

	if pattern == "none":
		return

	var color: Color = paint_part.get(
		"pattern_color",
		Color.WHITE
	)
	color = color.lerp(Color.WHITE, 1.0 - _paint_intensity)

	if pattern == "spots":
		_add_paint_spots(body_center_y, body_dimensions, color)
		return

	if pattern == "stripes":
		_add_paint_stripes(body_center_y, body_dimensions, color)
		return

	if pattern == "marks":
		_add_paint_warning_marks(body_center_y, body_dimensions, color)


func _add_paint_spots(
	body_center_y: float,
	body_dimensions: Vector3,
	paint_color: Color
) -> void:
	var spot_size := Vector3(
		body_dimensions.x * 0.18,
		0.018,
		body_dimensions.z * 0.16
	)

	var spot_y: float = body_center_y + body_dimensions.y * 0.51

	var positions: Array[Vector3] = [
		Vector3(-body_dimensions.x * 0.22, spot_y, -body_dimensions.z * 0.18),
		Vector3(body_dimensions.x * 0.20, spot_y, body_dimensions.z * 0.05),
		Vector3(0.0, spot_y, body_dimensions.z * 0.26),
	]

	for spot_index in range(positions.size()):
		_add_visual_box(
			"PaintSpot%d" % spot_index,
			positions[spot_index],
			spot_size,
			paint_color
		)


func _add_paint_stripes(
	body_center_y: float,
	body_dimensions: Vector3,
	paint_color: Color
) -> void:
	var stripe_y: float = body_center_y + body_dimensions.y * 0.515

	for stripe_index in range(3):
		var z_offset: float = (
			-body_dimensions.z * 0.28
			+ float(stripe_index) * body_dimensions.z * 0.28
		)

		_add_visual_box(
			"PaintStripe%d" % stripe_index,
			Vector3(0.0, stripe_y, z_offset),
			Vector3(body_dimensions.x * 0.92, 0.016, body_dimensions.z * 0.08),
			paint_color
		)


func _add_paint_warning_marks(
	body_center_y: float,
	body_dimensions: Vector3,
	paint_color: Color
) -> void:
	var mark_y: float = body_center_y + body_dimensions.y * 0.52

	_add_visual_box(
		"WarningMarkFront",
		Vector3(0.0, mark_y, -body_dimensions.z * 0.35),
		Vector3(body_dimensions.x * 0.55, 0.018, body_dimensions.z * 0.10),
		paint_color
	)
	_add_visual_box(
		"WarningMarkBack",
		Vector3(0.0, mark_y, body_dimensions.z * 0.20),
		Vector3(body_dimensions.x * 0.40, 0.018, body_dimensions.z * 0.10),
		paint_color
	)


func _get_tinted_body_color(body_part: Dictionary) -> Color:
	var base_color: Color = body_part.get("color", Color.WHITE)
	var paint_part: Dictionary = PAINT_PARTS[_paint_part_index]
	var tint: Color = paint_part.get("tint", Color.WHITE)
	var tinted_color := Color(
		base_color.r * tint.r,
		base_color.g * tint.g,
		base_color.b * tint.b,
		base_color.a
	)

	return base_color.lerp(
		tinted_color,
		clampf(_paint_intensity, 0.0, 1.0)
	)


func _add_visual_box(
	box_name: String,
	local_position: Vector3,
	box_size: Vector3,
	box_color: Color,
	local_rotation: Vector3 = Vector3.ZERO
) -> void:
	if _creature_visual_root == null:
		return

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = box_name

	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = local_position
	mesh_instance.rotation = local_rotation

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


func _cycle_eye_part() -> void:
	if not enable_creature_builder_debug_keys:
		return

	_eye_part_index = (_eye_part_index + 1) % EYE_PARTS.size()
	_apply_creature_part_blueprint()


func _cycle_arm_part() -> void:
	if not enable_creature_builder_debug_keys:
		return

	_arm_part_index = (_arm_part_index + 1) % ARM_PARTS.size()
	_apply_creature_part_blueprint()


func _cycle_tail_part() -> void:
	if not enable_creature_builder_debug_keys:
		return

	_tail_part_index = (_tail_part_index + 1) % TAIL_PARTS.size()
	_apply_creature_part_blueprint()


func _cycle_horn_part() -> void:
	if not enable_creature_builder_debug_keys:
		return

	_horn_part_index = (_horn_part_index + 1) % HORN_PARTS.size()
	_apply_creature_part_blueprint()


func _cycle_paint_part() -> void:
	if not enable_creature_builder_debug_keys:
		return

	_paint_part_index = (_paint_part_index + 1) % PAINT_PARTS.size()
	_apply_creature_part_blueprint()


func _get_current_creature_part_summary() -> Dictionary:
	return {
		"body": str(BODY_PARTS[_body_part_index].get("name", "Body")),
		"legs": str(LEG_PARTS[_leg_part_index].get("name", "Legs")),
		"mouth": str(MOUTH_PARTS[_mouth_part_index].get("name", "Mouth")),
		"eyes": str(EYE_PARTS[_eye_part_index].get("name", "Eyes")),
		"arms": str(ARM_PARTS[_arm_part_index].get("name", "Arms")),
		"tail": str(TAIL_PARTS[_tail_part_index].get("name", "Tail")),
		"horns": str(HORN_PARTS[_horn_part_index].get("name", "Horns")),
		"paint": str(PAINT_PARTS[_paint_part_index].get("name", "Paint")),
		"selected_slot": _get_selected_builder_slot_name(),
		"selected_part": _get_selected_builder_part_name(),
		"complexity": _get_creature_complexity(),
		"complexity_ratio": _get_creature_complexity_ratio(),
		"body_shape": _get_body_shape_text(),
		"selected_transform": _get_selected_builder_transform_text(),
	}


func _get_selected_builder_slot_name() -> String:
	return BUILDER_SLOT_NAMES[
		clampi(
			_builder_slot_index,
			0,
			BUILDER_SLOT_NAMES.size() - 1
		)
	]


func _get_selected_builder_part_name() -> String:
	match _builder_slot_index:
		BUILDER_SLOT_BODY:
			return str(BODY_PARTS[_body_part_index].get("name", "Body"))
		BUILDER_SLOT_LEGS:
			return str(LEG_PARTS[_leg_part_index].get("name", "Legs"))
		BUILDER_SLOT_MOUTH:
			return str(MOUTH_PARTS[_mouth_part_index].get("name", "Mouth"))
		BUILDER_SLOT_EYES:
			return str(EYE_PARTS[_eye_part_index].get("name", "Eyes"))
		BUILDER_SLOT_ARMS:
			return str(ARM_PARTS[_arm_part_index].get("name", "Arms"))
		BUILDER_SLOT_TAIL:
			return str(TAIL_PARTS[_tail_part_index].get("name", "Tail"))
		BUILDER_SLOT_HORNS:
			return str(HORN_PARTS[_horn_part_index].get("name", "Horns"))
		BUILDER_SLOT_PAINT:
			return str(PAINT_PARTS[_paint_part_index].get("name", "Paint"))
		_:
			return "Unknown Part"


func _get_body_shape_text() -> String:
	return (
		"W %s / H %s / L %s"
	) % [
		_format_float(_body_width_scale, 0.01),
		_format_float(_body_height_scale, 0.01),
		_format_float(_body_length_scale, 0.01),
	]


func _get_selected_builder_transform_text() -> String:
	match _builder_slot_index:
		BUILDER_SLOT_BODY:
			return _get_body_shape_text()
		BUILDER_SLOT_LEGS:
			return (
				"Scale %s / Spread %s / Z %s"
			) % [
				_format_float(_leg_scale, 0.01),
				_format_float(_leg_spread_scale, 0.01),
				_format_float(_leg_position_offset_z, 0.01),
			]
		BUILDER_SLOT_MOUTH:
			return _format_part_transform(
				_mouth_scale,
				_mouth_position_offset,
				_mouth_rotation_y
			)
		BUILDER_SLOT_EYES:
			return (
				"Scale %s / Pos %s,%s,%s / Spread %s / Rot %s"
			) % [
				_format_float(_eye_scale, 0.01),
				_format_float(_eye_position_offset.x, 0.01),
				_format_float(_eye_position_offset.y, 0.01),
				_format_float(_eye_position_offset.z, 0.01),
				_format_float(_eye_spread_scale, 0.01),
				_format_float(rad_to_deg(_eye_rotation_y), 1.0),
			]
		BUILDER_SLOT_ARMS:
			return (
				"Scale %s / Pos %s,%s,%s / Spread %s / Rot %s"
			) % [
				_format_float(_arm_scale, 0.01),
				_format_float(_arm_position_offset.x, 0.01),
				_format_float(_arm_position_offset.y, 0.01),
				_format_float(_arm_position_offset.z, 0.01),
				_format_float(_arm_spread_scale, 0.01),
				_format_float(rad_to_deg(_arm_rotation_y), 1.0),
			]
		BUILDER_SLOT_TAIL:
			return _format_part_transform(
				_tail_scale,
				_tail_position_offset,
				_tail_rotation_y
			)
		BUILDER_SLOT_HORNS:
			return (
				"Scale %s / Pos %s,%s,%s / Spread %s / Rot %s"
			) % [
				_format_float(_horn_scale, 0.01),
				_format_float(_horn_position_offset.x, 0.01),
				_format_float(_horn_position_offset.y, 0.01),
				_format_float(_horn_position_offset.z, 0.01),
				_format_float(_horn_spread_scale, 0.01),
				_format_float(rad_to_deg(_horn_rotation_y), 1.0),
			]
		BUILDER_SLOT_PAINT:
			return (
				"Intensity %s"
			) % [
				_format_float(_paint_intensity, 0.01),
			]
		_:
			return "-"


func _format_part_transform(
	part_scale: float,
	position_offset: Vector3,
	rotation_y: float
) -> String:
	return (
		"Scale %s / Pos %s,%s,%s / Rot %s"
	) % [
		_format_float(part_scale, 0.01),
		_format_float(position_offset.x, 0.01),
		_format_float(position_offset.y, 0.01),
		_format_float(position_offset.z, 0.01),
		_format_float(rad_to_deg(rotation_y), 1.0),
	]


func _get_creature_complexity() -> float:
	var leg_part: Dictionary = LEG_PARTS[_leg_part_index]
	var leg_count: int = int(leg_part.get("leg_count", 4))
	var eye_part: Dictionary = EYE_PARTS[_eye_part_index]
	var arm_part: Dictionary = ARM_PARTS[_arm_part_index]
	var tail_part: Dictionary = TAIL_PARTS[_tail_part_index]
	var horn_part: Dictionary = HORN_PARTS[_horn_part_index]
	var paint_part: Dictionary = PAINT_PARTS[_paint_part_index]

	var body_volume: float = (
		_body_width_scale
		* _body_height_scale
		* _body_length_scale
	)

	var complexity: float = 0.0
	complexity += 18.0 * body_volume
	complexity += float(leg_count) * 5.0 * _leg_scale
	complexity += 8.0 * _mouth_scale
	complexity += float(eye_part.get("complexity", 4.0)) * _eye_scale
	complexity += float(arm_part.get("complexity", 0.0)) * _arm_scale
	complexity += float(tail_part.get("complexity", 0.0)) * _tail_scale
	complexity += float(horn_part.get("complexity", 0.0)) * _horn_scale
	complexity += float(paint_part.get("complexity", 0.0)) * _paint_intensity
	complexity += absf(_mouth_position_offset.length()) * 10.0
	complexity += absf(_eye_position_offset.length()) * 10.0
	complexity += absf(_arm_position_offset.length()) * 10.0
	complexity += absf(_tail_position_offset.length()) * 10.0
	complexity += absf(_horn_position_offset.length()) * 10.0
	complexity += absf(_leg_position_offset_z) * 8.0
	complexity += absf(_leg_spread_scale - 1.0) * 8.0
	complexity += absf(_eye_spread_scale - 1.0) * 5.0
	complexity += absf(_arm_spread_scale - 1.0) * 5.0
	complexity += absf(_horn_spread_scale - 1.0) * 5.0
	complexity += absf(_mouth_rotation_y) * 2.0
	complexity += absf(_eye_rotation_y) * 2.0
	complexity += absf(_arm_rotation_y) * 2.0
	complexity += absf(_tail_rotation_y) * 2.0
	complexity += absf(_horn_rotation_y) * 2.0

	return complexity


func _get_creature_complexity_ratio() -> float:
	return clampf(
		_get_creature_complexity() / MAX_CREATURE_COMPLEXITY,
		0.0,
		1.0
	)


func _initialize_simulation_speed() -> void:
	_simulation_speed_index = clampi(
		initial_simulation_speed_index,
		0,
		SIMULATION_SPEEDS.size() - 1
	)
	_apply_simulation_speed(false)


func _handle_creature_builder_key(event: InputEvent) -> bool:
	if not enable_creature_builder_debug_keys:
		return false

	if not (event is InputEventKey):
		return false

	var key_event := event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return false

	if key_event.keycode == KEY_C:
		_toggle_creature_builder_mode()
		return true

	if not _builder_mode_enabled:
		return false

	if key_event.ctrl_pressed and key_event.keycode == KEY_S:
		_save_creature_build_to_disk()
		return true

	if key_event.ctrl_pressed and key_event.keycode == KEY_L:
		_load_creature_build_from_disk()
		return true

	if key_event.ctrl_pressed and key_event.keycode == KEY_R:
		_reset_entire_creature_build()
		return true

	match key_event.keycode:
		KEY_TAB:
			_cycle_builder_slot()
			return true
		KEY_Q:
			_change_builder_variant(-1)
			return true
		KEY_E:
			_change_builder_variant(1)
			return true
		KEY_COMMA, KEY_KP_SUBTRACT:
			_scale_selected_builder_part(-1.0)
			return true
		KEY_PERIOD, KEY_KP_ADD:
			_scale_selected_builder_part(1.0)
			return true
		KEY_LEFT:
			_move_selected_builder_part(Vector3(-1.0, 0.0, 0.0))
			return true
		KEY_RIGHT:
			_move_selected_builder_part(Vector3(1.0, 0.0, 0.0))
			return true
		KEY_UP:
			_move_selected_builder_part(Vector3(0.0, 0.0, -1.0))
			return true
		KEY_DOWN:
			_move_selected_builder_part(Vector3(0.0, 0.0, 1.0))
			return true
		KEY_PAGEUP:
			_move_selected_builder_part(Vector3(0.0, 1.0, 0.0))
			return true
		KEY_PAGEDOWN:
			_move_selected_builder_part(Vector3(0.0, -1.0, 0.0))
			return true
		KEY_R:
			_rotate_selected_builder_part(1.0)
			return true
		KEY_X:
			_reset_selected_builder_slot()
			return true
		_:
			return false


func _toggle_creature_builder_mode() -> void:
	_builder_mode_enabled = not _builder_mode_enabled

	print(
		"Creature builder mode: ",
		"ON" if _builder_mode_enabled else "OFF"
	)

	_update_development_debug_overlay(0.0, true)


func _cycle_builder_slot() -> void:
	_builder_slot_index = (
		_builder_slot_index + 1
	) % BUILDER_SLOT_NAMES.size()

	print(
		"Selected builder slot: ",
		_get_selected_builder_slot_name(),
		" | ",
		_get_selected_builder_part_name()
	)

	_update_development_debug_overlay(0.0, true)


func _change_builder_variant(direction: int) -> void:
	match _builder_slot_index:
		BUILDER_SLOT_BODY:
			_body_part_index = posmod(
				_body_part_index + direction,
				BODY_PARTS.size()
			)
		BUILDER_SLOT_LEGS:
			_leg_part_index = posmod(
				_leg_part_index + direction,
				LEG_PARTS.size()
			)
		BUILDER_SLOT_MOUTH:
			_mouth_part_index = posmod(
				_mouth_part_index + direction,
				MOUTH_PARTS.size()
			)
		BUILDER_SLOT_EYES:
			_eye_part_index = posmod(
				_eye_part_index + direction,
				EYE_PARTS.size()
			)
		BUILDER_SLOT_ARMS:
			_arm_part_index = posmod(
				_arm_part_index + direction,
				ARM_PARTS.size()
			)
		BUILDER_SLOT_TAIL:
			_tail_part_index = posmod(
				_tail_part_index + direction,
				TAIL_PARTS.size()
			)
		BUILDER_SLOT_HORNS:
			_horn_part_index = posmod(
				_horn_part_index + direction,
				HORN_PARTS.size()
			)
		BUILDER_SLOT_PAINT:
			_paint_part_index = posmod(
				_paint_part_index + direction,
				PAINT_PARTS.size()
			)

	_apply_creature_part_blueprint()


func _scale_selected_builder_part(direction: float) -> void:
	var scale_delta: float = BUILDER_PART_SCALE_STEP * direction

	match _builder_slot_index:
		BUILDER_SLOT_BODY:
			_body_width_scale = clampf(
				_body_width_scale + BODY_SHAPE_STEP * direction,
				MIN_BODY_SHAPE_SCALE,
				MAX_BODY_SHAPE_SCALE
			)
			_body_height_scale = clampf(
				_body_height_scale + BODY_SHAPE_STEP * direction,
				MIN_BODY_SHAPE_SCALE,
				MAX_BODY_SHAPE_SCALE
			)
			_body_length_scale = clampf(
				_body_length_scale + BODY_SHAPE_STEP * direction,
				MIN_BODY_SHAPE_SCALE,
				MAX_BODY_SHAPE_SCALE
			)
		BUILDER_SLOT_LEGS:
			_leg_scale = clampf(
				_leg_scale + scale_delta,
				MIN_PART_SCALE,
				MAX_PART_SCALE
			)
		BUILDER_SLOT_MOUTH:
			_mouth_scale = clampf(
				_mouth_scale + scale_delta,
				MIN_PART_SCALE,
				MAX_PART_SCALE
			)
		BUILDER_SLOT_EYES:
			_eye_scale = clampf(
				_eye_scale + scale_delta,
				MIN_PART_SCALE,
				MAX_PART_SCALE
			)
		BUILDER_SLOT_ARMS:
			_arm_scale = clampf(
				_arm_scale + scale_delta,
				MIN_PART_SCALE,
				MAX_PART_SCALE
			)
		BUILDER_SLOT_TAIL:
			_tail_scale = clampf(
				_tail_scale + scale_delta,
				MIN_PART_SCALE,
				MAX_PART_SCALE
			)
		BUILDER_SLOT_HORNS:
			_horn_scale = clampf(
				_horn_scale + scale_delta,
				MIN_PART_SCALE,
				MAX_PART_SCALE
			)
		BUILDER_SLOT_PAINT:
			_paint_intensity = clampf(
				_paint_intensity + scale_delta,
				0.0,
				1.0
			)

	_apply_creature_part_blueprint()


func _move_selected_builder_part(direction: Vector3) -> void:
	var move_delta: Vector3 = direction * BUILDER_PART_MOVE_STEP

	match _builder_slot_index:
		BUILDER_SLOT_BODY:
			_body_width_scale = clampf(
				_body_width_scale + direction.x * BODY_SHAPE_STEP,
				MIN_BODY_SHAPE_SCALE,
				MAX_BODY_SHAPE_SCALE
			)
			_body_length_scale = clampf(
				_body_length_scale + -direction.z * BODY_SHAPE_STEP,
				MIN_BODY_SHAPE_SCALE,
				MAX_BODY_SHAPE_SCALE
			)
			_body_height_scale = clampf(
				_body_height_scale + direction.y * BODY_SHAPE_STEP,
				MIN_BODY_SHAPE_SCALE,
				MAX_BODY_SHAPE_SCALE
			)
		BUILDER_SLOT_LEGS:
			_leg_spread_scale = clampf(
				_leg_spread_scale + direction.x * BODY_SHAPE_STEP,
				MIN_LEG_SPREAD_SCALE,
				MAX_LEG_SPREAD_SCALE
			)
			_leg_position_offset_z = clampf(
				_leg_position_offset_z + move_delta.z,
				-0.45,
				0.45
			)
		BUILDER_SLOT_MOUTH:
			_mouth_position_offset = _clamp_part_offset(
				_mouth_position_offset + move_delta,
				Vector3(0.45, 0.45, 0.45),
				Vector3(0.45, 0.35, 0.30)
			)
		BUILDER_SLOT_EYES:
			_eye_position_offset = _clamp_part_offset(
				_eye_position_offset + move_delta,
				Vector3(0.30, 0.30, 0.45),
				Vector3(0.30, 0.45, 0.30)
			)
		BUILDER_SLOT_ARMS:
			_arm_position_offset = _clamp_part_offset(
				_arm_position_offset + move_delta,
				Vector3(0.35, 0.35, 0.45),
				Vector3(0.35, 0.45, 0.45)
			)
			_arm_spread_scale = clampf(
				_arm_spread_scale + direction.x * BODY_SHAPE_STEP,
				MIN_LEG_SPREAD_SCALE,
				MAX_LEG_SPREAD_SCALE
			)
		BUILDER_SLOT_TAIL:
			_tail_position_offset = _clamp_part_offset(
				_tail_position_offset + move_delta,
				Vector3(0.35, 0.35, 0.30),
				Vector3(0.35, 0.40, 0.55)
			)
		BUILDER_SLOT_HORNS:
			_horn_position_offset = _clamp_part_offset(
				_horn_position_offset + move_delta,
				Vector3(0.30, 0.25, 0.35),
				Vector3(0.30, 0.45, 0.30)
			)
			_horn_spread_scale = clampf(
				_horn_spread_scale + direction.x * BODY_SHAPE_STEP,
				MIN_LEG_SPREAD_SCALE,
				MAX_LEG_SPREAD_SCALE
			)
		BUILDER_SLOT_PAINT:
			_paint_intensity = clampf(
				_paint_intensity + direction.y * BODY_SHAPE_STEP,
				0.0,
				1.0
			)

	_apply_creature_part_blueprint()


func _clamp_part_offset(
	value: Vector3,
	negative_limits: Vector3,
	positive_limits: Vector3
) -> Vector3:
	return Vector3(
		clampf(value.x, -negative_limits.x, positive_limits.x),
		clampf(value.y, -negative_limits.y, positive_limits.y),
		clampf(value.z, -negative_limits.z, positive_limits.z)
	)


func _rotate_selected_builder_part(direction: float) -> void:
	var rotation_delta: float = deg_to_rad(
		BUILDER_PART_ROTATE_STEP * direction
	)

	match _builder_slot_index:
		BUILDER_SLOT_MOUTH:
			_mouth_rotation_y = wrapf(
				_mouth_rotation_y + rotation_delta,
				-PI,
				PI
			)
		BUILDER_SLOT_EYES:
			_eye_rotation_y = wrapf(
				_eye_rotation_y + rotation_delta,
				-PI,
				PI
			)
		BUILDER_SLOT_ARMS:
			_arm_rotation_y = wrapf(
				_arm_rotation_y + rotation_delta,
				-PI,
				PI
			)
		BUILDER_SLOT_TAIL:
			_tail_rotation_y = wrapf(
				_tail_rotation_y + rotation_delta,
				-PI,
				PI
			)
		BUILDER_SLOT_HORNS:
			_horn_rotation_y = wrapf(
				_horn_rotation_y + rotation_delta,
				-PI,
				PI
			)
		BUILDER_SLOT_LEGS:
			_leg_spread_scale = clampf(
				_leg_spread_scale + BODY_SHAPE_STEP * direction,
				MIN_LEG_SPREAD_SCALE,
				MAX_LEG_SPREAD_SCALE
			)
		BUILDER_SLOT_BODY:
			_body_height_scale = clampf(
				_body_height_scale + BODY_SHAPE_STEP * direction,
				MIN_BODY_SHAPE_SCALE,
				MAX_BODY_SHAPE_SCALE
			)

	_apply_creature_part_blueprint()


func _reset_selected_builder_slot() -> void:
	match _builder_slot_index:
		BUILDER_SLOT_BODY:
			_body_width_scale = 1.0
			_body_height_scale = 1.0
			_body_length_scale = 1.0
		BUILDER_SLOT_LEGS:
			_leg_scale = 1.0
			_leg_spread_scale = 1.0
			_leg_position_offset_z = 0.0
		BUILDER_SLOT_MOUTH:
			_mouth_scale = 1.0
			_mouth_position_offset = Vector3.ZERO
			_mouth_rotation_y = 0.0
		BUILDER_SLOT_EYES:
			_eye_scale = 1.0
			_eye_position_offset = Vector3.ZERO
			_eye_spread_scale = 1.0
			_eye_rotation_y = 0.0
		BUILDER_SLOT_ARMS:
			_arm_scale = 1.0
			_arm_position_offset = Vector3.ZERO
			_arm_spread_scale = 1.0
			_arm_rotation_y = 0.0
		BUILDER_SLOT_TAIL:
			_tail_scale = 1.0
			_tail_position_offset = Vector3.ZERO
			_tail_rotation_y = 0.0
		BUILDER_SLOT_HORNS:
			_horn_scale = 1.0
			_horn_position_offset = Vector3.ZERO
			_horn_spread_scale = 1.0
			_horn_rotation_y = 0.0
		BUILDER_SLOT_PAINT:
			_paint_intensity = 1.0

	_apply_creature_part_blueprint()


func _reset_entire_creature_build() -> void:
	_body_part_index = clampi(starting_body_part_index, 0, BODY_PARTS.size() - 1)
	_leg_part_index = clampi(starting_leg_part_index, 0, LEG_PARTS.size() - 1)
	_mouth_part_index = clampi(starting_mouth_part_index, 0, MOUTH_PARTS.size() - 1)
	_eye_part_index = clampi(starting_eye_part_index, 0, EYE_PARTS.size() - 1)
	_arm_part_index = clampi(starting_arm_part_index, 0, ARM_PARTS.size() - 1)
	_tail_part_index = clampi(starting_tail_part_index, 0, TAIL_PARTS.size() - 1)
	_horn_part_index = clampi(starting_horn_part_index, 0, HORN_PARTS.size() - 1)
	_paint_part_index = clampi(starting_paint_part_index, 0, PAINT_PARTS.size() - 1)

	_body_width_scale = 1.0
	_body_height_scale = 1.0
	_body_length_scale = 1.0
	_leg_scale = 1.0
	_leg_spread_scale = 1.0
	_leg_position_offset_z = 0.0
	_mouth_scale = 1.0
	_mouth_position_offset = Vector3.ZERO
	_mouth_rotation_y = 0.0
	_eye_scale = 1.0
	_eye_position_offset = Vector3.ZERO
	_eye_spread_scale = 1.0
	_eye_rotation_y = 0.0
	_arm_scale = 1.0
	_arm_position_offset = Vector3.ZERO
	_arm_spread_scale = 1.0
	_arm_rotation_y = 0.0
	_tail_scale = 1.0
	_tail_position_offset = Vector3.ZERO
	_tail_rotation_y = 0.0
	_horn_scale = 1.0
	_horn_position_offset = Vector3.ZERO
	_horn_spread_scale = 1.0
	_horn_rotation_y = 0.0
	_paint_intensity = 1.0

	_apply_creature_part_blueprint()
	print("Creature build reset.")


func _save_creature_build_to_disk() -> void:
	var save_file := FileAccess.open(
		CREATURE_BUILD_SAVE_PATH,
		FileAccess.WRITE
	)

	if save_file == null:
		push_error(
			"Could not save creature build. Error: %s"
			% FileAccess.get_open_error()
		)
		return

	save_file.store_string(
		JSON.stringify(
			_get_creature_build_dictionary(),
			"\t"
		)
	)

	print(
		"Creature build saved: ",
		CREATURE_BUILD_SAVE_PATH
	)


func _load_creature_build_from_disk() -> void:
	if not FileAccess.file_exists(CREATURE_BUILD_SAVE_PATH):
		push_warning(
			"No creature build save found: "
			+ CREATURE_BUILD_SAVE_PATH
		)
		return

	var save_file := FileAccess.open(
		CREATURE_BUILD_SAVE_PATH,
		FileAccess.READ
	)

	if save_file == null:
		push_error(
			"Could not load creature build. Error: %s"
			% FileAccess.get_open_error()
		)
		return

	var parser := JSON.new()
	var parse_error: Error = parser.parse(save_file.get_as_text())

	if parse_error != OK:
		push_error(
			"Creature build save is not valid JSON. Error: %s"
			% parse_error
		)
		return

	if not (parser.data is Dictionary):
		push_error("Creature build save is not a dictionary.")
		return

	_apply_creature_build_dictionary(parser.data)
	_apply_creature_part_blueprint()

	print(
		"Creature build loaded: ",
		CREATURE_BUILD_SAVE_PATH
	)


func _get_creature_build_dictionary() -> Dictionary:
	return {
		"version": 1,
		"parts": {
			"body": _body_part_index,
			"legs": _leg_part_index,
			"mouth": _mouth_part_index,
			"eyes": _eye_part_index,
			"arms": _arm_part_index,
			"tail": _tail_part_index,
			"horns": _horn_part_index,
			"paint": _paint_part_index,
		},
		"shape": {
			"body_width": _body_width_scale,
			"body_height": _body_height_scale,
			"body_length": _body_length_scale,
			"leg_scale": _leg_scale,
			"leg_spread": _leg_spread_scale,
			"leg_z": _leg_position_offset_z,
			"paint_intensity": _paint_intensity,
		},
		"transforms": {
			"mouth": _pack_part_transform(
				_mouth_scale,
				_mouth_position_offset,
				_mouth_rotation_y,
				1.0
			),
			"eyes": _pack_part_transform(
				_eye_scale,
				_eye_position_offset,
				_eye_rotation_y,
				_eye_spread_scale
			),
			"arms": _pack_part_transform(
				_arm_scale,
				_arm_position_offset,
				_arm_rotation_y,
				_arm_spread_scale
			),
			"tail": _pack_part_transform(
				_tail_scale,
				_tail_position_offset,
				_tail_rotation_y,
				1.0
			),
			"horns": _pack_part_transform(
				_horn_scale,
				_horn_position_offset,
				_horn_rotation_y,
				_horn_spread_scale
			),
		},
	}


func _apply_creature_build_dictionary(build_data: Dictionary) -> void:
	var parts: Dictionary = build_data.get("parts", {})
	var shape: Dictionary = build_data.get("shape", {})
	var transforms: Dictionary = build_data.get("transforms", {})

	_body_part_index = _get_safe_int(parts, "body", _body_part_index, BODY_PARTS.size())
	_leg_part_index = _get_safe_int(parts, "legs", _leg_part_index, LEG_PARTS.size())
	_mouth_part_index = _get_safe_int(parts, "mouth", _mouth_part_index, MOUTH_PARTS.size())
	_eye_part_index = _get_safe_int(parts, "eyes", _eye_part_index, EYE_PARTS.size())
	_arm_part_index = _get_safe_int(parts, "arms", _arm_part_index, ARM_PARTS.size())
	_tail_part_index = _get_safe_int(parts, "tail", _tail_part_index, TAIL_PARTS.size())
	_horn_part_index = _get_safe_int(parts, "horns", _horn_part_index, HORN_PARTS.size())
	_paint_part_index = _get_safe_int(parts, "paint", _paint_part_index, PAINT_PARTS.size())

	_body_width_scale = _get_safe_float(shape, "body_width", _body_width_scale, MIN_BODY_SHAPE_SCALE, MAX_BODY_SHAPE_SCALE)
	_body_height_scale = _get_safe_float(shape, "body_height", _body_height_scale, MIN_BODY_SHAPE_SCALE, MAX_BODY_SHAPE_SCALE)
	_body_length_scale = _get_safe_float(shape, "body_length", _body_length_scale, MIN_BODY_SHAPE_SCALE, MAX_BODY_SHAPE_SCALE)
	_leg_scale = _get_safe_float(shape, "leg_scale", _leg_scale, MIN_PART_SCALE, MAX_PART_SCALE)
	_leg_spread_scale = _get_safe_float(shape, "leg_spread", _leg_spread_scale, MIN_LEG_SPREAD_SCALE, MAX_LEG_SPREAD_SCALE)
	_leg_position_offset_z = _get_safe_float(shape, "leg_z", _leg_position_offset_z, -0.45, 0.45)
	_paint_intensity = _get_safe_float(shape, "paint_intensity", _paint_intensity, 0.0, 1.0)

	_unpack_part_transform(transforms.get("mouth", {}), "mouth")
	_unpack_part_transform(transforms.get("eyes", {}), "eyes")
	_unpack_part_transform(transforms.get("arms", {}), "arms")
	_unpack_part_transform(transforms.get("tail", {}), "tail")
	_unpack_part_transform(transforms.get("horns", {}), "horns")


func _pack_part_transform(
	part_scale: float,
	position_offset: Vector3,
	rotation_y: float,
	spread: float
) -> Dictionary:
	return {
		"scale": part_scale,
		"position": {
			"x": position_offset.x,
			"y": position_offset.y,
			"z": position_offset.z,
		},
		"rotation_y": rotation_y,
		"spread": spread,
	}


func _unpack_part_transform(
	transform_data: Variant,
	slot_name: String
) -> void:
	if not (transform_data is Dictionary):
		return

	var transform_dictionary: Dictionary = transform_data
	var packed_position: Dictionary = transform_dictionary.get(
		"position",
		{}
	)

	var part_scale: float = _get_safe_float(
		transform_dictionary,
		"scale",
		1.0,
		MIN_PART_SCALE,
		MAX_PART_SCALE
	)
	var rotation_y: float = _get_safe_float(
		transform_dictionary,
		"rotation_y",
		0.0,
		-PI,
		PI
	)
	var spread: float = _get_safe_float(
		transform_dictionary,
		"spread",
		1.0,
		MIN_LEG_SPREAD_SCALE,
		MAX_LEG_SPREAD_SCALE
	)
	var position := Vector3(
		_get_safe_float(packed_position, "x", 0.0, -0.55, 0.55),
		_get_safe_float(packed_position, "y", 0.0, -0.45, 0.55),
		_get_safe_float(packed_position, "z", 0.0, -0.55, 0.55)
	)

	match slot_name:
		"mouth":
			_mouth_scale = part_scale
			_mouth_rotation_y = rotation_y
			_mouth_position_offset = position
		"eyes":
			_eye_scale = part_scale
			_eye_rotation_y = rotation_y
			_eye_spread_scale = spread
			_eye_position_offset = position
		"arms":
			_arm_scale = part_scale
			_arm_rotation_y = rotation_y
			_arm_spread_scale = spread
			_arm_position_offset = position
		"tail":
			_tail_scale = part_scale
			_tail_rotation_y = rotation_y
			_tail_position_offset = position
		"horns":
			_horn_scale = part_scale
			_horn_rotation_y = rotation_y
			_horn_spread_scale = spread
			_horn_position_offset = position


func _get_safe_int(
	data: Dictionary,
	key: String,
	fallback: int,
	array_size: int
) -> int:
	return clampi(
		int(data.get(key, fallback)),
		0,
		maxi(array_size - 1, 0)
	)


func _get_safe_float(
	data: Dictionary,
	key: String,
	fallback: float,
	minimum: float,
	maximum: float
) -> float:
	return clampf(
		float(data.get(key, fallback)),
		minimum,
		maximum
	)


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
		KEY_N:
			_cycle_eye_part()
			return true
		KEY_I:
			_cycle_arm_part()
			return true
		KEY_T:
			_cycle_tail_part()
			return true
		KEY_H:
			_cycle_horn_part()
			return true
		KEY_P:
			_cycle_paint_part()
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
