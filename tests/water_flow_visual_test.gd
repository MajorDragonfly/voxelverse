extends SceneTree
## Native comparison of current-on/off and frozen frames on the spherical water shader.
const Water = preload("res://world/surface/visuals/living_water.gdshader")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(960, 540)
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 10, 15)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	scene.add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("879fa9")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("bdcfd1")
	scene.add_child(world)
	var material := ShaderMaterial.new()
	material.shader = Water
	material.set_shader_parameter("origin_up", Vector3.UP)
	material.set_shader_parameter("origin_height", 0.0)
	material.set_shader_parameter("body_radius", 6371000.0)
	material.set_shader_parameter("current_strength", 1.0)
	for index in range(2):
		var panel := MeshInstance3D.new()
		panel.mesh = _water_panel(float(index))
		panel.position.x = -5.0 if index == 0 else 5.0
		panel.material_override = material
		scene.add_child(panel)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output := ""
	if "--capture" in args:
		output = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(output)
		material.set_shader_parameter("surface_time", 1.8)
		material.set_shader_parameter("current_strength", 0.0)
		var still: Image = await _capture(output, "current-off")
		material.set_shader_parameter("current_strength", 1.0)
		var moving: Image = await _capture(output, "current-on")
		var ocean := Rect2i(10, 100, 465, 390)
		var lake := Rect2i(485, 100, 465, 390)
		_expect(still.get_region(ocean).get_data() != moving.get_region(ocean).get_data(), "Current did not affect ocean pixels.")
		_expect(still.get_region(lake).get_data() == moving.get_region(lake).get_data(), "Lake received the sea current.")
		material.set_shader_parameter("surface_time", 3.8)
		var later: Image = await _capture(output, "current-later")
		_expect(moving.get_region(ocean).get_data() != later.get_region(ocean).get_data(), "Sea current did not travel over time.")
		paused = true
		var frozen: Image = await _capture(output, "current-paused")
		_expect(later.get_data() == frozen.get_data(), "Paused water changed with a fixed surface clock.")
		paused = false
		var base: Dictionary = await _profile(material, 0.0)
		var flow: Dictionary = await _profile(material, 1.0)
		print(JSON.stringify({"test": "water_flow_frame_sample", "off": base, "on": flow,
			"scope": "36 software-rendered fixture frames per mode; target-PC measurement remains open"}))
	_expect(material.get_shader_parameter("current_strength") != null, "Spherical water has no bounded current setting.")
	scene.queue_free()
	await process_frame
	print(JSON.stringify({"test": "water_flow_visual", "passed": failures.is_empty(), "failures": failures,
		"native_capture": not output.is_empty()}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _water_panel(lake_mask: float) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-4.5, 0, -5), Vector3(-4.5, 0, 5), Vector3(4.5, 0, -5), Vector3(4.5, 0, 5)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(1.4, lake_mask), Vector2(1.4, lake_mask),
		Vector2(1.4, lake_mask), Vector2(1.4, lake_mask)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 2, 3, 1])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _capture(folder: String, name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	_expect(screenshot.save_png(folder.path_join(name + ".png")) == OK, "Cannot save " + name)
	return screenshot

func _profile(material: ShaderMaterial, strength: float) -> Dictionary:
	material.set_shader_parameter("current_strength", strength)
	var samples: Array[int] = []
	for frame in range(40):
		var started: int = Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		if frame >= 4: samples.append(Time.get_ticks_usec() - started)
	samples.sort()
	return {"p50_ms": float(samples[18]) / 1000.0, "p95_ms": float(samples[34]) / 1000.0,
		"max_ms": float(samples.back()) / 1000.0}

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
