extends RefCounted
class_name CreatureAttachmentNormalizer

const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")

# Old editor/runtime versions stored world-like part positions as manual offsets.
# This migration keeps deliberate small edits, but removes offsets that detach a
# part from the generated body surface.
static func normalize(blueprint: Dictionary, force_rebind: bool = false) -> bool:
	Anatomy.ensure_anchors(blueprint, true)
	var body_shape: Vector3 = Blueprint.get_body_shape(blueprint) * Blueprint.get_body_scale(blueprint)
	var maximum_offset := Vector3(
		maxf(body_shape.x * 0.38, 0.32),
		maxf(body_shape.y * 0.42, 0.32),
		maxf(body_shape.z * 0.24, 0.42)
	)
	var changed := false
	var parts: Array = blueprint.get("parts", [])

	for index in range(parts.size()):
		if not (parts[index] is Dictionary):
			continue
		var placement: Dictionary = parts[index]
		var manual_offset: Vector3 = Blueprint._as_vector3(
			placement.get("manual_offset", Vector3.ZERO)
		)
		var invalid := (
			force_rebind
			or absf(manual_offset.x) > maximum_offset.x
			or absf(manual_offset.y) > maximum_offset.y
			or absf(manual_offset.z) > maximum_offset.z
			or manual_offset.length() > maximum_offset.length() * 0.72
		)
		if invalid:
			placement["manual_offset"] = Vector3.ZERO
			placement["anchor_locked"] = true
			parts[index] = placement
			changed = true

	blueprint["parts"] = parts
	Anatomy.rebind_all_parts(blueprint)
	return changed
