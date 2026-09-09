extends "res://creatures/wildlife/procedural_wildlife_v7.gd"

const InspectionBlueprint = preload("res://creatures/editor/creature_blueprint.gd")

signal health_changed(current_health: float, maximum_health: float)
signal creature_defeated(creature: Node)

@export_category("Combat Feedback")
@export_range(0.05, 0.80, 0.01) var hit_reaction_duration: float = 0.20
@export_range(0.0, 30.0, 1.0) var hit_reaction_degrees: float = 11.0

var _hit_reaction_remaining: float = 0.0


func receive_creature_attack(damage: float, attacker: Node = null) -> void:
	if is_dead or damage <= 0.0:
		return
	if attacker != null and attacker.is_in_group(&"player") and get_node("/root/GameState").current_phase == 0:
		get_node("SocialBehavior").receive_player_attack(damage, attacker)
		return
	var was_alive: bool = not is_dead
	super.receive_creature_attack(damage, attacker)
	_hit_reaction_remaining = hit_reaction_duration
	health_changed.emit(current_health, maximum_health)
	if was_alive and is_dead:
		creature_defeated.emit(self)


func show_behavior_hit() -> void:
	_hit_reaction_remaining = hit_reaction_duration
	health_changed.emit(current_health, maximum_health)
	if is_dead:
		creature_defeated.emit(self)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _hit_reaction_remaining <= 0.0:
		return
	_hit_reaction_remaining = maxf(_hit_reaction_remaining - delta, 0.0)
	if _visual_root == null or not is_instance_valid(_visual_root) or is_dead:
		return
	var envelope: float = sin(
		(1.0 - _hit_reaction_remaining / maxf(hit_reaction_duration, 0.05)) * PI
	)
	_visual_root.rotation.x = deg_to_rad(hit_reaction_degrees) * envelope


func get_display_name() -> String:
	var species: Dictionary = blueprint.get("species", {})
	return str(species.get("display_name", blueprint.get("name", "Unknown Creature")))


func get_target_health_data() -> Dictionary:
	return {
		"name": get_display_name(),
		"current_health": current_health,
		"maximum_health": maximum_health,
		"health_ratio": get_health_ratio(),
		"dead": is_dead,
	}


func get_inspection_data() -> Dictionary:
	var stats: Dictionary = InspectionBlueprint.calculate_stats(blueprint)
	var species: Dictionary = blueprint.get("species", {})
	var body_shape: Vector3 = InspectionBlueprint.get_body_shape(blueprint)
	return {
		"name": get_display_name(),
		"domestication": species.get("domestication", {}).duplicate(true),
		"role": ecological_role,
		"species_seed": species_seed,
		"region": region_coordinates,
		"alive": not is_dead,
		"health": current_health,
		"maximum_health": maximum_health,
		"speed": float(stats.get("speed", 0.0)),
		"jump": float(stats.get("jump", 0.0)),
		"attack": float(stats.get("attack", 0.0)),
		"defense": float(stats.get("defense", 0.0)),
		"perception": float(stats.get("perception", 0.0)),
		"grip": float(stats.get("grip", 0.0)),
		"diet_plant": float(stats.get("diet_plant", 0.0)),
		"diet_meat": float(stats.get("diet_meat", 0.0)),
		"swim": float(stats.get("swim", 0.0)),
		"body_width": body_shape.x,
		"body_height": body_shape.y,
		"body_length": body_shape.z,
		"part_count": InspectionBlueprint.get_part_count(blueprint),
		"ecological_role": str(species.get("ecological_role", ecological_role)),
	}
