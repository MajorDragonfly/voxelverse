extends Node3D
## Repo-native voxel props. Deposits are village salvage/forage patches, separate
## from wildlife feeding and its bush stock. No collision can trap a worker.
const Home = preload("res://world/home_group/home_group_state.gd")

func rebuild(data: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var center: Vector3 = Home.vector(data["anchor"])
	_box(center + Vector3(0, 0.16, -1.3), Vector3(2.2, 0.32, 0.8), Color("765130"))
	_label(center + Vector3(0, 2.8, 0), "Dorfplatz · Lager & Werkbank", Color("ead19a"))
	for kind: String in ["wood", "stone", "food"]:
		var deposit: Dictionary = data["deposits"][kind]
		var location: Vector3 = Home.vector(deposit["position"])
		var amount: int = int(deposit["remaining"])
		if amount > 0:
			for i in range(5):
				var offset := Vector3((i % 3 - 1) * 0.35, 0.22 + (i / 3) * 0.22, (i % 2) * 0.4)
				var size := Vector3(0.26, 0.26, 1.2) if kind == "wood" else Vector3(0.4, 0.4, 0.4)
				_box(location + offset, size, Color("95643e") if kind == "wood" else Color("8e9fa4") if kind == "stone" else Color("ab7857"))
		var title: String = {"wood": "Leseholz", "stone": "Lose Steine", "food": "Essbare Wurzeln"}[kind]
		_label(location + Vector3(0, 2.3, 0), "%s · %d" % [title, amount], Color("c6dec7"))
	for i in range(2):
		var location: Vector3 = Home.vector(data["sites"][i])
		if i < int(data["huts"]):
			_hut(location)
			_label(location + Vector3(0, 3.6, 0), "Hütte %d · 2 Schlafplätze" % (i + 1), Color("edd5a8"))
		else:
			for x in [-1, 1]:
				for z in [-1, 1]:
					_box(location + Vector3(x * 0.9, 0.2, z * 0.9), Vector3(0.18, 0.4, 0.18), Color("b19b64"))
			var active: bool = not data["project"].is_empty() and data["project"]["kind"] == "hut" and i == int(data["huts"])
			_label(location + Vector3(0, 2.2, 0), "Hütte im Bau" if active else "Bauplatz %d" % (i + 1), Color("a0b4b4"))
	if int(data["tools"]) == 1:
		_box(center + Vector3(0, 0.6, -1.3), Vector3(0.18, 0.7, 0.18), Color("b08451"))
		_box(center + Vector3(0.14, 0.9, -1.3), Vector3(0.5, 0.3, 0.22), Color("b2c0c2"))

func _hut(location: Vector3) -> void:
	for x in [-1, 1]:
		for z in [-1, 1]:
			_box(location + Vector3(x * 0.85, 0.85, z * 0.85), Vector3(0.22, 1.7, 0.22), Color("785031"))
	for row in range(5):
		_box(location + Vector3(0, 0.2 + row * 0.3, -0.85), Vector3(1.7, 0.25, 0.16), Color("957049"))
	for layer in range(4):
		var width: float = 2.5 - layer * 0.5
		_box(location + Vector3(0, 1.8 + layer * 0.22, 0), Vector3(width, 0.24, 2.4), Color("9a975a"))

func _box(location: Vector3, size: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	visual.material_override = material
	add_child(visual)
	visual.global_position = location

func _label(location: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 26
	label.pixel_size = 0.011
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	label.global_position = location
