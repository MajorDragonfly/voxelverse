extends Node3D


func _ready() -> void:
	_build_reference_scene()


func _build_reference_scene() -> void:
	var existing := get_node_or_null("References")
	if existing != null:
		return
	var references := Node3D.new()
	references.name = "References"
	add_child(references)

	_add_reference_cube(
		references,
		"OneMetre",
		Vector3(-1.5, 0.5, 0.0),
		Vector3.ONE,
		Color(0.72, 0.72, 0.72, 1.0),
		"1.0 m"
	)
	_add_reference_cube(
		references,
		"QuarterMetre",
		Vector3(0.0, 0.125, 0.0),
		Vector3.ONE * 0.25,
		Color(0.35, 0.70, 0.48, 1.0),
		"0.25 m builder grid"
	)
	_add_reference_cube(
		references,
		"MicroVoxel",
		Vector3(0.75, 0.0625, 0.0),
		Vector3.ONE * 0.125,
		Color(0.32, 0.58, 0.78, 1.0),
		"0.125 m fine voxel"
	)
	_add_axis(
		references,
		"AxisX",
		Vector3(1.5, 0.025, 0.0),
		Vector3(3.0, 0.05, 0.05),
		Color(0.85, 0.25, 0.25, 1.0),
		"+X"
	)
	_add_axis(
		references,
		"AxisY",
		Vector3(0.0, 1.5, 0.0),
		Vector3(0.05, 3.0, 0.05),
		Color(0.30, 0.82, 0.38, 1.0),
		"+Y UP"
	)
	_add_axis(
		references,
		"AxisZ",
		Vector3(0.0, 0.025, -1.5),
		Vector3(0.05, 0.05, 3.0),
		Color(0.28, 0.46, 0.88, 1.0),
		"-Z FORWARD"
	)

	var import_anchor := Marker3D.new()
	import_anchor.name = "ImportedAssetHere"
	add_child(import_anchor)
	var label := Label3D.new()
	label.text = "Drop imported GLB under ImportedAssetHere\nBase/pivot should normally sit at Y = 0"
	label.position = Vector3(0.0, 2.5, 1.7)
	label.font_size = 32
	label.outline_size = 6
	import_anchor.add_child(label)


func _add_reference_cube(
	parent: Node3D,
	name_value: String,
	position_value: Vector3,
	size_value: Vector3,
	color_value: Color,
	label_text: String
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name_value
	mesh_instance.position = position_value
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh.material = _material(color_value)
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	var label := Label3D.new()
	label.text = label_text
	label.position = Vector3(0.0, size_value.y * 0.65 + 0.16, 0.0)
	label.font_size = 28
	label.outline_size = 5
	mesh_instance.add_child(label)


func _add_axis(
	parent: Node3D,
	name_value: String,
	position_value: Vector3,
	size_value: Vector3,
	color_value: Color,
	label_text: String
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name_value
	mesh_instance.position = position_value
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh.material = _material(color_value)
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	var label := Label3D.new()
	label.text = label_text
	label.position = Vector3(0.0, 0.18, 0.0)
	label.font_size = 24
	label.outline_size = 5
	mesh_instance.add_child(label)


func _material(color_value: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color_value
	material.roughness = 0.95
	return material
