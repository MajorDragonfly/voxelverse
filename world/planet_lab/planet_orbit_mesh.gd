extends RefCounted

## Unit-radius orbit geometry. Land and water share topology, so different
## sphere tessellations cannot bury coastlines at astronomical body radii.
const Cube = preload("res://world/space/cube_sphere.gd")
const Surface = preload("res://world/space/planet_surface.gd")
const CELLS: int = 32


static func build(body: Dictionary) -> Dictionary:
	var surface := Surface.new(body)
	var combined_ocean: bool = body.kind == "planet" and body.get("terrain_revision", 1) >= 3
	var land := PackedVector3Array()
	var water := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for face in range(6):
		var offset: int = land.size()
		for y in range(CELLS + 1):
			for x in range(CELLS + 1):
				var d: Array = Cube.direction(face, -1.0 + 2.0 * x / CELLS, -1.0 + 2.0 * y / CELLS)
				var height: float = surface.height_precise(d)
				var up: Vector3 = Cube.vector(d)
				land.append(up * (1.0 + (maxf(height, 0.0) if combined_ocean else height) / float(body.radius)))
				water.append(up)
				normals.append(up)
				colors.append(Color("247c9d") if combined_ocean and height < 0.0 else surface.color_at(up, height))
		for y in range(CELLS):
			for x in range(CELLS):
				var a: int = offset + y * (CELLS + 1) + x
				indices.append_array([a, a + CELLS + 1, a + 1, a + 1, a + CELLS + 1, a + CELLS + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = land
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# At orbit distance, metre-deep coastal water is below depth-buffer
	# precision even with shared tessellation. Use one visible outer shell;
	# the detailed ground/ocean meshes remain separate in surface view.
	if combined_ocean:
		return {"land": mesh, "water": null}
	arrays[Mesh.ARRAY_VERTEX] = water
	arrays[Mesh.ARRAY_COLOR] = null
	var sea := ArrayMesh.new()
	sea.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"land": mesh, "water": sea}
