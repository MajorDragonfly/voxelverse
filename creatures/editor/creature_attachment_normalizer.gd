extends RefCounted
class_name CreatureAttachmentNormalizer

const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const PartLibrary = preload("res://creatures/editor/creature_part_library.gd")
const SpineProfile = preload("res://creatures/editor/creature_spine_profile.gd")

const ATTACHMENT_SCHEMA_VERSION: int = 3
const LONGITUDINAL_OVERLAP_MIN: float = 0.10
const LONGITUDINAL_OVERLAP_MAX: float = 0.20


# Schema 3 aligns longitudinal parts by their actual voxel bounds. V7 stores
# this technical migration version under assembly instead of generation so the
# active creature model contains no genetics-related metadata.
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

	var assembly: Dictionary = blueprint.get("assembly", {})
	var uses_assembly_schema: bool = int(assembly.get("schema", 0)) >= 7
	var generation: Dictionary = blueprint.get("generation", {})
	var source_schema_version: int = int(
		assembly.get("attachment_schema_version", 0)
		if uses_assembly_schema
		else generation.get("attachment_schema_version", 0)
	)
	var migrate_connections: bool = (
		source_schema_version < ATTACHMENT_SCHEMA_VERSION
	)

	var changed: bool = false
	var reset_indices: Array[int] = []
	var parts: Array = blueprint.get("parts", [])

	for index in range(parts.size()):
		if not (parts[index] is Dictionary):
			continue
		var placement: Dictionary = parts[index]
		var category_id: String = str(placement.get("category", ""))
		var manual_offset: Vector3 = Blueprint._as_vector3(
			placement.get("manual_offset", Vector3.ZERO)
		)
		var maximum_offset: Vector3 = _get_maximum_offset(category_id, body_shape)
		var invalid: bool = (
			force_rebind
			or absf(manual_offset.x) > maximum_offset.x
			or absf(manual_offset.y) > maximum_offset.y
			or absf(manual_offset.z) > maximum_offset.z
			or manual_offset.length() > maximum_offset.length() * 0.72
		)
		if migrate_connections and _is_critical_attachment(category_id):
			invalid = true
		if invalid:
			reset_indices.append(index)

	for part_index in reset_indices:
		Anatomy.reset_part_anchor(blueprint, part_index)
		changed = true

	if migrate_connections or force_rebind:
		changed = _repair_longitudinal_connections(blueprint, body_shape) or changed

	if migrate_connections:
		if uses_assembly_schema:
			assembly["attachment_schema_version"] = ATTACHMENT_SCHEMA_VERSION
			blueprint["assembly"] = assembly
			blueprint.erase("generation")
		else:
			generation["attachment_schema_version"] = ATTACHMENT_SCHEMA_VERSION
			blueprint["generation"] = generation
		changed = true

	Anatomy.rebind_all_parts(blueprint)
	return changed


static func _repair_longitudinal_connections(
	blueprint: Dictionary,
	body_shape: Vector3
) -> bool:
	var parts: Array = blueprint.get("parts", [])
	var changed := false
	var overlap: float = clampf(
		body_shape.z * 0.045,
		LONGITUDINAL_OVERLAP_MIN,
		LONGITUDINAL_OVERLAP_MAX
	)

	for index in range(parts.size()):
		if not (parts[index] is Dictionary):
			continue
		var placement: Dictionary = parts[index]
		var category_id: String = str(placement.get("category", ""))
		if category_id not in [
			PartLibrary.CATEGORY_MOUTH,
			PartLibrary.CATEGORY_TAIL,
		]:
			continue

		var part_definition: Dictionary = PartLibrary.get_part(
			str(placement.get("part_id", ""))
		)
		var bounds: Vector2 = _get_part_z_bounds(part_definition)
		var part_scale: float = maxf(float(placement.get("scale", 1.0)), 0.05)
		var surface_offset := Blueprint._as_vector3(
			placement.get("anchor_surface_offset", Vector3.ZERO)
		)

		placement["manual_offset"] = Vector3.ZERO
		placement["anchor_locked"] = true
		placement["anchor_side"] = 0.0
		if category_id == PartLibrary.CATEGORY_MOUTH:
			placement["anchor_t"] = 0.0
			placement["anchor_vertical"] = 0.02
			# Place the part's rear-most face slightly inside the body front.
			surface_offset.z = overlap - bounds.y * part_scale
		else:
			placement["anchor_t"] = 1.0
			placement["anchor_vertical"] = -0.02
			# Place the part's front-most face slightly inside the body rear.
			surface_offset.z = -overlap - bounds.x * part_scale
		placement["anchor_surface_offset"] = surface_offset
		parts[index] = placement
		changed = true

	blueprint["parts"] = parts
	return changed


static func _get_part_z_bounds(part_definition: Dictionary) -> Vector2:
	var minimum_z := 0.0
	var maximum_z := 0.0
	var initialized := false
	var voxels: Array = part_definition.get("voxels", [])
	for voxel_value in voxels:
		if not (voxel_value is Dictionary):
			continue
		var voxel: Dictionary = voxel_value
		var voxel_position: Vector3 = Blueprint._as_vector3(
			voxel.get("position", Vector3.ZERO)
		)
		var voxel_size: Vector3 = Blueprint._as_vector3(
			voxel.get("size", Vector3.ONE * 0.25)
		)
		var low: float = voxel_position.z - voxel_size.z * 0.5
		var high: float = voxel_position.z + voxel_size.z * 0.5
		if not initialized:
			minimum_z = low
			maximum_z = high
			initialized = true
		else:
			minimum_z = minf(minimum_z, low)
			maximum_z = maxf(maximum_z, high)
	return Vector2(minimum_z, maximum_z)


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
			return Vector3(maxf(body_shape.x * 0.10, 0.14), maxf(body_shape.y * 0.12, 0.14), maxf(body_shape.z * 0.035, 0.16))
		PartLibrary.CATEGORY_EYES:
			return Vector3(maxf(body_shape.x * 0.10, 0.14), maxf(body_shape.y * 0.12, 0.14), maxf(body_shape.z * 0.03, 0.14))
		PartLibrary.CATEGORY_TAIL:
			return Vector3(maxf(body_shape.x * 0.10, 0.15), maxf(body_shape.y * 0.12, 0.15), maxf(body_shape.z * 0.04, 0.18))
		_:
			return Vector3(maxf(body_shape.x * 0.38, 0.32), maxf(body_shape.y * 0.42, 0.32), maxf(body_shape.z * 0.24, 0.42))
