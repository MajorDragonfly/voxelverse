extends CharacterBody3D


const STARVATION_DAMAGE_INTERVAL: float = 1.0
const DEHYDRATION_DAMAGE_INTERVAL: float = 1.0

const BIOLOGICAL_SEX_SEED_OFFSET: int = 1_592_746_831
const MAXIMUM_AGE_SEED_OFFSET: int = 2_147_483_647
const INITIAL_AGE_SEED_OFFSET: int = 1_073_741_823
const NEWBORN_SEED_OFFSET: int = 982_451_653

const GRAZER_SCENE_PATH: String = (
	"res://creatures/animals/grazer/grazer.tscn"
)

const BERRY_BUSH_SCENE_PATH: String = (
	"res://world/resources/plants/berry_bush.tscn"
)


enum BehaviorState {
	WANDERING,
	SEEKING_FOOD,
	SEEKING_WATER,
	SEEKING_MATE,
	FLEEING
}


enum BiologicalSex {
	FEMALE,
	MALE
}


@export_category("Movement")

@export_range(0.1, 10.0, 0.1)
var move_speed: float = 1.6

@export_range(1.0, 20.0, 0.5)
var rotation_speed: float = 5.0

@export_range(1.0, 10.0, 0.5)
var minimum_wander_time: float = 2.0

@export_range(1.0, 15.0, 0.5)
var maximum_wander_time: float = 5.0

@export_range(0.0, 1.0, 0.05)
var idle_probability: float = 0.25

@export_range(1.0, 50.0, 0.5)
var fall_acceleration: float = 20.0

@export_range(0.25, 5.0, 0.25)
var terrain_check_distance: float = 1.5

@export_range(0.25, 3.0, 0.25)
var maximum_step_height: float = 1.0


@export_category("Survival")

@export_range(1.0, 100.0, 1.0)
var maximum_health: float = 5.0

@export_range(0.1, 20.0, 0.1)
var bite_damage: float = 1.0

@export_range(1.0, 1000.0, 1.0)
var maximum_hunger: float = 100.0

@export_range(0.0, 100.0, 0.1)
var hunger_loss_per_second: float = 0.5

@export_range(0.0, 1.0, 0.05)
var hungry_threshold_ratio: float = 0.65

@export_range(0.0, 100.0, 0.1)
var starvation_damage_per_second: float = 0.5

@export_range(1.0, 1000.0, 1.0)
var maximum_thirst: float = 100.0

@export_range(0.0, 100.0, 0.1)
var thirst_loss_per_second: float = 0.8

@export_range(0.0, 1.0, 0.05)
var thirsty_threshold_ratio: float = 0.65

@export_range(0.0, 100.0, 0.1)
var dehydration_damage_per_second: float = 0.75


@export_category("Life Cycle")

@export_range(10.0, 3600.0, 1.0)
var minimum_maximum_age_seconds: float = 600.0

@export_range(10.0, 3600.0, 1.0)
var maximum_maximum_age_seconds: float = 900.0

@export_range(0.0, 0.95, 0.05)
var maximum_initial_age_ratio: float = 0.5

@export_range(0.05, 0.95, 0.05)
var sexual_maturity_age_ratio: float = 0.25

@export_range(0.0, 1.0, 0.05)
var minimum_reproduction_hunger_ratio: float = 0.75

@export_range(0.0, 1.0, 0.05)
var minimum_reproduction_thirst_ratio: float = 0.75


@export_category("Mate Search")

@export_range(1.0, 100.0, 1.0)
var mate_search_radius: float = 30.0

@export_range(0.1, 10.0, 0.1)
var mate_search_interval: float = 1.0

@export_range(0.5, 5.0, 0.1)
var mating_distance: float = 2.5

@export_range(1.0, 3.0, 0.1)
var mate_move_speed_multiplier: float = 1.5

@export_range(1.0, 600.0, 1.0)
var gestation_duration_seconds: float = 20.0

@export_range(1.0, 600.0, 1.0)
var reproduction_cooldown_seconds: float = 45.0

@export_range(2, 200, 1)
var maximum_grazer_population: int = 40

@export_range(0.5, 5.0, 0.25)
var newborn_spawn_distance: float = 2.5


@export_category("Food Search")

@export_range(1.0, 100.0, 1.0)
var food_search_radius: float = 18.0

@export_range(0.1, 10.0, 0.1)
var food_search_interval: float = 1.0

@export_range(0.5, 5.0, 0.1)
var food_reach_distance: float = 2.5


@export_category("Water Search")

@export_range(1.0, 100.0, 1.0)
var water_search_radius: float = 32.0

@export_range(0.1, 10.0, 0.1)
var water_search_interval: float = 1.0

@export_range(0.5, 5.0, 0.1)
var water_reach_distance: float = 2.0

@export_range(1.0, 100.0, 1.0)
var water_drink_amount: float = 60.0

@export_range(8, 64, 1)
var water_search_samples: int = 24

@export_range(1.0, 10.0, 0.5)
var water_search_step: float = 2.0

@export_range(0.5, 5.0, 0.25)
var shoreline_check_distance: float = 2.0


@export_category("Perception")

@export_range(1.0, 50.0, 0.5)
var player_detection_radius: float = 10.0

@export_range(0.05, 2.0, 0.05)
var perception_interval: float = 0.25

@export_range(0.5, 15.0, 0.5)
var flee_duration: float = 4.0

@export_range(1.0, 3.0, 0.1)
var flee_speed_multiplier: float = 1.5


@export_category("Corpse Food")

@export_range(1, 10, 1)
var meat_portions: int = 3

@export_range(1.0, 100.0, 1.0)
var hunger_restore_per_portion: float = 25.0


@export_category("Procedural Appearance")

@export_range(0.15, 0.60, 0.05)
var voxel_size: float = 0.25

@export_range(3, 8, 1)
var body_length_voxels: int = 5

@export_range(2, 5, 1)
var body_width_voxels: int = 3

@export_range(2, 5, 1)
var body_height_voxels: int = 3

@export_range(2, 6, 1)
var leg_height_voxels: int = 3


@export_category("Placement")

@export
var snap_to_terrain: bool = true


const BODY_COLOR: Color = Color(
	0.48,
	0.30,
	0.14,
	1.0
)

const BELLY_COLOR: Color = Color(
	0.62,
	0.48,
	0.29,
	1.0
)

const EYE_COLOR: Color = Color(
	0.03,
	0.03,
	0.02,
	1.0
)

const CORPSE_TINT: Color = Color(
	0.52,
	0.40,
	0.34,
	1.0
)


var current_health: float
var current_hunger: float
var current_thirst: float

var current_age_seconds: float = 0.0
var maximum_age_seconds: float = 0.0

var remaining_meat_portions: int
var biological_sex: int = BiologicalSex.FEMALE

var is_dead: bool = false

var _creature_seed: int = 0
var _seed_override: int = 0
var _has_seed_override: bool = false
var _configured_as_newborn: bool = false

var _is_sexually_mature: bool = false
var _is_reproduction_ready: bool = false

var _is_pregnant: bool = false
var _pregnancy_timer: float = 0.0
var _pregnancy_father_seed: int = 0
var _reproduction_cooldown_timer: float = 0.0
var _birth_count: int = 0

var _random := RandomNumberGenerator.new()

var _move_direction: Vector3 = Vector3.ZERO

var _decision_timer: float = 0.0
var _food_search_timer: float = 0.0
var _water_search_timer: float = 0.0
var _perception_timer: float = 0.0
var _mate_search_timer: float = 0.0
var _starvation_damage_timer: float = 0.0
var _dehydration_damage_timer: float = 0.0

var _behavior_state: int = BehaviorState.WANDERING

var _food_target: Node3D = null
var _ignored_food_targets: Dictionary = {}

var _water_target: Vector3 = Vector3.ZERO
var _has_water_target: bool = false

var _mate_target: Node3D = null
var _reported_no_compatible_mate: bool = false

var _threat_target: Node3D = null

var _initialized: bool = false


@onready
var body_mesh: MeshInstance3D = $BodyMesh

@onready
var body_collision: CollisionShape3D = $BodyCollision


func _ready() -> void:
	add_to_group(&"grazer")

	current_health = maximum_health
	current_hunger = maximum_hunger
	current_thirst = maximum_thirst
	remaining_meat_portions = meat_portions

	call_deferred("_initialize_creature")


func _initialize_creature() -> void:
	if snap_to_terrain:
		_snap_to_terrain()

	var creature_seed := _get_creature_seed()

	if _has_seed_override:
		creature_seed = _seed_override

	_creature_seed = creature_seed
	_random.seed = creature_seed

	_assign_biological_sex(creature_seed)
	_assign_life_cycle(creature_seed)
	_update_life_cycle_states(false)

	_generate_creature()
	_choose_new_behavior()

	_initialized = true

	print(
		"Grazer initialized. Sex: ",
		get_biological_sex_name(),
		" | Age: ",
		snappedf(current_age_seconds, 0.1),
		" / ",
		snappedf(maximum_age_seconds, 0.1),
		" seconds",
		" | Maturity age: ",
		snappedf(
			get_sexual_maturity_age_seconds(),
			0.1
		),
		" seconds",
		" | Sexually mature: ",
		is_sexually_mature(),
		" | Reproduction ready: ",
		is_reproduction_ready(),
		" | Newborn: ",
		_configured_as_newborn,
		" | Seed: ",
		_creature_seed,
		" | Position: ",
		global_position,
		" | In grazer group: ",
		is_in_group(&"grazer")
	)


func _assign_biological_sex(creature_seed: int) -> void:
	var sex_random := RandomNumberGenerator.new()

	sex_random.seed = (
		creature_seed
		+ BIOLOGICAL_SEX_SEED_OFFSET
	)

	biological_sex = sex_random.randi_range(
		BiologicalSex.FEMALE,
		BiologicalSex.MALE
	)


func _assign_life_cycle(creature_seed: int) -> void:
	var lowest_maximum_age := minf(
		minimum_maximum_age_seconds,
		maximum_maximum_age_seconds
	)

	var highest_maximum_age := maxf(
		minimum_maximum_age_seconds,
		maximum_maximum_age_seconds
	)

	var maximum_age_random := RandomNumberGenerator.new()

	maximum_age_random.seed = (
		creature_seed
		+ MAXIMUM_AGE_SEED_OFFSET
	)

	maximum_age_seconds = maximum_age_random.randf_range(
		lowest_maximum_age,
		highest_maximum_age
	)

	if _configured_as_newborn:
		current_age_seconds = 0.0
		return

	var initial_age_random := RandomNumberGenerator.new()

	initial_age_random.seed = (
		creature_seed
		+ INITIAL_AGE_SEED_OFFSET
	)

	var clamped_initial_age_ratio := clampf(
		maximum_initial_age_ratio,
		0.0,
		0.95
	)

	current_age_seconds = initial_age_random.randf_range(
		0.0,
		maximum_age_seconds
		* clamped_initial_age_ratio
	)


func get_biological_sex() -> int:
	return biological_sex


func get_biological_sex_name() -> String:
	match biological_sex:
		BiologicalSex.FEMALE:
			return "female"

		BiologicalSex.MALE:
			return "male"

		_:
			return "unknown"


func get_age_seconds() -> float:
	return current_age_seconds


func get_maximum_age_seconds() -> float:
	return maximum_age_seconds


func get_age_ratio() -> float:
	if maximum_age_seconds <= 0.0:
		return 0.0

	return clampf(
		current_age_seconds
		/ maximum_age_seconds,
		0.0,
		1.0
	)


func get_sexual_maturity_age_seconds() -> float:
	if maximum_age_seconds <= 0.0:
		return 0.0

	return (
		maximum_age_seconds
		* clampf(
			sexual_maturity_age_ratio,
			0.05,
			0.95
		)
	)


func is_sexually_mature() -> bool:
	return _is_sexually_mature


func is_reproduction_ready() -> bool:
	return _is_reproduction_ready


func is_alive() -> bool:
	return not is_dead


func is_pregnant() -> bool:
	return _is_pregnant


func get_creature_seed() -> int:
	return _creature_seed


func configure_as_newborn(newborn_seed: int) -> void:
	if _initialized:
		push_warning(
			"Grazer newborn configuration was attempted after initialization."
		)
		return

	_seed_override = newborn_seed
	_has_seed_override = true
	_configured_as_newborn = true


func apply_reproduction_cooldown() -> void:
	_reproduction_cooldown_timer = maxf(
		reproduction_cooldown_seconds,
		0.0
	)

	_clear_mate_target()
	_update_life_cycle_states()


func try_start_pregnancy(partner: Node) -> bool:
	if is_dead:
		return false

	if biological_sex != BiologicalSex.FEMALE:
		return false

	if _is_pregnant:
		return false

	if not _is_reproduction_ready:
		return false

	if partner is not Node3D:
		return false

	var partner_3d := partner as Node3D

	if not partner_3d.is_inside_tree():
		return false

	if not partner.has_method("get_biological_sex"):
		return false

	if not partner.has_method("get_creature_seed"):
		return false

	if not partner.has_method("is_reproduction_ready"):
		return false

	var partner_sex := int(
		partner.call("get_biological_sex")
	)

	if partner_sex != BiologicalSex.MALE:
		return false

	var partner_is_ready := bool(
		partner.call("is_reproduction_ready")
	)

	if not partner_is_ready:
		return false

	var safe_mating_distance := maxf(
		mating_distance,
		0.5
	)

	if (
		global_position.distance_to(
			partner_3d.global_position
		)
		> safe_mating_distance + 0.5
	):
		return false

	var safe_population_limit := maxi(
		maximum_grazer_population,
		2
	)

	if (
		_get_projected_grazer_population()
		>= safe_population_limit
	):
		print(
			"Grazer pregnancy blocked by population limit: ",
			safe_population_limit
		)

		return false

	_is_pregnant = true

	_pregnancy_timer = maxf(
		gestation_duration_seconds,
		0.1
	)

	_pregnancy_father_seed = int(
		partner.call("get_creature_seed")
	)

	_clear_mate_target()

	_move_direction = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0

	_update_life_cycle_states()

	print(
		"Grazer pregnancy started. Mother seed: ",
		_creature_seed,
		" | Father seed: ",
		_pregnancy_father_seed,
		" | Gestation: ",
		_pregnancy_timer,
		" seconds."
	)

	return true


func _physics_process(delta: float) -> void:
	if not _initialized:
		return

	if is_dead:
		_process_corpse_physics(delta)
		return

	_update_age(delta)

	if is_dead:
		return

	_update_hunger(delta)

	if is_dead:
		return

	_update_thirst(delta)

	if is_dead:
		return

	_update_reproduction(delta)
	_update_life_cycle_states()
	_update_perception(delta)
	_update_mate_awareness(delta)

	if _behavior_state == BehaviorState.FLEEING:
		_update_fleeing(delta)
	else:
		_update_target_selection(delta)

	match _behavior_state:
		BehaviorState.SEEKING_WATER:
			_update_water_movement()

		BehaviorState.SEEKING_FOOD:
			_update_food_movement()

		BehaviorState.SEEKING_MATE:
			_update_mate_movement()

		BehaviorState.WANDERING:
			_update_wandering(delta)

	if (
		_move_direction.length_squared() > 0.0
		and not _is_direction_safe(_move_direction)
	):
		match _behavior_state:
			BehaviorState.SEEKING_FOOD:
				_abandon_food_target(true)

			BehaviorState.SEEKING_WATER:
				_abandon_water_target()

			BehaviorState.SEEKING_MATE:
				_abandon_mate_target()

			BehaviorState.FLEEING:
				_update_flee_direction()

			_:
				_choose_new_behavior()

	var active_move_speed := move_speed

	if _behavior_state == BehaviorState.FLEEING:
		active_move_speed *= flee_speed_multiplier
	elif _behavior_state == BehaviorState.SEEKING_MATE:
		active_move_speed *= mate_move_speed_multiplier

	velocity.x = _move_direction.x * active_move_speed
	velocity.z = _move_direction.z * active_move_speed

	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= fall_acceleration * delta

	if _move_direction.length_squared() > 0.0:
		var target_rotation := atan2(
			-_move_direction.x,
			-_move_direction.z
		)

		rotation.y = lerp_angle(
			rotation.y,
			target_rotation,
			rotation_speed * delta
		)

	move_and_slide()


func _update_age(delta: float) -> void:
	if maximum_age_seconds <= 0.0:
		return

	current_age_seconds = minf(
		current_age_seconds + delta,
		maximum_age_seconds
	)

	if current_age_seconds < maximum_age_seconds:
		return

	print(
		"Grazer reached maximum age: ",
		snappedf(current_age_seconds, 0.1),
		" seconds."
	)

	_die()


func _update_life_cycle_states(
	announce_changes: bool = true
) -> void:
	var new_sexual_maturity := (
		not is_dead
		and current_age_seconds
		>= get_sexual_maturity_age_seconds()
	)

	if new_sexual_maturity != _is_sexually_mature:
		_is_sexually_mature = new_sexual_maturity

		if (
			announce_changes
			and _is_sexually_mature
		):
			print(
				"Grazer reached sexual maturity. Age: ",
				snappedf(current_age_seconds, 0.1),
				" / ",
				snappedf(
					get_sexual_maturity_age_seconds(),
					0.1
				),
				" seconds."
			)

	var new_reproduction_readiness := (
		not is_dead
		and _is_sexually_mature
		and not _is_pregnant
		and _reproduction_cooldown_timer <= 0.0
		and get_hunger_ratio()
		>= clampf(
			minimum_reproduction_hunger_ratio,
			0.0,
			1.0
		)
		and get_thirst_ratio()
		>= clampf(
			minimum_reproduction_thirst_ratio,
			0.0,
			1.0
		)
	)

	if (
		new_reproduction_readiness
		== _is_reproduction_ready
	):
		return

	_is_reproduction_ready = (
		new_reproduction_readiness
	)

	if not announce_changes:
		return

	print(
		"Grazer reproduction readiness changed: ",
		_is_reproduction_ready,
		" | Mature: ",
		_is_sexually_mature,
		" | Pregnant: ",
		_is_pregnant,
		" | Cooldown: ",
		snappedf(
			_reproduction_cooldown_timer,
			0.1
		),
		" | Hunger ratio: ",
		snappedf(get_hunger_ratio(), 0.01),
		" | Thirst ratio: ",
		snappedf(get_thirst_ratio(), 0.01)
	)


func _update_mate_awareness(delta: float) -> void:
	if (
		not _is_reproduction_ready
		or _behavior_state == BehaviorState.FLEEING
	):
		var was_seeking_mate := (
			_behavior_state
			== BehaviorState.SEEKING_MATE
		)

		_clear_mate_target()

		_mate_search_timer = 0.0
		_reported_no_compatible_mate = false

		if (
			was_seeking_mate
			and _behavior_state
			!= BehaviorState.FLEEING
		):
			_choose_new_behavior()

		return

	if _is_mate_target_valid():
		_behavior_state = BehaviorState.SEEKING_MATE
		return

	_clear_mate_target()

	_mate_search_timer = maxf(
		_mate_search_timer - delta,
		0.0
	)

	if _mate_search_timer > 0.0:
		return

	_mate_search_timer = maxf(
		mate_search_interval,
		0.1
	)

	var new_mate_target := (
		_find_nearest_compatible_mate()
	)

	if new_mate_target == null:
		if not _reported_no_compatible_mate:
			print(
				"Grazer found no compatible mate within ",
				mate_search_radius,
				" meters."
			)

			_reported_no_compatible_mate = true

		return

	_mate_target = new_mate_target
	_reported_no_compatible_mate = false

	_clear_food_target()
	_clear_water_target()

	_behavior_state = BehaviorState.SEEKING_MATE

	print(
		"Grazer started seeking compatible mate. Self sex: ",
		get_biological_sex_name(),
		" | Mate sex: ",
		String(
			_mate_target.call(
				"get_biological_sex_name"
			)
		),
		" | Distance: ",
		snappedf(
			global_position.distance_to(
				_mate_target.global_position
			),
			0.1
		)
	)


func _find_nearest_compatible_mate() -> Node3D:
	var nearest_mate: Node3D = null
	var nearest_distance_squared: float = INF

	var safe_search_radius := maxf(
		mate_search_radius,
		0.0
	)

	var search_radius_squared := (
		safe_search_radius
		* safe_search_radius
	)

	for grouped_node in get_tree().get_nodes_in_group(
		&"grazer"
	):
		if grouped_node is not Node3D:
			continue

		var candidate := grouped_node as Node3D

		if not _is_compatible_mate(candidate):
			continue

		var distance_squared := (
			global_position.distance_squared_to(
				candidate.global_position
			)
		)

		if distance_squared > search_radius_squared:
			continue

		if distance_squared >= nearest_distance_squared:
			continue

		nearest_distance_squared = distance_squared
		nearest_mate = candidate

	return nearest_mate


func _is_compatible_mate(candidate: Node) -> bool:
	if candidate == null:
		return false

	if candidate == self:
		return false

	if not is_instance_valid(candidate):
		return false

	if not candidate.is_inside_tree():
		return false

	if not candidate.has_method(
		"is_reproduction_ready"
	):
		return false

	if not candidate.has_method(
		"get_biological_sex"
	):
		return false

	if not candidate.has_method(
		"get_biological_sex_name"
	):
		return false

	var candidate_is_ready := bool(
		candidate.call(
			"is_reproduction_ready"
		)
	)

	if not candidate_is_ready:
		return false

	var candidate_sex := int(
		candidate.call(
			"get_biological_sex"
		)
	)

	return candidate_sex != biological_sex


func _is_mate_target_valid() -> bool:
	if _mate_target == null:
		return false

	if not is_instance_valid(_mate_target):
		return false

	if not _is_compatible_mate(_mate_target):
		return false

	var safe_search_radius := maxf(
		mate_search_radius,
		0.0
	)

	return (
		global_position.distance_squared_to(
			_mate_target.global_position
		)
		<= safe_search_radius
		* safe_search_radius
	)


func _clear_mate_target() -> void:
	_mate_target = null


func _abandon_mate_target() -> void:
	_clear_mate_target()

	_mate_search_timer = maxf(
		mate_search_interval,
		0.1
	)

	if _behavior_state == BehaviorState.SEEKING_MATE:
		_choose_new_behavior()


func _update_mate_movement() -> void:
	if not _is_mate_target_valid():
		_abandon_mate_target()
		return

	var target_offset := (
		_mate_target.global_position
		- global_position
	)

	target_offset.y = 0.0

	var distance_to_mate := target_offset.length()

	var safe_mating_distance := maxf(
		mating_distance,
		0.5
	)

	if distance_to_mate <= safe_mating_distance:
		_move_direction = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0

		_try_mate_with_target()
		return

	var target_direction := target_offset.normalized()

	if _is_direction_safe(target_direction):
		_move_direction = target_direction
	else:
		_abandon_mate_target()


func _try_mate_with_target() -> void:
	if not _is_mate_target_valid():
		_abandon_mate_target()
		return

	var partner := _mate_target
	var pregnancy_started := false

	if biological_sex == BiologicalSex.FEMALE:
		pregnancy_started = try_start_pregnancy(
			partner
		)

		if (
			pregnancy_started
			and partner.has_method(
				"apply_reproduction_cooldown"
			)
		):
			partner.call(
				"apply_reproduction_cooldown"
			)
	else:
		if partner.has_method(
			"try_start_pregnancy"
		):
			pregnancy_started = bool(
				partner.call(
					"try_start_pregnancy",
					self
				)
			)

		if pregnancy_started:
			apply_reproduction_cooldown()

	if not pregnancy_started:
		_abandon_mate_target()
		return

	print(
		"Grazer mating completed. Initiator sex: ",
		get_biological_sex_name()
	)

	_clear_mate_target()

	if _behavior_state != BehaviorState.FLEEING:
		_choose_new_behavior()


func _update_reproduction(delta: float) -> void:
	if _reproduction_cooldown_timer > 0.0:
		_reproduction_cooldown_timer = maxf(
			_reproduction_cooldown_timer - delta,
			0.0
		)

	if not _is_pregnant:
		return

	_pregnancy_timer = maxf(
		_pregnancy_timer - delta,
		0.0
	)

	if _pregnancy_timer > 0.0:
		return

	_finish_pregnancy_and_give_birth()


func _finish_pregnancy_and_give_birth() -> void:
	if not _is_pregnant:
		return

	var grazer_scene := load(
		GRAZER_SCENE_PATH
	) as PackedScene

	if grazer_scene == null:
		push_error(
			"Grazer scene could not be loaded for birth."
		)

		_pregnancy_timer = 1.0
		return

	var scene_parent := get_parent()

	if scene_parent == null:
		push_error(
			"Grazer birth failed because the mother has no parent node."
		)

		_pregnancy_timer = 1.0
		return

	_birth_count += 1

	var newborn_seed := _create_newborn_seed(
		_pregnancy_father_seed,
		_birth_count
	)

	var birth_position := (
		_find_newborn_spawn_position(
			newborn_seed
		)
	)

	var newborn_node := grazer_scene.instantiate()

	if newborn_node is not Node3D:
		push_error(
			"Instantiated grazer newborn is not a Node3D."
		)

		newborn_node.free()
		_pregnancy_timer = 1.0
		return

	var newborn := newborn_node as Node3D

	if not newborn.has_method(
		"configure_as_newborn"
	):
		push_error(
			"Grazer newborn is missing configure_as_newborn()."
		)

		newborn.free()
		_pregnancy_timer = 1.0
		return

	newborn.call(
		"configure_as_newborn",
		newborn_seed
	)

	scene_parent.add_child(newborn)
	newborn.global_position = birth_position

	_is_pregnant = false
	_pregnancy_timer = 0.0
	_pregnancy_father_seed = 0

	_reproduction_cooldown_timer = maxf(
		reproduction_cooldown_seconds,
		0.0
	)

	_clear_mate_target()
	_update_life_cycle_states()

	print(
		"Grazer gave birth. Newborn seed: ",
		newborn_seed,
		" | Birth number: ",
		_birth_count,
		" | Position: ",
		birth_position
	)


func _create_newborn_seed(
	father_seed: int,
	birth_number: int
) -> int:
	var newborn_seed := (
		_creature_seed
		* 31
		+ father_seed
		* 17
		+ birth_number
		* NEWBORN_SEED_OFFSET
		+ GameState.world_seed
		* 13
	)

	if newborn_seed == 0:
		newborn_seed = NEWBORN_SEED_OFFSET

	return newborn_seed


func _find_newborn_spawn_position(
	newborn_seed: int
) -> Vector3:
	var spawn_random := RandomNumberGenerator.new()

	spawn_random.seed = (
		newborn_seed
		+ NEWBORN_SEED_OFFSET
	)

	var current_terrain_height := (
		WorldGenerator.get_terrain_height(
			global_position.x,
			global_position.z
		)
	)

	var minimum_distance := maxf(
		0.75,
		newborn_spawn_distance * 0.5
	)

	var maximum_distance := maxf(
		minimum_distance + 0.1,
		newborn_spawn_distance
	)

	for _attempt in range(12):
		var angle := spawn_random.randf_range(
			0.0,
			TAU
		)

		var distance := spawn_random.randf_range(
			minimum_distance,
			maximum_distance
		)

		var candidate_position := (
			global_position
			+ Vector3(
				sin(angle),
				0.0,
				cos(angle)
			)
			* distance
		)

		var candidate_height := (
			WorldGenerator.get_terrain_height(
				candidate_position.x,
				candidate_position.z
			)
		)

		if (
			candidate_height
			<= WorldGenerator.get_sea_level()
			+ 0.20
		):
			continue

		if (
			absf(
				candidate_height
				- current_terrain_height
			)
			> maximum_step_height * 2.0
		):
			continue

		candidate_position.y = (
			candidate_height + 0.05
		)

		return candidate_position

	var fallback_position := (
		global_position
		+ Vector3.RIGHT
		* minimum_distance
	)

	fallback_position.y = (
		WorldGenerator.get_terrain_height(
			fallback_position.x,
			fallback_position.z
		)
		+ 0.05
	)

	return fallback_position


func _get_projected_grazer_population() -> int:
	var projected_population := 0

	for grouped_node in get_tree().get_nodes_in_group(
		&"grazer"
	):
		if not grouped_node.has_method("is_alive"):
			continue

		var grouped_grazer_is_alive := bool(
			grouped_node.call("is_alive")
		)

		if not grouped_grazer_is_alive:
			continue

		projected_population += 1

		if (
			grouped_node.has_method("is_pregnant")
			and bool(
				grouped_node.call("is_pregnant")
			)
		):
			projected_population += 1

	return projected_population


func _process_corpse_physics(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= fall_acceleration * delta

	move_and_slide()


func _update_hunger(delta: float) -> void:
	current_hunger = maxf(
		current_hunger
		- hunger_loss_per_second
		* delta,
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

		receive_hit(
			starvation_damage_per_second
			* STARVATION_DAMAGE_INTERVAL
		)

		if is_dead:
			return


func _update_thirst(delta: float) -> void:
	current_thirst = maxf(
		current_thirst
		- thirst_loss_per_second
		* delta,
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

		receive_hit(
			dehydration_damage_per_second
			* DEHYDRATION_DAMAGE_INTERVAL
		)

		if is_dead:
			return


func _update_perception(delta: float) -> void:
	_perception_timer -= delta

	if _perception_timer > 0.0:
		return

	_perception_timer = perception_interval

	var player_node := get_tree().get_first_node_in_group(
		&"player"
	)

	if player_node is not Node3D:
		return

	var player := player_node as Node3D

	var detection_distance_squared := (
		player_detection_radius
		* player_detection_radius
	)

	var player_distance_squared := (
		global_position.distance_squared_to(
			player.global_position
		)
	)

	if player_distance_squared > detection_distance_squared:
		return

	_start_fleeing_from(player)


func _start_fleeing_from(threat: Node3D) -> void:
	if threat == null:
		return

	var was_already_fleeing := (
		_behavior_state
		== BehaviorState.FLEEING
	)

	_threat_target = threat

	_clear_mate_target()
	_clear_food_target()
	_clear_water_target()

	_behavior_state = BehaviorState.FLEEING
	_decision_timer = flee_duration

	_update_flee_direction()

	if not was_already_fleeing:
		print(
			"Grazer detected player and started fleeing."
		)


func _update_flee_direction() -> void:
	if not is_instance_valid(_threat_target):
		_threat_target = null
		_choose_new_behavior()
		return

	var base_direction := (
		global_position
		- _threat_target.global_position
	)

	base_direction.y = 0.0

	if base_direction.length_squared() <= 0.001:
		var random_angle := _random.randf_range(
			0.0,
			TAU
		)

		base_direction = Vector3(
			sin(random_angle),
			0.0,
			cos(random_angle)
		)
	else:
		base_direction = base_direction.normalized()

	var escape_angles: Array[float] = [
		0.0,
		PI * 0.25,
		-PI * 0.25,
		PI * 0.5,
		-PI * 0.5,
		PI * 0.75,
		-PI * 0.75
	]

	for escape_angle in escape_angles:
		var candidate_direction := base_direction.rotated(
			Vector3.UP,
			escape_angle
		).normalized()

		if _is_direction_safe(candidate_direction):
			_move_direction = candidate_direction
			return

	_move_direction = Vector3.ZERO


func _update_target_selection(delta: float) -> void:
	_food_search_timer = maxf(
		_food_search_timer - delta,
		0.0
	)

	_water_search_timer = maxf(
		_water_search_timer - delta,
		0.0
	)

	if _behavior_state == BehaviorState.SEEKING_MATE:
		if _is_mate_target_valid():
			return

		_clear_mate_target()

	var hunger_ratio := get_hunger_ratio()
	var thirst_ratio := get_thirst_ratio()

	var needs_food := (
		hunger_ratio
		<= hungry_threshold_ratio
	)

	var needs_water := (
		thirst_ratio
		<= thirsty_threshold_ratio
	)

	if (
		_behavior_state == BehaviorState.SEEKING_FOOD
		and (
			not needs_food
			or not _is_food_target_valid()
		)
	):
		_clear_food_target()

	if (
		_behavior_state == BehaviorState.SEEKING_WATER
		and (
			not needs_water
			or not _is_water_target_valid()
		)
	):
		_clear_water_target()

	var water_has_priority := (
		needs_water
		and (
			not needs_food
			or thirst_ratio <= hunger_ratio
		)
	)

	if water_has_priority:
		if _prepare_water_target():
			_clear_food_target()
			_behavior_state = BehaviorState.SEEKING_WATER
			return

	if needs_food:
		if _prepare_food_target():
			_clear_water_target()
			_behavior_state = BehaviorState.SEEKING_FOOD
			return

	if needs_water:
		if _prepare_water_target():
			_clear_food_target()
			_behavior_state = BehaviorState.SEEKING_WATER
			return

	if _behavior_state != BehaviorState.WANDERING:
		_choose_new_behavior()


func _prepare_food_target() -> bool:
	if _is_food_target_valid():
		return true

	_food_target = null

	if _food_search_timer > 0.0:
		return false

	_food_search_timer = food_search_interval
	_food_target = _find_nearest_berry_bush()

	if _food_target == null:
		return false

	print(
		"Grazer found berry bush at: ",
		_food_target.global_position
	)

	return true


func _prepare_water_target() -> bool:
	if _is_water_target_valid():
		return true

	_clear_water_target()

	if _water_search_timer > 0.0:
		return false

	_water_search_timer = water_search_interval

	if not _find_nearest_water_shore():
		return false

	print(
		"Grazer found water at: ",
		_water_target
	)

	return true


func _update_wandering(delta: float) -> void:
	_decision_timer -= delta

	if _decision_timer <= 0.0:
		_choose_new_behavior()


func _update_fleeing(delta: float) -> void:
	_decision_timer -= delta

	if is_instance_valid(_threat_target):
		_update_flee_direction()

	if _decision_timer > 0.0:
		return

	_threat_target = null
	_choose_new_behavior()


func _update_food_movement() -> void:
	if not _is_food_target_valid():
		_abandon_food_target(false)
		return

	var target_offset := (
		_food_target.global_position
		- global_position
	)

	target_offset.y = 0.0

	var distance_to_food := target_offset.length()

	var effective_reach_distance := maxf(
		food_reach_distance,
		2.5
	)

	if distance_to_food <= effective_reach_distance:
		_move_direction = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0

		_try_eat_food_target()
		return

	if distance_to_food > food_search_radius * 1.5:
		_abandon_food_target(false)
		return

	var target_direction := target_offset.normalized()

	if _is_direction_safe(target_direction):
		_move_direction = target_direction
	else:
		_abandon_food_target(true)


func _update_water_movement() -> void:
	if not _is_water_target_valid():
		_abandon_water_target()
		return

	var target_offset := (
		_water_target
		- global_position
	)

	target_offset.y = 0.0

	var distance_to_water := target_offset.length()

	if distance_to_water <= water_reach_distance:
		_move_direction = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0

		_drink_water()
		return

	if distance_to_water > water_search_radius * 1.5:
		_abandon_water_target()
		return

	var target_direction := target_offset.normalized()

	if _is_direction_safe(target_direction):
		_move_direction = target_direction
	else:
		_abandon_water_target()


func _try_eat_food_target() -> void:
	if not _is_food_target_valid():
		_abandon_food_target(false)
		return

	var target_instance_id := (
		_food_target.get_instance_id()
	)

	var hunger_before := current_hunger

	if _food_target.has_method("interact"):
		_food_target.call(
			"interact",
			self
		)

	if current_hunger > hunger_before:
		print(
			"Grazer ate berries. Hunger: ",
			current_hunger,
			" / ",
			maximum_hunger
		)
	else:
		_ignored_food_targets[
			target_instance_id
		] = true

	_food_target = null
	_food_search_timer = food_search_interval

	_choose_new_behavior()


func _drink_water() -> void:
	if not _is_water_target_valid():
		_abandon_water_target()
		return

	restore_thirst(water_drink_amount)

	print(
		"Grazer drank water. Thirst: ",
		current_thirst,
		" / ",
		maximum_thirst
	)

	_clear_water_target()

	_water_search_timer = water_search_interval

	_choose_new_behavior()


func _find_nearest_water_shore() -> bool:
	var radial_steps := maxi(
		1,
		floori(
			water_search_radius
			/ water_search_step
		)
	)

	for ring_index in range(
		1,
		radial_steps + 1
	):
		var search_distance := (
			float(ring_index)
			* water_search_step
		)

		var found_on_ring := false
		var best_position := Vector3.ZERO
		var best_distance_squared := INF

		for sample_index in range(water_search_samples):
			var angle := (
				TAU
				* float(sample_index)
				/ float(water_search_samples)
			)

			var search_direction := Vector3(
				sin(angle),
				0.0,
				cos(angle)
			)

			var candidate_position := (
				global_position
				+ search_direction
				* search_distance
			)

			var candidate_height := (
				WorldGenerator.get_terrain_height(
					candidate_position.x,
					candidate_position.z
				)
			)

			candidate_position.y = candidate_height + 0.05

			if not _is_shore_position(candidate_position):
				continue

			var distance_squared := (
				global_position.distance_squared_to(
					candidate_position
				)
			)

			if distance_squared >= best_distance_squared:
				continue

			best_distance_squared = distance_squared
			best_position = candidate_position
			found_on_ring = true

		if found_on_ring:
			_water_target = best_position
			_has_water_target = true
			return true

	return false


func _is_shore_position(position: Vector3) -> bool:
	var sea_level := WorldGenerator.get_sea_level()

	var land_height := (
		WorldGenerator.get_terrain_height(
			position.x,
			position.z
		)
	)

	if land_height <= sea_level + 0.20:
		return false

	for sample_index in range(8):
		var angle := (
			TAU
			* float(sample_index)
			/ 8.0
		)

		var check_direction := Vector3(
			sin(angle),
			0.0,
			cos(angle)
		)

		var water_check_position := (
			position
			+ check_direction
			* shoreline_check_distance
		)

		var nearby_height := (
			WorldGenerator.get_terrain_height(
				water_check_position.x,
				water_check_position.z
			)
		)

		if nearby_height <= sea_level:
			return true

	return false


func _find_nearest_berry_bush() -> Node3D:
	var candidates: Array[Node] = []

	for grouped_node in get_tree().get_nodes_in_group(
		"berry_bush"
	):
		candidates.append(grouped_node)

	if candidates.is_empty():
		var scene_root := get_tree().current_scene

		if scene_root != null:
			_collect_berry_bushes(
				scene_root,
				candidates
			)

	var nearest_bush: Node3D = null

	var nearest_distance_squared := (
		food_search_radius
		* food_search_radius
	)

	for candidate in candidates:
		if candidate is not Node3D:
			continue

		var candidate_3d := candidate as Node3D

		if not is_instance_valid(candidate_3d):
			continue

		if not candidate_3d.is_inside_tree():
			continue

		if candidate_3d.has_method(
			"has_food_available"
		):
			var food_available := bool(
				candidate_3d.call(
					"has_food_available"
				)
			)

			if not food_available:
				continue

		var candidate_id := candidate_3d.get_instance_id()

		if _ignored_food_targets.has(candidate_id):
			continue

		var distance_squared := (
			global_position.distance_squared_to(
				candidate_3d.global_position
			)
		)

		if distance_squared >= nearest_distance_squared:
			continue

		nearest_distance_squared = distance_squared
		nearest_bush = candidate_3d

	return nearest_bush


func _collect_berry_bushes(
	node: Node,
	result: Array[Node]
) -> void:
	for child in node.get_children():
		if _is_berry_bush(child):
			result.append(child)

		_collect_berry_bushes(
			child,
			result
		)


func _is_berry_bush(node: Node) -> bool:
	if node.is_in_group("berry_bush"):
		return true

	if node.scene_file_path == BERRY_BUSH_SCENE_PATH:
		return true

	var node_name := String(node.name)

	return node_name.begins_with("BerryBush")


func _is_food_target_valid() -> bool:
	if _food_target == null:
		return false

	if not is_instance_valid(_food_target):
		return false

	if not _food_target.is_inside_tree():
		return false

	if _food_target.has_method("has_food_available"):
		var food_available := bool(
			_food_target.call(
				"has_food_available"
			)
		)

		if not food_available:
			return false

	return true


func _is_water_target_valid() -> bool:
	if not _has_water_target:
		return false

	if (
		global_position.distance_to(_water_target)
		> water_search_radius * 1.5
	):
		return false

	return _is_shore_position(_water_target)


func _clear_food_target() -> void:
	_food_target = null


func _clear_water_target() -> void:
	_has_water_target = false
	_water_target = Vector3.ZERO


func _abandon_food_target(
	ignore_target: bool
) -> void:
	if (
		ignore_target
		and _is_food_target_valid()
	):
		_ignored_food_targets[
			_food_target.get_instance_id()
		] = true

	_clear_food_target()

	_food_search_timer = food_search_interval

	_choose_new_behavior()


func _abandon_water_target() -> void:
	_clear_water_target()

	_water_search_timer = water_search_interval

	_choose_new_behavior()


func interact(actor: Node) -> void:
	if actor == null:
		return

	if is_dead:
		_try_eat_corpse(actor)
		return

	if not actor.has_method("can_perform_action"):
		return

	var can_bite := bool(
		actor.call(
			"can_perform_action",
			&"bite"
		)
	)

	if not can_bite:
		print(
			"Grazer interaction blocked. Missing ability: bite"
		)
		return

	receive_hit(
		bite_damage,
		actor
	)


func _try_eat_corpse(actor: Node) -> void:
	if remaining_meat_portions <= 0:
		queue_free()
		return

	if not actor.has_method("can_perform_action"):
		return

	var can_eat := bool(
		actor.call(
			"can_perform_action",
			&"eat"
		)
	)

	if not can_eat:
		print(
			"Grazer corpse interaction blocked. Missing ability: eat"
		)
		return

	if not actor.has_method("restore_hunger"):
		print("Actor cannot restore hunger.")
		return

	if actor.has_method("get_hunger_ratio"):
		var hunger_ratio := float(
			actor.call("get_hunger_ratio")
		)

		if hunger_ratio >= 0.999:
			print("Actor is not hungry.")
			return

	actor.call(
		"restore_hunger",
		hunger_restore_per_portion
	)

	remaining_meat_portions -= 1

	print(
		"Grazer meat eaten. Remaining portions: ",
		remaining_meat_portions
	)

	if remaining_meat_portions <= 0:
		print("Grazer carcass consumed.")
		queue_free()


func can_perform_action(
	action: StringName
) -> bool:
	return action == &"eat"


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


func get_hunger_ratio() -> float:
	if maximum_hunger <= 0.0:
		return 0.0

	return current_hunger / maximum_hunger


func get_thirst_ratio() -> float:
	if maximum_thirst <= 0.0:
		return 0.0

	return current_thirst / maximum_thirst


func receive_hit(
	damage: float,
	attacker: Node = null
) -> void:
	if is_dead:
		return

	if damage <= 0.0:
		return

	current_health = maxf(
		current_health - damage,
		0.0
	)

	print(
		"Grazer hit. Remaining health: ",
		current_health
	)

	if current_health <= 0.0:
		_die()
		return

	if attacker != null:
		_flee_from(attacker)


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	current_health = 0.0

	_is_pregnant = false
	_pregnancy_timer = 0.0
	_pregnancy_father_seed = 0

	_update_life_cycle_states()

	_clear_mate_target()
	_clear_food_target()
	_clear_water_target()

	_threat_target = null
	_move_direction = Vector3.ZERO
	_decision_timer = 0.0

	velocity.x = 0.0
	velocity.z = 0.0

	_apply_corpse_material()

	print(
		"Grazer died. Meat portions available: ",
		remaining_meat_portions
	)


func _flee_from(attacker: Node) -> void:
	if attacker is not Node3D:
		_choose_new_behavior()
		return

	_start_fleeing_from(
		attacker as Node3D
	)


func _choose_new_behavior() -> void:
	_threat_target = null
	_behavior_state = BehaviorState.WANDERING

	_decision_timer = _random.randf_range(
		minimum_wander_time,
		maximum_wander_time
	)

	if _random.randf() < idle_probability:
		_move_direction = Vector3.ZERO
		return

	for _attempt in range(8):
		var angle := _random.randf_range(
			0.0,
			TAU
		)

		var candidate_direction := Vector3(
			sin(angle),
			0.0,
			cos(angle)
		).normalized()

		if _is_direction_safe(candidate_direction):
			_move_direction = candidate_direction
			return

	_move_direction = Vector3.ZERO


func _is_direction_safe(direction: Vector3) -> bool:
	if direction.length_squared() <= 0.001:
		return true

	var check_position := (
		global_position
		+ direction.normalized()
		* terrain_check_distance
	)

	var current_height := (
		WorldGenerator.get_terrain_height(
			global_position.x,
			global_position.z
		)
	)

	var next_height := (
		WorldGenerator.get_terrain_height(
			check_position.x,
			check_position.z
		)
	)

	if (
		next_height
		<= WorldGenerator.get_sea_level() + 0.20
	):
		return false

	if (
		absf(next_height - current_height)
		> maximum_step_height
	):
		return false

	return true


func _generate_creature() -> void:
	var generated_length := maxi(
		4,
		body_length_voxels
		+ _random.randi_range(-1, 1)
	)

	var generated_width := maxi(
		2,
		body_width_voxels
		+ _random.randi_range(-1, 1)
	)

	var generated_height := maxi(
		2,
		body_height_voxels
		+ _random.randi_range(-1, 1)
	)

	var generated_leg_height := maxi(
		2,
		leg_height_voxels
		+ _random.randi_range(-1, 1)
	)

	var surface_tool := SurfaceTool.new()

	surface_tool.begin(
		Mesh.PRIMITIVE_TRIANGLES
	)

	_add_body(
		surface_tool,
		generated_length,
		generated_width,
		generated_height,
		generated_leg_height
	)

	_add_legs(
		surface_tool,
		generated_length,
		generated_width,
		generated_leg_height
	)

	_add_head(
		surface_tool,
		generated_length,
		generated_height,
		generated_leg_height
	)

	_add_tail(
		surface_tool,
		generated_length,
		generated_height,
		generated_leg_height
	)

	surface_tool.index()

	var generated_mesh: ArrayMesh = (
		surface_tool.commit()
	)

	if generated_mesh == null:
		push_error(
			"Grazer mesh could not be generated."
		)
		return

	body_mesh.mesh = generated_mesh

	_apply_material()

	_create_collision(
		generated_length,
		generated_width,
		generated_height,
		generated_leg_height
	)


func _add_body(
	surface_tool: SurfaceTool,
	length: int,
	width: int,
	height: int,
	leg_height: int
) -> void:
	for voxel_y in range(height):
		for voxel_x in range(width):
			for voxel_z in range(length):
				var center := Vector3(
					(
						float(voxel_x)
						- float(width - 1)
						* 0.5
					)
					* voxel_size,
					(
						float(leg_height)
						+ float(voxel_y)
						+ 0.5
					)
					* voxel_size,
					(
						float(voxel_z)
						- float(length - 1)
						* 0.5
					)
					* voxel_size
				)

				var color := _vary_color(
					BODY_COLOR,
					0.10
				)

				if voxel_y == 0:
					color = _vary_color(
						BELLY_COLOR,
						0.08
					)

				_add_voxel(
					surface_tool,
					center,
					voxel_size,
					color
				)


func _add_legs(
	surface_tool: SurfaceTool,
	length: int,
	width: int,
	leg_height: int
) -> void:
	var leg_x := (
		float(width - 1)
		* voxel_size
		* 0.5
	)

	var leg_z := (
		float(length - 2)
		* voxel_size
		* 0.5
	)

	var leg_positions: Array[Vector2] = [
		Vector2(-leg_x, -leg_z),
		Vector2(leg_x, -leg_z),
		Vector2(-leg_x, leg_z),
		Vector2(leg_x, leg_z)
	]

	for leg_position in leg_positions:
		for voxel_y in range(leg_height):
			var center := Vector3(
				leg_position.x,
				(
					float(voxel_y)
					+ 0.5
				)
				* voxel_size,
				leg_position.y
			)

			_add_voxel(
				surface_tool,
				center,
				voxel_size,
				_vary_color(
					BODY_COLOR,
					0.08
				)
			)


func _add_head(
	surface_tool: SurfaceTool,
	length: int,
	height: int,
	leg_height: int
) -> void:
	var head_center_y := (
		float(leg_height)
		+ float(height)
		* 0.72
	) * voxel_size

	var head_center_z := (
		-float(length)
		* 0.5
		- 0.75
	) * voxel_size

	for voxel_y in range(2):
		for voxel_x in range(2):
			for voxel_z in range(2):
				var center := Vector3(
					(
						float(voxel_x)
						- 0.5
					)
					* voxel_size,
					head_center_y
					+ float(voxel_y)
					* voxel_size,
					head_center_z
					- float(voxel_z)
					* voxel_size
				)

				_add_voxel(
					surface_tool,
					center,
					voxel_size,
					_vary_color(
						BODY_COLOR,
						0.10
					)
				)

	var eye_y := (
		head_center_y
		+ voxel_size
		* 0.75
	)

	var eye_z := (
		head_center_z
		- voxel_size
		* 1.05
	)

	for side in [-1.0, 1.0]:
		_add_voxel(
			surface_tool,
			Vector3(
				side
				* voxel_size
				* 0.58,
				eye_y,
				eye_z
			),
			voxel_size * 0.35,
			EYE_COLOR
		)


func _add_tail(
	surface_tool: SurfaceTool,
	length: int,
	height: int,
	leg_height: int
) -> void:
	var tail_y := (
		float(leg_height)
		+ float(height)
		* 0.65
	) * voxel_size

	var tail_z := (
		float(length)
		* 0.5
		+ 0.5
	) * voxel_size

	for tail_part in range(2):
		_add_voxel(
			surface_tool,
			Vector3(
				0.0,
				tail_y
				- float(tail_part)
				* voxel_size
				* 0.35,
				tail_z
				+ float(tail_part)
				* voxel_size
			),
			voxel_size * 0.75,
			_vary_color(
				BODY_COLOR,
				0.10
			)
		)


func _add_voxel(
	surface_tool: SurfaceTool,
	center: Vector3,
	size: float,
	color: Color
) -> void:
	var half_size := size * 0.5

	var left := center.x - half_size
	var right := center.x + half_size
	var bottom := center.y - half_size
	var top := center.y + half_size
	var front := center.z - half_size
	var back := center.z + half_size

	_add_face(
		surface_tool,
		Vector3(right, bottom, front),
		Vector3(right, top, front),
		Vector3(right, top, back),
		Vector3(right, bottom, back),
		Vector3.RIGHT,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, bottom, back),
		Vector3(left, top, back),
		Vector3(left, top, front),
		Vector3(left, bottom, front),
		Vector3.LEFT,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, top, front),
		Vector3(left, top, back),
		Vector3(right, top, back),
		Vector3(right, top, front),
		Vector3.UP,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, bottom, back),
		Vector3(left, bottom, front),
		Vector3(right, bottom, front),
		Vector3(right, bottom, back),
		Vector3.DOWN,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, bottom, front),
		Vector3(left, top, front),
		Vector3(right, top, front),
		Vector3(right, bottom, front),
		Vector3.FORWARD,
		color
	)

	_add_face(
		surface_tool,
		Vector3(right, bottom, back),
		Vector3(right, top, back),
		Vector3(left, top, back),
		Vector3(left, bottom, back),
		Vector3.BACK,
		color
	)


func _add_face(
	surface_tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	point_d: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	_add_mesh_vertex(
		surface_tool,
		point_a,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_b,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_c,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_a,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_c,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_d,
		normal,
		color
	)


func _add_mesh_vertex(
	surface_tool: SurfaceTool,
	vertex_position: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	surface_tool.set_normal(normal)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_position)


func _apply_material() -> void:
	var material := StandardMaterial3D.new()

	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0

	body_mesh.material_override = material


func _apply_corpse_material() -> void:
	var material := StandardMaterial3D.new()

	material.albedo_color = CORPSE_TINT
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0

	body_mesh.material_override = material


func _create_collision(
	length: int,
	width: int,
	height: int,
	leg_height: int
) -> void:
	var collision_shape := BoxShape3D.new()

	var collision_height := (
		float(leg_height + height)
		* voxel_size
	)

	collision_shape.size = Vector3(
		float(width) * voxel_size,
		collision_height,
		float(length + 1) * voxel_size
	)

	body_collision.shape = collision_shape

	body_collision.position = Vector3(
		0.0,
		collision_height * 0.5,
		-voxel_size * 0.25
	)


func _snap_to_terrain() -> void:
	var terrain_height := (
		WorldGenerator.get_terrain_height(
			global_position.x,
			global_position.z
		)
	)

	global_position.y = terrain_height + 0.05


func _vary_color(
	base_color: Color,
	variation: float
) -> Color:
	var value := _random.randf_range(
		-variation,
		variation
	)

	if value >= 0.0:
		return base_color.lerp(
			Color.WHITE,
			value
		)

	return base_color.lerp(
		Color.BLACK,
		-value
	)


func _get_creature_seed() -> int:
	return (
		GameState.world_seed
		* 59
		+ int(
			round(
				global_position.x
				* 100.0
			)
		)
		* 73_856_093
		+ int(
			round(
				global_position.z
				* 100.0
			)
		)
		* 19_349_663
	)
