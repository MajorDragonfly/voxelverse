extends Node
class_name AdaptiveLocomotionAnimator
const LimbRig = preload("res://creatures/runtime/creature_limb_rig.gd")
const Gait = preload("res://creatures/runtime/creature_gait_profile.gd")

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
var _bound_preview_id: int = 0
var _base_preview_position: Vector3 = Vector3.ZERO
var _base_body_rotation: Vector3 = Vector3.ZERO
var _base_camera_position: Vector3 = Vector3.ZERO
var _base_camera_fov: float = 66.0
var _grounding_offset: float = 0.0
var _gait_profile: Dictionary = {}
var _terrain_pitch: float = 0.0


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
	# The procedural preview can rebuild its child hierarchy without replacing
	# the preview node itself. Validate the complete binding every frame before
	# touching stored leg/knee/foot references.
	if not _validate_or_rebind():
		return

	var horizontal_speed: float = _player.velocity.slide(_player.up_direction).length()
	var maximum_speed: float = maxf(float(_player.get("move_speed")), 0.1)
	var target_blend: float = clampf(horizontal_speed / maximum_speed, 0.0, 1.0)
	_movement_blend = move_toward(_movement_blend, target_blend, delta * 5.5)
	var cadence: float = lerpf(1.1, minf(maximum_cadence, float(_gait_profile.get("cadence", maximum_cadence)) * 1.65), _movement_blend)
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


func _validate_or_rebind() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var expected := _player.get_node_or_null(
		"CreatureRuntimeVisual/BlueprintCreatureVisual"
	) as Node3D
	if expected == null:
		_clear_binding()
		return false

	var needs_rebind: bool = (
		_preview == null
		or not is_instance_valid(_preview)
		or expected.get_instance_id() != _bound_preview_id
	)
	if not needs_rebind and _body_root != null and not is_instance_valid(_body_root):
		needs_rebind = true
	if not needs_rebind and not _leg_records_are_valid():
		needs_rebind = true

	if needs_rebind:
		_bind_runtime_visual()
	return _preview != null and is_instance_valid(_preview)


func _clear_binding() -> void:
	_preview = null
	_body_root = null
	_body_slices.clear()
	_part_roots.clear()
	_leg_records.clear()
	_bound_preview_id = 0


func _leg_records_are_valid() -> bool:
	for record in _leg_records:
		var root_value: Variant = record.get("root")
		if root_value != null and not is_instance_valid(root_value):
			return false
		var knee_value: Variant = record.get("knee")
		if knee_value != null and not is_instance_valid(knee_value):
			return false
		var foot_value: Variant = record.get("foot")
		if foot_value != null and not is_instance_valid(foot_value):
			return false
	return true


func _bind_runtime_visual() -> void:
	if _player == null or not is_instance_valid(_player):
		_clear_binding()
		return
	var candidate := _player.get_node_or_null(
		"CreatureRuntimeVisual/BlueprintCreatureVisual"
	) as Node3D
	if candidate == null:
		_clear_binding()
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
	_gait_profile = Gait.build(_leg_records)
	_terrain_pitch = 0.0


func _build_leg_records() -> void:
	var legs: Array[Node3D] = []
	for part_root in _part_roots:
		if is_instance_valid(part_root) and str(part_root.get_meta("creature_part_category", "")) == "legs":
			legs.append(part_root)
	legs.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		if not is_equal_approx(a.position.z, b.position.z):
			return a.position.z < b.position.z
		return float(a.get_meta("creature_part_side", 1.0)) < float(b.get_meta("creature_part_side", 1.0))
	)

	var positive_rank: int = 0
	var negative_rank: int = 0
	for leg in legs:
		if not is_instance_valid(leg):
			continue
		var side: float = float(leg.get_meta("creature_part_side", 1.0))
		var longitudinal_rank: int = positive_rank
		var side_bit: int = 0
		if side < 0.0:
			longitudinal_rank = negative_rank
			side_bit = 1
			negative_rank += 1
		else:
			positive_rank += 1
		var gait_phase: float = Gait.phase_offset(legs.size(), longitudinal_rank, side)
		var rig: Dictionary = _create_runtime_leg_rig(leg)
		rig["phase_offset"] = gait_phase
		rig["side"] = side
		rig["rank"] = longitudinal_rank
		_leg_records.append(rig)


func _create_runtime_leg_rig(leg: Node3D) -> Dictionary:
	if leg.has_meta("sculpt_limb_rig"):
		return leg.get_meta("sculpt_limb_rig")
	_remove_existing_runtime_leg_rig(leg)

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


func _remove_existing_runtime_leg_rig(leg: Node3D) -> void:
	for child in leg.get_children():
		var rig := child as Node3D
		if rig == null or not bool(rig.get_meta("adaptive_runtime_rig", false)):
			continue
		for rig_child in rig.get_children():
			if rig_child is MeshInstance3D:
				rig_child.reparent(leg, true)
		rig.queue_free()


func _store_base_transform(node: Node3D) -> void:
	node.set_meta("adaptive_base_position", node.position)
	node.set_meta("adaptive_base_rotation", node.rotation)


func _animate_body(delta: float) -> void:
	if _preview == null or not is_instance_valid(_preview):
		return
	var idle_breath: float = sin(_phase * 0.55) * 0.015
	var step_bob: float = absf(sin(_phase * 2.0)) * body_bob_strength * _movement_blend
	var target_position: Vector3 = _base_preview_position
	target_position.y += idle_breath + step_bob + _grounding_offset
	target_position.x += sin(_phase) * float(_gait_profile.get("sway", 0.02)) * _movement_blend
	_preview.position = _preview.position.lerp(
		target_position,
		clampf(delta * 14.0, 0.0, 1.0)
	)

	var horizontal_velocity := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	var local_velocity: Vector3 = _player.global_basis.inverse() * horizontal_velocity
	var target_rotation := Vector3(
		deg_to_rad(-local_velocity.z * 0.55) + _terrain_pitch,
		_preview.rotation.y,
		deg_to_rad(-local_velocity.x * 0.85)
	)
	if not _player.is_on_floor():
		target_rotation.x += deg_to_rad(-5.0 if _player.velocity.dot(_player.up_direction) > 0.0 else 6.0)
	_preview.rotation.x = lerp_angle(_preview.rotation.x, target_rotation.x, clampf(delta * 6.0, 0.0, 1.0))
	_preview.rotation.z = lerp_angle(_preview.rotation.z, target_rotation.z, clampf(delta * 6.0, 0.0, 1.0))


func _animate_spine() -> void:
	if _preview != null and bool(_preview.get("sculpted_surface")):
		# A continuous skin and its surface attachments share the preview motion.
		# Rotating only the skin would detach eyes and limbs from their sockets.
		if is_instance_valid(_body_root):
			_body_root.rotation = _base_body_rotation
		return
	if _body_root != null and is_instance_valid(_body_root):
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
		var leg: Node3D = _get_valid_node3d(record, "root")
		if leg == null:
			continue
		var base_rotation: Vector3 = record.get("base_rotation", leg.rotation)
		var base_position: Vector3 = record.get("base_position", leg.position)
		var gait_phase: float = _phase + float(record.get("phase_offset", 0.0))
		var wave: float = sin(gait_phase)
		var stride: float = cos(gait_phase)
		var lift: float = pow(maxf(wave, 0.0), 1.35) * _movement_blend
		if bool(record.get("sculpt_rig", false)):
			leg.rotation = base_rotation
			leg.position = base_position
			var settings: Dictionary = Gait.parameters(_gait_profile, _movement_blend > 0.75)
			var step: Dictionary = Gait.sample(settings, gait_phase, _movement_blend)
			record["lift"] = step["lift"]
			record["swing"] = step["swing"]
			record["step_height"] = float(settings["lift"]) * _preview.global_basis.y.length()
			var point: Vector3 = record["rest_contact_preview"] + step["offset"]
			var frame: Transform3D = _ground_frame()
			LimbRig.plant(record, frame * point, frame.basis.y.normalized(), frame.basis)
			continue
		var target_rotation: Vector3 = base_rotation
		target_rotation.x += deg_to_rad(stride_degrees) * stride * _movement_blend
		leg.rotation = target_rotation
		leg.position = base_position
		record["lift"] = lift
		record["wave"] = wave

		var knee: Node3D = _get_valid_node3d(record, "knee")
		if knee != null:
			var knee_base: Vector3 = record.get("knee_base_rotation", knee.rotation)
			var knee_target: Vector3 = knee_base
			knee_target.x += deg_to_rad(knee_bend_degrees) * (
				0.18 * _movement_blend + lift * 0.82
			)
			knee.rotation = knee_target


func _solve_ground_contact(delta: float) -> void:
	if _leg_records.is_empty() or not _player.is_on_floor():
		for record in _leg_records:
			record.erase("planted_world")
		_terrain_pitch = move_toward(_terrain_pitch, 0.0, delta)
		_grounding_offset = move_toward(
			_grounding_offset,
			0.0,
			delta * ground_follow_speed * 0.25
		)
		return
	var world := _player.get_world_3d()
	if world == null:
		return
	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	var offsets: Array[float] = []
	var support_normals := Vector3.ZERO
	var support_count: int = 0
	var up: Vector3 = _player.up_direction
	for record in _leg_records:
		var foot: Node3D = _get_valid_node3d(record, "foot")
		if foot == null:
			continue
		var lift: float = float(record.get("lift", 0.0))
		if lift > 0.42 and not bool(record.get("sculpt_rig", false)):
			continue
		var foot_position: Vector3 = foot.global_position
		var query := PhysicsRayQueryParameters3D.create(
			foot_position + up * ground_probe_up,
			foot_position - up * ground_probe_down
		)
		query.exclude = [_player.get_rid()]
		query.collision_mask = _player.collision_mask
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var hit_position: Vector3 = hit.get("position", foot_position)
		if bool(record.get("sculpt_rig", false)):
			var frame: Transform3D = _ground_frame()
			var swing: bool = bool(record.get("swing", false))
			if swing:
				record.erase("planted_world")
			else:
				var planted: Vector3 = record.get("planted_world", hit_position)
				var distance: Vector3 = (planted - hit_position).slide(up)
				if distance.length() > maxf(0.3, float(_gait_profile.get("stride", 0.2)) * 2.5 * frame.basis.y.length()):
					planted = hit_position
				record["planted_world"] = planted
				query.from = planted + up * ground_probe_up
				query.to = planted - up * ground_probe_down
				var planted_hit: Dictionary = space_state.intersect_ray(query)
				if not planted_hit.is_empty():
					hit_position = planted_hit["position"]
					hit = planted_hit
			var normal: Vector3 = hit.get("normal", up)
			LimbRig.plant(record, hit_position + up * lift * float(record.get("step_height", 0.15)), normal, frame.basis)
			var rest: Vector3 = frame * record["rest_contact_preview"]
			offsets.append((hit_position - rest).dot(up))
			support_normals += normal
			support_count += 1
			continue
		offsets.append((hit_position - foot_position).dot(up))
	if offsets.is_empty():
		_grounding_offset = move_toward(
			_grounding_offset,
			0.0,
			delta * ground_follow_speed * 0.25
		)
		return
	offsets.sort()
	var median_index: int = floori(float(offsets.size()) * 0.5)
	var median: float = offsets[median_index]
	var desired: float = clampf(
		median,
		-maximum_visual_ground_offset,
		maximum_visual_ground_offset
	)
	_grounding_offset = lerpf(
		_grounding_offset,
		desired,
		clampf(delta * ground_follow_speed, 0.0, 1.0)
	)
	if support_count > 0:
		var local_normal: Vector3 = _player.global_basis.inverse() * support_normals.normalized()
		_terrain_pitch = lerpf(_terrain_pitch, clampf(atan2(local_normal.z, local_normal.y), -0.32, 0.32), clampf(delta * 6.0, 0, 1))


func surface_origin_shifted(shift: Vector3) -> void:
	for record in _leg_records:
		if record.has("planted_world"): record.planted_world += shift

func _ground_frame() -> Transform3D:
	var parent: Node3D = _preview.get_parent_node_3d()
	var local := Transform3D(Basis.from_euler(Vector3(0, _preview.rotation.y, 0)).scaled(_preview.scale), _base_preview_position)
	return parent.global_transform * local if parent != null else local


func _get_valid_node3d(record: Dictionary, key: String) -> Node3D:
	var value: Variant = record.get(key)
	if value == null:
		return null
	# Important: never use `record.get(key) as Node3D` directly. A Dictionary
	# may still contain a reference to a freed Object for one frame after the
	# procedural visual hierarchy was rebuilt; casting that freed Variant is a
	# runtime error in Godot.
	if not is_instance_valid(value):
		return null
	if not (value is Node3D):
		return null
	return value as Node3D


func _animate_camera(delta: float) -> void:
	if _camera_pivot != null and is_instance_valid(_camera_pivot):
		var target_position: Vector3 = _base_camera_position
		target_position.y += sin(_phase * 2.0) * camera_bob_strength * 0.06 * _movement_blend
		target_position.x += cos(_phase) * camera_bob_strength * 0.025 * _movement_blend
		_camera_pivot.position = _camera_pivot.position.lerp(
			target_position,
			clampf(delta * 8.0, 0.0, 1.0)
		)
	if _camera != null and is_instance_valid(_camera):
		var target_fov: float = _base_camera_fov + _movement_blend * movement_fov_bonus
		_camera.fov = lerpf(
			_camera.fov,
			target_fov,
			clampf(delta * 4.0, 0.0, 1.0)
		)
