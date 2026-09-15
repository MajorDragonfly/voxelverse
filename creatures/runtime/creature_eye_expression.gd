extends RefCounted
## Local eyelids and pupil motion. Mesh bounds define the socket, not nominal
## recipe sizes: voxel rounding must not leave white/iris in front of a brow.
const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")
const LID_COLUMNS: int = 16
static var _lid_mesh: BoxMesh
var _eyes: Array[Dictionary] = []


static func prepare(root: Node3D, prefix: String, color: Color, blueprint: Dictionary) -> void:
	var pieces: Array[Dictionary] = []
	var bounds: AABB
	var iris_bounds: AABB
	for suffix: String in ["Sclera", "Iris", "Pupil", "Glint"]:
		var node: MeshInstance3D = root.get_node(prefix + suffix)
		var box: AABB = node.transform * node.mesh.get_aabb()
		bounds = box if pieces.is_empty() else bounds.merge(box)
		if suffix != "Sclera":
			iris_bounds = box if suffix == "Iris" else iris_bounds.merge(box)
		pieces.append({"node": node, "rest": node.transform, "gaze": suffix != "Sclera"})
	var globe: MeshInstance3D = pieces[0].node
	var white: AABB = globe.transform * globe.mesh.get_aabb()
	var padding: float = maxf(minf(white.size.x, white.size.y) * 0.025, 0.0001)
	var record: Dictionary = {"parts": pieces, "bounds": bounds, "white": white,
		"iris_bounds": iris_bounds, "padding": padding}
	if _lid_mesh == null:
		_lid_mesh = BoxMesh.new()
		_lid_mesh.size = Vector3.ONE
	for id: String in ["upper", "lower"]:
		var lid := MultiMeshInstance3D.new()
		lid.name = prefix + ("Lid" if id == "upper" else "LowerLid")
		lid.multimesh = MultiMesh.new()
		lid.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		lid.multimesh.mesh = _lid_mesh
		lid.multimesh.instance_count = LID_COLUMNS
		lid.material_override = Surface.material(color if id == "upper" else color.darkened(0.08), true, blueprint)
		root.add_child(lid)
		lid.multimesh.custom_aabb = AABB(
			Vector3(bounds.position.x - padding, white.get_center().y - white.size.y * 0.56, bounds.position.z - padding),
			Vector3(bounds.size.x + padding * 2.0, white.size.y * 1.12, white.end.z - bounds.position.z + padding))
		record[id] = lid
		var buffer := PackedFloat32Array()
		buffer.resize(LID_COLUMNS * 12)
		record[id + "_buffer"] = buffer
	var sockets: Array = root.get_meta("eye_expression_sockets", [])
	sockets.append(record)
	root.set_meta("eye_expression_sockets", sockets)
	_pose_eye(record, 1.0, 0.0)


func bind(preview: Node3D) -> void:
	unbind()
	for part: Node in preview.get_children():
		if part.has_meta("eye_expression_sockets"):
			for eye: Dictionary in part.get_meta("eye_expression_sockets"):
				_eyes.append(eye)


func unbind() -> void:
	reset()
	_eyes.clear()


func reset() -> void:
	for eye: Dictionary in _eyes: _pose_eye(eye, 1.0, 0.0)


func apply(pose: Dictionary) -> void:
	var openness: float = _finite(pose.get("eye_open", 1.0), 1.0, 0.0, 1.0)
	var gaze: float = _finite(pose.get("look_yaw", 0.0), 0.0, -0.3, 0.3)
	for eye: Dictionary in _eyes: _pose_eye(eye, openness, gaze)


static func _pose_eye(eye: Dictionary, openness: float, gaze: float) -> void:
	if not is_instance_valid(eye.upper) or not is_instance_valid(eye.lower): return
	if eye.get("last_open", -1.0) == openness and eye.get("last_gaze", INF) == gaze: return
	eye.last_open = openness
	eye.last_gaze = gaze
	var bounds: AABB = eye.bounds
	var white: AABB = eye.white
	var padding: float = eye.padding
	var center: Vector3 = bounds.get_center()
	# Pose fixed-count voxel strips between a fixed outer ellipse and the
	# moving aperture. Unlike shrinking a rim, this fills the closed socket.
	# The mask extends back to the globe so the brow is attached at oblique views.
	var front: float = bounds.position.z - padding
	var back: float = white.end.z
	var width: float = bounds.size.x + padding * 2.0
	var closed_y: float = white.get_center().y - white.size.y * 0.25
	var upper_buffer: PackedFloat32Array = eye.upper_buffer
	var lower_buffer: PackedFloat32Array = eye.lower_buffer
	for index in range(LID_COLUMNS):
		var u: float = (float(index) + 0.5) / LID_COLUMNS * 2.0 - 1.0
		var x: float = center.x + u * width * 0.5
		var outer: float = white.size.y * 0.56 * sqrt(maxf(0.0, 1.0 - u * u))
		var inner_u: float = (x - white.get_center().x) / (white.size.x * 0.465)
		var inner: float = white.size.y * 0.5 * sqrt(maxf(0.0, 1.0 - inner_u * inner_u))
		var top: float = white.get_center().y + outer
		var bottom: float = white.get_center().y - outer
		var seam: float = clampf(closed_y, bottom, top)
		var open_top: float = lerpf(seam, white.get_center().y + inner, openness)
		var open_bottom: float = lerpf(seam, white.get_center().y - inner, openness)
		_lid_column(upper_buffer, index, x, open_top, top, front, back, width / LID_COLUMNS)
		_lid_column(lower_buffer, index, x, bottom, open_bottom, front, back, width / LID_COLUMNS)
	# Bulk buffers work in both the renderer and headless inspection, and
	# avoid one RenderingServer call per strip. No nodes/meshes are rebuilt.
	eye.upper_buffer = upper_buffer
	eye.lower_buffer = lower_buffer
	eye.upper.multimesh.buffer = upper_buffer
	eye.lower.multimesh.buffer = lower_buffer
	# Compress only the visible eye pieces into the aperture, never the root
	# or an eye stalk. Padding fades in continuously, avoiding an opening pop.
	var aperture_center: float = lerpf(closed_y, white.get_center().y, openness)
	var y_scale: float = openness * (1.0 - padding * 2.0 / white.size.y * (1.0 - openness))
	var iris_bounds: AABB = eye.iris_bounds
	var slack: float = maxf(0.0, minf(iris_bounds.position.x - white.position.x,
		white.end.x - iris_bounds.end.x) - padding)
	var shift: float = -gaze / 0.3 * minf(slack, white.size.x * 0.075)
	for piece: Dictionary in eye.parts:
		var node: MeshInstance3D = piece.node
		if not is_instance_valid(node): continue
		var rest: Transform3D = piece.rest
		var transform := Transform3D(Basis.from_scale(Vector3(1.0, maxf(y_scale, 0.001), 1.0)), Vector3.ZERO) * rest
		transform.origin.y = aperture_center + (rest.origin.y - white.get_center().y) * y_scale
		if piece.gaze: transform.origin.x += shift
		node.transform = transform
		node.visible = openness > 0.015


static func _lid_column(buffer: PackedFloat32Array, index: int, x: float, bottom: float, top: float, front: float, back: float, width: float) -> void:
	var size := Vector3(width, maxf(top - bottom, 0.000001), back - front)
	var center := Vector3(x, (top + bottom) * 0.5, (front + back) * 0.5)
	var offset: int = index * 12
	buffer[offset] = size.x
	buffer[offset + 3] = center.x
	buffer[offset + 5] = size.y
	buffer[offset + 7] = center.y
	buffer[offset + 10] = size.z
	buffer[offset + 11] = center.z


static func _finite(value: Variant, fallback: float, low: float, high: float) -> float:
	var number: float = float(value)
	return clampf(number, low, high) if is_finite(number) else fallback
