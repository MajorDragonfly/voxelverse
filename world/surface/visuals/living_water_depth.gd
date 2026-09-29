extends RefCounted

## Adds depth and a lake mask to already sampled water; no additional height/noise
## calls, no added vertices/triangles and no displacement of the sea or floor.
static func enrich(arrays: Dictionary, tile: Dictionary, body_radius: float) -> Dictionary:
	if arrays.water_arrays.is_empty():
		return arrays
	var land: PackedVector3Array = arrays.land_arrays[Mesh.ARRAY_VERTEX]
	var sea: PackedVector3Array = arrays.water_arrays[Mesh.ARRAY_VERTEX]
	var uv := PackedVector2Array()
	uv.resize(sea.size())
	for index in range(sea.size()):
		var water_radius: float = _length(sea[index], tile.anchor)
		# V2 freshwater sits above the global sea. Fade the current out at the
		# basin rim using the surface vertices already prepared by the worker.
		uv[index] = Vector2(water_radius - _length(land[index], tile.anchor),
			smoothstep(0.1, 0.6, water_radius - body_radius))
	arrays.water_arrays[Mesh.ARRAY_TEX_UV] = uv
	return arrays


static func _length(point: Vector3, anchor: Array) -> float:
	var x: float = anchor[0] + point.x
	var y: float = anchor[1] + point.y
	var z: float = anchor[2] + point.z
	return sqrt(x * x + y * y + z * z)
