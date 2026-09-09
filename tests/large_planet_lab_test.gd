extends SceneTree

const Lab = preload("res://world/planet_lab/planet_lab.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Save = preload("res://world/planet_lab/planet_lab_save.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var lab := Lab.new()
	root.add_child(lab)
	lab.time_speed = 0.0
	if "--large-restart-check" in OS.get_cmdline_user_args():
		lab.walker.enabled = false
		var saved: Dictionary = Save.read()
		_expect(lab.body_id == "m1b:terra" and lab.system.real_scale and lab.system.binary and lab.system.elapsed == 117.25, "Restart lost the large system or its clock.")
		_expect(_distance(saved.location, lab.walker.location(), lab.system.bodies[lab.body_id].radius) < 0.001, "Restart lost the precise Earth location.")
	else:
		lab._open_body("m1b:terra")
		lab.walker.enabled = false
		_expect(lab.system.real_scale and lab.system.bodies[lab.body_id].radius == 6371000.0, "Terra is not physically Earth-sized.")
		var original: Dictionary = lab.snapshot()
		for mode in ["orbit", "system", "surface"]:
			lab.set_view(mode)
			lab.walker.enabled = false
			await process_frame
			_expect(_distance(original.location, lab.walker.location(), 6371000.0) < 0.001, "Earth orbit return changed the physical saved location.")
			if mode == "orbit":
				_expect(lab.space_camera.position.length() < 100.0 and lab.space_bodies[lab.body_id].position.length() < 0.001, "Orbit did not centre/scale before converting to render coordinates.")
		lab.toggle_binary()
		lab.system.elapsed = 117.25
		_expect(lab.save_lab() and Save.read().schema == 3, "Full-size body was not saved with its own schema.")
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", get_script().resource_path, "--", "--large-restart-check"], output, true)
		_expect(code == 0 and not str(output).contains("ERROR:"), "A fresh process failed to reopen the Earth-sized world.")
		var dry: Dictionary = Save.read()
		var future: Dictionary = dry.duplicate(true)
		future.schema = 4
		_expect(not Save.valid(future), "Unknown future large-world schema was accepted.")
		# A real camera below the radial sea level must activate the same optics
		# as the main game, even after changing the floating origin.
		var water: Dictionary = {}
		for face in range(6):
			for u in [-0.6, 0.0, 0.6]:
				var candidate: Dictionary = Cube.address(lab.body_id, face, u, 0.2, -1.2)
				if lab.terrain.surface.sample(candidate).height < -10.0:
					water = candidate
		_expect(not water.is_empty(), "Earth-sized body has no ocean fixture.")
		if not water.is_empty():
			lab.walker.place(water)
			lab.walker.enabled = false
			var camera := Camera3D.new()
			lab.add_child(camera)
			camera.position = Vector3.ZERO
			camera.make_current()
			lab.underwater.update_view()
			_expect(lab.underwater.submerged and camera.environment.fog_depth_end < 40.0, "Earth camera failed to enter its radial ocean.")
			camera.position += lab.walker.up_direction * 2.0
			lab.underwater.update_view()
			_expect(not lab.underwater.submerged and camera.environment == null, "Earth camera kept its water atmosphere in the air.")
			lab.walker.camera.make_current()
			camera.queue_free()
		lab._open_body("m1:aster")
		lab.load_lab()
		lab.walker.enabled = false
		_expect(lab.system.real_scale and _distance(dry.location, lab.walker.location(), 6371000.0) < 0.001, "Switching back from the old test system lost the Earth save.")
	lab.queue_free()
	await process_frame
	await process_frame
	for message in failures:
		push_error(message)
	print("LARGE_PLANET_LAB orbit, double-star system, radial water, schema protection and restart: ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _distance(a: Dictionary, b: Dictionary, radius: float) -> float:
	return Cube.local_position(Cube.cartesian(a, radius), Cube.cartesian(b, radius)).length()


func _expect(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
