extends RefCounted

# Incremental value-array construction. Imported resources and renderer uploads
# remain on the main thread; no resource work is submitted to worker threads.
const ELEMENTS_PER_STEP: int = 256
var sources: Array[Dictionary] = []
var vertex_limit: int = 65536
var complete: bool = false
var failure: String = ""
var instance_count: int = 0
var palettes: Array[Dictionary] = []
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()
var shades := PackedVector2Array()
var indices := PackedInt32Array()

var _source_index: int = 0
var _instance_index: int = 0
var _vertex_index: int = 0
var _index_index: int = 0
var _base_vertex: int = 0
var _source_vertices := PackedVector3Array()
var _source_normals := PackedVector3Array()
var _source_uvs := PackedVector2Array()
var _source_indices := PackedInt32Array()
var _transform: Transform3D
var _normal_basis: Basis
var _shade: float = 1.0
var _loaded: bool = false


func step() -> void:
	if complete:
		return
	if _source_index >= sources.size():
		complete = true
		_release_inputs()
		return
	var source: Dictionary = sources[_source_index]
	if not _loaded:
		var mesh: Mesh = source["mesh"]
		var arrays: Array = mesh.surface_get_arrays(0)
		_source_vertices = arrays[Mesh.ARRAY_VERTEX]
		_source_normals = arrays[Mesh.ARRAY_NORMAL]
		_source_uvs = arrays[Mesh.ARRAY_TEX_UV]
		_source_indices = arrays[Mesh.ARRAY_INDEX]
		var count: int = source["transforms"].size()
		if _source_vertices.is_empty() or _source_normals.size() != _source_vertices.size() or _source_uvs.size() != _source_vertices.size() or _source_indices.is_empty():
			_fail("invalid_source")
			return
		if vertices.size() + _source_vertices.size() * count > vertex_limit or indices.size() + _source_indices.size() * count > vertex_limit * 3:
			_fail("capacity")
			return
		palettes.append(source["palette"])
		_loaded = true
		return
	if _vertex_index == 0 and _index_index == 0:
		_base_vertex = vertices.size()
		_transform = source["transforms"][_instance_index]
		_normal_basis = _transform.basis.inverse().transposed()
		_shade = float(source["custom"][_instance_index].r)
	if _vertex_index < _source_vertices.size():
		var end: int = mini(_vertex_index + ELEMENTS_PER_STEP, _source_vertices.size())
		var row: float = (float(_source_index) + 0.5) / float(sources.size())
		for index in range(_vertex_index, end):
			vertices.append(_transform * _source_vertices[index])
			normals.append((_normal_basis * _source_normals[index]).normalized())
			uvs.append(Vector2(_source_uvs[index].x, row))
			shades.append(Vector2(_shade, 0.0))
		_vertex_index = end
		return
	var end: int = mini(_index_index + ELEMENTS_PER_STEP * 3, _source_indices.size())
	for index in range(_index_index, end):
		indices.append(_base_vertex + _source_indices[index])
	_index_index = end
	if _index_index == _source_indices.size():
		instance_count += 1
		_instance_index += 1
		_vertex_index = 0
		_index_index = 0
		if _instance_index == source["transforms"].size():
			_source_index += 1
			_instance_index = 0
			_loaded = false


func get_arrays() -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = shades
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


func _fail(reason: String) -> void:
	failure = reason
	complete = true
	vertices.clear()
	normals.clear()
	uvs.clear()
	shades.clear()
	indices.clear()
	palettes.clear()
	_release_inputs()


func _release_inputs() -> void:
	sources.clear()
	_source_vertices.clear()
	_source_normals.clear()
	_source_uvs.clear()
	_source_indices.clear()
