extends RefCounted
class_name ModularVoxelMeshBuilder

const HIGHLIGHT_MIX: float = 0.38


static func build_mesh(
	blueprint: Dictionary,
	part_definitions: Dictionary,
	selected_index: int = -1
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var parts: Array = blueprint.get("parts", [])
	for part_index in range(parts.size()):
		if not (parts[part_index] is Dictionary):
			continue
		var placement: Dictionary = parts[part_index]
		var definition: Dictionary = part_definitions.get(
			str(placement.get("part_id", "")),
			{}
		)
		if definition.is_empty():
			continue
		_append_definition(
			vertices,
			normals,
			colors,
			placement,
			definition,
			part_index == selected_index
		)
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_name(0, "ModularAssembly")
	mesh.surface_set_material(0, _create_material())
	return mesh


static func _append_definition(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	placement: Dictionary,
	definition: Dictionary,
	selected: bool
) -> void:
	var geometry_value: Variant = definition.get("geometry", definition.get("voxels", []))
	var geometry: Array = geometry_value if geometry_value is Array else []
	if geometry.is_empty():
		geometry = [{
			"position": Vector3.ZERO,
			"size": _as_vector3(definition.get("size", Vector3.ONE), Vector3.ONE),
			"color": definition.get("color", Color(0.65, 0.65, 0.65, 1.0)),
		}]
	var part_position: Vector3 = _as_vector3(placement.get("position", Vector3.ZERO), Vector3.ZERO)
	var part_rotation: Vector3 = _as_vector3(placement.get("rotation", Vector3.ZERO), Vector3.ZERO)
	var part_scale: Vector3 = _as_vector3(placement.get("scale", Vector3.ONE), Vector3.ONE)
	var radians := Vector3(
		deg_to_rad(part_rotation.x),
		deg_to_rad(part_rotation.y),
		deg_to_rad(part_rotation.z)
	)
	var rotation_basis: Basis = Basis.from_euler(radians)
	for box_value in geometry:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var local_position: Vector3 = _as_vector3(box.get("position", Vector3.ZERO), Vector3.ZERO)
		var local_size: Vector3 = _as_vector3(box.get("size", Vector3.ONE), Vector3.ONE)
		local_position *= part_scale
		local_size *= part_scale
		var color: Color = _as_color(
			box.get("color", definition.get("color", Color.WHITE)),
			Color.WHITE
		)
		if selected:
			color = color.lerp(Color(0.35, 0.95, 1.0, 1.0), HIGHLIGHT_MIX)
		_append_box(
			vertices,
			normals,
			colors,
			part_position,
			rotation_basis,
			local_position,
			local_size,
			color
		)


static func _append_box(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	part_position: Vector3,
	rotation_basis: Basis,
	local_position: Vector3,
	size: Vector3,
	color: Color
) -> void:
	var half: Vector3 = size * 0.5
	var corners: Array[Vector3] = [
		Vector3(-half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, half.y, -half.z),
		Vector3(-half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z),
		Vector3(half.x, -half.y, half.z),
		Vector3(half.x, half.y, half.z),
		Vector3(-half.x, half.y, half.z),
	]
	for index in range(corners.size()):
		corners[index] = part_position + rotation_basis * (local_position + corners[index])
	_append_face(vertices, normals, colors, corners, [0, 3, 2, 1], rotation_basis * Vector3(0, 0, -1), color)
	_append_face(vertices, normals, colors, corners, [5, 6, 7, 4], rotation_basis * Vector3(0, 0, 1), color)
	_append_face(vertices, normals, colors, corners, [4, 7, 3, 0], rotation_basis * Vector3(-1, 0, 0), color)
	_append_face(vertices, normals, colors, corners, [1, 2, 6, 5], rotation_basis * Vector3(1, 0, 0), color)
	_append_face(vertices, normals, colors, corners, [3, 7, 6, 2], rotation_basis * Vector3(0, 1, 0), color)
	_append_face(vertices, normals, colors, corners, [4, 0, 1, 5], rotation_basis * Vector3(0, -1, 0), color)


static func _append_face(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	corners: Array[Vector3],
	indices: Array,
	normal: Vector3,
	color: Color
) -> void:
	var order: Array[int] = [0, 1, 2, 0, 2, 3]
	for order_index in order:
		vertices.append(corners[int(indices[order_index])])
		normals.append(normal.normalized())
		colors.append(color)


static func _create_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.90
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_BACK
	return material


static func _as_vector3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(
			float(value.get("x", fallback.x)),
			float(value.get("y", fallback.y)),
			float(value.get("z", fallback.z))
		)
	return fallback


static func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(
			float(value[0]),
			float(value[1]),
			float(value[2]),
			float(value[3]) if value.size() >= 4 else 1.0
		)
	return fallback
