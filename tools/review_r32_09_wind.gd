extends SceneTree
## Production asset, material-only diagnosis. Campaign review is separate.
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const Profile = preload("res://world/generation/planet_profile_v9.gd")
const Flora = preload("res://world/visuals/scenery/flora_species_factory_v9.gd")
const Slots = preload("res://assets/catalog/planet_material_slots.gd")
var output: String
var report: Dictionary = {"samples": [], "failures": []}
var camera: Camera3D
var holder: Node3D
var material: ShaderMaterial

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or DisplayServer.get_name() == "headless":
		push_error("Native display, output and baseline shader folder required")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960, 540)
	report.merge({"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "seed": 15838,
		"scope": "Unshaded production oak; isolates wind/rebase/handoff from lighting and geometry LOD. Not campaign or target-PC acceptance.", "shader_sha256": {}})
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	holder = Node3D.new()
	scene.add_child(holder)
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(0, 3, 8), Vector3(0, 2.5, 0))
	camera.make_current()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("15202b")
	scene.add_child(environment)
	var profile: Dictionary = Profile.create(15838)
	var species: Dictionary = Flora.create_species_variant(profile, "forest", "ancient_oak_v2", 0)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = Assets.get_mesh("ancient_oak_v2", 0)
	multi.instance_count = 1
	multi.set_instance_transform(0, Transform3D.IDENTITY)
	multi.set_instance_custom_data(0, Color(1, 0.37, 0, 1))
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = multi
	material = ShaderMaterial.new()
	material.set_shader_parameter("planet_palette", Slots.create_texture(species.palette))
	material.set_shader_parameter("wind_strength", 0.065)
	material.set_shader_parameter("motion_time", 1.2)
	material.set_shader_parameter("wind_speed", 1.1)
	material.set_shader_parameter("wind_direction", Vector2(0.8, 0.6))
	material.set_shader_parameter("detailed_patch", true)
	material.set_shader_parameter("patch_coverage", 1.0)
	visual.material_override = material
	holder.add_child(visual)
	for version: String in ["before", "after"]:
		var detail: String = FileAccess.get_file_as_string(args[1].path_join("planet_surface_detail.gdshaderinc") if version == "before" else "res://assets/catalog/planet_surface_detail.gdshaderinc")
		var shaders: Dictionary = {}
		for kind: String in ["planet_foliage", "surface_scenery"]:
			var path: String = args[1].path_join(kind + ".gdshader") if version == "before" else ("res://assets/catalog/" if kind == "planet_foliage" else "res://world/surface/visuals/") + kind + ".gdshader"
			var code: String = FileAccess.get_file_as_string(path)
			if code.is_empty() or detail.is_empty():
				push_error("Missing shader source")
				quit(1)
				return
			report.shader_sha256[version + "/" + kind] = code.sha256_text()
			var shader := Shader.new()
			shader.code = code.replace('#include "res://assets/catalog/planet_surface_detail.gdshaderinc"', detail).replace("render_mode diffuse_burley;", "render_mode unshaded;")
			shaders[kind] = shader
		material.shader = shaders.planet_foliage
		var original: Image = await _capture(version + "-near")
		var shift := Vector3(64, -32, 128)
		holder.position = -shift
		camera.position -= shift
		var rebased: Image = await _capture(version + "-rebase")
		holder.position = Vector3.ZERO
		camera.position += shift
		material.shader = shaders.surface_scenery
		var handoff: Image = await _capture(version + "-handoff")
		paused = true
		# Shader TIME is not the campaign clock. Keep the authored clock fixed.
		var until: int = Time.get_ticks_msec() + 600
		while Time.get_ticks_msec() < until: await process_frame
		var frozen: Image = await _capture(version + "-paused")
		paused = false
		var sample := {"version": version, "rebase_mean_rgb": _difference(original, rebased),
			"handoff_mean_rgb": _difference(original, handoff), "pause_mean_rgb": _difference(handoff, frozen)}
		report.samples.append(sample)
		if version == "after":
			for metric: String in ["rebase_mean_rgb", "handoff_mean_rgb", "pause_mean_rgb"]:
				if sample[metric] > 0.0001: report.failures.append("Candidate changed pixels: " + metric)
		else:
			for metric: String in ["rebase_mean_rgb", "handoff_mean_rgb", "pause_mean_rgb"]:
				if sample[metric] <= 0.0001: report.failures.append("Baseline did not reproduce " + metric)
	report.passed = report.failures.is_empty()
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("R32_09_WIND ", JSON.stringify(report))
	scene.queue_free()
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if report.passed else 1)

func _capture(label: String) -> Image:
	for warm in range(4): await RenderingServer.frame_post_draw
	var result: Image = root.get_texture().get_image()
	if result.save_png(output.path_join(label + ".png")) != OK: report.failures.append("Capture failed: " + label)
	return result

func _difference(a: Image, b: Image) -> float:
	var sum: float = 0.0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			sum += absf(ca.r-cb.r) + absf(ca.g-cb.g) + absf(ca.b-cb.b)
	return sum / float(a.get_width() * a.get_height() * 3)
