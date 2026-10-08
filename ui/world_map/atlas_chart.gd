extends "res://core/map/atlas_projection.gd"
## Narrow world-map consumer adapter. Keep the authoritative addresses,
## chart and inverse; wrap without an approximate upper-bound snap.
const AddressCube = preload("res://world/space/cube_sphere.gd")
const AddressSurface = preload("res://core/map/surface_map_projection.gd")

static func wrap_exact(value: float, half_period: float) -> float:
	if value >= -half_period and value < half_period: return value
	var period: float = 2.0 * half_period
	return value - period * floor((value + half_period) / period)

func project(address: Dictionary) -> Vector2:
	if local.mode != AddressCube.MODE: return super.project(address)
	if not AddressSurface.valid(address) or address.body_id != local.body_id or address.mode != local.mode: return Vector2(INF, INF)
	var direction: Array = AddressCube.direction(address.face, address.u, address.v)
	var x: float = atan2(float(direction[0]), float(direction[2])) * radius
	return Vector2(center.x + wrap_exact(x - center.x, PI * radius), -asin(clampf(float(direction[1]), -1.0, 1.0)) * radius)

func clamp_center(point: Vector2) -> Vector2:
	if local.mode != AddressCube.MODE: return super.clamp_center(point)
	return Vector2(wrap_exact(point.x, PI * radius), clampf(point.y, -PI * radius * 0.5, PI * radius * 0.5))
