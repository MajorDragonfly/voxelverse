extends RefCounted
class_name CubeSphere

## Canonical, body-fixed coordinates. Arrays intentionally keep scalar doubles;
## a global Vector3 would discard precision before floating-origin subtraction.
const MODE: String = "cube_sphere_m1_v1"


static func address(body_id: String, face: int, u: float, v: float, height: float = 0.0) -> Dictionary:
	var result: Dictionary = from_direction(body_id, direction(face, u, v))
	result["height"] = height
	return result


static func direction(face: int, u: float, v: float) -> Array:
	var p: Array
	match face:
		0: p = [1.0, v, -u]
		1: p = [-1.0, v, u]
		2: p = [u, 1.0, -v]
		3: p = [u, -1.0, v]
		4: p = [u, v, 1.0]
		_: p = [-u, v, -1.0]
	var length: float = sqrt(float(p[0]) * p[0] + float(p[1]) * p[1] + float(p[2]) * p[2])
	return [p[0] / length, p[1] / length, p[2] / length]


static func from_direction(body_id: String, p: Array) -> Dictionary:
	var x: float = p[0]
	var y: float = p[1]
	var z: float = p[2]
	var face: int
	var u: float
	var v: float
	if absf(x) >= absf(y) and absf(x) >= absf(z):
		face = 0 if x >= 0.0 else 1
		u = (-z if x >= 0.0 else z) / absf(x)
		v = y / absf(x)
	elif absf(y) >= absf(z):
		face = 2 if y >= 0.0 else 3
		u = x / absf(y)
		v = (-z if y >= 0.0 else z) / absf(y)
	else:
		face = 4 if z >= 0.0 else 5
		u = (x if z >= 0.0 else -x) / absf(z)
		v = y / absf(z)
	return {"mode": MODE, "body_id": body_id, "face": face, "u": u, "v": v, "height": 0.0}


static func cartesian(location: Dictionary, radius: float) -> Array:
	var d: Array = direction(int(location.face), float(location.u), float(location.v))
	var r: float = radius + float(location.height)
	return [d[0] * r, d[1] * r, d[2] * r]


static func from_cartesian(body_id: String, p: Array, radius: float) -> Dictionary:
	var result: Dictionary = from_direction(body_id, p)
	result.height = sqrt(float(p[0]) * p[0] + float(p[1]) * p[1] + float(p[2]) * p[2]) - radius
	return result


static func local_position(p: Array, origin: Array) -> Vector3:
	return Vector3(float(p[0]) - origin[0], float(p[1]) - origin[1], float(p[2]) - origin[2])


static func global_position(local: Vector3, origin: Array) -> Array:
	return [float(origin[0]) + local.x, float(origin[1]) + local.y, float(origin[2]) + local.z]


static func vector(p: Array) -> Vector3:
	return Vector3(p[0], p[1], p[2])


static func scaled_offset(p: Array, origin: Array, scale_value: float) -> Vector3:
	return Vector3((float(p[0]) - origin[0]) * scale_value,
		(float(p[1]) - origin[1]) * scale_value, (float(p[2]) - origin[2]) * scale_value)


static func normalized(p: Array) -> Array:
	var length: float = sqrt(float(p[0]) * p[0] + float(p[1]) * p[1] + float(p[2]) * p[2])
	return [p[0] / length, p[1] / length, p[2] / length]


static func frame(up: Vector3, forward: Vector3 = Vector3.FORWARD) -> Basis:
	var tangent: Vector3 = forward.slide(up).normalized()
	if tangent.length_squared() < 0.5:
		tangent = Vector3.RIGHT.slide(up).normalized()
	return Basis(tangent.cross(up).normalized(), up, -tangent).orthonormalized()


static func valid(location: Variant, body_id: String = "") -> bool:
	if not location is Dictionary or location.get("mode") != MODE:
		return false
	if not location.get("body_id") is String or str(location.body_id).is_empty():
		return false
	if not body_id.is_empty() and location.body_id != body_id:
		return false
	for key in ["face", "u", "v", "height"]:
		if not (location.get(key) is float or location.get(key) is int) or not is_finite(float(location[key])):
			return false
	return float(location.face) == float(int(location.face)) and int(location.face) in range(6) \
		and absf(float(location.u)) <= 1.0 and absf(float(location.v)) <= 1.0
