extends "res://creatures/editor/creature_preview_v4.gd"
class_name CreatureRuntimePreview

const RUNTIME_VOXEL_TARGET_SIZE: float = 0.16
const RUNTIME_VOXEL_OVERLAP_XY: float = 1.04
const RUNTIME_VOXEL_OVERLAP_Z: float = 1.10


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
		ceili(width / RUNTIME_VOXEL_TARGET_SIZE),
		5,
		14
	)
	var rows_y: int = clampi(
		ceili(height / RUNTIME_VOXEL_TARGET_SIZE),
		4,
		12
	)
	var cell_width: float = width / float(columns_x)
	var cell_height: float = height / float(rows_y)
	var voxel_size := Vector3(
		cell_width * RUNTIME_VOXEL_OVERLAP_XY,
		cell_height * RUNTIME_VOXEL_OVERLAP_XY,
		segment_length * RUNTIME_VOXEL_OVERLAP_Z
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
			var color_variation: float = float(color_index) * 0.012
			var voxel_color: Color = base_color

			if color_index % 2 == 0:
				voxel_color = base_color.lightened(color_variation)
			else:
				voxel_color = base_color.darkened(
					color_variation * 0.55
				)

			_create_box(
				slice_root,
				"RuntimeBodyVoxel_%02d_%02d_%02d" % [
					segment_index,
					x_index,
					y_index,
				],
				Vector3(x_position, y_position, z_position),
				voxel_size,
				voxel_color,
				false
			)
