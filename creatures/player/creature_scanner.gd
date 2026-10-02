extends Node

signal scan_completed(species_key: String)
const Tracker = preload("res://core/discovery/scan_tracker.gd")
const Silhouette = preload("res://core/discovery/scan_silhouette.gd")
var tracker := Tracker.new()
var silhouette := Silhouette.new()
var target_pixel := Vector2.ZERO
var last_query_usec: int = 0
var last_scan_rays: int = 0
var _fully_occluded: Dictionary = {}
var target: Node3D
var known: bool = false
var _player: Node
var _progression: Node
var _world_seed: int = 0
var _campaign_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_parent()
	_progression = get_node("/root/ProgressionService")
	_player.inspection_mode_changed.connect(func(_enabled: bool): reset())

func active() -> bool:
	if not is_inside_tree() or is_queued_for_deletion(): return false
	var flow := get_node_or_null("/root/SessionFlow")
	return is_instance_valid(_player) and _player.is_physics_processing() and _player.inspection_mode_enabled and not _player.is_dead and not get_tree().paused and (flow == null or not flow.loading) and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless")

func reset() -> void:
	tracker.reset()
	target = null
	known = false
	target_pixel = Vector2.ZERO

func get_scan_target() -> Node3D:
	var started: int = Time.get_ticks_usec()
	last_scan_rays = 0
	_fully_occluded.clear()
	target_pixel = Vector2.ZERO
	var result: Node3D = _choose_target()
	last_query_usec = Time.get_ticks_usec() - started
	return result

func _choose_target() -> Node3D:
	if not is_instance_valid(_player) or not is_instance_valid(_player._gameplay_camera): return null
	var circle: Dictionary = _player._scan_circle()
	var previous: Node3D = target if is_instance_valid(target) else null
	var candidates: Array[Dictionary] = []
	for group_name: StringName in [&"wildlife", &"wildlife_nest"]:
		for value: Node in get_tree().get_nodes_in_group(group_name):
			var candidate := value as Node3D
			if candidate == null or candidate.is_queued_for_deletion(): continue
			var distance: float = _player.global_position.distance_to(candidate.global_position)
			if distance > _player.inspection_radius: continue
			var nest: bool = candidate.is_in_group(&"wildlife_nest")
			if not nest and (not candidate.has_method("get_inspection_data") or bool(candidate.get("is_dead"))): continue
			# Proximity orders visibility work; it never establishes eligibility.
			var rank: Dictionary = _player._scan_contact(candidate, circle)
			var score: float = float(rank.score) if not rank.is_empty() else _player._gameplay_camera.unproject_position(candidate.global_position).distance_to(circle.center) / float(circle.radius)
			candidates.append({"target": candidate, "rank": rank, "score": score + distance * 0.001, "nest": nest})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score < b.score)
	var best: Dictionary = {}
	for entry: Dictionary in candidates:
		var visible: Dictionary = _visible_contact(entry, circle)
		if visible.is_empty(): continue
		best = visible
		break
	if best.is_empty(): return null
	# Only the former target can override the nearest visible result. Other,
	# lower-ranked animals cannot change this choice and need no triangle query.
	var chosen: Dictionary = best
	if best.target != previous:
		for entry: Dictionary in candidates:
			if entry.target != previous or float(entry.score) > float(best.score) + 0.12: continue
			var retained: Dictionary = _visible_contact(entry, circle)
			if not retained.is_empty(): chosen = retained
			break
	target_pixel = chosen.pixel
	return chosen.target

func _visible_contact(entry: Dictionary, circle: Dictionary) -> Dictionary:
	var candidate: Node3D = entry.target
	# Nests share the same visual predicate. Their query cylinder also contains
	# empty space and cannot prove that the nest mesh overlaps the drawn disc.
	var visible: Array[Dictionary] = silhouette.contacts(_player._gameplay_camera, candidate, circle,
		func(point: Dictionary) -> int:
			if _mesh_visible(candidate, point): return 1
			return -1 if _fully_occluded.has(candidate.get_instance_id()) else 0)
	if visible.is_empty(): return {}
	var contact: Dictionary = visible.front()
	contact.score = entry.score
	contact.target = candidate
	return contact

func _mesh_visible(candidate: Node3D, contact: Dictionary) -> bool:
	last_scan_rays += 1
	var camera: Camera3D = _player._gameplay_camera
	var origin: Vector3 = camera.project_ray_origin(contact.pixel)
	# The endpoint is on a real visual triangle; the animal's movement capsule
	# must not reject a tail/foot outside that capsule or invent an invisible hit.
	var exclude: Array[RID] = [_player.get_rid()]
	if candidate is CollisionObject3D: exclude.append(candidate.get_rid())
	if candidate.is_in_group(&"wildlife_nest"):
		for child: Node in candidate.get_children():
			if child is CollisionObject3D: exclude.append(child.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, contact.point, 5, exclude)
	query.collide_with_areas = true
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	# A movement capsule can intersect this ray in an empty gap between body
	# parts. Only actual visible foreign geometry at this pixel blocks scanning.
	while not hit.is_empty():
		var obstruction: Node3D = _player._resolve_interaction_target(hit.collider) as Node3D
		if obstruction == null or not (obstruction.is_in_group(&"wildlife") or obstruction.is_in_group(&"wildlife_nest")): break
		if silhouette.occludes(camera, obstruction, contact.pixel, contact.point): return false
		exclude.append(hit.collider.get_rid())
		query.exclude = exclude
		last_scan_rays += 1
		hit = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return true
	# A solid convex box that covers every corner of the actual visual bounds
	# covers every point inside those bounds. Stop exhaustive surface probing.
	# Wildlife colliders cannot prove visual occlusion and never use this path.
	var blocker: CollisionObject3D = hit.collider as CollisionObject3D
	if blocker != null and camera.projection == Camera3D.PROJECTION_PERSPECTIVE and not blocker.is_in_group(&"wildlife"):
		var owner_id: int = blocker.shape_find_owner(int(hit.shape))
		var shape_node: Node = blocker.shape_owner_get_owner(owner_id)
		if shape_node is CollisionShape3D and shape_node.shape is BoxShape3D:
			var transform: Transform3D = shape_node.global_transform.affine_inverse()
			var bounds: AABB = silhouette.world_bounds(candidate)
			var box := AABB(-shape_node.shape.size * 0.5, shape_node.shape.size)
			var covered: bool = bounds.size != Vector3.ZERO
			for index in range(8):
				var corner: Vector3 = bounds.get_endpoint(index)
				if camera.is_position_behind(corner) or box.intersects_segment(transform * origin, transform * corner) == null:
					covered = false
					break
			if covered: _fully_occluded[candidate.get_instance_id()] = true
	return false

func _physics_process(delta: float) -> void:
	if not active():
		reset()
		return
	var state: Node = get_node("/root/GameState")
	var seed_value: int = state.get_world_seed()
	var identity: String = state.campaign.data.id
	if seed_value != _world_seed or identity != _campaign_id:
		reset()
		_world_seed = seed_value
		_campaign_id = identity
	var aimed: Node3D = get_scan_target()
	var changed: bool = aimed != target
	target = aimed
	known = false
	if target == null:
		tracker.reset()
		return
	if target.is_in_group(&"wildlife_nest"):
		var nest_id: String = str(target.colony.get("id", ""))
		var body_id: String = str(state.get_current_body_record().get("id", ""))
		known = _progression.has_nest_scan(nest_id, body_id, _world_seed)
		if known:
			tracker.reset()
		elif tracker.advance(target.get_instance_id(), delta):
			known = _progression.register_nest_scan(nest_id, body_id, _world_seed)
			if known:
				_player.guidance_action.emit("inspect", 1.0)
				scan_completed.emit(body_id + ":" + nest_id)
		return
	var species_seed: int = int(target.get("species_seed"))
	known = _progression.has_species_scan(species_seed, _world_seed)
	if known:
		tracker.reset()
		if changed:
			_progression.register_species_scan(species_seed, target.get("blueprint"), _world_seed)
		_player.guidance_action.emit("inspect", 1.0)
		return
	if tracker.advance(target.get_instance_id(), delta):
		var result: Dictionary = _progression.register_species_scan(species_seed, target.get("blueprint"), _world_seed)
		known = _progression.has_species_scan(species_seed, _world_seed)
		if known:
			_player.guidance_action.emit("inspect", 1.0)
			scan_completed.emit(str(result.get("species_key", "")))

func ratio() -> float:
	return 1.0 if known else tracker.ratio()
