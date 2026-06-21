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

	_create_high_detail_body_shell(
		body_root,
		shape,
		base_color
	)
	_create_spine_highlight_blocks(
		body_root,
		shape,
		accent_color.darkened(0.28)
	)
	_create_body_pattern(
		body_root,
		shape,
		paint_part,
		accent_color
	)


func _create_high_detail_body_shell(
	body_root: Node3D,
	shape: Vector3,
	base_color: Color
) -> void:
	# V3: deutlich feinere Voxelauflösung.
	# Der Körper besteht nicht mehr aus wenigen großen Segmenten,
	# sondern aus 16-32 dünnen Querschnitten mit kleinen Randvoxeln.
	var segment_count: int = clampi(
		roundi(shape.z * 9.5),
		16,
		32
	)
	var segment_length: float = shape.z / float(segment_count)
	var start_z: float = -shape.z * 0.5 + segment_length * 0.5

	for segment_index in range(segment_count):
		var t: float = 0.0

		if segment_count > 1:
			t = float(segment_index) / float(segment_count - 1)

		var taper: float = absf(t - 0.5) * 0.46
		var width: float = shape.x * (1.0 - taper)
		var height: float = shape.y * (1.0 - taper * 0.52)
		var z: float = start_z + float(segment_index) * segment_length

		_create_body_slice_voxels(
			body_root,
			segment_index,
			z,
			width,
			height,
			segment_length,
			base_color
		)


func _create_body_slice_voxels(
	body_root: Node3D,
	segment_index: int,
	z: float,
	width: float,
	height: float,
	segment_length: float,
	base_color: Color
) -> void:
	var target_voxel_size: float = 0.115
	var columns_x: int = clampi(
		ceili(width / target_voxel_size),
		6,
		14
	)
	var rows_y: int = clampi(
		ceili(height / target_voxel_size),
		5,
		12
	)

	var voxel_size := Vector3(
		width / float(columns_x),
		height / float(rows_y),
		segment_length * 0.92
	)

	for y_index in range(rows_y):
		for x_index in range(columns_x):
			var normalized_x: float = (
				(float(x_index) + 0.5) / float(columns_x)
				* 2.0
				- 1.0
			)
			var normalized_y: float = (
				(float(y_index) + 0.5) / float(rows_y)
				* 2.0
				- 1.0
			)

			var distance: float = (
				normalized_x * normalized_x
				+ normalized_y * normalized_y
			)

			if distance > 1.0:
				continue

			if not _is_body_surface_voxel(
				x_index,
				y_index,
				columns_x,
				rows_y
			):
				continue

			var x: float = (
				-float(columns_x) * 0.5
				+ float(x_index)
				+ 0.5
			) * voxel_size.x
			var y: float = (
				-float(rows_y) * 0.5
				+ float(y_index)
				+ 0.5
			) * voxel_size.y

			var color_variation: float = (
				float((segment_index + x_index + y_index) % 4)
				* 0.025
			)
			var voxel_color: Color = base_color.lightened(color_variation)

			_create_box(
				body_root,
				"BodyVoxel%02d_%02d_%02d" % [
					segment_index,
					x_index,
					y_index
				],
				Vector3(x, y, z),
				voxel_size * 0.96,
				voxel_color,
				false
			)


func _is_body_surface_voxel(
	x_index: int,
	y_index: int,
	columns_x: int,
	rows_y: int
) -> bool:
	if (
		x_index == 0
		or y_index == 0
		or x_index == columns_x - 1
		or y_index == rows_y - 1
	):
		return true

	var neighbors: Array[Vector2i] = [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
	]

	for neighbor in neighbors:
		var nx: int = x_index + neighbor.x
		var ny: int = y_index + neighbor.y

		var normalized_x: float = (
			(float(nx) + 0.5) / float(columns_x)
			* 2.0
			- 1.0
		)
		var normalized_y: float = (
			(float(ny) + 0.5) / float(rows_y)
			* 2.0
			- 1.0
		)

		if (
			normalized_x * normalized_x
			+ normalized_y * normalized_y
			> 1.0
		):
			return true

	return false


func _create_spine_highlight_blocks(
	body_root: Node3D,
	shape: Vector3,
	spine_color: Color
) -> void:
	var spine_count: int = clampi(
		roundi(shape.z * 6.0),
		10,
		22
	)
	var spine_length: float = shape.z / float(spine_count)

	for index in range(spine_count):
		var t: float = 0.0

		if spine_count > 1:
			t = float(index) / float(spine_count - 1)

		var z: float = -shape.z * 0.5 + spine_length * 0.5 + float(index) * spine_length
		var taper: float = absf(t - 0.5) * 0.46
		var height: float = shape.y * (1.0 - taper * 0.52)

		_create_box(
			body_root,
			"SpineVoxel%02d" % index,
			Vector3(0.0, height * 0.54, z),
			Vector3(shape.x * 0.16, 0.055, spine_length * 0.62),
			spine_color,
			false
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
	root.set_meta("creature_part_index", part_index)
	root.set_meta("creature_part_category", category_id)
	root.set_meta("creature_part_side", side)

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

		_create_detail_box(
			root,
			"Voxel%02d" % voxel_index,
			voxel_position,
			voxel_size,
			_get_part_color(voxel_color, is_selected),
			is_selected
		)

	_setup_part_root_collider(
		root,
		voxels,
		side
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


func _create_detail_box(
	parent: Node3D,
	box_name: String,
	local_position: Vector3,
	box_size: Vector3,
	box_color: Color,
	is_highlighted: bool
) -> void:
	# Einzelteile werden aus mehreren kleinen Voxeln aufgebaut.
	# Dadurch wirken Augen, Hörner, Klauen und Platten nicht mehr wie
	# nur 3-5 große Bauklötze, sondern deutlich feiner.
	var target_voxel_size: float = 0.105
	var x_count: int = clampi(ceili(box_size.x / target_voxel_size), 1, 5)
	var y_count: int = clampi(ceili(box_size.y / target_voxel_size), 1, 5)
	var z_count: int = clampi(ceili(box_size.z / target_voxel_size), 1, 5)

	var small_size := Vector3(
		box_size.x / float(x_count),
		box_size.y / float(y_count),
		box_size.z / float(z_count)
	)

	for x_index in range(x_count):
		for y_index in range(y_count):
			for z_index in range(z_count):
				if not _is_detail_surface_voxel(
					x_index,
					y_index,
					z_index,
					x_count,
					y_count,
					z_count
				):
					continue

				var offset := Vector3(
					(-float(x_count) * 0.5 + float(x_index) + 0.5) * small_size.x,
					(-float(y_count) * 0.5 + float(y_index) + 0.5) * small_size.y,
					(-float(z_count) * 0.5 + float(z_index) + 0.5) * small_size.z
				)

				_create_box(
					parent,
					"%s_%d_%d_%d" % [
						box_name,
						x_index,
						y_index,
						z_index
					],
					local_position + offset,
					small_size * 0.94,
					box_color,
					is_highlighted
				)


func _is_detail_surface_voxel(
	x_index: int,
	y_index: int,
	z_index: int,
	x_count: int,
	y_count: int,
	z_count: int
) -> bool:
	return (
		x_index == 0
		or y_index == 0
		or z_index == 0
		or x_index == x_count - 1
		or y_index == y_count - 1
		or z_index == z_count - 1
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


func _setup_part_root_collider(
	part_root: Node3D,
	voxels: Array,
	side: float
) -> void:
	if not part_root.has_meta("creature_part_index"):
		return

	var minimum := Vector3(9999.0, 9999.0, 9999.0)
	var maximum := Vector3(-9999.0, -9999.0, -9999.0)

	for voxel in voxels:
		if not (voxel is Dictionary):
			continue

		var position: Vector3 = Blueprint._as_vector3(
			voxel.get("position", Vector3.ZERO)
		)
		var size: Vector3 = Blueprint._as_vector3(
			voxel.get("size", Vector3.ONE * 0.25)
		)
		position.x *= side

		var half_size: Vector3 = size * 0.5
		minimum.x = minf(minimum.x, position.x - half_size.x)
		minimum.y = minf(minimum.y, position.y - half_size.y)
		minimum.z = minf(minimum.z, position.z - half_size.z)
		maximum.x = maxf(maximum.x, position.x + half_size.x)
		maximum.y = maxf(maximum.y, position.y + half_size.y)
		maximum.z = maxf(maximum.z, position.z + half_size.z)

	if maximum.x < minimum.x:
		return

	var collider := StaticBody3D.new()
	collider.name = "PartPickCollider"
	collider.set_meta(
		"creature_part_index",
		int(part_root.get_meta("creature_part_index"))
	)
	collider.set_meta(
		"creature_part_category",
		str(part_root.get_meta("creature_part_category"))
	)
	collider.set_meta(
		"creature_part_side",
		float(part_root.get_meta("creature_part_side"))
	)

	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = (maximum - minimum) + Vector3(0.18, 0.18, 0.18)
	collision_shape.shape = shape
	collision_shape.position = (minimum + maximum) * 0.5

	collider.add_child(collision_shape)
	part_root.add_child(collider)


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
