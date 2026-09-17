extends SceneTree

const Basin = preload("res://world/surface/living_lake_water.gd")
const Surface = preload("res://world/surface/living_planet_surface_v2.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Profile = preload("res://world/space/celestial_body_profile.gd")
var failures: Array[String] = []
var checks: int = 0

class Fixture extends RefCounted:
	var body: Dictionary = {"radius": 6371000.0}
	var outlet: bool = false
	func height_precise(d: Array) -> float:
		var p := Vector2(d[0], d[2]) * float(body.radius)
		var height: float = minf(14.0, 6.0 + p.length() * 0.4)
		if outlet and p.x > 2.0 and absf(p.y) < 3.0: height = minf(height, 7.0)
		# A separate low hollow behind the west bank must not inherit the lake.
		if p.x < -17.0: height = 4.0
		return height

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	_containment()
	var report: Array[Dictionary] = []
	for seed_value in [15838, 23757, 424242]:
		var body: Dictionary = Profile.create("water:" + str(seed_value), "planet", seed_value, 6371000.0)
		body.terrain_revision = 4
		body.surface_generation = Surface.VERSION
		var surface := Surface.new(body)
		var lakes: Array[Dictionary] = []
		for face in range(6):
			for y in range(-3, 4):
				for x in range(-3, 4):
					surface._feature(Cube.direction(face, x * 0.3, y * 0.3))
					for lake: Dictionary in surface._lakes.values():
						if not lake.is_empty() and lakes.size() < 5 and not lakes.any(func(item: Dictionary) -> bool: return item.key == lake.key): lakes.append(lake)
		_expect(lakes.size() == 5, "Freshwater fixtures missing for " + str(seed_value))
		var start: int = Time.get_ticks_usec()
		var max_jump: float = 0.0
		var old_jump: float = 0.0
		var drained: int = 0
		for lake: Dictionary in lakes:
			var center: Array = lake.direction
			var frame: Basis = Cube.frame(Cube.vector(center))
			var stage: float = surface.water_level_precise(center)
			drained += int(stage < float(lake.level) - 0.01)
			_expect(stage <= lake.level, "Drainage raised a saved lake above its source head")
			for angle in range(48):
				var axis: Vector3 = frame.x * cos(angle * TAU / 48.0) + frame.z * sin(angle * TAU / 48.0)
				for distance in [21.999, 22.001, Basin.REACH - 0.001, Basin.REACH + 0.001]:
					var d: Array = _offset(center, axis * distance, body.radius)
					var next: Array = _offset(center, axis * (distance + 0.002), body.radius)
					max_jump = maxf(max_jump, absf(surface.water_level_precise(d) - surface.water_level_precise(next)))
					old_jump = maxf(old_jump, absf(float(surface._feature(d).get("level", 0.0)) - float(surface._feature(next).get("level", 0.0))))
					var sample: Dictionary = surface._sample(d)
					_expect(is_equal_approx(sample.water_level, surface.water_level_precise(d)), "Rendering and immersion disagree")
			# A cold worker or cache eviction must produce the same surface.
			var fresh := Surface.new(body)
			_expect(is_equal_approx(stage, fresh.water_level_precise(center)), "Lake depends on worker/cache order")
			_expect(surface._water_basins.size() <= 32, "Unbounded hydrology cache")
		_expect(max_jump < 0.03, "Water still jumps at the old 22m edge or new lookup boundary")
		report.append({"seed": seed_value, "lakes": lakes.size(), "drained": drained, "max_edge_jump_m": max_jump, "old_edge_jump_m": old_jump, "elapsed_ms": (Time.get_ticks_usec() - start) / 1000.0})
	for failure in failures: push_error(failure)
	print("LIVING_LAKE_WATER ", JSON.stringify({"checks": checks, "passed": failures.is_empty(), "measurements": report}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _containment() -> void:
	var surface := Fixture.new()
	var lake: Dictionary = {"direction": [0.0, 1.0, 0.0], "level": 10.0}
	var enclosed := Basin.new(surface, lake)
	_expect(is_equal_approx(enclosed.stage, 10.0), "Contained lake lost its flat source level")
	_expect(enclosed.level_at(lake.direction) > surface.height_precise(lake.direction), "Lake basin dried unexpectedly")
	var hollow: Array = _offset(lake.direction, Vector3(-22, 0, 0), surface.body.radius)
	_expect(enclosed.level_at(hollow) < surface.height_precise(hollow), "Disconnected hollow became a floating lake")
	surface.outlet = true
	var drained := Basin.new(surface, lake)
	_expect(drained.stage < enclosed.stage and drained.stage < 7.0, "Open outlet did not drain the source")
	_expect(drained.level_at(lake.direction) > surface.height_precise(lake.direction), "Drained basin lost all retained freshwater")
	for index in range(120):
		var angle: float = index * TAU / 120.0
		var d: Array = _offset(lake.direction, Vector3(cos(angle), 0, sin(angle)) * Basin.REACH, surface.body.radius)
		_expect(is_zero_approx(drained.level_at(d)), "Water escaped the bounded solution at a vertical wall")

func _offset(center: Array, delta: Vector3, radius: float) -> Array:
	return Cube.normalized([center[0] + delta.x / radius, center[1] + delta.y / radius, center[2] + delta.z / radius])

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value and message not in failures: failures.append(message)
