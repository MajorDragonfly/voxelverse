extends Node
class_name AdaptiveLocomotionAnimator

@export_category("Adaptive Gait")
@export_range(0.0, 55.0, 0.5) var stride_degrees: float = 27.0
@export_range(0.0, 70.0, 0.5) var knee_bend_degrees: float = 32.0
@export_range(0.5, 16.0, 0.1) var maximum_cadence: float = 9.5
@export_range(0.0, 0.25, 0.005) var body_bob_strength: float = 0.065
@export_range(0.0, 18.0, 0.25) var spine_wave_degrees: float = 4.5
@export_range(0.0, 45.0, 0.5) var tail_swing_degrees: float = 20.0

@export_category("Ground Contact")
@export_range(0.1, 2.0, 0.05) var ground_probe_up: float = 0.65
@export_range(0.1, 3.0, 0.05) var ground_probe_down: float = 1.35
@export_range(0.0, 0.8, 0.01) var maximum_visual_ground_offset: float = 0.30
@export_range(1.0, 30.0, 0.5) var ground_follow_speed: float = 12.0

@export_category("Camera")
@export_range(0.0, 1.0, 0.01) var camera_bob_strength: float = 0.16
@export_range(0.0, 12.0, 0.25) var movement_fov_bonus: float = 4.0

var _player: CharacterBody3D
var _preview: Node3D
var _body_root: Node3D
var _body_slices: Array[Node3D] = []
var _part_roots: Array[Node3D] = []
var _leg_records: Array[Dictionary] = []
var _camera_pivot: Node3D
var _camera: Camera3D

var _phase: float = 0.0
var _movement_blend: float = 0.0
var _binding_timer: float = 0.0
var _bound_preview_id: int = 0
var _base_preview_position: Vector3 = Vector3.ZERO
var _base_body_rotation: Vector3 = Vector3.ZERO
var _base_camera_position: Vector3 = Vector3.ZERO
var _base_camera_fov: float = 66.0
var _grounding_offset: float = 0.0


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	if _player == null:
		set_physics_process(false)
		return
	_camera_pivot = _player.get_node_or_null("CameraPivot") as Node3D
	_camera = _player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if _camera_pivot != null:
		_base_camera_position = _camera_pivot.position
	if _camera != null:
		_base_camera_fov = _camera.fov
	call_deferred("_bind_runtime_visual")


func _physics_process(delta: float) -> void:
	_binding_timer -= delta
	if _binding_timer <= 0.0:
		_binding_timer = 0.45
		_validate_or_rebind()
	if _preview == null or not is_instance_valid(_preview):
		return

	var horizontal_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	var maximum_speed: float = maxf(float(_player.get("move_speed")), 0.1)
	var target_blend: float = clampf(horizontal_speed / maximum_speed, 0.0, 1.0)
	_movement_blend = move_toward(_movement_blend, target_blend, delta * 5.5)
	var cadence: float = lerpf(1.1, maximum_cadence, _movement_blend)
	_phase = fmod(_phase + delta * cadence, TAU)

	_animate_body(delta)
	_animate_spine()
	_animate_non_leg_parts()
	_animate_adaptive_legs()
	_solve_ground_contact(delta)
	_animate_camera(delta)


func get_leg_count() -> int:
	return _leg_records.size()


func get_gait_debug_state() -> Dictionary:
	return {
		"leg_count": _leg_records.size(),
		"movement_blend": _movement_blend,
		"phase": _phase,
		"grounding_offset": _grounding_offset,
	}


func _validate_or_rebind() -> void:
	var expected := _player.get_node_or_null(
		"CreatureRuntimeVisual/BlueprintCreatureVisual"
	) as Node3D
	if expected == null:
		return
	if expected.get_instance_id() != _bound_preview_id:
		_bind_runtime_visual()
		return
	if _body_root != null and not is_instance_valid(_body_root):
		_bind_runtime_visual()


func _bind_runtime_visual() -> void:
	var candidate := _player.get_node_or_null(
		"CreatureRuntimeVisual/BlueprintCreatureVisual"
	) as Node3D
	if candidate == null:
		return
	_preview = candidate
	_bound_preview_id = candidate.get_instance_id()
	_base_preview_position = _preview.position
	_grounding_offset = 0.0

	_body_root = _preview.get_node_or_null("BodyV4") as Node3D
	_body_slices.clear()
	_part_roots.clear()
	_leg_records.clear()

	if _body_root != null:
		_base_body_rotation = _body_root.rotation
		for child in _body_root.get_children():
			var slice := child as Node3D
			if slice == null or not slice.name.begins_with("BodySliceV4_"):
				continue
			_store_base_transform(slice)
			_body_slices.append(slice)

	for child in _preview.get_children():
		var part_root := child as Node3D
		if part_root == null or not part_root.has_meta("creature_part_category"):
			continue
		_store_base_transform(part_root)
		_part_roots.append(part_root)

	_build_leg_records()


func _build_leg_records() -> void:
	var legs: Array[Node3D] = []
	for part_root in _part_roots:
		if str(part_root.get_meta("creature_part_category", "")) == "legs":
			legs.append(part_root)
	legs.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		if not is_equal_approx(a.position.z, b.position.z):
			return a.position.z < b.position.z
		return float(a.get_meta("creature_part_side", 1.0)) < float(b.get_meta("creature_part_side", 1.0))
	)

	var positive_rank: int = 0
	var negative_rank: int = 0
	for leg in legs:
		var side: float = float(leg.get_meta("creature_part_side", 1.0))
		var longitudinal_rank: int = positive_rank
		var side_bit: int = 0
		if side < 0.0:
			longitudinal_rank = negative_rank
			side_bit = 1
			negative_rank += 1
		else:
			positive_rank += 1
		var gait_phase: float = PI * float((longitudinal_rank + side_bit) % 2)
		var rig: Dictionary = _create_runtime_leg_rig(leg)
		rig["phase_offset"] = gait_phase
		rig["side"] = side
		rig["rank"] = longitudinal_rank
		_leg_records.append(rig)


func _create_runtime_leg_rig(leg: Node3D) -> Dictionary:
	var meshes: Array[MeshInstance3D] = []
	var minimum_y: float = INF
	var maximum_y: float = -INF
	var foot_x_sum: float = 0.0
	var foot_z_sum: float = 0.0
	var foot_samples: int = 0

	for child in leg.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		meshes.append(mesh_instance)
		var bounds: AABB = mesh_instance.mesh.get_aabb()
		var local_min_y: float = mesh_instance.position.y + bounds.position.y * mesh_instance.scale.y
		var local_max_y: float = mesh_instance.position.y + (bounds.position.y + bounds.size.y) * mesh_instance.scale.y
		minimum_y = minf(minimum_y, local_min_y)
		maximum_y = maxf(maximum_y, local_max_y)

	if meshes.is_empty() or is_inf(minimum_y) or is_inf(maximum_y):
		return {
			"root": leg,
			"knee": null,
			"foot": null,
			"base_rotation": leg.rotation,
			"base_position": leg.position,
		}

	var knee_y: float = lerpf(minimum_y, maximum_y, 0.48)
	var knee := Node3D.new()
	knee.name = "RuntimeKneePivot"
	knee.position = Vector3(0.0, knee_y, 0.0)
	leg.add_child(knee)
	knee.set_meta("adaptive_runtime_rig", true)

	for mesh_instance in meshes:
		if mesh_instance.position.y <= knee_y:
			foot_x_sum += mesh_instance.position.x
			foot_z_sum += mesh_instance.position.z
			foot_samples += 1
			mesh_instance.reparent(knee, true)

	var foot := Marker3D.new()
	foot.name = "RuntimeFootContact"
	var foot_x: float = foot_x_sum / float(maxi(foot_samples, 1))
	var foot_z: float = foot_z_sum / float(maxi(foot_samples, 1))
	var foot_global_before: Vector3 = leg.to_global(Vector3(foot_x, minimum_y, foot_z))
	knee.add_child(foot)
	foot.global_position = foot_global_before

	return {
		"root": leg,
		"knee": knee,
		"foot": foot,
		"base_rotation": leg.rotation,
		"base_position": leg.position,
		"knee_base_rotation": knee.rotation,
	}


func _store_base_transform(node: Node3D) -> void:
	node.set_meta("adaptive_base_position", node.position)
	node.set_meta("adaptive_base_rotation", node.rotation)


func _animate_body(delta: float) -> void:
	var idle_breath: float = sin(_phase * 0.55) * 0.015
	var step_bob: float = absf(sin(_phase * 2.0)) * body_bob_strength * _movement_blend
	var target_position: Vector3 = _base_preview_position
	target_position.y += idle_breath + step_bob + _grounding_offset
	_preview.position = _preview.position.lerp(
		target_position,
		clampf(delta * 14.0, 0.0, 1.0)
	)

	var horizontal_velocity := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	var local_velocity: Vector3 = _player.global_basis.inverse() * horizontal_velocity
	var target_rotation := Vector3(
		deg_to_rad(-local_velocity.z * 0.55),
		_preview.rotation.y,
		deg_to_rad(-local_velocity.x * 0.85)
	)
	if not _player.is_on_floor():
		target_rotation.x += deg_to_rad(-5.0 if _player.velocity.y > 0.0 else 6.0)
	_preview.rotation.x = lerp_angle(_preview.rotation.x, target_rotation.x, clampf(delta * 6.0, 0.0, 1.0))
	_preview.rotation.z = lerp_angle(_preview.rotation.z, target_rotation.z, clampf(delta * 6.0, 0.0, 1.0))


func _animate_spine() -> void:
	if _body_root != null:
		var body_yaw: float = sin(_phase) * deg_to_rad(spine_wave_degrees) * _movement_blend
		_body_root.rotation = _base_body_rotation + Vector3(0.0, body_yaw * 0.28, 0.0)
	var count: int = _body_slices.size()
	for index in range(count):
		var slice: Node3D = _body_slices[index]
		if not is_instance_valid(slice):
			continue
		var base_position: Vector3 = slice.get_meta("adaptive_base_position", slice.position)
		var normalized_index: float = float(index) / float(maxi(count - 1, 1))
		var wave: float = sin(_phase - normalized_index * TAU * 0.72)
		var target: Vector3 = base_position
		target.x += wave * deg_to_rad(spine_wave_degrees) * 0.35 * _movement_blend
		target.y += sin(_phase * 2.0 + normalized_index * PI) * 0.016 * _movement_blend
		slice.position = target


func _animate_non_leg_parts() -> void:
	for part_root in _part_roots:
		if not is_instance_valid(part_root):
			continue
		var category: String = str(part_root.get_meta("creature_part_category", ""))
		if category == "legs":
			continue
		var side: float = float(part_root.get_meta("creature_part_side", 1.0))
		var base_position: Vector3 = part_root.get_meta("adaptive_base_position", part_root.position)
		var base_rotation: Vector3 = part_root.get_meta("adaptive_base_rotation", part_root.rotation)
		var target_position: Vector3 = base_position
		var target_rotation: Vector3 = base_rotation
		match category:
			"arms":
				target_rotation.x -= deg_to_rad(stride_degrees * 0.60) * sin(_phase + (0.0 if side >= 0.0 else PI)) * _movement_blend
			"tail":
				target_rotation.y += deg_to_rad(tail_swing_degrees) * sin(_phase * 0.82) * lerpf(0.42, 1.0, _movement_blend)
				target_rotation.x += deg_to_rad(3.5) * sin(_phase * 0.55)
			"mouth", "eyes", "horns":
				target_rotation.x += deg_to_rad(1.8) * sin(_phase * 0.62)
				target_position.y += sin(_phase * 0.55) * 0.010
			"plates", "spikes", "decor":
				target_rotation.z += deg_to_rad(1.1) * sin(_phase * 0.48 + (0.0 if side >= 0.0 else PI))
		part_root.position = target_position
		part_root.rotation = target_rotation


func _animate_adaptive_legs() -> void:
	for record in _leg_records:
		var leg := record.get("root") as Node3D
		if leg == null or not is_instance_valid(leg):
			continue
		var base_rotation: Vector3 = record.get("base_rotation", leg.rotation)
		var base_position: Vector3 = record.get("base_position", leg.position)
		var gait_phase: float = _phase + float(record.get("phase_offset", 0.0))
		var wave: float = sin(gait_phase)
		var stride: float = cos(gait_phase)
		var lift: float = pow(maxf(wave, 0.0), 1.35) * _movement_blend
		var target_rotation: Vector3 = base_rotation
		target_rotation.x += deg_to_rad(stride_degrees) * stride * _movement_blend
		leg.rotation = target_rotation
		leg.position = base_position
		record["lift"] = lift
		record["wave"] = wave

		var knee := record.get("knee") as Node3D
		if knee != null and is_instance_valid(knee):
			var knee_base: Vector3 = record.get("knee_base_rotation", knee.rotation)
			var knee_target: Vector3 = knee_base
			knee_target.x += deg_to_rad(knee_bend_degrees) * (0.18 * _movement_blend + lift * 0.82)
			knee.rotation = knee_target


func _solve_ground_contact(delta: float) -> void:
	if _leg_records.is_empty() or not _player.is_on_floor():
		_grounding_offset = move_toward(_grounding_offset, 0.0, delta * ground_follow_speed * 0.25)
		return
	var world := _player.get_world_3d()
	if world == null:
		return
	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	var offsets: Array[float] = []
	for record in _leg_records:
		var foot := record.get("foot") as Node3D
		if foot == null or not is_instance_valid(foot):
			continue
		var lift: float = float(record.get("lift", 0.0))
		if lift > 0.42:
			continue
		var foot_position: Vector3 = foot.global_position
		var query := PhysicsRayQueryParameters3D.create(
			foot_position + Vector3.UP * ground_probe_up,
			foot_position + Vector3.DOWN * ground_probe_down
		)
		query.exclude = [_player.get_rid()]
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var hit_position: Vector3 = hit.get("position", foot_position)
		offsets.append(hit_position.y - foot_position.y)
	if offsets.is_empty():
		_grounding_offset = move_toward(_grounding_offset, 0.0, delta * ground_follow_speed * 0.25)
		return
	offsets.sort()
	var median: float = offsets[offsets.size() / 2]
	var desired: float = clampf(median, -maximum_visual_ground_offset, maximum_visual_ground_offset)
	_grounding_offset = lerpf(
		_grounding_offset,
		desired,
		clampf(delta * ground_follow_speed, 0.0, 1.0)
	)


func _animate_camera(delta: float) -> void:
	if _camera_pivot != null:
		var target_position: Vector3 = _base_camera_position
		target_position.y += sin(_phase * 2.0) * camera_bob_strength * 0.06 * _movement_blend
		target_position.x += cos(_phase) * camera_bob_strength * 0.025 * _movement_blend
		_camera_pivot.position = _camera_pivot.position.lerp(
			target_position,
			clampf(delta * 8.0, 0.0, 1.0)
		)
	if _camera != null:
		var target_fov: float = _base_camera_fov + _movement_blend * movement_fov_bonus
		_camera.fov = lerpf(_camera.fov, target_fov, clampf(delta * 4.0, 0.0, 1.0))
