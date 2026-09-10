extends SceneTree
## Export actual Godot mesh arrays for a display-free geometry review.
const Geometry = preload("res://creatures/editor/creature_part_geometry.gd")
const Catalog = preload("res://creatures/catalog/creature_foot_catalog.gd")


func _initialize() -> void:
	var output: Array = []
	for id: String in ["feet_feline_paws", "feet_bear_paws", "feet_horse_hooves"]:
		var node := Node3D.new()
		Geometry._terminal(node, id, Color("b09d85"), Color("e5d5ab"))
		var meshes: Array = []
		for child: MeshInstance3D in node.get_children():
			var arrays: Array = child.mesh.surface_get_arrays(0)
			var vertices: Array = []
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = child.transform * vertex
				vertices.append([point.x, point.y, point.z])
			var colors: Array = []
			for color: Color in arrays[Mesh.ARRAY_COLOR]:
				color *= child.material_override.albedo_color
				colors.append([color.r, color.g, color.b])
			meshes.append({"name": str(child.name), "vertices": vertices, "indices": Array(arrays[Mesh.ARRAY_INDEX]), "colors": colors})
		output.append({"id": id, "name": Catalog.get_profile(id).name, "meshes": meshes})
		node.free()
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(output))
	file.close()
	print("ANIMAL_FOOT_MESH_EXPORT_PASSED")
	quit()
