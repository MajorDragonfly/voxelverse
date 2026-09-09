extends Node3D
## Bounded editor course. Surface sampling matches the actual box colliders.
const COLLISION_LAYER: int = 1 << 18
var kind: String = "flat"
var floor_y: float = -1.0
var course_length: float = 8.0
var course_width: float = 4.0
var travel_half: float = 2.0


func configure(new_kind: String, ground: float, extent: Vector3) -> void:
	kind = new_kind if new_kind in ["flat", "slope", "steps"] else "flat"
	floor_y = ground
	course_length = maxf(8.0, extent.z + 5.0)
	course_width = maxf(3.5, extent.x + 1.0)
	travel_half = (course_length - extent.z) * 0.5 - 0.95
	for child in get_children():
		remove_child(child)
		child.queue_free()
	visible = kind != "flat"
	if kind == "flat":
		return
	var half: float = course_length * 0.5
	if kind == "slope":
		_block(1.2, half, 0.0, 0)
		_block(-half, -1.2, 0.6, 2)
		var angle: float = atan(0.6 / 2.4)
		var basis := Basis(Vector3.RIGHT, angle)
		_box("Ramp", Vector3(course_width, 0.22, sqrt(2.4 * 2.4 + 0.6 * 0.6)), Vector3(0, floor_y + 0.3, 0) - basis.y * 0.11, basis, Color("42796e"))
	else:
		var edges: Array[float] = [half, 1.05, 0.35, -0.35, -1.05, -half]
		for index in range(5):
			_block(edges[index + 1], edges[index], float(index) * 0.18, index)
	for entry in [[travel_half, "START"], [-travel_half, "ZIEL"]]:
		var label := Label3D.new()
		label.name = "CourseLabel" + str(entry[1])
		label.text = str(entry[1])
		label.font_size = 38
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(course_width * 0.5 + 0.12, surface(Vector3(0, 0, entry[0]))["height"] + 0.15, entry[0])
		add_child(label)


func _block(from: float, to: float, height: float, index: int) -> void:
	var thickness: float = height + 0.22
	_box("CourseStep%d" % index, Vector3(course_width, thickness, to - from), Vector3(0, floor_y + height - thickness * 0.5, (from + to) * 0.5), Basis.IDENTITY, Color("315a60") if index % 2 == 0 else Color("46786d"))
	# Small edge strips keep the travel direction readable in the voxel room.
	for side: float in [-1.0, 1.0]:
		var marker := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.025, 0.012, to - from)
		marker.mesh = mesh
		marker.position = Vector3(side * (course_width * 0.5 - 0.06), floor_y + height + 0.006, (from + to) * 0.5)
		marker.material_override = _material(Color("a6ebcc"))
		add_child(marker)


func _box(node_name: String, size: Vector3, point: Vector3, basis: Basis, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = COLLISION_LAYER
	body.collision_mask = 0
	body.transform = Transform3D(basis, point)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _material(color)
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func surface(point: Vector3) -> Dictionary:
	var rise: float = 0.0
	var normal := Vector3.UP
	if kind == "slope":
		rise = clampf((1.2 - point.z) / 2.4, 0, 1) * 0.6
		if point.z > -1.2 and point.z < 1.2:
			normal = Vector3(0, 1, 0.25).normalized()
	elif kind == "steps":
		for edge: float in [1.05, 0.35, -0.35, -1.05]:
			if point.z < edge:
				rise += 0.18
	return {"height": floor_y + rise, "normal": normal}


func route(time: float, speed: float) -> Vector3:
	return Vector3(0, 0, travel_half - clampf(time * speed, 0, travel_half * 2.0))


func duration(speed: float) -> float:
	return travel_half * 2.0 / maxf(speed, 0.01)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	return material
