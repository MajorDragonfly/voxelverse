extends RefCounted

## Adds one depth channel to already sampled water; no additional height/noise
## calls, no added vertices/triangles and no displacement of the sea or floor.
static func enrich(arrays: Dictionary, tile: Dictionary) -> Dictionary:
	if arrays.water_arrays.is_empty():
		return arrays
	var land: PackedVector3Array = arrays.land_arrays[Mesh.ARRAY_VERTEX]
	var sea: PackedVector3Array = arrays.water_arrays[Mesh.ARRAY_VERTEX]
	var uv := PackedVector2Array()
	uv.resize(sea.size())
	for index in range(sea.size()):
		uv[index] = Vector2(_length(sea[index], tile.anchor) - _length(land[index], tile.anchor), 0.0)
	arrays.water_arrays[Mesh.ARRAY_TEX_UV] = uv
	return arrays


static func _length(point: Vector3, anchor: Array) -> float:
	var x: float = anchor[0] + point.x
	var y: float = anchor[1] + point.y
	var z: float = anchor[2] + point.z
	return sqrt(x * x + y * y + z * z)
