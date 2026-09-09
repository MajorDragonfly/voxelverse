extends RefCounted
class_name PlanetSurface

const Cube = preload("res://world/space/cube_sphere.gd")
const Profile = preload("res://world/space/celestial_body_profile.gd")
const ValueField = preload("res://world/space/scalar_noise.gd")
var body: Dictionary
var terrain: Dictionary
var continents := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var local_relief := FastNoiseLite.new()


func _init(descriptor: Dictionary) -> void:
	body = descriptor
	terrain = Profile.terrain_profile(int(body.seed))
	continents.seed = int(body.seed)
	continents.frequency = 1.8
	continents.fractal_octaves = 2
	detail.seed = int(body.seed) + 733
	detail.frequency = 4.0
	detail.fractal_octaves = 1
	local_relief.seed = int(body.seed) + 1973
	local_relief.frequency = 1.0 / 48.0
	local_relief.fractal_octaves = 2


func height_at(d: Vector3) -> float:
	if body.get("terrain_revision", 1) >= 3:
		return height_precise([d.x, d.y, d.z])
	# All faces sample the same continuous 3-D field, including the poles.
	var broad: float = continents.get_noise_3dv(d)
	var small: float = detail.get_noise_3dv(d)
	var amplitude: float = minf(float(body.radius) * 0.065, 80.0)
	var height: float = (broad * 1.8 + small * 0.18 + 0.12) * amplitude
	if body.get("terrain_revision", 1) >= 2:
		height += local_relief.get_noise_3dv(d * float(body.radius)) * 4.0
	return height


func height_precise(d: Array) -> float:
	if body.get("terrain_revision", 1) < 3:
		return height_at(Cube.vector(d))
	var radius: float = body.radius
	var seed_value: int = body.seed
	var p: Array = [d[0] * radius, d[1] * radius, d[2] * radius]
	var broad: float = ValueField.sample(d, 0.55, seed_value)
	var regional: float = ValueField.sample(p, clampf(radius * 0.015, 2000.0, 50000.0), seed_value + 733)
	return (broad * 1.8 + 0.12) * minf(radius * 0.008, 2600.0) \
		+ regional * minf(radius * 0.003, 850.0) \
		+ ValueField.sample(p, 768.0, seed_value + 937) * 24.0 \
		+ ValueField.sample(p, 48.0, seed_value + 1973) * 2.0


func normal_precise(d: Array, span: float = 2.0) -> Vector3:
	if body.get("terrain_revision", 1) < 3:
		return normal_at(Cube.vector(d))
	var up: Vector3 = Cube.vector(d)
	var frame: Basis = Cube.frame(up)
	var epsilon: float = span / float(body.radius)
	var a: Array = Cube.normalized([d[0] + frame.x.x * epsilon, d[1] + frame.x.y * epsilon, d[2] + frame.x.z * epsilon])
	var b: Array = Cube.normalized([d[0] + frame.z.x * epsilon, d[1] + frame.z.y * epsilon, d[2] + frame.z.z * epsilon])
	var r: float = float(body.radius) + height_precise(d)
	var ra: float = float(body.radius) + height_precise(a)
	var rb: float = float(body.radius) + height_precise(b)
	var center: Array = [d[0] * r, d[1] * r, d[2] * r]
	var dx: Vector3 = Cube.local_position([a[0] * ra, a[1] * ra, a[2] * ra], center)
	var dz: Vector3 = Cube.local_position([b[0] * rb, b[1] * rb, b[2] * rb], center)
	return dz.cross(dx).normalized()


func sample(location: Dictionary) -> Dictionary:
	var d: Array = Cube.direction(int(location.face), location.u, location.v)
	return _sample(d)


func sample_direction(d: Vector3) -> Dictionary:
	return _sample([d.x, d.y, d.z])


func _sample(d: Array) -> Dictionary:
	var h: float = height_precise(d)
	var lapse_height: float = 9000.0 if body.get("terrain_revision", 1) >= 3 else 100.0
	var temperature: float = clampf(1.0 - absf(d[1]) - maxf(h, 0.0) / lapse_height, 0.0, 1.0)
	var moisture: float = clampf(0.5 + detail.get_noise_3dv(Cube.vector(d) * 0.7), 0.0, 1.0)
	var water: bool = body.kind == "planet" and h < 0.0
	var biome: String = "ocean" if water else ("ice" if temperature < 0.25 else ("forest" if moisture > 0.5 else "grass"))
	return {"height": h, "water_level": 0.0, "water": water, "temperature": temperature,
		"moisture": moisture, "biome": biome, "normal": normal_precise(d), "blocked": false}


func normal_at(d: Vector3) -> Vector3:
	if body.get("terrain_revision", 1) >= 3:
		return normal_precise([d.x, d.y, d.z])
	var frame: Basis = Cube.frame(d)
	var epsilon: float = 0.0002
	var a: Vector3 = (d + frame.x * epsilon).normalized()
	var b: Vector3 = (d + frame.z * epsilon).normalized()
	var center: Vector3 = d * (float(body.radius) + height_at(d))
	var dx: Vector3 = a * (float(body.radius) + height_at(a)) - center
	var dz: Vector3 = b * (float(body.radius) + height_at(b)) - center
	return dz.cross(dx).normalized()


func color_at(d: Vector3, h: float) -> Color:
	var palette: Dictionary = terrain.palette
	if body.kind == "moon":
		return Color("a7a7b3").lerp(Color("595d73"), clampf(0.5 + h * 0.1, 0.0, 1.0))
	if h < 0.6:
		return Color("c6b581")
	var snow_height: float = 2400.0 if body.get("terrain_revision", 1) >= 3 else minf(float(body.radius) * 0.026, 45.0)
	if absf(d.y) > 0.82 or h > snow_height:
		return palette.get("snow", Color("dadcdd"))
	return palette.get("grass", Color("528254")).lerp(palette.get("forest", Color("294e49")),
		clampf(0.45 + detail.get_noise_3dv(d), 0.0, 1.0))


func point(face: int, u: float, v: float) -> Array:
	var location: Dictionary = Cube.address(body.id, face, u, v)
	location.height = height_precise(Cube.direction(face, u, v))
	return Cube.cartesian(location, float(body.radius))
