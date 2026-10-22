extends SceneTree
# Native material-only regression. The campaign comparison is a separate run.
const Ground = preload("res://world/surface/visuals/living_ground.gdshader")
var output: String
var camera: Camera3D
var plane: MeshInstance3D
var material: ShaderMaterial
var failures: Array[String] = []
var rows: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(640, 360)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("819294")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	scene.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, -25, 0)
	light.light_energy = 0.8
	scene.add_child(light)
	camera = Camera3D.new()
	camera.fov = 65
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(5, 4, 9), Vector3.ZERO)
	camera.make_current()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(42, 42)
	var arrays: Array = mesh.get_mesh_arrays()
	var pigment := PackedColorArray()
	pigment.resize(arrays[Mesh.ARRAY_VERTEX].size())
	pigment.fill(Color(0.31, 0.45, 0.28))
	arrays[Mesh.ARRAY_COLOR] = pigment
	plane = MeshInstance3D.new()
	var surface := ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	plane.mesh = surface
	material = ShaderMaterial.new()
	material.shader = Ground
	if OS.get_cmdline_user_args().size() > 1:
		var control := Shader.new()
		control.code = FileAccess.get_file_as_string(OS.get_cmdline_user_args()[1])
		material.shader = control
	material.set_shader_parameter("body_radius", 1000000000000.0)
	material.set_shader_parameter("origin_up", Vector3.UP)
	material.set_shader_parameter("origin_height", 20.0)
	material.set_shader_parameter("origin_phase", Vector3(120, 20, 124))
	plane.material_override = material
	scene.add_child(plane)
	await process_frame
	var original_camera: Transform3D = camera.transform
	var before: Image = await _capture("original")
	var shift := Vector3(83.25, -77.5, 129.125)
	plane.position = -shift
	camera.transform = original_camera.translated(-shift)
	material.set_shader_parameter("origin_height", 20.0 + shift.y)
	material.set_shader_parameter("origin_phase", _phase(Vector3(120, 20, 124) + shift))
	var rebased: Image = await _capture("shifted")
	var error: float = _difference(before, rebased)
	rows.append({"case": "non_periodic_rebase", "mean_rgb_change": error})
	if error > 0.0001: failures.append("Ground pigment moved on rebase")
	# Deliberate broken-origin control establishes sensitivity of this image probe.
	material.set_shader_parameter("origin_phase", Vector3(120, 20, 124))
	var broken: Image = await _capture("negative-missing-origin-update")
	var negative: float = _difference(before, broken)
	rows.append({"case": "negative_missing_origin_update", "mean_rgb_change": negative})
	if negative < 0.005: failures.append("Missing-origin negative control was invisible")
	shift = Vector3(128, 0, -128)
	plane.position = -shift
	camera.transform = original_camera.translated(-shift)
	material.set_shader_parameter("origin_height", 20.0)
	material.set_shader_parameter("origin_phase", Vector3(120, 20, 124))
	var wrapped: Image = await _capture("period-wrapped")
	error = _difference(before, wrapped)
	rows.append({"case": "128m_period", "mean_rgb_change": error})
	if error > 0.0001: failures.append("Ground pigment moved at period boundary")
	var report := {"passed": failures.is_empty(), "failures": failures, "cases": rows,
		"scope": "Production shader on a coloured flat mesh; native origin regression only, separate from the public campaign captures.",
		"renderer": RenderingServer.get_current_rendering_method()}
	var file := FileAccess.open(output.path_join("rebase.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("GFX02_REBASE ", JSON.stringify(report))
	for failure in failures: push_error(failure)
	scene.queue_free()
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _phase(value: Vector3) -> Vector3:
	return Vector3(fposmod(value.x, 128), fposmod(value.y, 128), fposmod(value.z, 128))

func _capture(id: String) -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_draw(false)
	var image: Image = root.get_texture().get_image()
	image.save_png(output.path_join(id + ".png"))
	return image

func _difference(a: Image, b: Image) -> float:
	var x: PackedByteArray = a.get_data()
	var y: PackedByteArray = b.get_data()
	var error: float = 0.0
	for index in range(x.size()): error += abs(int(x[index]) - int(y[index]))
	return error / (float(x.size()) * 255.0)
