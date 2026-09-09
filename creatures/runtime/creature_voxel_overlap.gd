extends RefCounted
## Exact occupied-cube / affine-box SAT, with a bounded broad-phase scan.
const LIMIT: int = 40000
const EPSILON: float = 0.00001


static func query(mesh: Mesh, mesh_to_box: Transform3D, box: AABB, budget: int = LIMIT) -> Dictionary:
	var result: Dictionary = {"hit": false, "complete": true, "cells_tested": 0}
	if absf(mesh_to_box.basis.determinant()) < 0.00000001:
		result["complete"] = false
		return result
	var broad: AABB = (mesh_to_box.affine_inverse() * box).intersection(mesh.get_aabb())
	if not broad.has_volume():
		return result
	if not mesh.has_meta("voxel_cells") and not mesh.has_meta("voxel_occupancy"):
		result["complete"] = false
		return result
	var step: float = mesh.get_meta("voxel_size")
	var low := Vector3i((broad.position / step).floor())
	var high := Vector3i((broad.end / step).ceil())
	var cells: Dictionary = mesh.get_meta("voxel_cells", {})
	var occupancy: PackedByteArray = mesh.get_meta("voxel_occupancy", PackedByteArray())
	var grid: Vector3i = mesh.get_meta("voxel_grid", Vector3i.ZERO)
	var start: Vector3i = mesh.get_meta("voxel_grid_origin", Vector3i.ZERO)
	var edges: Array[Vector3] = [mesh_to_box.basis.x * step * 0.5,
		mesh_to_box.basis.y * step * 0.5, mesh_to_box.basis.z * step * 0.5]
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK,
		edges[0].cross(edges[1]), edges[1].cross(edges[2]), edges[2].cross(edges[0])]
	for edge in edges:
		for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			axes.append(edge.cross(axis))
	var separating: Array = []
	for axis in axes:
		if axis.length_squared() > 0.0000000001:
			axis = axis.normalized()
			separating.append([axis, box.size.dot(axis.abs()) * 0.5 + absf(axis.dot(edges[0])) + absf(axis.dot(edges[1])) + absf(axis.dot(edges[2]))])
	for z in range(low.z, high.z):
		for y in range(low.y, high.y):
			for x in range(low.x, high.x):
				if result["cells_tested"] >= budget:
					result["complete"] = false
					return result
				result["cells_tested"] += 1
				var cell := Vector3i(x, y, z)
				var at: Vector3i = cell - start
				var occupied: bool = cells.has(cell)
				if not occupancy.is_empty() and at.x >= 0 and at.y >= 0 and at.z >= 0 and at.x < grid.x and at.y < grid.y and at.z < grid.z:
					occupied = occupancy[at.x + grid.x * (at.y + grid.y * at.z)] != 0
				if not occupied:
					continue
				var point: Vector3 = mesh_to_box * ((Vector3(cell) + Vector3.ONE * 0.5) * step)
				var delta: Vector3 = point - box.get_center()
				var overlaps: bool = true
				for separation in separating:
					if absf(delta.dot(separation[0])) >= float(separation[1]) - EPSILON:
						overlaps = false
						break
				if overlaps:
					result["hit"] = true
					result["point"] = point.clamp(box.position, box.end)
					return result
	return result
