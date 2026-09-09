extends RefCounted
## Optional visual fit witnesses, excluded from anatomy bounds and collisions.
const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")


static func install(marker: Node3D, id: String, body_scale: float) -> void:
	var guide := Node3D.new()
	guide.name = "FitGuide"
	guide.set_meta("editor_guide", true)
	guide.scale = Vector3.ONE * body_scale
	marker.add_child(guide)
	var color := Color("efc36c") if id == "saddle.primary" else Color("63d5dd")
	_box(guide, "Anchor", Vector3.ZERO, Vector3.ONE * 0.075, color)
	Surface.bone(guide, "Forward", Vector3.ZERO, Vector3.FORWARD * 0.32, 0.025, Color("d3edf8"))
	if id == "saddle.primary":
		# The attachment origin is the saddle's underside. The seated witness
		# faces -Z; its pelvis is 0.20 design units above that origin.
		_box(guide, "Saddle", Vector3(0, 0.055, 0), Vector3(0.36, 0.11, 0.48), color)
		_box(guide, "Pelvis", Vector3(0, 0.20, 0), Vector3(0.20, 0.16, 0.18), Color("d3edf8"))
		_box(guide, "Torso", Vector3(0, 0.40, 0), Vector3(0.24, 0.30, 0.16), Color("d3edf8"))
		_box(guide, "Head", Vector3(0, 0.65, -0.025), Vector3.ONE * 0.17, Color("d3edf8"))
		for side in [-1.0, 1.0]:
			_box(guide, "RiderLeg", Vector3(side * 0.24, 0.02, -0.04), Vector3(0.09, 0.32, 0.12), Color("d3edf8"))
	else:
		_box(guide, "HarnessPad", Vector3.ZERO, Vector3(0.075, 0.24, 0.3), color)
		Surface.bone(guide, "Trace", Vector3.ZERO, Vector3.BACK * 0.8, 0.035, color)


static func _box(parent: Node3D, label: String, position: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	node.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = Surface.material(color)
	parent.add_child(node)
