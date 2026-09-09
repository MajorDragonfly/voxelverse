extends Node3D
## Repo-native voxel props. Deposits are village salvage/forage patches, separate
## from wildlife feeding and its bush stock. Housing has a separate stable owner.
const Economy = preload("res://world/tribe/village_economy.gd")
const Home = preload("res://world/home_group/home_group_state.gd")

func rebuild(data: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var center: Vector3 = Home.vector(data["anchor"])
	_box(center + Vector3(0, 0.16, -1.3), Vector3(2.2, 0.32, 0.8), Color("765130"))
	_label(center + Vector3(0, 2.8, 0), "Dorfplatz · Lager & Werkbank", Color("ead19a"))
	for kind: String in data["deposits"]:
		if kind in ["water", "fiber"] and not data["economy"]["stations"].has("well" if kind == "water" else "fiberbed"):
			continue
		var deposit: Dictionary = data["deposits"][kind]
		var location: Vector3 = Home.vector(deposit["position"])
		var amount: int = int(deposit["remaining"])
		if kind == "food" and int(data["garden"]) == 1:
			_box(location + Vector3(0, 0.08, 0), Vector3(1.8, 0.16, 1.8), Color("634933"))
			for side in [-1, 1]:
				_box(location + Vector3(side * 0.95, 0.16, 0), Vector3(0.12, 0.25, 2), Color("ab8151"))
			for i in range(8):
				var root_position: Vector3 = location + Vector3((i % 4 - 1.5) * 0.4, 0.23, (i / 4 - 0.5) * 0.75)
				_box(root_position, Vector3(0.12, 0.25 if i < amount else 0.08, 0.12), Color("7caa53") if i < amount else Color("46643c"))
		if amount > 0:
			for i in range(5):
				var offset := Vector3((i % 3 - 1) * 0.35, 0.22 + (i / 3) * 0.22, (i % 2) * 0.4)
				var size := Vector3(0.26, 0.26, 1.2) if kind == "wood" else Vector3(0.4, 0.4, 0.4)
				_box(location + offset, size, Color("95643e") if kind == "wood" else Color("8e9fa4") if kind == "stone" else Color("60bde8") if kind == "water" else Color("b8bf67") if kind == "fiber" else Color("ab7857"))
		var title: String = {"wood": "Leseholz", "stone": "Lose Steine", "food": "Essbare Wurzeln", "water": "Brunnen", "fiber": "Faserbeet"}[kind]
		if kind == "food" and int(data["garden"]) == 1:
			title = "Wurzelgarten · erntereif"
		for station: String in data["economy"]["stations"]:
			if Economy.STATIONS[station] == kind:
				title = {"well": "Brunnen", "forester": "Forstplatz", "quarry": "Steinbruch", "fiberbed": "Faserbeet"}[station]
				if station == "well":
					for side in [-1, 1]:
						_box(location + Vector3(side * 0.7, 0.4, 0), Vector3(0.2, 0.8, 1.5), Color("a7b1b4"))
					_box(location + Vector3(0, 0.2, 0), Vector3(1.2, 0.15, 1.2), Color("438fa9"))
				else:
					_box(location + Vector3(0, 0.08, 0), Vector3(2.1, 0.16, 2.1), Color("6b5b45"))
		_label(location + Vector3(0, 2.3, 0), "%s · %d" % [title, amount], Color("c6dec7"))
	if not data["project"].is_empty() and data["project"]["kind"] in Economy.STATIONS:
		var site: Vector3 = Home.vector(data["project"]["position"])
		_box(site + Vector3(0, 0.08, 0), Vector3(2.1, 0.16, 2.1), Color("b6a46a"))
		_label(site + Vector3(0, 2.3, 0), "Arbeitsplatz im Bau", Color("edd5a8"))
	for batch: Dictionary in data["economy"]["incoming"]:
		var site: Vector3 = Home.vector(batch["position"])
		_box(site + Vector3(0, 0.4, 0), Vector3(0.5, 0.8, 0.5), Color("f4f0dd"))
		_label(site + Vector3(0, 2.5, 0), "Milch zur Abholung · %d" % batch["remaining"], Color("f4f0dd"))
	if data["project"].get("kind") in ["hut", "tent"]:
		var project: Dictionary = data["project"]
		var location: Vector3 = Home.vector(project["position"])
		for x in [-1, 1]:
			for z in [-1, 1]:
				_box(location + Vector3(x, 0.25, z), Vector3(0.18, 0.5, 0.18), Color("b19b64"))
		_box(Home.vector(project["entrance"]) + Vector3(0, 0.03, 0), Vector3(1.3, 0.06, 1), Color("c9b080"))
		var delivered: int = 0
		var required: int = 0
		for kind: String in project["delivered_materials"]:
			delivered += int(project["delivered_materials"][kind])
			required += int(preload("res://world/tribe/village_housing.gd").COSTS[project["kind"]][kind])
		_label(location + Vector3(0, 2.8, 0), "%s im Bau · Material %d / %d" % ["Hütte" if project["kind"] == "hut" else "Zelt", delivered, required], Color("edd5a8"))
	if int(data["tools"]) == 1:
		_box(center + Vector3(0, 0.6, -1.3), Vector3(0.18, 0.7, 0.18), Color("b08451"))
		_box(center + Vector3(0.14, 0.9, -1.3), Vector3(0.5, 0.3, 0.22), Color("b2c0c2"))

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
	label.pixel_size = 0.017
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	label.global_position = location
