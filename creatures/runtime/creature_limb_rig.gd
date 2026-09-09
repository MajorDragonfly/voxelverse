extends RefCounted
## Shared two-segment posing for the workshop, wildlife and terrain animator.
const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")


static func bounds(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var initialized: bool = false
	for child in node.get_children():
		if not (child is Node3D) or child is CollisionObject3D or child.get_meta("editor_guide", false):
			continue
		var local: Transform3D = transform * child.transform
		var box := AABB()
		if child is MeshInstance3D and child.mesh != null:
			box = local * child.mesh.get_aabb()
		else:
			box = bounds(child, local)
		if box.has_volume():
			result = result.merge(box) if initialized else box
			initialized = true
	return result


static func configure(root: Node3D, upper: MeshInstance3D, lower: MeshInstance3D, knee: Node3D, joint: MeshInstance3D, socket: Node3D, width: float, end_rotation: Vector3) -> void:
	var ankle: Vector3 = knee.position + socket.position
	# Keep the sole level while the hip can be rotated freely. End-piece
	# rotation remains independent and is included in its contact height.
	var foot_basis: Basis = Basis.from_euler(Vector3(0, root.rotation.y, 0)) * Basis.from_euler(end_rotation)
	socket.basis = root.basis.inverse() * foot_basis.scaled(Vector3.ONE * root.scale.x)
	var sole: AABB = bounds(socket, Transform3D(root.basis * socket.basis, Vector3.ZERO))
	var offset: float = sole.position.y
	var foot := Marker3D.new()
	foot.name = "RuntimeFootContact"
	foot.position = (root.basis * socket.basis).inverse() * Vector3(sole.get_center().x, offset, sole.get_center().z)
	socket.add_child(foot)
	var record: Dictionary = {"root": root, "upper": upper, "lower": lower, "knee": knee, "joint": joint, "socket": socket, "foot": foot,
		"base_rotation": root.rotation, "base_position": root.position, "knee_base_rotation": Vector3.ZERO,
		"rest_ankle": ankle, "rest_ankle_preview": root.transform * ankle, "sole_offset": offset,
		"foot_basis": foot_basis, "width": width, "sculpt_rig": true}
	root.set_meta("sculpt_limb_rig", record)
	remesh(record, ankle)


static func remesh(record: Dictionary, ankle: Vector3) -> void:
	var knee: Node3D = record["knee"]
	var root: Node3D = record["root"]
	var bend: Vector3 = Vector3(0, 0, maxf(ankle.length() * 0.22, 0.07))
	if str(root.get_meta("creature_part_id", "")) in ["legs_sprinter", "legs_hoof"]:
		bend.z *= -1.0
	knee.position = ankle * 0.5 + bend
	var upper_length: float = knee.position.length()
	var lower_length: float = ankle.distance_to(knee.position)
	var width: float = record["width"]
	var upper: MeshInstance3D = record["upper"]
	var lower: MeshInstance3D = record["lower"]
	upper.mesh = Surface.Voxels.primitive(Vector3(width, upper_length + width, width), "capsule")
	lower.mesh = Surface.Voxels.primitive(Vector3(width * 0.82, lower_length + width * 0.82, width * 0.82), "capsule")
	record["upper_length"] = upper_length
	record["lower_length"] = lower_length
	record["pole"] = bend.normalized()
	record["rest_ankle"] = ankle
	record["rest_ankle_preview"] = root.transform * ankle
	_set_bone(upper, Vector3.ZERO, knee.position, 1.0)
	_set_bone(lower, Vector3.ZERO, ankle - knee.position, 1.0)
	record["joint"].position = knee.position
	record["socket"].position = ankle - knee.position


static func level_legs(preview: Node3D, body_bottom: float) -> float:
	var legs: Array[Dictionary] = []
	var ground: float = body_bottom - 0.08
	for child in preview.get_children():
		if child is Node3D and child.has_meta("sculpt_limb_rig") and str(child.get_meta("creature_part_category", "")) == "legs":
			var record: Dictionary = child.get_meta("sculpt_limb_rig")
			legs.append(record)
			ground = minf(ground, record["rest_ankle_preview"].y + float(record["sole_offset"]))
	for record in legs:
		var root: Node3D = record["root"]
		var point: Vector3 = record["rest_ankle_preview"]
		point.y = ground - float(record["sole_offset"])
		remesh(record, root.transform.affine_inverse() * point)
	preview.set_meta("ground_y", ground)
	return ground


static func pose(record: Dictionary, ankle_world: Vector3) -> void:
	var root: Node3D = record["root"]
	if not is_instance_valid(root) or not root.is_inside_tree():
		return
	var preview: Node3D = root.get_parent() as Node3D
	if preview == null:
		return
	var ankle: Vector3 = root.to_local(ankle_world)
	var distance: float = maxf(ankle.length(), 0.001)
	var first: float = record["upper_length"]
	var second: float = record["lower_length"]
	# Small reach changes (breathing, terrain) preserve the contact rather
	# than lifting an entire leg. Large authoring changes rebuild the mesh.
	var stretch: float = maxf(1.0, distance / maxf(first + second - 0.001, 0.001))
	first *= stretch
	second *= stretch
	var axis: Vector3 = ankle / distance
	var pole: Vector3 = record["pole"]
	var bend: Vector3 = (pole - axis * pole.dot(axis)).normalized()
	if bend.length_squared() < 0.01:
		bend = axis.cross(Vector3.RIGHT).normalized()
	var along: float = clampf((first * first - second * second + distance * distance) / (2.0 * distance), 0.0, first)
	var knee_position: Vector3 = axis * along + bend * sqrt(maxf(0.0, first * first - along * along))
	var knee: Node3D = record["knee"]
	knee.position = knee_position
	knee.rotation = Vector3.ZERO
	_set_bone(record["upper"], Vector3.ZERO, knee_position, stretch)
	_set_bone(record["lower"], Vector3.ZERO, ankle - knee_position, stretch)
	record["joint"].position = knee_position
	var socket: Node3D = record["socket"]
	socket.position = ankle - knee_position
	socket.basis = root.global_basis.inverse() * preview.global_basis * record["foot_basis"] * Basis.from_scale(Vector3.ONE * root.scale.x)


static func _set_bone(mesh: MeshInstance3D, start: Vector3, end: Vector3, stretch: float) -> void:
	mesh.position = (start + end) * 0.5
	mesh.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	mesh.scale = Vector3(1, stretch, 1)
