extends "res://creatures/editor/creature_preview_v4.gd"
class_name CreatureRuntimePreview

const RUNTIME_VOXEL_TARGET_SIZE: float = 0.16
const RUNTIME_VOXEL_OVERLAP_XY: float = 1.04
const RUNTIME_VOXEL_OVERLAP_Z: float = 1.10
const InstanceBuffer = preload("res://core/multimesh_buffer.gd")
const SculptSurface = preload("res://creatures/editor/creature_sculpt_surface.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Motion = preload("res://creatures/runtime/creature_sculpt_motion.gd")

# Kept for compatibility: true selects the editable, cubic surface; false
# selects the original independently batched slice renderer.
var sculpted_surface: bool = true
var motion_mode: String = "edit"
var _motion := Motion.new()
var _motion_time: float = 0.0

# Runtime-only batching preserves body-slice and attachment roots. Leg meshes
# remain individual because the adaptive animator reparents them into knee rigs.
var batch_runtime_boxes: bool = true
var _pending_boxes: Dictionary = {}
static var _shared_box: BoxMesh
static var _shared_box_material: StandardMaterial3D


func rebuild() -> void:
	_motion.reset()
	_pending_boxes.clear()
	super.rebuild()
	for parent: Node3D in _pending_boxes:
		var boxes: Array = _pending_boxes[parent]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		if _shared_box == null:
			_shared_box = BoxMesh.new()
			_shared_box.size = Vector3.ONE
		mm.mesh = _shared_box
		mm.instance_count = boxes.size()
		var bounds: AABB
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		for index in range(boxes.size()):
			var box: Dictionary = boxes[index]
			var transform := Transform3D(Basis.from_scale(box["size"]), box["position"])
			transforms.append(transform)
			colors.append(box["color"])
			var box_bounds: AABB = transform * _shared_box.get_aabb()
			bounds = box_bounds if index == 0 else bounds.merge(box_bounds)
		mm.custom_aabb = bounds
		mm.buffer = InstanceBuffer.pack(transforms, colors)
		var node := MultiMeshInstance3D.new()
		node.name = "RuntimeVoxelBatch"
		node.multimesh = mm
		if _shared_box_material == null:
			_shared_box_material = StandardMaterial3D.new()
			_shared_box_material.vertex_color_use_as_albedo = true
			_shared_box_material.vertex_color_is_srgb = true
			_shared_box_material.roughness = 1.0
			_shared_box_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		node.material_override = _shared_box_material
		parent.add_child(node)
	_pending_boxes.clear()
	if motion_mode != "edit":
		_motion.bind(self)
	set_process(motion_mode != "edit")


func set_motion(mode: String) -> void:
	_motion.reset()
	motion_mode = mode if mode in ["edit", "idle", "walk", "run"] else "edit"
	_motion_time = 0.0
	if motion_mode != "edit":
		_motion.bind(self)
	set_process(motion_mode != "edit")


func _process(delta: float) -> void:
	_motion_time += delta
	_motion.sample(motion_mode, _motion_time)


func _create_body() -> void:
	if not sculpted_surface:
		super._create_body()
		return
	var root := Node3D.new()
	root.name = "BodyV4"
	add_child(root)
	var skin := MeshInstance3D.new()
	skin.name = "SculptedSkin"
	skin.mesh = SculptSurface.build_skin(blueprint)
	skin.material_override = SculptSurface.material(Color.WHITE, true)
	root.add_child(skin)
	if show_spine_handles:
		for index in range(SpineProfile.SEGMENT_COUNT):
			var segment: Dictionary = SpineProfile.get_segment(blueprint, index)
			var section: Dictionary = SculptSurface.section(blueprint, float(segment["t"]))
			var handle := StaticBody3D.new()
			handle.name = "SpineHandleV4_%d" % index
			handle.set_meta("creature_spine_index", index)
			handle.collision_layer = HANDLE_COLLISION_LAYER
			handle.collision_mask = 0
			handle.position = section["center"] + Vector3.UP * (section["radius"].y + 0.13)
			root.add_child(handle)
			var color := Color("fff1bd") if index == selected_body_segment else Color("8ae3ce")
			var cube := MeshInstance3D.new()
			cube.name = "Handle"
			var box := BoxMesh.new()
			box.size = Vector3.ONE * 0.13
			cube.mesh = box
			cube.material_override = SculptSurface.material(color)
			cube.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cube.material_override.no_depth_test = true
			handle.add_child(cube)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3.ONE * 0.20
			collision.shape = shape
			handle.add_child(collision)


func _create_all_parts() -> void:
	if not sculpted_surface:
		super._create_all_parts()
		return
	Anatomy.ensure_anchors(blueprint, true)
	Anatomy.rebind_all_parts(blueprint)
	var parts: Array = blueprint.get("parts", [])
	for index in range(parts.size()):
		if parts[index] is Dictionary:
			# Anchor positions already include spine width, height and length.
			# V4's extra display transform applied those factors a second time.
			_create_part_instance(parts[index], index)


func _create_detail_box(parent: Node3D, box_name: String, local_position: Vector3,
	box_size: Vector3, box_color: Color, is_highlighted: bool) -> void:
	if sculpted_surface:
		SculptSurface.make_part_piece(parent, box_name, local_position, box_size, box_color, blueprint)
	else:
		super._create_detail_box(parent, box_name, local_position, box_size, box_color, is_highlighted)


func _get_part_color(color: Color, is_selected: bool) -> Color:
	return color if sculpted_surface else super._get_part_color(color, is_selected)


func _create_selection_marker(part_root: Node3D) -> void:
	if not sculpted_surface:
		super._create_selection_marker(part_root)
		return
	var marker := MeshInstance3D.new()
	marker.name = "SelectionRing"
	var frame: Dictionary = {}
	for x in range(-5, 5):
		for z in range(-5, 5):
			if x in [-5, 4] or z in [-5, 4]:
				frame[Vector3i(x, 0, z)] = Color.WHITE
	marker.mesh = SculptSurface.Voxels.from_cells(frame, 0.035)
	marker.material_override = SculptSurface.material(Color("9affd9"))
	marker.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override.no_depth_test = true
	part_root.add_child(marker)


func _clear_preview() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _create_box(parent: Node3D, box_name: String, local_position: Vector3,
	box_size: Vector3, box_color: Color, is_highlighted: bool) -> MeshInstance3D:
	if not batch_runtime_boxes or is_highlighted or str(parent.get_meta("creature_part_category", "")) == "legs":
		return super._create_box(parent, box_name, local_position, box_size, box_color, is_highlighted)
	if not _pending_boxes.has(parent):
		_pending_boxes[parent] = []
	_pending_boxes[parent].append({"position": local_position, "size": box_size, "color": box_color})
	# The inherited body/attachment builders do not retain individual box nodes.
	return null


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
