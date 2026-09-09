extends Control
## Screen-projected local axes: large hit targets, independent of voxel size.
var editor: Node
var mode: String = "move"
var drag: Dictionary = {}
var hovered: Dictionary = {}
const COLORS: Array[Color] = [Color("ff8981"), Color("b2eba6"), Color("8ac7ff")]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func handles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if editor == null or not editor.has_method("_gizmo_context"):
		return result
	var context: Dictionary = editor.call("_gizmo_context", mode)
	if context.is_empty():
		return result
	var camera: Camera3D = editor.get("_camera")
	var origin: Vector3 = context["origin"]
	if camera.is_position_behind(origin):
		return result
	var center: Vector2 = camera.unproject_position(origin) - global_position
	var unit: float = 2.0 * camera.global_position.distance_to(origin) * tan(deg_to_rad(camera.fov * 0.5)) / get_viewport_rect().size.y
	var basis: Basis = context["basis"]
	for axis in range(3):
		var points := PackedVector2Array()
		var world_axis: Vector3 = basis[axis].normalized()
		if mode == "rotate":
			for index in range(65):
				var angle: float = TAU * float(index) / 64.0
				var direction: Vector3 = basis[(axis + 1) % 3] * cos(angle) + basis[(axis + 2) % 3] * sin(angle)
				points.append(camera.unproject_position(origin + direction * unit * 72.0) - global_position)
		else:
			points.append(center + (camera.unproject_position(origin + world_axis * unit * 18.0) - global_position - center))
			points.append(camera.unproject_position(origin + world_axis * unit * 82.0) - global_position)
		result.append({"axis": axis, "points": points, "center": center, "context": context, "unit": unit})
	if mode in ["scale", "joint"]:
		result.append({"axis": -1, "points": PackedVector2Array([center]), "center": center, "context": context, "unit": unit})
	return result


func hit_test(point: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var distance: float = 11.0
	for handle in handles():
		var points: PackedVector2Array = handle["points"]
		var candidate: float = point.distance_to(points[0]) if points.size() == 1 else INF
		for index in range(points.size() - 1):
			candidate = minf(candidate, point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[index], points[index + 1])))
		if candidate < distance:
			distance = candidate
			best = handle
	return best


func begin(point: Vector2) -> bool:
	var handle: Dictionary = hit_test(point)
	if handle.is_empty():
		return false
	drag = handle.duplicate(true)
	drag["start"] = point
	drag["mode"] = mode
	drag["blueprint"] = editor.get("blueprint").duplicate(true)
	drag["index"] = editor.get("selected_part_index")
	drag["terminal"] = editor.get("_editing_terminal")
	drag["history_undo"] = editor.get("_history").get("_undo_stack").duplicate()
	drag["history_redo"] = editor.get("_history").get("_redo_stack").duplicate()
	drag["angle"] = 0.0
	drag["last_angle"] = _ring_angle(point, drag) if mode == "rotate" else 0.0
	editor.call("_begin_gesture")
	return true


func motion(point: Vector2, snap: bool) -> bool:
	if drag.is_empty():
		hovered = hit_test(point)
		return false
	var delta: Vector2 = point - Vector2(drag["start"])
	var amount: float = 0.0
	if mode == "rotate":
		var angle: float = _ring_angle(point, drag)
		drag["angle"] = float(drag["angle"]) + wrapf(angle - float(drag["last_angle"]), -PI, PI)
		drag["last_angle"] = angle
		amount = rad_to_deg(float(drag["angle"]))
		if snap:
			amount = snappedf(amount, 15.0)
	else:
		var points: PackedVector2Array = drag["points"]
		var axis: int = drag["axis"]
		amount = (delta.x - delta.y) / 110.0 if axis < 0 else delta.dot((points[-1] - Vector2(drag["center"])).normalized()) / maxf(points[-1].distance_to(drag["center"]), 12.0)
		if snap:
			amount = snappedf(amount, 0.1)
	editor.call("_apply_gizmo_drag", drag, amount, delta)
	return true


func finish(cancel: bool = false) -> void:
	if cancel and not drag.is_empty():
		editor.call("_cancel_gizmo_drag", drag)
	drag.clear()
	hovered.clear()


func _ring_angle(point: Vector2, handle: Dictionary) -> float:
	var context: Dictionary = handle["context"]
	var camera: Camera3D = editor.get("_camera")
	var axis: int = handle["axis"]
	var basis: Basis = context["basis"]
	var normal: Vector3 = basis[axis]
	var plane := Plane(normal, Vector3(context["origin"]))
	var intersection: Variant = plane.intersects_ray(camera.project_ray_origin(point + global_position), camera.project_ray_normal(point + global_position))
	if intersection is Vector3:
		var ray: Vector3 = intersection - Vector3(context["origin"])
		return atan2(ray.dot(basis[(axis + 2) % 3]), ray.dot(basis[(axis + 1) % 3]))
	return (point - Vector2(handle["center"])).angle()


func _draw() -> void:
	for handle in handles():
		var axis: int = handle["axis"]
		var color: Color = COLORS[axis] if axis >= 0 else Color("ffd88c")
		var active: bool = int(drag.get("axis", -99)) == axis or int(hovered.get("axis", -99)) == axis
		var points: PackedVector2Array = handle["points"]
		if active:
			color = Color.WHITE
		if points.size() == 1:
			draw_rect(Rect2(points[0] - Vector2.ONE * 6, Vector2.ONE * 12), Color("193c42"))
			draw_rect(Rect2(points[0] - Vector2.ONE * 6, Vector2.ONE * 12), color, false, 2)
			continue
		draw_polyline(points, Color(0.02, 0.07, 0.08, 0.85), 6, true)
		draw_polyline(points, color, 3.5 if active else 2.4, true)
		if mode != "rotate":
			var end: Vector2 = points[-1]
			if mode == "scale":
				draw_rect(Rect2(end - Vector2.ONE * 5, Vector2.ONE * 10), color)
			else:
				var direction: Vector2 = (end - points[0]).normalized()
				draw_colored_polygon(PackedVector2Array([end + direction * 5, end - direction * 9 + direction.orthogonal() * 6, end - direction * 9 - direction.orthogonal() * 6]), color)
			draw_string(ThemeDB.fallback_font, end + Vector2(8, -8), ["X", "Y", "Z"][axis], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
	if not drag.is_empty():
		var value: String = "%+.0f°" % rad_to_deg(float(drag.get("angle", 0))) if mode == "rotate" else "Ziehen · Umschalt: Raster · Esc: Abbrechen"
		draw_string(ThemeDB.fallback_font, Vector2(drag["center"]) + Vector2(-80, 108), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
