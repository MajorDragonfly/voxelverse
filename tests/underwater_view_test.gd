extends SceneTree

const WaterView = preload("res://world/visuals/underwater_view.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.fog_density = 0.017
	scene.add_child(world)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.make_current()
	var water := WaterView.new()
	water.sample_water = func(point: Vector3): return {"water": point.x < 10.0, "depth": 12.0 - point.y}
	scene.add_child(water)
	camera.position = Vector3(0, 13, 0)
	water.update_view()
	_expect(not water.submerged and camera.environment == null, "Dry eye received the water atmosphere.")
	camera.position.y = 11.5
	water.update_view()
	_expect(water.submerged and camera.environment != null, "Eye did not enter an elevated lake.")
	var shallow_range: float = camera.environment.fog_depth_end
	var shallow_exposure: float = camera.environment.tonemap_exposure
	camera.position.y = -12.0
	water.update_view()
	_expect(camera.environment.fog_depth_end < shallow_range and camera.environment.tonemap_exposure < shallow_exposure, "Depth does not reduce visibility/light.")
	_expect(is_equal_approx(world.environment.fog_density, 0.017), "Underwater effect mutated the shared air environment.")
	camera.position = Vector3(12, 0, 0)
	water.update_view()
	_expect(not water.submerged and camera.environment == null, "Dry land below sea height was marked underwater.")
	var custom := Environment.new()
	custom.tonemap_exposure = 1.23
	camera.environment = custom
	camera.position = Vector3(0, 11, 0)
	water.update_view()
	_expect(water.submerged and camera.environment != custom, "Custom camera environment was not overridden.")
	camera.position.y = 12.001
	water.update_view()
	_expect(not water.submerged and camera.environment == custom and is_equal_approx(custom.tonemap_exposure, 1.23), "Surfacing did not restore the exact camera environment.")
	camera.position.y = 11.0
	water.update_view()
	var second := Camera3D.new()
	scene.add_child(second)
	second.position.y = 15.0
	second.make_current()
	water.update_view()
	_expect(camera.environment == custom and second.environment == null and not water.submerged, "Camera switch leaked the water effect.")
	second.position.y = 10.0
	water.update_view()
	water.queue_free()
	await process_frame
	_expect(second.environment == null, "Removing water effect left an overridden camera.")
	scene.queue_free()
	await process_frame
	for message in failures:
		push_error(message)
	print("UNDERWATER_VIEW camera depth, elevated lake, dry land, lighting, restore and camera switch: ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
