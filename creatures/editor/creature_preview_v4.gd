extends "res://creatures/editor/creature_preview.gd"

const BaseBlueprint = preload(
	"res://creatures/editor/creature_blueprint.gd"
)

const BasePartLibrary = preload(
	"res://creatures/editor/creature_part_library.gd"
)

const SpineProfile = preload(
	"res://creatures/editor/creature_spine_profile.gd"
)

const HANDLE_COLLISION_LAYER: int = 1 << 5

const BODY_VOXEL_TARGET_SIZE: float = 0.105
const BODY_VOXEL_OVERLAP_XY: float = 1.045
const BODY_VOXEL_OVERLAP_Z: float = 1.12

var selected_body_segment: int = -1
var show_spine_handles: bool = false


func set_editor_state(
	new_blueprint: Dictionary,
	new_selected_part_index: int,
	new_selected_body_segment: int,
	new_show_spine_handles: bool
) -> void:
	blueprint = new_blueprint
	selected_part_index = new_selected_part_index
	selected_body_segment = new_selected_body_segment
	show_spine_handles = new_show_spine_handles

	rebuild()


func _create_body() -> void:
	SpineProfile.ensure_profile(blueprint)

	var body_root := Node3D.new()
	body_root.name = "BodyV4"
	add_child(body_root)

	var body_part: Dictionary = BasePartLibrary.get_part(
		BaseBlueprint.get_body_part_id(blueprint)
	)

	var paint_part: Dictionary = BasePartLibrary.get_part(
		BaseBlueprint.get_paint_part_id(blueprint)
	)

	var shape: Vector3 = BaseBlueprint.get_body_shape(
		blueprint
	)

	var body_scale: float = BaseBlueprint.get_body_scale(
		blueprint
	)

	var body_length_scale: float = (
		SpineProfile.get_body_length_scale(
			blueprint
		)
	)

	var base_color: Color = _get_body_color(
		body_part,
		paint_part
	)

	var accent_color: Color = _get_accent_color(
		paint_part
	)

	shape *= body_scale
	shape.z *= body_length_scale

	var segment_count: int = clampi(
		roundi(shape.z * 10.5),
		14,
		64
	)

	var segment_length: float = (
		shape.z / float(segment_count)
	)

	var start_z: float = (
		-shape.z * 0.5
		+ segment_length * 0.5
	)

	for segment_index in range(segment_count):
		var normalized_position: float = 0.5

		if segment_count > 1:
			normalized_position = (
				float(segment_index)
				/ float(segment_count - 1)
			)

		var profile: Dictionary = SpineProfile.sample(
			blueprint,
			normalized_position
		)

		var taper: float = (
			absf(normalized_position - 0.5)
			* 0.46
		)

		var width: float = (
			shape.x
			* (1.0 - taper)
			* float(
				profile.get(
					"width_scale",
					1.0
				)
			)
		)

		var height: float = (
			shape.y
			* (1.0 - taper * 0.52)
			* float(
				profile.get(
					"height_scale",
					1.0
				)
			)
		)

		var center_y: float = (
			float(
				profile.get(
					"y_offset",
					0.0
				)
			)
			* body_scale
		)

		var z_position: float = (
			start_z
			+ float(segment_index)
			* segment_length
		)

		var slice_root := Node3D.new()

		slice_root.name = (
			"BodySliceV4_%02d"
			% segment_index
		)

		slice_root.position.y = center_y
		body_root.add_child(slice_root)

		_create_seamless_body_slice(
			slice_root,
			segment_index,
			z_position,
			width,
			height,
			segment_length,
			base_color
		)

		_create_profile_ridge(
			body_root,
			segment_index,
			z_position,
			center_y,
			width,
			height,
			segment_length,
			accent_color
		)

		_create_profile_pattern_marker(
			body_root,
			paint_part,
			segment_index,
			segment_count,
			z_position,
			center_y,
			width,
			height,
			segment_length,
			accent_color
		)

	if show_spine_handles:
		_create_spine_handles(
			body_root,
			shape,
			body_scale
		)


func _create_seamless_body_slice(
	slice_root: Node3D,
	segment_index: int,
	z_position: float,
	width: float,
	height: float,
	segment_length: float,
	base_color: Color
) -> void:
	var columns_x: int = clampi(
		ceili(
			width / BODY_VOXEL_TARGET_SIZE
		),
		6,
		20
	)

	var rows_y: int = clampi(
		ceili(
			height / BODY_VOXEL_TARGET_SIZE
		),
		5,
		18
	)

	var cell_width: float = (
		width / float(columns_x)
	)

	var cell_height: float = (
		height / float(rows_y)
	)

	var voxel_size := Vector3(
		cell_width * BODY_VOXEL_OVERLAP_XY,
		cell_height * BODY_VOXEL_OVERLAP_XY,
		segment_length * BODY_VOXEL_OVERLAP_Z
	)

	for y_index in range(rows_y):
		for x_index in range(columns_x):
			var normalized_x: float = (
				(float(x_index) + 0.5)
				/ float(columns_x)
				* 2.0
				- 1.0
			)

			var normalized_y: float = (
				(float(y_index) + 0.5)
				/ float(rows_y)
				* 2.0
				- 1.0
			)

			var ellipse_distance: float = (
				normalized_x * normalized_x
				+ normalized_y * normalized_y
			)

			if ellipse_distance > 1.04:
				continue

			var x_position: float = (
				-float(columns_x) * 0.5
				+ float(x_index)
				+ 0.5
			) * cell_width

			var y_position: float = (
				-float(rows_y) * 0.5
				+ float(y_index)
				+ 0.5
			) * cell_height

			var color_index: int = (
				segment_index
				+ x_index * 2
				+ y_index * 3
			) % 5

			var color_variation: float = (
				float(color_index)
				* 0.012
			)

			var voxel_color: Color = base_color

			if color_index % 2 == 0:
				voxel_color = base_color.lightened(
					color_variation
				)
			else:
				voxel_color = base_color.darkened(
					color_variation * 0.55
				)

			_create_box(
				slice_root,
				"BodyVoxelV4_%02d_%02d_%02d" % [
					segment_index,
					x_index,
					y_index,
				],
				Vector3(
					x_position,
					y_position,
					z_position
				),
				voxel_size,
				voxel_color,
				false
			)


func _create_profile_ridge(
	body_root: Node3D,
	segment_index: int,
	z_position: float,
	center_y: float,
	width: float,
	height: float,
	segment_length: float,
	accent_color: Color
) -> void:
	if segment_index % 2 != 0:
		return

	_create_box(
		body_root,
		"ProfileRidgeV4_%02d"
		% segment_index,
		Vector3(
			0.0,
			center_y + height * 0.53,
			z_position
		),
		Vector3(
			maxf(width * 0.13, 0.055),
			0.052,
			segment_length * 1.02
		),
		accent_color.darkened(0.28),
		false
	)


func _create_profile_pattern_marker(
	body_root: Node3D,
	paint_part: Dictionary,
	segment_index: int,
	segment_count: int,
	z_position: float,
	center_y: float,
	width: float,
	height: float,
	segment_length: float,
	accent_color: Color
) -> void:
	var pattern: String = str(
		paint_part.get(
			"pattern",
			"plain"
		)
	)

	var intensity: float = (
		BaseBlueprint.get_paint_intensity(
			blueprint
		)
	)

	if pattern == "plain" or intensity <= 0.01:
		return

	var pattern_color: Color = accent_color.lerp(
		Color.WHITE,
		1.0 - intensity
	)

	match pattern:
		"stripes":
			if segment_index % 4 != 1:
				return

			for side in [-1.0, 1.0]:
				_create_box(
					body_root,
					"StripeV4_%02d_%d" % [
						segment_index,
						int(side),
					],
					Vector3(
						side * width * 0.50,
						center_y,
						z_position
					),
					Vector3(
						0.045,
						height * 0.48,
						segment_length * 1.04
					),
					pattern_color,
					false
				)

		"spots":
			if segment_index % 5 != 0:
				return

			var side: float = -1.0

			if segment_index % 10 == 0:
				side = 1.0

			_create_box(
				body_root,
				"SpotV4_%02d"
				% segment_index,
				Vector3(
					side * width * 0.42,
					center_y + height * 0.25,
					z_position
				),
				Vector3(
					0.09,
					0.09,
					segment_length * 1.04
				),
				pattern_color,
				false
			)

		"warning":
			if segment_index % 6 >= 2:
				return

			_create_box(
				body_root,
				"WarningV4_%02d"
				% segment_index,
				Vector3(
					0.0,
					center_y + height * 0.56,
					z_position
				),
				Vector3(
					width * 0.38,
					0.045,
					segment_length * 1.04
				),
				pattern_color,
				false
			)

		"crystal":
			var quarter: int = maxi(
				floori(
					float(segment_count)
					/ 4.0
				),
				1
			)

			if (
				segment_index != quarter
				and segment_index != quarter * 2
				and segment_index != quarter * 3
			):
				return

			_create_box(
				body_root,
				"CrystalV4_%02d"
				% segment_index,
				Vector3(
					0.0,
					center_y + height * 0.66,
					z_position
				),
				Vector3(
					0.14,
					0.24,
					0.14
				),
				pattern_color,
				false
			)


func _create_spine_handles(
	body_root: Node3D,
	shape: Vector3,
	body_scale: float
) -> void:
	for segment_index in range(
		SpineProfile.SEGMENT_COUNT
	):
		var normalized_position: float = (
			float(segment_index)
			/ float(
				SpineProfile.SEGMENT_COUNT - 1
			)
		)

		var profile: Dictionary = SpineProfile.sample(
			blueprint,
			normalized_position
		)

		var taper: float = (
			absf(normalized_position - 0.5)
			* 0.46
		)

		var height: float = (
			shape.y
			* (1.0 - taper * 0.52)
			* float(
				profile.get(
					"height_scale",
					1.0
				)
			)
		)

		var center_y: float = (
			float(
				profile.get(
					"y_offset",
					0.0
				)
			)
			* body_scale
		)

		var z_position: float = lerpf(
			-shape.z * 0.5,
			shape.z * 0.5,
			normalized_position
		)

		var body_top: float = (
			center_y
			+ height * 0.54
		)

		var handle_y: float = (
			body_top + 0.19
		)

		_create_box(
			body_root,
			"SpineStemV4_%02d"
			% segment_index,
			Vector3(
				0.0,
				body_top + 0.095,
				z_position
			),
			Vector3(
				0.035,
				0.19,
				0.035
			),
			Color(
				0.10,
				0.72,
				0.95,
				1.0
			),
			false
		)

		var handle_root := StaticBody3D.new()

		handle_root.name = (
			"SpineHandleV4_%02d"
			% segment_index
		)

		handle_root.position = Vector3(
			0.0,
			handle_y,
			z_position
		)

		handle_root.collision_layer = (
			HANDLE_COLLISION_LAYER
		)

		handle_root.collision_mask = 0

		handle_root.set_meta(
			"creature_spine_index",
			segment_index
		)

		body_root.add_child(handle_root)

		var is_selected: bool = (
			segment_index
			== selected_body_segment
		)

		var handle_size: float = 0.17

		var handle_color := Color(
			0.10,
			0.72,
			0.95,
			1.0
		)

		if is_selected:
			handle_size = 0.23

			handle_color = Color(
				1.0,
				0.86,
				0.12,
				1.0
			)

		_create_box(
			handle_root,
			"HandleVisual",
			Vector3.ZERO,
			Vector3.ONE * handle_size,
			handle_color,
			is_selected
		)

		var collision_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()

		box_shape.size = Vector3.ONE * maxf(
			handle_size,
			0.25
		)

		collision_shape.shape = box_shape
		handle_root.add_child(collision_shape)


func _create_all_parts() -> void:
	SpineProfile.ensure_profile(blueprint)

	var base_body_shape: Vector3 = (
		BaseBlueprint.get_body_shape(blueprint)
		* BaseBlueprint.get_body_scale(blueprint)
	)

	var body_scale: float = (
		BaseBlueprint.get_body_scale(blueprint)
	)

	var body_length_scale: float = (
		SpineProfile.get_body_length_scale(
			blueprint
		)
	)

	var displayed_body_length: float = (
		base_body_shape.z
		* body_length_scale
	)

	var parts: Array = blueprint.get(
		"parts",
		[]
	)

	for part_index in range(parts.size()):
		var placement_value: Variant = (
			parts[part_index]
		)

		if not (placement_value is Dictionary):
			continue

		var source_placement: Dictionary = (
			placement_value
		)

		var display_placement: Dictionary = (
			source_placement.duplicate(true)
		)

		var position: Vector3 = (
			BaseBlueprint._as_vector3(
				display_placement.get(
					"position",
					Vector3.ZERO
				)
			)
		)

		var normalized_position: float = 0.5

		if base_body_shape.z > 0.001:
			normalized_position = clampf(
				position.z
					/ base_body_shape.z
					+ 0.5,
				0.0,
				1.0
			)

		var profile: Dictionary = SpineProfile.sample(
			blueprint,
			normalized_position
		)

		position.x *= float(
			profile.get(
				"width_scale",
				1.0
			)
		)

		position.y = (
			float(
				profile.get(
					"y_offset",
					0.0
				)
			)
			* body_scale
			+ position.y
			* float(
				profile.get(
					"height_scale",
					1.0
				)
			)
		)

		position.z *= body_length_scale

		display_placement["position"] = position

		var before_t: float = maxf(
			normalized_position - 0.035,
			0.0
		)

		var after_t: float = minf(
			normalized_position + 0.035,
			1.0
		)

		var before_profile: Dictionary = (
			SpineProfile.sample(
				blueprint,
				before_t
			)
		)

		var after_profile: Dictionary = (
			SpineProfile.sample(
				blueprint,
				after_t
			)
		)

		var before_y: float = (
			float(
				before_profile.get(
					"y_offset",
					0.0
				)
			)
			* body_scale
		)

		var after_y: float = (
			float(
				after_profile.get(
					"y_offset",
					0.0
				)
			)
			* body_scale
		)

		var sample_length: float = maxf(
			(after_t - before_t)
				* displayed_body_length,
			0.001
		)

		var curve_angle: float = -rad_to_deg(
			atan2(
				after_y - before_y,
				sample_length
			)
		)

		var rotation: Vector3 = (
			BaseBlueprint._as_vector3(
				display_placement.get(
					"rotation",
					Vector3.ZERO
				)
			)
		)

		rotation.x += clampf(
			curve_angle,
			-35.0,
			35.0
		)

		display_placement["rotation"] = rotation

		_create_part_instance(
			display_placement,
			part_index
		)
