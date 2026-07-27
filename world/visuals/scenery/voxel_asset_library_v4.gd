extends RefCounted
class_name VoxelAssetLibraryV4

# Shared meshes are generated once and reused by every chunk. Each object is a
# small cluster of cuboids rather than one large primitive, producing a finer
# voxel silhouette without adding one Node per micro block.

static var _shared_material: StandardMaterial3D
static var _trunk_mesh: ArrayMesh
static var _crown_mesh: ArrayMesh
static var _rock_mesh: ArrayMesh
static var _ground_cluster_mesh: ArrayMesh


static func get_trunk_mesh() -> ArrayMesh:
	if _trunk_mesh == null:
		_trunk_mesh = _build_boxes([
			{"center": Vector3(0.0, -0.40, 0.0), "size": Vector3(0.42, 0.22, 0.42)},
			{"center": Vector3(0.0, -0.18, 0.0), "size": Vector3(0.38, 0.22, 0.38)},
			{"center": Vector3(0.02, 0.04, -0.01), "size": Vector3(0.34, 0.22, 0.34)},
			{"center": Vector3(-0.02, 0.26, 0.01), "size": Vector3(0.30, 0.22, 0.30)},
			{"center": Vector3(0.0, 0.45, 0.0), "size": Vector3(0.26, 0.16, 0.26)},
		])
	return _trunk_mesh


static func get_crown_mesh() -> ArrayMesh:
	if _crown_mesh == null:
		_crown_mesh = _build_boxes([
			{"center": Vector3(0.0, 0.0, 0.0), "size": Vector3(0.56, 0.42, 0.56)},
			{"center": Vector3(0.42, -0.02, 0.0), "size": Vector3(0.34, 0.34, 0.38)},
			{"center": Vector3(-0.42, 0.02, 0.0), "size": Vector3(0.34, 0.38, 0.38)},
			{"center": Vector3(0.0, 0.04, 0.42), "size": Vector3(0.38, 0.36, 0.34)},
			{"center": Vector3(0.0, -0.02, -0.42), "size": Vector3(0.38, 0.34, 0.34)},
			{"center": Vector3(0.25, 0.26, 0.22), "size": Vector3(0.30, 0.28, 0.30)},
			{"center": Vector3(-0.22, 0.30, -0.18), "size": Vector3(0.32, 0.30, 0.32)},
			{"center": Vector3(0.0, -0.24, 0.18), "size": Vector3(0.32, 0.24, 0.32)},
		])
	return _crown_mesh


static func get_rock_mesh() -> ArrayMesh:
	if _rock_mesh == null:
		_rock_mesh = _build_boxes([
			{"center": Vector3(0.0, -0.14, 0.0), "size": Vector3(0.58, 0.28, 0.50)},
			{"center": Vector3(-0.22, 0.10, 0.02), "size": Vector3(0.30, 0.26, 0.34)},
			{"center": Vector3(0.20, 0.08, -0.10), "size": Vector3(0.34, 0.22, 0.28)},
			{"center": Vector3(0.04, 0.22, 0.12), "size": Vector3(0.24, 0.20, 0.24)},
		])
	return _rock_mesh


static func get_ground_cluster_mesh() -> ArrayMesh:
	if _ground_cluster_mesh == null:
		_ground_cluster_mesh = _build_boxes([
			{"center": Vector3(-0.28, -0.16, -0.16), "size": Vector3(0.12, 0.32, 0.12)},
			{"center": Vector3(-0.10, -0.06, 0.12), "size": Vector3(0.10, 0.52, 0.10)},
			{"center": Vector3(0.08, -0.12, -0.08), "size": Vector3(0.12, 0.40, 0.12)},
			{"center": Vector3(0.26, -0.04, 0.14), "size": Vector3(0.10, 0.56, 0.10)},
			{"center": Vector3(0.34, -0.18, -0.22), "size": Vector3(0.11, 0.28, 0.11)},
			{"center": Vector3(-0.34, -0.20, 0.24), "size": Vector3(0.10, 0.24, 0.10)},
		])
	return _ground_cluster_mesh


static func get_material() -> StandardMaterial3D:
	if _shared_material == null:
		_shared_material = StandardMaterial3D.new()
		_shared_material.albedo_color = Color.WHITE
		_shared_material.vertex_color_use_as_albedo = true
		_shared_material.roughness = 0.92
		_shared_material.metallic = 0.0
		_shared_material.cull_mode = BaseMaterial3D.CULL_BACK
	return _shared_material


static func _build_boxes(boxes: Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		_append_box(
			surface,
			box.get("center", Vector3.ZERO),
			box.get("size", Vector3.ONE)
		)
	var mesh: ArrayMesh = surface.commit()
	mesh.surface_set_material(0, get_material())
	return mesh


static func _append_box(
	surface: SurfaceTool,
	center: Vector3,
	size: Vector3
) -> void:
	var half: Vector3 = size * 0.5
	var x0: float = center.x - half.x
	var x1: float = center.x + half.x
	var y0: float = center.y - half.y
	var y1: float = center.y + half.y
	var z0: float = center.z - half.z
	var z1: float = center.z + half.z

	_append_quad(surface, Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.UP)
	_append_quad(surface, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3.DOWN)
	_append_quad(surface, Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y0, z0), Vector3.FORWARD)
	_append_quad(surface, Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3.BACK)
	_append_quad(surface, Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(x0, y0, z0), Vector3.LEFT)
	_append_quad(surface, Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3.RIGHT)


static func _append_quad(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3
) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.set_color(Color.WHITE)
		surface.set_normal(normal)
		surface.add_vertex(vertex)
