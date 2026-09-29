extends "res://creatures/player/player_controller.gd"
const ScanCircle = preload("res://core/discovery/scan_circle_geometry.gd")

signal inspection_mode_changed(enabled: bool)

@export_category("Inspection")
@export_range(4.0, 40.0, 1.0) var inspection_radius: float = 20.0
@export_range(10.0, 100.0, 1.0) var inspection_cone_degrees: float = 42.0

@export_category("Third-Person Targeting")
@export_range(6.0, 30.0, 0.5) var camera_target_distance: float = 14.0
@export_range(1.0, 6.0, 0.1) var bite_reach: float = 3.6
@export_range(20.0, 120.0, 1.0) var bite_cone_degrees: float = 72.0
@export_range(0.1, 2.0, 0.05) var target_center_height: float = 0.70

var inspection_mode_enabled: bool = false
var _gameplay_camera: Camera3D
var last_scan_rays: int = 0
var _scan_target_pixel: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	_gameplay_camera = get_node_or_null(
		"CameraPivot/SpringArm3D/Camera3D"
	) as Camera3D

	# The camera sits several metres behind the player. The old ray was only
	# 3.2 m long, so it ended before it even reached the creature being played.
	# Keep a long camera ray for observation and use a player-centred cone for
	# close combat.
	interaction_ray.collision_mask = 5
	interaction_ray.collide_with_bodies = true
	interaction_ray.collide_with_areas = true
	interaction_ray.target_position = Vector3(
		0.0,
		0.0,
		-maxf(camera_target_distance, interaction_range + 8.0)
	)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead: return
	super._unhandled_input(event)
	if _is_inspection_toggle_event(event):
		toggle_inspection_mode()
		get_viewport().set_input_as_handled()


func toggle_inspection_mode() -> bool:
	if is_dead: return inspection_mode_enabled
	inspection_mode_enabled = not inspection_mode_enabled
	inspection_mode_changed.emit(inspection_mode_enabled)
	show_gameplay_message(
		"Scanmodus aktiviert" if inspection_mode_enabled else "Scanmodus deaktiviert",
		1.4
	)
	return inspection_mode_enabled


func _try_primary_action() -> void:
	# Observation is intentionally more forgiving than physical interaction.
	# A creature can be observed from inspection range even if the camera ray
	# passes just above a small procedural body.
	var wildlife_target: Node = _get_camera_wildlife_target(inspection_radius)
	if wildlife_target == null:
		wildlife_target = _find_wildlife_target(
			inspection_radius,
			inspection_cone_degrees,
			false
		)
	if wildlife_target != null and wildlife_target.has_method("interact"):
		wildlife_target.call("interact", self)
		return

	if is_swimming:
		_try_drink_water()
		return

	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return
	var collision_point: Vector3 = interaction_ray.get_collision_point()
	if global_position.distance_to(collision_point) > interaction_range:
		return
	if Space.sample(self, collision_point).water:
		_try_drink_water(collision_point)
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

	var target: Node = _get_camera_wildlife_target(bite_reach)
	if target == null:
		target = _find_wildlife_target(
			bite_reach,
			bite_cone_degrees,
			true
		)
	if target == null:
		show_gameplay_message("No creature in bite range.", 1.2)
		return
	if not perform_bite_on_target(target):
		show_gameplay_message("That creature cannot be bitten.", 1.2)


func perform_bite_on_target(target: Node) -> bool:
	if is_dead or get_tree().paused or not is_physics_processing() or not can_perform_action(&"bite"):
		return false
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_method("receive_creature_attack"):
		return false
	if target is Node3D:
		var distance: float = global_position.distance_to(
			(target as Node3D).global_position
		)
		if distance > bite_reach + 0.35:
			return false
		if not _has_clear_line_of_sight(target, global_position + up_direction * 0.7, target.global_position + Space.up(self, target.global_position) * 0.7):
			return false
	if _bite_cooldown_timer > 0.0:
		return false

	var behavior := get_node("BehaviorController")
	var before_stamina: Dictionary = behavior.export_state()
	if not behavior.spend_bite():
		return false
	var damage: float = get_bite_damage()
	if target.has_node("SocialBehavior") and GameState.current_phase == 0:
		if not target.get_node("SocialBehavior").receive_player_attack(damage, self):
			behavior.import_state(before_stamina)
			return false
	else:
		target.call("receive_creature_attack", damage, self)
	recovery.end_protection()
	_bite_cooldown_timer = bite_cooldown
	_trigger_bite_animation()
	creature_attacked.emit(target, damage)
	return true


func get_interaction_target() -> Node:
	var target: Node = _get_camera_wildlife_target(inspection_radius)
	if target != null:
		return target
	return _find_wildlife_target(
		inspection_radius,
		inspection_cone_degrees,
		false
	)


func get_scan_target() -> Node3D:
	last_scan_rays = 0
	_scan_target_pixel = Vector2.ZERO
	if _gameplay_camera == null or not is_inside_tree(): return null
	var circle: Dictionary = _scan_circle()
	var old_target: Variant = get_node("CreatureScanner").target
	var previous: Node3D = old_target as Node3D if is_instance_valid(old_target) else null
	var retained: Node3D
	var retained_score: float = INF
	var retained_pixel: Vector2
	var best: Node3D
	var best_score: float = INF
	var best_pixel: Vector2
	# The bounded physical population has at most twelve animals and six nests.
	# Reject by projected collision silhouette before asking physics for a ray.
	for group_name: StringName in [&"wildlife", &"wildlife_nest"]:
		for value: Node in get_tree().get_nodes_in_group(group_name):
			var candidate := value as Node3D
			if candidate == null or not is_instance_valid(candidate): continue
			if candidate.is_in_group(&"wildlife") and (not candidate.has_method("get_inspection_data") or bool(candidate.get("is_dead"))): continue
			if global_position.distance_to(candidate.global_position) > inspection_radius: continue
			var contact: Dictionary = _scan_contact(candidate, circle)
			if contact.is_empty(): continue
			var visible_pixel: Variant = _scan_visible(candidate, contact.pixel, circle)
			if visible_pixel == null: continue
			var score: float = float(contact.score) + global_position.distance_to(candidate.global_position) * 0.001
			if candidate == previous:
				retained = candidate
				retained_score = score
				retained_pixel = visible_pixel
			if score < best_score:
				best = candidate
				best_score = score
				best_pixel = visible_pixel
	# A small preference for the still-visible individual prevents two moving
	# animals at the ring edge from swapping every physics frame.
	var chosen: Node3D = retained if retained != null and retained_score <= best_score + 0.12 else best
	if chosen != null: _scan_target_pixel = retained_pixel if chosen == retained else best_pixel
	return chosen

func get_scan_target_pixel() -> Vector2:
	return _scan_target_pixel

func _scan_circle() -> Dictionary:
	var hud := get_node_or_null("CreatureInspectionHUD")
	var circle: Dictionary = hud.scan_circle() if hud != null and hud.has_method("scan_circle") else {}
	if not circle.is_empty() and float(circle.get("radius", 0.0)) > 0.0: return circle
	return {"center": get_viewport().get_visible_rect().get_center(), "radius": 26.0}

func _scan_contact(candidate: Node3D, circle: Dictionary) -> Dictionary:
	var collider := candidate.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider == null:
		for child: Node in candidate.get_children():
			if child is CollisionObject3D:
				for shape_node: Node in child.get_children():
					if shape_node is CollisionShape3D:
						collider = shape_node
						break
				if collider != null: break
	if collider == null or collider.disabled: return {}
	var radius: float
	var axis_half: float
	if collider.shape is CapsuleShape3D:
		var capsule := collider.shape as CapsuleShape3D
		radius = capsule.radius
		axis_half = maxf(0.0, capsule.height * 0.5 - radius)
	elif collider.shape is CylinderShape3D:
		var cylinder := collider.shape as CylinderShape3D
		radius = cylinder.radius
		axis_half = cylinder.height * 0.5
	else: return {}
	var start: Vector3 = collider.to_global(Vector3(0, -axis_half, 0))
	var finish: Vector3 = collider.to_global(Vector3(0, axis_half, 0))
	if _gameplay_camera.is_position_behind(start) or _gameplay_camera.is_position_behind(finish): return {}
	var a: Vector2 = _gameplay_camera.unproject_position(start)
	var b: Vector2 = _gameplay_camera.unproject_position(finish)
	var screen_right: Vector3 = _gameplay_camera.global_basis.x * radius * collider.global_basis.get_scale().x
	var ra: float = a.distance_to(_gameplay_camera.unproject_position(start + screen_right))
	var rb: float = b.distance_to(_gameplay_camera.unproject_position(finish + screen_right))
	return ScanCircle.contact(circle.center, float(circle.radius), a, b, ra, rb)

func _scan_visible(candidate: Node3D, pixel: Vector2, circle: Dictionary) -> Variant:
	if _scan_ray_hits(candidate, pixel): return pixel
	# At an occluder's edge the closest pixel can be hidden although another
	# part of the overlapping body is visible. Probe once farther inward.
	var inside: Vector2 = pixel.lerp(circle.center, 0.25)
	return inside if inside.distance_to(circle.center) <= float(circle.radius) and _scan_ray_hits(candidate, inside) else null

func _scan_ray_hits(candidate: Node3D, pixel: Vector2) -> bool:
	last_scan_rays += 1
	var origin: Vector3 = _gameplay_camera.project_ray_origin(pixel)
	var direction: Vector3 = _gameplay_camera.project_ray_normal(pixel)
	var distance: float = origin.distance_to(global_position) + inspection_radius + 2.0
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * distance, 5, [get_rid()])
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and _resolve_interaction_target(hit.get("collider")) == candidate


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
		return (
			global_position.distance_squared_to(a.global_position)
			< global_position.distance_squared_to(b.global_position)
		)
	)
	if candidates.size() > maximum_count:
		candidates.resize(maximum_count)
	return candidates


func is_inspection_mode_enabled() -> bool:
	return inspection_mode_enabled


func _is_inspection_toggle_event(event: InputEvent) -> bool:
	return event.is_action_pressed("inspection_mode") and not event.is_echo()


func _get_camera_wildlife_target(maximum_distance_from_player: float) -> Node:
	if interaction_ray == null:
		return null
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return null
	var target: Node = _resolve_interaction_target(interaction_ray.get_collider())
	if target == null or not target.is_in_group(&"wildlife"):
		return null
	if target is Node3D:
		if global_position.distance_to((target as Node3D).global_position) > maximum_distance_from_player:
			return null
	return target


func _find_wildlife_target(
	maximum_distance: float,
	cone_degrees: float,
	require_line_of_sight: bool
) -> Node:
	var origin: Vector3 = global_position + up_direction * target_center_height
	var forward: Vector3 = -global_transform.basis.z
	if _gameplay_camera != null:
		forward = -_gameplay_camera.global_transform.basis.z
	forward = forward.slide(up_direction) + up_direction * forward.dot(up_direction) * 0.35
	if forward.length_squared() < 0.001:
		forward = -global_transform.basis.z
	forward = forward.normalized()
	var minimum_dot: float = cos(deg_to_rad(clampf(cone_degrees, 1.0, 179.0) * 0.5))
	var best_target: Node = null
	var best_score: float = -INF
	var nearest_close_target: Node = null
	var nearest_close_distance: float = INF

	for value in get_tree().get_nodes_in_group(&"wildlife"):
		var creature := value as Node3D
		if creature == null or not is_instance_valid(creature):
			continue
		var target_position: Vector3 = (
			creature.global_position + Space.up(self, creature.global_position) * target_center_height
		)
		var delta: Vector3 = target_position - origin
		var distance: float = delta.length()
		if distance <= 0.001 or distance > maximum_distance:
			continue
		if distance < nearest_close_distance and distance <= minf(1.55, maximum_distance) and (not require_line_of_sight or _has_clear_line_of_sight(creature, origin, target_position)):
			nearest_close_target = creature
			nearest_close_distance = distance
		var direction: Vector3 = delta / distance
		var alignment: float = forward.dot(direction)
		if alignment < minimum_dot:
			continue
		if require_line_of_sight and not _has_clear_line_of_sight(creature, origin, target_position):
			continue
		var distance_weight: float = 1.0 - distance / maxf(maximum_distance, 0.001)
		var score: float = alignment * 2.4 + distance_weight
		if score > best_score:
			best_score = score
			best_target = creature

	if best_target != null:
		return best_target
	if nearest_close_target != null:
		return nearest_close_target
	return null


func _has_clear_line_of_sight(
	target: Node3D,
	origin: Vector3,
	target_position: Vector3
) -> bool:
	var world := get_world_3d()
	if world == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		target_position,
		5
	)
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var resolved: Node = _resolve_interaction_target(hit.get("collider"))
	return resolved == target


func _resolve_interaction_target(collider_value: Variant) -> Node:
	var current := collider_value as Node
	var depth: int = 0
	while current != null and depth < 8:
		if (
			current.has_method("receive_creature_attack")
			or current.has_method("interact")
			or current.is_in_group(&"wildlife")
			or current.is_in_group(&"wildlife_nest")
		):
			return current
		current = current.get_parent()
		depth += 1
	return null


func consume_food(food_type: String, base_nutrition: float) -> bool:
	var consumed: bool = super.consume_food(food_type, base_nutrition)
	if consumed:
		var visual := get_node_or_null("CreatureRuntimeVisual/BlueprintCreatureVisual")
		if visual != null and visual.has_method("play_part_action"):
			visual.play_part_action("eat")
	return consumed


func _trigger_bite_animation() -> void:
	var animator := get_node_or_null("AdaptiveLocomotionAnimator")
	if animator != null and animator.has_method("trigger_bite"):
		animator.call("trigger_bite")


func _die() -> void:
	if is_dead: return
	if inspection_mode_enabled:
		inspection_mode_enabled = false
		inspection_mode_changed.emit(false)
	super._die()
