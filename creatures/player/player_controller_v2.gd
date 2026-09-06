extends "res://creatures/player/player_controller.gd"

signal inspection_mode_changed(enabled: bool)

@export_category("Inspection")
@export_range(4.0, 40.0, 1.0) var inspection_radius: float = 18.0

var inspection_mode_enabled: bool = false


func _ready() -> void:
	super._ready()
	# Terrain uses layer 1, modular wildlife uses layer value 4. The old ray only
	# queried layer 1, so observing and biting wildlife often never reached it.
	interaction_ray.collision_mask = 5
	interaction_ray.collide_with_bodies = true
	interaction_ray.collide_with_areas = true


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event.is_action_pressed("inspection_mode"):
		inspection_mode_enabled = not inspection_mode_enabled
		inspection_mode_changed.emit(inspection_mode_enabled)
		show_gameplay_message(
			"Inspection mode enabled" if inspection_mode_enabled else "Inspection mode disabled",
			1.4
		)


func _try_primary_action() -> void:
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return
	var collision_point: Vector3 = interaction_ray.get_collision_point()
	if global_position.distance_to(collision_point) > interaction_range:
		return
	if WorldGenerator.is_below_sea_level(collision_point.x, collision_point.z):
		_try_drink_water()
		return
	var target: Node = _resolve_interaction_target(interaction_ray.get_collider())
	if target != null and target.has_method("interact"):
		target.call("interact", self)


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
	var target: Node = _resolve_interaction_target(interaction_ray.get_collider())
	if target == null or not target.has_method("receive_creature_attack"):
		show_gameplay_message("That cannot be bitten.", 1.2)
		return
	_bite_cooldown_timer = bite_cooldown
	var damage: float = clampf(attack_power * bite_damage_scale, 2.0, 80.0)
	_trigger_bite_animation()
	target.call("receive_creature_attack", damage, self)
	creature_attacked.emit(target, damage)


func get_interaction_target() -> Node:
	if interaction_ray == null:
		return null
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return null
	return _resolve_interaction_target(interaction_ray.get_collider())


func get_nearby_wildlife(maximum_count: int = 8) -> Array[Node3D]:
	var candidates: Array[Node3D] = []
	for value in get_tree().get_nodes_in_group(&"wildlife"):
		var creature := value as Node3D
		if creature == null or not is_instance_valid(creature):
			continue
		if global_position.distance_to(creature.global_position) > inspection_radius:
			continue
		candidates.append(creature)
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	if candidates.size() > maximum_count:
		candidates.resize(maximum_count)
	return candidates


func is_inspection_mode_enabled() -> bool:
	return inspection_mode_enabled


func _resolve_interaction_target(collider_value: Variant) -> Node:
	var current := collider_value as Node
	var depth: int = 0
	while current != null and depth < 8:
		if (
			current.has_method("receive_creature_attack")
			or current.has_method("interact")
			or current.is_in_group(&"wildlife")
		):
			return current
		current = current.get_parent()
		depth += 1
	return null


func _trigger_bite_animation() -> void:
	var animator := get_node_or_null("AdaptiveLocomotionAnimator")
	if animator != null and animator.has_method("trigger_bite"):
		animator.call("trigger_bite")
