extends CharacterBody3D

const SpeciesFactory = preload(
	"res://creatures/wildlife/species_assembly_factory_v7.gd"
)
const RuntimePreview = preload(
	"res://creatures/runtime/creature_runtime_preview.gd"
)
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const PartLibrary = preload("res://creatures/editor/creature_part_library.gd")

@export var species_seed: int = 1
@export var individual_seed: int = 1
@export var region_coordinates: Vector2i = Vector2i.ZERO
@export var requested_role: String = "auto"
@export_range(0.5, 8.0, 0.1) var base_move_speed: float = 1.7
@export_range(0.5, 12.0, 0.5) var gravity_strength: float = 18.0
@export_range(0.1, 1.0, 0.05) var visual_scale_min: float = 0.42
@export_range(0.1, 1.2, 0.05) var visual_scale_max: float = 0.72
@export_range(0.1, 0.8, 0.05) var maximum_step_height: float = 0.42

@export_category("Behaviour")
@export_range(0.5, 4.0, 0.1) var predator_attack_distance: float = 1.55
@export_range(0.2, 5.0, 0.1) var predator_attack_cooldown: float = 1.35
@export_range(0.0, 50.0, 0.5) var predator_attack_damage: float = 7.0
@export_range(1.0, 12.0, 0.5) var threat_memory_seconds: float = 6.0

@export_category("Combat / Carcass")
@export_range(0.1, 2.0, 0.05) var health_stat_multiplier: float = 0.58
@export_range(5.0, 100.0, 1.0) var carcass_bite_nutrition: float = 18.0

var blueprint: Dictionary = {}
var _campaign_identity: Dictionary = {}
var ecological_role: String = "forager"
var maximum_health: float = 40.0
var current_health: float = 40.0
var is_dead: bool = false
var carcass_food_remaining: float = 0.0

var _visual_root: Node3D
var _preview: Node3D
var _player: Node3D
var _threat: Node3D
var _random := RandomNumberGenerator.new()
var _wander_direction := Vector3.ZERO
var _decision_timer: float = 0.0
var _move_speed: float = 1.7
var _attack_timer: float = 0.0
var _threat_timer: float = 0.0


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
	_campaign_identity = _create_campaign_identity()
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
	maximum_health = clampf(
		float(stats.get("health", 75.0)) * health_stat_multiplier,
		20.0,
		180.0
	)
	current_health = maximum_health
	match ecological_role:
		"predator": _move_speed *= 1.15
		"grazer": _move_speed *= 0.90
		"climber": maximum_step_height = 0.56
		"swimmer": _move_speed *= 1.05


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_threat_timer = maxf(_threat_timer - delta, 0.0)
	if is_dead:
		_process_carcass(delta)
		return
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


func interact(actor: Node) -> void:
	if actor == null:
		return
	if is_dead:
		_try_feed_actor_from_carcass(actor)
		return
	if actor.has_method("can_perform_action"):
		if not bool(actor.call("can_perform_action", &"socialize")):
			return
	var key_hints = preload("res://core/input_preferences.gd")
	_show_actor_message(actor, "%s · Scanmodus öffnen und das Tier im Fadenkreuz halten." % key_hints.binding_label("inspection_mode"))


func receive_creature_attack(damage: float, attacker: Node = null) -> void:
	if is_dead or damage <= 0.0:
		return
	if attacker != null:
		_threat = attacker as Node3D
		_threat_timer = threat_memory_seconds
	current_health = maxf(current_health - damage, 0.0)
	if attacker != null:
		_show_actor_message(
			attacker,
			"Bite hit · %d damage · %d/%d health" % [
				roundi(damage),
				roundi(current_health),
				roundi(maximum_health),
			]
		)
	if current_health <= 0.0:
		_die(attacker)


func get_health_ratio() -> float:
	return current_health / maxf(maximum_health, 0.001)


func _update_role_direction() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if _threat_timer > 0.0 and _threat != null and is_instance_valid(_threat):
		var threat_delta: Vector3 = _threat.global_position - global_position
		threat_delta.y = 0.0
		if threat_delta.length_squared() > 0.01:
			if ecological_role == "predator":
				_wander_direction = threat_delta.normalized()
				if threat_delta.length() <= predator_attack_distance:
					_try_predator_attack(_threat)
			else:
				_wander_direction = -threat_delta.normalized()
		return
	if _player == null or not is_instance_valid(_player):
		return
	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	if distance <= 0.01:
		return
	if ecological_role == "predator" and distance < 13.0:
		_wander_direction = to_player.normalized()
		if distance <= predator_attack_distance:
			_try_predator_attack(_player)
	elif ecological_role in ["grazer", "forager"] and distance < 6.0:
		_wander_direction = -to_player.normalized()


func _try_predator_attack(target: Node) -> void:
	if _attack_timer > 0.0 or target == null:
		return
	if not target.has_method("receive_damage"):
		return
	_attack_timer = predator_attack_cooldown
	target.call("receive_damage", predator_attack_damage)
	_show_actor_message(
		target,
		"A predator hit you for %d." % roundi(predator_attack_damage)
	)


func _die(killer: Node = null) -> void:
	if is_dead:
		return
	is_dead = true
	current_health = 0.0
	velocity = Vector3.ZERO
	carcass_food_remaining = clampf(maximum_health * 0.55, 20.0, 90.0)
	_wander_direction = Vector3.ZERO
	_register_ecology_death()
	if killer != null:
		_show_actor_message(killer, "Creature defeated · carcass can be eaten.")


func _process_carcass(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity_strength * delta
	move_and_slide()
	if _visual_root != null:
		_visual_root.rotation.z = lerp_angle(
			_visual_root.rotation.z,
			deg_to_rad(72.0),
			clampf(delta * 3.5, 0.0, 1.0)
		)


func _try_feed_actor_from_carcass(actor: Node) -> void:
	if carcass_food_remaining <= 0.01:
		queue_free()
		return
	if not actor.has_method("consume_food"):
		return
	var serving: float = minf(carcass_bite_nutrition, carcass_food_remaining)
	var consumed: bool = bool(actor.call("consume_food", "meat", serving))
	if not consumed:
		return
	carcass_food_remaining = maxf(carcass_food_remaining - serving, 0.0)
	if carcass_food_remaining <= 0.01:
		_show_actor_message(actor, "Carcass consumed.")
		queue_free()
	else:
		_show_actor_message(
			actor,
			"Carcass remaining: %d" % roundi(carcass_food_remaining)
		)


func _register_ecology_death() -> void:
	var simulation := get_tree().get_first_node_in_group(&"region_background_simulation")
	if simulation == null:
		return
	if simulation.has_method("register_wildlife_loss"):
		simulation.call(
			"register_wildlife_loss",
			region_coordinates,
			species_seed,
			1.0
		)
	if simulation.has_method("register_carcass_addition"):
		simulation.call(
			"register_carcass_addition",
			region_coordinates,
			clampf(carcass_food_remaining / 160.0, 0.02, 0.35)
		)


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
	var forward_transform: Transform3D = raised_transform.translated(horizontal_motion)
	if not test_move(
		forward_transform,
		Vector3.DOWN * (maximum_step_height + 0.10)
	):
		return false
	global_transform = raised_transform
	return true


func _show_actor_message(actor: Node, message: String) -> void:
	if actor != null and actor.has_method("show_gameplay_message"):
		actor.call("show_gameplay_message", message)


func _disable_collisions(root: Node) -> void:
	var collision_object := root as CollisionObject3D
	if collision_object != null:
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
		collision_object.input_ray_pickable = false
	for child in root.get_children():
		_disable_collisions(child)


func get_campaign_identity() -> Dictionary:
	return _campaign_identity.duplicate(true)


func _create_campaign_identity() -> Dictionary:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return {}
	var campaign = state.get("campaign")
	var body: Dictionary = state.call("get_current_body")
	var region: String = campaign.region_id(body["id"], region_coordinates)
	return {"object_id": campaign.object_id(region, "wildlife:%d:%d" % [species_seed, individual_seed]),
		"species_id": campaign.species_id(body["id"], species_seed), "body_id": body["id"], "region_id": region,
		"design_ref": {"design_id": blueprint.get("design_id", ""), "revision": 0}}
