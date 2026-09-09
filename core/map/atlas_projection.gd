extends RefCounted
## Plane coordinates, or a north-up equirectangular planet chart. Sphere x is
## equatorial arc length (not a claim of local distance at every latitude).
const Surface = preload("res://core/map/surface_map_projection.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var local := Surface.new()
var radius: float = 0.0
var center := Vector2.ZERO

func configure(address: Dictionary, body_radius: float) -> bool:
	radius = body_radius
	center = Vector2.ZERO
	return local.configure(address, radius)

func project(address: Dictionary) -> Vector2:
	if not Surface.valid(address) or address.body_id != local.body_id or address.mode != local.mode: return Vector2(INF, INF)
	if local.mode != Cube.MODE: return local.project(address)
	var direction: Array = Cube.direction(address.face, address.u, address.v)
	var x: float = atan2(float(direction[0]), float(direction[2])) * radius
	x = center.x + wrapf(x - center.x, -PI * radius, PI * radius)
	return Vector2(x, -asin(clampf(float(direction[1]), -1.0, 1.0)) * radius)

func address_at(point: Vector2) -> Dictionary:
	if local.mode != Cube.MODE: return local.address_at(point)
	var latitude: float = -float(point.y) / radius
	if absf(latitude) > PI * 0.5: return {}
	var longitude: float = float(point.x) / radius
	return Cube.from_direction(local.body_id, [sin(longitude) * cos(latitude), sin(latitude), cos(longitude) * cos(latitude)])

func clamp_center(point: Vector2) -> Vector2:
	if local.mode != Cube.MODE: return point.clamp(Vector2.ONE * -1.0e7, Vector2.ONE * 1.0e7)
	return Vector2(wrapf(point.x, -PI * radius, PI * radius), clampf(point.y, -PI * radius * 0.5, PI * radius * 0.5))
