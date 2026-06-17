extends Node3D
class_name CreaturePreview


const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const PartLibrary = preload("res://creatures/editor/creature_part_library.gd")


var blueprint: Dictionary = {}
var selected_part_index: int = -1

var _material_cache: Dictionary = {}


func _ready() -> void:
	if blueprint.is_empty():
		blueprint = Blueprint.create_default()

	rebuild()


func set_blueprint(new_blueprint: Dictionary) -> void:
	blueprint = new_blueprint
	rebuild()


func set_selected_part_index(new_selected_part_index: int) -> void:
	selected_part_index = new_selected_part_index
	rebuild()


func rebuild() -> void:
	_clear_preview()

	if blueprint.is_empty():
		return

	_create_body()
	_create_all_parts()


func _clear_preview() -> void:
	for child in get_children():
		child.queue_free()


func _create_body() -> void:
	var body_root := Node3D.new()
	body_root.name = "Body"
	add_child(body_root)

	var body_part: Dictionary = PartLibrary.get_part(
		Blueprint.get_body_part_id(blueprint)
	)
	var paint_part: Dictionary = PartLibrary.get_part(
		Blueprint.get_paint_part_id(blueprint)
	)

	var shape: Vector3 = Blueprint.get_body_shape(blueprint)
	var body_scale: float = Blueprint.get_body_scale(blueprint)
	var base_color: Color = _get_body_color(body_part, paint_part)
	var accent_color: Color = _get_accent_color(paint_part)

	shape *= body_scale

	var segment_count: int = clampi(roundi(shape.z * 3.0), 4, 10)
	var segment_length: float = shape.z / float(segment_count)
	var start_z: float = -shape.z * 0.5 + segment_length * 0.5

	for index in range(segment_count):
		var t: float = 0.0

		if segment_count > 1:
			t = float(index) / float(segment_count - 1)

		var taper: float = absf(t - 0.5) * 0.42
		var segment_width: float = shape.x * (1.0 - taper)
		var segment_height: float = shape.y * (1.0 - taper * 0.45)
		var position_z: float = start_z + float(index) * segment_length

		_create_box(
			body_root,
			"BodySegment%02d" % index,
			Vector3(0.0, 0.0, position_z),
			Vector3(segment_width, segment_height, segment_length * 1.05),
			base_color,
			false
		)

	_create_body_pattern(
		body_root,
		shape,
		paint_part,
		accent_color
	)


func _create_body_pattern(
	body_root: Node3D,
	shape: Vector3,
	paint_part: Dictionary,
	accent_color: Color
) -> void:
	var pattern: String = str(paint_part.get("pattern", "plain"))
	var intensity: float = Blueprint.get_paint_intensity(blueprint)

	if pattern == "plain" or intensity <= 0.01:
		return

	var pattern_color: Color = accent_color.lerp(
		Color.WHITE,
		1.0 - intensity
	)

	match pattern:
		"spots":
			_create_spots_pattern(body_root, shape, pattern_color)
		"stripes":
			_create_stripes_pattern(body_root, shape, pattern_color)
		"warning":
			_create_warning_pattern(body_root, shape, pattern_color)
		"crystal":
			_create_crystal_pattern(body_root, shape, pattern_color)
		_:
			pass


func _create_spots_pattern(
	body_root: Node3D,
	shape: Vector3,
	pattern_color: Color
) -> void:
	var positions: Array = [
		Vector3(-shape.x * 0.28, shape.y * 0.52, -shape.z * 0.22),
		Vector3(shape.x * 0.18, shape.y * 0.54, -shape.z * 0.05),
		Vector3(-shape.x * 0.10, shape.y * 0.55, shape.z * 0.18),
		Vector3(shape.x * 0.30, shape.y * 0.48, shape.z * 0.30),
	]

	for index in range(positions.size()):
		_create_box(
			body_root,
			"Spot%02d" % index,
			positions[index],
			Vector3(shape.x * 0.16, 0.035, shape.z * 0.09),
			pattern_color,
			false
		)


func _create_stripes_pattern(
	body_root: Node3D,
	shape: Vector3,
	pattern_color: Color
) -> void:
	for index in range(4):
		var z: float = -shape.z * 0.36 + float(index) * shape.z * 0.24

		_create_box(
			body_root,
			"Stripe%02d" % index,
			Vector3(0.0, shape.y * 0.54, z),
			Vector3(shape.x * 0.82, 0.04, shape.z * 0.055),
			pattern_color,
			false
		)


func _create_warning_pattern(
	body_root: Node3D,
	shape: Vector3,
	pattern_color: Color
) -> void:
	_create_box(
		body_root,
		"WarningMarkA",
		Vector3(-shape.x * 0.18, shape.y * 0.55, -shape.z * 0.16),
		Vector3(shape.x * 0.16, 0.05, shape.z * 0.44),
		pattern_color,
		false
	)
	_create_box(
		body_root,
		"WarningMarkB",
		Vector3(shape.x * 0.18, shape.y * 0.55, shape.z * 0.12),
		Vector3(shape.x * 0.16, 0.05, shape.z * 0.44),
		pattern_color,
		false
	)


func _create_crystal_pattern(
	body_root: Node3D,
	shape: Vector3,
	pattern_color: Color
) -> void:
	var positions: Array = [
		Vector3(-shape.x * 0.25, shape.y * 0.62, -shape.z * 0.22),
		Vector3(shape.x * 0.22, shape.y * 0.65, 0.0),
		Vector3(0.0, shape.y * 0.68, shape.z * 0.24),
	]

	for index in range(positions.size()):
		_create_box(
			body_root,
			"CrystalPaint%02d" % index,
			positions[index],
			Vector3(0.16, 0.28, 0.16),
			pattern_color,
			false
		)


func _create_all_parts() -> void:
	var parts: Array = blueprint.get("parts", [])

	for index in range(parts.size()):
		var placement: Variant = parts[index]

		if not (placement is Dictionary):
			continue

		_create_part_instance(placement, index)


func _create_part_instance(
	placement: Dictionary,
	part_index: int
) -> void:
	var part_id: String = str(placement.get("part_id", ""))
	var part_definition: Dictionary = PartLibrary.get_part(part_id)

	if part_definition.is_empty():
		return

	var category_id: String = str(placement.get("category", ""))
	var mirrored: bool = bool(placement.get("mirrored", false))
	var base_position: Vector3 = Blueprint._as_vector3(
		placement.get("position", Vector3.ZERO)
	)
	var rotation_degrees: Vector3 = Blueprint._as_vector3(
		placement.get("rotation", Vector3.ZERO)
	)
	var part_scale: float = float(placement.get("scale", 1.0))
	var is_selected: bool = part_index == selected_part_index

	if mirrored:
		_create_single_part_side(
			placement,
			part_definition,
			category_id,
			part_index,
			1.0,
			Vector3(absf(base_position.x), base_position.y, base_position.z),
			rotation_degrees,
			part_scale,
			is_selected
		)
		_create_single_part_side(
			placement,
			part_definition,
			category_id,
			part_index,
			-1.0,
			Vector3(-absf(base_position.x), base_position.y, base_position.z),
			rotation_degrees,
			part_scale,
			is_selected
		)
		return

	_create_single_part_side(
		placement,
		part_definition,
		category_id,
		part_index,
		1.0,
		base_position,
		rotation_degrees,
		part_scale,
		is_selected
	)


func _create_single_part_side(
	placement: Dictionary,
	part_definition: Dictionary,
	category_id: String,
	part_index: int,
	side: float,
	part_position: Vector3,
	rotation_degrees: Vector3,
	part_scale: float,
	is_selected: bool
) -> void:
	var root := Node3D.new()
	root.name = "%s_%s_%d" % [
		category_id,
		str(placement.get("uid", "part")),
		int(side)
	]
	root.position = part_position
	root.rotation_degrees = rotation_degrees
	root.scale = Vector3.ONE * part_scale

	add_child(root)

	var voxels: Array = part_definition.get("voxels", [])

	for voxel_index in range(voxels.size()):
		var voxel: Variant = voxels[voxel_index]

		if not (voxel is Dictionary):
			continue

		var voxel_position: Vector3 = Blueprint._as_vector3(
			voxel.get("position", Vector3.ZERO)
		)
		var voxel_size: Vector3 = Blueprint._as_vector3(
			voxel.get("size", Vector3.ONE * 0.25)
		)
		var voxel_color: Color = voxel.get(
			"color",
			Color(0.65, 0.55, 0.45, 1.0)
		)

		voxel_position.x *= side

		_create_box(
			root,
			"Voxel%02d" % voxel_index,
			voxel_position,
			voxel_size,
			_get_part_color(voxel_color, is_selected),
			is_selected
		)

	if is_selected:
		_create_selection_marker(root)


func _create_selection_marker(part_root: Node3D) -> void:
	_create_box(
		part_root,
		"SelectionMarker",
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.08, 0.08, 0.08),
		Color(1.0, 0.95, 0.15, 1.0),
		true
	)


func _create_box(
	parent: Node3D,
	box_name: String,
	local_position: Vector3,
	box_size: Vector3,
	box_color: Color,
	is_highlighted: bool
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = box_name
	mesh_instance.position = local_position

	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _get_material(
		box_color,
		is_highlighted
	)
	mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)

	parent.add_child(mesh_instance)

	return mesh_instance


func _get_body_color(
	body_part: Dictionary,
	paint_part: Dictionary
) -> Color:
	var body_color: Color = body_part.get(
		"color",
		Color(0.70, 0.55, 0.38, 1.0)
	)
	var tint: Color = paint_part.get(
		"base_tint",
		Color.WHITE
	)
	var intensity: float = Blueprint.get_paint_intensity(blueprint)

	var tinted := Color(
		body_color.r * tint.r,
		body_color.g * tint.g,
		body_color.b * tint.b,
		1.0
	)

	return body_color.lerp(tinted, intensity)


func _get_accent_color(paint_part: Dictionary) -> Color:
	return paint_part.get(
		"accent",
		Color(0.18, 0.22, 0.12, 1.0)
	)


func _get_part_color(
	base_color: Color,
	is_selected: bool
) -> Color:
	if is_selected:
		return base_color.lightened(0.22)

	return base_color


func _get_material(
	color: Color,
	is_highlighted: bool
) -> StandardMaterial3D:
	var key: String = "%s_%s" % [color.to_html(), str(is_highlighted)]

	if _material_cache.has(key):
		return _material_cache[key]

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_BACK

	if is_highlighted:
		material.emission_enabled = true
		material.emission = color.lightened(0.35)
		material.emission_energy_multiplier = 0.20

	_material_cache[key] = material

	return material
