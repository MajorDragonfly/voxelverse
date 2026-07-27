extends RefCounted
class_name TerrainMeshPoolV7

# Unique terrain geometry cannot be shared between chunks, but the ArrayMesh
# resources themselves can be recycled. This avoids repeatedly allocating and
# discarding empty mesh containers while chunks stream in and out.

const MAX_POOLED_MESHES: int = 48

static var _available_meshes: Array[ArrayMesh] = []
static var _far_material: StandardMaterial3D


static func acquire_mesh() -> ArrayMesh:
	if not _available_meshes.is_empty():
		var mesh: ArrayMesh = _available_meshes.pop_back()
		mesh.clear_surfaces()
		return mesh
	return ArrayMesh.new()


static func release_mesh(mesh: ArrayMesh) -> void:
	if mesh == null:
		return
	mesh.clear_surfaces()
	if _available_meshes.size() < MAX_POOLED_MESHES:
		_available_meshes.append(mesh)


static func get_far_material() -> StandardMaterial3D:
	if _far_material == null:
		_far_material = StandardMaterial3D.new()
		_far_material.albedo_color = Color.WHITE
		_far_material.vertex_color_use_as_albedo = true
		_far_material.roughness = 0.98
		_far_material.metallic = 0.0
		_far_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_far_material.cull_mode = BaseMaterial3D.CULL_BACK
	return _far_material


static func get_pool_size() -> int:
	return _available_meshes.size()
