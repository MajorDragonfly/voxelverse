extends RefCounted
class_name VoxelAssetLibraryV6

const BaseAssets = preload("res://world/visuals/scenery/voxel_asset_library_v4.gd")

static var _canopy_mesh: ArrayMesh
static var _conifer_mesh: ArrayMesh
static var _gnarled_trunk_mesh: ArrayMesh
static var _cliff_mesh: ArrayMesh
static var _fern_mesh: ArrayMesh


static func get_straight_trunk_mesh() -> ArrayMesh:
	return BaseAssets.get_trunk_mesh()


static func get_round_crown_mesh() -> ArrayMesh:
	return BaseAssets.get_crown_mesh()


static func get_rock_mesh() -> ArrayMesh:
	return BaseAssets.get_rock_mesh()


static func get_ground_cluster_mesh() -> ArrayMesh:
	return BaseAssets.get_ground_cluster_mesh()


static func get_gnarled_trunk_mesh() -> ArrayMesh:
	if _gnarled_trunk_mesh == null:
		_gnarled_trunk_mesh = _build_boxes([
			{"center": Vector3(-0.08, -0.38, 0.00), "size": Vector3(0.34, 0.24, 0.34)},
			{"center": Vector3(0.02, -0.14, 0.02), "size": Vector3(0.32, 0.24, 0.32)},
			{"center": Vector3(0.12, 0.10, -0.02), "size": Vector3(0.29, 0.24, 0.29)},
			{"center": Vector3(0.02, 0.33, 0.02), "size": Vector3(0.25, 0.22, 0.25)},
			{"center": Vector3(-0.24, 0.20, 0.00), "size": Vector3(0.34, 0.12, 0.12)},
			{"center": Vector3(0.28, 0.34, -0.08), "size": Vector3(0.42, 0.11, 0.11)},
		])
	return _gnarled_trunk_mesh


static func get_flat_canopy_mesh() -> ArrayMesh:
	if _canopy_mesh == null:
		_canopy_mesh = _build_boxes([
			{"center": Vector3(0.00, 0.00, 0.00), "size": Vector3(0.78, 0.24, 0.58)},
			{"center": Vector3(0.48, 0.02, 0.04), "size": Vector3(0.42, 0.22, 0.44)},
			{"center": Vector3(-0.48, -0.01, -0.02), "size": Vector3(0.42, 0.22, 0.44)},
			{"center": Vector3(0.10, 0.08, 0.42), "size": Vector3(0.55, 0.20, 0.34)},
			{"center": Vector3(-0.08, 0.06, -0.42), "size": Vector3(0.55, 0.20, 0.34)},
			{"center": Vector3(0.28, 0.18, -0.18), "size": Vector3(0.38, 0.18, 0.34)},
			{"center": Vector3(-0.30, 0.16, 0.16), "size": Vector3(0.38, 0.18, 0.34)},
		])
	return _canopy_mesh


static func get_conifer_crown_mesh() -> ArrayMesh:
	if _conifer_mesh == null:
		_conifer_mesh = _build_boxes([
			{"center": Vector3(0.0, -0.30, 0.0), "size": Vector3(0.86, 0.20, 0.86)},
			{"center": Vector3(0.0, -0.08, 0.0), "size": Vector3(0.70, 0.20, 0.70)},
			{"center": Vector3(0.0, 0.14, 0.0), "size": Vector3(0.54, 0.20, 0.54)},
			{"center": Vector3(0.0, 0.36, 0.0), "size": Vector3(0.36, 0.20, 0.36)},
			{"center": Vector3(0.0, 0.55, 0.0), "size": Vector3(0.20, 0.18, 0.20)},
		])
	return _conifer_mesh


static func get_cliff_cluster_mesh() -> ArrayMesh:
	if _cliff_mesh == null:
		_cliff_mesh = _build_boxes([
			{"center": Vector3(-0.30, -0.20, 0.02), "size": Vector3(0.46, 0.40, 0.48)},
			{"center": Vector3(0.10, -0.06, -0.08), "size": Vector3(0.50, 0.52, 0.44)},
			{"center": Vector3(0.38, 0.08, 0.10), "size": Vector3(0.32, 0.38, 0.36)},
			{"center": Vector3(-0.06, 0.34, 0.04), "size": Vector3(0.34, 0.30, 0.34)},
			{"center": Vector3(0.16, 0.54, -0.02), "size": Vector3(0.22, 0.22, 0.24)},
		])
	return _cliff_mesh


static func get_fern_mesh() -> ArrayMesh:
	if _fern_mesh == null:
		_fern_mesh = _build_boxes([
			{"center": Vector3(0.00, 0.18, 0.00), "size": Vector3(0.08, 0.36, 0.08)},
			{"center": Vector3(0.18, 0.18, 0.00), "size": Vector3(0.34, 0.08, 0.08)},
			{"center": Vector3(-0.18, 0.15, 0.02), "size": Vector3(0.34, 0.08, 0.08)},
			{"center": Vector3(0.00, 0.22, 0.18), "size": Vector3(0.08, 0.08, 0.34)},
			{"center": Vector3(0.02, 0.12, -0.18), "size": Vector3(0.08, 0.08, 0.34)},
		])
	return _fern_mesh


static func _build_boxes(boxes: Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		_append_box(surface, box.get("center", Vector3.ZERO), box.get("size", Vector3.ONE))
	var mesh: ArrayMesh = surface.commit()
	mesh.surface_set_material(0, BaseAssets.get_material())
	return mesh


static func _append_box(surface: SurfaceTool, center: Vector3, size: Vector3) -> void:
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
