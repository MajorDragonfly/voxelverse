extends RefCounted
class_name CreatureAnatomy

const Blueprint = preload(
	"res://creatures/editor/creature_blueprint.gd"
)
const PartLibrary = preload(
	"res://creatures/editor/creature_part_library.gd"
)
const SpineProfile = preload(
	"res://creatures/editor/creature_spine_profile.gd"
)


static func ensure_anchors(
	blueprint: Dictionary,
	preserve_current_position: bool = true
) -> void:
	SpineProfile.ensure_profile(blueprint)

	var parts: Array = blueprint.get("parts", [])
	var category_counts: Dictionary = _get_category_counts(parts)
	var category_ordinals: Dictionary = {}

	for index in range(parts.size()):
		if not (parts[index] is Dictionary):
			continue

		var placement: Dictionary = parts[index]
		var category_id: String = str(
			placement.get("category", "")
		)
		var ordinal: int = int(
			category_ordinals.get(category_id, 0)
		)
		var category_count: int = maxi(
			int(category_counts.get(category_id, 1)),
			1
		)
		category_ordinals[category_id] = ordinal + 1

		var had_anchor: bool = placement.has("anchor_t")

		if not had_anchor:
			_apply_default_anchor_fields(
				placement,
				category_id,
				ordinal,
				category_count
			)

		if not placement.has("anchor_locked"):
			placement["anchor_locked"] = true

		if not placement.has("anchor_surface_offset"):
			placement["anchor_surface_offset"] = Vector3.ZERO

		if not placement.has("manual_offset"):
			if preserve_current_position:
				var current_position: Vector3 = Blueprint._as_vector3(
					placement.get("position", Vector3.ZERO)
				)
				placement["manual_offset"] = (
					current_position
					- get_anchor_position(blueprint, placement)
				)
			else:
				placement["manual_offset"] = Vector3.ZERO

		parts[index] = placement

	blueprint["parts"] = parts


static func reset_all_anchors(blueprint: Dictionary) -> void:
	var parts: Array = blueprint.get("parts", [])
	var category_counts: Dictionary = _get_category_counts(parts)
	var category_ordinals: Dictionary = {}

	for index in range(parts.size()):
		if not (parts[index] is Dictionary):
			continue

		var placement: Dictionary = parts[index]
		var category_id: String = str(
			placement.get("category", "")
		)
		var ordinal: int = int(
			category_ordinals.get(category_id, 0)
		)
		var category_count: int = maxi(
			int(category_counts.get(category_id, 1)),
			1
		)
		category_ordinals[category_id] = ordinal + 1

		_apply_default_anchor_fields(
			placement,
			category_id,
			ordinal,
			category_count
		)
		placement["manual_offset"] = Vector3.ZERO
		placement["anchor_locked"] = true
		parts[index] = placement

	blueprint["parts"] = parts
	rebind_all_parts(blueprint)


static func reset_part_anchor(
	blueprint: Dictionary,
	part_index: int
) -> void:
	var parts: Array = blueprint.get("parts", [])

	if part_index < 0 or part_index >= parts.size():
		return

	if not (parts[part_index] is Dictionary):
		return

	var placement: Dictionary = parts[part_index]
	var category_id: String = str(placement.get("category", ""))
	var ordinal: int = 0
	var category_count: int = 0

	for index in range(parts.size()):
		if not (parts[index] is Dictionary):
			continue

		if str(parts[index].get("category", "")) != category_id:
			continue

		if index == part_index:
			ordinal = category_count

		category_count += 1

	_apply_default_anchor_fields(
		placement,
		category_id,
		ordinal,
		maxi(category_count, 1)
	)
	placement["manual_offset"] = Vector3.ZERO
	placement["anchor_locked"] = true
	parts[part_index] = placement
	blueprint["parts"] = parts
	rebind_part(blueprint, part_index)


static func rebind_all_parts(blueprint: Dictionary) -> void:
	ensure_anchors(blueprint, true)

	var parts: Array = blueprint.get("parts", [])

	for index in range(parts.size()):
		rebind_part(blueprint, index)


static func rebind_part(
	blueprint: Dictionary,
	part_index: int
) -> void:
	var parts: Array = blueprint.get("parts", [])

	if part_index < 0 or part_index >= parts.size():
		return

	if not (parts[part_index] is Dictionary):
		return

	var placement: Dictionary = parts[part_index]

	if not bool(placement.get("anchor_locked", true)):
		return

	var manual_offset: Vector3 = Blueprint._as_vector3(
		placement.get("manual_offset", Vector3.ZERO)
	)
	placement["position"] = (
		get_anchor_position(blueprint, placement)
		+ manual_offset
	)
	parts[part_index] = placement
	blueprint["parts"] = parts


static func capture_manual_offset(
	blueprint: Dictionary,
	part_index: int
) -> void:
	var parts: Array = blueprint.get("parts", [])

	if part_index < 0 or part_index >= parts.size():
		return

	if not (parts[part_index] is Dictionary):
		return

	var placement: Dictionary = parts[part_index]
	var current_position: Vector3 = Blueprint._as_vector3(
		placement.get("position", Vector3.ZERO)
	)
	placement["manual_offset"] = (
		current_position
		- get_anchor_position(blueprint, placement)
	)
	placement["anchor_locked"] = true
	parts[part_index] = placement
	blueprint["parts"] = parts


static func get_anchor_position(
	blueprint: Dictionary,
	placement: Dictionary
) -> Vector3:
	var body_shape: Vector3 = (
		Blueprint.get_body_shape(blueprint)
		* Blueprint.get_body_scale(blueprint)
	)
	body_shape.z *= SpineProfile.get_body_length_scale(blueprint)

	var anchor_t: float = clampf(
		float(placement.get("anchor_t", 0.5)),
		0.0,
		1.0
	)
	var anchor_side: float = clampf(
		float(placement.get("anchor_side", 0.0)),
		-1.0,
		1.0
	)
	var anchor_vertical: float = clampf(
		float(placement.get("anchor_vertical", 0.0)),
		-1.0,
		1.0
	)
	var profile: Dictionary = SpineProfile.sample(
		blueprint,
		anchor_t
	)
	var taper: float = absf(anchor_t - 0.5) * 0.46
	var width: float = (
		body_shape.x
		* (1.0 - taper)
		* float(profile.get("width_scale", 1.0))
	)
	var height: float = (
		body_shape.y
		* (1.0 - taper * 0.52)
		* float(profile.get("height_scale", 1.0))
	)
	var center_y: float = (
		float(profile.get("y_offset", 0.0))
		* Blueprint.get_body_scale(blueprint)
	)
	var position := Vector3(
		anchor_side * width * 0.52,
		center_y + anchor_vertical * height * 0.55,
		-body_shape.z * 0.5 + anchor_t * body_shape.z
	)

	position += Blueprint._as_vector3(
		placement.get(
			"anchor_surface_offset",
			Vector3.ZERO
		)
	)
	return position


static func _apply_default_anchor_fields(
	placement: Dictionary,
	category_id: String,
	ordinal: int,
	category_count: int
) -> void:
	var distribution: float = 0.5

	if category_count > 1:
		distribution = (
			float(ordinal)
			/ float(category_count - 1)
		)

	match category_id:
		PartLibrary.CATEGORY_MOUTH:
			placement["anchor_t"] = 0.0
			placement["anchor_side"] = 0.0
			placement["anchor_vertical"] = 0.04
			placement["anchor_surface_offset"] = Vector3(0.0, 0.0, -0.12)

		PartLibrary.CATEGORY_EYES:
			placement["anchor_t"] = 0.055
			placement["anchor_side"] = 0.58
			placement["anchor_vertical"] = 0.38
			placement["anchor_surface_offset"] = Vector3(0.0, 0.02, -0.05)

		PartLibrary.CATEGORY_LEGS:
			placement["anchor_t"] = lerpf(0.28, 0.72, distribution)
			placement["anchor_side"] = 0.56
			placement["anchor_vertical"] = -0.54
			placement["anchor_surface_offset"] = Vector3.ZERO

		PartLibrary.CATEGORY_ARMS:
			placement["anchor_t"] = lerpf(0.18, 0.42, distribution)
			placement["anchor_side"] = 0.60
			placement["anchor_vertical"] = -0.05
			placement["anchor_surface_offset"] = Vector3.ZERO

		PartLibrary.CATEGORY_TAIL:
			placement["anchor_t"] = 1.0
			placement["anchor_side"] = 0.0
			placement["anchor_vertical"] = -0.02
			placement["anchor_surface_offset"] = Vector3(0.0, 0.0, 0.12)

		PartLibrary.CATEGORY_HORNS:
			placement["anchor_t"] = lerpf(0.06, 0.18, distribution)
			placement["anchor_side"] = 0.46
			placement["anchor_vertical"] = 0.54
			placement["anchor_surface_offset"] = Vector3.ZERO

		PartLibrary.CATEGORY_PLATES:
			placement["anchor_t"] = lerpf(0.20, 0.82, distribution)
			placement["anchor_side"] = 0.0
			placement["anchor_vertical"] = 0.58
			placement["anchor_surface_offset"] = Vector3.ZERO

		PartLibrary.CATEGORY_SPIKES:
			placement["anchor_t"] = lerpf(0.16, 0.86, distribution)
			placement["anchor_side"] = 0.0
			placement["anchor_vertical"] = 0.62
			placement["anchor_surface_offset"] = Vector3.ZERO

		PartLibrary.CATEGORY_DECOR:
			placement["anchor_t"] = lerpf(0.24, 0.76, distribution)
			placement["anchor_side"] = 0.0
			placement["anchor_vertical"] = 0.58
			placement["anchor_surface_offset"] = Vector3.ZERO

		_:
			placement["anchor_t"] = 0.5
			placement["anchor_side"] = 0.0
			placement["anchor_vertical"] = 0.0
			placement["anchor_surface_offset"] = Vector3.ZERO


static func _get_category_counts(parts: Array) -> Dictionary:
	var counts: Dictionary = {}

	for placement_value in parts:
		if not (placement_value is Dictionary):
			continue

		var category_id: String = str(
			placement_value.get("category", "")
		)
		counts[category_id] = int(counts.get(category_id, 0)) + 1

	return counts
