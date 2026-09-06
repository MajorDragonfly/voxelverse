extends "res://creatures/runtime/adaptive_locomotion_animator.gd"

@export_category("Attack Animation")
@export_range(0.08, 0.60, 0.01) var bite_duration: float = 0.24
@export_range(0.02, 0.60, 0.01) var bite_lunge_distance: float = 0.22
@export_range(0.0, 55.0, 1.0) var bite_mouth_rotation_degrees: float = 24.0
@export_range(0.0, 25.0, 1.0) var bite_body_pitch_degrees: float = 8.0

var _bite_time_remaining: float = 0.0


func trigger_bite() -> void:
	_bite_time_remaining = maxf(bite_duration, 0.08)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _bite_time_remaining <= 0.0:
		return
	_bite_time_remaining = maxf(_bite_time_remaining - delta, 0.0)
	_apply_bite_animation()


func _apply_bite_animation() -> void:
	if _preview == null or not is_instance_valid(_preview):
		return
	var duration: float = maxf(bite_duration, 0.08)
	var progress: float = 1.0 - _bite_time_remaining / duration
	var envelope: float = sin(clampf(progress, 0.0, 1.0) * PI)
	_preview.position.z -= bite_lunge_distance * envelope
	_preview.rotation.x -= deg_to_rad(bite_body_pitch_degrees) * envelope
	for part_root in _part_roots:
		if part_root == null or not is_instance_valid(part_root):
			continue
		if str(part_root.get_meta("creature_part_category", "")) != "mouth":
			continue
		part_root.rotation.x += deg_to_rad(bite_mouth_rotation_degrees) * envelope
		part_root.position.z -= bite_lunge_distance * 0.22 * envelope
	if _camera != null:
		_camera.fov += envelope * 1.2
