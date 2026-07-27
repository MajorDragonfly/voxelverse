extends CharacterBody3D

const SpeciesFactory = preload(
	"res://creatures/wildlife/species_assembly_factory_v7.gd"
)
const RuntimePreview = preload(
	"res://creatures/runtime/creature_runtime_preview.gd"
)
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")

@export var species_seed: int = 1
@export var individual_seed: int = 1
@export var region_coordinates: Vector2i = Vector2i.ZERO
@export var requested_role: String = "auto"
@export_range(0.5, 8.0, 0.1) var base_move_speed: float = 1.7
@export_range(0.5, 12.0, 0.5) var gravity_strength: float = 18.0
@export_range(0.1, 1.0, 0.05) var visual_scale_min: float = 0.42
@export_range(0.1, 1.2, 0.05) var visual_scale_max: float = 0.72
@export_range(0.1, 0.8, 0.05) var maximum_step_height: float = 0.42

var blueprint: Dictionary = {}
var ecological_role: String = "forager"
var _visual_root: Node3D
var _preview: Node3D
var _player: Node3D
var _random := RandomNumberGenerator.new()
var _wander_direction := Vector3.ZERO
var _decision_timer: float = 0.0
var _move_speed: float = 1.7


func configure(
	new_species_seed: int,
	new_individual_seed: int,
	new_region_coordinates: Vector2i = Vector2i.ZERO,
	new_role: String = "auto"
) -> void:
	species_seed = new_species_seed
	individual_seed = new_individual_seed
	region_coordinates = new_region_coordinates
	requested_role = new_role


func _ready() -> void:
	add_to_group(&"wildlife")
	add_to_group(&"streamed_fauna")
	floor_snap_length = maximum_step_height + 0.10
	floor_max_angle = deg_to_rad(50.0)
	floor_constant_speed = true
	_random.seed = individual_seed * 97_409 + species_seed
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	_build_species()
	_choose_wander_state()


func _build_species() -> void:
	blueprint = SpeciesFactory.create_species(
		species_seed,
		region_coordinates,
		requested_role
	)
	ecological_role = SpeciesFactory.get_role(blueprint)
	add_to_group(StringName("wildlife_%s" % ecological_role))

	_visual_root = Node3D.new()
	_visual_root.name = "SpeciesVisual"
	add_child(_visual_root)
	_preview = RuntimePreview.new()
	_preview.name = "ModularWildlifeCreature"
	var size_random := RandomNumberGenerator.new()
	size_random.seed = individual_seed + species_seed * 31
	var individual_scale: float = size_random.randf_range(
		visual_scale_min,
		visual_scale_max
	)
	_preview.scale = Vector3.ONE * individual_scale
	_preview.position = Vector3(0.0, 0.72 * individual_scale, 0.0)
	_visual_root.add_child(_preview)
	if _preview.has_method("set_editor_state"):
		_preview.call("set_editor_state", blueprint, -1, -1, false)
	else:
		_preview.call("set_blueprint", blueprint)
	_disable_collisions(_preview)

	var stats: Dictionary = Blueprint.calculate_stats(blueprint)
	_move_speed = clampf(
		base_move_speed + float(stats.get("speed", 5.0)) * 0.17,
		0.9,
		4.4
	)
	match ecological_role:
		"predator":
			_move_speed *= 1.15
		"grazer":
			_move_speed *= 0.90
		"climber":
			maximum_step_height = 0.56
		"swimmer":
			_move_speed *= 1.05


func _physics_process(delta: float) -> void:
	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_choose_wander_state()
	_update_role_direction()
	velocity.x = _wander_direction.x * _move_speed
	velocity.z = _wander_direction.z * _move_speed
	var grounded_before_move: bool = is_on_floor()
	if grounded_before_move:
		velocity.y = 0.0
	else:
		velocity.y -= gravity_strength * delta
	if grounded_before_move:
		_attempt_step_up(delta)
	move_and_slide()
	if is_on_floor():
		apply_floor_snap()
	if _visual_root != null and _wander_direction.length_squared() > 0.01:
		var target_yaw: float = atan2(-_wander_direction.x, -_wander_direction.z)
		_visual_root.rotation.y = lerp_angle(
			_visual_root.rotation.y,
			target_yaw,
			clampf(delta * 4.5, 0.0, 1.0)
		)
	if get_slide_collision_count() > 0 and is_on_floor():
		_wander_direction = _wander_direction.rotated(
			Vector3.UP,
			_random.randf_range(0.7, 2.2)
		)


func _update_role_direction() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		return
	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	if distance <= 0.01:
		return
	if ecological_role == "predator" and distance < 13.0:
		_wander_direction = to_player.normalized()
	elif ecological_role in ["grazer", "forager"] and distance < 6.0:
		_wander_direction = -to_player.normalized()


func _choose_wander_state() -> void:
	_decision_timer = _random.randf_range(2.0, 5.5)
	var idle_chance: float = 0.24
	if ecological_role == "predator":
		idle_chance = 0.10
	elif ecological_role == "grazer":
		idle_chance = 0.34
	if _random.randf() < idle_chance:
		_wander_direction = Vector3.ZERO
		return
	var angle: float = _random.randf_range(0.0, TAU)
	_wander_direction = Vector3(cos(angle), 0.0, sin(angle)).normalized()


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
	var forward_transform: Transform3D = raised_transform.translated(
		horizontal_motion
	)
	if not test_move(
		forward_transform,
		Vector3.DOWN * (maximum_step_height + 0.10)
	):
		return false
	global_transform = raised_transform
	return true


func _disable_collisions(root: Node) -> void:
	var collision_object := root as CollisionObject3D
	if collision_object != null:
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
		collision_object.input_ray_pickable = false
	for child in root.get_children():
		_disable_collisions(child)
