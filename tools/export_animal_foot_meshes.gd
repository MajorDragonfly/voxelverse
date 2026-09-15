extends SceneTree
## Export actual Godot mesh arrays for a display-free geometry review.
const Geometry = preload("res://creatures/editor/creature_part_geometry.gd")
const Catalog = preload("res://creatures/editor/creature_part_library.gd")


func _initialize() -> void:
	var output: Array = []
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ids: Array = ["feet_feline_paws", "feet_bear_paws", "feet_horse_hooves"]
	if args.size() > 1: ids = Array(args.slice(1))
	for token: String in ids:
		# Optional id@-1 exports the actual mirrored terminal recipe.
		var fields: PackedStringArray = token.split("@")
		var id: String = fields[0]
		var side: float = -1.0 if fields.size() > 1 and fields[1] == "-1" else 1.0
		var node := Node3D.new()
		node.set_meta("creature_part_side", side)
		if str(Catalog.get_part(id).get("category", "")) == "mouth":
			var blueprint: Dictionary = preload("res://creatures/editor/creature_blueprint.gd").create_default()
			Geometry.build(node, Catalog.get_part(id), {"category": "mouth"}, blueprint)
		else:
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
		output.append({"id": id, "name": Catalog.get_part(id).name, "side": side, "meshes": meshes})
		node.free()
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(output))
	file.close()
	print("TERMINAL_MESH_EXPORT_PASSED")
	quit()
