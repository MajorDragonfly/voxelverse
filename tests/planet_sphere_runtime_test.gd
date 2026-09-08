extends SceneTree

const Lab = preload("res://world/planet_lab/planet_lab.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Save = preload("res://world/planet_lab/planet_lab_save.gd")
var failures: Array[String] = []
var lab: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	lab = Lab.new()
	root.add_child(lab)
	lab.time_speed = 0.0
	if "--seam-only" in OS.get_cmdline_user_args():
		lab._open_body("m1:lune")
		await _seam_rays()
		for failure in failures:
			push_error(failure)
		lab.queue_free()
		await process_frame
		quit(0 if failures.is_empty() else 1)
		return
	if "--restart-check" in OS.get_cmdline_user_args():
		lab.walker.enabled = false
		var saved: Dictionary = Save.read()
		var matches: bool = lab.system.elapsed == saved.elapsed and lab.system.binary == saved.binary \
			and _distance(saved.location, lab.walker.location(), 256.0) < 0.02
		lab.queue_free()
		await process_frame
		quit(0 if matches else 1)
		return
	await physics_frame
	await physics_frame
	lab.walker.enabled = false
	var start: Dictionary = lab.snapshot()
	var design: String = str(lab.walker.preview.blueprint.get("design_id", ""))
	for mode in ["orbit", "system", "surface"]:
		lab.set_view(mode)
		lab.walker.enabled = false
		await process_frame
		_expect(_distance(start.location, lab.walker.location(), 256.0) < 0.02, "Orbit return moved the player.")
	lab.toggle_binary()
	lab._update_views()
	for id: String in lab.lights:
		var direction: Vector3 = lab.system.sky_direction(lab.body_id, id,
			Cube.vector(Cube.cartesian(lab.walker.location(), 256.0)))
		_expect(lab.lights[id].basis.z.dot(direction) > 0.99999, "Sunlight does not follow the visible star.")
	for time in [0.0, 120.0]:
		lab.system.elapsed = time
		lab._update_views()
		for id: String in lab.lights:
			var direction: Vector3 = lab.system.sky_direction(lab.body_id, id,
				Cube.vector(Cube.cartesian(lab.walker.location(), 256.0)))
			if direction.dot(lab.walker.up_direction) < -0.04:
				_expect(lab.lights[id].light_energy == 0.0, "A sun below the horizon lights the surface from inside the planet.")
	lab.system.elapsed = 117.25
	_expect(lab.save_lab(), "Lab save failed.")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", get_script().resource_path, "--", "--restart-check"], output, true)
	_expect(code == 0 and not str(output).contains("ERROR:"), "Separate process did not restore the M1 snapshot.")
	lab.next_body()
	lab.system.elapsed = 500.0
	lab.load_lab()
	lab.walker.enabled = false
	_expect(lab.body_id == "m1:haven" and lab.system.binary and lab.system.elapsed == 117.25, "Load lost body, binary system or clock.")
	_expect(_distance(start.location, lab.walker.location(), 256.0) < 0.02, "Load moved surface location.")
	_expect(str(lab.walker.preview.blueprint.get("design_id", "")) == design, "Creature design changed on landing.")
	await _water()
	await _circumnavigate()
	await _seam_rays()
	lab.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("M1 runtime passed: radial walking over both poles, cube seams, bounded streaming, ocean buoyancy, origin shifts, orbit return and save recovery.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _water() -> void:
	var water: Dictionary = {}
	for face in range(6):
		for u in [-0.8, -0.4, 0.0, 0.4, 0.8]:
			for v in [-0.8, -0.4, 0.0, 0.4, 0.8]:
				var candidate: Dictionary = Cube.address(lab.body_id, face, u, v, 0.5)
				if lab.terrain.surface.sample(candidate).height < -3.0:
					water = candidate
	_expect(not water.is_empty(), "No ocean fixture found.")
	if water.is_empty():
		return
	lab.walker.place(water)
	lab.walker.enabled = true
	for frame in range(120):
		await physics_frame
	_expect(lab.walker.swimming, "Ocean did not activate buoyancy.")
	_expect(absf(lab.walker.location().height - 0.6) < 0.15, "Ocean surface height is inconsistent with buoyancy.")


func _circumnavigate() -> void:
	# Same streaming/controller, 64 m moon: complete polar route at ordinary
	# fixed physics cadence, with real move_and_slide contact (no teleports).
	lab._open_body("m1:lune")
	_expect(lab.environment.background_color == Color("050913"), "Airless moon incorrectly uses an atmospheric sky.")
	lab.walker.speed = 12.0
	var start: Dictionary = Cube.address(lab.body_id, 0, 0.0, 0.0)
	start.height = lab.terrain.surface.sample(start).height + 1.1
	lab.walker.place(start, Vector3.UP)
	lab.walker.automatic = true
	lab.walker.orbit_axis = Vector3.FORWARD
	var previous: Vector3 = Vector3.RIGHT
	var angle: float = 0.0
	var north: bool = false
	var south: bool = false
	var contacts: int = 0
	var max_altitude: float = 0.0
	var frames: int = 0
	while angle < TAU and frames < 3300:
		await physics_frame
		frames += 1
		var location: Dictionary = lab.walker.location()
		var d: Vector3 = Cube.vector(Cube.direction(location.face, location.u, location.v))
		var projected: Vector3 = d.slide(lab.walker.orbit_axis).normalized()
		angle += atan2(previous.cross(projected).dot(lab.walker.orbit_axis), clampf(previous.dot(projected), -1.0, 1.0))
		previous = projected
		north = north or d.y > 0.999
		south = south or d.y < -0.999
		contacts += int(lab.walker.is_on_floor())
		var above_ground: float = location.height - lab.terrain.surface.sample(location).height
		max_altitude = maxf(max_altitude, above_ground)
		_expect(above_ground > 0.25, "Walker fell through a seam.")
		_expect(above_ground < 4.0, "Walker left the surface during circumnavigation.")
		_expect(lab.terrain.active.size() <= 24, "Collision tile budget exceeded.")
		_expect(lab.terrain.tiles.size() == 96, "Far tile count grew.")
		_expect(lab.walker.basis.y.dot(d) > 0.995, "Creature lost radial orientation.")
	_expect(angle >= TAU and north and south, "Full polar circumnavigation did not finish.")
	_expect(contacts > frames * 0.6, "Walking lacked sustained physical floor contact.")
	_expect(lab.terrain.rebases >= 4, "Circumnavigation did not exercise origin changes.")
	print("M1 polar route: %.4f rad, %d frames, %d floor contacts, %.3f m max ground clearance, %d rebases, %d colliders." % [
		angle, frames, contacts, max_altitude, lab.terrain.rebases, lab.terrain.active.size()])


func _seam_rays() -> void:
	lab.walker.enabled = false
	for face in range(6):
		for uv in [Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1), Vector2(0, -1),
			Vector2(0, 1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1)]:
			var address: Dictionary = Cube.address(lab.body_id, face, uv.x, uv.y)
			address.height = lab.terrain.surface.sample(address).height + 1.1
			lab.walker.place(address)
			await physics_frame
			await physics_frame
			var up: Vector3 = Cube.vector(Cube.direction(face, uv.x, uv.y))
			var query := PhysicsRayQueryParameters3D.create(up * 5.0, -up * 5.0, 1, [lab.walker.get_rid()])
			var hit: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(query)
			_expect(not hit.is_empty(), "Ray passed through cube face %d edge %s." % [face, uv])
			if not hit.is_empty():
				_expect(hit.normal.dot(up) > 0.5, "Seam collider normal points inward.")


func _distance(a: Dictionary, b: Dictionary, radius: float) -> float:
	return Cube.local_position(Cube.cartesian(a, radius), Cube.cartesian(b, radius)).length()


func _expect(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
