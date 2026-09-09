extends RefCounted

const Cube = preload("res://world/space/cube_sphere.gd")
const Voxels = preload("res://world/planet_lab/voxel_patch_builder.gd")
const CELLS: int = 16
const STRIDE: int = CELLS + 1


static func build(tile: Dictionary, surface: RefCounted) -> Dictionary:
	return upload(build_arrays(tile, surface))


static func build_arrays(tile: Dictionary, surface: RefCounted) -> Dictionary:
	var vertices := PackedVector3Array()
	var ocean := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var has_water: bool = false
	for y in range(STRIDE):
		for x in range(STRIDE):
			var uv: Vector2 = tile.uv + Vector2(x, y) * (float(tile.width) / CELLS)
			var address: Dictionary = Cube.address(surface.body.id, tile.face, uv.x, uv.y)
			var precise: Array = Cube.direction(tile.face, uv.x, uv.y)
			var d: Vector3 = Cube.vector(precise)
			var height: float = surface.height_precise(precise)
			ocean.append(Cube.local_position(Cube.cartesian(address, surface.body.radius), tile.anchor))
			address.height = height
			vertices.append(Cube.local_position(Cube.cartesian(address, surface.body.radius), tile.anchor))
			normals.append(d if surface.body.get("terrain_revision", 1) >= 3 else surface.normal_at(d))
			colors.append(surface.color_at(d, height))
			has_water = has_water or height < 1.0
	if surface.body.get("terrain_revision", 1) >= 3:
		# Derive render normals from already sampled local geometry. Repeating
		# three full double-noise queries for each vertex delayed nearby tiles.
		for y in range(STRIDE):
			for x in range(STRIDE):
				var dx: Vector3 = vertices[y * STRIDE + mini(x + 1, CELLS)] - vertices[y * STRIDE + maxi(x - 1, 0)]
				var dz: Vector3 = vertices[mini(y + 1, CELLS) * STRIDE + x] - vertices[maxi(y - 1, 0) * STRIDE + x]
				normals[y * STRIDE + x] = dz.cross(dx).normalized()
	# Fine boundary vertices collapse onto the coarse neighbor's actual straight
	# segments. Even samples are shared exactly, including across cube faces.
	for edge in range(4):
		if int(tile.mask) & (1 << edge) == 0:
			continue
		for step in range(1, CELLS, 2):
			var i: int = edge_index(edge, step)
			var a: int = edge_index(edge, step - 1)
			var b: int = edge_index(edge, step + 1)
			vertices[i] = (vertices[a] + vertices[b]) * 0.5
			ocean[i] = (ocean[a] + ocean[b]) * 0.5
			normals[i] = (normals[a] + normals[b]).normalized()
			colors[i] = colors[a].lerp(colors[b], 0.5)
	for y in range(CELLS):
		for x in range(CELLS):
			var a: int = y * STRIDE + x
			indices.append_array([a, a + STRIDE, a + 1, a + 1, a + STRIDE, a + STRIDE + 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var land: Array = arrays.duplicate()
	if surface.body.get("terrain_revision", 1) >= 2 and float(tile.width) * float(surface.body.radius) / CELLS <= Voxels.MAX_CELL_WIDTH:
		land = Voxels.new().build(tile, surface, land)
	var water: Array = []
	if has_water and surface.body.kind == "planet":
		arrays[Mesh.ARRAY_VERTEX] = ocean
		arrays[Mesh.ARRAY_COLOR] = null
		var water_normals := PackedVector3Array()
		for point in ocean:
			water_normals.append(Cube.vector(Cube.global_position(point, tile.anchor)).normalized())
		arrays[Mesh.ARRAY_NORMAL] = water_normals
		water = arrays
	return {"land_arrays": land, "water_arrays": water}


static func upload(data: Dictionary) -> Dictionary:
	var land := ArrayMesh.new()
	land.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.land_arrays)
	var water: ArrayMesh
	if not data.water_arrays.is_empty():
		water = ArrayMesh.new()
		water.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.water_arrays)
	return {"mesh": land, "water": water}


static func edge_index(edge: int, step: int) -> int:
	return [step, step * STRIDE + CELLS, CELLS * STRIDE + step, step * STRIDE][edge]
