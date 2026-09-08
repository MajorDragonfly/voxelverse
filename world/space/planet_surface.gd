extends RefCounted
class_name PlanetSurface

const Cube = preload("res://world/space/cube_sphere.gd")
const Profile = preload("res://world/space/celestial_body_profile.gd")
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
	# All faces sample the same continuous 3-D field, including the poles.
	var broad: float = continents.get_noise_3dv(d)
	var small: float = detail.get_noise_3dv(d)
	var amplitude: float = minf(float(body.radius) * 0.065, 80.0)
	var height: float = (broad * 1.8 + small * 0.18 + 0.12) * amplitude
	if body.get("terrain_revision", 1) >= 2:
		height += local_relief.get_noise_3dv(d * float(body.radius)) * 4.0
	return height


func sample(location: Dictionary) -> Dictionary:
	var d: Vector3 = Cube.vector(Cube.direction(int(location.face), location.u, location.v))
	return sample_direction(d)


func sample_direction(d: Vector3) -> Dictionary:
	var h: float = height_at(d)
	var temperature: float = clampf(1.0 - absf(d.y) - maxf(h, 0.0) / 100.0, 0.0, 1.0)
	var moisture: float = clampf(0.5 + detail.get_noise_3dv(d * 0.7), 0.0, 1.0)
	var water: bool = body.kind == "planet" and h < 0.0
	var biome: String = "ocean" if water else ("ice" if temperature < 0.25 else ("forest" if moisture > 0.5 else "grass"))
	return {"height": h, "water_level": 0.0, "water": water, "temperature": temperature,
		"moisture": moisture, "biome": biome, "normal": normal_at(d), "blocked": false}


func normal_at(d: Vector3) -> Vector3:
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
	if absf(d.y) > 0.82 or h > minf(float(body.radius) * 0.026, 45.0):
		return palette.get("snow", Color("dadcdd"))
	return palette.get("grass", Color("528254")).lerp(palette.get("forest", Color("294e49")),
		clampf(0.45 + detail.get_noise_3dv(d), 0.0, 1.0))


func point(face: int, u: float, v: float) -> Array:
	var location: Dictionary = Cube.address(body.id, face, u, v)
	location.height = height_at(Cube.vector(Cube.direction(face, u, v)))
	return Cube.cartesian(location, float(body.radius))
