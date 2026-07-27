extends RefCounted
class_name CreatureAttachmentNormalizer

const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const PartLibrary = preload("res://creatures/editor/creature_part_library.gd")
const SpineProfile = preload("res://creatures/editor/creature_spine_profile.gd")

const ATTACHMENT_SCHEMA_VERSION: int = 2


# Old editor/runtime versions stored world-like part positions as manual offsets.
# Version 2 performs a one-time hard repair for critical body connections. After
# the migration, deliberate edits remain possible as long as they stay close to
# the anatomical surface anchor.
static func normalize(
	blueprint: Dictionary,
	force_rebind: bool = false
) -> bool:
	SpineProfile.ensure_profile(blueprint)
	Anatomy.ensure_anchors(blueprint, true)

	var body_shape: Vector3 = (
		Blueprint.get_body_shape(blueprint)
		* Blueprint.get_body_scale(blueprint)
	)
	body_shape.z *= SpineProfile.get_body_length_scale(blueprint)

	var generation: Dictionary = blueprint.get("generation", {})
	var source_schema_version: int = int(
		generation.get("attachment_schema_version", 0)
	)
	var migrate_critical_connections: bool = (
		source_schema_version < ATTACHMENT_SCHEMA_VERSION
	)

	var changed: bool = false
	var reset_indices: Array[int] = []
	var parts: Array = blueprint.get("parts", [])

	for index in range(parts.size()):
		if not (parts[index] is Dictionary):
			continue

		var placement: Dictionary = parts[index]
		var category_id: String = str(
			placement.get("category", "")
		)
		var manual_offset: Vector3 = Blueprint._as_vector3(
			placement.get("manual_offset", Vector3.ZERO)
		)
		var maximum_offset: Vector3 = _get_maximum_offset(
			category_id,
			body_shape
		)
		var invalid: bool = (
			force_rebind
			or absf(manual_offset.x) > maximum_offset.x
			or absf(manual_offset.y) > maximum_offset.y
			or absf(manual_offset.z) > maximum_offset.z
			or manual_offset.length() > maximum_offset.length() * 0.72
		)

		# Mouths, eyes and tails must start from a known surface connection.
		# Earlier saves can contain offsets that are numerically small compared
		# with a long body, but still leave a visible gap at the attachment point.
		if (
			migrate_critical_connections
			and _is_critical_attachment(category_id)
		):
			invalid = true

		if invalid:
			reset_indices.append(index)

	for part_index in reset_indices:
		Anatomy.reset_part_anchor(blueprint, part_index)
		changed = true

	if migrate_critical_connections:
		generation["attachment_schema_version"] = (
			ATTACHMENT_SCHEMA_VERSION
		)
		blueprint["generation"] = generation
		changed = true

	Anatomy.rebind_all_parts(blueprint)
	return changed


static func _is_critical_attachment(category_id: String) -> bool:
	return category_id in [
		PartLibrary.CATEGORY_MOUTH,
		PartLibrary.CATEGORY_EYES,
		PartLibrary.CATEGORY_TAIL,
	]


static func _get_maximum_offset(
	category_id: String,
	body_shape: Vector3
) -> Vector3:
	match category_id:
		PartLibrary.CATEGORY_MOUTH:
			return Vector3(
				maxf(body_shape.x * 0.10, 0.14),
				maxf(body_shape.y * 0.12, 0.14),
				maxf(body_shape.z * 0.035, 0.16)
			)
		PartLibrary.CATEGORY_EYES:
			return Vector3(
				maxf(body_shape.x * 0.10, 0.14),
				maxf(body_shape.y * 0.12, 0.14),
				maxf(body_shape.z * 0.03, 0.14)
			)
		PartLibrary.CATEGORY_TAIL:
			return Vector3(
				maxf(body_shape.x * 0.10, 0.15),
				maxf(body_shape.y * 0.12, 0.15),
				maxf(body_shape.z * 0.04, 0.18)
			)
		_:
			return Vector3(
				maxf(body_shape.x * 0.38, 0.32),
				maxf(body_shape.y * 0.42, 0.32),
				maxf(body_shape.z * 0.24, 0.42)
			)
