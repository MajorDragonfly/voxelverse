extends RefCounted
## Stable geometry evidence, captured from main ea900f2 before provider extraction.
const Geometry = preload("res://creatures/editor/creature_part_geometry.gd")
const FootIds = ["feet_pads", "feet_claws", "feet_hooves", "feet_webbed"]


static func capture(part_ids: Array = FootIds) -> Dictionary:
	var result: Dictionary = {}
	for id: String in part_ids:
		for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9)]:
			for side: float in [-1.0, 1.0]:
				var node := Node3D.new()
				node.set_meta("part_shape", shape)
				node.set_meta("creature_part_side", side)
				Geometry._terminal(node, id, Color("8fb39b"), Color("e5d5ab"))
				result["%s:%s:%d" % [id, shape, int(side)]] = describe(node)
				node.free()
	return result


static func describe(node: Node3D) -> Array:
	var result: Array = []
	for child: Node in node.get_children():
		if not child is MeshInstance3D: continue
		var mesh: ArrayMesh = child.mesh
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: Array = []
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			vertices.append([snappedf(vertex.x, 0.000001), snappedf(vertex.y, 0.000001), snappedf(vertex.z, 0.000001)])
		result.append({"name": str(child.name), "position": var_to_str(child.position),
			"basis": var_to_str(child.basis), "aabb": var_to_str(mesh.get_aabb()),
			"vertices": vertices.size(), "vertex_hash": JSON.stringify(vertices).sha256_text(),
			"color": child.material_override.albedo_color.to_html()})
	return result
