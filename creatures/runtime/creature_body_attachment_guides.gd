extends RefCounted
## Optional visual fit witnesses, excluded from anatomy bounds and collisions.
const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")
const Shapes = preload("res://creatures/runtime/creature_body_fit_shapes.gd")


static func install(marker: Node3D, id: String, body_scale: float, profile: Dictionary = Shapes.Rider.DEFAULT) -> void:
	var guide := Node3D.new()
	guide.name = "FitGuide"
	guide.set_meta("editor_guide", true)
	guide.scale = Vector3.ONE * body_scale
	marker.add_child(guide)
	var color := Color("efc36c") if id == "saddle.primary" else Color("63d5dd")
	_box(guide, "Anchor", Vector3.ZERO, Vector3.ONE * 0.075, color)
	Surface.bone(guide, "Forward", Vector3.ZERO, Vector3.FORWARD * 0.32, 0.025, Color("d3edf8"))
	for shape: Dictionary in Shapes.boxes(id, profile):
		var bounds: AABB = shape["bounds"]
		var tint: Color = Color("d3edf8") if id == "saddle.primary" and shape["id"] != "Saddle" else color
		_box(guide, shape["id"], bounds.get_center(), bounds.size, tint)


static func _box(parent: Node3D, label: String, position: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	node.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = Surface.material(color)
	parent.add_child(node)
