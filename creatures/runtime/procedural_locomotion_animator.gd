extends Node

@export_category("Procedural Locomotion")
@export_range(0.0, 1.0, 0.01)
var body_bob_strength: float = 0.075

@export_range(0.0, 45.0, 0.5)
var leg_swing_degrees: float = 24.0

@export_range(0.0, 45.0, 0.5)
var tail_swing_degrees: float = 18.0

@export_range(0.0, 20.0, 0.5)
var spine_wave_degrees: float = 4.5

@export_range(0.0, 10.0, 0.1)
var camera_bob_strength: float = 0.16

var _player: CharacterBody3D
var _preview: Node3D
var _body_root: Node3D
var _body_slices: Array[Node3D] = []
var _part_roots: Array[Node3D] = []
var _camera_pivot: Node3D
var _camera: Camera3D

var _phase: float = 0.0
var _movement_blend: float = 0.0
var _binding_timer: float = 0.0
var _base_preview_position: Vector3 = Vector3.ZERO
var _base_body_rotation: Vector3 = Vector3.ZERO
var _base_camera_position: Vector3 = Vector3.ZERO
var _base_camera_fov: float = 70.0


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	if _player == null:
		set_physics_process(false)
		return

	_camera_pivot = _player.get_node_or_null("CameraPivot") as Node3D
	_camera = _player.get_node_or_null(
		"CameraPivot/SpringArm3D/Camera3D"
	) as Camera3D

	if _camera_pivot != null:
		_base_camera_position = _camera_pivot.position
	if _camera != null:
		_base_camera_fov = _camera.fov

	call_deferred("_bind_runtime_visual")


func _physics_process(delta: float) -> void:
	_binding_timer -= delta
	if _binding_timer <= 0.0:
		_binding_timer = 0.55
		_validate_or_rebind()

	if _preview == null or not is_instance_valid(_preview):
		return

	var horizontal_speed: float = Vector2(
		_player.velocity.x,
		_player.velocity.z
	).length()
	var maximum_speed: float = maxf(float(_player.get("move_speed")), 0.1)
	var movement_target: float = clampf(horizontal_speed / maximum_speed, 0.0, 1.0)
	_movement_blend = move_toward(
		_movement_blend,
		movement_target,
		delta * 5.5
	)

	var cadence: float = lerpf(1.3, 9.0, _movement_blend)
	_phase = fmod(_phase + delta * cadence, TAU)

	_animate_preview_root(delta)
	_animate_spine()
	_animate_parts()
	_animate_camera(delta)


func _validate_or_rebind() -> void:
	var expected_preview: Node3D = _player.get_node_or_null(
		"CreatureRuntimeVisual/BlueprintCreatureVisual"
	) as Node3D

	if expected_preview == null:
		return
	if expected_preview != _preview:
		_bind_runtime_visual()
		return
	if not is_instance_valid(_body_root):
		_bind_runtime_visual()


func _bind_runtime_visual() -> void:
	_preview = _player.get_node_or_null(
		"CreatureRuntimeVisual/BlueprintCreatureVisual"
	) as Node3D
	if _preview == null:
		return

	_base_preview_position = _preview.position
	_body_root = _preview.get_node_or_null("BodyV4") as Node3D
	_body_slices.clear()
	_part_roots.clear()

	if _body_root != null:
		_base_body_rotation = _body_root.rotation
		for child in _body_root.get_children():
			var slice := child as Node3D
			if slice == null:
				continue
			if not slice.name.begins_with("BodySliceV4_"):
				continue
			_store_base_transform(slice)
			_body_slices.append(slice)

	for child in _preview.get_children():
		var part_root := child as Node3D
		if part_root == null:
			continue
		if not part_root.has_meta("creature_part_category"):
			continue
		_store_base_transform(part_root)
		_part_roots.append(part_root)


func _store_base_transform(node: Node3D) -> void:
	node.set_meta("locomotion_base_position", node.position)
	node.set_meta("locomotion_base_rotation", node.rotation)


func _animate_preview_root(delta: float) -> void:
	var idle_breath: float = sin(_phase * 0.55) * 0.018
	var step_bob: float = absf(sin(_phase * 2.0)) * body_bob_strength
	var target_position: Vector3 = _base_preview_position
	target_position.y += idle_breath + step_bob * _movement_blend

	_preview.position = _preview.position.lerp(
		target_position,
		clampf(delta * 12.0, 0.0, 1.0)
	)

	var lateral_velocity: float = _player.velocity.dot(_player.global_basis.x)
	var forward_velocity: float = _player.velocity.dot(-_player.global_basis.z)
	var target_rotation := Vector3(
		deg_to_rad(-forward_velocity * 0.75),
		0.0,
		deg_to_rad(-lateral_velocity * 1.15)
	)

	if not _player.is_on_floor():
		target_rotation.x += deg_to_rad(-6.0 if _player.velocity.y > 0.0 else 7.0)

	_preview.rotation = _preview.rotation.lerp(
		target_rotation,
		clampf(delta * 6.0, 0.0, 1.0)
	)


func _animate_spine() -> void:
	if _body_root != null:
		var body_yaw: float = sin(_phase) * deg_to_rad(spine_wave_degrees) * _movement_blend
		_body_root.rotation = _base_body_rotation + Vector3(0.0, body_yaw * 0.28, 0.0)

	var count: int = _body_slices.size()
	for index in range(count):
		var slice: Node3D = _body_slices[index]
		if not is_instance_valid(slice):
			continue

		var base_position: Vector3 = slice.get_meta(
			"locomotion_base_position",
			slice.position
		)
		var normalized_index: float = float(index) / float(maxi(count - 1, 1))
		var wave: float = sin(_phase - normalized_index * TAU * 0.72)
		var animated_position: Vector3 = base_position
		animated_position.x += (
			wave
			* deg_to_rad(spine_wave_degrees)
			* 0.35
			* _movement_blend
		)
		animated_position.y += sin(_phase * 2.0 + normalized_index * PI) * 0.018 * _movement_blend
		slice.position = animated_position


func _animate_parts() -> void:
	for part_root in _part_roots:
		if not is_instance_valid(part_root):
			continue

		var category: String = str(part_root.get_meta("creature_part_category", ""))
		var side: float = float(part_root.get_meta("creature_part_side", 1.0))
		var base_position: Vector3 = part_root.get_meta(
			"locomotion_base_position",
			part_root.position
		)
		var base_rotation: Vector3 = part_root.get_meta(
			"locomotion_base_rotation",
			part_root.rotation
		)
		var side_phase: float = 0.0 if side >= 0.0 else PI
		var animated_position: Vector3 = base_position
		var animated_rotation: Vector3 = base_rotation

		match category:
			"legs":
				var step_wave: float = sin(_phase + side_phase)
				animated_rotation.x += deg_to_rad(leg_swing_degrees) * step_wave * _movement_blend
				animated_position.y += maxf(step_wave, 0.0) * 0.07 * _movement_blend
			"arms":
				animated_rotation.x -= deg_to_rad(leg_swing_degrees * 0.72) * sin(_phase + side_phase) * _movement_blend
			"tail":
				animated_rotation.y += deg_to_rad(tail_swing_degrees) * sin(_phase * 0.82) * lerpf(0.45, 1.0, _movement_blend)
				animated_rotation.x += deg_to_rad(4.0) * sin(_phase * 0.55)
			"mouth", "eyes", "horns":
				animated_rotation.x += deg_to_rad(2.2) * sin(_phase * 0.62)
				animated_position.y += sin(_phase * 0.55) * 0.012
			"plates", "spikes", "decor":
				animated_rotation.z += deg_to_rad(1.2) * sin(_phase * 0.48 + side_phase)

		part_root.position = animated_position
		part_root.rotation = animated_rotation


func _animate_camera(delta: float) -> void:
	if _camera_pivot == null:
		return

	var target_position: Vector3 = _base_camera_position
	target_position.y += (
		sin(_phase * 2.0)
		* camera_bob_strength
		* 0.06
		* _movement_blend
	)
	target_position.x += (
		cos(_phase)
		* camera_bob_strength
		* 0.025
		* _movement_blend
	)
	_camera_pivot.position = _camera_pivot.position.lerp(
		target_position,
		clampf(delta * 8.0, 0.0, 1.0)
	)

	if _camera != null:
		var target_fov: float = _base_camera_fov + _movement_blend * 4.0
		_camera.fov = lerpf(
			_camera.fov,
			target_fov,
			clampf(delta * 4.0, 0.0, 1.0)
		)
