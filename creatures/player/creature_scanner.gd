extends Node

signal scan_completed(species_key: String)
const Tracker = preload("res://core/discovery/scan_tracker.gd")
const Silhouette = preload("res://core/discovery/scan_silhouette.gd")
var tracker := Tracker.new()
var silhouette := Silhouette.new()
var target_pixel := Vector2.ZERO
var last_query_usec: int = 0
var last_scan_rays: int = 0
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
	target_pixel = Vector2.ZERO
	var result: Node3D = _choose_target()
	last_query_usec = Time.get_ticks_usec() - started
	return result

func _choose_target() -> Node3D:
	if not is_instance_valid(_player) or not is_instance_valid(_player._gameplay_camera): return null
	var circle: Dictionary = _player._scan_circle()
	var previous: Node3D = target if is_instance_valid(target) else null
	var retained: Dictionary = {}
	var best: Dictionary = {}
	for group_name: StringName in [&"wildlife", &"wildlife_nest"]:
		for value: Node in get_tree().get_nodes_in_group(group_name):
			var candidate := value as Node3D
			if candidate == null or candidate.is_queued_for_deletion(): continue
			var distance: float = _player.global_position.distance_to(candidate.global_position)
			if distance > _player.inspection_radius: continue
			var contact: Dictionary = {}
			if candidate.is_in_group(&"wildlife_nest"):
				# Preserve the existing query-only landmark contract. Nest holes
				# remain a deliberate scan area; no species/count is disclosed here.
				contact = _player._scan_contact(candidate, circle)
				if contact.is_empty(): continue
				var pixel: Variant = _player._scan_visible(candidate, contact.pixel, circle)
				if pixel == null: continue
				contact.pixel = pixel
			else:
				if not candidate.has_method("get_inspection_data") or bool(candidate.get("is_dead")): continue
				for visible: Dictionary in silhouette.contacts(_player._gameplay_camera, candidate, circle):
					if _mesh_visible(candidate, visible): contact = visible; break
				if contact.is_empty(): continue
			contact.score = float(contact.score) + distance * 0.001
			contact.target = candidate
			if candidate == previous: retained = contact
			if best.is_empty() or float(contact.score) < float(best.score): best = contact
	var chosen: Dictionary = retained if not retained.is_empty() and (best.is_empty() or float(retained.score) <= float(best.score) + 0.12) else best
	if chosen.is_empty(): return null
	target_pixel = chosen.pixel
	return chosen.target

func _mesh_visible(candidate: Node3D, contact: Dictionary) -> bool:
	last_scan_rays += 1
	var camera: Camera3D = _player._gameplay_camera
	var origin: Vector3 = camera.project_ray_origin(contact.pixel)
	# The endpoint is on a real visual triangle; the animal's movement capsule
	# must not reject a tail/foot outside that capsule or invent an invisible hit.
	var exclude: Array[RID] = [_player.get_rid()]
	if candidate is CollisionObject3D: exclude.append(candidate.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, contact.point, 5, exclude)
	query.collide_with_areas = true
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

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
