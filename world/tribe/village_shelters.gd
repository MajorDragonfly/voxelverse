extends Node3D
## Stable fixed models and matching walls. Rebuilt only when homes change.
const Housing = preload("res://world/tribe/village_housing.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
var _signature: String = ""
var _waiting_clear: Dictionary = {}

func sync(data: Dictionary, actors: Dictionary) -> void:
	var signature: String = JSON.stringify(data["housing"]["homes"])
	if signature == _signature:
		return
	_signature = signature
	_waiting_clear.clear()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for shelter: Dictionary in data["housing"]["homes"]:
		var building := StaticBody3D.new()
		building.name = shelter["id"].validate_node_name()
		building.collision_layer = 1
		building.collision_mask = 0
		add_child(building)
		building.global_position = Home.vector(shelter["position"])
		# Older decorative huts could contain a resident or overlap its capsule.
		# Keep that exact saved position; enable walls once the resident walks out.
		if _occupied(shelter, actors):
			building.collision_layer = 0
			_waiting_clear[building] = shelter
		var tent: bool = shelter["kind"] == "tent"
		var wall: Color = Color("c5ab7c") if tent else Color("957049")
		_part(building, Vector3(-1, 0.85, 0), Vector3(0.15, 1.7, 2.1), wall, true)
		_part(building, Vector3(1, 0.85, 0), Vector3(0.15, 1.7, 2.1), wall, true)
		_part(building, Vector3(0, 0.85, -1), Vector3(2.1, 1.7, 0.15), wall, true)
		# Open 1.6m doorway, facing +Z; walls and lintel agree with the model.
		for side in [-1, 1]:
			_part(building, Vector3(side * 0.95, 0.85, 1), Vector3(0.3, 1.7, 0.15), wall, true)
		_part(building, Vector3(0, 2.0, 1), Vector3(2.1, 0.3, 0.15), wall, true)
		for layer in range(5):
			_part(building, Vector3(0, 2.25 + layer * 0.2, 0), Vector3(2.5 - layer * 0.45, 0.23, 2.4), Color("d4bb89") if tent else Color("9a975a"), false)
		_part(building, Vector3(0, 2.25, 0), Vector3(2.5, 0.23, 2.4), wall, true, false)
		_part(building, Vector3(0, 0.02, 1.75), Vector3(1.3, 0.04, 1.5), Color("c9b080"), false)
		var label := Label3D.new()
		label.text = "Zelt · 1 Schlafplatz" if tent else "Hütte · 2 Schlafplätze"
		label.position = Vector3(0, 3.8, 0)
		label.font_size = 26
		label.pixel_size = 0.014
		label.modulate = Color("edd5a8")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		building.add_child(label)

func clear_entrances(actors: Dictionary) -> void:
	for building: StaticBody3D in _waiting_clear.keys():
		if not _occupied(_waiting_clear[building], actors):
			building.collision_layer = 1
			_waiting_clear.erase(building)

func _occupied(shelter: Dictionary, actors: Dictionary) -> bool:
	for actor: Node3D in actors.values():
		if Housing.contains(shelter, actor.global_position):
			return true
	return false

func _part(building: Node3D, offset: Vector3, size: Vector3, color: Color, collision: bool, visible_mesh: bool = true) -> void:
	if visible_mesh:
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.95
		visual.material_override = material
		visual.position = offset
		building.add_child(visual)
	if collision:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		collider.position = offset
		building.add_child(collider)
