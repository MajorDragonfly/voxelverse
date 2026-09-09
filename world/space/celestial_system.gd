extends RefCounted
class_name CelestialSystem

const Profile = preload("res://world/space/celestial_body_profile.gd")
var bodies: Dictionary = {}
var elapsed: float = 0.0
var binary: bool = false
var real_scale: bool = false
var catalog_id: String = ""
var catalog_name: String = ""
const LANDABLE: Array[String] = ["m1:haven", "m1:ember", "m1:lune", "m1:aster"]
const REAL_LANDABLE: Array[String] = ["m1b:terra", "m1b:100", "m1b:1000"]
const TERRAIN_REVISION: int = 2
const PREVIOUS_RADII: Dictionary = {"m1:haven": 256.0, "m1:ember": 160.0, "m1:lune": 64.0, "m1:aster": 4096.0}


func _init(two_stars: bool = false, full_size: bool = false) -> void:
	binary = two_stars
	real_scale = full_size
	if full_size:
		_real_system()
		return
	# Compressed gameplay scale, in metres. Stars exceed every planet; moon
	# and binary-star orbits leave physical clearance in every phase.
	_add("m1:sol", "Solis", "star", 9, 16384.0, "", 0.0, 600.0, 0.0)
	if binary:
		bodies["m1:sol"].orbit_radius = 30000.0
		bodies["m1:sol"].orbit_period = 100.0
		_add("m1:vesper", "Vesper", "star", 17, 10240.0, "", 48000.0, 100.0, PI)
	_add("m1:haven", "Haven", "planet", 12345, 2048.0, "m1:sol", 120000.0, 1400.0, 0.1)
	_add("m1:ember", "Ember", "planet", 98765, 1536.0, "m1:sol", 240000.0, 2300.0, 2.2)
	_add("m1:lune", "Lune", "moon", 31415, 512.0, "m1:haven", 12000.0, 180.0, 1.1)
	_add("m1:aster", "Aster", "planet", 15838, 4096.0, "m1:sol", 420000.0, 5100.0, 3.5)
	for id: String in LANDABLE:
		bodies[id]["adaptive_tiles"] = true
		bodies[id]["terrain_revision"] = TERRAIN_REVISION
	if binary:
		# Empty parent denotes the common, stationary barycentric reference frame.
		bodies["m1:haven"].parent_id = ""
		bodies["m1:ember"].parent_id = ""
		bodies["m1:haven"]["orbit_center"] = "barycenter"
		bodies["m1:ember"]["orbit_center"] = "barycenter"
		bodies["m1:aster"].parent_id = ""
		bodies["m1:aster"]["orbit_center"] = "barycenter"
	bodies["m1:lune"].gravity = 5.0


func _real_system() -> void:
	# Physical metres. The renderer scales already-centred double coordinates;
	# none of these astronomical translations enter local ground physics.
	_add("m1:sol", "Solis", "star", 9, 696340000.0, "", 0.0, 600.0, 0.0)
	if binary:
		bodies["m1:sol"].orbit_radius = 3000000000.0
		bodies["m1:sol"].orbit_period = 100.0
		_add("m1:vesper", "Vesper", "star", 17, 470000000.0, "", 4800000000.0, 100.0, PI)
	_add("m1b:terra", "Terra", "planet", 15838, 6371000.0, "m1:sol", 149600000000.0, 1400.0, 0.1)
	_add("m1b:100", "Neris", "planet", 12345, 50000.0, "m1b:terra", 90000000.0, 180.0, 1.1)
	_add("m1b:1000", "Orin", "planet", 23757, 500000.0, "m1:sol", 240000000000.0, 2300.0, 2.2)
	for id: String in REAL_LANDABLE:
		bodies[id]["adaptive_tiles"] = true
		bodies[id]["terrain_revision"] = 3
		bodies[id]["gravity"] = 9.81
	if binary:
		for id in ["m1b:terra", "m1b:1000"]:
			bodies[id].parent_id = ""


func landable_ids() -> Array[String]:
	if not catalog_id.is_empty():
		var result: Array[String] = []
		for id: String in bodies:
			if bodies[id].get("landable", false):
				result.append(id)
		return result
	return REAL_LANDABLE if real_scale else LANDABLE


static func from_catalog(entry: Dictionary) -> RefCounted:
	var result := CelestialSystem.new()
	result.catalog_id = entry.id
	result.catalog_name = entry.name
	result.bodies = entry.bodies.duplicate(true)
	result.binary = entry.star_count == 2
	result.real_scale = true
	return result


func primary_star_id() -> String:
	for id: String in bodies:
		if bodies[id].kind == "star":
			return id
	return ""


func extent_meters() -> float:
	var extent: float = 1.0
	for id: String in bodies:
		var reach: float = bodies[id].radius
		var parent: String = id
		while not parent.is_empty():
			reach += float(bodies[parent].orbit_radius)
			parent = bodies[parent].parent_id
		extent = maxf(extent, reach)
	return extent


func _add(id: String, label: String, kind: String, seed_value: int, radius: float,
		parent: String, orbit_radius: float, period: float, phase: float) -> void:
	var body: Dictionary = Profile.create(id, kind, seed_value, radius, parent)
	body.merge({"name": label, "orbit_radius": orbit_radius, "orbit_period": period, "orbit_phase": phase}, true)
	bodies[id] = body


func position_at(id: String, time: float = -1.0) -> Vector3:
	var point: Array = position_precise(id, time)
	return Vector3(point[0], point[1], point[2])


func position_precise(id: String, time: float = -1.0) -> Array:
	if time < 0.0:
		time = elapsed
	var body: Dictionary = bodies[id]
	var angle: float = body.orbit_phase + TAU * fposmod(time, body.orbit_period) / body.orbit_period
	var position: Array = [cos(angle) * float(body.orbit_radius), 0.0, sin(angle) * float(body.orbit_radius)]
	if not str(body.parent_id).is_empty():
		var parent: Array = position_precise(body.parent_id, time)
		for axis in range(3):
			position[axis] += parent[axis]
	return position


func rotation_at(id: String, time: float = -1.0) -> Basis:
	if time < 0.0:
		time = elapsed
	var body: Dictionary = bodies[id]
	return Basis(Vector3.FORWARD, float(body.axial_tilt)) * Basis(Vector3.UP,
		TAU * fposmod(time, body.rotation_period) / body.rotation_period)


func sky_direction(observer_id: String, target_id: String, location: Vector3 = Vector3.ZERO) -> Vector3:
	var observer: Array = position_precise(observer_id)
	var target: Array = position_precise(target_id)
	var delta := Vector3(target[0] - observer[0], target[1] - observer[1], target[2] - observer[2])
	return (rotation_at(observer_id).inverse() * delta - location).normalized()
