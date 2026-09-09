extends RefCounted
## Body-fixed local map. Double scalar arrays preserve precision before any
## conversion to screen Vector2. Cube-face seams and floating origins are absent.
const Cube = preload("res://world/space/cube_sphere.gd")
var body_id: String = ""
var mode: String = ""
var radius_m: float = 0.0
var origin: Dictionary = {}
var _up: Array = []
var _east: Array = []
var _north: Array = []

func configure(address: Dictionary, radius: float = 0.0) -> bool:
	if not valid(address): return false
	if address["mode"] == Cube.MODE and (not is_finite(radius) or radius <= 0.0): return false
	body_id = address["body_id"]
	mode = address["mode"]
	radius_m = radius
	origin = address.duplicate(true)
	if mode == Cube.MODE:
		_up = Cube.direction(address.face, address.u, address.v)
		var north: Array = [0.0 - _up[0] * _up[1], 1.0 - _up[1] * _up[1], 0.0 - _up[2] * _up[1]]
		if _length(north) < 0.000001:
			north = [-1.0, 0.0, 0.0] # A stable longitude convention at the pole.
		_north = Cube.normalized(north)
		_east = Cube.normalized(_cross(_north, _up))
	return true

static func valid(address: Dictionary) -> bool:
	if str(address.get("body_id", "")).is_empty(): return false
	if address.get("mode") == Cube.MODE: return Cube.valid(address)
	if address.get("mode") != "legacy_plane_v9": return false
	var p: Variant = address.get("position")
	if not p is Array or p.size() != 3: return false
	for number in p:
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return true

static func plane_address(id: String, p: Vector3) -> Dictionary:
	return {"body_id": id, "mode": "legacy_plane_v9", "position": [p.x, p.y, p.z]}

func project(address: Dictionary) -> Vector2:
	if not valid(address) or address["body_id"] != body_id or address["mode"] != mode:
		return Vector2(INF, INF)
	if mode == "legacy_plane_v9":
		return Vector2(float(address.position[0]) - origin.position[0], float(address.position[2]) - origin.position[2])
	var d: Array = Cube.direction(address.face, address.u, address.v)
	var cosine: float = clampf(_dot(d, _up), -1.0, 1.0)
	var tangent: Array = [d[0] - cosine * _up[0], d[1] - cosine * _up[1], d[2] - cosine * _up[2]]
	var sine: float = _length(tangent)
	if sine < 0.000000000001: return Vector2.ZERO if cosine > 0.0 else Vector2(INF, INF)
	var scale_value: float = atan2(sine, cosine) * radius_m / sine
	return Vector2(_dot(tangent, _east) * scale_value, -_dot(tangent, _north) * scale_value)

func address_at(offset: Vector2) -> Dictionary:
	if mode == "legacy_plane_v9":
		return {"mode": mode, "body_id": body_id, "position": [float(origin.position[0]) + offset.x, 0.0, float(origin.position[2]) + offset.y]}
	var distance: float = offset.length()
	if distance < 0.0000001: return origin.duplicate(true)
	var angle: float = minf(distance / radius_m, PI - 0.00001)
	var d: Array = []
	for i in range(3):
		d.append(_up[i] * cos(angle) + (_east[i] * offset.x - _north[i] * offset.y) / distance * sin(angle))
	return Cube.from_direction(body_id, d)

func heading(forward: Vector3) -> Vector2:
	if mode == "legacy_plane_v9": return Vector2(forward.x, forward.z).normalized()
	var d: Array = [forward.x, forward.y, forward.z]
	return Vector2(_dot(d, _east), -_dot(d, _north)).normalized()

static func _dot(a: Array, b: Array) -> float:
	return float(a[0]) * b[0] + float(a[1]) * b[1] + float(a[2]) * b[2]

static func _length(a: Array) -> float:
	return sqrt(_dot(a, a))

static func _cross(a: Array, b: Array) -> Array:
	return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
