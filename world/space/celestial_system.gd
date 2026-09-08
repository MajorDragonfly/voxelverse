extends RefCounted
class_name CelestialSystem

const Profile = preload("res://world/space/celestial_body_profile.gd")
var bodies: Dictionary = {}
var elapsed: float = 0.0
var binary: bool = false
const LANDABLE: Array[String] = ["m1:haven", "m1:ember", "m1:lune"]


func _init(two_stars: bool = false) -> void:
	binary = two_stars
	_add("m1:sol", "Solis", "star", 9, 120.0, "", 0.0, 600.0, 0.0)
	if binary:
		bodies["m1:sol"].orbit_radius = 200.0
		bodies["m1:sol"].orbit_period = 100.0
		_add("m1:vesper", "Vesper", "star", 17, 80.0, "", 330.0, 100.0, PI)
	_add("m1:haven", "Haven", "planet", 12345, 256.0, "m1:sol", 6000.0, 1400.0, 0.1)
	_add("m1:ember", "Ember", "planet", 98765, 160.0, "m1:sol", 11000.0, 2300.0, 2.2)
	_add("m1:lune", "Lune", "moon", 31415, 64.0, "m1:haven", 950.0, 180.0, 1.1)
	if binary:
		# Empty parent denotes the common, stationary barycentric reference frame.
		bodies["m1:haven"].parent_id = ""
		bodies["m1:ember"].parent_id = ""
		bodies["m1:haven"]["orbit_center"] = "barycenter"
		bodies["m1:ember"]["orbit_center"] = "barycenter"
	bodies["m1:lune"].gravity = 5.0


func _add(id: String, label: String, kind: String, seed_value: int, radius: float,
		parent: String, orbit_radius: float, period: float, phase: float) -> void:
	var body: Dictionary = Profile.create(id, kind, seed_value, radius, parent)
	body.merge({"name": label, "orbit_radius": orbit_radius, "orbit_period": period, "orbit_phase": phase}, true)
	bodies[id] = body


func position_at(id: String, time: float = -1.0) -> Vector3:
	if time < 0.0:
		time = elapsed
	var body: Dictionary = bodies[id]
	var angle: float = body.orbit_phase + TAU * fposmod(time, body.orbit_period) / body.orbit_period
	var position: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * float(body.orbit_radius)
	if not str(body.parent_id).is_empty():
		position += position_at(body.parent_id, time)
	return position


func rotation_at(id: String, time: float = -1.0) -> Basis:
	if time < 0.0:
		time = elapsed
	var body: Dictionary = bodies[id]
	return Basis(Vector3.FORWARD, float(body.axial_tilt)) * Basis(Vector3.UP,
		TAU * fposmod(time, body.rotation_period) / body.rotation_period)


func sky_direction(observer_id: String, target_id: String, location: Vector3 = Vector3.ZERO) -> Vector3:
	return (rotation_at(observer_id).inverse() * (position_at(target_id) - position_at(observer_id)) - location).normalized()
