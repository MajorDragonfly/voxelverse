extends CharacterBody3D

const EvolutionGenerator = preload("res://creatures/editor/creature_evolution_generator.gd")
const BlueprintV5 = preload("res://creatures/editor/creature_blueprint_v5.gd")
const AttachmentNormalizer = preload("res://creatures/editor/creature_attachment_normalizer.gd")
const RuntimePreview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")

@export var species_seed: int = 1
@export var individual_seed: int = 1
@export_range(0.5, 8.0, 0.1) var base_move_speed: float = 1.8
@export_range(0.5, 12.0, 0.5) var gravity_strength: float = 18.0
@export_range(0.1, 1.0, 0.05) var visual_scale_min: float = 0.42
@export_range(0.1, 1.2, 0.05) var visual_scale_max: float = 0.72

var blueprint: Dictionary = {}
var _visual_root: Node3D
var _preview: Node3D
var _random := RandomNumberGenerator.new()
var _wander_direction := Vector3.ZERO
var _decision_timer: float = 0.0
var _move_speed: float = 1.8


func _ready() -> void:
	add_to_group(&"wildlife")
	add_to_group(&"streamed_fauna")
	floor_snap_length = 0.48
	floor_max_angle = deg_to_rad(50.0)
	_random.seed = individual_seed * 97_409 + species_seed
	_build_species()
	_choose_wander_state()


func configure(new_species_seed: int, new_individual_seed: int) -> void:
	species_seed = new_species_seed
	individual_seed = new_individual_seed


func _build_species() -> void:
	var archetypes: Array[String] = [
		"grazer",
		"predator",
		"sprinter",
		"armored",
		"insectoid",
		"serpent",
	]
	var archetype_index: int = posmod(species_seed, archetypes.size())
	blueprint = EvolutionGenerator.generate(
		species_seed,
		archetypes[archetype_index]
	)
	BlueprintV5.normalize(blueprint)
	AttachmentNormalizer.normalize(blueprint, true)

	_visual_root = Node3D.new()
	_visual_root.name = "SpeciesVisual"
	add_child(_visual_root)

	_preview = RuntimePreview.new()
	_preview.name = "ProceduralCreature"
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
		base_move_speed + float(stats.get("speed", 5.0)) * 0.18,
		0.9,
		4.2
	)


func _physics_process(delta: float) -> void:
	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_choose_wander_state()

	velocity.x = _wander_direction.x * _move_speed
	velocity.z = _wander_direction.z * _move_speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity_strength * delta

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


func _choose_wander_state() -> void:
	_decision_timer = _random.randf_range(2.0, 5.5)
	if _random.randf() < 0.24:
		_wander_direction = Vector3.ZERO
		return
	var angle: float = _random.randf_range(0.0, TAU)
	_wander_direction = Vector3(cos(angle), 0.0, sin(angle)).normalized()


func _disable_collisions(root: Node) -> void:
	var collision_object := root as CollisionObject3D
	if collision_object != null:
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
		collision_object.input_ray_pickable = false
	for child in root.get_children():
		_disable_collisions(child)
