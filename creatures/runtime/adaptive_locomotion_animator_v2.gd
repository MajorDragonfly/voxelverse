extends "res://creatures/runtime/adaptive_locomotion_animator.gd"

@export_category("Attack Animation")
@export_range(0.08, 0.60, 0.01) var bite_duration: float = 0.28
@export_range(0.02, 0.60, 0.01) var bite_lunge_distance: float = 0.32
@export_range(0.0, 55.0, 1.0) var bite_mouth_rotation_degrees: float = 30.0
@export_range(0.0, 25.0, 1.0) var bite_body_pitch_degrees: float = 11.0
@export_range(0.0, 0.20, 0.01) var bite_body_drop: float = 0.055

var _bite_time_remaining: float = 0.0
var _visual_container: Node3D
var _base_visual_container_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	super._ready()
	if _player != null:
		_visual_container = _player.get_node_or_null("CreatureRuntimeVisual") as Node3D
		if _visual_container != null:
			_base_visual_container_position = _visual_container.position


func trigger_bite() -> void:
	_bite_time_remaining = maxf(bite_duration, 0.08)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _visual_container == null or not is_instance_valid(_visual_container):
		if _player != null and is_instance_valid(_player):
			_visual_container = _player.get_node_or_null("CreatureRuntimeVisual") as Node3D
			if _visual_container != null:
				_base_visual_container_position = _visual_container.position

	if _visual_container != null and is_instance_valid(_visual_container):
		_visual_container.position = _base_visual_container_position

	if _bite_time_remaining <= 0.0:
		return
	_bite_time_remaining = maxf(_bite_time_remaining - delta, 0.0)
	_apply_bite_animation()


func _apply_bite_animation() -> void:
	if _preview == null or not is_instance_valid(_preview):
		return
	var duration: float = maxf(bite_duration, 0.08)
	var progress: float = 1.0 - _bite_time_remaining / duration
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	var envelope: float = sin(clamped_progress * PI)
	var snap: float = sin(clampf(clamped_progress * 1.45, 0.0, 1.0) * PI)

	# Apply the lunge to the stable visual container instead of accumulating an
	# offset on the preview every frame. This guarantees a full return to the
	# locomotion pose after the bite finishes.
	if _visual_container != null and is_instance_valid(_visual_container):
		_visual_container.position = (
			_base_visual_container_position
			+ Vector3(0.0, -bite_body_drop * envelope, -bite_lunge_distance * envelope)
		)

	if _body_root != null and is_instance_valid(_body_root):
		_body_root.rotation.x += deg_to_rad(bite_body_pitch_degrees) * envelope

	for part_root in _part_roots:
		if part_root == null or not is_instance_valid(part_root):
			continue
		if str(part_root.get_meta("creature_part_category", "")) != "mouth":
			continue
		part_root.rotation.x += deg_to_rad(bite_mouth_rotation_degrees) * snap
		part_root.position.z -= bite_lunge_distance * 0.16 * envelope

	if _camera != null:
		_camera.fov = maxf(
			_camera.fov,
			_base_camera_fov + envelope * 1.8
		)
