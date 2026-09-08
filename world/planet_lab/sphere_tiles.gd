extends Node3D
class_name SphereTiles

const Cube = preload("res://world/space/cube_sphere.gd")
const Surface = preload("res://world/space/planet_surface.gd")
const GRID: int = 4
const SUBDIVISIONS: int = 16
const FAR_SUBDIVISIONS: int = 8
const MAX_NEAR: int = 24
const COLLISION_EDGE_GUARD: float = 0.0005
var surface: RefCounted
var origin: Array = [0.0, 0.0, 0.0]
var tiles: Array[Dictionary] = []
var active: Dictionary = {}
var rebases: int = 0
var material: StandardMaterial3D
var water: MeshInstance3D
var _last_direction: Vector3 = Vector3.ZERO


func configure(descriptor: Dictionary) -> void:
	surface = Surface.new(descriptor)
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	for face in range(6):
		for y in range(GRID):
			for x in range(GRID):
				var u: float = -1.0 + (float(x) + 0.5) * 2.0 / GRID
				var v: float = -1.0 + (float(y) + 0.5) * 2.0 / GRID
				var anchor: Array = surface.point(face, u, v)
				var node := MeshInstance3D.new()
				node.name = "Tile_%d_%d_%d" % [face, x, y]
				node.material_override = material
				add_child(node)
				var tile: Dictionary = {"face": face, "x": x, "y": y, "anchor": anchor,
					"direction": Cube.vector(Cube.direction(face, u, v)), "node": node}
				tile["far"] = build_mesh(tile, false)
				node.mesh = tile.far
				node.position = Cube.local_position(anchor, origin)
				tiles.append(tile)
	if descriptor.kind == "planet":
		water = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = descriptor.radius
		sphere.height = descriptor.radius * 2.0
		sphere.radial_segments = 128
		sphere.rings = 64
		water.mesh = sphere
		var ocean := StandardMaterial3D.new()
		ocean.albedo_color = Color("247c9d")
		ocean.roughness = 0.26
		ocean.metallic = 0.15
		water.material_override = ocean
		add_child(water)


func build_mesh(tile: Dictionary, detailed: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	# Both LODs retain the exact same perimeter. Far tiles use 8x8 cell fans;
	# near tiles use a 16x16 grid. There are no T-junctions or skirts.
	if detailed:
		for y in range(SUBDIVISIONS + 1):
			for x in range(SUBDIVISIONS + 1):
				_add_vertex(tile, float(x) / SUBDIVISIONS, float(y) / SUBDIVISIONS, vertices, normals, colors)
		for y in range(SUBDIVISIONS):
			for x in range(SUBDIVISIONS):
				var a: int = y * (SUBDIVISIONS + 1) + x
				indices.append_array([a, a + SUBDIVISIONS + 1, a + 1,
					a + 1, a + SUBDIVISIONS + 1, a + SUBDIVISIONS + 2])
	else:
		for cy in range(FAR_SUBDIVISIONS):
			for cx in range(FAR_SUBDIVISIONS):
				var center: int = vertices.size()
				_add_vertex(tile, (cx + 0.5) / FAR_SUBDIVISIONS, (cy + 0.5) / FAR_SUBDIVISIONS, vertices, normals, colors)
				for edge in range(4):
					var boundary: bool = [cy == 0, cx == FAR_SUBDIVISIONS - 1, cy == FAR_SUBDIVISIONS - 1, cx == 0][edge]
					var steps: int = SUBDIVISIONS / FAR_SUBDIVISIONS if boundary else 1
					for step in range(steps):
						var t: float = float(step) / steps
						var xy: Vector2 = [Vector2(t, 0), Vector2(1, t), Vector2(1 - t, 1), Vector2(0, 1 - t)][edge]
						_add_vertex(tile, (cx + xy.x) / FAR_SUBDIVISIONS, (cy + xy.y) / FAR_SUBDIVISIONS, vertices, normals, colors)
				var count: int = vertices.size() - center - 1
				for i in range(count):
					indices.append_array([center, center + 1 + (i + 1) % count, center + 1 + i])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_vertex(tile: Dictionary, x: float, y: float, vertices: PackedVector3Array,
		normals: PackedVector3Array, colors: PackedColorArray) -> void:
	var u: float = -1.0 + (float(tile.x) + x) * 2.0 / GRID
	var v: float = -1.0 + (float(tile.y) + y) * 2.0 / GRID
	var d: Vector3 = Cube.vector(Cube.direction(tile.face, u, v))
	var h: float = surface.height_at(d)
	vertices.append(Cube.local_position(surface.point(tile.face, u, v), tile.anchor))
	normals.append(surface.normal_at(d))
	colors.append(surface.color_at(d, h))


func stream_at(direction: Vector3, force: bool = false) -> void:
	if not force and direction.distance_to(_last_direction) * float(surface.body.radius) < 5.0:
		return
	_last_direction = direction
	var sorted: Array[int] = []
	for index in range(tiles.size()):
		sorted.append(index)
	sorted.sort_custom(func(a: int, b: int) -> bool: return tiles[a].direction.dot(direction) > tiles[b].direction.dot(direction))
	var wanted: Array[int] = sorted.slice(0, MAX_NEAR)
	for index in active.keys():
		if index not in wanted:
			var tile: Dictionary = tiles[index]
			tile.node.mesh = tile.far
			# Remove immediately from physics; deferred deletion may retain a stale
			# collider during a same-frame origin change or body switch.
			tile.node.remove_child(active[index])
			active[index].queue_free()
			active.erase(index)
	for index in wanted:
		if active.has(index):
			continue
		var tile: Dictionary = tiles[index]
		var near_mesh: ArrayMesh = build_mesh(tile, true)
		tile.node.mesh = near_mesh
		var collision := StaticBody3D.new()
		var shape_node := CollisionShape3D.new()
		var shape: ConcavePolygonShape3D = _collision_shape(near_mesh)
		shape_node.shape = shape
		collision.add_child(shape_node)
		tile.node.add_child(collision)
		active[index] = collision


func _collision_shape(mesh: ArrayMesh) -> ConcavePolygonShape3D:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Independently translated float32 tile frames can differ by micrometres.
	# A bounded half-millimetre overlap keeps zero-width edge raycasts reliable;
	# it does not move visual vertices or add a broad collision skirt.
	for i in range(vertices.size()):
		var x: int = i % (SUBDIVISIONS + 1)
		var y: int = i / (SUBDIVISIONS + 1)
		if x == 0 or x == SUBDIVISIONS or y == 0 or y == SUBDIVISIONS:
			vertices[i] += vertices[i].normalized() * COLLISION_EDGE_GUARD
	var faces := PackedVector3Array()
	for index in indices:
		faces.append(vertices[index])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	return shape


func rebase(new_origin: Array) -> void:
	origin = new_origin.duplicate()
	rebases += 1
	for tile in tiles:
		tile.node.position = Cube.local_position(tile.anchor, origin)
	if is_instance_valid(water):
		water.position = Cube.local_position([0.0, 0.0, 0.0], origin)


func orbital_mesh() -> ArrayMesh:
	# Same source, same perimeter and colors; combine far patches for one draw.
	var builder := SurfaceTool.new()
	for tile in tiles:
		builder.append_from(tile.far, 0, Transform3D(Basis.IDENTITY, Cube.vector(tile.anchor)))
	return builder.commit()
