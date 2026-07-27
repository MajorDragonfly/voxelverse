extends RefCounted
class_name CreatureSurfaceSocketsV7

const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const PartLibrary = preload("res://creatures/editor/creature_part_library.gd")
const SpineProfile = preload("res://creatures/editor/creature_spine_profile.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")


static func snap_part_to_surface(
	blueprint: Dictionary,
	part_index: int
) -> bool:
	var parts: Array = blueprint.get("parts", [])
	if part_index < 0 or part_index >= parts.size():
		return false
	if not (parts[part_index] is Dictionary):
		return false
	var placement: Dictionary = parts[part_index]
	var position: Vector3 = Blueprint._as_vector3(
		placement.get("position", Vector3.ZERO)
	)
	var body_shape: Vector3 = Blueprint.get_body_shape(blueprint)
	body_shape *= Blueprint.get_body_scale(blueprint)
	body_shape.z *= SpineProfile.get_body_length_scale(blueprint)
	var category_id: String = str(placement.get("category", ""))

	var anchor_t: float = clampf(
		(position.z + body_shape.z * 0.5) / maxf(body_shape.z, 0.001),
		0.0,
		1.0
	)
	if category_id == PartLibrary.CATEGORY_MOUTH:
		anchor_t = 0.0
	elif category_id == PartLibrary.CATEGORY_TAIL:
		anchor_t = 1.0

	var profile: Dictionary = SpineProfile.sample(blueprint, anchor_t)
	var taper: float = absf(anchor_t - 0.5) * 0.46
	var width: float = body_shape.x * (1.0 - taper)
	width *= float(profile.get("width_scale", 1.0))
	var height: float = body_shape.y * (1.0 - taper * 0.52)
	height *= float(profile.get("height_scale", 1.0))
	var center_y: float = float(profile.get("y_offset", 0.0))
	center_y *= Blueprint.get_body_scale(blueprint)
	var anchor_side: float = clampf(
		position.x / maxf(width * 0.52, 0.001),
		-1.0,
		1.0
	)
	var anchor_vertical: float = clampf(
		(position.y - center_y) / maxf(height * 0.55, 0.001),
		-1.0,
		1.0
	)

	# Snap to the closest shell direction. Keeping both values below full scale
	# places a part inside the body, while forcing the dominant axis to +/-1 keeps
	# the socket on the actual surface.
	if absf(anchor_side) >= absf(anchor_vertical):
		anchor_side = signf(anchor_side) if absf(anchor_side) > 0.001 else 1.0
	else:
		anchor_vertical = (
			signf(anchor_vertical)
			if absf(anchor_vertical) > 0.001
			else 1.0
		)
	if category_id in [
		PartLibrary.CATEGORY_MOUTH,
		PartLibrary.CATEGORY_TAIL,
	]:
		anchor_side = 0.0
		anchor_vertical = clampf(anchor_vertical, -0.25, 0.25)

	placement["anchor_t"] = anchor_t
	placement["anchor_side"] = anchor_side
	placement["anchor_vertical"] = anchor_vertical
	placement["anchor_surface_offset"] = Vector3.ZERO
	placement["manual_offset"] = Vector3.ZERO
	placement["anchor_locked"] = true
	placement["socket_type"] = _get_socket_type(category_id)
	parts[part_index] = placement
	blueprint["parts"] = parts
	Anatomy.rebind_part(blueprint, part_index)
	return true


static func apply_symmetry(
	blueprint: Dictionary,
	part_index: int,
	enabled: bool
) -> bool:
	var parts: Array = blueprint.get("parts", [])
	if part_index < 0 or part_index >= parts.size():
		return false
	if not (parts[part_index] is Dictionary):
		return false
	var placement: Dictionary = parts[part_index]
	var category_id: String = str(placement.get("category", ""))
	var supports_pair: bool = category_id in [
		PartLibrary.CATEGORY_EYES,
		PartLibrary.CATEGORY_LEGS,
		PartLibrary.CATEGORY_ARMS,
		PartLibrary.CATEGORY_HORNS,
		PartLibrary.CATEGORY_DECOR,
	]
	placement["mirrored"] = enabled and supports_pair
	parts[part_index] = placement
	blueprint["parts"] = parts
	return supports_pair


static func _get_socket_type(category_id: String) -> String:
	match category_id:
		PartLibrary.CATEGORY_MOUTH:
			return "front"
		PartLibrary.CATEGORY_TAIL:
			return "rear"
		PartLibrary.CATEGORY_LEGS:
			return "lower_side"
		PartLibrary.CATEGORY_ARMS:
			return "side"
		PartLibrary.CATEGORY_EYES, PartLibrary.CATEGORY_HORNS:
			return "upper_front"
		PartLibrary.CATEGORY_PLATES, PartLibrary.CATEGORY_SPIKES:
			return "upper_spine"
		_:
			return "surface"
